-- Pontos de interesse do mapa.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared.World)
local Enemies = require(Shared.Enemies)

local Props = require(script.Parent.Props)
local Placement = require(script.Parent.Placement)

local Landmarks = {}

-- Estruturas desenhadas em tamanho "de design" e ampliadas por K (proporcional ao personagem)
local K = World.Scale

local M = Enum.Material
local C = Props.Colors
local part = Props.part

local function ground(x, z, yaw, sink)
	return CFrame.new(x, World.height(x, z) - (sink or 0), z) * CFrame.Angles(0, yaw or 0, 0)
end

-- Altura mínima de uma área (para assentar plataformas em terreno irregular)
local function lowestAround(x, z, radius)
	local lowest = math.huge
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		lowest = math.min(lowest, World.height(x + math.cos(a) * radius, z + math.sin(a) * radius))
	end
	return math.min(lowest, World.height(x, z))
end

local function platform(parent, x, z, size, color, material, yaw)
	local low = lowestAround(x, z, math.max(size.X, size.Z) / 2)
	local high = World.height(x, z)
	local thickness = math.max(2, high - low + 2)
	local top = high + 0.4
	part(parent, {
		Name = "Plataforma",
		Size = Vector3.new(size.X, thickness, size.Z),
		CFrame = CFrame.new(x, top - thickness / 2, z) * CFrame.Angles(0, yaw or 0, 0),
		Color = color,
		Material = material,
	})
	return CFrame.new(x, top, z) * CFrame.Angles(0, yaw or 0, 0)
end

-- ===================== PEDRAS DE VIAGEM =====================
function Landmarks.waystones(parent)
	local folder = Instance.new("Folder")
	folder.Name = "PedrasDeViagem"
	folder.Parent = parent
	for _, stone in World.Waystones do
		local model = Instance.new("Model")
		model.Name = stone.id
		local cf = platform(model, stone.x, stone.z, Vector3.new(7, 0, 7), C.DarkStone, M.Slate)
		part(model, { Name = "Base", Size = Vector3.new(4, 1.2, 4), CFrame = cf * CFrame.new(0, 0.6, 0), Color = C.Stone, Material = M.Cobblestone })
		local obelisk = part(model, { Name = "Obelisco", Size = Vector3.new(2, 8, 2), CFrame = cf * CFrame.new(0, 5.2, 0), Color = Color3.fromRGB(70, 75, 95), Material = M.Slate })
		local rune = part(model, { Name = "Runa", Size = Vector3.new(2.15, 5, 0.6), CFrame = cf * CFrame.new(0, 5.2, 0), Color = Color3.fromRGB(90, 90, 110), Material = M.Neon })
		local crystal = part(model, { Name = "Cristal", Size = Vector3.new(1.4, 1.4, 1.4), CFrame = cf * CFrame.new(0, 10.4, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)), Color = Color3.fromRGB(110, 200, 255), Material = M.Neon, CanCollide = false })
		CollectionService:AddTag(crystal, "Spin")
		Props.light(crystal, Color3.fromRGB(110, 200, 255), 16, 1.5)
		model.PrimaryPart = obelisk
		model:SetAttribute("WaystoneId", stone.id)
		CollectionService:AddTag(model, "Waystone")
		rune:SetAttribute("Rune", true)
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "WaystonePrompt"
		prompt.ActionText = "Viajar"
		prompt.ObjectText = "Pedra de " .. stone.name
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = obelisk
		Props.billboard(obelisk, "🌀 " .. stone.name, Color3.fromRGB(140, 210, 255), 6.5, 70)
		model.Parent = folder
		Props.scaleModel(model, cf, K)
		Placement.reserve(stone.x, stone.z, 6 * K, "pedra")
	end
end

-- ===================== ACAMPAMENTOS =====================
local function goblinCamp(parent, camp, rng)
	local cx, cz = camp.center.X, camp.center.Y
	local model = Instance.new("Model")
	model.Name = "AcampamentoGoblin_" .. camp.id
	local fireGround = ground(cx, cz, 0, 0.2)
	Props.scaleModel(Props.campfire(model, fireGround), fireGround, K)
	for i = 1, 3 do
		local a = i / 3 * math.pi * 2 + rng:NextNumber() * 0.4
		local x, z = cx + math.cos(a) * 11 * K, cz + math.sin(a) * 11 * K
		local tentGround = ground(x, z, math.atan2(-(cx - x), -(cz - z)), 0.3)
		local tent = Props.tent(model, tentGround, Color3.fromRGB(120, 90, 60):Lerp(Color3.fromRGB(80, 100, 60), rng:NextNumber()))
		Props.scaleModel(tent, tentGround, K)
		Placement.reserve(x, z, 4 * K, "tenda")
	end
	-- paliçada parcial
	for i = 0, 14 do
		local a = math.rad(i * 14 + 40)
		local x, z = cx + math.cos(a) * 22 * K, cz + math.sin(a) * 22 * K
		local h = rng:NextNumber(5, 7) * K
		part(model, { Name = "Estaca", Size = Vector3.new(1.1 * K, h, 1.1 * K), CFrame = ground(x, z, 0, 1) * CFrame.new(0, h / 2, 0) * CFrame.Angles(rng:NextNumber(-0.1, 0.1), 0, rng:NextNumber(-0.1, 0.1)), Color = C.DarkWood, Material = M.Wood })
	end
	for _ = 1, 4 do
		local a = rng:NextNumber() * math.pi * 2
		local x, z = cx + math.cos(a) * 6 * K, cz + math.sin(a) * 6 * K
		Props.crate(model, ground(x, z, rng:NextNumber() * 3, 0.2), rng:NextNumber(1.6, 2.4) * K)
	end
	-- estandarte
	local pole = ground(cx + 4 * K, cz - 4 * K, 0, 0.5)
	local banner = Instance.new("Model")
	banner.Name = "Estandarte"
	banner.Parent = model
	part(banner, { Name = "Mastro", Size = Vector3.new(0.4, 9, 0.4), CFrame = pole * CFrame.new(0, 4.5, 0), Color = C.DarkWood, Material = M.Wood })
	part(banner, { Name = "Bandeira", Size = Vector3.new(2.6, 3, 0.15), CFrame = pole * CFrame.new(1.4, 7.4, 0), Color = Color3.fromRGB(160, 30, 30), Material = M.Fabric })
	Props.scaleModel(banner, pole, K)
	model.Parent = parent
	Placement.reserve(cx, cz, 4 * K, "fogueira")
end

local function spiderNest(parent, camp, rng)
	local cx, cz = camp.center.X, camp.center.Y
	local model = Instance.new("Model")
	model.Name = "NinhoAranhas"
	for _ = 1, 14 do
		local a = rng:NextNumber() * math.pi * 2
		local r = rng:NextNumber(4, 26) * K
		local x, z = cx + math.cos(a) * r, cz + math.sin(a) * r
		local base = ground(x, z, rng:NextNumber() * 6, 0)
		part(model, { Name = "Teia", Size = Vector3.new(rng:NextNumber(5, 9) * K, rng:NextNumber(4, 7) * K, 0.1), CFrame = base * CFrame.new(0, 3.5 * K, 0) * CFrame.Angles(0, 0, rng:NextNumber(-0.4, 0.4)), Color = Color3.fromRGB(235, 235, 240), Material = M.ForceField, Transparency = 0.3, CanCollide = false })
	end
	for _ = 1, 6 do
		local a = rng:NextNumber() * math.pi * 2
		local r = rng:NextNumber(3, 10) * K
		Props.ball(model, (ground(cx + math.cos(a) * r, cz + math.sin(a) * r)).Position + Vector3.new(0, 0.6 * K, 0), rng:NextNumber(1.2, 2) * K, Color3.fromRGB(230, 225, 210), M.SmoothPlastic, { CanCollide = false })
	end
	model.Parent = parent
end

-- ===================== RUÍNAS =====================
local function temple(parent, rng)
	local loc = World.Locations.templo_ruinas
	local model = Instance.new("Model")
	model.Name = "TemploRuinas"
	local cf = platform(model, loc.x, loc.z, Vector3.new(30, 0, 22), Color3.fromRGB(150, 145, 130), M.Slate)
	-- degraus na frente (lado sul, de onde vem o jogador)
	for i = 1, 3 do
		part(model, { Name = "Degrau", Size = Vector3.new(14, 0.6, 2), CFrame = cf * CFrame.new(0, -0.3 - (i - 1) * 0.6, 11 + i * 1.6), Color = C.Stone, Material = M.Slate })
	end
	for row = -1, 1, 2 do
		for i = 0, 4 do
			local broken = rng:NextNumber() < 0.4
			local h = if broken then rng:NextNumber(3, 7) else 12
			local x = -10 + i * 5
			part(model, { Name = "Coluna", Size = Vector3.new(2.2, h, 2.2), CFrame = cf * CFrame.new(x, h / 2, row * 8), Color = Color3.fromRGB(190, 185, 170), Material = M.Marble })
			if broken then
				part(model, { Name = "Pedaco", Size = Vector3.new(2.2, 4, 2.2), CFrame = cf * CFrame.new(x + rng:NextNumber(-3, 3), 1.1, row * 8 + row * rng:NextNumber(2, 4)) * CFrame.Angles(0, rng:NextNumber() * 3, math.rad(90)), Color = Color3.fromRGB(180, 175, 160), Material = M.Marble })
			else
				part(model, { Name = "Capitel", Size = Vector3.new(3, 0.8, 3), CFrame = cf * CFrame.new(x, h + 0.4, row * 8), Color = Color3.fromRGB(190, 185, 170), Material = M.Marble })
			end
		end
	end
	part(model, { Name = "Altar", Size = Vector3.new(5, 3, 3), CFrame = cf * CFrame.new(0, 1.5, -6), Color = Color3.fromRGB(110, 105, 100), Material = M.Slate })
	local orb = Props.ball(model, (cf * CFrame.new(0, 4.4, -6)).Position, 1.8, Color3.fromRGB(100, 230, 255), M.Neon, { CanCollide = false })
	Props.light(orb, Color3.fromRGB(100, 230, 255), 24, 2)
	model.Parent = parent
	Props.scaleModel(model, cf, K)
	Placement.reserve(loc.x, loc.z, 18 * K, "templo")
end

local function mine(parent)
	local loc = World.Locations.mina
	local model = Instance.new("Model")
	model.Name = "Mina"
	local cf = ground(loc.x, loc.z - 8 * K, 0, 0.5)
	-- encosta de pedra com entrada
	part(model, { Name = "Encosta", Size = Vector3.new(26, 16, 10), CFrame = cf * CFrame.new(0, 7, -6), Color = Color3.fromRGB(105, 100, 95), Material = M.Rock })
	part(model, { Name = "Entrada", Size = Vector3.new(6, 7, 1), CFrame = cf * CFrame.new(0, 3.5, -0.6), Color = Color3.fromRGB(15, 12, 10), Material = M.SmoothPlastic })
	for _, x in { -3.6, 3.6 } do
		part(model, { Name = "Escora", Size = Vector3.new(0.9, 8, 0.9), CFrame = cf * CFrame.new(x, 4, 0), Color = C.Wood, Material = M.Wood })
	end
	part(model, { Name = "Viga", Size = Vector3.new(8.5, 0.9, 0.9), CFrame = cf * CFrame.new(0, 8, 0), Color = C.Wood, Material = M.Wood })
	local lantern = part(model, { Name = "Lanterna", Size = Vector3.new(0.8, 1, 0.8), CFrame = cf * CFrame.new(3.6, 6.5, 0.7), Color = Color3.fromRGB(255, 210, 140), Material = M.Neon })
	Props.light(lantern, Color3.fromRGB(255, 200, 130), 18, 1.6)
	Props.nightLight(lantern)
	-- trilhos e carrinho
	for i = 0, 5 do
		part(model, { Name = "Dormente", Size = Vector3.new(4, 0.3, 0.7), CFrame = cf * CFrame.new(0, 0.2, 2 + i * 2), Color = C.DarkWood, Material = M.Wood })
	end
	for _, x in { -1.3, 1.3 } do
		part(model, { Name = "Trilho", Size = Vector3.new(0.3, 0.3, 12), CFrame = cf * CFrame.new(x, 0.45, 7), Color = Color3.fromRGB(90, 90, 95), Material = M.Metal })
	end
	part(model, { Name = "Carrinho", Size = Vector3.new(3, 2, 3.6), CFrame = cf * CFrame.new(0, 1.6, 9), Color = Color3.fromRGB(80, 70, 60), Material = M.Metal })
	part(model, { Name = "Minerio", Size = Vector3.new(2.6, 0.8, 3.2), CFrame = cf * CFrame.new(0, 2.8, 9), Color = Color3.fromRGB(150, 160, 175), Material = M.Rock })
	model.Parent = parent
	Props.scaleModel(model, cf, K)
	Placement.reserve(loc.x, loc.z - 8 * K, 16 * K, "mina")
end

-- ===================== LAGO E COSTA =====================
local function shrine(parent)
	local loc = World.Locations.santuario_lago
	local model = Instance.new("Model")
	model.Name = "SantuarioLago"
	local cf = platform(model, loc.x - 6 * K, loc.z, Vector3.new(12, 0, 12), Color3.fromRGB(200, 200, 205), M.Marble)
	for _, x in { -5, 5 } do
		for _, z in { -5, 5 } do
			part(model, { Name = "Pilar", Size = Vector3.new(1.2, 8, 1.2), CFrame = cf * CFrame.new(x, 4, z), Color = Color3.fromRGB(230, 230, 235), Material = M.Marble })
		end
	end
	Props.roof(model, cf * CFrame.new(0, 8, 0), 13, 13, 20, Color3.fromRGB(60, 120, 140))
	local crystal = part(model, { Name = "Cristal", Size = Vector3.new(2, 2, 2), CFrame = cf * CFrame.new(0, 3, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)), Color = Color3.fromRGB(120, 255, 220), Material = M.Neon, CanCollide = false })
	CollectionService:AddTag(crystal, "Spin")
	Props.light(crystal, Color3.fromRGB(120, 255, 220), 22, 2)
	model.Parent = parent
	Props.scaleModel(model, cf, K)
	Placement.reserve(loc.x - 6 * K, loc.z, 9 * K, "santuario")
end

local function lighthouse(parent)
	local loc = World.Locations.farol
	local model = Instance.new("Model")
	model.Name = "Farol"
	local cf = platform(model, loc.x, loc.z, Vector3.new(14, 0, 14), C.DarkStone, M.Cobblestone)
	for i = 0, 5 do
		local color = if i % 2 == 0 then Color3.fromRGB(240, 240, 240) else Color3.fromRGB(200, 50, 50)
		Props.column(model, cf * CFrame.new(0, i * 5, 0), 5, 9 - i * 0.5, color, M.SmoothPlastic)
	end
	Props.column(model, cf * CFrame.new(0, 30, 0), 1, 8, Color3.fromRGB(40, 40, 45), M.Metal)
	local lamp = Props.column(model, cf * CFrame.new(0, 31, 0), 4, 5, Color3.fromRGB(255, 240, 160), M.Neon, { Transparency = 0.2 })
	Props.light(lamp, Color3.fromRGB(255, 240, 160), 60, 3)
	Props.nightLight(lamp)
	Props.column(model, cf * CFrame.new(0, 35, 0), 1.5, 6, Color3.fromRGB(200, 50, 50), M.Slate)
	model.Parent = parent
	Props.scaleModel(model, cf, K)
	Placement.reserve(loc.x, loc.z, 9 * K, "farol")
end

local function pier(parent)
	local model = Instance.new("Model")
	model.Name = "Pier"
	local x0, z0 = 45 * K, 292 * K
	local deckY = World.SeaLevel + 2.2
	for i = 0, 11 do
		local z = z0 + i * 3.4
		part(model, { Name = "Tabua", Size = Vector3.new(6, 0.5, 3.2), CFrame = CFrame.new(x0, deckY, z), Color = C.Plank:Lerp(C.Wood, (i % 3) * 0.2), Material = M.WoodPlanks })
		if i % 2 == 0 then
			for _, side in { -3, 3 } do
				part(model, { Name = "Estaca", Size = Vector3.new(0.8, 12, 0.8), CFrame = CFrame.new(x0 + side, deckY - 5, z), Color = C.DarkWood, Material = M.Wood })
			end
		end
	end
	Props.barrel(model, CFrame.new(x0 + 1.8, deckY + 0.25, z0 + 34))
	Props.crate(model, CFrame.new(x0 - 1.8, deckY + 0.25, z0 + 32), 2)
	model.Parent = parent
	Props.scaleModel(model, CFrame.new(x0, deckY, z0), K)
	Placement.reserve(x0, z0 + 10 * K, 6 * K, "pier")
end

-- ===================== NORTE =====================
local function passGate(parent)
	local z = World.PassGateZ
	local model = Instance.new("Model")
	model.Name = "PortaoNorte"
	for _, side in { -1, 1 } do
		local x = side * 22
		local base = ground(x, z, 0, 2)
		part(model, { Name = "Torre", Size = Vector3.new(10, 30, 10), CFrame = base * CFrame.new(0, 15, 0), Color = Color3.fromRGB(90, 88, 95), Material = M.Cobblestone })
		part(model, { Name = "Ameias", Size = Vector3.new(11, 2, 11), CFrame = base * CFrame.new(0, 31, 0), Color = Color3.fromRGB(80, 78, 85), Material = M.Cobblestone })
		Props.fire(model, (base * CFrame.new(-side * 5.5, 22, 0)).Position, 0.9)
		-- muralhas até a montanha
		part(model, { Name = "Muralha", Size = Vector3.new(30, 22, 6), CFrame = base * CFrame.new(side * 20, 11, 0), Color = Color3.fromRGB(85, 83, 90), Material = M.Cobblestone })
	end
	local center = ground(0, z, 0, 0)
	part(model, { Name = "Arco", Size = Vector3.new(36, 5, 6), CFrame = center * CFrame.new(0, 26, 0), Color = Color3.fromRGB(80, 78, 85), Material = M.Cobblestone })
	local barrier = part(model, { Name = "Barreira", Size = Vector3.new(34, 24, 1), CFrame = center * CFrame.new(0, 12, 0), Color = Color3.fromRGB(170, 90, 255), Material = M.ForceField, CanCollide = false, Transparency = 0.1 })
	barrier:SetAttribute("Barrier", true)
	Props.billboard(barrier, "🔒 PORTÃO SELADO • Nível 10", Color3.fromRGB(220, 170, 255), 15, 120)
	model.Parent = parent
	Props.scaleModel(model, center, K)
	Placement.reserve(0, z, 30 * K, "portao")
	return barrier
end

local function crater(parent, rng)
	local c = World.CraterCenter
	local model = Instance.new("Model")
	model.Name = "CovilRei"
	-- trono ao fundo (norte)
	local throne = ground(c.X, c.Z - 38 * K, 0, 0.5)
	local throneModel = Instance.new("Model")
	throneModel.Name = "Trono"
	throneModel.Parent = model
	part(throneModel, { Name = "Estrado", Size = Vector3.new(20, 3, 12), CFrame = throne * CFrame.new(0, 1.5, 0), Color = Color3.fromRGB(70, 60, 55), Material = M.Slate })
	part(throneModel, { Name = "Assento", Size = Vector3.new(8, 3, 6), CFrame = throne * CFrame.new(0, 4.5, 0), Color = Color3.fromRGB(120, 30, 30), Material = M.Fabric })
	part(throneModel, { Name = "Encosto", Size = Vector3.new(9, 14, 2), CFrame = throne * CFrame.new(0, 10, 3), Color = Color3.fromRGB(90, 75, 40), Material = M.Metal })
	local gem = Props.ball(throneModel, (throne * CFrame.new(0, 15, 2)).Position, 2.4, Color3.fromRGB(255, 60, 40), M.Neon)
	Props.light(gem, Color3.fromRGB(255, 80, 40), 30, 2)
	Props.scaleModel(throneModel, throne, K)
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2
		local x, z = c.X + math.cos(a) * 58 * K, c.Z + math.sin(a) * 58 * K
		local base = ground(x, z, a, 1)
		local h = rng:NextNumber(10, 16) * K
		part(model, { Name = "Pilar", Size = Vector3.new(3 * K, h, 3 * K), CFrame = base * CFrame.new(0, h / 2, 0), Color = Color3.fromRGB(70, 65, 60), Material = M.Basalt })
		Props.fire(model, (base * CFrame.new(0, h, 0)).Position, K)
	end
	for _ = 1, 8 do
		local a = rng:NextNumber() * math.pi * 2
		local r = rng:NextNumber(20, 50) * K
		local base = ground(c.X + math.cos(a) * r, c.Z + math.sin(a) * r, rng:NextNumber() * 3, 0)
		for _ = 1, 4 do
			part(model, { Name = "Osso", Size = Vector3.new(0.4, 0.4, rng:NextNumber(1.5, 3)), CFrame = base * CFrame.new(rng:NextNumber(-1, 1), 0.2, rng:NextNumber(-1, 1)) * CFrame.Angles(0, rng:NextNumber() * 3, 0), Color = Color3.fromRGB(230, 225, 205), CanCollide = false })
		end
	end
	model.Parent = parent
	Placement.reserve(c.X, c.Z, 60 * K, "cratera")
end

function Landmarks.build(parent, rng)
	local folder = Instance.new("Folder")
	folder.Name = "Locais"
	folder.Parent = parent

	Landmarks.waystones(folder)
	for _, camp in Enemies.Camps do
		if camp.structure == "goblinCamp" then
			goblinCamp(folder, camp, rng)
		elseif camp.structure == "spiderNest" then
			spiderNest(folder, camp, rng)
		end
		if not camp.boss and camp.id ~= "treino" then
			Placement.reserve(camp.center.X, camp.center.Y, 6 * K, "acampamento")
		end
	end
	temple(folder, rng)
	mine(folder)
	shrine(folder)
	lighthouse(folder)
	pier(folder)
	crater(folder, rng)
	return { barrier = passGate(folder) }
end

return Landmarks
