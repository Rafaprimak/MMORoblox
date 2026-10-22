-- Vila Aurora: construções dos NPCs, chafariz, casas, postes e entrada.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared.World)
local NPCs = require(Shared.NPCs)
local Enemies = require(Shared.Enemies)

local Props = require(script.Parent.Props)
local Placement = require(script.Parent.Placement)

local Town = {}

local M = Enum.Material
local C = Props.Colors
local part = Props.part
local Y = World.TownHeight
-- Construções são desenhadas em tamanho "de design" e ampliadas por K (proporcional ao personagem)
local K = World.Scale

local function npcFrame(npc)
	return CFrame.new(npc.x, Y, npc.z) * CFrame.Angles(0, npc.yaw, 0)
end

-- Frente da construção (porta). NPCs "indoor" ficam lá dentro; a porta fica onde estava o NPC.
local function doorFrame(npc)
	if npc.doorX then
		return CFrame.new(npc.doorX, Y, npc.doorZ) * CFrame.Angles(0, npc.yaw, 0)
	end
	return npcFrame(npc)
end

local builders = {}

-- Forja: salão com fornalha no fundo, bigorna no meio, suportes de armas, amolador e bancada
function builders.forge(parent, npc, rng)
	local cf = doorFrame(npc)
	local model = Props.building(parent, cf, 18, 16, 10, Color3.fromRGB(150, 110, 80), Color3.fromRGB(90, 60, 50), {
		name = "Forja",
		doorWidth = 5,
		chimney = -5,
		floorColor = Color3.fromRGB(95, 90, 88),
		lights = { Vector3.new(4, 9, 5), Vector3.new(-3, 9, 10) },
	})
	local inside = cf * CFrame.new(0, 1.2, 0)
	-- fornalha de tijolos no canto do fundo
	local furnace = part(model, { Name = "Fornalha", Size = Vector3.new(6, 6, 3.5), CFrame = inside * CFrame.new(-5, 3, 13.6), Color = Color3.fromRGB(120, 60, 50), Material = M.Brick })
	local _ = furnace
	local opening = part(model, { Name = "Brasa", Size = Vector3.new(3.4, 2.2, 0.3), CFrame = inside * CFrame.new(-5, 2, 11.8), Color = C.Fire, Material = M.Neon })
	Props.light(opening, C.Fire, 24, 3, true)
	Props.fire(model, (inside * CFrame.new(-5, 0.6, 12.6)).Position, 0.7)
	-- bigorna e balde de têmpera
	local anvil = inside * CFrame.new(2.5, 0, 6)
	part(model, { Name = "BigornaBase", Size = Vector3.new(1.6, 1.8, 1.4), CFrame = anvil * CFrame.new(0, 0.9, 0), Color = Color3.fromRGB(45, 45, 50), Material = M.Metal })
	part(model, { Name = "Bigorna", Size = Vector3.new(3.2, 0.9, 1.4), CFrame = anvil * CFrame.new(0, 2.2, 0), Color = Color3.fromRGB(70, 70, 78), Material = M.Metal })
	part(model, { Name = "Ponta", Size = Vector3.new(1, 0.5, 0.8), CFrame = anvil * CFrame.new(-2, 2.35, 0), Color = Color3.fromRGB(70, 70, 78), Material = M.Metal })
	Props.column(model, inside * CFrame.new(5.5, 0, 5), 1.6, 2.2, Color3.fromRGB(90, 70, 50), M.Wood)
	Props.column(model, inside * CFrame.new(5.5, 1.4, 5), 0.2, 1.9, Color3.fromRGB(60, 110, 160), M.Glass)
	-- bancada com ferramentas
	Props.table(model, inside * CFrame.new(6.5, 0, 12.5), 4, 2.2, 3, C.DarkWood)
	for i = -1, 1 do
		part(model, { Name = "Ferramenta", Size = Vector3.new(0.3, 0.3, 1.6), CFrame = inside * CFrame.new(6.5 + i * 1.1, 3.35, 12.5) * CFrame.Angles(0, math.rad(i * 15), 0), Color = Color3.fromRGB(110, 110, 120), Material = M.Metal })
	end
	-- suportes de armas nas paredes laterais
	for _, side in { -1, 1 } do
		local wall = inside * CFrame.new(side * 8.2, 0, 7) * CFrame.Angles(0, math.rad(side * 90), 0)
		part(model, { Name = "Suporte", Size = Vector3.new(6, 0.4, 0.4), CFrame = wall * CFrame.new(0, 4.5, 0), Color = C.DarkWood, Material = M.Wood })
		for i = -2, 2 do
			part(model, { Name = "Lamina", Size = Vector3.new(0.3, 3.2, 0.12), CFrame = wall * CFrame.new(i * 1.15, 3.3, -0.3), Color = Color3.fromRGB(175, 175, 185), Material = M.Metal })
			part(model, { Name = "Guarda", Size = Vector3.new(0.9, 0.2, 0.25), CFrame = wall * CFrame.new(i * 1.15, 4.8, -0.3), Color = C.Gold, Material = M.Metal })
		end
	end
	-- amolador
	local grind = inside * CFrame.new(-5.5, 0, 4)
	part(model, { Name = "Apoio", Size = Vector3.new(0.4, 2, 1.6), CFrame = grind * CFrame.new(0, 1, 0), Color = C.DarkWood, Material = M.Wood })
	Props.column(model, grind * CFrame.new(0, 1.4, 0) * CFrame.Angles(0, 0, math.rad(90)), 0.4, 2.2, C.Stone, M.Slate)
	Props.barrel(model, inside * CFrame.new(-7, 0, 1.8))
	Props.barrel(model, inside * CFrame.new(-7, 0, 9))
	-- placa por fora
	local sign = part(model, { Name = "Placa", Size = Vector3.new(5, 1.6, 0.3), CFrame = cf * CFrame.new(0, 9.2, -0.4), Color = C.Plank, Material = M.WoodPlanks })
	Props.billboard(sign, "⚒️ FORJA", C.Fire, 3)
	local _r = rng
	return model
end

-- Casa da alquimista: prateleiras de frascos, caldeirão borbulhante, ervas penduradas e balcão
function builders.alchemy(parent, npc, rng)
	local cf = doorFrame(npc)
	local model = Props.building(parent, cf, 16, 15, 9, Color3.fromRGB(175, 205, 165), Color3.fromRGB(60, 120, 80), { name = "Alquimia", chimney = 4 })
	local inside = cf * CFrame.new(0, 1.2, 0)
	Props.shelf(model, inside * CFrame.new(-3, 0, 14) * CFrame.Angles(0, math.rad(180), 0), 7, 3, "potions", rng)
	Props.shelf(model, inside * CFrame.new(-7.3, 0, 8) * CFrame.Angles(0, math.rad(-90), 0), 6, 3, "potions", rng)
	Props.shelf(model, inside * CFrame.new(7.3, 0, 10) * CFrame.Angles(0, math.rad(90), 0), 5, 2, "books", rng)
	-- caldeirão
	local cauldronCf = inside * CFrame.new(4, 0, 11)
	local cauldron = Props.column(model, cauldronCf, 2.4, 3.2, Color3.fromRGB(40, 40, 45), M.Metal)
	cauldron.Name = "Caldeirao"
	local liquid = Props.column(model, cauldronCf * CFrame.new(0, 2.2, 0), 0.3, 2.7, Color3.fromRGB(90, 255, 120), M.Neon)
	Props.light(liquid, Color3.fromRGB(90, 255, 120), 14, 1.5)
	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Color = ColorSequence.new(Color3.fromRGB(150, 255, 170))
	bubbles.LightEmission = 0.8
	bubbles.Size = NumberSequence.new(0.4, 0.1)
	bubbles.Lifetime = NumberRange.new(0.6, 1.2)
	bubbles.Rate = 10
	bubbles.Speed = NumberRange.new(1.5, 3)
	bubbles.Parent = liquid
	Props.fire(model, (cauldronCf * CFrame.new(0, -0.3, 0)).Position, 0.5)
	-- balcão na frente da alquimista
	part(model, { Name = "Balcao", Size = Vector3.new(7, 3, 1.4), CFrame = inside * CFrame.new(-1, 1.5, 6.5), Color = C.Wood, Material = M.WoodPlanks })
	part(model, { Name = "Tampo", Size = Vector3.new(7.4, 0.3, 1.8), CFrame = inside * CFrame.new(-1, 3.1, 6.5), Color = C.DarkWood, Material = M.Wood })
	for i = -2, 2 do
		part(model, { Name = "Frasco", Size = Vector3.new(0.5, 0.9, 0.5), CFrame = inside * CFrame.new(-1 + i * 1.3, 3.7, 6.4), Color = Color3.fromHSV((i + 2) / 5, 0.7, 1), Material = M.Neon, Transparency = 0.2 })
	end
	-- ervas penduradas
	for i = 0, 5 do
		part(model, { Name = "Erva", Size = Vector3.new(0.5, 1.4, 0.5), CFrame = inside * CFrame.new(-6 + i * 2.4, 7.2, 3), Color = Color3.fromRGB(90, 150 + i * 10, 70), Material = M.Grass })
	end
	Props.rug(model, cf * CFrame.new(0, 0, 4), 6, 4, Color3.fromRGB(130, 50, 60))
	local sign = part(model, { Name = "Placa", Size = Vector3.new(5, 1.6, 0.3), CFrame = cf * CFrame.new(0, 8.4, -0.4), Color = C.Plank, Material = M.WoodPlanks })
	Props.billboard(sign, "⚗️ ALQUIMIA", Color3.fromRGB(120, 255, 140), 3)
	return model
end

-- Torre do encantador: salão redondo com vão de porta, estantes, mesa de encantar, círculo mágico
function builders.tower(parent, npc, rng)
	local cf = doorFrame(npc)
	local radius = 9
	local center = cf * CFrame.new(0, 0, radius)
	local model = Instance.new("Model")
	model.Name = "TorreEncantador"
	Props.column(model, center, 1, radius * 2 + 2, C.DarkStone, M.Slate)
	part(model, { Name = "Degrau", Size = Vector3.new(6, 0.5, 2), CFrame = cf * CFrame.new(0, 0.25, -1.6), Color = C.Stone, Material = M.Cobblestone })
	part(model, { Name = "Piso", Size = Vector3.new(0.3, radius * 2 - 1, radius * 2 - 1), Shape = Enum.PartType.Cylinder, CFrame = center * CFrame.new(0, 1.05, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(70, 60, 90), Material = M.Slate })
	-- paredes em segmentos (o segmento da frente vira a porta)
	local segments = 18
	local wallHeight = 12
	for i = 0, segments - 1 do
		local angle = (i + 0.5) / segments * math.pi * 2
		local frame = center * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -radius)
		local isDoor = i == 0 or i == segments - 1
		local width = 2 * radius * math.tan(math.pi / segments) + 0.3
		if isDoor then
			part(model, { Name = "Verga", Size = Vector3.new(width, wallHeight - 7, 1), CFrame = frame * CFrame.new(0, 1 + 7 + (wallHeight - 7) / 2, 0), Color = Color3.fromRGB(120, 110, 140), Material = M.Brick })
		else
			part(model, { Name = "Parede", Size = Vector3.new(width, wallHeight, 1), CFrame = frame * CFrame.new(0, 1 + wallHeight / 2, 0), Color = Color3.fromRGB(120, 110, 140), Material = M.Brick })
		end
		if i % 4 == 2 then
			part(model, { Name = "Janela", Size = Vector3.new(1.6, 3, 1.2), CFrame = frame * CFrame.new(0, 8, 0), Color = Color3.fromRGB(200, 150, 255), Material = M.Neon })
		end
	end
	-- andares de cima, telhado cônico e cristal
	Props.column(model, center * CFrame.new(0, 1 + wallHeight, 0), 1.2, radius * 2 + 1.5, Color3.fromRGB(80, 60, 110), M.Slate)
	Props.column(model, center * CFrame.new(0, 2.2 + wallHeight, 0), 8, radius * 1.6, Color3.fromRGB(120, 110, 140), M.Brick)
	for i = 1, 4 do
		Props.column(model, center * CFrame.new(0, 10.2 + wallHeight + (i - 1) * 2.2, 0), 2.2, radius * 1.7 - i * 3, Color3.fromRGB(90, 50, 160), M.Slate)
	end
	local crystal = part(model, { Name = "Cristal", Size = Vector3.new(2.4, 2.4, 2.4), CFrame = center * CFrame.new(0, 23 + wallHeight, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)), Color = Color3.fromRGB(190, 120, 255), Material = M.Neon, CanCollide = false })
	Props.light(crystal, Color3.fromRGB(190, 120, 255), 30, 2)
	CollectionService:AddTag(crystal, "Spin")
	-- interior: estantes, mesa de encantar com livro e cristal flutuante, círculo no chão
	local inside = center * CFrame.new(0, 1.2, 0)
	for _, angle in { 70, 110, 250, 290 } do
		Props.shelf(model, inside * CFrame.Angles(0, math.rad(angle), 0) * CFrame.new(0, 0, -(radius - 1.2)) * CFrame.Angles(0, math.rad(180), 0), 4, 3, "books", rng)
	end
	local circle = part(model, { Name = "Circulo", Size = Vector3.new(0.1, 8, 8), Shape = Enum.PartType.Cylinder, CFrame = inside * CFrame.new(0, 0.02, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(180, 120, 255), Material = M.Neon, Transparency = 0.6, CanCollide = false })
	local _c = circle
	Props.table(model, inside * CFrame.new(0, 0, 3), 4, 2.4, 3, Color3.fromRGB(70, 50, 90))
	part(model, { Name = "Livro", Size = Vector3.new(1.4, 0.3, 1), CFrame = inside * CFrame.new(0, 3.35, 3) * CFrame.Angles(0, math.rad(15), 0), Color = Color3.fromRGB(120, 40, 60) })
	local orb = part(model, { Name = "Orbe", Size = Vector3.one * 1.1, Shape = Enum.PartType.Ball, CFrame = inside * CFrame.new(0, 5.2, 3), Color = Color3.fromRGB(200, 150, 255), Material = M.Neon, CanCollide = false })
	Props.light(orb, Color3.fromRGB(190, 130, 255), 22, 2, true)
	CollectionService:AddTag(orb, "Spin")
	model.Parent = parent
	Props.billboard(crystal, "✨ ENCANTAMENTOS", Color3.fromRGB(200, 150, 255), 3)
	return model
end

-- Empório do Otto: balcão, prateleiras de mercadorias, baús em exposição e ovos de pet no pedestal
function builders.emporium(parent, npc, rng)
	local cf = doorFrame(npc)
	local model = Props.building(parent, cf, 18, 15, 9, Color3.fromRGB(230, 205, 160), Color3.fromRGB(170, 60, 50), { name = "Emporio", doorWidth = 5 })
	local inside = cf * CFrame.new(0, 1.2, 0)
	-- toldo listrado sobre a porta
	for i = 0, 7 do
		local color = if i % 2 == 0 then Color3.fromRGB(220, 60, 50) else Color3.fromRGB(245, 235, 220)
		part(model, { Name = "Toldo", Size = Vector3.new(1.1, 0.25, 3), CFrame = cf * CFrame.new(-3.85 + i * 1.1, 8, -1.5) * CFrame.Angles(math.rad(-18), 0, 0), Color = color, Material = M.Fabric })
	end
	-- balcão
	part(model, { Name = "Balcao", Size = Vector3.new(10, 3, 1.4), CFrame = inside * CFrame.new(0, 1.5, 6.5), Color = C.Plank, Material = M.WoodPlanks })
	part(model, { Name = "Tampo", Size = Vector3.new(10.4, 0.3, 1.8), CFrame = inside * CFrame.new(0, 3.1, 6.5), Color = C.DarkWood, Material = M.Wood })
	part(model, { Name = "Balanca", Size = Vector3.new(1.4, 0.3, 0.8), CFrame = inside * CFrame.new(3, 3.4, 6.4), Color = C.Gold, Material = M.Metal })
	for i = -1, 1 do
		Props.ball(model, (inside * CFrame.new(-3 + i * 0.9, 3.6, 6.4)).Position, 0.7, Color3.fromRGB(240, 60, 60), M.SmoothPlastic)
	end
	-- prateleiras
	Props.shelf(model, inside * CFrame.new(0, 0, 13.9) * CFrame.Angles(0, math.rad(180), 0), 10, 3, "goods", rng)
	Props.shelf(model, inside * CFrame.new(-8.3, 0, 9) * CFrame.Angles(0, math.rad(-90), 0), 6, 2, "potions", rng)
	-- baús em exposição (bronze, prata, real)
	local chestColors = { Color3.fromRGB(205, 130, 70), Color3.fromRGB(200, 205, 220), Color3.fromRGB(255, 200, 50) }
	for i, color in chestColors do
		local chest = inside * CFrame.new(-7.2 + (i - 1) * 2.1, 0, 3)
		part(model, { Name = "Bau", Size = Vector3.new(1.8, 1.2, 1.2), CFrame = chest * CFrame.new(0, 0.6, 0), Color = C.DarkWood, Material = M.Wood })
		part(model, { Name = "Tampa", Size = Vector3.new(1.9, 0.5, 1.3), CFrame = chest * CFrame.new(0, 1.45, 0), Color = color, Material = M.Metal })
	end
	-- pedestal com ovos de pet
	local pedestal = inside * CFrame.new(6, 0, 3)
	Props.column(model, pedestal, 2.5, 2.4, C.Stone, M.Marble)
	local eggColors = { Color3.fromRGB(230, 220, 200), Color3.fromRGB(110, 170, 255), Color3.fromRGB(255, 190, 50) }
	for i, color in eggColors do
		local egg = part(model, { Name = "Ovo", Size = Vector3.new(0.8, 1.05, 0.8), Shape = Enum.PartType.Ball, CFrame = pedestal * CFrame.new(-0.8 + (i - 1) * 0.8, 3, 0), Color = color, Material = if i == 3 then M.Neon else M.SmoothPlastic })
		local _e = egg
	end
	Props.crate(model, inside * CFrame.new(7, 0, 11))
	Props.crate(model, inside * CFrame.new(7, 2.5, 11), 1.6)
	Props.barrel(model, inside * CFrame.new(-7, 0, 13))
	Props.rug(model, cf * CFrame.new(0, 0, 3.5), 5, 4, Color3.fromRGB(60, 80, 140))
	local sign = part(model, { Name = "Placa", Size = Vector3.new(6, 1.6, 0.3), CFrame = cf * CFrame.new(0, 9.4, -0.4), Color = C.Plank, Material = M.WoodPlanks })
	Props.billboard(sign, "🛒 EMPÓRIO DO OTTO", C.Gold, 3)
	return model
end

-- Pátio de treino cercado (os bonecos são inimigos do tipo "boneco")
function builders.training(parent, npc)
	local model = Instance.new("Model")
	model.Name = "PatioTreino"
	local camp
	for _, c in Enemies.Camps do
		if c.id == "treino" then
			camp = c
		end
	end
	local cx, cz = camp.center.X, camp.center.Y
	local w, d = 13 * K, 10 * K
	local corners = {
		Vector3.new(cx - w, Y, cz - d), Vector3.new(cx + w, Y, cz - d),
		Vector3.new(cx + w, Y, cz + d), Vector3.new(cx - w, Y, cz + d),
	}
	Props.fence(model, corners[2], corners[3], 3 * K)
	Props.fence(model, corners[3], corners[4], 3 * K)
	Props.fence(model, corners[4], corners[1], 3 * K)
	Props.fence(model, corners[1], Vector3.new(cx - 4 * K, Y, cz - d), 3 * K)
	Props.fence(model, Vector3.new(cx + 4 * K, Y, cz - d), corners[2], 3 * K)
	-- suporte de armas ao lado do mestre (modelo próprio, ampliado no lugar)
	local rackModel = Instance.new("Model")
	rackModel.Name = "SuporteArmas"
	rackModel.Parent = model
	local rack = npcFrame(npc) * CFrame.new(5 * K, 0, 1 * K)
	part(rackModel, { Name = "Suporte", Size = Vector3.new(4, 0.4, 0.4), CFrame = rack * CFrame.new(0, 3.5, 0), Color = C.DarkWood, Material = M.Wood })
	for _, x in { -1.7, 1.7 } do
		part(rackModel, { Name = "Pe", Size = Vector3.new(0.4, 4, 0.4), CFrame = rack * CFrame.new(x, 2, 0), Color = C.DarkWood, Material = M.Wood })
	end
	for i = -1, 1 do
		part(rackModel, { Name = "Arma", Size = Vector3.new(0.25, 3.6, 0.25), CFrame = rack * CFrame.new(i * 1.1, 2.4, -0.3) * CFrame.Angles(math.rad(-12), 0, 0), Color = Color3.fromRGB(150, 150, 160), Material = M.Metal })
	end
	Props.scaleModel(rackModel, rack, K)
	model.Parent = parent
	Placement.reserve(cx, cz, 14 * K, "treino")
	return model
end

-- Cavalo blocado detalhado. Partes que se mexem ficam em grupos (Model) com uma peça principal:
-- "PernaFL/FR/BL/BR" (principal "Perna"), "Cabeca" (principal "Pescoco") e "Cauda" (principal "Cauda").
-- Na montaria o servidor liga cada grupo ao "Corpo" com Motor6D e o cliente anima o galope.
local function horse(parent, cf, color, saddle)
	local model = Instance.new("Model")
	model.Name = "Cavalo"
	local dark = color:Lerp(Color3.new(0, 0, 0), 0.45)
	local light = color:Lerp(Color3.new(1, 1, 1), 0.25)
	local hoofColor = Color3.fromRGB(45, 38, 32)
	local function add(group, name, size, offset, partColor, material, shape)
		return part(group, { Name = name, Size = size, CFrame = cf * offset, Color = partColor, Material = material or M.SmoothPlastic, Shape = shape })
	end
	local function group(name)
		local g = Instance.new("Model")
		g.Name = name
		g.Parent = model
		return g
	end
	-- tronco
	add(model, "Corpo", Vector3.new(2.2, 2.2, 4.4), CFrame.new(0, 3.6, 0), color)
	add(model, "Peito", Vector3.new(2.1, 2.0, 1.2), CFrame.new(0, 3.55, -2.3) * CFrame.Angles(math.rad(-12), 0, 0), color)
	add(model, "Garupa", Vector3.new(2.35, 2.1, 1.6), CFrame.new(0, 3.75, 1.9), color)
	add(model, "Barriga", Vector3.new(1.8, 0.5, 3.4), CFrame.new(0, 2.45, 0), light)
	-- cabeça e pescoço
	local head = group("Cabeca")
	add(head, "Pescoco", Vector3.new(1.2, 2.6, 1.35), CFrame.new(0, 5.0, -2.55) * CFrame.Angles(math.rad(-35), 0, 0), color)
	add(head, "Cranio", Vector3.new(1.15, 1.15, 1.6), CFrame.new(0, 6.35, -3.35) * CFrame.Angles(math.rad(12), 0, 0), color)
	add(head, "Focinho", Vector3.new(0.95, 0.85, 1.1), CFrame.new(0, 6.0, -4.3) * CFrame.Angles(math.rad(12), 0, 0), light)
	add(head, "Narina", Vector3.new(0.8, 0.2, 0.2), CFrame.new(0, 6.0, -4.86), dark)
	for _, x in { -0.32, 0.32 } do
		add(head, "Orelha", Vector3.new(0.25, 0.65, 0.22), CFrame.new(x, 7.15, -3.05) * CFrame.Angles(math.rad(-10), 0, math.rad(x > 0 and -8 or 8)), color)
		add(head, "Olho", Vector3.new(0.12, 0.22, 0.22), CFrame.new(x * 1.85, 6.5, -3.65), Color3.fromRGB(20, 20, 25))
	end
	add(head, "Crina", Vector3.new(0.38, 3.0, 0.75), CFrame.new(0, 5.55, -2.15) * CFrame.Angles(math.rad(-35), 0, 0), dark, M.Fabric)
	add(head, "Topete", Vector3.new(0.6, 0.45, 0.7), CFrame.new(0, 6.95, -3.35), dark, M.Fabric)
	if saddle then
		add(head, "Redea", Vector3.new(1.2, 0.15, 0.15), CFrame.new(0, 6.0, -4.0), Color3.fromRGB(70, 40, 25))
	end
	-- pernas (coxa, canela e casco)
	for _, leg in { { "PernaFL", -0.65, -1.65 }, { "PernaFR", 0.65, -1.65 }, { "PernaBL", -0.68, 1.75 }, { "PernaBR", 0.68, 1.75 } } do
		local g = group(leg[1])
		local x, z = leg[2], leg[3]
		add(g, "Perna", Vector3.new(0.62, 1.7, 0.7), CFrame.new(x, 2.45, z), color)
		add(g, "Canela", Vector3.new(0.48, 1.35, 0.5), CFrame.new(x, 1.0, z), color)
		add(g, "Casco", Vector3.new(0.6, 0.35, 0.65), CFrame.new(x, 0.18, z - 0.03), hoofColor)
	end
	-- cauda
	local tail = group("Cauda")
	add(tail, "Cauda", Vector3.new(0.5, 2.2, 0.55), CFrame.new(0, 3.6, 2.85) * CFrame.Angles(math.rad(28), 0, 0), dark, M.Fabric)
	add(tail, "Ponta", Vector3.new(0.62, 0.9, 0.62), CFrame.new(0, 2.6, 3.35) * CFrame.Angles(math.rad(28), 0, 0), dark, M.Fabric)
	-- sela
	if saddle then
		add(model, "Manta", Vector3.new(2.5, 0.15, 2.4), CFrame.new(0, 4.73, 0.1), Color3.fromRGB(40, 70, 140), M.Fabric)
		add(model, "Sela", Vector3.new(2.25, 0.45, 1.9), CFrame.new(0, 4.95, 0.1), Color3.fromRGB(110, 55, 30))
		add(model, "Arcao", Vector3.new(1.0, 0.5, 0.35), CFrame.new(0, 5.3, -0.75), Color3.fromRGB(90, 45, 25))
		for _, x in { -1.2, 1.2 } do
			add(model, "Estribo", Vector3.new(0.12, 1.4, 0.12), CFrame.new(x, 4.1, 0.1), Color3.fromRGB(60, 60, 65), M.Metal)
		end
	end
	model.Parent = parent
	return model
end
Town.horse = horse

-- Estábulo: cerca, abrigo, feno e cavalos
function builders.stable(parent, npc)
	local cf = npcFrame(npc) * CFrame.new(0, 0, 12)
	local model = Instance.new("Model")
	model.Name = "Estabulo"
	local w, d = 9, 7
	local function corner(x, z)
		return (cf * CFrame.new(x, 0, z)).Position
	end
	Props.fence(model, corner(-w, -d), corner(-3, -d), 3.2)
	Props.fence(model, corner(3, -d), corner(w, -d), 3.2)
	Props.fence(model, corner(w, -d), corner(w, d), 3.2)
	Props.fence(model, corner(-w, -d), corner(-w, d), 3.2)
	for _, x in { -w, w } do
		part(model, { Name = "Pilar", Size = Vector3.new(0.8, 8, 0.8), CFrame = cf * CFrame.new(x, 4, d), Color = C.DarkWood, Material = M.Wood })
	end
	part(model, { Name = "Fundo", Size = Vector3.new(w * 2, 8, 0.8), CFrame = cf * CFrame.new(0, 4, d + 0.4), Color = Color3.fromRGB(150, 70, 50), Material = M.WoodPlanks })
	Props.roof(model, cf * CFrame.new(0, 8, d - 2), w * 2 + 1, 6, 15, Color3.fromRGB(120, 50, 40))
	for i = 0, 2 do
		part(model, { Name = "Feno", Size = Vector3.new(3, 1.6, 2), CFrame = cf * CFrame.new(-6 + i * 0.4, 0.8 + i * 1.6, 4.5), Color = Color3.fromRGB(220, 190, 90), Material = M.Fabric })
	end
	horse(model, cf * CFrame.new(-2, 0, 0) * CFrame.Angles(0, math.rad(70), 0), Color3.fromRGB(120, 80, 50))
	horse(model, cf * CFrame.new(4, 0, 2) * CFrame.Angles(0, math.rad(-20), 0), Color3.fromRGB(230, 225, 215))
	model.Parent = parent
	return model
end

-- Quadro de recompensas
function builders.board(parent, npc)
	local cf = npcFrame(npc)
	local model = Instance.new("Model")
	model.Name = "Quadro"
	for _, x in { -2.6, 2.6 } do
		part(model, { Name = "Poste", Size = Vector3.new(0.6, 7, 0.6), CFrame = cf * CFrame.new(x, 3.5, 0), Color = C.DarkWood, Material = M.Wood })
	end
	local board = part(model, { Name = "Tabua", Size = Vector3.new(5.6, 3.6, 0.4), CFrame = cf * CFrame.new(0, 4.6, 0), Color = C.Plank, Material = M.WoodPlanks })
	Props.roof(model, cf * CFrame.new(0, 6.9, 0), 6.4, 1.6, 25, C.Roof)
	for i = 0, 4 do
		part(model, { Name = "Cartaz", Size = Vector3.new(1.2, 1.4, 0.1), CFrame = cf * CFrame.new(-2 + i, 4.6 + (if i % 2 == 0 then 0.6 else -0.6), -0.25) * CFrame.Angles(0, 0, math.rad((i - 2) * 4)), Color = Color3.fromRGB(245, 235, 210) })
	end
	model.Parent = parent
	return model, board
end

local function fountain(parent)
	local cf = CFrame.new(World.TownCenter.X, Y, World.TownCenter.Z)
	local model = Instance.new("Model")
	model.Name = "Chafariz"
	Props.column(model, cf, 1.6, 14, C.Stone, M.Cobblestone)
	local water = Props.column(model, cf * CFrame.new(0, 1.2, 0), 0.6, 12.4, Color3.fromRGB(70, 150, 200), M.Glass, { Transparency = 0.3, CanCollide = false })
	Props.column(model, cf, 4.5, 2.6, C.Stone, M.Cobblestone)
	Props.column(model, cf * CFrame.new(0, 4.5, 0), 0.8, 6, C.Stone, M.Cobblestone)
	local top = Props.column(model, cf * CFrame.new(0, 5.3, 0), 2.5, 1.4, C.Stone, M.Cobblestone)
	local spray = Instance.new("ParticleEmitter")
	spray.Color = ColorSequence.new(Color3.fromRGB(180, 220, 255))
	spray.Transparency = NumberSequence.new(0.2, 1)
	spray.Size = NumberSequence.new(0.5, 0.2)
	spray.Lifetime = NumberRange.new(0.8, 1.2)
	spray.Rate = 40
	spray.Speed = NumberRange.new(10, 13)
	spray.SpreadAngle = Vector2.new(18, 18)
	spray.Acceleration = Vector3.new(0, -30, 0)
	spray.EmissionDirection = Enum.NormalId.Right -- eixo X do cilindro aponta para cima
	spray.Parent = top
	water.Name = "Agua"
	model.Parent = parent
	Props.scaleModel(model, cf, K)
	Placement.reserve(cf.X, cf.Z, 9 * K, "chafariz")
end

local function entranceArch(parent)
	local x, z = World.TownCenter.X, World.TownCenter.Z - 74 * K
	local ground = World.height(x, z)
	local cf = CFrame.new(x, ground, z)
	local model = Instance.new("Model")
	model.Name = "Portal da Vila"
	for _, side in { -1, 1 } do
		part(model, { Name = "Pilar", Size = Vector3.new(2, 12, 2), CFrame = cf * CFrame.new(side * 7, 5.5, 0), Color = C.DarkStone, Material = M.Cobblestone })
		Props.fire(model, (cf * CFrame.new(side * 7, 11.5, 0)).Position, 0.7)
	end
	local beam = part(model, { Name = "Viga", Size = Vector3.new(17, 2, 1.6), CFrame = cf * CFrame.new(0, 10.5, 0), Color = C.DarkWood, Material = M.Wood })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = beam
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = C.Gold
	label.Text = "VILA AURORA"
	label.Parent = gui
	for _, side in { -1, 1 } do
		Props.banner(model, cf * CFrame.new(side * 4.2, 9.3, -1), Color3.fromRGB(40, 70, 150))
	end
	model.Parent = parent
	Props.scaleModel(model, cf, K)
	Placement.reserve(x - 7 * K, z, 2.5 * K, "arco")
	Placement.reserve(x + 7 * K, z, 2.5 * K, "arco")
end


-- ===================== VIDA DA VILA =====================

-- ponto em volta da praça (ângulo, raio de projeto) virado para o centro
local function spotFacing(angle, radius)
	local a = math.rad(angle)
	local x = World.TownCenter.X + math.cos(a) * radius * K
	local z = World.TownCenter.Z + math.sin(a) * radius * K
	local yaw = math.atan2(-(World.TownCenter.X - x), -(World.TownCenter.Z - z))
	return x, z, CFrame.new(x, Y, z) * CFrame.Angles(0, yaw, 0)
end

-- tenta cada posição candidata até achar uma livre; build(cf) devolve o modelo (ampliado por K)
local function placeDecor(folder, candidates, radius, build)
	for _, candidate in candidates do
		local x, z, cf = spotFacing(candidate[1], candidate[2])
		-- dentro da vila pode encostar na beira da rua, mas não no meio dela
		if Placement.isFree(x, z, radius * K) and World.roadDistance(x, z) > World.RoadWidth / 2 + radius * K * 0.6 then
			local model = build(cf, candidate)
			if model then
				if model.Parent == nil then
					model.Parent = folder
				end
				Props.scaleModel(model, cf, K)
			end
			Placement.reserve(x, z, radius * K, "enfeite")
			return true
		end
	end
	return false
end

function Town.decorate(folder, rng, lampSpots)
	-- bancos em volta do chafariz, virados para ele
	for i = 0, 3 do
		placeDecor(folder, { { 45 + i * 90, 11.5 } }, 2.4, function(cf)
			return Props.bench(folder, cf)
		end)
	end
	-- feira: barracas de frutas, pães, peixes e tecidos
	local awnings = { Color3.fromRGB(200, 60, 50), Color3.fromRGB(60, 120, 190), Color3.fromRGB(70, 150, 80), Color3.fromRGB(200, 140, 40) }
	local stallSpots = { { -60, 44 }, { -120, 44 }, { 170, 46 }, { -15, 47 }, { 60, 47 }, { 150, 47 } }
	local stalls = 0
	for _, spot in stallSpots do
		if stalls >= 4 then
			break
		end
		if placeDecor(folder, { spot }, 4.5, function(cf)
			stalls += 1
			return Props.marketStall(folder, cf, stalls, awnings[stalls])
		end) then
			continue
		end
	end
	-- poço, carroça, varal e galinheiro
	placeDecor(folder, { { 150, 42 }, { -160, 30 }, { 30, 46 }, { 110, 46 } }, 4, function(cf)
		return Props.well(folder, cf)
	end)
	placeDecor(folder, { { -75, 54 }, { 110, 52 }, { -140, 56 }, { 15, 56 } }, 4, function(cf)
		return Props.cart(folder, cf * CFrame.Angles(0, math.rad(70), 0))
	end)
	placeDecor(folder, { { 175, 54 }, { -20, 56 }, { 80, 58 }, { 230, 50 } }, 5, function(cf)
		return Props.laundry(folder, cf, rng)
	end)
	placeDecor(folder, { { -150, 52 }, { -140, 50 }, { 60, 52 }, { -170, 48 } }, 4, function(cf)
		return Props.coop(folder, cf)
	end)
	-- canteiros de flores em volta da praça
	for i = 0, 7 do
		placeDecor(folder, { { 22 + i * 45, 24 } }, 1.6, function(cf)
			local planter = Instance.new("Model")
			planter.Name = "Canteiro"
			Props.part(planter, { Name = "Base", Size = Vector3.new(3.2, 0.8, 1.4), CFrame = cf * CFrame.new(0, 0.4, 0), Color = C.Stone, Material = M.Cobblestone })
			Props.flowerBox(planter, cf * CFrame.new(0, 1.1, 0), 3, rng)
			planter.Parent = folder
			return planter
		end)
	end
	-- bandeirinhas entre postes vizinhos (só onde não passam por cima de construções)
	for i = 0, 11 do
		local a, b = lampSpots[i], lampSpots[(i + 1) % 12]
		if a and b then
			local mid = (a + b) / 2
			if Placement.isFree(mid.X, mid.Z, 1.5 * K) then
				local top = 7.2 * K
				Props.bunting(folder, a + Vector3.new(0, top, 0), b + Vector3.new(0, top, 0), 1.6 * K)
			end
		end
	end
end

function Town.build(parent, rng)
	local folder = Instance.new("Folder")
	folder.Name = "Vila"
	folder.Parent = parent

	fountain(folder)
	entranceArch(folder)

	-- construções de cada NPC
	local boardPart = nil
	for _, npc in NPCs.List do
		if npc.building and builders[npc.building] then
			local model = builders[npc.building](folder, npc, rng)
			if model and npc.building ~= "training" then
				Props.scaleModel(model, doorFrame(npc), K)
			end
			-- reserva a área da construção (atrás da porta)
			local look = CFrame.Angles(0, npc.yaw, 0).LookVector
			local door = Vector3.new(npc.doorX or npc.x, 0, npc.doorZ or npc.z)
			local back = door - look * 9 * K
			Placement.reserve(back.X, back.Z, 12 * K, npc.building)
		elseif npc.board then
			local model, board = builders.board(folder, npc)
			Props.scaleModel(model, npcFrame(npc), K)
			boardPart = board
		end
		Placement.reserve(npc.x, npc.z, 3 * K, "npc")
	end

	-- casas decorativas em volta
	local houseColors = {
		Color3.fromRGB(235, 220, 190), Color3.fromRGB(200, 170, 130), Color3.fromRGB(220, 200, 170), Color3.fromRGB(180, 150, 120),
	}
	local roofColors = { Color3.fromRGB(150, 60, 45), Color3.fromRGB(70, 80, 120), Color3.fromRGB(110, 70, 50), Color3.fromRGB(60, 100, 70) }
	local houseSpots = { { -125, 74 }, { -60, 74 }, { -12, 76 }, { 40, 82 }, { 105, 76 }, { 145, 74 }, { 195, 76 }, { 232, 72 }, { -165, 70 }, { 165, 62 } }
	for i, spot in houseSpots do
		local a = math.rad(spot[1])
		local x = World.TownCenter.X + math.cos(a) * spot[2] * 0.82 * K
		local z = World.TownCenter.Z + math.sin(a) * spot[2] * 0.82 * K
		if Placement.canPlace(x, z, 10 * K, 2) then
			local yaw = math.atan2(-(World.TownCenter.X - x), -(World.TownCenter.Z - z))
			local w = rng:NextInteger(10, 14)
			local d = rng:NextInteger(9, 12)
			local ground = CFrame.new(x, Y, z) * CFrame.Angles(0, yaw, 0)
			local house = Props.house(folder, ground, w, d, rng:NextInteger(7, 9), houseColors[(i % #houseColors) + 1], roofColors[(i % #roofColors) + 1], rng)
			Props.scaleModel(house, ground, K)
			Placement.reserve(x, z, 10 * K, "casa")
		end
	end

	-- postes de luz em volta da praça e nas estradas
	local lampSpots = {}
	for i = 0, 11 do
		local a = math.rad(15 + i * 30)
		local x = World.TownCenter.X + math.cos(a) * 37 * K
		local z = World.TownCenter.Z + math.sin(a) * 37 * K
		if Placement.isFree(x, z, 2 * K) then
			local ground = CFrame.new(x, Y, z) * CFrame.Angles(0, math.atan2(-(World.TownCenter.X - x), -(World.TownCenter.Z - z)), 0)
			Props.scaleModel(Props.lamp(folder, ground), ground, K)
			Placement.reserve(x, z, 1.5 * K, "poste")
			lampSpots[i] = Vector3.new(x, Y, z)
		end
	end

	-- detalhes: caixas e barris espalhados
	for _ = 1, 14 do
		local a = rng:NextNumber() * math.pi * 2
		local r = rng:NextNumber(38, 66) * K
		local x = World.TownCenter.X + math.cos(a) * r
		local z = World.TownCenter.Z + math.sin(a) * r
		if Placement.canPlace(x, z, 2 * K, 1) then
			local cf = CFrame.new(x, Y, z) * CFrame.Angles(0, rng:NextNumber() * 3, 0)
			if rng:NextNumber() < 0.5 then
				Props.crate(folder, cf, 2.5 * K)
			else
				Props.barrel(folder, cf, K)
			end
			Placement.reserve(x, z, 2 * K, "caixa")
		end
	end

	Town.decorate(folder, rng, lampSpots)
	return boardPart
end

return Town
