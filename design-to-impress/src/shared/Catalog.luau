--!strict
-- The catalogue: every item a player can place, plus wall and floor finishes.
-- Furniture is built from simple Parts so the game works with no imported models.
-- Each part is { Size, Offset, Color, Material?, Shape?, Rot?, Light? } where Offset
-- is the part's centre measured from the item's bottom-centre (y = 0 is the floor).

export type PartSpec = {
	Size: Vector3,
	Offset: Vector3,
	Color: Color3,
	Material: Enum.Material?,
	Shape: Enum.PartType?,
	Rot: Vector3?, -- degrees
	Light: { Brightness: number, Range: number, Color: Color3 }?,
}

export type Item = {
	Id: string,
	Name: string,
	Category: string,
	Price: number,
	Footprint: Vector3?, -- bounding box (x width, y height, z depth)
	Flat: boolean?, -- flat items (rugs) may overlap other items
	Parts: { PartSpec }?,
	Color: Color3?, -- walls / floors
	Material: Enum.Material?, -- walls / floors
}

local Catalog = {}

Catalog.Categories = { "Furniture", "Walls", "Floors", "Lighting", "Decor" }

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

local WOOD = rgb(150, 105, 65)
local DARK_WOOD = rgb(90, 60, 40)
local WHITE = rgb(240, 240, 235)
local BLACK = rgb(30, 30, 35)
local METAL = rgb(120, 120, 130)

local function legs(w: number, d: number, h: number, inset: number, color: Color3): { PartSpec }
	local out: { PartSpec } = {}
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			table.insert(out, {
				Size = v(0.4, h, 0.4),
				Offset = v(sx * (w / 2 - inset), h / 2, sz * (d / 2 - inset)),
				Color = color,
				Material = Enum.Material.Wood,
			})
		end
	end
	return out
end

local function join(...: { PartSpec }): { PartSpec }
	local out: { PartSpec } = {}
	for _, list in { ... } do
		for _, p in list do
			table.insert(out, p)
		end
	end
	return out
end

local items: { Item } = {
	---------------------------------------------------------------- Furniture (10)
	{
		Id = "bed", Name = "Cosy Bed", Category = "Furniture", Price = 0,
		Footprint = v(6, 4, 9),
		Parts = {
			{ Size = v(6, 1.5, 9), Offset = v(0, 0.75, 0), Color = WOOD, Material = Enum.Material.Wood },
			{ Size = v(5.6, 0.8, 8.4), Offset = v(0, 1.9, 0.2), Color = WHITE, Material = Enum.Material.Fabric },
			{ Size = v(4, 0.5, 1.4), Offset = v(0, 2.55, -3.2), Color = rgb(255, 255, 255), Material = Enum.Material.Fabric },
			{ Size = v(5.6, 0.3, 5), Offset = v(0, 2.45, 1.6), Color = rgb(110, 150, 210), Material = Enum.Material.Fabric },
			{ Size = v(6, 4, 0.5), Offset = v(0, 2, -4.25), Color = DARK_WOOD, Material = Enum.Material.Wood },
		},
	},
	{
		Id = "sofa", Name = "Sofa", Category = "Furniture", Price = 0,
		Footprint = v(7, 3.5, 3),
		Parts = {
			{ Size = v(7, 1.5, 3), Offset = v(0, 0.75, 0), Color = rgb(200, 90, 80), Material = Enum.Material.Fabric },
			{ Size = v(7, 2, 0.8), Offset = v(0, 2.5, -1.1), Color = rgb(185, 80, 70), Material = Enum.Material.Fabric },
			{ Size = v(0.8, 1, 3), Offset = v(-3.1, 2, 0), Color = rgb(185, 80, 70), Material = Enum.Material.Fabric },
			{ Size = v(0.8, 1, 3), Offset = v(3.1, 2, 0), Color = rgb(185, 80, 70), Material = Enum.Material.Fabric },
		},
	},
	{
		Id = "armchair", Name = "Armchair", Category = "Furniture", Price = 0,
		Footprint = v(3.5, 3.5, 3),
		Parts = {
			{ Size = v(3.5, 1.5, 3), Offset = v(0, 0.75, 0), Color = rgb(90, 130, 110), Material = Enum.Material.Fabric },
			{ Size = v(3.5, 2, 0.7), Offset = v(0, 2.5, -1.15), Color = rgb(80, 115, 100), Material = Enum.Material.Fabric },
			{ Size = v(0.6, 1, 3), Offset = v(-1.45, 2, 0), Color = rgb(80, 115, 100), Material = Enum.Material.Fabric },
			{ Size = v(0.6, 1, 3), Offset = v(1.45, 2, 0), Color = rgb(80, 115, 100), Material = Enum.Material.Fabric },
		},
	},
	{
		Id = "dining_table", Name = "Dining Table", Category = "Furniture", Price = 0,
		Footprint = v(6, 3, 4),
		Parts = join(
			{ { Size = v(6, 0.4, 4), Offset = v(0, 2.8, 0), Color = WOOD, Material = Enum.Material.Wood } },
			legs(6, 4, 2.6, 0.4, DARK_WOOD)
		),
	},
	{
		Id = "chair", Name = "Wooden Chair", Category = "Furniture", Price = 0,
		Footprint = v(2, 4, 2),
		Parts = join({
			{ Size = v(2, 0.3, 2), Offset = v(0, 1.65, 0), Color = WOOD, Material = Enum.Material.Wood },
			{ Size = v(2, 2.2, 0.3), Offset = v(0, 2.9, -0.85), Color = WOOD, Material = Enum.Material.Wood },
		}, legs(2, 2, 1.5, 0.25, DARK_WOOD)),
	},
	{
		Id = "desk", Name = "Desk", Category = "Furniture", Price = 0,
		Footprint = v(6, 3, 3),
		Parts = {
			{ Size = v(6, 0.3, 3), Offset = v(0, 2.85, 0), Color = WHITE, Material = Enum.Material.SmoothPlastic },
			{ Size = v(0.3, 2.7, 3), Offset = v(-2.85, 1.35, 0), Color = WHITE, Material = Enum.Material.SmoothPlastic },
			{ Size = v(1.8, 2.7, 2.8), Offset = v(1.95, 1.35, 0), Color = rgb(215, 215, 210), Material = Enum.Material.SmoothPlastic },
		},
	},
	{
		Id = "bookshelf", Name = "Bookshelf", Category = "Furniture", Price = 0,
		Footprint = v(4, 7, 1.5),
		Parts = {
			{ Size = v(4, 7, 0.2), Offset = v(0, 3.5, -0.65), Color = DARK_WOOD, Material = Enum.Material.Wood },
			{ Size = v(0.2, 7, 1.5), Offset = v(-1.9, 3.5, 0), Color = DARK_WOOD, Material = Enum.Material.Wood },
			{ Size = v(0.2, 7, 1.5), Offset = v(1.9, 3.5, 0), Color = DARK_WOOD, Material = Enum.Material.Wood },
			{ Size = v(3.6, 0.2, 1.5), Offset = v(0, 0.1, 0), Color = DARK_WOOD, Material = Enum.Material.Wood },
			{ Size = v(3.6, 0.2, 1.5), Offset = v(0, 2.4, 0), Color = DARK_WOOD, Material = Enum.Material.Wood },
			{ Size = v(3.6, 0.2, 1.5), Offset = v(0, 4.7, 0), Color = DARK_WOOD, Material = Enum.Material.Wood },
			{ Size = v(3.6, 0.2, 1.5), Offset = v(0, 6.9, 0), Color = DARK_WOOD, Material = Enum.Material.Wood },
			{ Size = v(2.6, 1.6, 1), Offset = v(-0.4, 1.0, 0), Color = rgb(180, 60, 60) },
			{ Size = v(3, 1.6, 1), Offset = v(0.1, 3.3, 0), Color = rgb(60, 110, 180) },
			{ Size = v(2, 1.6, 1), Offset = v(0.6, 5.6, 0), Color = rgb(220, 180, 60) },
		},
	},
	{
		Id = "wardrobe", Name = "Wardrobe", Category = "Furniture", Price = 0,
		Footprint = v(4, 8, 2),
		Parts = {
			{ Size = v(4, 8, 2), Offset = v(0, 4, 0), Color = WOOD, Material = Enum.Material.Wood },
			{ Size = v(0.1, 7.4, 0.1), Offset = v(0, 4, 1.02), Color = DARK_WOOD },
			{ Size = v(0.2, 1, 0.2), Offset = v(-0.35, 4, 1.1), Color = METAL, Material = Enum.Material.Metal },
			{ Size = v(0.2, 1, 0.2), Offset = v(0.35, 4, 1.1), Color = METAL, Material = Enum.Material.Metal },
		},
	},
	{
		Id = "coffee_table", Name = "Coffee Table", Category = "Furniture", Price = 0,
		Footprint = v(4, 1.5, 2.5),
		Parts = join(
			{ { Size = v(4, 0.3, 2.5), Offset = v(0, 1.35, 0), Color = rgb(170, 200, 210), Material = Enum.Material.Glass } },
			legs(4, 2.5, 1.2, 0.3, BLACK)
		),
	},
	{
		Id = "tv_stand", Name = "TV & Stand", Category = "Furniture", Price = 0,
		Footprint = v(6, 5.5, 1.5),
		Parts = {
			{ Size = v(6, 1.5, 1.5), Offset = v(0, 0.75, 0), Color = BLACK, Material = Enum.Material.SmoothPlastic },
			{ Size = v(0.6, 0.6, 0.4), Offset = v(0, 1.8, -0.2), Color = BLACK },
			{ Size = v(5, 3, 0.3), Offset = v(0, 3.6, -0.2), Color = BLACK, Material = Enum.Material.SmoothPlastic },
			{ Size = v(4.7, 2.7, 0.05), Offset = v(0, 3.6, -0.03), Color = rgb(40, 70, 120), Material = Enum.Material.Neon },
		},
	},

	---------------------------------------------------------------- Lighting (4)
	{
		Id = "floor_lamp", Name = "Floor Lamp", Category = "Lighting", Price = 0,
		Footprint = v(1.5, 6, 1.5),
		Parts = {
			{ Size = v(1.5, 0.2, 1.5), Offset = v(0, 0.1, 0), Color = METAL, Material = Enum.Material.Metal },
			{ Size = v(0.2, 5, 0.2), Offset = v(0, 2.6, 0), Color = METAL, Material = Enum.Material.Metal },
			{
				Size = v(1.5, 1, 1.5), Offset = v(0, 5.5, 0), Color = rgb(255, 235, 190), Material = Enum.Material.Neon,
				Light = { Brightness = 2, Range = 14, Color = rgb(255, 220, 170) },
			},
		},
	},
	{
		Id = "neon_pink", Name = "Pink Neon Tube", Category = "Lighting", Price = 0,
		Footprint = v(1, 7, 1),
		Parts = {
			{ Size = v(1, 0.3, 1), Offset = v(0, 0.15, 0), Color = BLACK },
			{
				Size = v(0.4, 6.5, 0.4), Offset = v(0, 3.55, 0), Color = rgb(255, 60, 200), Material = Enum.Material.Neon,
				Light = { Brightness = 2, Range = 16, Color = rgb(255, 60, 200) },
			},
		},
	},
	{
		Id = "neon_blue", Name = "Blue Neon Tube", Category = "Lighting", Price = 0,
		Footprint = v(1, 7, 1),
		Parts = {
			{ Size = v(1, 0.3, 1), Offset = v(0, 0.15, 0), Color = BLACK },
			{
				Size = v(0.4, 6.5, 0.4), Offset = v(0, 3.55, 0), Color = rgb(60, 160, 255), Material = Enum.Material.Neon,
				Light = { Brightness = 2, Range = 16, Color = rgb(60, 160, 255) },
			},
		},
	},
	{
		Id = "candelabra", Name = "Candelabra", Category = "Lighting", Price = 0,
		Footprint = v(2, 4.5, 1),
		Parts = {
			{ Size = v(1, 0.2, 1), Offset = v(0, 0.1, 0), Color = rgb(60, 55, 50), Material = Enum.Material.Metal },
			{ Size = v(0.2, 3, 0.2), Offset = v(0, 1.6, 0), Color = rgb(60, 55, 50), Material = Enum.Material.Metal },
			{ Size = v(2, 0.2, 0.2), Offset = v(0, 3.1, 0), Color = rgb(60, 55, 50), Material = Enum.Material.Metal },
			{ Size = v(0.3, 0.8, 0.3), Offset = v(-0.9, 3.6, 0), Color = WHITE },
			{ Size = v(0.3, 0.8, 0.3), Offset = v(0, 3.6, 0), Color = WHITE },
			{ Size = v(0.3, 0.8, 0.3), Offset = v(0.9, 3.6, 0), Color = WHITE },
			{
				Size = v(0.2, 0.4, 0.2), Offset = v(0, 4.2, 0), Color = rgb(255, 170, 50), Material = Enum.Material.Neon,
				Light = { Brightness = 1.5, Range = 12, Color = rgb(255, 150, 60) },
			},
			{ Size = v(0.2, 0.4, 0.2), Offset = v(-0.9, 4.2, 0), Color = rgb(255, 170, 50), Material = Enum.Material.Neon },
			{ Size = v(0.2, 0.4, 0.2), Offset = v(0.9, 4.2, 0), Color = rgb(255, 170, 50), Material = Enum.Material.Neon },
		},
	},

	---------------------------------------------------------------- Decor (4)
	{
		Id = "plant", Name = "Potted Plant", Category = "Decor", Price = 0,
		Footprint = v(2, 4, 2),
		Parts = {
			{ Size = v(1.6, 1.4, 1.6), Offset = v(0, 0.7, 0), Color = rgb(190, 100, 60), Material = Enum.Material.Concrete },
			{ Size = v(2, 2.6, 2), Offset = v(0, 2.7, 0), Color = rgb(70, 150, 70), Material = Enum.Material.Grass, Shape = Enum.PartType.Ball },
		},
	},
	{
		Id = "rug", Name = "Round Rug", Category = "Decor", Price = 0,
		Footprint = v(6, 0.2, 6), Flat = true,
		Parts = {
			{
				Size = v(0.2, 6, 6), Offset = v(0, 0.1, 0), Color = rgb(200, 170, 220), Material = Enum.Material.Fabric,
				Shape = Enum.PartType.Cylinder, Rot = v(0, 0, 90),
			},
		},
	},
	{
		Id = "pumpkin", Name = "Jack-o'-Lantern", Category = "Decor", Price = 0,
		Footprint = v(2, 2.3, 2),
		Parts = {
			{
				Size = v(2, 1.8, 2), Offset = v(0, 0.9, 0), Color = rgb(235, 120, 20), Material = Enum.Material.SmoothPlastic,
				Shape = Enum.PartType.Ball,
				Light = { Brightness = 1, Range = 8, Color = rgb(255, 140, 40) },
			},
			{ Size = v(0.3, 0.5, 0.3), Offset = v(0, 2.05, 0), Color = rgb(70, 110, 40) },
		},
	},
	{
		Id = "gaming_pc", Name = "Gaming PC Setup", Category = "Decor", Price = 0,
		Footprint = v(4, 4.8, 2.5),
		Parts = join({
			{ Size = v(4, 0.3, 2.5), Offset = v(0, 2.45, 0), Color = BLACK, Material = Enum.Material.SmoothPlastic },
			{ Size = v(2.6, 1.6, 0.2), Offset = v(-0.3, 3.8, -0.8), Color = BLACK },
			{ Size = v(2.4, 1.4, 0.05), Offset = v(-0.3, 3.8, -0.68), Color = rgb(80, 255, 140), Material = Enum.Material.Neon },
			{
				Size = v(0.8, 1.6, 1.6), Offset = v(1.5, 3.4, -0.3), Color = rgb(170, 60, 255), Material = Enum.Material.Neon,
				Light = { Brightness = 1.5, Range = 10, Color = rgb(170, 60, 255) },
			},
		}, legs(4, 2.5, 2.3, 0.3, BLACK)),
	},

	---------------------------------------------------------------- Walls (6)
	{ Id = "wall_white", Name = "Plain White", Category = "Walls", Price = 0, Color = rgb(235, 235, 230), Material = Enum.Material.SmoothPlastic },
	{ Id = "wall_purple", Name = "Midnight Purple", Category = "Walls", Price = 0, Color = rgb(55, 35, 80), Material = Enum.Material.SmoothPlastic },
	{ Id = "wall_cream", Name = "Café Cream", Category = "Walls", Price = 0, Color = rgb(240, 220, 185), Material = Enum.Material.Plaster },
	{ Id = "wall_black", Name = "Gamer Black", Category = "Walls", Price = 0, Color = rgb(25, 25, 30), Material = Enum.Material.SmoothPlastic },
	{ Id = "wall_mint", Name = "Mint Green", Category = "Walls", Price = 0, Color = rgb(170, 225, 195), Material = Enum.Material.SmoothPlastic },
	{ Id = "wall_brick", Name = "Red Brick", Category = "Walls", Price = 0, Color = rgb(160, 75, 60), Material = Enum.Material.Brick },

	---------------------------------------------------------------- Floors (6)
	{ Id = "floor_oak", Name = "Oak Planks", Category = "Floors", Price = 0, Color = rgb(190, 145, 95), Material = Enum.Material.WoodPlanks },
	{ Id = "floor_dark", Name = "Dark Planks", Category = "Floors", Price = 0, Color = rgb(85, 55, 40), Material = Enum.Material.WoodPlanks },
	{ Id = "floor_marble", Name = "White Marble", Category = "Floors", Price = 0, Color = rgb(235, 235, 240), Material = Enum.Material.Marble },
	{ Id = "floor_carpet", Name = "Grey Carpet", Category = "Floors", Price = 0, Color = rgb(130, 130, 135), Material = Enum.Material.Fabric },
	{ Id = "floor_slate", Name = "Slate", Category = "Floors", Price = 0, Color = rgb(70, 75, 80), Material = Enum.Material.Slate },
	{ Id = "floor_pink", Name = "Pink Carpet", Category = "Floors", Price = 0, Color = rgb(240, 160, 200), Material = Enum.Material.Fabric },
}

Catalog.Items = items

local byId: { [string]: Item } = {}
for _, item in items do
	assert(byId[item.Id] == nil, "Duplicate catalogue id " .. item.Id)
	byId[item.Id] = item
end

function Catalog.Get(id: string): Item?
	return byId[id]
end

function Catalog.ByCategory(category: string): { Item }
	local out = {}
	for _, item in items do
		if item.Category == category then
			table.insert(out, item)
		end
	end
	return out
end

function Catalog.IsSurface(item: Item): boolean
	return item.Category == "Walls" or item.Category == "Floors"
end

return Catalog
