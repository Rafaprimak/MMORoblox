-- Registro de espaço ocupado: impede que construções, árvores, pedras e nós de coleta se sobreponham.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("World"))

local Placement = {}

local CELL = 16
local grid = {}

local function key(cx, cz)
	return cx * 100000 + cz
end

function Placement.reserve(x, z, radius, tag)
	local entry = { x = x, z = z, r = radius, tag = tag }
	local minX, maxX = math.floor((x - radius) / CELL), math.floor((x + radius) / CELL)
	local minZ, maxZ = math.floor((z - radius) / CELL), math.floor((z + radius) / CELL)
	for cx = minX, maxX do
		for cz = minZ, maxZ do
			local k = key(cx, cz)
			local cell = grid[k]
			if not cell then
				cell = {}
				grid[k] = cell
			end
			table.insert(cell, entry)
		end
	end
end

function Placement.isFree(x, z, radius)
	local minX, maxX = math.floor((x - radius) / CELL), math.floor((x + radius) / CELL)
	local minZ, maxZ = math.floor((z - radius) / CELL), math.floor((z + radius) / CELL)
	for cx = minX, maxX do
		for cz = minZ, maxZ do
			local cell = grid[key(cx, cz)]
			if cell then
				for _, entry in cell do
					local dx, dz = entry.x - x, entry.z - z
					local limit = entry.r + radius
					if dx * dx + dz * dz < limit * limit then
						return false
					end
				end
			end
		end
	end
	return true
end

-- Livre de outras coisas, longe de estradas e fora d'água
function Placement.canPlace(x, z, radius, roadClearance)
	if math.abs(x) > World.Half - 12 or math.abs(z) > World.Half - 12 then
		return false
	end
	if World.roadDistance(x, z) < World.RoadWidth + (roadClearance or 4) + radius then
		return false
	end
	return Placement.isFree(x, z, radius)
end

-- Inclinação aproximada do terreno em (x, z)
function Placement.slope(x, z)
	local d = 3
	local hx = World.height(x + d, z) - World.height(x - d, z)
	local hz = World.height(x, z + d) - World.height(x, z - d)
	return math.max(math.abs(hx), math.abs(hz)) / (2 * d)
end

return Placement
