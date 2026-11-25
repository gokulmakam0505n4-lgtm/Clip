--!strict
-- Owns the room plots: assigning them each round, and validating every place / remove /
-- wallpaper / flooring request from clients. The client is never trusted.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Catalog = require(Shared.Catalog)
local ItemBuilder = require(Shared.ItemBuilder)

local PlotService = {}

local plots: { Model } = {}
local plotOf: { [Player]: Model } = {}
local lastAction: { [Player]: number } = {}

PlotService.Editing = false

local DEFAULT_WALL = Color3.fromRGB(200, 200, 205)
local DEFAULT_FLOOR = Color3.fromRGB(160, 160, 165)

local function resetPlot(plot: Model)
	local itemsFolder = plot:FindFirstChild("Items") :: Folder
	itemsFolder:ClearAllChildren()
	for _, wall in (plot:FindFirstChild("Walls") :: Folder):GetChildren() do
		local p = wall :: Part
		p.Color = DEFAULT_WALL
		p.Material = Enum.Material.SmoothPlastic
	end
	local floor = plot:FindFirstChild("Floor") :: Part
	floor.Color = DEFAULT_FLOOR
	floor.Material = Enum.Material.SmoothPlastic
	plot:SetAttribute("OwnerUserId", 0)
	plot:SetAttribute("OwnerName", "")
	plot:SetAttribute("WallId", "")
	plot:SetAttribute("FloorId", "")
	local label = plot:FindFirstChild("OwnerLabel", true) :: TextLabel?
	if label then
		label.Text = "Room " .. tostring(plot:GetAttribute("Index"))
	end
end

function PlotService.Init(allPlots: { Model })
	plots = allPlots
	for _, plot in plots do
		resetPlot(plot)
	end
end

function PlotService.ClearAll()
	for player in plotOf do
		player:SetAttribute("PlotIndex", nil)
	end
	table.clear(plotOf)
	for _, plot in plots do
		resetPlot(plot)
	end
end

-- Gives each player an empty room. Returns the players who got one (in order).
function PlotService.Assign(players: { Player }): { Player }
	PlotService.ClearAll()
	local assigned = {}
	for i, player in players do
		local plot = plots[i]
		if not plot then
			break -- more players than rooms: the rest spectate this round
		end
		plotOf[player] = plot
		plot:SetAttribute("OwnerUserId", player.UserId)
		plot:SetAttribute("OwnerName", player.DisplayName)
		player:SetAttribute("PlotIndex", plot:GetAttribute("Index"))
		local label = plot:FindFirstChild("OwnerLabel", true) :: TextLabel?
		if label then
			label.Text = player.DisplayName .. "'s Room"
		end
		table.insert(assigned, player)
	end
	return assigned
end

function PlotService.Release(player: Player)
	local plot = plotOf[player]
	if plot then
		resetPlot(plot)
		plotOf[player] = nil
	end
	lastAction[player] = nil
end

function PlotService.GetPlot(player: Player): Model?
	return plotOf[player]
end

function PlotService.GetPlotByIndex(index: number): Model?
	return plots[index]
end

local function canEdit(player: Player): (boolean, Model?)
	if not PlotService.Editing then
		return false, nil
	end
	local plot = plotOf[player]
	if not plot then
		return false, nil
	end
	-- light rate limit: 15 actions a second is more than any human needs
	local now = os.clock()
	if lastAction[player] and now - lastAction[player] < 1 / 15 then
		return false, nil
	end
	lastAction[player] = now
	return true, plot
end

function PlotService.Place(player: Player, itemId: any, x: any, z: any, rot: any): (boolean, string?)
	if typeof(itemId) ~= "string" or typeof(x) ~= "number" or typeof(z) ~= "number" or typeof(rot) ~= "number" then
		return false, "Bad request"
	end
	if x ~= x or z ~= z or rot ~= rot or math.abs(x) > 1000 or math.abs(z) > 1000 then
		return false, "Bad request" -- NaN / absurd values
	end
	local item = Catalog.Get(itemId)
	if not item or Catalog.IsSurface(item) then
		return false, "Unknown item"
	end
	local ok, plot = canEdit(player)
	if not ok or not plot then
		return false, "You can't build right now"
	end
	local items = plot:FindFirstChild("Items") :: Folder
	if #items:GetChildren() >= Config.MaxItemsPerRoom then
		return false, "Your room is full!"
	end
	-- (price checks go here once paid items exist)

	local r = math.floor(rot) % 4
	local cx, cz = ItemBuilder.SnapToRoom(item, r, x, z)
	if ItemBuilder.Overlaps(items:GetChildren(), item, r, cx, cz) then
		return false, "Something is already there"
	end

	local floorTop = plot:GetAttribute("FloorTop") :: CFrame
	local model = ItemBuilder.Build(item, ItemBuilder.ItemCFrame(floorTop, cx, cz, r))
	model:SetAttribute("X", cx)
	model:SetAttribute("Z", cz)
	model:SetAttribute("Rot", r)
	model.Parent = items
	return true, nil
end

function PlotService.Remove(player: Player, target: any): (boolean, string?)
	local ok, plot = canEdit(player)
	if not ok or not plot then
		return false, "You can't build right now"
	end
	if typeof(target) ~= "Instance" or not target:IsA("Model") then
		return false, "Bad request"
	end
	if target.Parent ~= plot:FindFirstChild("Items") then
		return false, "That isn't in your room"
	end
	target:Destroy()
	return true, nil
end

function PlotService.SetSurface(player: Player, itemId: any): (boolean, string?)
	if typeof(itemId) ~= "string" then
		return false, "Bad request"
	end
	local item = Catalog.Get(itemId)
	if not item or not Catalog.IsSurface(item) then
		return false, "Unknown finish"
	end
	local ok, plot = canEdit(player)
	if not ok or not plot then
		return false, "You can't build right now"
	end
	if item.Category == "Walls" then
		for _, wall in (plot:FindFirstChild("Walls") :: Folder):GetChildren() do
			local p = wall :: Part
			p.Color = item.Color or DEFAULT_WALL
			p.Material = item.Material or Enum.Material.SmoothPlastic
		end
		plot:SetAttribute("WallId", item.Id)
	else
		local floor = plot:FindFirstChild("Floor") :: Part
		floor.Color = item.Color or DEFAULT_FLOOR
		floor.Material = item.Material or Enum.Material.SmoothPlastic
		plot:SetAttribute("FloorId", item.Id)
	end
	return true, nil
end

return PlotService
