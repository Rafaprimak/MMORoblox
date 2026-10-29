-- Vila Aurora: construções dos NPCs, chafariz, casas, postes e entrada.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared.World)
local NPCs = require(Shared.NPCs)
local Enemies = require(Shared.Enemies)
local TownPlan = require(Shared.TownPlan)
local ItemModels = require(Shared.ItemModels)

local Props = require(script.Parent.Props)
local Placement = require(script.Parent.Placement)

local Town = {}

local M = Enum.Material
local C = Props.Colors
local part = Props.part
local Y = World.TownHeight
-- Construções são desenhadas em tamanho "de design" e ampliadas por K (proporcional ao personagem)
local K = World.PropScale

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

-- Alturas dos móveis em unidades de PROJETO (o modelo é ampliado ×K): balcão ~1,8 (≈ cintura do
-- personagem depois de ampliado), mesa ~1,9, bigorna ~1,7. Nada passa da altura do peito do NPC.

-- FERRARIA: tijolos escuros, porta larga, chão de pedra, fornalha acesa no fundo, bigorna, bancada,
-- suportes de armas e, do lado de fora, um pátio de trabalho com forja aberta e tina de têmpera.
function builders.forge(parent, npc, rng)
	local cf = doorFrame(npc)
	local model = Props.building(parent, cf, 18, 16, 10, Color3.fromRGB(125, 72, 58), Color3.fromRGB(55, 55, 62), {
		name = "Ferraria",
		doorWidth = 6,
		chimney = -5,
		wallMaterial = M.Brick,
		roofMaterial = M.Slate,
		floor = "stone",
		trim = Color3.fromRGB(45, 45, 52),
		lights = { Vector3.new(4, 9, 5), Vector3.new(-3, 9, 11) },
	})
	local inside = cf * CFrame.new(0, 1.2, 0)
	-- fornalha de tijolos no canto do fundo (brasa na altura do peito)
	part(model, { Name = "Fornalha", Size = Vector3.new(6, 4.5, 3.5), CFrame = inside * CFrame.new(-5, 2.25, 13.6), Color = Color3.fromRGB(110, 55, 45), Material = M.Brick })
	local opening = part(model, { Name = "Brasa", Size = Vector3.new(3.4, 1.6, 0.3), CFrame = inside * CFrame.new(-5, 1.5, 11.8), Color = C.Fire, Material = M.Neon })
	Props.light(opening, C.Fire, 24, 3, true)
	Props.fire(model, (inside * CFrame.new(-5, 0.5, 12.6)).Position, 0.6)
	-- bigorna no meio (cintura)
	local anvil = inside * CFrame.new(2.5, 0, 5.5)
	part(model, { Name = "Toco", Size = Vector3.new(1.4, 1.0, 1.4), CFrame = anvil * CFrame.new(0, 0.5, 0), Color = C.DarkWood, Material = M.Wood })
	part(model, { Name = "BigornaBase", Size = Vector3.new(0.9, 0.4, 0.8), CFrame = anvil * CFrame.new(0, 1.2, 0), Color = Color3.fromRGB(45, 45, 50), Material = M.Metal })
	part(model, { Name = "Bigorna", Size = Vector3.new(2.2, 0.45, 0.9), CFrame = anvil * CFrame.new(0, 1.6, 0), Color = Color3.fromRGB(70, 70, 78), Material = M.Metal })
	part(model, { Name = "Ponta", Size = Vector3.new(0.8, 0.3, 0.5), CFrame = anvil * CFrame.new(-1.4, 1.65, 0), Color = Color3.fromRGB(70, 70, 78), Material = M.Metal })
	part(model, { Name = "Martelo", Size = Vector3.new(0.15, 0.15, 1.1), CFrame = anvil * CFrame.new(0.5, 1.9, 0.1) * CFrame.Angles(0, 0.5, 0), Color = C.DarkWood, Material = M.Wood })
	-- bancada com ferramentas e lingotes
	Props.table(model, inside * CFrame.new(6.3, 0, 12.5), 4, 2, 1.9, C.DarkWood)
	for i = -1, 1 do
		part(model, { Name = "Lingote", Size = Vector3.new(0.8, 0.3, 0.4), CFrame = inside * CFrame.new(6.3 + i * 1.1, 2.2, 12.5), Color = if i == 0 then C.Gold else Color3.fromRGB(150, 150, 160), Material = M.Metal })
	end
	-- suportes de armas nas paredes laterais
	for _, side in { -1, 1 } do
		local wall = inside * CFrame.new(side * 8.2, 0, 8) * CFrame.Angles(0, math.rad(side * 90), 0)
		part(model, { Name = "Suporte", Size = Vector3.new(6, 0.3, 0.3), CFrame = wall * CFrame.new(0, 3.2, 0), Color = C.DarkWood, Material = M.Wood })
		for i = -2, 2 do
			part(model, { Name = "Lamina", Size = Vector3.new(0.25, 2.4, 0.1), CFrame = wall * CFrame.new(i * 1.15, 2.2, -0.25), Color = Color3.fromRGB(175, 175, 185), Material = M.Metal })
			part(model, { Name = "Guarda", Size = Vector3.new(0.7, 0.15, 0.2), CFrame = wall * CFrame.new(i * 1.15, 3.4, -0.25), Color = C.Gold, Material = M.Metal })
		end
	end
	Props.barrel(model, inside * CFrame.new(-7, 0, 2), 0.75)
	-- pátio de trabalho do lado de fora (forja aberta, tina de têmpera, amolador e lenha)
	local yard = cf * CFrame.new(-1, 0, -1) * CFrame.new(0, 0, 0)
	local side = cf * CFrame.new(-12.5, 0, 5)
	part(model, { Name = "PisoPatio", Size = Vector3.new(6, 0.3, 10), CFrame = side * CFrame.new(0, 0.15, 0), Color = Color3.fromRGB(100, 95, 90), Material = M.Slate })
	part(model, { Name = "ForjaAberta", Size = Vector3.new(3, 2, 3), CFrame = side * CFrame.new(0, 1, 2.5), Color = Color3.fromRGB(100, 55, 45), Material = M.Brick })
	local coal = part(model, { Name = "Carvao", Size = Vector3.new(2.4, 0.3, 2.4), CFrame = side * CFrame.new(0, 2.1, 2.5), Color = C.Fire, Material = M.Neon })
	Props.light(coal, C.Fire, 14, 1.5)
	Props.smoke(coal, 2)
	part(model, { Name = "Tina", Size = Vector3.new(2.6, 1.2, 1.4), CFrame = side * CFrame.new(0, 0.6, -1.5), Color = C.Wood, Material = M.WoodPlanks })
	part(model, { Name = "Agua", Size = Vector3.new(2.3, 0.1, 1.1), CFrame = side * CFrame.new(0, 1.15, -1.5), Color = Color3.fromRGB(60, 110, 150), Material = M.Glass, Transparency = 0.2 })
	for i = 0, 2 do
		part(model, { Name = "Lenha", Size = Vector3.new(0.6, 0.6, 3), CFrame = side * CFrame.new(-1 + i * 0.7, 0.3, -4) * CFrame.Angles(0, math.rad(90), 0), Color = C.Wood, Material = M.Wood })
	end
	local _y = yard
	-- placa de ferro com martelo e espada
	local sign = part(model, { Name = "Placa", Size = Vector3.new(4.5, 2, 0.3), CFrame = cf * CFrame.new(0, 9.4, -0.5), Color = Color3.fromRGB(50, 50, 58), Material = M.Metal })
	part(model, { Name = "Simbolo", Size = Vector3.new(0.3, 1.5, 0.35), CFrame = cf * CFrame.new(-0.5, 9.4, -0.6) * CFrame.Angles(0, 0, math.rad(35)), Color = C.Fire, Material = M.Neon })
	part(model, { Name = "Simbolo", Size = Vector3.new(0.3, 1.5, 0.35), CFrame = cf * CFrame.new(0.5, 9.4, -0.6) * CFrame.Angles(0, 0, math.rad(-35)), Color = C.Fire, Material = M.Neon })
	Props.engrave(sign, "FERRARIA", C.Fire)
	Props.readable(sign, "Ferraria do Bruno", "Aqui o aço é forjado, aprimorado e fundido. O Bruno diz que \"aço não esquece\": o que você forja continua com você mesmo quando o dia volta. Serviços: forjar, aprimorar, desmontar, reforjar perks e fundir 9 itens iguais em 1 melhor.", 18)
	local _r = rng
	return model
end

-- ALQUIMIA: chalé de enxaimel (reboco verde-claro com vigas escuras), telhado roxo, chão de tábuas com
-- tapete, prateleiras de frascos, caldeirão, ervas penduradas e, do lado de fora, uma horta de ervas.
function builders.alchemy(parent, npc, rng)
	local cf = doorFrame(npc)
	local model = Props.building(parent, cf, 16, 15, 9, Color3.fromRGB(205, 225, 190), Color3.fromRGB(95, 60, 140), {
		name = "Alquimia",
		chimney = 4,
		wallMaterial = M.Plaster,
		floor = "planks",
		floorColor = Color3.fromRGB(150, 105, 70),
		timbered = true,
	})
	local inside = cf * CFrame.new(0, 1.2, 0)
	Props.shelf(model, inside * CFrame.new(-3, 0, 14) * CFrame.Angles(0, math.rad(180), 0), 7, 3, "potions", rng)
	Props.shelf(model, inside * CFrame.new(-7.3, 0, 8) * CFrame.Angles(0, math.rad(-90), 0), 6, 3, "potions", rng)
	Props.shelf(model, inside * CFrame.new(7.3, 0, 10) * CFrame.Angles(0, math.rad(90), 0), 5, 2, "books", rng)
	-- caldeirão (borda na altura da cintura)
	local cauldronCf = inside * CFrame.new(4, 0, 11)
	local cauldron = Props.column(model, cauldronCf, 1.5, 2.8, Color3.fromRGB(40, 40, 45), M.Metal)
	cauldron.Name = "Caldeirao"
	local liquid = Props.column(model, cauldronCf * CFrame.new(0, 1.35, 0), 0.25, 2.4, Color3.fromRGB(90, 255, 120), M.Neon)
	Props.light(liquid, Color3.fromRGB(90, 255, 120), 14, 1.5)
	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Color = ColorSequence.new(Color3.fromRGB(150, 255, 170))
	bubbles.LightEmission = 0.8
	bubbles.Size = NumberSequence.new(0.4, 0.1)
	bubbles.Lifetime = NumberRange.new(0.6, 1.2)
	bubbles.Rate = 10
	bubbles.Speed = NumberRange.new(1.5, 3)
	bubbles.Parent = liquid
	-- balcão (cintura) com frascos
	part(model, { Name = "Balcao", Size = Vector3.new(7, 1.7, 1.4), CFrame = inside * CFrame.new(-1, 0.85, 6.5), Color = C.Wood, Material = M.WoodPlanks })
	part(model, { Name = "Tampo", Size = Vector3.new(7.4, 0.2, 1.8), CFrame = inside * CFrame.new(-1, 1.8, 6.5), Color = C.DarkWood, Material = M.Wood })
	for i = -2, 2 do
		part(model, { Name = "Frasco", Size = Vector3.new(0.45, 0.7, 0.45), CFrame = inside * CFrame.new(-1 + i * 1.3, 2.25, 6.4), Color = Color3.fromHSV((i + 2) / 5, 0.7, 1), Material = M.Neon, Transparency = 0.2 })
	end
	-- ervas penduradas nos caibros
	for i = 0, 5 do
		part(model, { Name = "Erva", Size = Vector3.new(0.5, 1.2, 0.5), CFrame = inside * CFrame.new(-6 + i * 2.4, 7.1, 3), Color = Color3.fromRGB(90, 150 + i * 10, 70), Material = M.Grass })
	end
	Props.rug(model, cf * CFrame.new(0, 0, 4), 6, 4, Color3.fromRGB(110, 50, 120), Color3.fromRGB(220, 190, 90))
	-- horta de ervas do lado de fora, com cerquinha
	local garden = cf * CFrame.new(11.5, 0, 6)
	for row = 0, 3 do
		for i = 0, 2 do
			local color = ({ Color3.fromRGB(80, 170, 70), Color3.fromRGB(150, 90, 200), Color3.fromRGB(230, 200, 70), Color3.fromRGB(70, 140, 200) })[row + 1]
			Props.ball(model, (garden * CFrame.new(-1.6 + i * 1.6, 0.5, -4 + row * 2.4)).Position, 1.1, color, M.Grass, { CanCollide = false })
		end
	end
	local g1, g2 = (garden * CFrame.new(-2.8, 0, -5.5)).Position, (garden * CFrame.new(2.8, 0, -5.5)).Position
	local g3, g4 = (garden * CFrame.new(2.8, 0, 4.5)).Position, (garden * CFrame.new(-2.8, 0, 4.5)).Position
	Props.fence(model, g1, g2, 1.6, Color3.fromRGB(230, 225, 210))
	Props.fence(model, g2, g3, 1.6, Color3.fromRGB(230, 225, 210))
	Props.fence(model, g4, g1, 1.6, Color3.fromRGB(230, 225, 210))
	-- placa em forma de frasco
	local sign = part(model, { Name = "PlacaFrasco", Size = Vector3.new(1.6, 1.6, 0.3), Shape = Enum.PartType.Ball, CFrame = cf * CFrame.new(0, 9.0, -1.0), Color = Color3.fromRGB(110, 230, 140), Material = M.Neon })
	part(model, { Name = "Gargalo", Size = Vector3.new(0.5, 0.8, 0.3), CFrame = cf * CFrame.new(0, 10.0, -1.0), Color = Color3.fromRGB(110, 230, 140), Material = M.Neon })
	-- tabuleta embaixo do frasco (o frasco é redondo, não dá para gravar)
	local board = part(model, { Name = "Tabuleta", Size = Vector3.new(3.6, 1.1, 0.25), CFrame = cf * CFrame.new(0, 7.7, -1.0), Color = Color3.fromRGB(112, 74, 42), Material = M.WoodPlanks })
	Props.engrave(board, "ALQUIMIA", Color3.fromRGB(150, 255, 170))
	Props.readable(board, "Alquimia da Mira", "Ervas, cogumelos e flores lunares viram poções de vida, mana e vigor. Mira guarda num caderno tudo o que cada dia repetido apaga da memória dela.", 18)
	return model
end

-- Torre do encantador (Elric): torre de mago em três partes.
--   Base: pedestal em degraus, salão redondo em fiadas de pedra de dois tons, contrafortes, porta em arco
--   com batentes e pedra-chave dourada, janelas com peitoril, lanternas, runas no chão e hera.
--   Meio: cornija com sacada de balaústres, fuste mais estreito com janelas em fenda e estandartes.
--   Topo: "chapéu de bruxo" em gomos com a ponta torta, faixa dourada e cristal flutuante com auréola.
--   Dentro (salão): chão de mármore com círculo mágico, estantes, mesa de encantar e orbe flutuante.
-- Peças vizinhas nunca dividem a mesma face (sem tremido): cada camada é um pouco maior ou menor.
function builders.tower(parent, npc, rng)
	local cf = doorFrame(npc)
	local radius = 9
	local center = cf * CFrame.new(0, 0, radius)
	local model = Instance.new("Model")
	model.Name = "TorreEncantador"
	local stoneA = Color3.fromRGB(132, 122, 156)
	local stoneB = Color3.fromRGB(108, 99, 132)
	local trim = Color3.fromRGB(72, 60, 96)
	local roofA = Color3.fromRGB(82, 48, 142)
	local roofB = Color3.fromRGB(64, 36, 116)
	local gold = Color3.fromRGB(226, 186, 96)
	local glass = Color3.fromRGB(200, 150, 255)

	-- ===== pedestal e piso =====
	Props.column(model, center * CFrame.new(0, -0.6, 0), 1.0, radius * 2 + 2.6, C.DarkStone, M.Slate)
	Props.column(model, center * CFrame.new(0, 0.4, 0), 0.6, radius * 2 + 1.4, trim, M.Slate)
	part(model, { Name = "Degrau", Size = Vector3.new(6.4, 0.5, 2.2), CFrame = cf * CFrame.new(0, 0.25, -1.7), Color = C.Stone, Material = M.Cobblestone })
	part(model, { Name = "DegrauAlto", Size = Vector3.new(5.6, 0.45, 1.2), CFrame = cf * CFrame.new(0, 0.72, -0.9), Color = C.Stone:Lerp(Color3.new(1, 1, 1), 0.08), Material = M.Cobblestone })
	part(model, { Name = "Piso", Size = Vector3.new(0.3, radius * 2 - 1, radius * 2 - 1), Shape = Enum.PartType.Cylinder, CFrame = center * CFrame.new(0, 1.05, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(225, 220, 235), Material = M.Marble })

	-- ===== salão: paredes em 3 fiadas (a frente vira o vão da porta) =====
	local segments = 20
	local wallHeight = 12
	local course = wallHeight / 3
	local doorHeight = 8
	local width = 2 * radius * math.tan(math.pi / segments) + 0.3
	for i = 0, segments - 1 do
		local angle = (i + 0.5) / segments * math.pi * 2
		local frame = center * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -radius)
		local isDoor = i == 0 or i == segments - 1
		for c = 0, 2 do
			local bottom = 1 + c * course
			if not (isDoor and bottom < doorHeight) then
				part(model, { Name = "Parede", Size = Vector3.new(width, course, 1), CFrame = frame * CFrame.new(0, bottom + course / 2, 0), Color = if (c + i) % 2 == 0 then stoneA else stoneB, Material = M.Brick })
			end
		end
		-- janelas com peitoril e vidro mágico (acendem à noite)
		if i == 5 or i == 9 or i == 10 or i == 14 then
			local glassPart = part(model, { Name = "Janela", Size = Vector3.new(1.5, 2.8, 0.2), CFrame = frame * CFrame.new(0, 7.6, -0.55), Color = glass, Material = M.Neon })
			Props.nightWindow(glassPart)
			part(model, { Name = "Peitoril", Size = Vector3.new(2.3, 0.35, 1.2), CFrame = frame * CFrame.new(0, 6.0, -0.8), Color = trim, Material = M.Slate })
			part(model, { Name = "VergaJanela", Size = Vector3.new(2.1, 0.5, 1.1), CFrame = frame * CFrame.new(0, 9.25, -0.75), Color = trim, Material = M.Slate })
		end
		-- hera subindo em alguns pontos
		if not isDoor and rng:NextNumber() < 0.3 then
			for leaf = 1, rng:NextInteger(2, 4) do
				part(model, { Name = "Hera", Size = Vector3.new(rng:NextNumber(0.8, 1.6), rng:NextNumber(0.8, 1.4), 0.12), CFrame = frame * CFrame.new(rng:NextNumber(-0.6, 0.6), 1.2 + leaf * rng:NextNumber(0.8, 1.3), -0.58), Color = Color3.fromRGB(60, 110, 55):Lerp(Color3.fromRGB(90, 140, 60), rng:NextNumber()), Material = M.Grass, CanCollide = false })
			end
		end
	end
	-- contrafortes (fora da porta), com sapata mais larga embaixo
	for _, degrees in { 54, 108, 162, 198, 252, 306 } do
		local frame = center * CFrame.Angles(0, math.rad(degrees), 0) * CFrame.new(0, 0, -(radius + 0.55))
		part(model, { Name = "Contraforte", Size = Vector3.new(1.3, wallHeight - 1, 1.3), CFrame = frame * CFrame.new(0, 1 + (wallHeight - 1) / 2, 0), Color = trim, Material = M.Slate })
		part(model, { Name = "Sapata", Size = Vector3.new(1.8, 2.4, 1.9), CFrame = frame * CFrame.new(0, 2.2, -0.1), Color = C.DarkStone, Material = M.Slate })
	end
	-- porta: batentes, arco de aduelas e pedra-chave dourada; runa brilhando em cima
	local doorWall = cf * CFrame.new(0, 0, 0.2)
	local opening = width * 2 - 0.6
	for _, side in { -1, 1 } do
		part(model, { Name = "Batente", Size = Vector3.new(0.9, doorHeight - 1, 1.6), CFrame = doorWall * CFrame.new(side * (opening / 2 + 0.45), 1 + (doorHeight - 1) / 2, 0), Color = trim, Material = M.Slate })
		-- lanterna dos dois lados
		local lantern = part(model, { Name = "Lanterna", Size = Vector3.new(0.7, 1.0, 0.7), CFrame = doorWall * CFrame.new(side * (opening / 2 + 1.6), 5.6, -1.0), Color = Color3.fromRGB(255, 200, 120), Material = M.Neon })
		Props.nightLight(lantern)
		part(model, { Name = "BracoLanterna", Size = Vector3.new(0.2, 0.2, 2.2), CFrame = doorWall * CFrame.new(side * (opening / 2 + 1.6), 6.2, 0), Color = Color3.fromRGB(40, 36, 44), Material = M.Metal })
		part(model, { Name = "TampaLanterna", Size = Vector3.new(0.9, 0.25, 0.9), CFrame = doorWall * CFrame.new(side * (opening / 2 + 1.6), 6.2, -1.0), Color = Color3.fromRGB(40, 36, 44), Material = M.Metal })
		-- runa no chão, ao lado da entrada
		part(model, { Name = "RunaChao", Size = Vector3.new(1.1, 0.06, 1.1), CFrame = cf * CFrame.new(side * 4.2, 0.03, -2.2) * CFrame.Angles(0, math.rad(45), 0), Color = glass, Material = M.Neon, Transparency = 0.25, CanCollide = false })
	end
	for k = 0, 6 do
		local a = math.pi * k / 6
		local r = opening / 2 + 0.45
		part(model, { Name = "AduelaPorta", Size = Vector3.new(0.9, 0.8, 1.6), CFrame = doorWall * CFrame.new(math.cos(a) * r, doorHeight + math.sin(a) * 0.9, 0) * CFrame.Angles(0, 0, a - math.pi / 2), Color = if k == 3 then gold else trim, Material = if k == 3 then M.Metal else M.Slate })
	end
	local rune = part(model, { Name = "RunaPorta", Size = Vector3.new(0.9, 0.9, 0.12), CFrame = doorWall * CFrame.new(0, doorHeight + 2.3, -0.86) * CFrame.Angles(0, 0, math.rad(45)), Color = glass, Material = M.Neon })
	Props.light(rune, glass, 10, 1)

	-- ===== cornija e sacada (vira o teto do salão) =====
	local top = 1 + wallHeight
	Props.column(model, center * CFrame.new(0, top, 0), 0.7, radius * 2 + 1.8, trim, M.Slate)
	Props.column(model, center * CFrame.new(0, top + 0.7, 0), 0.5, radius * 2 + 2.6, C.DarkStone, M.Slate)
	local deck = top + 1.2
	local posts = 24
	for i = 0, posts - 1 do
		local angle = i / posts * math.pi * 2
		local frame = center * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -(radius + 0.9))
		part(model, { Name = "Balaustre", Size = Vector3.new(0.35, 1.4, 0.35), CFrame = frame * CFrame.new(0, deck + 0.7, 0), Color = stoneA, Material = M.Slate })
		part(model, { Name = "Corrimao", Size = Vector3.new(2 * (radius + 0.9) * math.tan(math.pi / posts) + 0.2, 0.3, 0.5), CFrame = center * CFrame.Angles(0, angle + math.pi / posts, 0) * CFrame.new(0, deck + 1.55, -(radius + 0.9) * math.cos(math.pi / posts)), Color = trim, Material = M.Slate })
	end

	-- ===== fuste (parte de cima da torre) =====
	local shaftRadius = 6
	local shaftHeight = 14
	local bands = 4
	for b = 0, bands - 1 do
		local h = shaftHeight / bands
		Props.column(model, center * CFrame.new(0, deck + b * h, 0), h, shaftRadius * 2 + (if b % 2 == 0 then 0 else -0.2), if b % 2 == 0 then stoneA else stoneB, M.Brick)
	end
	-- janelas em fenda no fuste
	for _, degrees in { 0, 120, 240 } do
		local frame = center * CFrame.Angles(0, math.rad(degrees), 0) * CFrame.new(0, 0, -shaftRadius)
		Props.nightWindow(part(model, { Name = "Fenda", Size = Vector3.new(0.9, 3.4, 0.25), CFrame = frame * CFrame.new(0, deck + 8, -0.05), Color = glass, Material = M.Neon }))
		part(model, { Name = "MolduraFenda", Size = Vector3.new(1.5, 0.35, 0.8), CFrame = frame * CFrame.new(0, deck + 9.9, -0.2), Color = trim, Material = M.Slate })
	end
	-- estandartes roxos com estrela dourada, pendurados no fuste
	for _, degrees in { -55, 55 } do
		local frame = center * CFrame.Angles(0, math.rad(degrees), 0) * CFrame.new(0, 0, -(shaftRadius + 0.12))
		part(model, { Name = "Estandarte", Size = Vector3.new(2.2, 5.2, 0.12), CFrame = frame * CFrame.new(0, deck + 6.2, 0), Color = Color3.fromRGB(96, 46, 150), Material = M.Fabric })
		part(model, { Name = "BarraEstandarte", Size = Vector3.new(2.8, 0.25, 0.25), CFrame = frame * CFrame.new(0, deck + 8.9, -0.1), Color = gold, Material = M.Metal })
		part(model, { Name = "EstrelaEstandarte", Size = Vector3.new(0.9, 0.9, 0.08), CFrame = frame * CFrame.new(0, deck + 6.6, -0.1) * CFrame.Angles(0, 0, math.rad(45)), Color = gold, Material = M.Neon })
		part(model, { Name = "PontaEstandarte", Size = Vector3.new(1.1, 1.1, 0.12), CFrame = frame * CFrame.new(0, deck + 3.6, 0) * CFrame.Angles(0, 0, math.rad(45)), Color = Color3.fromRGB(96, 46, 150), Material = M.Fabric })
	end
	-- mísulas segurando o chapéu
	local hatBase = deck + shaftHeight
	Props.column(model, center * CFrame.new(0, hatBase, 0), 0.8, shaftRadius * 2 + 1.4, trim, M.Slate)

	-- ===== chapéu de bruxo: aba, gomos afinando e ponta torta =====
	Props.column(model, center * CFrame.new(0, hatBase + 0.8, 0), 0.7, shaftRadius * 2 + 4.6, roofB, M.Slate)
	Props.column(model, center * CFrame.new(0, hatBase + 1.52, 0), 0.6, shaftRadius * 2 + 3.8, gold, M.Metal)
	local frame = center * CFrame.new(0, hatBase + 1.55, 0) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local layers = 11
	for i = 1, layers do
		local t = (i - 1) / layers
		local diameter = (shaftRadius * 2 + 2.4) * (1 - t) ^ 1.15 + 0.7
		Props.column(model, frame, 1.9, diameter, if i % 2 == 0 then roofA else roofB, M.Slate)
		local bend = if i > 6 then (i - 6) * 5 else 0
		frame = frame * CFrame.new(0, 1.75, 0) * CFrame.Angles(math.rad(bend), 0, 0)
	end
	-- cristal flutuando sobre a ponta, com auréola girando
	local crystal = part(model, { Name = "Cristal", Size = Vector3.new(1.8, 1.8, 1.8), CFrame = frame * CFrame.new(0, 2.2, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)), Color = glass, Material = M.Neon, CanCollide = false })
	Props.light(crystal, Color3.fromRGB(190, 120, 255), 34, 2)
	CollectionService:AddTag(crystal, "Spin")
	local halo = part(model, { Name = "Aureola", Size = Vector3.new(0.12, 3.6, 3.6), Shape = Enum.PartType.Cylinder, CFrame = frame * CFrame.new(0, 2.2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = gold, Material = M.Neon, Transparency = 0.35, CanCollide = false })
	CollectionService:AddTag(halo, "Spin")

	-- ===== interior =====
	local inside = center * CFrame.new(0, 1.2, 0)
	for _, angle in { 70, 110, 250, 290 } do
		Props.shelf(model, inside * CFrame.Angles(0, math.rad(angle), 0) * CFrame.new(0, 0, -(radius - 1.2)) * CFrame.Angles(0, math.rad(180), 0), 4, 3, "books", rng)
	end
	part(model, { Name = "Circulo", Size = Vector3.new(0.1, 8, 8), Shape = Enum.PartType.Cylinder, CFrame = inside * CFrame.new(0, 0.02, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(180, 120, 255), Material = M.Neon, Transparency = 0.5, CanCollide = false })
	part(model, { Name = "CirculoInterno", Size = Vector3.new(0.12, 5, 5), Shape = Enum.PartType.Cylinder, CFrame = inside * CFrame.new(0, 0.03, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(60, 40, 90), Material = M.Marble, CanCollide = false })
	Props.table(model, inside * CFrame.new(0, 0, 3), 3.6, 2.2, 1.9, Color3.fromRGB(70, 50, 90))
	part(model, { Name = "Livro", Size = Vector3.new(1.4, 0.25, 1), CFrame = inside * CFrame.new(0, 2.2, 3) * CFrame.Angles(0, math.rad(15), 0), Color = Color3.fromRGB(120, 40, 60) })
	part(model, { Name = "Vela", Size = Vector3.new(0.2, 0.5, 0.2), CFrame = inside * CFrame.new(1.3, 2.32, 2.6), Color = Color3.fromRGB(240, 230, 210) })
	Props.light(part(model, { Name = "ChamaVela", Size = Vector3.new(0.14, 0.22, 0.14), CFrame = inside * CFrame.new(1.3, 2.68, 2.6), Color = C.Fire, Material = M.Neon, CanCollide = false }), C.Fire, 8, 1)
	local orb = part(model, { Name = "Orbe", Size = Vector3.one * 1.0, Shape = Enum.PartType.Ball, CFrame = inside * CFrame.new(0, 3.4, 3), Color = Color3.fromRGB(200, 150, 255), Material = M.Neon, CanCollide = false })
	Props.light(orb, Color3.fromRGB(190, 130, 255), 22, 2, true)
	CollectionService:AddTag(orb, "Spin")
	-- lustre de velas no meio do salão (pendurado no teto)
	part(model, { Name = "Corrente", Size = Vector3.new(0.12, 4.1, 0.12), CFrame = inside * CFrame.new(0, wallHeight - 2.22, 0), Color = Color3.fromRGB(40, 36, 44), Material = M.Metal, CanCollide = false })
	Props.column(model, inside * CFrame.new(0, wallHeight - 4.3, 0), 0.25, 3, Color3.fromRGB(50, 44, 54), M.Metal, { CanCollide = false })
	for k = 0, 4 do
		local a = k / 5 * math.pi * 2
		local flame = part(model, { Name = "VelaLustre", Size = Vector3.new(0.18, 0.4, 0.18), CFrame = inside * CFrame.new(math.cos(a) * 1.3, wallHeight - 4.05 + 0.2, math.sin(a) * 1.3), Color = C.Fire, Material = M.Neon, CanCollide = false })
		if k == 0 then
			Props.light(flame, C.Fire, 16, 1.2)
		end
	end
	model.Parent = parent
	Props.readable(crystal, "Torre do Arquimago Elric", "Elric é um dos três arquimagos que ergueram o Orbe Infinito em volta do vale. Na torre ele encanta armas com a essência dos monstros: a mesma mana que os mudou, agora domada.", 18)
	return model
end

-- EMPÓRIO: loja de madeira clara com acabamento vermelho, vitrines, chão quadriculado, balcão,
-- prateleiras, baús e ovos de pet em exposição; caixotes e sacos de mercadoria na frente.
function builders.emporium(parent, npc, rng)
	local cf = doorFrame(npc)
	local model = Props.building(parent, cf, 18, 15, 9, Color3.fromRGB(235, 210, 165), Color3.fromRGB(170, 55, 45), {
		name = "Emporio",
		doorWidth = 5,
		floor = "checker",
		trim = Color3.fromRGB(160, 40, 40),
	})
	local inside = cf * CFrame.new(0, 1.2, 0)
	-- toldo listrado sobre a porta e vitrines
	for i = 0, 9 do
		local color = if i % 2 == 0 then Color3.fromRGB(200, 50, 45) else Color3.fromRGB(245, 235, 220)
		part(model, { Name = "Toldo", Size = Vector3.new(1.4, 0.25, 3), CFrame = cf * CFrame.new(-6.3 + i * 1.4, 8, -1.5) * CFrame.Angles(math.rad(-18), 0, 0), Color = color, Material = M.Fabric })
	end
	-- vitrines do lado de fora, embaixo das janelas: móvel de madeira, tampo vermelho e redoma de vidro
	for _, x in { -5.6, 5.6 } do
		local stand = cf * CFrame.new(x, 0, -1.1)
		part(model, { Name = "Vitrine", Size = Vector3.new(3, 1.5, 0.9), CFrame = stand * CFrame.new(0, 0.75, 0), Color = C.DarkWood, Material = M.WoodPlanks })
		part(model, { Name = "TampoVitrine", Size = Vector3.new(3.2, 0.15, 1.05), CFrame = stand * CFrame.new(0, 1.575, 0), Color = Color3.fromRGB(160, 40, 40), Material = M.Wood })
		part(model, { Name = "Redoma", Size = Vector3.new(2.9, 1.0, 0.85), CFrame = stand * CFrame.new(0, 2.15, 0), Color = Color3.fromRGB(200, 230, 255), Material = M.Glass, Transparency = 0.6, CanCollide = false })
		for j = -1, 1 do
			Props.ball(model, (stand * CFrame.new(j * 0.9, 1.95, 0)).Position, 0.6, Color3.fromHSV((x + j + 6) / 12, 0.6, 1), M.SmoothPlastic, { CanCollide = false })
		end
	end
	-- balcão (cintura)
	part(model, { Name = "Balcao", Size = Vector3.new(10, 1.7, 1.4), CFrame = inside * CFrame.new(0, 0.85, 6.5), Color = C.Plank, Material = M.WoodPlanks })
	part(model, { Name = "Tampo", Size = Vector3.new(10.4, 0.2, 1.8), CFrame = inside * CFrame.new(0, 1.8, 6.5), Color = Color3.fromRGB(150, 40, 40), Material = M.Wood })
	part(model, { Name = "Balanca", Size = Vector3.new(1.2, 0.25, 0.7), CFrame = inside * CFrame.new(3, 2.0, 6.4), Color = C.Gold, Material = M.Metal })
	for i = -1, 1 do
		Props.ball(model, (inside * CFrame.new(-3 + i * 0.8, 2.2, 6.4)).Position, 0.6, Color3.fromRGB(240, 60, 60), M.SmoothPlastic, { CanCollide = false })
	end
	Props.shelf(model, inside * CFrame.new(0, 0, 13.9) * CFrame.Angles(0, math.rad(180), 0), 10, 3, "goods", rng)
	Props.shelf(model, inside * CFrame.new(-8.3, 0, 9) * CFrame.Angles(0, math.rad(-90), 0), 6, 2, "potions", rng)
	-- baús em exposição (bronze, prata, real)
	local chestColors = { Color3.fromRGB(205, 130, 70), Color3.fromRGB(200, 205, 220), Color3.fromRGB(255, 200, 50) }
	for i, color in chestColors do
		local chest = inside * CFrame.new(-7.2 + (i - 1) * 2.1, 0, 3)
		part(model, { Name = "Bau", Size = Vector3.new(1.6, 1.0, 1.1), CFrame = chest * CFrame.new(0, 0.5, 0), Color = C.DarkWood, Material = M.Wood })
		part(model, { Name = "Tampa", Size = Vector3.new(1.7, 0.45, 1.2), CFrame = chest * CFrame.new(0, 1.2, 0), Color = color, Material = M.Metal })
	end
	-- pedestal com ovos de pet
	local pedestal = inside * CFrame.new(6, 0, 3)
	Props.column(model, pedestal, 1.6, 2.4, C.Stone, M.Marble)
	for i, color in { Color3.fromRGB(230, 220, 200), Color3.fromRGB(110, 170, 255), Color3.fromRGB(255, 190, 50) } do
		part(model, { Name = "Ovo", Size = Vector3.new(0.8, 1.05, 0.8), Shape = Enum.PartType.Ball, CFrame = pedestal * CFrame.new(-0.8 + (i - 1) * 0.8, 2.1, 0), Color = color, Material = if i == 3 then M.Neon else M.SmoothPlastic })
	end
	-- mercadoria na frente da loja
	Props.crate(model, cf * CFrame.new(7.5, 0, -2.8), 1.8)
	Props.crate(model, cf * CFrame.new(7.8, 1.8, -2.7), 1.2)
	Props.barrel(model, cf * CFrame.new(-7.5, 0, -2.9), 0.8)
	for i = 0, 1 do
		part(model, { Name = "Saco", Size = Vector3.new(1.2, 1.4, 1), CFrame = cf * CFrame.new(-5.6 + i * 1.3, 0.7, -2.6), Color = Color3.fromRGB(200, 180, 130), Material = M.Fabric })
	end
	local sign = part(model, { Name = "Placa", Size = Vector3.new(7, 1.8, 0.3), CFrame = cf * CFrame.new(0, 9.6, -0.65), Color = Color3.fromRGB(150, 40, 40), Material = M.WoodPlanks })
	Props.engrave(sign, "EMPÓRIO DO OTTO", C.Gold)
	Props.readable(sign, "Empório do Otto", "Tudo se compra, tudo se vende. Otto também cuida do Mercado dos Caçadores, onde Hunters de todos os servidores anunciam equipamentos e materiais.", 18)
	return model
end

-- item de verdade (mesmo modelo do ícone) pendurado/exposto: encolhido para caber no tamanho pedido
local function showcase(parent, baseId, rarityId, cf, maxSize)
	local model = ItemModels.build(baseId, rarityId, { anchored = true })
	local size = model:GetExtentsSize()
	model:ScaleTo(math.clamp(maxSize / math.max(size.X, size.Y, size.Z), 0.1, 1))
	local center = model:GetBoundingBox()
	model:PivotTo(cf * CFrame.new(center.Position):ToObjectSpace(model:GetPivot()))
	model.Parent = parent
	return model
end

-- COVIL DO MERCADOR (masmorras): casa de pedra escura com vigas roxas, piso de pedra, balcão com
-- chaves e frascos, armas exclusivas das masmorras expostas nas paredes, manequim com armadura de
-- conjunto, baú de saque, estandartes das três masmorras e um cristal de portal no fundo.
function builders.dungeonShop(parent, npc, rng)
	local cf = doorFrame(npc)
	local model = Props.building(parent, cf, 14, 15, 10, Color3.fromRGB(78, 74, 84), Color3.fromRGB(70, 45, 95), {
		name = "CovilMercador",
		doorWidth = 4.5,
		wallMaterial = M.Cobblestone,
		roofMaterial = M.Slate,
		floor = "stone",
		floorColor = Color3.fromRGB(70, 66, 74),
		trim = Color3.fromRGB(70, 45, 95),
		chimney = -4,
		lights = { Vector3.new(-3, 8.5, 5), Vector3.new(3, 8.5, 11) },
	})
	local inside = cf * CFrame.new(0, 1.2, 0)
	-- balcão (cintura) com tampo, chaves e frascos; Varg fica atrás dele
	part(model, { Name = "Balcao", Size = Vector3.new(8, 1.7, 1.4), CFrame = inside * CFrame.new(0, 0.85, 8), Color = Color3.fromRGB(55, 38, 30), Material = M.WoodPlanks })
	part(model, { Name = "Tampo", Size = Vector3.new(8.4, 0.2, 1.8), CFrame = inside * CFrame.new(0, 1.8, 8), Color = Color3.fromRGB(90, 55, 120), Material = M.Wood })
	for i, color in { Color3.fromRGB(150, 220, 255), Color3.fromRGB(255, 120, 60), Color3.fromRGB(255, 220, 120) } do
		part(model, { Name = "Chave", Size = Vector3.new(0.9, 0.16, 0.25), CFrame = inside * CFrame.new(-3.2 + i * 0.6, 1.98, 7.8) * CFrame.Angles(0, 0.4 * i, 0), Color = color, Material = M.Neon })
	end
	for i = 0, 2 do
		part(model, { Name = "Frasco", Size = Vector3.new(0.4, 0.65, 0.4), CFrame = inside * CFrame.new(1.8 + i * 0.6, 2.22, 8), Color = Color3.fromHSV(0.05 + i * 0.3, 0.7, 1), Material = M.Neon, Transparency = 0.15 })
	end
	part(model, { Name = "Livro", Size = Vector3.new(1.2, 0.2, 0.9), CFrame = inside * CFrame.new(0, 1.98, 7.9) * CFrame.Angles(0, 0.2, 0), Color = Color3.fromRGB(110, 40, 50), Material = M.Fabric })
	-- prateleira de poções e chaves no fundo, atrás do balcão
	Props.shelf(model, inside * CFrame.new(-2, 0, 14) * CFrame.Angles(0, math.rad(180), 0), 7, 3, "potions", rng)
	-- armas exclusivas expostas nas paredes, em placas de madeira
	-- (entre as janelas laterais, que ficam em z 4,5 e 10,8)
	local displays = {
		{ "ceifa_espectral", "Epico", -1, 1.9 }, { "martelo_magma", "Lendario", -1, 7.6 },
		{ "lanca_magma", "Lendario", 1, 1.9 }, { "arco_luto", "Epico", 1, 7.6 },
	}
	for _, entry in displays do
		local side, z = entry[3], entry[4]
		-- -Z da placa aponta para dentro da sala
		local wall = inside * CFrame.new(side * 6.07, 3.6, z) * CFrame.Angles(0, math.rad(side * 90), 0)
		part(model, { Name = "Placa", Size = Vector3.new(2.2, 4.4, 0.25), CFrame = wall, Color = Color3.fromRGB(60, 40, 30), Material = M.WoodPlanks })
		part(model, { Name = "Moldura", Size = Vector3.new(2.5, 0.25, 0.35), CFrame = wall * CFrame.new(0, 2.2, 0), Color = Color3.fromRGB(90, 55, 120), Material = M.Wood })
		for _, hookX in { -0.6, 0.6 } do
			part(model, { Name = "Gancho", Size = Vector3.new(0.12, 0.12, 0.35), CFrame = wall * CFrame.new(hookX, 0.6, -0.25), Color = Color3.fromRGB(40, 40, 45), Material = M.Metal })
		end
		showcase(model, entry[1], entry[2], wall * CFrame.new(0, 0, -0.45) * CFrame.Angles(0, 0, math.rad(-12)), 3.8)
	end
	-- manequim com a armadura do conjunto da Cripta
	local stand = inside * CFrame.new(4.4, 0, 12.6) * CFrame.Angles(0, math.rad(200), 0)
	part(model, { Name = "BaseManequim", Size = Vector3.new(1.8, 0.3, 1.8), CFrame = stand * CFrame.new(0, 0.15, 0), Color = Color3.fromRGB(55, 38, 30), Material = M.Wood })
	part(model, { Name = "Haste", Size = Vector3.new(0.25, 2.4, 0.25), CFrame = stand * CFrame.new(0, 1.5, 0), Color = Color3.fromRGB(55, 38, 30), Material = M.Wood })
	showcase(model, "mortalha_cripta", "Epico", stand * CFrame.new(0, 3.6, 0), 3.2)
	showcase(model, "elmo_vigia", "Epico", stand * CFrame.new(0, 5.6, 0), 1.3)
	-- baú de saque aberto com ouro
	local chest = inside * CFrame.new(-4.6, 0, 11.8) * CFrame.Angles(0, math.rad(20), 0)
	part(model, { Name = "Bau", Size = Vector3.new(2.4, 1.2, 1.5), CFrame = chest * CFrame.new(0, 0.6, 0), Color = Color3.fromRGB(80, 50, 30), Material = M.WoodPlanks })
	part(model, { Name = "Tampa", Size = Vector3.new(2.5, 0.25, 1.6), CFrame = chest * CFrame.new(0, 1.55, 0.9) * CFrame.Angles(math.rad(-70), 0, 0), Color = C.Gold, Material = M.Metal })
	for i = 0, 5 do
		Props.ball(model, (chest * CFrame.new(-0.8 + (i % 3) * 0.8, 1.25 + math.floor(i / 3) * 0.15, -0.2 + math.floor(i / 3) * 0.3)).Position, 0.5, C.Gold, M.Metal, { CanCollide = false })
	end
	-- cristal de portal num pedestal (lembra as masmorras)
	local crystalBase = inside * CFrame.new(2.4, 0, 12.6)
	Props.column(model, crystalBase, 1.2, 1.8, Color3.fromRGB(60, 56, 66), M.Slate)
	local crystal = part(model, { Name = "CristalPortal", Size = Vector3.new(0.9, 1.6, 0.9), CFrame = crystalBase * CFrame.new(0, 2.3, 0) * CFrame.Angles(0, math.rad(45), 0), Color = Color3.fromRGB(170, 120, 255), Material = M.Neon, CanCollide = false })
	Props.light(crystal, Color3.fromRGB(170, 120, 255), 16, 1.6, true)
	CollectionService:AddTag(crystal, "Spin")
	-- estandartes das três masmorras pendurados no teto, perto da entrada
	for i, color in { Color3.fromRGB(150, 110, 60), Color3.fromRGB(90, 70, 130), Color3.fromRGB(170, 60, 30) } do
		Props.banner(model, inside * CFrame.new(-3 + (i - 1) * 3, 8.4, 3), color)
	end
	Props.rug(model, cf * CFrame.new(0, 0, 4), 5, 4, Color3.fromRGB(80, 40, 100), Color3.fromRGB(220, 180, 90))
	-- placa pendurada na frente
	part(model, { Name = "Braco", Size = Vector3.new(0.2, 0.2, 2.2), CFrame = cf * CFrame.new(3.6, 8.6, -1.1), Color = Color3.fromRGB(40, 40, 45), Material = M.Metal })
	local sign = part(model, { Name = "Placa", Size = Vector3.new(0.25, 1.6, 2.2), CFrame = cf * CFrame.new(3.6, 7.6, -1.6), Color = Color3.fromRGB(70, 45, 95), Material = M.WoodPlanks })
	part(model, { Name = "Simbolo", Size = Vector3.new(0.3, 0.8, 0.8), CFrame = cf * CFrame.new(3.6, 7.6, -1.6) * CFrame.Angles(math.rad(45), 0, 0), Color = Color3.fromRGB(255, 200, 90), Material = M.Neon })
	Props.engrave(sign, "COVIL", Color3.fromRGB(220, 180, 255), { Enum.NormalId.Left, Enum.NormalId.Right })
	Props.readable(sign, "Covil do Mercador", "Varg só negocia com quem desce às masmorras. Chaves, poções fortes e os itens exclusivos da Toca, da Cripta e do Abismo, em Raro, Épico ou Lendário.", 18)
	return model
end

-- TREINO
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
		part(model, { Name = "Poste", Size = Vector3.new(0.6, 5.2, 0.6), CFrame = cf * CFrame.new(x, 2.6, 0), Color = C.DarkWood, Material = M.Wood })
	end
	local board = part(model, { Name = "Tabua", Size = Vector3.new(5.6, 2.8, 0.4), CFrame = cf * CFrame.new(0, 3.2, 0), Color = C.Plank, Material = M.WoodPlanks })
	Props.roof(model, cf * CFrame.new(0, 5.1, 0), 6.4, 1.6, 25, C.Roof)
	for i = 0, 4 do
		part(model, { Name = "Cartaz", Size = Vector3.new(1.0, 1.1, 0.1), CFrame = cf * CFrame.new(-2 + i, 3.2 + (if i % 2 == 0 then 0.5 else -0.5), -0.25) * CFrame.Angles(0, 0, math.rad((i - 2) * 4)), Color = Color3.fromRGB(245, 235, 210) })
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
	-- luz da água (acende à noite) e quatro lampiões baixos na borda
	local glow = part(model, { Name = "LuzAgua", Size = Vector3.new(1, 0.2, 1), CFrame = cf * CFrame.new(0, 1.7, 0), Transparency = 1, CanCollide = false, CanQuery = false })
	Props.light(glow, Color3.fromRGB(150, 205, 255), 26, 1.2)
	Props.nightLight(glow)
	for i = 0, 3 do
		local post = cf * CFrame.Angles(0, math.rad(45 + i * 90), 0) * CFrame.new(0, 0, -8.6)
		part(model, { Name = "PosteLampiao", Size = Vector3.new(0.35, 3.6, 0.35), CFrame = post * CFrame.new(0, 1.8, 0), Color = Color3.fromRGB(40, 40, 45), Material = M.Metal })
		part(model, { Name = "Tampa", Size = Vector3.new(0.9, 0.2, 0.9), CFrame = post * CFrame.new(0, 4.35, 0), Color = Color3.fromRGB(40, 40, 45), Material = M.Metal })
		local lamp = part(model, { Name = "Lampiao", Size = Vector3.new(0.7, 0.8, 0.7), CFrame = post * CFrame.new(0, 3.85, 0), Color = Color3.fromRGB(255, 220, 150), Material = M.Neon, CanCollide = false })
		Props.light(lamp, Color3.fromRGB(255, 205, 145), 20, 1.2)
		Props.nightLight(lamp)
	end
	model.Parent = parent
	Props.scaleModel(model, cf, K)
	Placement.reserve(cf.X, cf.Z, 9 * K, "chafariz")
end

local function entranceArch(parent)
	local x, z = World.TownCenter.X, World.TownCenter.Z + TownPlan.ArchZ * K
	local ground = World.height(x, z)
	local cf = CFrame.new(x, ground, z)
	local model = Instance.new("Model")
	model.Name = "Portal da Vila"
	for _, side in { -1, 1 } do
		part(model, { Name = "Pilar", Size = Vector3.new(2.2, 12, 2.2), CFrame = cf * CFrame.new(side * 9.5, 5.5, 0), Color = C.DarkStone, Material = M.Cobblestone })
		Props.fire(model, (cf * CFrame.new(side * 9.5, 11.5, 0)).Position, 0.7)
	end
	local beam = part(model, { Name = "Viga", Size = Vector3.new(22, 2, 1.6), CFrame = cf * CFrame.new(0, 10.5, 0), Color = C.DarkWood, Material = M.Wood })
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
		Props.banner(model, cf * CFrame.new(side * 5.5, 9.3, -1), Color3.fromRGB(40, 70, 150))
	end
	model.Parent = parent
	Props.scaleModel(model, cf, K)
	Placement.reserve(x - 9.5 * K, z, 2.5 * K, "arco")
	Placement.reserve(x + 9.5 * K, z, 2.5 * K, "arco")
end


-- ===================== TRAÇADO DA VILA =====================
-- Tudo vem do TownPlan (fonte única do traçado). Coordenadas de projeto relativas à praça.

local function rel(x, z)
	return World.TownCenter.X + x * K, World.TownCenter.Z + z * K
end

local function lotFrame(x, z, facing)
	local wx, wz = rel(x, z)
	return CFrame.new(wx, Y, wz) * CFrame.Angles(0, math.rad(facing), 0)
end

local PAVING_LOOK = {
	praca = { Color3.fromRGB(170, 160, 145), M.Pavement, 0.3 },
	rua = { Color3.fromRGB(125, 120, 115), M.Cobblestone, 0.28 },
	calcada = { Color3.fromRGB(190, 180, 165), M.Slate, 0.36 },
	beco = { Color3.fromRGB(120, 95, 70), M.Ground, 0.22 },
}

local function reserveStrip(x1, z1, x2, z2)
	local ax, az = rel(math.min(x1, x2), math.min(z1, z2))
	local bx, bz = rel(math.max(x1, x2), math.max(z1, z2))
	local step = 6 * K
	local x = ax
	while x <= bx + 0.01 do
		local z = az
		while z <= bz + 0.01 do
			Placement.reserve(x, z, step * 0.75, "rua")
			z += step
		end
		x += step
	end
end

local function pave(folder, x1, z1, x2, z2, kind)
	local look = PAVING_LOOK[kind]
	local ax, az = rel(math.min(x1, x2), math.min(z1, z2))
	local bx, bz = rel(math.max(x1, x2), math.max(z1, z2))
	part(folder, {
		Name = "Piso_" .. kind,
		Size = Vector3.new(bx - ax, look[3], bz - az),
		CFrame = CFrame.new((ax + bx) / 2, Y + look[3] / 2 - 0.05, (az + bz) / 2),
		Color = look[1],
		Material = look[2],
	})
	-- ruas e calçadas ficam reservadas já; praça e becos só depois dos enfeites
	if kind == "rua" or kind == "calcada" then
		reserveStrip(x1, z1, x2, z2)
	end
end

-- coloca um enfeite (montado em tamanho de projeto e ampliado por K) se o lugar estiver livre
local function placeDecor(folder, x, z, facing, radius, build)
	local wx, wz = rel(x, z)
	if not Placement.isFree(wx, wz, radius * K) then
		return false
	end
	local cf = lotFrame(x, z, facing or 0) * CFrame.new(0, 0.25, 0) -- em cima do calçamento
	local model = build(cf)
	if model then
		if model.Parent == nil then
			model.Parent = folder
		end
		Props.scaleModel(model, cf, K)
	end
	Placement.reserve(wx, wz, radius * K, "enfeite")
	return true
end

local HOUSE_COLORS = { Color3.fromRGB(235, 220, 190), Color3.fromRGB(200, 170, 130), Color3.fromRGB(220, 200, 170), Color3.fromRGB(180, 150, 120), Color3.fromRGB(210, 190, 200), Color3.fromRGB(190, 205, 215) }
local ROOF_COLORS = { Color3.fromRGB(150, 60, 45), Color3.fromRGB(70, 80, 120), Color3.fromRGB(110, 70, 50), Color3.fromRGB(60, 100, 70), Color3.fromRGB(130, 50, 70) }
local FLOORS = {
	{ Color3.fromRGB(160, 115, 75), M.WoodPlanks }, { Color3.fromRGB(120, 85, 55), M.WoodPlanks },
	{ Color3.fromRGB(130, 125, 120), M.Slate }, { Color3.fromRGB(165, 95, 70), M.Brick }, { Color3.fromRGB(200, 195, 185), M.Marble },
}

-- Jardim na frente da casa: caminho de pedras da calçada até a porta e arbustos com flores
local function frontGarden(model, door, rng)
	local gap = TownPlan.FrontLine - TownPlan.SidewalkOuter
	for i = 0, 2 do
		part(model, { Name = "PedraCaminho", Size = Vector3.new(1.6, 0.2, 0.8), CFrame = door * CFrame.new(rng:NextNumber(-0.2, 0.2), 0.1, -0.5 - i * gap / 3) * CFrame.Angles(0, rng:NextNumber(-0.2, 0.2), 0), Color = C.Stone, Material = M.Slate })
	end
	for _, side in { -1, 1 } do
		local spot = door * CFrame.new(side * 3.2, 0, -gap / 2)
		Props.ball(model, (spot * CFrame.new(0, 0.7, 0)).Position, 1.5, Color3.fromRGB(70, 140, 60), M.Grass, { CanCollide = false })
		for _ = 1, 3 do
			Props.ball(model, (spot * CFrame.new(rng:NextNumber(-0.6, 0.6), 1.2, rng:NextNumber(-0.5, 0.5))).Position, 0.35, Color3.fromHSV(rng:NextNumber(), 0.55, 1), M.SmoothPlastic, { CanCollide = false })
		end
	end
end

function Town.decorate(folder, rng)
	-- bancos em volta do chafariz, virados para ele
	for _, spot in { { 9, 9 }, { -9, 9 }, { 9, -9 }, { -9, -9 } } do
		placeDecor(folder, spot[1], spot[2], math.deg(math.atan2(spot[1], spot[2])), 2.4, function(cf)
			return Props.bench(folder, cf)
		end)
	end
	-- feira: lados leste e oeste da praça (perto do norte) e cantos do sul
	local awnings = { Color3.fromRGB(200, 60, 50), Color3.fromRGB(60, 120, 190), Color3.fromRGB(70, 150, 80), Color3.fromRGB(200, 140, 40) }
	for i, spot in { { 21, -14 }, { -21, -14 }, { 18, 18 }, { -18, 18 } } do
		local facing = if math.abs(spot[2]) < 16 then (if spot[1] > 0 then -90 else 90) else math.deg(math.atan2(spot[1], spot[2]))
		placeDecor(folder, spot[1], spot[2], facing, 3.6, function(cf)
			return Props.marketStall(folder, cf, i, awnings[i])
		end)
	end
	-- canteiros nas bordas da praça
	for _, spot in { { -14, 24, 180 }, { 14, 24, 180 }, { -24, 9, 90 }, { -24, -9, 90 }, { 24, 9, -90 }, { 24, -9, -90 } } do
		placeDecor(folder, spot[1], spot[2], spot[3], 1.6, function(cf)
			local planter = Instance.new("Model")
			planter.Name = "Canteiro"
			Props.part(planter, { Name = "Base", Size = Vector3.new(3.2, 0.8, 1.4), CFrame = cf * CFrame.new(0, 0.4, 0), Color = C.Stone, Material = M.Cobblestone })
			Props.flowerBox(planter, cf * CFrame.new(0, 1.1, 0), 3, rng)
			planter.Parent = folder
			return planter
		end)
	end
	-- becos: poço, carroça, varais, galinheiro, caixas e barris
	placeDecor(folder, -33, -29, 45, 2.6, function(cf)
		return Props.well(folder, cf)
	end)
	placeDecor(folder, 60, -30, 90, 3.2, function(cf)
		return Props.cart(folder, cf)
	end)
	placeDecor(folder, -32.5, -50, 0, 2.6, function(cf)
		return Props.laundry(folder, cf * CFrame.Angles(0, math.rad(90), 0), rng)
	end)
	placeDecor(folder, 32.5, -72, 0, 2.6, function(cf)
		return Props.laundry(folder, cf * CFrame.Angles(0, math.rad(90), 0), rng)
	end)
	placeDecor(folder, -55, 34, 0, 3, function(cf)
		return Props.coop(folder, cf)
	end)
	for _, spot in { { -32.5, -70 }, { 32.5, -46 }, { -50, -29 }, { 75, -30 }, { 32.5, 42 }, { -75, -29 } } do
		placeDecor(folder, spot[1], spot[2], rng:NextNumber(0, 360), 1.2, function(cf)
			local model = Instance.new("Model")
			model.Name = "Entulho"
			if rng:NextNumber() < 0.5 then
				Props.crate(model, cf, 2.2)
				Props.crate(model, cf * CFrame.new(0.3, 2.2, 0.2), 1.5)
			else
				Props.barrel(model, cf, 0.8)
				Props.barrel(model, cf * CFrame.new(1.4, 0, 0.5), 0.8)
			end
			model.Parent = folder
			return model
		end)
	end
end

function Town.build(parent, rng)
	local folder = Instance.new("Folder")
	folder.Name = "Vila"
	folder.Parent = parent

	-- piso: praça, ruas, calçadas e becos
	local paving = Instance.new("Folder")
	paving.Name = "Ruas"
	paving.Parent = folder
	for _, strip in TownPlan.Paving do
		pave(paving, strip[1], strip[2], strip[3], strip[4], strip[5])
	end

	fountain(folder)
	entranceArch(folder)

	-- construções de cada NPC (posições em NPCs.List vêm do TownPlan)
	local boardPart = nil
	for _, npc in NPCs.List do
		if npc.building and builders[npc.building] then
			local model = builders[npc.building](folder, npc, rng)
			if model and npc.building ~= "training" then
				Props.scaleModel(model, doorFrame(npc), K)
			end
			local look = CFrame.Angles(0, npc.yaw, 0).LookVector
			local door = Vector3.new(npc.doorX or npc.x, 0, npc.doorZ or npc.z)
			local back = door - look * 8 * K
			Placement.reserve(back.X, back.Z, 11 * K, npc.building)
		elseif npc.board then
			local model, board = builders.board(folder, npc)
			Props.scaleModel(model, npcFrame(npc), K)
			boardPart = board
		end
		Placement.reserve(npc.x, npc.z, 3 * K, "npc")
	end

	-- casas: porta na linha do jardim, virada para a rua ou beco; piso variado por dentro
	for i, house in TownPlan.Houses do
		local x, z, facing, width, depth = house[1], house[2], house[3], house[4], house[5]
		local door = lotFrame(x, z, facing)
		local center = door * CFrame.new(0, 0, depth / 2 + 0.3)
		local model = Props.house(folder, center, width, depth, rng:NextInteger(7, 9), HOUSE_COLORS[(i % #HOUSE_COLORS) + 1], ROOF_COLORS[(i % #ROOF_COLORS) + 1], rng)
		local floor = FLOORS[rng:NextInteger(1, #FLOORS)]
		part(model, { Name = "PisoCasa", Size = Vector3.new(width - 1.6, 0.15, depth - 1.6), CFrame = center * CFrame.new(0, 1.08, 0), Color = floor[1], Material = floor[2] })
		-- jardim só nas casas viradas para a rua (as do beco encostam no chão de terra)
		if math.abs(x) < 20 or math.abs(z) < 20 then
			frontGarden(model, door, rng)
		end
		Props.scaleModel(model, door, K)
		local middle = (door * CFrame.new(0, 0, depth / 2 * K)).Position
		Placement.reserve(middle.X, middle.Z, math.max(width, depth) / 2 * K, "casa")
	end

	-- postes nas calçadas, nos vãos entre lotes, com bandeirinhas altas cruzando a rua
	local lampOffset = (TownPlan.StreetHalf + TownPlan.SidewalkOuter) / 2
	local top = 7.9 * K
	for _, lamp in TownPlan.Lamps do
		local pair = {}
		for _, side in { -1, 1 } do
			local x, z, facing
			if lamp[1] == "z" then
				x, z, facing = side * lampOffset, lamp[2], if side < 0 then -90 else 90
			else
				x, z, facing = lamp[2], side * lampOffset, if side < 0 then 180 else 0
			end
			local wx, wz = rel(x, z)
			local ground = CFrame.new(wx, Y + 0.3, wz) * CFrame.Angles(0, math.rad(facing), 0)
			Props.scaleModel(Props.lamp(folder, ground), ground, K)
			Placement.reserve(wx, wz, 1.2 * K, "poste")
			table.insert(pair, Vector3.new(wx, Y + top, wz))
		end
		Props.bunting(folder, pair[1], pair[2], 0.5 * K)
	end
	-- postes nos cantos da praça e bandeirinhas em X bem no alto
	local corner = TownPlan.PlazaHalf - 2
	local corners = {}
	for _, c in { { -corner, -corner }, { corner, corner }, { corner, -corner }, { -corner, corner } } do
		local wx, wz = rel(c[1], c[2])
		local ground = CFrame.new(wx, Y + 0.3, wz) * CFrame.Angles(0, math.atan2(c[1], c[2]), 0)
		Props.scaleModel(Props.lamp(folder, ground), ground, K)
		Placement.reserve(wx, wz, 1.2 * K, "poste")
		table.insert(corners, Vector3.new(wx, Y + top, wz))
	end
	Props.bunting(folder, corners[1], corners[2], 1.2 * K)
	Props.bunting(folder, corners[3], corners[4], 1.2 * K)

	Town.decorate(folder, rng)

	-- praça e becos ficam reservados (nada de árvore no caminho)
	for _, strip in TownPlan.Paving do
		if strip[5] == "praca" or strip[5] == "beco" then
			reserveStrip(strip[1], strip[2], strip[3], strip[4])
		end
	end
	return boardPart
end

return Town
