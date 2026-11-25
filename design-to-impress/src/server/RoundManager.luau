--!strict
-- The core loop: Intermission -> Theme reveal -> Design -> Showcase & voting -> Results.
-- Round state is published as attributes on ReplicatedStorage.GameState so clients that
-- join mid-round can read it straight away.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlotService = require(script.Parent.PlotService)
local DataService = require(script.Parent.DataService)

type World = {
	LobbySpawn: CFrame,
	Podium: { CFrame },
	Plots: { Model },
}

type Remotes = {
	State: Folder,
	Vote: RemoteEvent,
	Results: RemoteEvent,
	Notify: RemoteEvent,
}

local RoundManager = {}

local world: World
local remotes: Remotes
local phase = "Waiting"
local participants: { Player } = {}
-- votes[ownerUserId][voterUserId] = stars
local votes: { [number]: { [number]: number } } = {}
local currentShowcaseOwner = 0

local function setState(attrs: { [string]: any })
	-- Phase is written last so listeners see the other values already updated.
	for key, value in attrs do
		if key ~= "Phase" then
			remotes.State:SetAttribute(key, value)
		end
	end
	if attrs.Phase then
		phase = attrs.Phase
		remotes.State:SetAttribute("Phase", attrs.Phase)
	end
end

local function now(): number
	return workspace:GetServerTimeNow()
end

local function teleport(player: Player, cf: CFrame)
	local character = player.Character
	if character and character.PrimaryPart then
		character:PivotTo(cf)
	end
end

local function lobbySpot(): CFrame
	return world.LobbySpawn * CFrame.new(math.random(-3, 3), 0, math.random(-3, 3))
end

local function teleportAllToLobby()
	for _, player in Players:GetPlayers() do
		teleport(player, lobbySpot())
	end
end

-- Waits `seconds`, returning early if `stopWhen()` becomes true.
local function countdown(seconds: number, stopWhen: (() -> boolean)?)
	local endsAt = now() + seconds
	remotes.State:SetAttribute("EndsAt", endsAt)
	while now() < endsAt do
		if stopWhen and stopWhen() then
			return
		end
		task.wait(0.25)
	end
end

local function stillHere(player: Player): boolean
	return player.Parent == Players
end

local function pickTheme(previous: string?): { Name: string, Hint: string }
	local themes = Config.Themes
	local choice = themes[math.random(1, #themes)]
	if #themes > 1 then
		while choice.Name == previous do
			choice = themes[math.random(1, #themes)]
		end
	end
	return choice
end

local function onVote(voter: Player, ownerUserId: any, stars: any)
	if phase ~= "Showcase" or typeof(ownerUserId) ~= "number" or typeof(stars) ~= "number" then
		return
	end
	if ownerUserId ~= currentShowcaseOwner or ownerUserId == voter.UserId then
		return -- only the room on screen, and never your own
	end
	stars = math.clamp(math.floor(stars), 1, 5)
	local roomVotes = votes[ownerUserId]
	if roomVotes then
		roomVotes[voter.UserId] = stars -- changing your mind overwrites your vote
	end
end

local function runShowcase()
	-- Show rooms in a random order so nobody is always first.
	local order = {}
	for _, p in participants do
		if stillHere(p) and PlotService.GetPlot(p) then
			table.insert(order, p)
		end
	end
	for i = #order, 2, -1 do
		local j = math.random(1, i)
		order[i], order[j] = order[j], order[i]
	end

	teleportAllToLobby()
	local shown = 0
	for _, owner in order do
		if not stillHere(owner) then
			continue
		end
		local plot = PlotService.GetPlot(owner)
		if not plot then
			continue
		end
		shown += 1
		currentShowcaseOwner = owner.UserId
		setState({
			Phase = "Showcase",
			ShowcasePlot = plot:GetAttribute("Index"),
			ShowcaseOwner = owner.UserId,
			ShowcaseOwnerName = owner.DisplayName,
			ShowcaseTotal = #order,
		})
		-- ShowcaseIndex changes last: it's the client's cue to switch rooms.
		remotes.State:SetAttribute("ShowcaseIndex", shown)
		countdown(Config.ShowcaseTimePerRoom)
	end
	currentShowcaseOwner = 0
	remotes.State:SetAttribute("ShowcaseIndex", 0) -- so index 1 fires a change next round
end

local function runResults()
	type Entry = { Player: Player, Score: number, Votes: number, Tie: number }
	local entries: { Entry } = {}
	for _, player in participants do
		if stillHere(player) then
			local total, count = 0, 0
			for _, stars in votes[player.UserId] or {} do
				total += stars
				count += 1
			end
			table.insert(entries, {
				Player = player,
				Score = if count > 0 then total / count else 0,
				Votes = count,
				Tie = math.random(),
			})
		end
	end
	table.sort(entries, function(a, b)
		if a.Score ~= b.Score then
			return a.Score > b.Score
		end
		if a.Votes ~= b.Votes then
			return a.Votes > b.Votes
		end
		return a.Tie > b.Tie
	end)

	local ranking = {}
	for place, entry in entries do
		local reward = Config.PlaceRewards[place] or Config.ParticipationReward
		DataService.AddReward(entry.Player, reward.Coins, reward.XP, place == 1 and #entries > 1)
		table.insert(ranking, {
			Place = place,
			UserId = entry.Player.UserId,
			Name = entry.Player.DisplayName,
			Score = math.floor(entry.Score * 10 + 0.5) / 10,
			Votes = entry.Votes,
			Coins = reward.Coins,
			XP = reward.XP,
		})
		local spot = world.Podium[place]
		if spot then
			teleport(entry.Player, spot)
		end
	end

	setState({ Phase = "Results" })
	remotes.Results:FireAllClients(ranking)
	countdown(Config.ResultsTime)
end

local function runRound(previousTheme: string?): string?
	-- Intermission
	teleportAllToLobby()
	setState({ Phase = "Intermission", Theme = "" })
	countdown(Config.IntermissionTime, function()
		return #Players:GetPlayers() < Config.MinPlayers
	end)
	if #Players:GetPlayers() < Config.MinPlayers then
		return previousTheme
	end

	-- Theme reveal
	local theme = pickTheme(previousTheme)
	setState({ Phase = "Theme", Theme = theme.Name, ThemeHint = theme.Hint })
	countdown(Config.ThemeRevealTime)

	-- Design
	participants = PlotService.Assign(Players:GetPlayers())
	table.clear(votes)
	for _, player in participants do
		votes[player.UserId] = {}
		local plot = PlotService.GetPlot(player)
		if plot then
			teleport(player, plot:GetAttribute("SpawnCFrame") :: CFrame)
		end
	end
	for _, player in Players:GetPlayers() do
		if not table.find(participants, player) then
			remotes.Notify:FireClient(player, "All rooms are taken - you'll get one next round!")
		end
	end
	PlotService.Editing = true
	setState({ Phase = "Design" })
	countdown(Config.DesignTime, function()
		for _, p in participants do
			if stillHere(p) then
				return false
			end
		end
		return true -- everyone who was building has left
	end)
	PlotService.Editing = false

	runShowcase()
	runResults()

	teleportAllToLobby()
	PlotService.ClearAll()
	participants = {}
	return theme.Name
end

function RoundManager.Start(w: World, r: Remotes)
	world = w
	remotes = r

	r.Vote.OnServerEvent:Connect(onVote)

	local function onCharacter(player: Player, character: Model)
		-- respawning mid-design puts you back in your room, otherwise the lobby
		task.defer(function()
			if not character.PrimaryPart then
				character:WaitForChild("HumanoidRootPart", 5)
			end
			local plot = PlotService.GetPlot(player)
			if phase == "Design" and plot then
				teleport(player, plot:GetAttribute("SpawnCFrame") :: CFrame)
			else
				teleport(player, lobbySpot())
			end
		end)
	end
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(c)
			onCharacter(player, c)
		end)
		if player.Character then
			onCharacter(player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		PlotService.Release(player)
		votes[player.UserId] = nil
	end)

	task.spawn(function()
		local lastTheme: string? = nil
		while true do
			if #Players:GetPlayers() < Config.MinPlayers then
				setState({ Phase = "Waiting", Theme = "", EndsAt = 0 })
				repeat
					task.wait(1)
				until #Players:GetPlayers() >= Config.MinPlayers
			end
			local ok, result = pcall(runRound, lastTheme)
			if ok then
				lastTheme = result
			else
				warn("[RoundManager] Round crashed, starting a new one:", result)
				PlotService.Editing = false
				PlotService.ClearAll()
				task.wait(2)
			end
		end
	end)
end

return RoundManager
