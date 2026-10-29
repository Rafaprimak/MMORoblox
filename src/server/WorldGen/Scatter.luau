-- Espalha natureza (árvores, pedras, arbustos, flores, ruínas) e pontos de coleta pelo mapa,
-- respeitando biomas, estradas, água e o espaço já ocupado.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared.World)
local Resources = require(Shared.Resources)

local Props = require(script.Parent.Props)
local Placement = require(script.Parent.Placement)

local Scatter = {}

-- Escala do mapa (posições) e tamanho dos objetos em relação ao personagem (escala realista:
-- árvores adultas com 10x a altura do personagem, pedras grandes)
local S = World.Scale
local P = World.PropScale
local TREE_SCALE = 3.0
local ROCK_SCALE = 2.4
local NODE_SCALE = 1.35

local M = Enum.Material
local part = Props.part

local function groundCf(x, z, yaw, sink)
	return CFrame.new(x, World.height(x, z) - (sink or 0), z) * CFrame.Angles(0, yaw or 0, 0)
end

local function dry(x, z, margin)
	return World.height(x, z) > World.SeaLevel + (margin or 1.5)
end

-- ===================== PONTOS DE COLETA =====================

-- def.veins/veinSize: mais veios e maiores; def.sparkle: brilho piscando (ver de longe no meio da grama)
local function oreNode(parent, cf, def, rng)
	local model = Instance.new("Model")
	-- rocha manchada com a cor do minério quando ele precisa aparecer mais (cobre na grama)
	local stain = if def.sparkle then 0.18 else 0
	local base = part(model, { Name = "Rocha", Size = Vector3.new(4, 3, 3.6), CFrame = cf * CFrame.new(0, 1.1, 0) * CFrame.Angles(0, rng:NextNumber() * 3, rng:NextNumber(-0.2, 0.2)), Color = Color3.fromRGB(110, 106, 102):Lerp(def.color, stain), Material = M.Rock })
	part(model, { Name = "Rocha", Size = Vector3.new(2.6, 2, 2.4), CFrame = cf * CFrame.new(1.6, 0.7, 1) * CFrame.Angles(0.3, rng:NextNumber() * 3, 0.2), Color = Color3.fromRGB(100, 96, 92):Lerp(def.color, stain), Material = M.Rock })
	local veinSize = def.veinSize or 1
	for i = 1, def.veins or 4 do
		local crystal = part(model, {
			Name = "Veio",
			Size = Vector3.new(0.8 * veinSize, rng:NextNumber(1.2, 2) * veinSize, 0.8 * veinSize),
			CFrame = cf * CFrame.new(rng:NextNumber(-1.4, 1.4), 2.2 + rng:NextNumber(0, 0.6), rng:NextNumber(-1.2, 1.2)) * CFrame.Angles(rng:NextNumber(-0.6, 0.6), rng:NextNumber() * 3, rng:NextNumber(-0.6, 0.6)),
			Color = def.color,
			Material = if def.glow then M.Neon else M.Metal,
			CanCollide = false,
		})
		crystal:SetAttribute("Harvestable", true)
		if i == 1 and def.glow then
			Props.light(crystal, def.color, 10, 1)
		end
		if i == 1 and def.sparkle then
			-- faíscas na cor do minério (o ResourceService desliga ao minerar)
			local sparkle = Instance.new("ParticleEmitter")
			sparkle.Name = "Brilho"
			sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			sparkle.Color = ColorSequence.new(def.color:Lerp(Color3.new(1, 1, 1), 0.35))
			sparkle.LightEmission = 1
			sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.7), NumberSequenceKeypoint.new(1, 0) })
			sparkle.Lifetime = NumberRange.new(0.6, 1)
			sparkle.Rate = 4
			sparkle.Speed = NumberRange.new(0.5, 1.5)
			sparkle.SpreadAngle = Vector2.new(180, 180)
			sparkle.Parent = crystal
		end
	end
	return model, base
end

local function herbNode(parent, cf, def, rng, kind)
	local model = Instance.new("Model")
	local base = part(model, { Name = "Terra", Size = Vector3.new(2.2, 0.4, 2.2), CFrame = cf * CFrame.new(0, 0.1, 0), Color = Color3.fromRGB(90, 70, 50), Material = M.Ground, CanCollide = false })
	if kind == "erva" then
		for i = 1, 6 do
			local blade = part(model, { Name = "Folha", Size = Vector3.new(0.3, 1.6, 0.1), CFrame = cf * CFrame.Angles(0, i, 0) * CFrame.new(0, 0.8, -0.3) * CFrame.Angles(math.rad(-25), 0, 0), Color = def.color:Lerp(Color3.fromRGB(40, 120, 40), rng:NextNumber() * 0.4), CanCollide = false })
			blade:SetAttribute("Harvestable", true)
		end
	elseif kind == "cogumelo" then
		for i = 1, 3 do
			local offset = Vector3.new(rng:NextNumber(-0.7, 0.7), 0, rng:NextNumber(-0.7, 0.7))
			local h = rng:NextNumber(0.8, 1.4)
			local stem = part(model, { Name = "Talo", Size = Vector3.new(0.35, h, 0.35), CFrame = cf * CFrame.new(offset + Vector3.new(0, h / 2, 0)), Color = Color3.fromRGB(235, 230, 215), CanCollide = false })
			local cap = Props.ball(model, (cf * CFrame.new(offset + Vector3.new(0, h, 0))).Position, 1.1, def.color, M.Neon, { CanCollide = false })
			stem:SetAttribute("Harvestable", true)
			cap:SetAttribute("Harvestable", true)
			if i == 1 then
				Props.light(cap, def.color, 8, 0.8)
			end
		end
	else -- flor lunar
		local stem = part(model, { Name = "Talo", Size = Vector3.new(0.2, 1.6, 0.2), CFrame = cf * CFrame.new(0, 0.8, 0), Color = Color3.fromRGB(60, 140, 80), CanCollide = false })
		stem:SetAttribute("Harvestable", true)
		for i = 1, 5 do
			local petal = part(model, { Name = "Petala", Size = Vector3.new(0.5, 0.12, 0.9), CFrame = cf * CFrame.new(0, 1.65, 0) * CFrame.Angles(0, i * math.pi * 2 / 5, 0) * CFrame.new(0, 0, -0.4) * CFrame.Angles(math.rad(25), 0, 0), Color = def.color, Material = M.Neon, CanCollide = false })
			petal:SetAttribute("Harvestable", true)
		end
		local glowPart = model:FindFirstChild("Petala")
		if glowPart then
			Props.light(glowPart, def.color, 10, 1.2)
		end
	end
	return model, base
end

local function treeNode(parent, cf, def, rng, ancient)
	local model = Instance.new("Model")
	local trunkHeight = if ancient then 9 else 7
	local diameter = if ancient then 3 else 2
	local trunkColor = if ancient then Color3.fromRGB(80, 60, 70) else Props.Colors.Wood
	local trunk = Props.column(model, cf * CFrame.new(0, -0.5, 0), trunkHeight + 0.5, diameter, trunkColor, M.Wood)
	trunk.Name = "Tronco"
	local leaves = if ancient then Color3.fromRGB(130, 80, 170) else Color3.fromRGB(80, 150, 60)
	local top = cf * CFrame.new(0, trunkHeight, 0)
	local size = if ancient then 13 else 9
	local crown = Props.ball(model, top.Position + Vector3.new(0, 2.5, 0), size, leaves, M.Grass, { CanCollide = false })
	crown:SetAttribute("Harvestable", true)
	for i = 1, 3 do
		local a = i * 2.1
		local blob = Props.ball(model, top.Position + Vector3.new(math.cos(a) * size * 0.35, 1, math.sin(a) * size * 0.35), size * 0.65, leaves:Lerp(Color3.new(0, 0, 0), 0.1), M.Grass, { CanCollide = false })
		blob:SetAttribute("Harvestable", true)
	end
	-- fita amarela: indica que a árvore pode ser cortada
	local ribbon = Props.column(model, cf * CFrame.new(0, 3, 0), 0.6, diameter + 0.2, Color3.fromRGB(255, 220, 60), M.Neon, { CanCollide = false })
	ribbon:SetAttribute("Harvestable", true)
	if ancient then
		local glow = Props.ball(model, top.Position + Vector3.new(0, 1, 0), 1.6, Color3.fromRGB(220, 160, 255), M.Neon, { CanCollide = false })
		glow:SetAttribute("Harvestable", true)
		Props.light(glow, Color3.fromRGB(200, 140, 255), 14, 1.2)
	end
	return model, trunk
end

local function buildNode(parent, nodeType, x, z, rng)
	local def = Resources.Nodes[nodeType]
	local cf = groundCf(x, z, rng:NextNumber() * 6, 0.3)
	local model, prompted
	if nodeType == "cobre" or nodeType == "ferro" or nodeType == "mitril" then
		model, prompted = oreNode(parent, cf, def, rng)
	elseif nodeType == "erva" or nodeType == "cogumelo" or nodeType == "flor_lunar" then
		model, prompted = herbNode(parent, cf, def, rng, nodeType)
	else
		model, prompted = treeNode(parent, cf, def, rng, nodeType == "arvore_antiga")
	end
	model.Name = def.name
	model.PrimaryPart = prompted
	model:SetAttribute("NodeType", nodeType)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ResourcePrompt"
	prompt.ActionText = def.action
	prompt.ObjectText = ("%s (Nv. %d)"):format(def.name, def.level)
	prompt.HoldDuration = def.hold
	prompt.MaxActivationDistance = 15
	prompt.RequiresLineOfSight = false
	prompt.Parent = prompted
	CollectionService:AddTag(model, "ResourceNode")
	Props.scaleModel(model, cf, NODE_SCALE)
	model.Parent = parent
	return model
end

-- Regras de onde cada recurso aparece
local NODE_RULES = {
	{ type = "cobre", count = 140, radius = 4, test = function(w, x, z)
		return w.forest < 0.4 and w.ruins < 0.6 and w.mountain < 0.2 and w.town < 0.05 and w.ocean < 0.05 and w.lake < 0.1
	end },
	{ type = "ferro", count = 64, radius = 4, test = function(w)
		return w.ruins > 0.45 and w.mountain < 0.4
	end },
	{ type = "ferro", count = 8, radius = 4, test = function(_w, x, z)
		local loc = World.Locations.mina
		local d = math.sqrt((x - loc.x) ^ 2 + (z - loc.z) ^ 2)
		return d > 14 * S and d < 40 * S
	end },
	{ type = "mitril", count = 28, radius = 4, test = function(w, _x, z)
		return w.corridor > 0.25 and z < -250 * S and z > -400 * S
	end },
	{ type = "erva", count = 170, radius = 2.5, test = function(w)
		return w.forest < 0.7 and w.ruins < 0.5 and w.mountain < 0.2 and w.town < 0.1 and w.ocean < 0.05 and w.lake < 0.2
	end },
	{ type = "cogumelo", count = 90, radius = 2.5, test = function(w)
		return w.forest > 0.5 and w.mountain < 0.4
	end },
	{ type = "flor_lunar", count = 48, radius = 2.5, test = function(w)
		return w.ruins > 0.5 and w.mountain < 0.4
	end },
	{ type = "arvore", count = 120, radius = 6, test = function(w)
		return w.town < 0.05 and w.ocean < 0.05 and w.mountain < 0.3 and w.ruins < 0.4 and w.lake < 0.1
	end },
	{ type = "arvore_antiga", count = 40, radius = 8, test = function(w)
		return w.forest > 0.65 and w.mountain < 0.3
	end },
}

function Scatter.resources(parent, rng)
	local folder = Instance.new("Folder")
	folder.Name = "Recursos"
	folder.Parent = parent
	for _, rule in NODE_RULES do
		local placed, attempts = 0, 0
		while placed < rule.count and attempts < rule.count * 80 do
			attempts += 1
			local x = rng:NextNumber(-470, 470) * S
			local z = rng:NextNumber(-470, 330) * S
			if rule.type == "ferro" and rule.count == 8 then
				local loc = World.Locations.mina
				x = loc.x + rng:NextNumber(-40, 40) * S
				z = loc.z + rng:NextNumber(-40, 40) * S
			end
			local w = World.weights(x, z)
			local radius = rule.radius * NODE_SCALE
			if rule.test(w, x, z) and dry(x, z, 2) and Placement.slope(x, z) < 0.7 and Placement.canPlace(x, z, radius, 3) then
				buildNode(folder, rule.type, x, z, rng)
				Placement.reserve(x, z, radius, rule.type)
				placed += 1
			end
		end
	end
	return folder
end

-- ===================== NATUREZA =====================

local function ruinPiece(parent, cf, rng)
	local model = Instance.new("Model")
	model.Name = "Ruina"
	local stone = Color3.fromRGB(150, 145, 130)
	if rng:NextNumber() < 0.5 then
		local h = rng:NextNumber(3, 9)
		part(model, { Name = "Coluna", Size = Vector3.new(2.2, h, 2.2), CFrame = cf * CFrame.new(0, h / 2 - 0.5, 0), Color = stone, Material = M.Marble })
		if rng:NextNumber() < 0.5 then
			part(model, { Name = "Pedaco", Size = Vector3.new(2.2, 3.5, 2.2), CFrame = cf * CFrame.new(2.8, 1, 0) * CFrame.Angles(0, rng:NextNumber() * 3, math.rad(90)), Color = stone, Material = M.Marble })
		end
	else
		local w = rng:NextNumber(6, 12)
		local h = rng:NextNumber(2.5, 6)
		part(model, { Name = "Muro", Size = Vector3.new(w, h, 1.6), CFrame = cf * CFrame.new(0, h / 2 - 0.5, 0), Color = stone:Lerp(Color3.new(0, 0, 0), 0.15), Material = M.Brick })
		part(model, { Name = "Muro", Size = Vector3.new(w * 0.5, h * 0.5, 1.6), CFrame = cf * CFrame.new(w * 0.2, h + h * 0.25 - 0.5, 0), Color = stone:Lerp(Color3.new(0, 0, 0), 0.15), Material = M.Brick })
	end
	model.Parent = parent
	return model
end

-- Sub-bosque (peças simples, embaixo das copas): tronco caído, toco com cogumelos, samambaia
local function fallenLog(parent, cf, scale, rng)
	local model = Instance.new("Model")
	model.Name = "TroncoCaido"
	local length = rng:NextNumber(7, 12) * scale
	local diameter = rng:NextNumber(1.4, 2.2) * scale
	local bark = Props.Colors.Wood:Lerp(Props.Colors.DarkWood, rng:NextNumber(0.3, 0.8))
	part(model, { Name = "Tronco", Shape = Enum.PartType.Cylinder, Size = Vector3.new(length, diameter, diameter), CFrame = cf * CFrame.new(0, diameter * 0.35, 0) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-4, 4))), Color = bark, Material = M.Wood })
	part(model, { Name = "Musgo", Size = Vector3.new(length * 0.6, 0.2, diameter * 0.7), CFrame = cf * CFrame.new(rng:NextNumber(-1, 1) * scale, diameter * 0.83, 0), Color = Color3.fromRGB(80, 125, 60), Material = M.Grass, CanCollide = false })
	for _, side in { -1, 1 } do
		if rng:NextNumber() < 0.6 then
			part(model, { Name = "Galho", Size = Vector3.new(0.35, 0.35, 2.4) * scale, CFrame = cf * CFrame.new(side * length * 0.25, diameter * 0.6, diameter * 0.6) * CFrame.Angles(math.rad(-30), rng:NextNumber(-0.6, 0.6), 0), Color = bark, Material = M.Wood, CanCollide = false })
		end
	end
	model.Parent = parent
	return model
end

local function stump(parent, cf, scale, rng)
	local model = Instance.new("Model")
	model.Name = "Toco"
	local diameter = rng:NextNumber(1.8, 2.8) * scale
	local height = rng:NextNumber(0.9, 1.6) * scale
	Props.column(model, cf * CFrame.new(0, -0.3, 0), height + 0.3, diameter, Props.Colors.Wood:Lerp(Props.Colors.DarkWood, 0.5), M.Wood)
	Props.column(model, cf * CFrame.new(0, height, 0), 0.08, diameter * 0.8, Color3.fromRGB(190, 150, 100), M.Wood, { CanCollide = false })
	for _ = 1, rng:NextInteger(1, 3) do
		local a = rng:NextNumber() * math.pi * 2
		local spot = cf * CFrame.new(math.cos(a) * diameter * 0.6, 0, math.sin(a) * diameter * 0.6)
		Props.column(model, spot, 0.45 * scale, 0.18 * scale, Color3.fromRGB(235, 225, 205), M.SmoothPlastic, { CanCollide = false })
		Props.column(model, spot * CFrame.new(0, 0.45 * scale, 0), 0.18 * scale, 0.6 * scale, Color3.fromRGB(200, 60, 50), M.SmoothPlastic, { CanCollide = false })
	end
	model.Parent = parent
	return model
end

local function fern(parent, cf, scale, rng)
	local model = Instance.new("Model")
	model.Name = "Samambaia"
	local green = Color3.fromRGB(55, 115, 50):Lerp(Color3.fromRGB(95, 150, 60), rng:NextNumber())
	local fronds = rng:NextInteger(5, 7)
	for i = 1, fronds do
		local a = i / fronds * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		part(model, { Name = "Folha", Size = Vector3.new(0.6, 0.1, 2.6) * scale, CFrame = cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.55 * scale, -1.1 * scale) * CFrame.Angles(math.rad(28), 0, 0), Color = green, Material = M.Grass, CanCollide = false })
	end
	model.Parent = parent
	return model
end

-- Floresta em camadas, para dar profundidade:
--   * árvores adultas enormes (reservam só o tronco: a copa fica lá em cima e o sub-bosque cresce embaixo);
--   * árvores jovens entre elas;
--   * sub-bosque: arbustos, samambaias, troncos caídos, tocos com cogumelos;
--   * densidade por ruído: miolo fechado, bordas ralas e clareiras (com flores);
-- Fora das florestas: bosques nos campos, pinheiros nas montanhas, palmeiras na praia, árvores secas nas ruínas.
function Scatter.nature(parent, rng)
	local folder = Instance.new("Folder")
	folder.Name = "Natureza"
	folder.Parent = parent
	local budget = { tree = 2600, young = 1500, rock = 1100, bush = 2200, under = 1500, flowers = 900, ruin = 160 }
	local counts = { tree = 0, young = 0, rock = 0, bush = 0, under = 0, flowers = 0, ruin = 0 }

	for attempt = 1, 150000 do
		local x = rng:NextNumber(-500, 500) * S
		local z = rng:NextNumber(-500, 360) * S
		local w = World.weights(x, z)
		local h = World.heightWithWeights(x, z, w)
		if h > World.SeaLevel + 1 and w.town < 0.2 and w.crater < 0.25 then
			local dh = World.designHeight(h)
			local plains = (1 - w.forest) * (1 - w.ruins) * (1 - w.mountain) * (1 - w.ocean)
			local grove = World.fbm(x, z, 2, 110, 999) > 0.12
			local beach = w.ocean > 0.06 and dh < World.SeaLevel + 7
			-- densidade da floresta: -1 (clareira) a 1 (mata fechada)
			local density = World.fbm(x, z, 3, 55, 4343)
			local clearing = w.forest > 0.5 and density < -0.32
			local thick = w.forest * World.smoothstep(-0.3, 0.35, density)
			local treeChance = (if clearing then 0 else 0.1 + thick * 0.45) * w.forest + plains * (if grove then 0.22 else 0.012) + w.mountain * (if dh < 140 then 0.12 else 0) + w.ruins * 0.05 + (if beach then 0.05 else 0)
			local youngChance = (if clearing then 0.015 else 0.06 + thick * 0.2) * w.forest + plains * (if grove then 0.07 else 0.004)
			local underChance = (if clearing then 0.03 else 0.1 + thick * 0.22) * w.forest + w.ruins * 0.01
			local bushChance = w.forest * (if clearing then 0.06 else 0.18) + plains * 0.05
			local rockChance = 0.02 + w.ruins * 0.06 + w.mountain * 0.09 + w.forest * 0.015
			local flowerChance = plains * 0.05 + w.lake * 0.1 + (if clearing then 0.3 else 0)
			local ruinChance = w.ruins * 0.02
			local chances = {
				{ "tree", treeChance }, { "young", youngChance }, { "under", underChance }, { "bush", bushChance },
				{ "rock", rockChance }, { "flowers", flowerChance }, { "ruin", ruinChance },
			}
			local roll = rng:NextNumber()
			local kind = nil
			for _, entry in chances do
				if roll < entry[2] then
					kind = entry[1]
					break
				end
				roll -= entry[2]
			end
			if kind and counts[kind] < budget[kind] then
				local scale = rng:NextNumber(0.8, 1.3)
				-- raio reservado: árvores só o tronco (copas se cruzam, como numa floresta de verdade)
				local radius = if kind == "tree" then 2.6 * TREE_SCALE * scale
					elseif kind == "young" then 1.4 * TREE_SCALE * scale
					elseif kind == "rock" then 3.5 * ROCK_SCALE
					elseif kind == "ruin" then 6 * P * 1.8
					elseif kind == "under" then 3.5 * P
					else 2.5
				local slope = Placement.slope(x, z)
				local slopeLimit = if kind == "rock" then 2 else 0.8
				if slope < slopeLimit and Placement.canPlace(x, z, radius, if kind == "flowers" or kind == "under" then 1 else 3) then
					local cf = groundCf(x, z, rng:NextNumber() * math.pi * 2, if kind == "rock" then 0.6 else 0.2)
					if kind == "tree" or kind == "young" then
						scale *= TREE_SCALE * (if kind == "young" then 0.45 else 1)
						if beach then
							Props.palm(folder, cf, scale, rng)
						elseif w.mountain > 0.4 then
							Props.pine(folder, cf, scale * 1.1, rng, dh > 110)
						elseif w.ruins > 0.5 and rng:NextNumber() < 0.6 then
							Props.deadTree(folder, cf, scale, rng)
						elseif w.forest > 0.5 and rng:NextNumber() < 0.4 then
							-- no miolo da mata as árvores são as mais altas
							Props.pine(folder, cf, scale * (1.15 + thick * 0.35), rng, false)
						else
							Props.oak(folder, cf, scale * (if w.forest > 0.5 then 1.15 + thick * 0.3 else 1), rng)
						end
					elseif kind == "under" then
						local pick = rng:NextNumber()
						if pick < 0.45 then
							Props.scaleModel(fern(folder, cf, 1, rng), cf, P * rng:NextNumber(0.9, 1.4))
						elseif pick < 0.75 then
							Props.scaleModel(fallenLog(folder, cf, 1, rng), cf, P * rng:NextNumber(0.9, 1.3))
						else
							Props.scaleModel(stump(folder, cf, 1, rng), cf, P * rng:NextNumber(0.9, 1.3))
						end
					elseif kind == "rock" then
						Props.rock(folder, cf, scale * ROCK_SCALE * (if w.mountain > 0.5 then 1.8 else 1), rng)
					elseif kind == "bush" then
						Props.bush(folder, cf, scale * ROCK_SCALE * (if w.forest > 0.5 then 1.2 else 1), rng)
					elseif kind == "flowers" then
						Props.scaleModel(Props.flowers(folder, cf, rng), cf, 1.6)
					else
						Props.scaleModel(ruinPiece(folder, cf, rng), cf, P * 1.8)
					end
					Placement.reserve(x, z, radius, kind)
					counts[kind] += 1
				end
			end
		end
		if attempt % 400 == 0 then
			task.wait()
		end
	end
	return counts
end

return Scatter
