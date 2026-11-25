--!strict
-- Builds the lobby, podium, leaderboard and room plots from code, so the game runs in an
-- empty Baseplate with nothing built by hand. Re-running it replaces the previous build.

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local WorldBuilder = {}

export type World = {
	Root: Folder,
	LobbySpawn: CFrame,
	Podium: { CFrame }, -- standing spots for 1st, 2nd, 3rd
	Board: Part,
	Plots: { Model },
}

local function part(props: { [string]: any }, parent: Instance): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, val in props do
		(p :: any)[k] = val
	end
	p.Parent = parent
	return p
end

local function signText(parent: Part, face: Enum.NormalId, text: string, name: string?): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = parent
	local label = Instance.new("TextLabel")
	label.Name = name or "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = text
	label.Parent = gui
	return label
end

local function buildLobby(root: Folder): (CFrame, { CFrame }, Part)
	local lobby = Instance.new("Folder")
	lobby.Name = "Lobby"
	lobby.Parent = root

	part({ Name = "Floor", Size = Vector3.new(90, 1, 90), Position = Vector3.new(0, 0.5, 0),
		Color = Color3.fromRGB(245, 205, 225), Material = Enum.Material.Marble }, lobby)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = Vector3.new(0, 1.5, 22)
	spawn.Color = Color3.fromRGB(255, 255, 255)
	spawn.Material = Enum.Material.Neon
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = lobby

	-- Podium: 2nd (left), 1st (middle), 3rd (right), facing the spawn (+Z).
	local podium = Instance.new("Folder")
	podium.Name = "Podium"
	podium.Parent = lobby
	local spots: { CFrame } = {}
	local layout = {
		{ place = 1, x = 0, h = 6, color = Color3.fromRGB(255, 200, 40) },
		{ place = 2, x = -7, h = 4, color = Color3.fromRGB(200, 200, 210) },
		{ place = 3, x = 7, h = 2.5, color = Color3.fromRGB(205, 130, 70) },
	}
	for _, step in layout do
		local block = part({ Name = "Place" .. step.place, Size = Vector3.new(6, step.h, 6),
			Position = Vector3.new(step.x, 1 + step.h / 2, -20), Color = step.color }, podium)
		signText(block, Enum.NormalId.Back, tostring(step.place))
		spots[step.place] = CFrame.new(step.x, 1 + step.h + 3, -20) * CFrame.Angles(0, math.pi, 0)
	end

	local board = part({ Name = "Leaderboard", Size = Vector3.new(18, 12, 1),
		Position = Vector3.new(-28, 7, -10), Color = Color3.fromRGB(60, 40, 90) }, lobby)
	board.CFrame = CFrame.lookAt(board.Position, Vector3.new(0, 7, 22))

	local title = part({ Name = "TitleSign", Size = Vector3.new(30, 6, 1),
		Position = Vector3.new(0, 18, -30), Color = Color3.fromRGB(255, 120, 180),
		Material = Enum.Material.Neon }, lobby)
	signText(title, Enum.NormalId.Back, "DESIGN TO IMPRESS")

	return spawn.CFrame * CFrame.new(0, 3, 0), spots, board
end

local function buildPlot(index: number, origin: CFrame, parent: Instance): Model
	local size = Config.RoomSize
	local h = Config.WallHeight
	local half = size / 2

	local plot = Instance.new("Model")
	plot.Name = "Plot" .. index
	plot:SetAttribute("Index", index)
	plot:SetAttribute("OwnerUserId", 0)

	local floor = part({ Name = "Floor", Size = Vector3.new(size, 1, size),
		CFrame = origin * CFrame.new(0, 0.5, 0), Color = Color3.fromRGB(160, 160, 165) }, plot)
	plot.PrimaryPart = floor

	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = plot
	local wallColor = Color3.fromRGB(200, 200, 205)
	part({ Name = "Back", Size = Vector3.new(size + 2, h, 1),
		CFrame = origin * CFrame.new(0, 1 + h / 2, -half - 0.5), Color = wallColor }, walls)
	part({ Name = "Left", Size = Vector3.new(1, h, size),
		CFrame = origin * CFrame.new(-half - 0.5, 1 + h / 2, 0), Color = wallColor }, walls)
	part({ Name = "Right", Size = Vector3.new(1, h, size),
		CFrame = origin * CFrame.new(half + 0.5, 1 + h / 2, 0), Color = wallColor }, walls)

	-- Invisible front barrier keeps players inside but never blocks clicks or the camera.
	part({ Name = "FrontBarrier", Size = Vector3.new(size + 2, h + 10, 1),
		CFrame = origin * CFrame.new(0, 1 + (h + 10) / 2, half + 0.5), Transparency = 1,
		CanQuery = false, CastShadow = false }, plot)

	local sign = part({ Name = "Sign", Size = Vector3.new(14, 2.5, 0.5),
		CFrame = origin * CFrame.new(0, 1 + h + 1.5, -half - 0.5), Color = Color3.fromRGB(40, 30, 60) }, plot)
	signText(sign, Enum.NormalId.Back, "Room " .. index, "OwnerLabel")

	local items = Instance.new("Folder")
	items.Name = "Items"
	items.Parent = plot

	plot:SetAttribute("SpawnCFrame", origin * CFrame.new(0, 4, half - 3))
	plot:SetAttribute("CameraCFrame",
		CFrame.lookAt((origin * CFrame.new(0, h + 8, half + 20)).Position, (origin * CFrame.new(0, 2, -2)).Position))
	plot:SetAttribute("FloorTop", origin * CFrame.new(0, 1, 0))

	plot.Parent = parent
	return plot
end

function WorldBuilder.Build(): World
	local existing = workspace:FindFirstChild("DesignToImpress")
	if existing then
		existing:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "DesignToImpress"
	root.Parent = workspace

	local lobbySpawn, podium, board = buildLobby(root)

	-- Turn off the Baseplate template's default spawn so everyone spawns in our lobby.
	for _, inst in workspace:GetDescendants() do
		if inst:IsA("SpawnLocation") and not inst:IsDescendantOf(root) then
			inst.Enabled = false
			inst.Transparency = 1
			inst.CanCollide = false
			local decal = inst:FindFirstChildOfClass("Decal")
			if decal then
				decal.Transparency = 1
			end
		end
	end

	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = root
	local plots = {}
	local columns = 4
	local spacing = Config.RoomSize + 16
	for i = 1, Config.MaxPlots do
		local col = (i - 1) % columns
		local row = (i - 1) // columns
		local origin = CFrame.new((col - (columns - 1) / 2) * spacing, 0, 260 + row * (spacing + 20))
		table.insert(plots, buildPlot(i, origin, plotsFolder))
	end

	-- A ground slab under the room area in case the place has no Baseplate.
	part({ Name = "PlotGround", Size = Vector3.new(columns * spacing + 40, 1, 3 * (spacing + 20) + 60),
		Position = Vector3.new(0, -0.45, 260 + (spacing + 20)), Color = Color3.fromRGB(110, 170, 90),
		Material = Enum.Material.Grass }, plotsFolder)

	return { Root = root, LobbySpawn = lobbySpawn, Podium = podium, Board = board, Plots = plots }
end

return WorldBuilder
