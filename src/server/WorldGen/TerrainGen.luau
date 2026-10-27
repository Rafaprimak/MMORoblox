-- Gera o terreno do Roblox (voxels) a partir das funções de relevo em Shared/World.
-- Continente com colinas, bosque, planalto, lago, praia, oceano e montanhas nas bordas.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("World"))

local TerrainGen = {}

local RES = 4
local HALF = World.Half
local MIN_Y = -24
local MAX_Y = 440 -- montanhas esticadas (World.HeightScale)
local NY = (MAX_Y - MIN_Y) / RES -- altura máxima possível (cada bloco usa só o que precisa)
local N = (2 * HALF) / RES -- colunas por eixo
local CHUNK = 32 -- colunas por bloco gravado

local M = Enum.Material

local function setupLook(terrain)
	terrain:SetMaterialColor(M.Grass, Color3.fromRGB(104, 160, 72))
	terrain:SetMaterialColor(M.LeafyGrass, Color3.fromRGB(88, 142, 64))
	terrain:SetMaterialColor(M.Ground, Color3.fromRGB(120, 95, 70))
	terrain:SetMaterialColor(M.Sand, Color3.fromRGB(225, 205, 150))
	terrain:SetMaterialColor(M.Rock, Color3.fromRGB(120, 118, 115))
	terrain:SetMaterialColor(M.Slate, Color3.fromRGB(125, 125, 130))
	terrain:SetMaterialColor(M.Cobblestone, Color3.fromRGB(150, 145, 140))
	terrain:SetMaterialColor(M.Mud, Color3.fromRGB(85, 70, 50))
	terrain:SetMaterialColor(M.Basalt, Color3.fromRGB(60, 55, 55))
	terrain.WaterColor = Color3.fromRGB(40, 120, 160)
	terrain.WaterTransparency = 0.35
	terrain.WaterWaveSize = 0.12
	terrain.WaterWaveSpeed = 8
	terrain.WaterReflectance = 0.6
	pcall(function()
		terrain.Decoration = true -- grama animada
	end)
end

-- Calibração: o Roblox desenha a superfície de um voxel cheio mais alto do que a conta sugere (cerca de
-- meio voxel). Escreve uma laje de teste plana numa altura conhecida, mede com raycast onde o chão ficou
-- e devolve a correção. Assim o chão sai na altura de World.height (vila, pisos, NPCs, moradores).
TerrainGen.Bias = 0

local function calibrate(terrain)
	local target = World.TownHeight
	local size = 8 -- voxels por lado
	local origin = Vector3.new(-HALF, MIN_Y, -HALF)
	local ny = math.ceil((target - MIN_Y) / RES) + 3
	local materials, occupancy = table.create(size), table.create(size)
	for i = 1, size do
		materials[i], occupancy[i] = table.create(ny), table.create(ny)
		for j = 1, ny do
			local fill = math.clamp((target - (MIN_Y + (j - 1) * RES)) / RES, 0, 1)
			materials[i][j], occupancy[i][j] = table.create(size, if fill > 0 then M.Grass else M.Air), table.create(size, fill)
		end
	end
	local region = Region3.new(origin, origin + Vector3.new(size * RES, ny * RES, size * RES))
	terrain:WriteVoxels(region, RES, materials, occupancy)
	task.wait()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { terrain }
	local center = origin + Vector3.new(size * RES / 2, 0, size * RES / 2)
	local hit = workspace:Raycast(Vector3.new(center.X, target + 40, center.Z), Vector3.new(0, -80, 0), params)
	terrain:FillBlock(CFrame.new(region.CFrame.Position), region.Size, M.Air)
	if not hit then
		return 0
	end
	return math.clamp(target - hit.Position.Y, -RES, RES)
end

function TerrainGen.generate(onProgress)
	local terrain = workspace.Terrain
	terrain:Clear()
	setupLook(terrain)
	local ok, bias = pcall(calibrate, terrain)
	TerrainGen.Bias = if ok then bias else 0
	print(("[Terreno] Correção de altura dos voxels: %.2f studs"):format(TerrainGen.Bias))

	-- 1) alturas e pesos de cada coluna (com borda de 1 para calcular inclinação)
	local heights = table.create(N + 2)
	local weights = table.create(N)
	for ix = 0, N + 1 do
		local column = table.create(N + 2)
		local x = -HALF + (ix - 0.5) * RES
		for iz = 0, N + 1 do
			local z = -HALF + (iz - 0.5) * RES
			if ix >= 1 and ix <= N and iz >= 1 and iz <= N then
				local w = World.weights(x, z)
				weights[ix] = weights[ix] or table.create(N)
				weights[ix][iz] = w
				column[iz + 1] = World.heightWithWeights(x, z, w)
			else
				column[iz + 1] = World.height(x, z)
			end
		end
		heights[ix + 1] = column
		if ix % 32 == 0 then
			task.wait()
		end
	end

	local function heightAt(ix, iz)
		return heights[ix + 1][iz + 1]
	end

	-- 2) grava os voxels em blocos
	local chunksPerAxis = N / CHUNK
	local total = chunksPerAxis * chunksPerAxis
	local done = 0
	for cx = 0, chunksPerAxis - 1 do
		for cz = 0, chunksPerAxis - 1 do
			-- altura útil deste bloco (evita gravar ar vazio acima do relevo)
			local top = World.SeaLevel
			for i = 1, CHUNK do
				for k = 1, CHUNK do
					top = math.max(top, heightAt(cx * CHUNK + i, cz * CHUNK + k))
				end
			end
			local ny = math.min(NY, math.ceil((top - MIN_Y) / RES) + 2)
			local materials = table.create(CHUNK)
			local occupancy = table.create(CHUNK)
			for i = 1, CHUNK do
				local matX = table.create(ny)
				local occX = table.create(ny)
				for j = 1, ny do
					matX[j] = table.create(CHUNK)
					occX[j] = table.create(CHUNK)
				end
				materials[i] = matX
				occupancy[i] = occX

				local ix = cx * CHUNK + i
				local x = -HALF + (ix - 0.5) * RES
				for k = 1, CHUNK do
					local iz = cz * CHUNK + k
					local z = -HALF + (iz - 0.5) * RES
					local h = heightAt(ix, iz)
					local slope = math.max(
						math.abs(heightAt(ix + 1, iz) - heightAt(ix - 1, iz)),
						math.abs(heightAt(ix, iz + 1) - heightAt(ix, iz - 1))
					) / (2 * RES)
					local surface = World.surfaceMaterial(x, z, h, slope, weights[ix][iz])
					for j = 1, ny do
						local yBottom = MIN_Y + (j - 1) * RES
						local fill = (h + TerrainGen.Bias - yBottom) / RES
						if fill > 0 then
							matX[j][k] = if fill > 2.5 then M.Rock else surface
							occX[j][k] = math.min(fill, 1)
						elseif yBottom < World.SeaLevel + TerrainGen.Bias then
							matX[j][k] = M.Water
							occX[j][k] = math.min((World.SeaLevel + TerrainGen.Bias - yBottom) / RES, 1)
						else
							matX[j][k] = M.Air
							occX[j][k] = 0
						end
					end
				end
			end
			local minCorner = Vector3.new(-HALF + cx * CHUNK * RES, MIN_Y, -HALF + cz * CHUNK * RES)
			local maxCorner = minCorner + Vector3.new(CHUNK * RES, ny * RES, CHUNK * RES)
			terrain:WriteVoxels(Region3.new(minCorner, maxCorner), RES, materials, occupancy)
			done += 1
			if onProgress then
				onProgress(done / total)
			end
			task.wait()
		end
	end

	-- 3) oceano além das bordas sul (para não ver o "fim do mundo")
	terrain:FillBlock(CFrame.new(0, -10, HALF + 300), Vector3.new(HALF * 2 + 1200, 28, 600), M.Water)
	terrain:FillBlock(CFrame.new(0, -26, HALF + 300), Vector3.new(HALF * 2 + 1200, 4, 600), M.Sand)
end

return TerrainGen
