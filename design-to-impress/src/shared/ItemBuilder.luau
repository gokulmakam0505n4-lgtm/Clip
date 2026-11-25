--!strict
-- Builds catalogue items as Models, and does the footprint / grid maths shared by
-- the client (ghost preview) and the server (real placement + validation).

local Catalog = require(script.Parent.Catalog)
local Config = require(script.Parent.Config)

local ItemBuilder = {}

-- Footprint (x, z) after rotating by rot * 90 degrees.
function ItemBuilder.RotatedFootprint(item: Catalog.Item, rot: number): (number, number)
	local fp = item.Footprint or Vector3.one
	if rot % 2 == 1 then
		return fp.Z, fp.X
	end
	return fp.X, fp.Z
end

-- Snap a centre coordinate so the footprint edges sit on the grid.
local function snapAxis(value: number, extent: number): number
	local g = Config.GridSize
	local half = extent / 2
	-- the left edge snaps to the grid, then we add back half the extent
	return math.floor((value - half) / g + 0.5) * g + half
end

-- Snap + clamp a local (x, z) position on a room floor. Returns the corrected centre.
function ItemBuilder.SnapToRoom(item: Catalog.Item, rot: number, x: number, z: number): (number, number)
	local w, d = ItemBuilder.RotatedFootprint(item, rot)
	local limit = Config.RoomSize / 2
	x = snapAxis(x, w)
	z = snapAxis(z, d)
	x = math.clamp(x, -limit + w / 2, limit - w / 2)
	z = math.clamp(z, -limit + d / 2, limit - d / 2)
	return x, z
end

-- CFrame for an item's bottom-centre given the floor's top-surface CFrame.
function ItemBuilder.ItemCFrame(floorTop: CFrame, x: number, z: number, rot: number): CFrame
	return floorTop * CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(rot * 90), 0)
end

local function rectOverlap(ax: number, az: number, aw: number, ad: number, bx: number, bz: number, bw: number, bd: number): boolean
	local eps = 0.01
	return math.abs(ax - bx) < (aw + bw) / 2 - eps and math.abs(az - bz) < (ad + bd) / 2 - eps
end

-- True if placing `item` at (x, z, rot) would overlap a solid item already in `placed`.
-- Flat items (rugs) never block and are never blocked.
function ItemBuilder.Overlaps(placed: { Instance }, item: Catalog.Item, rot: number, x: number, z: number): boolean
	if item.Flat then
		return false
	end
	local w, d = ItemBuilder.RotatedFootprint(item, rot)
	for _, other in placed do
		local otherItem = Catalog.Get(other:GetAttribute("ItemId") :: string)
		local ox, oz, orot = other:GetAttribute("X"), other:GetAttribute("Z"), other:GetAttribute("Rot")
		if otherItem and not otherItem.Flat and typeof(ox) == "number" and typeof(oz) == "number" and typeof(orot) == "number" then
			local ow, od = ItemBuilder.RotatedFootprint(otherItem, orot)
			if rectOverlap(x, z, w, d, ox, oz, ow, od) then
				return true
			end
		end
	end
	return false
end

-- Build the model. `ghost` makes it a see-through, non-colliding preview.
function ItemBuilder.Build(item: Catalog.Item, base: CFrame, ghost: boolean?): Model
	local model = Instance.new("Model")
	model.Name = item.Name
	model:SetAttribute("ItemId", item.Id)

	local fp = item.Footprint or Vector3.one
	local hitbox = Instance.new("Part")
	hitbox.Name = "Hitbox"
	hitbox.Size = fp
	hitbox.CFrame = base * CFrame.new(0, fp.Y / 2, 0)
	hitbox.Transparency = if ghost then 0.8 else 1
	hitbox.Color = Color3.fromRGB(80, 200, 255)
	hitbox.Anchored = true
	hitbox.CanCollide = false
	hitbox.CanTouch = false
	hitbox.CanQuery = not ghost
	hitbox.CastShadow = false
	hitbox.Parent = model
	model.PrimaryPart = hitbox

	for i, spec in item.Parts or {} do
		local part = Instance.new("Part")
		part.Name = "Part" .. i
		part.Size = spec.Size
		part.Shape = spec.Shape or Enum.PartType.Block
		local rot = spec.Rot or Vector3.zero
		part.CFrame = base
			* CFrame.new(spec.Offset)
			* CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))
		part.Color = spec.Color
		part.Material = spec.Material or Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Anchored = true
		part.CanTouch = false
		if ghost then
			part.Transparency = 0.5
			part.CanCollide = false
			part.CanQuery = false
			part.CastShadow = false
		else
			part.CanCollide = not item.Flat
			part.CanQuery = false -- clicks hit the Hitbox instead
		end
		if spec.Light and not ghost then
			local light = Instance.new("PointLight")
			light.Brightness = spec.Light.Brightness
			light.Range = spec.Light.Range
			light.Color = spec.Light.Color
			light.Shadows = false
			light.Parent = part
		end
		part.Parent = model
	end

	return model
end

return ItemBuilder
