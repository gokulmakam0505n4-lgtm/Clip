--!strict
-- The build tool: catalogue panel, ghost preview, grid snapping, rotate, move and delete.
-- PC: the ghost follows the mouse, click to place, R rotates, Esc cancels.
-- Mobile: tap the floor to move the ghost, then press Place. Everything has a button.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local ItemBuilder = require(Shared:WaitForChild("ItemBuilder"))
local UI = require(script.Parent.UI)

local BuildController = {}

type Mode = "Idle" | "Place" | "Delete" | "Move"

function BuildController.Start(state: Folder, remotes: Folder)
	local player = Players.LocalPlayer
	local camera = workspace.CurrentCamera
	local placeRemote = remotes:WaitForChild("PlaceItem") :: RemoteFunction
	local removeRemote = remotes:WaitForChild("RemoveItem") :: RemoteFunction
	local surfaceRemote = remotes:WaitForChild("SetSurface") :: RemoteFunction

	local mode: Mode = "Idle"
	local selected: Catalog.Item? = nil
	local rotation = 0
	local ghost: Model? = nil
	local ghostX, ghostZ = 0, 0
	local ghostValid = false
	local pointer: Vector2? = nil -- screen position (GUI-inset space)
	local busy = false
	local hoverHighlight = Instance.new("Highlight")
	hoverHighlight.FillTransparency = 0.6
	hoverHighlight.DepthMode = Enum.HighlightDepthMode.Occluded

	local function myPlot(): Model?
		local index = player:GetAttribute("PlotIndex")
		if typeof(index) ~= "number" then
			return nil
		end
		local root = workspace:FindFirstChild("DesignToImpress")
		local plots = root and root:FindFirstChild("Plots")
		return plots and plots:FindFirstChild("Plot" .. index) :: Model?
	end

	local function canBuild(): boolean
		return state:GetAttribute("Phase") == "Design" and myPlot() ~= nil
	end

	---------------------------------------------------------------- UI
	local root = UI.new("Frame", {
		Name = "Build", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = UI.Screen,
	})

	-- Panel: category tabs + scrolling item grid, docked bottom-centre.
	local panel = UI.new("Frame", {
		Name = "Catalogue",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -70),
		Size = UDim2.new(0.6, 0, 0.38, 0),
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.05,
		Visible = false,
		Parent = root,
	}, {
		UI.corner(14),
		UI.stroke(UI.Colors.Accent),
		UI.new("UISizeConstraint", { MinSize = Vector2.new(320, 180), MaxSize = Vector2.new(720, 360) }),
	})
	local tabs = UI.new("Frame", {
		Name = "Tabs", BackgroundTransparency = 1, Position = UDim2.new(0, 8, 0, 8), Size = UDim2.new(1, -16, 0, 34), Parent = panel,
	}, {
		UI.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local grid = UI.new("ScrollingFrame", {
		Name = "Items", BackgroundTransparency = 1, Position = UDim2.new(0, 8, 0, 48), Size = UDim2.new(1, -16, 1, -56),
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6,
		ScrollingDirection = Enum.ScrollingDirection.Y, Parent = panel,
	}, {
		UI.new("UIGridLayout", { CellSize = UDim2.new(0, 96, 0, 70), CellPadding = UDim2.new(0, 6, 0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	-- Bottom toolbar: Catalogue / Move / Delete.
	local toolbar = UI.new("Frame", {
		Name = "Toolbar", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(0, 360, 0, 52), BackgroundTransparency = 1, Parent = root,
	}, {
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	-- Placement bar: Place / Rotate / Cancel, shown while holding an item.
	local placeBar = UI.new("Frame", {
		Name = "PlaceBar", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -70),
		Size = UDim2.new(0, 360, 0, 56), BackgroundTransparency = 1, Visible = false, Parent = root,
	}, {
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local holdingLabel = UI.label({
		Name = "Holding", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -132),
		Size = UDim2.new(0, 360, 0, 28), Visible = false, MaxTextSize = 22, TextStrokeTransparency = 0.4, Parent = root,
	})

	local setMode: (Mode) -> ()

	local function clearGhost()
		if ghost then
			ghost:Destroy()
			ghost = nil
		end
	end

	local function updateGhost()
		local plot = myPlot()
		local item = selected
		if mode ~= "Place" or not plot or not item then
			clearGhost()
			return
		end
		if not ghost then
			ghost = ItemBuilder.Build(item, CFrame.new(), true)
			ghost.Name = "BuildGhost"
			ghost.Parent = workspace
		end
		local floor = plot:FindFirstChild("Floor") :: Part
		local floorTop = plot:GetAttribute("FloorTop") :: CFrame
		if pointer then
			local ray = camera:ScreenPointToRay(pointer.X, pointer.Y)
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Include
			params.FilterDescendantsInstances = { floor }
			local hit = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
			if hit then
				local localPos = floorTop:PointToObjectSpace(hit.Position)
				ghostX, ghostZ = localPos.X, localPos.Z
			end
		end
		ghostX, ghostZ = ItemBuilder.SnapToRoom(item, rotation, ghostX, ghostZ)
		local items = plot:FindFirstChild("Items") :: Folder
		ghostValid = not ItemBuilder.Overlaps(items:GetChildren(), item, rotation, ghostX, ghostZ)
		local g = ghost :: Model
		g:PivotTo(ItemBuilder.ItemCFrame(floorTop, ghostX, ghostZ, rotation) * CFrame.new(0, (item.Footprint or Vector3.one).Y / 2, 0))
		local hitbox = g:FindFirstChild("Hitbox") :: Part
		hitbox.Color = if ghostValid then Color3.fromRGB(80, 200, 255) else Color3.fromRGB(255, 70, 70)
		hitbox.Transparency = if ghostValid then 0.85 else 0.5
	end

	local function placeNow()
		local item = selected
		if mode ~= "Place" or not item or busy then
			return
		end
		updateGhost()
		if not ghostValid then
			UI.toast("Something is already there", UI.Colors.Bad)
			return
		end
		busy = true
		local ok, msg = placeRemote:InvokeServer(item.Id, ghostX, ghostZ, rotation)
		busy = false
		if not ok then
			UI.toast(msg or "Couldn't place that", UI.Colors.Bad)
		end
		-- stay in placement mode so you can place several in a row
	end

	local function rotate()
		rotation = (rotation + 1) % 4
		updateGhost()
	end

	local function startPlacing(item: Catalog.Item, rot: number?, x: number?, z: number?)
		clearGhost()
		selected = item
		rotation = rot or 0
		ghostX, ghostZ = x or 0, z or 0
		pointer = nil
		setMode("Place")
		holdingLabel.Text = "Placing: " .. item.Name
		updateGhost()
	end

	local function selectItem(item: Catalog.Item)
		if not canBuild() then
			return
		end
		if Catalog.IsSurface(item) then
			local ok, msg = surfaceRemote:InvokeServer(item.Id)
			if not ok then
				UI.toast(msg or "Couldn't apply that", UI.Colors.Bad)
			end
			return
		end
		panel.Visible = false
		startPlacing(item)
	end

	-- Tabs and item buttons
	local tabButtons: { [string]: TextButton } = {}
	local function showCategory(category: string)
		for name, b in tabButtons do
			b.BackgroundColor3 = if name == category then UI.Colors.Accent else UI.Colors.PanelLight
		end
		for _, child in grid:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		for i, item in Catalog.ByCategory(category) do
			local swatch = item.Color
			if not swatch and item.Parts and item.Parts[1] then
				swatch = item.Parts[1].Color
			end
			local b = UI.button({
				Name = item.Id, LayoutOrder = i, Text = item.Name, MaxTextSize = 16,
				TextYAlignment = Enum.TextYAlignment.Bottom, Parent = grid,
			}, function()
				selectItem(item)
			end)
			UI.new("Frame", {
				Name = "Swatch", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 2),
				Size = UDim2.new(0, 30, 0, 24), BackgroundColor3 = swatch or Color3.new(1, 1, 1), Parent = b,
			}, { UI.corner(6) })
		end
	end
	for i, category in Catalog.Categories do
		tabButtons[category] = UI.button({
			Name = category, LayoutOrder = i, Text = category, Size = UDim2.new(0.2, -5, 1, 0), MaxTextSize = 16, Parent = tabs,
		}, function()
			showCategory(category)
		end)
	end
	showCategory(Catalog.Categories[1])

	UI.button({
		Name = "CatalogueButton", LayoutOrder = 1, Text = "🛋️ Catalogue", Size = UDim2.new(0, 140, 1, 0),
		BackgroundColor3 = UI.Colors.Accent, Parent = toolbar,
	}, function()
		setMode("Idle")
		panel.Visible = not panel.Visible
	end)
	local moveButton = UI.button({
		Name = "MoveButton", LayoutOrder = 2, Text = "✋ Move", Size = UDim2.new(0, 96, 1, 0), Parent = toolbar,
	}, function()
		setMode(if mode == "Move" then "Idle" else "Move")
	end)
	local deleteButton = UI.button({
		Name = "DeleteButton", LayoutOrder = 3, Text = "🗑️ Delete", Size = UDim2.new(0, 96, 1, 0), Parent = toolbar,
	}, function()
		setMode(if mode == "Delete" then "Idle" else "Delete")
	end)

	UI.button({ Name = "Place", LayoutOrder = 1, Text = "✅ Place", Size = UDim2.new(0, 120, 1, 0),
		BackgroundColor3 = UI.Colors.Good, Parent = placeBar }, placeNow)
	UI.button({ Name = "Rotate", LayoutOrder = 2, Text = "🔄 Rotate", Size = UDim2.new(0, 110, 1, 0), Parent = placeBar }, rotate)
	UI.button({ Name = "Cancel", LayoutOrder = 3, Text = "❌ Done", Size = UDim2.new(0, 100, 1, 0),
		BackgroundColor3 = UI.Colors.Bad, Parent = placeBar }, function()
		setMode("Idle")
	end)

	setMode = function(newMode: Mode)
		mode = newMode
		if newMode ~= "Place" then
			selected = nil
			clearGhost()
		else
			panel.Visible = false
		end
		if newMode == "Delete" or newMode == "Move" then
			panel.Visible = false
			UI.toast(if newMode == "Delete" then "Tap an item to delete it" else "Tap an item to pick it up")
		end
		hoverHighlight.Adornee = nil
		hoverHighlight.Parent = nil
		placeBar.Visible = newMode == "Place"
		holdingLabel.Visible = newMode == "Place"
		toolbar.Visible = newMode ~= "Place"
		moveButton.BackgroundColor3 = if newMode == "Move" then UI.Colors.Accent else UI.Colors.PanelLight
		deleteButton.BackgroundColor3 = if newMode == "Delete" then UI.Colors.Bad else UI.Colors.PanelLight
	end

	---------------------------------------------------------------- World input
	local function itemAt(screenPos: Vector2): Model?
		local plot = myPlot()
		if not plot then
			return nil
		end
		local ray = camera:ScreenPointToRay(screenPos.X, screenPos.Y)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { plot:FindFirstChild("Items") :: Instance }
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
		if hit and hit.Instance.Parent and hit.Instance.Parent:IsA("Model") then
			return hit.Instance.Parent :: Model
		end
		return nil
	end

	local function actOnItem(model: Model)
		if busy then
			return
		end
		if mode == "Delete" then
			busy = true
			local ok, msg = removeRemote:InvokeServer(model)
			busy = false
			if not ok then
				UI.toast(msg or "Couldn't delete that", UI.Colors.Bad)
			end
		elseif mode == "Move" then
			local item = Catalog.Get(model:GetAttribute("ItemId") :: string)
			if not item then
				return
			end
			local rot = (model:GetAttribute("Rot") or 0) :: number
			local x = (model:GetAttribute("X") or 0) :: number
			local z = (model:GetAttribute("Z") or 0) :: number
			busy = true
			local ok, msg = removeRemote:InvokeServer(model)
			busy = false
			if ok then
				startPlacing(item, rot, x, z)
			else
				UI.toast(msg or "Couldn't move that", UI.Colors.Bad)
			end
		end
	end

	-- Screen position in GUI-inset space (what ScreenPointToRay expects).
	local function mouseScreenPos(): Vector2
		local m = UserInputService:GetMouseLocation()
		local inset = game:GetService("GuiService"):GetGuiInset()
		return m - inset
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not root.Visible then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local pos = mouseScreenPos()
			if mode == "Place" then
				pointer = pos
				placeNow()
			elseif mode == "Delete" or mode == "Move" then
				local model = itemAt(pos)
				if model then
					actOnItem(model)
				end
			end
		elseif input.KeyCode == Enum.KeyCode.R and mode == "Place" then
			rotate()
		elseif input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.Q then
			setMode("Idle")
		end
	end)

	-- Touch: a tap (not a camera drag) moves the ghost, or picks an item in Move/Delete mode.
	UserInputService.TouchTapInWorld:Connect(function(position, processedByUI)
		if processedByUI or not root.Visible then
			return
		end
		if mode == "Place" then
			pointer = position
			updateGhost()
		elseif mode == "Delete" or mode == "Move" then
			local model = itemAt(position)
			if model then
				actOnItem(model)
			end
		end
	end)

	RunService.RenderStepped:Connect(function()
		if not root.Visible then
			return
		end
		local usingMouse = UserInputService.MouseEnabled and not UserInputService.TouchEnabled
		if mode == "Place" then
			if usingMouse then
				pointer = mouseScreenPos()
			end
			updateGhost()
		elseif (mode == "Delete" or mode == "Move") and usingMouse then
			local model = itemAt(mouseScreenPos())
			if model then
				hoverHighlight.FillColor = if mode == "Delete" then UI.Colors.Bad else UI.Colors.Accent
				hoverHighlight.Adornee = model
				hoverHighlight.Parent = model
			else
				hoverHighlight.Adornee = nil
				hoverHighlight.Parent = nil
			end
		end
	end)

	---------------------------------------------------------------- Show / hide with the round
	local function refresh()
		local active = canBuild()
		if root.Visible ~= active then
			root.Visible = active
			setMode("Idle")
			panel.Visible = active -- open the catalogue at the start of the design phase
		end
	end
	state:GetAttributeChangedSignal("Phase"):Connect(refresh)
	player:GetAttributeChangedSignal("PlotIndex"):Connect(refresh)
	setMode("Idle")
	refresh()
end

return BuildController
