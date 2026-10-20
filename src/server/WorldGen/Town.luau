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

local builders = {}

-- Forja aberta: telhado sobre pilares, bigorna, fornalha com chaminé, barril e suporte de armas
function builders.forge(parent, npc)
	local cf = npcFrame(npc) * CFrame.new(0, 0, 9)
	local model = Instance.new("Model")
	model.Name = "Forja"
	part(model, { Name = "Piso", Size = Vector3.new(16, 0.6, 12), CFrame = cf * CFrame.new(0, 0.3, 0), Color = C.DarkStone, Material = M.Slate })
	for _, x in { -7.5, 7.5 } do
		for _, z in { -5.5, 5.5 } do
			part(model, { Name = "Pilar", Size = Vector3.new(1, 9, 1), CFrame = cf * CFrame.new(x, 4.8, z), Color = C.DarkWood, Material = M.Wood })
		end
	end
	Props.roof(model, cf * CFrame.new(0, 9.3, 0), 16, 12, 25, Color3.fromRGB(90, 60, 50))
	local furnace = part(model, { Name = "Fornalha", Size = Vector3.new(6, 6, 4), CFrame = cf * CFrame.new(-3, 3.6, 3.5), Color = Color3.fromRGB(110, 60, 50), Material = M.Brick })
	local opening = part(model, { Name = "Brasa", Size = Vector3.new(3, 2, 0.3), CFrame = cf * CFrame.new(-3, 2.4, 1.4), Color = C.Fire, Material = M.Neon })
	Props.light(opening, C.Fire, 20, 2.5)
	local chimney = part(model, { Name = "Chamine", Size = Vector3.new(2, 9, 2), CFrame = cf * CFrame.new(-3, 11, 3.5), Color = Color3.fromRGB(90, 50, 45), Material = M.Brick })
	Props.smoke(chimney, 4)
	part(model, { Name = "BigornaBase", Size = Vector3.new(1.6, 1.8, 1.4), CFrame = cf * CFrame.new(3, 1.5, -1), Color = Color3.fromRGB(45, 45, 50), Material = M.Metal })
	part(model, { Name = "Bigorna", Size = Vector3.new(3.2, 0.9, 1.4), CFrame = cf * CFrame.new(3, 2.8, -1), Color = Color3.fromRGB(70, 70, 78), Material = M.Metal })
	Props.barrel(model, cf * CFrame.new(6, 0.6, 3.5))
	-- suporte com armas
	part(model, { Name = "Suporte", Size = Vector3.new(6, 0.4, 0.4), CFrame = cf * CFrame.new(3, 4.5, 5.2), Color = C.DarkWood, Material = M.Wood })
	for i = -2, 2 do
		part(model, { Name = "Lamina", Size = Vector3.new(0.3, 3, 0.15), CFrame = cf * CFrame.new(3 + i * 1.1, 3.2, 5), Color = Color3.fromRGB(170, 170, 180), Material = M.Metal })
	end
	model.Parent = parent
	Props.billboard(opening, "⚒️ FORJA", C.Fire, 9)
	return model
end

-- Casa da alquimista com caldeirão borbulhante e prateleira de poções
function builders.alchemy(parent, npc, rng)
	local cf = npcFrame(npc) * CFrame.new(0, 0, 11)
	local house = Props.house(parent, cf, 12, 10, 8, Color3.fromRGB(170, 200, 160), Color3.fromRGB(60, 120, 80), rng)
	local cauldronCf = npcFrame(npc) * CFrame.new(5, 0, 2)
	local cauldron = Props.column(house, cauldronCf, 2.4, 3.2, Color3.fromRGB(40, 40, 45), M.Metal)
	local liquid = Props.column(house, cauldronCf * CFrame.new(0, 2.2, 0), 0.3, 2.7, Color3.fromRGB(90, 255, 120), M.Neon)
	Props.light(liquid, Color3.fromRGB(90, 255, 120), 12, 1.5)
	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Color = ColorSequence.new(Color3.fromRGB(150, 255, 170))
	bubbles.LightEmission = 0.8
	bubbles.Size = NumberSequence.new(0.4, 0.1)
	bubbles.Lifetime = NumberRange.new(0.6, 1.2)
	bubbles.Rate = 10
	bubbles.Speed = NumberRange.new(1.5, 3)
	bubbles.Parent = liquid
	Props.fire(house, (cauldronCf * CFrame.new(0, -0.3, 0)).Position, 0.6)
	cauldron.Name = "Caldeirao"
	-- prateleira na frente da casa
	local shelf = npcFrame(npc) * CFrame.new(-4.5, 0, 4.5)
	part(house, { Name = "Prateleira", Size = Vector3.new(4, 4, 1), CFrame = shelf * CFrame.new(0, 2, 0), Color = C.Wood, Material = M.WoodPlanks })
	for i = 0, 5 do
		local color = Color3.fromHSV(i / 6, 0.7, 1)
		part(house, { Name = "Frasco", Size = Vector3.new(0.5, 0.8, 0.5), CFrame = shelf * CFrame.new(-1.5 + (i % 3) * 1.5, 1.6 + math.floor(i / 3) * 1.6, -0.6), Color = color, Material = M.Neon, Transparency = 0.2 })
	end
	Props.billboard(liquid, "⚗️ ALQUIMIA", Color3.fromRGB(120, 255, 140), 7)
	return house
end

-- Torre do encantador: cilindros empilhados, telhado cônico e cristal flutuante
function builders.tower(parent, npc)
	local cf = npcFrame(npc) * CFrame.new(0, 0, 11)
	local model = Instance.new("Model")
	model.Name = "TorreEncantador"
	Props.column(model, cf, 1, 14, C.DarkStone, M.Slate)
	Props.column(model, cf * CFrame.new(0, 1, 0), 18, 11, Color3.fromRGB(120, 110, 140), M.Brick)
	Props.column(model, cf * CFrame.new(0, 19, 0), 1.2, 13, Color3.fromRGB(80, 60, 110), M.Slate)
	for i = 1, 4 do
		Props.column(model, cf * CFrame.new(0, 20 + (i - 1) * 2.2, 0), 2.2, 12 - i * 2.6, Color3.fromRGB(90, 50, 160), M.Slate)
	end
	part(model, { Name = "Porta", Size = Vector3.new(3.2, 5.5, 1), CFrame = cf * CFrame.new(0, 3.8, -5.3), Color = C.DarkWood, Material = M.Wood })
	for _, angle in { -50, 50, 180 } do
		local a = math.rad(angle)
		part(model, { Name = "Janela", Size = Vector3.new(1.6, 2.4, 0.4), CFrame = cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 12, -5.45), Color = Color3.fromRGB(200, 150, 255), Material = M.Neon })
	end
	local crystal = part(model, { Name = "Cristal", Size = Vector3.new(2.2, 2.2, 2.2), CFrame = cf * CFrame.new(0, 32, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)), Color = Color3.fromRGB(190, 120, 255), Material = M.Neon, CanCollide = false })
	Props.light(crystal, Color3.fromRGB(190, 120, 255), 30, 2)
	CollectionService:AddTag(crystal, "Spin")
	model.Parent = parent
	Props.billboard(crystal, "✨ ENCANTAMENTOS", Color3.fromRGB(200, 150, 255), 3)
	return model
end

-- Barraca do mercador com toldo listrado, caixas e barris
function builders.stall(parent, npc)
	local cf = npcFrame(npc) * CFrame.new(0, 0, 2.5)
	local model = Instance.new("Model")
	model.Name = "Barraca"
	part(model, { Name = "Balcao", Size = Vector3.new(8, 3, 1.6), CFrame = npcFrame(npc) * CFrame.new(0, 1.5, -2.2), Color = C.Plank, Material = M.WoodPlanks })
	for _, x in { -4.2, 4.2 } do
		for _, z in { -5, 3 } do
			part(model, { Name = "Poste", Size = Vector3.new(0.5, 8, 0.5), CFrame = cf * CFrame.new(x, 4, z), Color = C.DarkWood, Material = M.Wood })
		end
	end
	for i = 0, 7 do
		local color = if i % 2 == 0 then Color3.fromRGB(220, 60, 50) else Color3.fromRGB(245, 235, 220)
		part(model, { Name = "Toldo", Size = Vector3.new(1.1, 0.3, 9.4), CFrame = cf * CFrame.new(-3.85 + i * 1.1, 8.2, -1) * CFrame.Angles(math.rad(12), 0, 0), Color = color, Material = M.Fabric })
	end
	Props.crate(model, cf * CFrame.new(-3, 0, 2))
	Props.crate(model, cf * CFrame.new(-3, 2.5, 2), 1.8)
	Props.barrel(model, cf * CFrame.new(3, 0, 2))
	for i = -1, 1 do
		Props.ball(model, (npcFrame(npc) * CFrame.new(i * 1.5, 3.4, -2.2)).Position, 0.8, Color3.fromRGB(240, 60, 60), M.SmoothPlastic)
	end
	model.Parent = parent
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

local function horse(parent, cf, color)
	local model = Instance.new("Model")
	model.Name = "Cavalo"
	local dark = color:Lerp(Color3.new(0, 0, 0), 0.4)
	part(model, { Name = "Corpo", Size = Vector3.new(2, 2, 4.4), CFrame = cf * CFrame.new(0, 3.4, 0), Color = color })
	part(model, { Name = "Pescoco", Size = Vector3.new(1.2, 2.4, 1.2), CFrame = cf * CFrame.new(0, 4.8, -2.2) * CFrame.Angles(math.rad(-30), 0, 0), Color = color })
	part(model, { Name = "Cabeca", Size = Vector3.new(1.1, 1.1, 2.2), CFrame = cf * CFrame.new(0, 5.8, -3.2), Color = color })
	part(model, { Name = "Crina", Size = Vector3.new(0.4, 2.4, 0.6), CFrame = cf * CFrame.new(0, 5.2, -1.8) * CFrame.Angles(math.rad(-30), 0, 0), Color = dark })
	part(model, { Name = "Cauda", Size = Vector3.new(0.5, 2.2, 0.5), CFrame = cf * CFrame.new(0, 3.2, 2.4) * CFrame.Angles(math.rad(25), 0, 0), Color = dark })
	for _, x in { -0.65, 0.65 } do
		for _, z in { -1.6, 1.6 } do
			part(model, { Name = "Perna", Size = Vector3.new(0.55, 2.6, 0.55), CFrame = cf * CFrame.new(x, 1.3, z), Color = color })
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
	model.Parent = parent
	Props.scaleModel(model, cf, K)
	Placement.reserve(x - 7 * K, z, 2.5 * K, "arco")
	Placement.reserve(x + 7 * K, z, 2.5 * K, "arco")
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
				Props.scaleModel(model, npcFrame(npc), K)
			end
			local look = CFrame.Angles(0, npc.yaw, 0).LookVector
			local back = Vector3.new(npc.x, 0, npc.z) - look * 10 * K
			Placement.reserve(back.X, back.Z, 10 * K, npc.building)
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
	for i = 0, 11 do
		local a = math.rad(15 + i * 30)
		local x = World.TownCenter.X + math.cos(a) * 37 * K
		local z = World.TownCenter.Z + math.sin(a) * 37 * K
		if Placement.isFree(x, z, 2 * K) then
			local ground = CFrame.new(x, Y, z) * CFrame.Angles(0, math.atan2(-(World.TownCenter.X - x), -(World.TownCenter.Z - z)), 0)
			Props.scaleModel(Props.lamp(folder, ground), ground, K)
			Placement.reserve(x, z, 1.5 * K, "poste")
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

	return boardPart
end

return Town
