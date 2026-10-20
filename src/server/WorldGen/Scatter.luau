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

local M = Enum.Material
local part = Props.part

local function groundCf(x, z, yaw, sink)
	return CFrame.new(x, World.height(x, z) - (sink or 0), z) * CFrame.Angles(0, yaw or 0, 0)
end

local function dry(x, z, margin)
	return World.height(x, z) > World.SeaLevel + (margin or 1.5)
end

-- ===================== PONTOS DE COLETA =====================

local function oreNode(parent, cf, def, rng)
	local model = Instance.new("Model")
	local base = part(model, { Name = "Rocha", Size = Vector3.new(4, 3, 3.6), CFrame = cf * CFrame.new(0, 1.1, 0) * CFrame.Angles(0, rng:NextNumber() * 3, rng:NextNumber(-0.2, 0.2)), Color = Color3.fromRGB(110, 106, 102), Material = M.Rock })
	part(model, { Name = "Rocha", Size = Vector3.new(2.6, 2, 2.4), CFrame = cf * CFrame.new(1.6, 0.7, 1) * CFrame.Angles(0.3, rng:NextNumber() * 3, 0.2), Color = Color3.fromRGB(100, 96, 92), Material = M.Rock })
	for i = 1, 4 do
		local crystal = part(model, {
			Name = "Veio",
			Size = Vector3.new(0.8, rng:NextNumber(1.2, 2), 0.8),
			CFrame = cf * CFrame.new(rng:NextNumber(-1.4, 1.4), 2.2 + rng:NextNumber(0, 0.6), rng:NextNumber(-1.2, 1.2)) * CFrame.Angles(rng:NextNumber(-0.6, 0.6), rng:NextNumber() * 3, rng:NextNumber(-0.6, 0.6)),
			Color = def.color,
			Material = if def.glow then M.Neon else M.Metal,
			CanCollide = false,
		})
		crystal:SetAttribute("Harvestable", true)
		if i == 1 and def.glow then
			Props.light(crystal, def.color, 10, 1)
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
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	prompt.Parent = prompted
	CollectionService:AddTag(model, "ResourceNode")
	model.Parent = parent
	return model
end

-- Regras de onde cada recurso aparece
local NODE_RULES = {
	{ type = "cobre", count = 45, radius = 4, test = function(w, x, z)
		return w.forest < 0.4 and w.ruins < 0.6 and w.mountain < 0.2 and w.town < 0.05 and w.ocean < 0.05 and w.lake < 0.1
	end },
	{ type = "ferro", count = 22, radius = 4, test = function(w)
		return w.ruins > 0.45 and w.mountain < 0.4
	end },
	{ type = "ferro", count = 8, radius = 4, test = function(_w, x, z)
		local loc = World.Locations.mina
		local d = math.sqrt((x - loc.x) ^ 2 + (z - loc.z) ^ 2)
		return d > 14 and d < 40
	end },
	{ type = "mitril", count = 10, radius = 4, test = function(w, _x, z)
		return w.corridor > 0.25 and z < -250 and z > -400
	end },
	{ type = "erva", count = 55, radius = 2.5, test = function(w)
		return w.forest < 0.7 and w.ruins < 0.5 and w.mountain < 0.2 and w.town < 0.1 and w.ocean < 0.05 and w.lake < 0.2
	end },
	{ type = "cogumelo", count = 30, radius = 2.5, test = function(w)
		return w.forest > 0.5 and w.mountain < 0.4
	end },
	{ type = "flor_lunar", count = 16, radius = 2.5, test = function(w)
		return w.ruins > 0.5 and w.mountain < 0.4
	end },
	{ type = "arvore", count = 40, radius = 6, test = function(w)
		return w.town < 0.05 and w.ocean < 0.05 and w.mountain < 0.3 and w.ruins < 0.4 and w.lake < 0.1
	end },
	{ type = "arvore_antiga", count = 14, radius = 8, test = function(w)
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
			local x = rng:NextNumber(-470, 470)
			local z = rng:NextNumber(-470, 330)
			if rule.type == "ferro" and rule.count == 8 then
				local loc = World.Locations.mina
				x = loc.x + rng:NextNumber(-40, 40)
				z = loc.z + rng:NextNumber(-40, 40)
			end
			local w = World.weights(x, z)
			if rule.test(w, x, z) and dry(x, z, 2) and Placement.slope(x, z) < 0.7 and Placement.canPlace(x, z, rule.radius, 3) then
				buildNode(folder, rule.type, x, z, rng)
				Placement.reserve(x, z, rule.radius, rule.type)
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

function Scatter.nature(parent, rng)
	local folder = Instance.new("Folder")
	folder.Name = "Natureza"
	folder.Parent = parent
	local budget = { tree = 750, rock = 320, bush = 380, flowers = 220, ruin = 45 }
	local counts = { tree = 0, rock = 0, bush = 0, flowers = 0, ruin = 0 }

	for attempt = 1, 16000 do
		local x = rng:NextNumber(-500, 500)
		local z = rng:NextNumber(-500, 360)
		local w = World.weights(x, z)
		local h = World.heightWithWeights(x, z, w)
		if h > World.SeaLevel + 1 and w.town < 0.2 and w.crater < 0.25 then
			local plains = (1 - w.forest) * (1 - w.ruins) * (1 - w.mountain) * (1 - w.ocean)
			local grove = World.fbm(x, z, 2, 110, 999) > 0.12
			local beach = w.ocean > 0.06 and h < World.SeaLevel + 7
			local treeChance = w.forest * 0.6 + plains * (if grove then 0.3 else 0.015) + w.mountain * (if h < 120 then 0.12 else 0) + w.ruins * 0.05 + (if beach then 0.05 else 0)
			local rockChance = 0.02 + w.ruins * 0.06 + w.mountain * 0.09
			local bushChance = w.forest * 0.12 + plains * 0.05
			local flowerChance = plains * 0.05 + w.lake * 0.1
			local ruinChance = w.ruins * 0.02
			local roll = rng:NextNumber()
			local kind = nil
			if roll < treeChance then
				kind = "tree"
			elseif roll < treeChance + rockChance then
				kind = "rock"
			elseif roll < treeChance + rockChance + bushChance then
				kind = "bush"
			elseif roll < treeChance + rockChance + bushChance + flowerChance then
				kind = "flowers"
			elseif roll < treeChance + rockChance + bushChance + flowerChance + ruinChance then
				kind = "ruin"
			end
			if kind and counts[kind] < budget[kind] then
				local radius = if kind == "tree" then 5 elseif kind == "rock" then 3.5 elseif kind == "ruin" then 6 else 2
				local slope = Placement.slope(x, z)
				local slopeLimit = if kind == "rock" then 2 else 0.8
				if slope < slopeLimit and Placement.canPlace(x, z, radius, if kind == "flowers" then 1 else 3) then
					local cf = groundCf(x, z, rng:NextNumber() * math.pi * 2, if kind == "rock" then 0.6 else 0.2)
					local scale = rng:NextNumber(0.8, 1.3)
					if kind == "tree" then
						if beach then
							Props.palm(folder, cf, scale, rng)
						elseif w.mountain > 0.4 then
							Props.pine(folder, cf, scale * 1.1, rng, h > 95)
						elseif w.ruins > 0.5 and rng:NextNumber() < 0.6 then
							Props.deadTree(folder, cf, scale, rng)
						elseif w.forest > 0.5 and rng:NextNumber() < 0.45 then
							Props.pine(folder, cf, scale * 1.2, rng, false)
						else
							Props.oak(folder, cf, scale * (if w.forest > 0.5 then 1.25 else 1), rng)
						end
					elseif kind == "rock" then
						Props.rock(folder, cf, scale * (if w.mountain > 0.5 then 1.8 else 1), rng)
					elseif kind == "bush" then
						Props.bush(folder, cf, scale, rng)
					elseif kind == "flowers" then
						Props.flowers(folder, cf, rng)
					else
						ruinPiece(folder, cf, rng)
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
