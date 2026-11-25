--!strict
-- Saves coins, XP and wins with DataStores, and mirrors them into leaderstats and
-- player attributes (Coins, XP, Level, XPIntoLevel, XPForNextLevel) for the HUD.
-- In Studio, turn on Game Settings > Security > "Enable Studio Access to API Services"
-- or progress simply won't save (the game still runs).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

type Profile = { Coins: number, XP: number, Wins: number }

local DataService = {}

local profiles: { [Player]: Profile } = {}
local canSave: { [Player]: boolean } = {}

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStores unavailable, progress will not save:", result)
	end
end

local function defaultProfile(): Profile
	return { Coins = 0, XP = 0, Wins = 0 }
end

-- Returns level, XP into the current level, and XP needed for the next level.
function DataService.LevelFromXP(xp: number): (number, number, number)
	local level = 1
	local remaining = xp
	while remaining >= Config.XPPerLevel * level do
		remaining -= Config.XPPerLevel * level
		level += 1
	end
	return level, remaining, Config.XPPerLevel * level
end

local function retry<T>(fn: () -> T): (boolean, T | string)
	local ok, result
	for attempt = 1, 3 do
		ok, result = pcall(fn)
		if ok then
			return true, result
		end
		task.wait(attempt)
	end
	return false, result
end

local function refresh(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	local level, into, need = DataService.LevelFromXP(profile.XP)
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		(stats:FindFirstChild("Coins") :: IntValue).Value = profile.Coins;
		(stats:FindFirstChild("Level") :: IntValue).Value = level;
		(stats:FindFirstChild("Wins") :: IntValue).Value = profile.Wins
	end
	player:SetAttribute("Coins", profile.Coins)
	player:SetAttribute("XP", profile.XP)
	player:SetAttribute("Level", level)
	player:SetAttribute("Wins", profile.Wins)
	player:SetAttribute("XPIntoLevel", into)
	player:SetAttribute("XPForNextLevel", need)
end

local function onPlayerAdded(player: Player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	for _, name in { "Coins", "Level", "Wins" } do
		local value = Instance.new("IntValue")
		value.Name = name
		value.Parent = stats
	end
	stats.Parent = player

	local profile = defaultProfile()
	local ok = true
	local activeStore = store
	if activeStore then
		local loaded, data = retry(function()
			return activeStore:GetAsync("player_" .. player.UserId)
		end)
		if loaded and typeof(data) == "table" then
			profile.Coins = tonumber((data :: any).Coins) or 0
			profile.XP = tonumber((data :: any).XP) or 0
			profile.Wins = tonumber((data :: any).Wins) or 0
		elseif not loaded then
			ok = false -- never overwrite real data with a blank profile
			warn("[DataService] Could not load data for", player.Name, data)
		end
	end
	if player.Parent == nil then
		return
	end
	profiles[player] = profile
	canSave[player] = ok and activeStore ~= nil
	refresh(player)
end

local function save(player: Player)
	local profile = profiles[player]
	local activeStore = store
	if not profile or not canSave[player] or not activeStore then
		return
	end
	local snapshot = { Coins = profile.Coins, XP = profile.XP, Wins = profile.Wins }
	local ok, err = retry(function()
		activeStore:SetAsync("player_" .. player.UserId, snapshot)
		return true
	end)
	if not ok then
		warn("[DataService] Save failed for", player.Name, err)
	end
end

function DataService.AddReward(player: Player, coins: number, xp: number, win: boolean)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.Coins += coins
	profile.XP += xp
	if win then
		profile.Wins += 1
	end
	refresh(player)
end

function DataService.Get(player: Player): Profile?
	return profiles[player]
end

function DataService.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		save(player)
		profiles[player] = nil
		canSave[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(120)
			for _, player in Players:GetPlayers() do
				task.spawn(save, player)
			end
		end
	end)
	game:BindToClose(function()
		local pending = 0
		for _, player in Players:GetPlayers() do
			pending += 1
			task.spawn(function()
				save(player)
				pending -= 1
			end)
		end
		local started = os.clock()
		while pending > 0 and os.clock() - started < 25 do
			task.wait(0.1)
		end
	end)
end

return DataService
