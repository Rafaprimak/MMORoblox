-- Constrói os locais de interesse (módulo Points): cada um tem cenário próprio e um baú escondido.
-- Montados em tamanho de projeto em volta do ponto no chão e ampliados por World.Scale.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared.World)
local Points = require(Shared.Points)

local Props = require(script.Parent.Props)
local Placement = require(script.Parent.Placement)

local PointsOfInterest = {}

local M = Enum.Material
local C = Props.Colors
local part = Props.part
local S = World.Scale

local STONE = Color3.fromRGB(150, 145, 135)
local OLD_STONE = Color3.fromRGB(120, 118, 110)
local MOSS = Color3.fromRGB(85, 125, 60)

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include

local function groundAt(x, z)
	rayParams.FilterDescendantsInstances = { workspace.Terrain }
	local result = workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -600, 0), rayParams)
	return if result then result.Position.Y else World.height(x, z)
end

-- Baú escondido do local (o prompt é tratado pelo ExploreService)
local function treasureChest(model, cf, poi)
	local chest = Instance.new("Model")
	chest.Name = "BauEscondido"
	local body = part(chest, { Name = "Corpo", Size = Vector3.new(2.4, 1.5, 1.6), CFrame = cf * CFrame.new(0, 0.75, 0), Color = C.DarkWood, Material = M.Wood })
	part(chest, { Name = "Tampa", Size = Vector3.new(2.5, 0.7, 1.7), CFrame = cf * CFrame.new(0, 1.8, 0), Color = C.Wood, Material = M.Wood })
	for _, x in { -0.9, 0.9 } do
		part(chest, { Name = "Cinta", Size = Vector3.new(0.25, 2.3, 1.75), CFrame = cf * CFrame.new(x, 1.1, 0), Color = C.Gold, Material = M.Metal })
	end
	part(chest, { Name = "Fecho", Size = Vector3.new(0.4, 0.5, 0.15), CFrame = cf * CFrame.new(0, 1.4, -0.85), Color = C.Gold, Material = M.Metal })
	local glow = Instance.new("ParticleEmitter")
	glow.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120))
	glow.LightEmission = 1
	glow.Size = NumberSequence.new(0.25, 0)
	glow.Lifetime = NumberRange.new(0.8, 1.4)
	glow.Rate = 4
	glow.Speed = NumberRange.new(0.5, 1.2)
	glow.SpreadAngle = Vector2.new(60, 60)
	glow.Parent = body
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BauLocal"
	prompt.ActionText = "Abrir baú"
	prompt.ObjectText = poi.name
	prompt.HoldDuration = 0.6
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("PoiId", poi.id)
	prompt.Parent = body
	chest.Parent = model
	return chest
end

local builders = {}

-- Moinho com plantação cercada (pás giram)
function builders.windmill(model, cf, rng)
	Props.column(model, cf * CFrame.new(0, -0.5, 0), 3, 10, STONE, M.Cobblestone)
	for i = 0, 4 do
		Props.column(model, cf * CFrame.new(0, 2.5 + i * 3, 0), 3, 8.6 - i * 0.6, Color3.fromRGB(230, 220, 200), M.Plaster)
	end
	part(model, { Name = "Porta", Size = Vector3.new(2.4, 4.2, 0.6), CFrame = cf * CFrame.new(0, 4.6, -4.3), Color = C.DarkWood, Material = M.Wood })
	Props.roof(model, cf * CFrame.new(0, 17.5, 0), 7, 7, 40, Color3.fromRGB(130, 60, 45))
	local hub = cf * CFrame.new(0, 15, -4.6)
	part(model, { Name = "Eixo", Size = Vector3.new(1, 1, 1.6), CFrame = hub, Color = C.DarkWood, Material = M.Wood })
	-- duas pás cruzadas giram juntas em volta do eixo (o eixo Y local de cada pá aponta para frente)
	for _, size in { Vector3.new(18, 0.3, 2.2), Vector3.new(2.2, 0.3, 18) } do
		local blade = part(model, { Name = "Pa", Size = size, CFrame = hub * CFrame.new(0, 0, -1) * CFrame.Angles(math.rad(90), 0, 0), Color = Color3.fromRGB(235, 225, 205), Material = M.Fabric, CanCollide = false })
		CollectionService:AddTag(blade, "Spin")
	end
	-- plantação de trigo e abóboras com cerca
	local field = cf * CFrame.new(16, 0, 4)
	for row = 0, 5 do
		for i = 0, 6 do
			local p = field * CFrame.new(-6 + i * 2, 0, -6 + row * 2.4)
			if row % 3 == 2 then
				Props.ball(model, (p * CFrame.new(0, 0.6, 0)).Position, 1.2, Color3.fromRGB(240, 140, 40), M.SmoothPlastic, { CanCollide = false })
			else
				part(model, { Name = "Trigo", Size = Vector3.new(1.2, 1.6 + rng:NextNumber() * 0.5, 1.2), CFrame = p * CFrame.new(0, 0.8, 0), Color = Color3.fromRGB(225, 195, 90), Material = M.Grass, CanCollide = false })
			end
		end
	end
	local corners = { (field * CFrame.new(-8, 0, -8)).Position, (field * CFrame.new(8, 0, -8)).Position, (field * CFrame.new(8, 0, 8)).Position, (field * CFrame.new(-8, 0, 8)).Position }
	for i = 1, 4 do
		Props.fence(model, corners[i], corners[i % 4 + 1], 2.4)
	end
	-- espantalho
	local crow = field * CFrame.new(0, 0, 0)
	part(model, { Name = "Poste", Size = Vector3.new(0.3, 5, 0.3), CFrame = crow * CFrame.new(0, 2.5, 0), Color = C.DarkWood, Material = M.Wood })
	part(model, { Name = "Bracos", Size = Vector3.new(3.4, 0.3, 0.3), CFrame = crow * CFrame.new(0, 3.8, 0), Color = C.DarkWood, Material = M.Wood })
	part(model, { Name = "Roupa", Size = Vector3.new(1.4, 1.6, 0.7), CFrame = crow * CFrame.new(0, 3.4, 0), Color = Color3.fromRGB(160, 80, 60), Material = M.Fabric })
	part(model, { Name = "Cabeca", Size = Vector3.new(1, 1, 1), CFrame = crow * CFrame.new(0, 4.7, 0), Color = Color3.fromRGB(220, 190, 110), Material = M.Fabric })
	Props.ball(model, (crow * CFrame.new(0, 5.5, 0)).Position, 1.6, Color3.fromRGB(200, 170, 90), M.Fabric, { CanCollide = false })
	Props.cart(model, cf * CFrame.new(-9, 0, 5) * CFrame.Angles(0, math.rad(30), 0))
	return cf * CFrame.new(-4, 0, -6)
end

-- Círculo de pedras com altar e runa que brilha
function builders.stonecircle(model, cf, rng)
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2
		local stone = cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -10)
		local height = rng:NextNumber(6, 8.5)
		if i ~= 3 then
			part(model, { Name = "Menir", Size = Vector3.new(2.2, height, 1.4), CFrame = stone * CFrame.new(0, height / 2 - 0.4, 0) * CFrame.Angles(rng:NextNumber(-0.05, 0.05), 0, rng:NextNumber(-0.06, 0.06)), Color = OLD_STONE:Lerp(Color3.new(0, 0, 0), rng:NextNumber() * 0.15), Material = M.Slate })
			part(model, { Name = "Musgo", Size = Vector3.new(2.3, 0.8, 1.5), CFrame = stone * CFrame.new(0, height - 0.6, 0), Color = MOSS, Material = M.Grass, CanCollide = false })
			if i % 2 == 0 and i ~= 2 then
				local next = cf * CFrame.Angles(0, a + math.pi * 2 / 10, 0) * CFrame.new(0, 0, -10)
				local mid = (stone.Position + next.Position) / 2
				part(model, { Name = "Lintel", Size = Vector3.new(1.2, 1, (next.Position - stone.Position).Magnitude + 1.6), CFrame = CFrame.lookAt(mid + Vector3.new(0, height, 0), next.Position + Vector3.new(0, height, 0)), Color = OLD_STONE, Material = M.Slate })
			end
		else
			-- pedra caída
			part(model, { Name = "Menir", Size = Vector3.new(2.2, 1.4, 7), CFrame = stone * CFrame.new(1.5, 0.5, -1) * CFrame.Angles(0, 0.6, 0), Color = OLD_STONE, Material = M.Slate })
		end
	end
	part(model, { Name = "Altar", Size = Vector3.new(4, 2, 3), CFrame = cf * CFrame.new(0, 1, 0), Color = STONE, Material = M.Slate })
	local rune = part(model, { Name = "Runa", Size = Vector3.new(0.2, 3.6, 3.6), Shape = Enum.PartType.Cylinder, CFrame = cf * CFrame.new(0, 2.05, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(120, 220, 255), Material = M.Neon, Transparency = 0.3, CanCollide = false })
	Props.light(rune, Color3.fromRGB(120, 220, 255), 18, 1.5)
	local crystal = part(model, { Name = "Cristal", Size = Vector3.new(1, 1.8, 1), CFrame = cf * CFrame.new(0, 4.2, 0), Color = Color3.fromRGB(150, 230, 255), Material = M.Neon, CanCollide = false })
	CollectionService:AddTag(crystal, "Spin")
	return cf * CFrame.new(0, 0, 6)
end

-- Torre de vigia de madeira meio desabada
function builders.watchtower(model, cf, rng)
	for _, x in { -3, 3 } do
		for _, z in { -3, 3 } do
			part(model, { Name = "Pilar", Size = Vector3.new(1, 16, 1), CFrame = cf * CFrame.new(x, 8, z) * CFrame.Angles(0, 0, if x > 0 and z > 0 then math.rad(-6) else 0), Color = C.DarkWood, Material = M.Wood })
		end
	end
	for _, y in { 5, 10 } do
		for _, side in { -1, 1 } do
			part(model, { Name = "Travessa", Size = Vector3.new(7, 0.5, 0.5), CFrame = cf * CFrame.new(0, y, side * 3), Color = C.Wood, Material = M.Wood })
			part(model, { Name = "Travessa", Size = Vector3.new(0.5, 0.5, 7), CFrame = cf * CFrame.new(side * 3, y, 0), Color = C.Wood, Material = M.Wood })
		end
	end
	-- plataforma com buraco, parapeito quebrado e telhado caído
	for i = 0, 6 do
		if i ~= 4 then
			part(model, { Name = "Tabua", Size = Vector3.new(7.6, 0.4, 1), CFrame = cf * CFrame.new(0, 16, -3 + i), Color = C.Plank, Material = M.WoodPlanks })
		end
	end
	for _, side in { -1, 1 } do
		part(model, { Name = "Parapeito", Size = Vector3.new(7.6, 1.4, 0.4), CFrame = cf * CFrame.new(0, 17, side * 3.7), Color = C.Wood, Material = M.WoodPlanks })
	end
	Props.roof(model, cf * CFrame.new(0, 20, 0) * CFrame.Angles(0, 0, math.rad(18)), 7, 7, 35, Color3.fromRGB(90, 60, 45))
	-- escada encostada
	for i = 0, 9 do
		part(model, { Name = "Degrau", Size = Vector3.new(2.2, 0.25, 0.4), CFrame = cf * CFrame.new(0, 0.8 + i * 1.6, -4.4 - i * 0.18), Color = C.Wood, Material = M.Wood })
	end
	for _, x in { -1.1, 1.1 } do
		part(model, { Name = "Banzo", Size = Vector3.new(0.3, 16.5, 0.3), CFrame = cf * CFrame.new(x, 8, -5.2) * CFrame.Angles(math.rad(-6), 0, 0), Color = C.DarkWood, Material = M.Wood })
	end
	-- tábuas caídas no chão
	for _ = 1, 5 do
		part(model, { Name = "Tabua", Size = Vector3.new(4, 0.3, 0.9), CFrame = cf * CFrame.new(rng:NextNumber(-6, 6), 0.2, rng:NextNumber(-6, 6)) * CFrame.Angles(0, rng:NextNumber(0, 3), rng:NextNumber(-0.2, 0.2)), Color = C.Plank, Material = M.WoodPlanks })
	end
	Props.campfire(model, cf * CFrame.new(6, 0, 4))
	return cf * CFrame.new(0, 0, 1)
end

-- Estátua gigante de um herói (braço quebrado) com pedestal e oferendas
function builders.statue(model, cf, rng)
	part(model, { Name = "Base", Size = Vector3.new(10, 1.5, 10), CFrame = cf * CFrame.new(0, 0.75, 0), Color = STONE, Material = M.Cobblestone })
	part(model, { Name = "Pedestal", Size = Vector3.new(6, 4, 6), CFrame = cf * CFrame.new(0, 3.5, 0), Color = OLD_STONE, Material = M.Marble })
	part(model, { Name = "Placa", Size = Vector3.new(3, 1.2, 0.2), CFrame = cf * CFrame.new(0, 3.5, -3.05), Color = Color3.fromRGB(150, 120, 60), Material = M.Metal })
	local body = cf * CFrame.new(0, 5.5, 0)
	local marble = Color3.fromRGB(210, 205, 195)
	for _, x in { -0.8, 0.8 } do
		part(model, { Name = "Perna", Size = Vector3.new(1.4, 5, 1.4), CFrame = body * CFrame.new(x, 2.5, 0), Color = marble, Material = M.Marble })
	end
	part(model, { Name = "Torso", Size = Vector3.new(3.6, 4.4, 2), CFrame = body * CFrame.new(0, 7.2, 0), Color = marble, Material = M.Marble })
	part(model, { Name = "Capa", Size = Vector3.new(3.6, 7, 0.4), CFrame = body * CFrame.new(0, 5.8, 1.1) * CFrame.Angles(math.rad(-6), 0, 0), Color = marble:Lerp(Color3.new(0, 0, 0), 0.08), Material = M.Marble })
	part(model, { Name = "Cabeca", Size = Vector3.new(1.8, 1.9, 1.8), CFrame = body * CFrame.new(0, 10.4, 0), Color = marble, Material = M.Marble })
	-- braço direito erguido com espada; o esquerdo quebrou e está no chão
	part(model, { Name = "Braco", Size = Vector3.new(1.1, 4, 1.1), CFrame = body * CFrame.new(2.4, 10.4, 0) * CFrame.Angles(0, 0, math.rad(-15)), Color = marble, Material = M.Marble })
	part(model, { Name = "Espada", Size = Vector3.new(0.5, 7, 0.25), CFrame = body * CFrame.new(3.1, 15.6, 0) * CFrame.Angles(0, 0, math.rad(-15)), Color = Color3.fromRGB(190, 190, 200), Material = M.Metal })
	part(model, { Name = "Guarda", Size = Vector3.new(2, 0.4, 0.5), CFrame = body * CFrame.new(2.6, 12.3, 0) * CFrame.Angles(0, 0, math.rad(-15)), Color = C.Gold, Material = M.Metal })
	part(model, { Name = "BracoQuebrado", Size = Vector3.new(1.1, 3.6, 1.1), CFrame = cf * CFrame.new(-5.5, 0.8, -3) * CFrame.Angles(math.rad(85), 0.4, 0), Color = marble, Material = M.Marble })
	part(model, { Name = "Musgo", Size = Vector3.new(3.7, 0.5, 2.1), CFrame = body * CFrame.new(0, 9.2, 0), Color = MOSS, Material = M.Grass, CanCollide = false })
	-- oferendas: velas e flores
	for i = 0, 5 do
		local spot = cf * CFrame.Angles(0, i, 0) * CFrame.new(0, 1.5, -4.2)
		if i % 2 == 0 then
			local candle = part(model, { Name = "Vela", Size = Vector3.new(0.3, 0.8, 0.3), CFrame = spot * CFrame.new(0, 0.4, 0), Color = Color3.fromRGB(245, 240, 220) })
			local flame = part(model, { Name = "Chama", Size = Vector3.new(0.2, 0.35, 0.2), CFrame = spot * CFrame.new(0, 0.95, 0), Color = C.Fire, Material = M.Neon, CanCollide = false })
			Props.light(flame, C.Fire, 6, 1)
			local _ = candle
		else
			Props.ball(model, (spot * CFrame.new(0, 0.3, 0)).Position, 0.6, Color3.fromHSV(rng:NextNumber(), 0.6, 1), M.SmoothPlastic, { CanCollide = false })
		end
	end
	return cf * CFrame.new(0, 3.5, 2)
end

-- Acampamento abandonado: barracas rasgadas, fogueira apagada, carroça quebrada
function builders.camp(model, cf, rng)
	for i, spot in { { -6, -3, 0.4 }, { 5, -5, -0.6 }, { 0, 6, 3 } } do
		local tent = cf * CFrame.new(spot[1], 0, spot[2]) * CFrame.Angles(0, spot[3], 0)
		local color = if i == 2 then Color3.fromRGB(150, 130, 100) else Color3.fromRGB(170, 150, 110)
		Props.tent(model, tent, color)
	end
	-- fogueira apagada (pedras e lenha queimada)
	for i = 0, 6 do
		local a = i / 7 * math.pi * 2
		part(model, { Name = "Pedra", Size = Vector3.new(0.8, 0.6, 0.8), CFrame = cf * CFrame.new(math.cos(a) * 1.6, 0.3, math.sin(a) * 1.6), Color = OLD_STONE, Material = M.Slate })
	end
	for i = 0, 2 do
		part(model, { Name = "Brasa", Size = Vector3.new(0.4, 0.4, 2), CFrame = cf * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, i, 0), Color = Color3.fromRGB(40, 35, 30), Material = M.Wood })
	end
	local smoke = part(model, { Name = "Fumaca", Size = Vector3.one * 0.5, CFrame = cf * CFrame.new(0, 0.6, 0), Transparency = 1, CanCollide = false })
	Props.smoke(smoke, 0.8)
	-- colchonetes, caixas reviradas e carroça quebrada
	for _, spot in { { -3, 2 }, { 3, 2.5 } } do
		part(model, { Name = "Colchonete", Size = Vector3.new(1.6, 0.3, 3.4), CFrame = cf * CFrame.new(spot[1], 0.15, spot[2]) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0), Color = Color3.fromRGB(120, 60, 50), Material = M.Fabric })
	end
	Props.crate(model, cf * CFrame.new(7, 0, 3) * CFrame.Angles(0, 0.3, math.rad(80)), 2)
	Props.crate(model, cf * CFrame.new(8.5, 0, 1), 1.6)
	Props.barrel(model, cf * CFrame.new(-8, 0, 2) * CFrame.Angles(math.rad(90), 0, 0) * CFrame.new(0, -0.8, 0))
	local cart = Props.cart(model, cf * CFrame.new(-2, 0, -9) * CFrame.Angles(0, 1.2, math.rad(-12)))
	local _ = cart
	return cf * CFrame.new(-5, 0, 6)
end

-- Ruínas de observatório: muro redondo quebrado, costelas da cúpula e telescópio gigante
function builders.observatory(model, cf, rng)
	local radius = 12
	part(model, { Name = "Piso", Size = Vector3.new(0.6, radius * 2 + 2, radius * 2 + 2), Shape = Enum.PartType.Cylinder, CFrame = cf * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = OLD_STONE, Material = M.Slate })
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		local frame = cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -radius)
		local height = if i == 0 or i == 15 then 0 else rng:NextNumber(2, 9)
		if height > 0 then
			part(model, { Name = "Muro", Size = Vector3.new(5, height, 1.4), CFrame = frame * CFrame.new(0, height / 2, 0), Color = STONE:Lerp(Color3.new(0, 0, 0), rng:NextNumber() * 0.12), Material = M.Brick })
		end
	end
	-- costelas da cúpula (algumas caídas)
	for i = 0, 5 do
		local a = i / 6 * math.pi
		if i ~= 2 then
			for j = 0, 5 do
				local t = j / 6
				local angle = t * math.pi / 2
				part(model, { Name = "Costela", Size = Vector3.new(0.8, 0.8, 3.6), CFrame = cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 9 + math.sin(angle) * radius * 0.8, -math.cos(angle) * radius) * CFrame.Angles(angle, 0, 0), Color = Color3.fromRGB(100, 100, 110), Material = M.Metal })
			end
		end
	end
	-- telescópio no pedestal
	Props.column(model, cf * CFrame.new(0, 0.6, 0), 4, 3, STONE, M.Marble)
	local scope = cf * CFrame.new(0, 6, 0) * CFrame.Angles(math.rad(35), math.rad(30), 0)
	part(model, { Name = "Tubo", Size = Vector3.new(2, 2, 10), CFrame = scope, Color = Color3.fromRGB(150, 110, 60), Material = M.Metal })
	part(model, { Name = "Lente", Size = Vector3.new(2.6, 2.6, 0.6), CFrame = scope * CFrame.new(0, 0, -5), Color = Color3.fromRGB(180, 220, 255), Material = M.Glass, Transparency = 0.2 })
	part(model, { Name = "Anel", Size = Vector3.new(2.4, 2.4, 0.5), CFrame = scope * CFrame.new(0, 0, 2), Color = C.Gold, Material = M.Metal })
	-- entulho
	for _ = 1, 8 do
		local size = rng:NextNumber(1, 2.5)
		part(model, { Name = "Entulho", Size = Vector3.new(size, size * 0.6, size), CFrame = cf * CFrame.new(rng:NextNumber(-10, 10), size * 0.3, rng:NextNumber(-10, 10)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Color = STONE, Material = M.Brick })
	end
	return cf * CFrame.new(6, 0.6, 5)
end

-- Cemitério: muro baixo com portão, lápides, cruzes, árvore seca, cripta e lanternas
function builders.graveyard(model, cf, rng)
	local w, d = 14, 12
	local function wall(from, to)
		local a = (cf * CFrame.new(from[1], 0, from[2])).Position
		local b = (cf * CFrame.new(to[1], 0, to[2])).Position
		part(model, { Name = "Muro", Size = Vector3.new(1, 2.4, (b - a).Magnitude), CFrame = CFrame.lookAt((a + b) / 2 + Vector3.new(0, 1.2, 0), b + Vector3.new(0, 1.2, 0)), Color = OLD_STONE, Material = M.Cobblestone })
	end
	wall({ -w, -d }, { -3, -d })
	wall({ 3, -d }, { w, -d })
	wall({ w, -d }, { w, d })
	wall({ w, d }, { -w, d })
	wall({ -w, d }, { -w, -d })
	for _, x in { -3, 3 } do
		part(model, { Name = "Pilar", Size = Vector3.new(1.4, 4.4, 1.4), CFrame = cf * CFrame.new(x, 2.2, -d), Color = STONE, Material = M.Cobblestone })
	end
	part(model, { Name = "Arco", Size = Vector3.new(7.4, 0.8, 1), CFrame = cf * CFrame.new(0, 4.6, -d), Color = Color3.fromRGB(50, 50, 55), Material = M.Metal })
	-- lápides e cruzes em fileiras
	for row = 0, 2 do
		for i = 0, 4 do
			local spot = cf * CFrame.new(-9 + i * 4.5, 0, -6 + row * 5) * CFrame.Angles(rng:NextNumber(-0.12, 0.12), rng:NextNumber(-0.1, 0.1), rng:NextNumber(-0.1, 0.1))
			if (row + i) % 3 == 0 then
				part(model, { Name = "Cruz", Size = Vector3.new(0.4, 3, 0.4), CFrame = spot * CFrame.new(0, 1.5, 0), Color = OLD_STONE, Material = M.Slate })
				part(model, { Name = "Cruz", Size = Vector3.new(1.6, 0.4, 0.4), CFrame = spot * CFrame.new(0, 2.2, 0), Color = OLD_STONE, Material = M.Slate })
			else
				part(model, { Name = "Lapide", Size = Vector3.new(1.6, 2.2, 0.5), CFrame = spot * CFrame.new(0, 1.1, 0), Color = STONE:Lerp(Color3.new(0, 0, 0), rng:NextNumber() * 0.2), Material = M.Slate })
				part(model, { Name = "Topo", Size = Vector3.new(0.5, 1.6, 1.6), Shape = Enum.PartType.Cylinder, CFrame = spot * CFrame.new(0, 2.2, 0) * CFrame.Angles(0, math.rad(90), 0), Color = STONE, Material = M.Slate })
			end
			part(model, { Name = "Cova", Size = Vector3.new(1.8, 0.3, 3), CFrame = spot * CFrame.new(0, 0.15, 1.8), Color = Color3.fromRGB(80, 65, 50), Material = M.Ground, CanCollide = false })
		end
	end
	-- cripta no fundo
	local crypt = cf * CFrame.new(0, 0, d + 6)
	part(model, { Name = "Cripta", Size = Vector3.new(9, 7, 7), CFrame = crypt * CFrame.new(0, 3.5, 0), Color = OLD_STONE, Material = M.Cobblestone })
	part(model, { Name = "Porta", Size = Vector3.new(3, 4.5, 0.4), CFrame = crypt * CFrame.new(0, 2.25, -3.6), Color = Color3.fromRGB(30, 30, 35), Material = M.Metal })
	Props.roof(model, crypt * CFrame.new(0, 7, 0) * CFrame.Angles(0, math.rad(90), 0), 7, 9, 30, Color3.fromRGB(70, 70, 80))
	for _, x in { -3.5, 3.5 } do
		local lantern = part(model, { Name = "Lanterna", Size = Vector3.new(0.7, 0.9, 0.7), CFrame = crypt * CFrame.new(x, 5, -3.8), Color = Color3.fromRGB(140, 255, 180), Material = M.Neon, CanCollide = false })
		Props.light(lantern, Color3.fromRGB(140, 255, 180), 14, 1.2)
		Props.nightLight(lantern)
	end
	Props.deadTree(model, cf * CFrame.new(10, 0, 6), 1.2, rng)
	-- névoa baixa
	local fogPart = part(model, { Name = "Nevoa", Size = Vector3.new(26, 1, 22), CFrame = cf * CFrame.new(0, 0.6, 0), Transparency = 1, CanCollide = false, CanQuery = false })
	local fog = Instance.new("ParticleEmitter")
	fog.Color = ColorSequence.new(Color3.fromRGB(200, 210, 220))
	fog.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 0.75), NumberSequenceKeypoint.new(1, 1) })
	fog.Size = NumberSequence.new(5, 8)
	fog.Lifetime = NumberRange.new(5, 8)
	fog.Rate = 3
	fog.Speed = NumberRange.new(0.3, 0.8)
	fog.Parent = fogPart
	return cf * CFrame.new(-11, 0, d - 3)
end

-- Altar na floresta: degraus, pilares quebrados, cristal flutuante e trepadeiras
function builders.altar(model, cf, rng)
	for i = 0, 2 do
		part(model, { Name = "Degrau", Size = Vector3.new(14 - i * 3.5, 1, 14 - i * 3.5), CFrame = cf * CFrame.new(0, 0.5 + i, 0), Color = OLD_STONE, Material = M.Slate })
	end
	part(model, { Name = "Altar", Size = Vector3.new(3, 2.4, 2), CFrame = cf * CFrame.new(0, 4.2, 0), Color = STONE, Material = M.Marble })
	local crystal = part(model, { Name = "Cristal", Size = Vector3.new(1.6, 3, 1.6), CFrame = cf * CFrame.new(0, 8, 0), Color = Color3.fromRGB(120, 255, 200), Material = M.Neon, CanCollide = false })
	Props.light(crystal, Color3.fromRGB(120, 255, 200), 26, 2)
	CollectionService:AddTag(crystal, "Spin")
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + math.pi / 4
		local pillar = cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -6)
		local height = if i == 1 then 3 else rng:NextNumber(6, 9)
		Props.column(model, pillar * CFrame.new(0, 1, 0), height, 1.6, STONE, M.Marble)
		part(model, { Name = "Trepadeira", Size = Vector3.new(1.8, height * 0.7, 0.3), CFrame = pillar * CFrame.new(0, 1 + height * 0.4, -0.8), Color = MOSS, Material = M.Grass, CanCollide = false })
	end
	part(model, { Name = "PilarCaido", Size = Vector3.new(1.6, 7, 1.6), CFrame = cf * CFrame.new(5, 1.3, 7) * CFrame.Angles(0, 0.5, math.rad(85)), Color = STONE, Material = M.Marble })
	local motes = Instance.new("ParticleEmitter")
	motes.Color = ColorSequence.new(Color3.fromRGB(160, 255, 220))
	motes.LightEmission = 1
	motes.Size = NumberSequence.new(0.3, 0)
	motes.Lifetime = NumberRange.new(2, 4)
	motes.Rate = 8
	motes.Speed = NumberRange.new(0.5, 1.5)
	motes.SpreadAngle = Vector2.new(180, 180)
	motes.Parent = crystal
	return cf * CFrame.new(0, 3, 3)
end

-- Navio naufragado na areia: casco inclinado, mastro quebrado, vela rasgada e carga espalhada
function builders.shipwreck(model, cf, rng)
	local hull = cf * CFrame.new(0, 1.5, 0) * CFrame.Angles(0, 0, math.rad(18))
	local wood = Color3.fromRGB(100, 70, 45)
	part(model, { Name = "Fundo", Size = Vector3.new(7, 1, 24), CFrame = hull, Color = wood, Material = M.WoodPlanks })
	for _, side in { -1, 1 } do
		for i = 0, 2 do
			part(model, { Name = "Costado", Size = Vector3.new(1, 2.2, 24 - i * 2), CFrame = hull * CFrame.new(side * (3.5 + i * 0.6), 1.1 + i * 2.1, 0), Color = wood:Lerp(Color3.new(0, 0, 0), i * 0.08), Material = M.WoodPlanks })
		end
	end
	part(model, { Name = "Proa", Size = Vector3.new(8, 6, 4), CFrame = hull * CFrame.new(0, 3, -13) * CFrame.Angles(math.rad(-20), 0, 0), Color = wood, Material = M.WoodPlanks })
	part(model, { Name = "Convés", Size = Vector3.new(8, 0.6, 14), CFrame = hull * CFrame.new(0, 5, 4), Color = C.Plank, Material = M.WoodPlanks })
	part(model, { Name = "Mastro", Size = Vector3.new(1.2, 12, 1.2), CFrame = hull * CFrame.new(0, 11, 2), Color = C.DarkWood, Material = M.Wood })
	part(model, { Name = "MastroQuebrado", Size = Vector3.new(1, 10, 1), CFrame = cf * CFrame.new(10, 1, 4) * CFrame.Angles(math.rad(80), 0.4, 0), Color = C.DarkWood, Material = M.Wood })
	part(model, { Name = "Vela", Size = Vector3.new(0.2, 7, 8), CFrame = hull * CFrame.new(0.6, 12, 2) * CFrame.Angles(0, math.rad(90), math.rad(8)), Color = Color3.fromRGB(230, 220, 195), Material = M.Fabric, Transparency = 0.1, CanCollide = false })
	-- carga espalhada na areia
	for _ = 1, 6 do
		local spot = cf * CFrame.new(rng:NextNumber(-12, 12), 0, rng:NextNumber(-14, 14))
		if rng:NextNumber() < 0.5 then
			Props.barrel(model, spot * CFrame.Angles(math.rad(90), rng:NextNumber(0, 3), 0) * CFrame.new(0, -0.8, 0))
		else
			Props.crate(model, spot * CFrame.Angles(0, rng:NextNumber(0, 3), 0), rng:NextNumber(1.6, 2.4))
		end
	end
	part(model, { Name = "Ancora", Size = Vector3.new(0.6, 4, 0.6), CFrame = cf * CFrame.new(-9, 1.6, -8) * CFrame.Angles(0, 0, math.rad(30)), Color = Color3.fromRGB(70, 70, 75), Material = M.Metal })
	part(model, { Name = "Ancora", Size = Vector3.new(3, 0.6, 0.6), CFrame = cf * CFrame.new(-10, 0.5, -8), Color = Color3.fromRGB(70, 70, 75), Material = M.Metal })
	return cf * CFrame.new(8, 0, -6)
end

function PointsOfInterest.build(parent, rng)
	local folder = Instance.new("Folder")
	folder.Name = "LocaisDeInteresse"
	folder.Parent = parent
	for _, poi in Points.List do
		local builder = builders[poi.kind]
		if builder then
			local cf = CFrame.new(poi.x, groundAt(poi.x, poi.z), poi.z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
			local model = Instance.new("Model")
			model.Name = poi.name
			local ok, chestFrame = pcall(builder, model, cf, rng)
			if not ok then
				warn("[Locais] Falha ao montar " .. poi.id .. ": " .. tostring(chestFrame))
				chestFrame = cf * CFrame.new(0, 0, 4)
			end
			treasureChest(model, chestFrame, poi)
			model.Parent = folder
			Props.scaleModel(model, cf, S)
			Placement.reserve(poi.x, poi.z, 16 * S, "local")
		end
	end
end

return PointsOfInterest
