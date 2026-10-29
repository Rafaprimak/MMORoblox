-- Salão das Guildas: casa longa viking a leste da vila, ponto de encontro das guildas.
-- Por fora: alicerce de pedras, paredes de tábuas com mata-juntas, escudos sob o beiral, telhado alto com
-- tábuas cruzadas e cabeças de dragão, alpendre na porta, caminho de lajes até a estrada, tochas e
-- flâmulas, pátio de treino (bonecos e alvo), lenha com telheiro e carroça. A única placa é a da pedra
-- de viagem.
-- Por dentro: pé-direito alto (vigas lá em cima), fogueira comprida de brasas com fogo de verdade
-- (Props.flame, sem blocos de neon), mesas de banquete, lustres de roda com velas, armaduras e armas do
-- jogo (ItemModels) expostas nas paredes, estrado no fundo com a Helena (guildas) e o Ulf (contratos),
-- o Mural de Honra (desenhado pelo GuildService) e o barril de hidromel do brinde (prompt "BrindeSalao",
-- tratado no GuildService).
-- Montado em unidades de projeto no referencial do salão (x = largura, z = comprimento, -Z = porta) e
-- ampliado × PropScale. Os itens do jogo entram depois de ampliar, no tamanho real (o mesmo da mão do
-- jogador). Posição, tamanho e chão plano em World.GuildHall.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared.World)
local ItemModels = require(Shared.ItemModels)

local Props = require(script.Parent.Props)
local Placement = require(script.Parent.Placement)

local GuildHall = {}

local K = World.PropScale
local M = Enum.Material
local part = Props.part

local WOOD = Color3.fromRGB(96, 66, 42)
local DARK = Color3.fromRGB(58, 40, 28)
local STONE = Color3.fromRGB(112, 108, 100)
local IRON = Color3.fromRGB(45, 43, 42)
local GOLD = Color3.fromRGB(205, 165, 80)
local ROOF = Color3.fromRGB(88, 64, 46)
local CANDLE = Color3.fromRGB(235, 225, 200)
local EMBERS = Color3.fromRGB(75, 55, 48)
local STRAW = Color3.fromRGB(205, 175, 95)
local SHIELDS = { Color3.fromRGB(150, 40, 40), Color3.fromRGB(40, 70, 140), Color3.fromRGB(200, 165, 60), Color3.fromRGB(60, 110, 60) }

-- armaduras dos manequins (armadura, elmo, botas, raridade) e armas cruzadas atrás dos escudos
local ARMOR_SETS = {
	{ "armadura_placas", "elmo_ferro", "botas_ferro", "Raro" },
	{ "colete_couro", "elmo_couro", "botas_couro", "Comum" },
	{ "cota_malha", "elmo_ferro", "botas_ferro", "Raro" },
	{ "manto_arcano", "coroa_arcana", "sandalias_monge", "Epico" },
	{ "couraca_sombria", "capuz_sombrio", "botas_vento", "Epico" },
	{ "couraca_vento", "elmo_couro", "botas_vento", "Raro" },
	{ "manto_estelar", "capuz_aprendiz", "botas_estelares", "Epico" },
	{ "armadura_dragao", "elmo_dragao", "grevas_dragao", "Lendario" },
}
local WALL_WEAPONS = {
	{ { "machado_berserker", "Raro" }, { "lanca_cacador", "Comum" } },
	{ { "espada_runica", "Epico" }, { "machado_tempestade", "Epico" } },
	{ { "katana_errante", "Comum" }, { "lamina_guardiao", "Raro" } },
	{ { "martelo_gigante", "Raro" }, { "lanca_draconica", "Epico" } },
	{ { "machado_lenhador", "Comum" }, { "espada_cobre", "Comum" } },
	{ { "katana_sombria", "Raro" }, { "presas_gemeas", "Raro" } },
	{ { "maca_peregrino", "Raro" }, { "cetro_luz", "Epico" } },
	{ { "arco_longo", "Raro" }, { "lanca_celestial", "Lendario" } },
}
local RACK_WEAPONS = { "lanca_cacador", "machado_lenhador", "espada_cobre", "martelo_pedra", "adaga_cobre" }
local TROPHIES = { { "martelo_trovao", "Lendario" }, { "cajado_estelar", "Lendario" } }

local BOARD_TEXT = "Três contratos por dia, só para quem tem guilda. Pegue com o Ulf, faça e entregue aqui. Cada entrega rende ouro, XP e 25 pontos para a sua guilda (e conta na meta \"Contratos da Guilda\" quando ela sai na semana)."

-- cilindro deitado no eixo Z do cf (troncos)
local function log(parent, cf, length, diameter, color)
	return part(parent, { Name = "Tora", Shape = Enum.PartType.Cylinder, Size = Vector3.new(length, diameter, diameter), CFrame = cf * CFrame.Angles(0, math.rad(90), 0), Color = color or WOOD, Material = M.Wood })
end

-- peça entre dois pontos do mundo (vigas inclinadas, pernas de tripé, correntes)
local function beam(parent, a, b, thickness, color, material, name)
	return part(parent, { Name = name or "Viga", Size = Vector3.new(thickness, thickness, (b - a).Magnitude), CFrame = CFrame.lookAt((a + b) / 2, b), Color = color or DARK, Material = material or M.Wood, CanCollide = false })
end

-- pedra irregular (alicerce, beira da fogueira, beira do caminho)
local function stone(parent, cf, size, rng)
	return part(parent, {
		Name = "Pedra",
		Size = size,
		CFrame = cf * CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, math.pi), rng:NextNumber(-0.2, 0.2)),
		Color = STONE:Lerp(Color3.fromRGB(78, 76, 72), rng:NextNumber(0, 0.6)),
		Material = M.Slate,
	})
end

-- vela com chama de partículas
local function candle(parent, base, height)
	Props.column(parent, base, height, 0.3, CANDLE, M.SmoothPlastic, { CanCollide = false })
	Props.flame(parent, (base * CFrame.new(0, height + 0.12, 0)).Position, 0.35, { light = 0, sparks = false, rate = 8 })
end

-- escudo redondo (cf no centro, -Z = frente): tábuas pintadas, aro de ferro, faixas e bossa
local function roundShield(parent, cf, diameter, color)
	part(parent, { Name = "Escudo", Shape = Enum.PartType.Cylinder, Size = Vector3.new(diameter * 0.09, diameter, diameter), CFrame = cf * CFrame.Angles(0, math.rad(90), 0), Color = color, Material = M.WoodPlanks, CanCollide = false })
	part(parent, { Name = "Aro", Shape = Enum.PartType.Cylinder, Size = Vector3.new(diameter * 0.06, diameter * 1.05, diameter * 1.05), CFrame = cf * CFrame.new(0, 0, diameter * 0.02) * CFrame.Angles(0, math.rad(90), 0), Color = IRON, Material = M.Metal, CanCollide = false })
	local band = color:Lerp(Color3.new(1, 1, 1), 0.45)
	part(parent, { Name = "Faixa", Size = Vector3.new(diameter * 0.16, diameter * 0.97, 0.04), CFrame = cf * CFrame.new(0, 0, -diameter * 0.045 - 0.02), Color = band, Material = M.Fabric, CanCollide = false })
	part(parent, { Name = "Faixa", Size = Vector3.new(diameter * 0.97, diameter * 0.16, 0.04), CFrame = cf * CFrame.new(0, 0, -diameter * 0.045 - 0.03), Color = band, Material = M.Fabric, CanCollide = false })
	Props.ball(parent, (cf * CFrame.new(0, 0, -diameter * 0.05)).Position, diameter * 0.24, Color3.fromRGB(150, 140, 120), M.Metal, { CanCollide = false })
end

-- tábuas cruzadas na ponta da cumeeira, terminando em cabeças de dragão (s = escala)
local function crossedBoards(parent, ridgeCf, pitch, sz, s)
	local angle = math.rad(pitch)
	for i, side in { -1, 1 } do
		local d = Vector3.new(-side * math.cos(angle), math.sin(angle), 0) -- da beira até a cumeeira
		local n = Vector3.new(side * math.sin(angle), math.cos(angle), 0) -- para fora do telhado
		local ridge = n * 0.6 * s + Vector3.new(0, 0, sz * (i - 1) * 0.45 * s)
		local phi = math.atan2(d.Y, d.X)
		part(parent, { Name = "TabuaCruzada", Size = Vector3.new(9, 0.7, 0.4) * s, CFrame = ridgeCf * CFrame.new(ridge - d * 0.5 * s) * CFrame.Angles(0, 0, phi), Color = DARK, Material = M.Wood })
		local head = ridgeCf * CFrame.new(ridge + d * 4.4 * s) * CFrame.Angles(0, 0, phi)
		part(parent, { Name = "CabecaDragao", Size = Vector3.new(1.8, 1.1, 0.9) * s, CFrame = head, Color = Color3.fromRGB(70, 48, 32), Material = M.Wood })
		part(parent, { Name = "Focinho", Size = Vector3.new(1, 0.6, 0.7) * s, CFrame = head * CFrame.new(1.2 * s, -0.15 * s, 0), Color = Color3.fromRGB(70, 48, 32), Material = M.Wood })
		part(parent, { Name = "Crista", Size = Vector3.new(1.2, 0.35, 0.25) * s, CFrame = head * CFrame.new(-0.3 * s, 0.65 * s, 0) * CFrame.Angles(0, 0, math.rad(-20)), Color = DARK, Material = M.Wood })
		for _, ez in { -0.47, 0.47 } do
			Props.ball(parent, (head * CFrame.new(0.45 * s, 0.2 * s, ez * s)).Position, 0.22 * s, Color3.fromRGB(30, 20, 15), M.SmoothPlastic, { CanCollide = false })
		end
	end
end

-- mesa comprida de banquete: tampo em tábuas curtas (cada uma menor que uma "parede" do anti-trapaça),
-- cavaletes em X e a comida do banquete
local function feastTable(parent, cf, width, length, height, rng)
	local pieces = math.ceil(length / 5.5)
	local step = length / pieces
	for i = 0, pieces - 1 do
		part(parent, { Name = "Tampo", Size = Vector3.new(width, 0.35, step - 0.06), CFrame = cf * CFrame.new(0, height, -length / 2 + step * (i + 0.5)), Color = Color3.fromRGB(105, 70, 45):Lerp(DARK, rng:NextNumber(0, 0.25)), Material = M.WoodPlanks })
	end
	local legLength = (height - 0.17) / math.cos(math.rad(22))
	for _, z in { -length / 2 + 1, -length / 6, length / 6, length / 2 - 1 } do
		for _, s in { -1, 1 } do
			part(parent, { Name = "Cavalete", Size = Vector3.new(0.35, legLength, 0.35), CFrame = cf * CFrame.new(0, (height - 0.17) / 2, z) * CFrame.Angles(0, 0, math.rad(s * 22)), Color = DARK, Material = M.Wood })
		end
	end
	local top = height + 0.175
	local candelabra = { -length / 4 + 1.3, length / 4 + 1.3 }
	local fruits = { Color3.fromRGB(190, 40, 40), Color3.fromRGB(120, 170, 60), Color3.fromRGB(220, 180, 60), Color3.fromRGB(150, 50, 120) }
	for z = -length / 2 + 2.2, length / 2 - 2.2, 2.6 do
		for _, side in { -1, 1 } do
			-- prato e caneca de cada lugar
			Props.column(parent, cf * CFrame.new(side * 0.85, top, z + side * 0.4), 0.08, 0.95, Color3.fromRGB(150, 140, 125), M.Metal, { CanCollide = false })
			local mug = cf * CFrame.new(side * 1.3, top, z - side * 0.5)
			Props.column(parent, mug, 0.55, 0.42, Color3.fromRGB(120, 85, 50), M.Wood, { CanCollide = false })
			part(parent, { Name = "Alca", Size = Vector3.new(0.1, 0.32, 0.22), CFrame = mug * CFrame.new(0, 0.3, side * 0.27), Color = DARK, Material = M.Wood, CanCollide = false })
		end
		local free = true
		for _, cz in candelabra do
			if math.abs(z - cz) < 1.4 then
				free = false
			end
		end
		if free then
			-- travessa no meio: assado, pães ou frutas
			local center = cf * CFrame.new(0, top, z)
			Props.column(parent, center, 0.1, 1.5, Color3.fromRGB(130, 95, 60), M.Wood, { CanCollide = false })
			local kind = rng:NextInteger(1, 3)
			if kind == 1 then
				Props.ball(parent, (center * CFrame.new(0, 0.42, 0)).Position, 0.85, Color3.fromRGB(150, 80, 40), M.SmoothPlastic, { CanCollide = false })
				part(parent, { Name = "Osso", Size = Vector3.new(0.14, 0.14, 0.8), CFrame = center * CFrame.new(0.3, 0.6, 0.3) * CFrame.Angles(math.rad(-30), math.rad(40), 0), Color = Color3.fromRGB(235, 225, 205), Material = M.SmoothPlastic, CanCollide = false })
			elseif kind == 2 then
				for i = 0, 2 do
					Props.ball(parent, (center * CFrame.new(-0.4 + i * 0.4, 0.3, rng:NextNumber(-0.2, 0.2))).Position, 0.48, Color3.fromRGB(200, 150, 85), M.SmoothPlastic, { CanCollide = false })
				end
			else
				for i = 0, 3 do
					Props.ball(parent, (center * CFrame.new(-0.35 + (i % 2) * 0.7, 0.25 + (i // 2) * 0.12, -0.2 + (i // 2) * 0.4)).Position, 0.36, fruits[i + 1], M.SmoothPlastic, { CanCollide = false })
				end
			end
		end
	end
	-- candelabros de ferro com três velas
	for _, z in candelabra do
		local base = cf * CFrame.new(0, top, z)
		Props.column(parent, base, 0.12, 0.7, IRON, M.Metal, { CanCollide = false })
		part(parent, { Name = "Haste", Size = Vector3.new(0.12, 0.75, 0.12), CFrame = base * CFrame.new(0, 0.45, 0), Color = IRON, Material = M.Metal, CanCollide = false })
		part(parent, { Name = "Braco", Size = Vector3.new(0.12, 0.12, 1.3), CFrame = base * CFrame.new(0, 0.8, 0), Color = IRON, Material = M.Metal, CanCollide = false })
		for _, dz in { -0.6, 0, 0.6 } do
			candle(parent, base * CFrame.new(0, 0.86, dz), if dz == 0 then 0.65 else 0.45)
		end
	end
end

-- lustre de roda (centro da roda em "center", corrente de "drop" até a viga)
local function chandelier(parent, center, drop)
	local R = 1.9
	local top = center * CFrame.new(0, 1.6, 0)
	part(parent, { Name = "Corrente", Size = Vector3.new(0.14, drop - 1.6, 0.14), CFrame = center * CFrame.new(0, 1.6 + (drop - 1.6) / 2, 0), Color = IRON, Material = M.Metal, CanCollide = false })
	for i = 0, 11 do
		part(parent, { Name = "Roda", Size = Vector3.new(2 * R * math.sin(math.rad(15)) + 0.1, 0.22, 0.22), CFrame = center * CFrame.Angles(0, math.rad(i * 30), 0) * CFrame.new(0, 0, -R * math.cos(math.rad(15))), Color = IRON, Material = M.Metal, CanCollide = false })
	end
	for _, a in { 0, 90 } do
		part(parent, { Name = "Raio", Size = Vector3.new(2 * R, 0.16, 0.16), CFrame = center * CFrame.Angles(0, math.rad(a), 0), Color = IRON, Material = M.Metal, CanCollide = false })
	end
	local hub = Props.ball(parent, center.Position, 0.6, IRON, M.Metal, { CanCollide = false })
	Props.light(hub, Color3.fromRGB(255, 200, 140), 26, 0.9)
	for i = 0, 3 do
		beam(parent, (center * CFrame.Angles(0, math.rad(45 + i * 90), 0) * CFrame.new(0, 0, -R)).Position, top.Position, 0.08, IRON, M.Metal, "Corrente")
	end
	for i = 0, 7 do
		local spot = center * CFrame.Angles(0, math.rad(22.5 + i * 45), 0) * CFrame.new(0, 0.11, -R)
		Props.column(parent, spot, 0.15, 0.45, IRON, M.Metal, { CanCollide = false })
		candle(parent, spot * CFrame.new(0, 0.15, 0), 0.6)
	end
end

-- tocha de parede (cf na face da parede, -Z para dentro do salão)
local function wallTorch(parent, cf)
	part(parent, { Name = "Placa", Size = Vector3.new(0.7, 1.0, 0.12), CFrame = cf * CFrame.new(0, 0, -0.06), Color = IRON, Material = M.Metal, CanCollide = false })
	part(parent, { Name = "Suporte", Size = Vector3.new(0.3, 0.3, 0.9), CFrame = cf * CFrame.new(0, 0, -0.55), Color = IRON, Material = M.Metal, CanCollide = false })
	local handle = cf * CFrame.new(0, 0.55, -0.95) * CFrame.Angles(math.rad(-15), 0, 0)
	part(parent, { Name = "Cabo", Size = Vector3.new(0.3, 1.5, 0.3), CFrame = handle, Color = DARK, Material = M.Wood, CanCollide = false })
	part(parent, { Name = "Pano", Size = Vector3.new(0.42, 0.5, 0.42), CFrame = handle * CFrame.new(0, 0.7, 0), Color = Color3.fromRGB(70, 55, 40), Material = M.Fabric, CanCollide = false })
	Props.flame(parent, (handle * CFrame.new(0, 1.05, 0)).Position, 0.7, { light = 16, brightness = 0.9 })
end

-- tocha alta com cesto de ferro (caminho e pátio)
local function torchPost(parent, ground)
	part(parent, { Name = "PosteTocha", Size = Vector3.new(0.6, 5.2, 0.6), CFrame = ground * CFrame.new(0, 2.2, 0), Color = DARK, Material = M.Wood })
	Props.column(parent, ground * CFrame.new(0, 4.7, 0), 0.2, 0.9, IRON, M.Metal, { CanCollide = false })
	for i = 0, 3 do
		part(parent, { Name = "Cesto", Size = Vector3.new(0.12, 1.0, 0.12), CFrame = ground * CFrame.new(0, 5.0, 0) * CFrame.Angles(0, math.rad(i * 90), 0) * CFrame.new(0, 0, -0.42) * CFrame.Angles(math.rad(-18), 0, 0), Color = IRON, Material = M.Metal, CanCollide = false })
	end
	Props.flame(parent, (ground * CFrame.new(0, 5.15, 0)).Position, 1.0, { light = 20 })
end

-- braseiro de ferro num tripé
local function brazier(parent, ground)
	for i = 0, 2 do
		local a = math.rad(i * 120)
		beam(parent, (ground * CFrame.new(math.sin(a) * 1.0, 0, math.cos(a) * 1.0)).Position, (ground * CFrame.new(math.sin(a) * 0.55, 2.3, math.cos(a) * 0.55)).Position, 0.2, IRON, M.Metal, "Perna")
	end
	Props.column(parent, ground * CFrame.new(0, 2.2, 0), 0.7, 1.9, IRON, M.Metal)
	Props.column(parent, ground * CFrame.new(0, 2.75, 0), 0.2, 1.6, EMBERS, M.CrackedLava, { CanCollide = false })
	Props.flame(parent, (ground * CFrame.new(0, 3.0, 0)).Position, 1.0, { width = 1.1, depth = 1.1, light = 18 })
end

-- mastro com flâmula comprida (pano reto, franja e losango)
local function flagPole(parent, ground, color)
	Props.column(parent, ground * CFrame.new(0, -0.5, 0), 13.5, 0.45, DARK, M.Wood)
	Props.ball(parent, (ground * CFrame.new(0, 13.2, 0)).Position, 0.6, GOLD, M.Metal, { CanCollide = false })
	part(parent, { Name = "Travessa", Size = Vector3.new(3.4, 0.25, 0.25), CFrame = ground * CFrame.new(0, 12.3, -0.3), Color = DARK, Material = M.Wood, CanCollide = false })
	part(parent, { Name = "Flamula", Size = Vector3.new(3, 6.2, 0.1), CFrame = ground * CFrame.new(0, 9.05, -0.3), Color = color, Material = M.Fabric, CanCollide = false })
	part(parent, { Name = "Franja", Size = Vector3.new(3.05, 0.35, 0.12), CFrame = ground * CFrame.new(0, 5.8, -0.3), Color = GOLD, Material = M.Fabric, CanCollide = false })
	part(parent, { Name = "Losango", Size = Vector3.new(1.2, 1.2, 0.05), CFrame = ground * CFrame.new(0, 9.4, -0.38) * CFrame.Angles(0, 0, math.rad(45)), Color = GOLD, Material = M.Fabric, CanCollide = false })
end

-- boneco de treino de palha
local function dummy(parent, ground)
	part(parent, { Name = "Poste", Size = Vector3.new(0.4, 5.6, 0.4), CFrame = ground * CFrame.new(0, 2.4, 0), Color = DARK, Material = M.Wood })
	Props.column(parent, ground * CFrame.new(0, 2.0, 0), 2.4, 1.4, STRAW, M.Fabric)
	for _, y in { 2.4, 3.7 } do
		Props.column(parent, ground * CFrame.new(0, y, 0), 0.15, 1.46, Color3.fromRGB(140, 110, 70), M.Fabric, { CanCollide = false })
	end
	part(parent, { Name = "Bracos", Size = Vector3.new(3.2, 0.35, 0.35), CFrame = ground * CFrame.new(0, 3.9, 0), Color = DARK, Material = M.Wood })
	Props.ball(parent, (ground * CFrame.new(0, 5.0, 0)).Position, 1.1, Color3.fromRGB(185, 160, 120), M.Fabric)
end

-- alvo de arco e flecha num cavalete (-Z = frente)
local function archeryTarget(parent, ground, rng)
	local face = ground * CFrame.new(0, 3.2, 0) * CFrame.Angles(math.rad(-12), 0, 0)
	for _, leg in { { Vector3.new(-1.2, 0, -0.3), Vector3.new(-0.9, -0.6, 0.2) }, { Vector3.new(1.2, 0, -0.3), Vector3.new(0.9, -0.6, 0.2) }, { Vector3.new(0, 0, 1.8), Vector3.new(0, 0.6, 0.3) } } do
		beam(parent, (ground * CFrame.new(leg[1])).Position, (face * CFrame.new(leg[2])).Position, 0.25, DARK, M.Wood, "Perna")
	end
	part(parent, { Name = "Alvo", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 3.2, 3.2), CFrame = face * CFrame.Angles(0, math.rad(90), 0), Color = STRAW, Material = M.Fabric })
	for i, ring in { { 2.5, Color3.fromRGB(235, 230, 215) }, { 1.7, Color3.fromRGB(170, 40, 35) }, { 0.8, Color3.fromRGB(220, 180, 60) } } do
		part(parent, { Name = "Anel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.04, ring[1], ring[1]), CFrame = face * CFrame.new(0, 0, -0.27 - i * 0.02) * CFrame.Angles(0, math.rad(90), 0), Color = ring[2], Material = M.Fabric, CanCollide = false })
	end
	for _ = 1, 3 do
		local arrow = face * CFrame.new(rng:NextNumber(-0.9, 0.9), rng:NextNumber(-0.9, 0.9), -0.8) * CFrame.Angles(rng:NextNumber(-0.15, 0.15), rng:NextNumber(-0.15, 0.15), 0)
		part(parent, { Name = "Flecha", Size = Vector3.new(0.07, 0.07, 1.2), CFrame = arrow, Color = Color3.fromRGB(150, 115, 70), Material = M.Wood, CanCollide = false })
		part(parent, { Name = "Pena", Size = Vector3.new(0.02, 0.22, 0.3), CFrame = arrow * CFrame.new(0, 0, -0.5), Color = Color3.fromRGB(230, 225, 215), Material = M.Fabric, CanCollide = false })
	end
end

-- item do jogo (ItemModels) parado no lugar: origem do modelo = cabo da arma / centro da peça
local function showItem(parent, baseId, rarity, where, lit)
	local ok, item = pcall(ItemModels.build, baseId, rarity, { anchored = true })
	if not ok or not item then
		warn("[Salão] Item de exposição falhou: " .. tostring(baseId))
		return nil
	end
	item.Name = "Exposicao"
	item.PrimaryPart = nil
	item.WorldPivot = CFrame.identity
	for _, p in item:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.CanTouch = false
			p.CanQuery = false
		end
	end
	item:PivotTo(where)
	item.Parent = parent
	if lit then
		local first = item:FindFirstChildWhichIsA("BasePart")
		if first then
			Props.light(first, Color3.fromRGB(255, 215, 130), 9, 0.7)
		end
	end
	return item
end

-- manequim com armadura, elmo e botas (base no chão, -Z = frente) — tamanho real
local function armorStand(parent, base, set)
	Props.column(parent, base, 0.35, 2.4, DARK, M.Wood)
	part(parent, { Name = "Haste", Size = Vector3.new(0.4, 5.2, 0.4), CFrame = base * CFrame.new(0, 2.95, 0.15), Color = DARK, Material = M.Wood, CanCollide = false })
	showItem(parent, set[3], set[4], base * CFrame.new(0, 1.3, 0))
	showItem(parent, set[1], set[4], base * CFrame.new(0, 3.55, 0))
	showItem(parent, set[2], set[4], base * CFrame.new(0, 5.75, 0))
end

-- panóplia: duas armas cruzadas atrás de um escudo (face na parede, -Z para dentro) — tamanho real
local function panoply(parent, face, weapons, color)
	for i, entry in weapons do
		local side = if i == 1 then -1 else 1
		showItem(parent, entry[1], entry[2], face * CFrame.new(0, 0, -0.4) * CFrame.Angles(0, 0, math.rad(side * 38)) * CFrame.new(0, -1.8, 0))
	end
	roundShield(parent, face * CFrame.new(0, 0, -0.95), 3.4, color)
end

function GuildHall.build(parent, rng)
	local hall = World.GuildHall
	local W, L, H = hall.width, hall.length, 13
	local halfW, halfL = W / 2, L / 2
	local PL = 1.2 -- topo do alicerce de pedra
	local F = PL + 0.2 -- piso de tábuas
	local T = PL + H -- topo das paredes
	local DOOR, DH = 5, 10 -- meia largura e altura do vão da porta (com os batentes fica 8 de vão livre)
	local PITCH = 40
	local cf = CFrame.new(hall.x, hall.y, hall.z) * CFrame.Angles(0, hall.yaw, 0)
	local model = Instance.new("Model")
	model.Name = "SalaoDasGuildas"
	-- ponto de projeto → CFrame real (para o que entra depois de ampliar)
	local function at(x, y, z, yaw)
		return cf * CFrame.new(x * K, y * K, z * K) * CFrame.Angles(0, math.rad(yaw or 0), 0)
	end

	-- ===== estrutura =====
	part(model, { Name = "Base", Size = Vector3.new(W + 2, PL + 3, L + 2), CFrame = cf * CFrame.new(0, PL - (PL + 3) / 2, 0), Color = STONE, Material = M.Cobblestone })
	part(model, { Name = "Piso", Size = Vector3.new(W - 2, 0.2, L - 2), CFrame = cf * CFrame.new(0, PL + 0.1, 0), Color = Color3.fromRGB(120, 85, 55), Material = M.WoodPlanks })
	for _, sx in { -1, 1 } do
		part(model, { Name = "Parede", Size = Vector3.new(1, H, L), CFrame = cf * CFrame.new(sx * (halfW - 0.5), PL + H / 2, 0), Color = WOOD, Material = M.WoodPlanks })
		part(model, { Name = "Parede", Size = Vector3.new(halfW - 1 - DOOR, H, 1), CFrame = cf * CFrame.new(sx * (DOOR + (halfW - 1 - DOOR) / 2), PL + H / 2, -halfL + 0.5), Color = WOOD, Material = M.WoodPlanks })
		part(model, { Name = "Batente", Size = Vector3.new(1, DH, 1.6), CFrame = cf * CFrame.new(sx * (DOOR - 0.5), PL + DH / 2, -halfL + 0.5), Color = DARK, Material = M.Wood })
	end
	part(model, { Name = "Parede", Size = Vector3.new(W - 2, H, 1), CFrame = cf * CFrame.new(0, PL + H / 2, halfL - 0.5), Color = WOOD, Material = M.WoodPlanks })
	part(model, { Name = "Verga", Size = Vector3.new(DOOR * 2, H - DH, 1), CFrame = cf * CFrame.new(0, PL + DH + (H - DH) / 2, -halfL + 0.5), Color = WOOD, Material = M.WoodPlanks })
	-- quinas entalhadas e mata-juntas por fora (tábuas verticais escuras)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part(model, { Name = "Quina", Size = Vector3.new(1.6, H + 1, 1.6), CFrame = cf * CFrame.new(sx * halfW, PL + (H + 1) / 2, sz * halfL), Color = DARK, Material = M.Wood })
			for _, y in { PL + 1, T - 0.6 } do
				part(model, { Name = "Anel", Size = Vector3.new(1.85, 0.35, 1.85), CFrame = cf * CFrame.new(sx * halfW, y, sz * halfL), Color = Color3.fromRGB(45, 31, 22), Material = M.Wood })
			end
			Props.ball(model, (cf * CFrame.new(sx * halfW, T + 1.5, sz * halfL)).Position, 1.3, DARK, M.Wood)
		end
		for z = -halfL + 4, halfL - 4, 4 do
			part(model, { Name = "MataJunta", Size = Vector3.new(0.3, H, 0.5), CFrame = cf * CFrame.new(sx * (halfW + 0.15), PL + H / 2, z), Color = DARK, Material = M.Wood })
		end
	end
	for x = -halfW + 4, halfW - 4, 4 do
		part(model, { Name = "MataJunta", Size = Vector3.new(0.5, H, 0.3), CFrame = cf * CFrame.new(x, PL + H / 2, halfL + 0.15), Color = DARK, Material = M.Wood })
		if math.abs(x) > DOOR + 1 then
			part(model, { Name = "MataJunta", Size = Vector3.new(0.5, H, 0.3), CFrame = cf * CFrame.new(x, PL + H / 2, -halfL - 0.15), Color = DARK, Material = M.Wood })
		end
	end
	-- pedras do alicerce, meio enterradas (menos embaixo do alpendre)
	local function foundation(x, z)
		local size = Vector3.new(rng:NextNumber(1.3, 2.2), rng:NextNumber(0.7, 1.2), rng:NextNumber(1.1, 1.7))
		stone(model, cf * CFrame.new(x, size.Y * 0.3, z), size, rng)
	end
	for z = -halfL - 0.6, halfL + 0.6, 2.4 do
		for _, sx in { -1, 1 } do
			foundation(sx * (halfW + 1.3), z)
		end
	end
	for x = -halfW, halfW, 2.4 do
		foundation(x, halfL + 1.3)
		if math.abs(x) > 10.5 then
			foundation(x, -halfL - 1.3)
		end
	end
	-- escudos pintados sob o beiral, como nos navios
	for _, sx in { -1, 1 } do
		for i, z in { -34, -26, -18, -10, -2, 6, 14, 22, 30 } do
			roundShield(model, cf * CFrame.new(sx * (halfW + 0.55), T - 3.2, z) * CFrame.Angles(0, math.rad(-sx * 90), 0), 2.8, SHIELDS[(i + (if sx < 0 then 1 else 0)) % #SHIELDS + 1])
		end
	end
	-- verga entalhada sobre a porta (só ornamento, sem texto)
	part(model, { Name = "VigaEntalhada", Size = Vector3.new(DOOR * 2 + 3, 0.9, 0.4), CFrame = cf * CFrame.new(0, PL + DH + 0.45, -halfL - 0.2), Color = DARK, Material = M.Wood })
	for x = -5.5, 5.5, 1.1 do
		Props.ball(model, (cf * CFrame.new(x, PL + DH + 0.45, -halfL - 0.42)).Position, 0.35, Color3.fromRGB(45, 31, 22), M.Wood, { CanCollide = false })
	end
	-- portas abertas para fora
	for _, sx in { -1, 1 } do
		local hinge = cf * CFrame.new(sx * DOOR, PL + 0.1 + (DH - 0.4) / 2, -halfL - 0.2)
		local leaf = hinge * CFrame.Angles(0, math.rad(sx * 70), 0) * CFrame.new(sx * 2.4, 0, 0)
		part(model, { Name = "Porta", Size = Vector3.new(4.8, DH - 0.4, 0.35), CFrame = leaf, Color = Color3.fromRGB(80, 55, 35), Material = M.WoodPlanks })
		for _, y in { -3, 0, 3 } do
			part(model, { Name = "Ferragem", Size = Vector3.new(4.2, 0.3, 0.1), CFrame = leaf * CFrame.new(0, y, -0.22), Color = IRON, Material = M.Metal })
		end
		Props.ball(model, (leaf * CFrame.new(-sx * 1.6, 0, -0.3)).Position, 0.45, IRON, M.Metal, { CanCollide = false })
	end

	-- ===== telhado alto com tábuas cruzadas e cabeças de dragão =====
	local rise = Props.roof(model, cf * CFrame.new(0, T, 0), W, L, PITCH, ROOF)
	for _, sz in { -1, 1 } do
		crossedBoards(model, cf * CFrame.new(0, T + rise, sz * (halfL + 1.25)), PITCH, sz, 1)
	end
	-- cunha em cima das paredes dos lados, com a inclinação do telhado: fecha a fresta entre a parede e as
	-- telhas (sem ela o céu aparece por dentro) e faz o forro do beiral por fora
	local eaveWidth = 1.8
	local eaveHeight = eaveWidth * math.tan(math.rad(PITCH))
	for _, sx in { -1, 1 } do
		part(model, { Name = "Beiral", Shape = Enum.PartType.Wedge, Size = Vector3.new(L, eaveHeight, eaveWidth), CFrame = cf * CFrame.new(sx * (halfW - 1 + eaveWidth / 2), T + eaveHeight / 2, 0) * CFrame.Angles(0, math.rad(-sx * 90), 0), Color = WOOD, Material = M.WoodPlanks })
	end
	-- fumaça saindo pela cumeeira (em cima da fogueira)
	local vent = part(model, { Name = "Respiro", Size = Vector3.new(2, 0.4, 3), CFrame = cf * CFrame.new(0, T + rise + 0.9, -3), Color = DARK, Material = M.Wood, CanCollide = false })
	Props.smoke(vent, 4).Texture = "rbxasset://textures/particles/smoke_main.dds"

	-- ===== alpendre na porta =====
	local PP = PL + DH + 0.6 -- topo dos pilares
	local PZ = -halfL - 8 -- frente do alpendre
	part(model, { Name = "PisoAlpendre", Size = Vector3.new(19, PL + 3, 7.6), CFrame = cf * CFrame.new(0, PL - (PL + 3) / 2, -halfL - 4.8), Color = STONE, Material = M.Slate })
	part(model, { Name = "Degrau", Size = Vector3.new(12, 1.6, 1.2), CFrame = cf * CFrame.new(0, 0, PZ - 1.2), Color = STONE, Material = M.Slate })
	part(model, { Name = "Degrau", Size = Vector3.new(12, 1.2, 1.2), CFrame = cf * CFrame.new(0, -0.2, PZ - 2.4), Color = STONE, Material = M.Slate })
	for _, sx in { -1, 1 } do
		local x = sx * 8.2
		part(model, { Name = "BasePilar", Size = Vector3.new(1.4, 0.5, 1.4), CFrame = cf * CFrame.new(x, PL + 0.25, PZ + 0.3), Color = STONE, Material = M.Slate })
		part(model, { Name = "Pilar", Size = Vector3.new(0.9, PP - PL - 0.5, 0.9), CFrame = cf * CFrame.new(x, (PP + PL + 0.5) / 2, PZ + 0.3), Color = DARK, Material = M.Wood })
		for _, y in { PL + 1.4, PP - 1.6 } do
			part(model, { Name = "Anel", Size = Vector3.new(1.1, 0.3, 1.1), CFrame = cf * CFrame.new(x, y, PZ + 0.3), Color = Color3.fromRGB(45, 31, 22), Material = M.Wood })
		end
		part(model, { Name = "Capitel", Size = Vector3.new(1.3, 0.5, 1.3), CFrame = cf * CFrame.new(x, PP - 0.25, PZ + 0.3), Color = Color3.fromRGB(45, 31, 22), Material = M.Wood })
		local sideLength = -halfL - (PZ + 0.3)
		part(model, { Name = "VigaAlpendre", Size = Vector3.new(0.8, 0.8, sideLength), CFrame = cf * CFrame.new(x, PP + 0.4, PZ + 0.3 + sideLength / 2), Color = DARK, Material = M.Wood, CanCollide = false })
		beam(model, (cf * CFrame.new(x - sx * 0.3, PP - 2.2, PZ + 0.3)).Position, (cf * CFrame.new(x - sx * 2.4, PP + 0.1, PZ + 0.3)).Position, 0.45)
		-- barris dos lados do alpendre
		Props.barrel(model, cf * CFrame.new(sx * 11.6, 0, -halfL - 3), 0.85)
	end
	Props.crate(model, cf * CFrame.new(12.4, 0, -halfL - 5.4) * CFrame.Angles(0, math.rad(20), 0), 1.6)
	part(model, { Name = "VigaAlpendre", Size = Vector3.new(17.8, 0.8, 0.8), CFrame = cf * CFrame.new(0, PP + 0.4, PZ + 0.3), Color = DARK, Material = M.Wood, CanCollide = false })
	-- o fundo do telhado do alpendre para antes da parede (as telhas passam 0,8 da ponta e não podem
	-- aparecer do lado de dentro, acima da parede da frente)
	local porchRise = Props.roof(model, cf * CFrame.new(0, PP + 0.8, (PZ - halfL - 0.8) / 2), 17.6, -halfL - 0.8 - PZ, PITCH, ROOF)
	crossedBoards(model, cf * CFrame.new(0, PP + 0.8 + porchRise, PZ - 1.1), PITCH, -1, 0.55)
	-- lanterna de ferro pendurada no alpendre
	local lantern = cf * CFrame.new(0, PP - 1.4, PZ + 0.3)
	part(model, { Name = "Corrente", Size = Vector3.new(0.1, 1.2, 0.1), CFrame = lantern * CFrame.new(0, 1.2, 0), Color = IRON, Material = M.Metal, CanCollide = false })
	part(model, { Name = "Tampa", Size = Vector3.new(0.9, 0.2, 0.9), CFrame = lantern * CFrame.new(0, 0.55, 0), Color = IRON, Material = M.Metal, CanCollide = false })
	part(model, { Name = "Fundo", Size = Vector3.new(0.8, 0.15, 0.8), CFrame = lantern * CFrame.new(0, -0.5, 0), Color = IRON, Material = M.Metal, CanCollide = false })
	for _, corner in { { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } } do
		part(model, { Name = "Grade", Size = Vector3.new(0.08, 1.0, 0.08), CFrame = lantern * CFrame.new(corner[1] * 0.36, 0, corner[2] * 0.36), Color = IRON, Material = M.Metal, CanCollide = false })
	end
	Props.flame(model, (lantern * CFrame.new(0, -0.4, 0)).Position, 0.45, { light = 18, sparks = false, rate = 12 })

	-- ===== caminho de lajes até a estrada, com tochas e flâmulas =====
	for z = -halfL - 11.8, -halfL - 22, -1.5 do
		local mid = math.sin(z * 0.23) * 0.7
		local x = -2.2
		while x < 2.1 do
			local w = rng:NextNumber(1.1, 1.7)
			part(model, { Name = "Laje", Size = Vector3.new(w, 0.5, rng:NextNumber(1.0, 1.35)), CFrame = cf * CFrame.new(mid + x + w / 2, -0.12, z + rng:NextNumber(-0.15, 0.15)) * CFrame.Angles(0, rng:NextNumber(-0.25, 0.25), 0), Color = STONE:Lerp(Color3.fromRGB(150, 140, 120), rng:NextNumber(0, 0.6)), Material = M.Slate })
			x += w + rng:NextNumber(0.12, 0.3)
		end
		for _, sx in { -1, 1 } do
			if rng:NextNumber() < 0.7 then
				local size = rng:NextNumber(0.45, 0.8)
				stone(model, cf * CFrame.new(mid + sx * rng:NextNumber(2.7, 3.1), size * 0.2, z), Vector3.new(size * 1.3, size, size), rng)
			end
		end
	end
	for _, z in { -halfL - 13.5, -halfL - 20.5 } do
		for _, sx in { -1, 1 } do
			torchPost(model, cf * CFrame.new(sx * 3.9, 0, z))
		end
	end
	flagPole(model, cf * CFrame.new(-7.5, 0, -halfL - 16.5), Color3.fromRGB(140, 35, 40))
	flagPole(model, cf * CFrame.new(7.5, 0, -halfL - 16.5), Color3.fromRGB(35, 60, 130))
	for _, spot in { { -13.5, -halfL - 2.6 }, { 13.8, -halfL - 2.2 }, { -halfW - 3, 26 }, { halfW + 3, 30 }, { halfW + 3, 14 }, { -halfW - 3, 36 } } do
		Props.bush(model, cf * CFrame.new(spot[1], 0, spot[2]), 0.8, rng)
	end
	for _, spot in { { -5.8, -halfL - 11.5 }, { 5.8, -halfL - 12 }, { -6, -halfL - 19 }, { 6.2, -halfL - 22 } } do
		Props.flowers(model, cf * CFrame.new(spot[1], 0, spot[2]), rng)
	end

	-- ===== pátio de treino (lado esquerdo de quem entra) =====
	dummy(model, cf * CFrame.new(-halfW - 7, 0, -20) * CFrame.Angles(0, math.rad(20), 0))
	dummy(model, cf * CFrame.new(-halfW - 11.5, 0, -15) * CFrame.Angles(0, math.rad(-15), 0))
	archeryTarget(model, cf * CFrame.new(-halfW - 9, 0, -2) * CFrame.Angles(0, math.rad(180), 0), rng)
	for _, z in { -24, -6 } do
		torchPost(model, cf * CFrame.new(-halfW - 3.5, 0, z))
	end

	-- ===== lenha com telheiro, toco com machado e carroça (lado direito) =====
	for row = 0, 2 do
		for col = 0, 3 - row do
			log(model, cf * CFrame.new(halfW + 1.6 + col * 0.92 + row * 0.46, 0.45 + row * 0.8, -14), 6, 0.9, Color3.fromRGB(105, 75, 50))
		end
	end
	for _, z in { -17.8, -10.2 } do
		part(model, { Name = "PosteTelheiro", Size = Vector3.new(0.5, 6.4, 0.5), CFrame = cf * CFrame.new(halfW + 5.4, 3, z), Color = DARK, Material = M.Wood })
	end
	local roofFrom, roofTo = Vector2.new(halfW + 0.35, 8.7), Vector2.new(halfW + 6, 6.2)
	local slope = roofTo - roofFrom
	part(model, { Name = "Telheiro", Size = Vector3.new(slope.Magnitude, 0.3, 9), CFrame = cf * CFrame.new((roofFrom.X + roofTo.X) / 2, (roofFrom.Y + roofTo.Y) / 2 + 0.15, -14) * CFrame.Angles(0, 0, math.atan2(slope.Y, slope.X)), Color = ROOF, Material = M.WoodPlanks })
	local stumpTop = 1.6
	Props.column(model, cf * CFrame.new(halfW + 3.6, -0.2, -6.5), stumpTop + 0.2, 1.8, Color3.fromRGB(110, 80, 55), M.Wood)
	Props.cart(model, cf * CFrame.new(halfW + 8, 0, 3) * CFrame.Angles(0, math.rad(15), 0))

	-- ===== interior: colunas, vigas altas e caibros =====
	local CB = T + 4 -- vigas de travamento, bem acima das cabeças
	local PT = T + 4.6 -- topo das colunas (terças por cima)
	for z = -32, 32, 8 do
		for _, sx in { -1, 1 } do
			local x = sx * 13.5
			part(model, { Name = "BaseColuna", Size = Vector3.new(1.9, 0.6, 1.9), CFrame = cf * CFrame.new(x, F + 0.3, z), Color = STONE, Material = M.Slate })
			Props.column(model, cf * CFrame.new(x, F + 0.6, z), PT - F - 0.6, 1.3, DARK, M.Wood)
			for _, y in { F + 1.3, CB - 1.4 } do
				Props.column(model, cf * CFrame.new(x, y, z), 0.35, 1.5, IRON, M.Metal, { CanCollide = false })
			end
			beam(model, (cf * CFrame.new(x - sx * 0.4, CB - 3.4, z)).Position, (cf * CFrame.new(sx * 10, CB - 0.2, z)).Position, 0.55, nil, nil, "MaoFrancesa")
			part(model, { Name = "TiranteLateral", Size = Vector3.new(halfW - 1 - 13.5, 0.7, 0.7), CFrame = cf * CFrame.new(sx * (13.5 + halfW - 1) / 2, T - 0.4, z), Color = DARK, Material = M.Wood, CanCollide = false })
		end
		part(model, { Name = "Travamento", Size = Vector3.new(27.6, 0.9, 0.9), CFrame = cf * CFrame.new(0, CB, z), Color = DARK, Material = M.Wood, CanCollide = false })
	end
	for _, sx in { -1, 1 } do
		part(model, { Name = "Terca", Size = Vector3.new(1.1, 0.9, L - 2), CFrame = cf * CFrame.new(sx * 13.5, PT + 0.45, 0), Color = DARK, Material = M.Wood, CanCollide = false })
	end
	local tan = math.tan(math.rad(PITCH))
	local eave = halfW + 0.8
	for z = -38, 38, 4 do
		for _, sx in { -1, 1 } do
			local low = cf * Vector3.new(sx * (halfW - 1.2), T + (eave - (halfW - 1.2)) * tan - 0.6, z)
			local high = cf * Vector3.new(0, T + eave * tan - 0.6, z)
			beam(model, low, high, 0.5, nil, nil, "Caibro")
		end
	end

	-- ===== fogueira comprida de brasas =====
	local HZ0, HZ1 = -15, 9 -- pontas do leito de brasas
	part(model, { Name = "Brasas", Size = Vector3.new(3.2, 0.25, HZ1 - HZ0), CFrame = cf * CFrame.new(0, F + 0.125, (HZ0 + HZ1) / 2), Color = EMBERS, Material = M.CrackedLava, CanCollide = false })
	local function rim(x, z)
		stone(model, cf * CFrame.new(x, F + 0.3, z), Vector3.new(rng:NextNumber(0.9, 1.3), rng:NextNumber(0.6, 0.85), rng:NextNumber(0.9, 1.3)), rng)
	end
	for z = HZ0 - 0.6, HZ1 + 0.6, 1.15 do
		rim(-2.25, z)
		rim(2.25, z)
	end
	for x = -1.15, 1.15, 1.15 do
		rim(x, HZ0 - 0.75)
		rim(x, HZ1 + 0.75)
	end
	for _, z in { -11.5, -4.5, 2.5 } do
		for i, angle in { -35, 35, 90 } do
			part(model, { Name = "Lenha", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.4, 0.45, 0.45), CFrame = cf * CFrame.new(0, F + 0.4 + (if i == 3 then 0.35 else 0), z) * CFrame.Angles(0, math.rad(angle), math.rad(if i == 3 then 0 else 10)), Color = Color3.fromRGB(48, 32, 22), Material = M.Wood, CanCollide = false })
		end
		Props.flame(model, (cf * CFrame.new(0, F + 0.55, z)).Position, 1.5, { width = 2, depth = 2.6, light = 24, smoke = true })
	end
	-- caldeirão pendurado num tripé na ponta da fogueira
	local pot = Vector3.new(0, F, 7)
	local apex = cf * (pot + Vector3.new(0, 5.2, 0))
	for i = 0, 2 do
		local a = math.rad(i * 120)
		beam(model, cf * (pot + Vector3.new(math.sin(a) * 2, 0, math.cos(a) * 2)), apex, 0.22, IRON, M.Metal, "Tripe")
	end
	part(model, { Name = "Corrente", Size = Vector3.new(0.12, 2, 0.12), CFrame = cf * CFrame.new(pot + Vector3.new(0, 4.2, 0)), Color = IRON, Material = M.Metal, CanCollide = false })
	Props.ball(model, (cf * CFrame.new(pot + Vector3.new(0, 2.2, 0))).Position, 1.9, IRON, M.Metal, { CanCollide = false })
	Props.column(model, cf * CFrame.new(pot + Vector3.new(0, 2.85, 0)), 0.25, 1.75, IRON, M.Metal, { CanCollide = false })
	Props.column(model, cf * CFrame.new(pot + Vector3.new(0, 3.0, 0)), 0.06, 1.5, Color3.fromRGB(110, 70, 40), M.SmoothPlastic, { CanCollide = false })
	Props.flame(model, (cf * CFrame.new(pot + Vector3.new(0, 0.4, 0))).Position, 0.8, { light = 0, rate = 14 })

	-- ===== mesas de banquete, bancos e lustres =====
	for _, sx in { -1, 1 } do
		local tableCf = cf * CFrame.new(sx * 8.5, F, -4)
		feastTable(model, tableCf, 3.2, 32, 1.9, rng)
		for _, bx in { -2.35, 2.35 } do
			part(model, { Name = "Banco", Size = Vector3.new(0.95, 1.1, 30), CFrame = tableCf * CFrame.new(bx, 0.55, 0), Color = WOOD, Material = M.Wood })
		end
		for _, z in { -16, 0, 16 } do
			chandelier(model, cf * CFrame.new(sx * 8.5, T - 3, z), CB - 0.45 - (T - 3))
		end
	end
	-- tapete do corredor da porta e tapete grande da roda de conversa (entre as mesas e o estrado)
	for _, rug in { { -28.5, 4.4, 20, Color3.fromRGB(120, 38, 35) }, { 20.5, 14, 10, Color3.fromRGB(40, 60, 95) } } do
		local z, width, depth = rug[1], rug[2], rug[3]
		part(model, { Name = "Tapete", Size = Vector3.new(width, 0.06, depth), CFrame = cf * CFrame.new(0, F + 0.03, z), Color = rug[4], Material = M.Fabric, CanCollide = false })
		for _, s in { -1, 1 } do
			part(model, { Name = "Barra", Size = Vector3.new(0.4, 0.04, depth - 0.4), CFrame = cf * CFrame.new(s * (width / 2 - 0.45), F + 0.08, z), Color = GOLD, Material = M.Fabric, CanCollide = false })
			part(model, { Name = "Barra", Size = Vector3.new(width - 0.4, 0.04, 0.4), CFrame = cf * CFrame.new(0, F + 0.085, z + s * (depth / 2 - 0.45)), Color = GOLD, Material = M.Fabric, CanCollide = false })
		end
	end

	-- ===== paredes por dentro: tochas (as armas, escudos e armaduras entram depois de ampliar) =====
	for _, sx in { -1, 1 } do
		for _, z in { -20, -4, 12, 28 } do
			wallTorch(model, cf * CFrame.new(sx * (halfW - 1), F + 6.2, z) * CFrame.Angles(0, math.rad(sx * 90), 0))
		end
	end

	-- ===== estrado do fundo =====
	part(model, { Name = "Estrado", Size = Vector3.new(32, 1, 10), CFrame = cf * CFrame.new(0, F + 0.5, 34), Color = DARK, Material = M.WoodPlanks })
	part(model, { Name = "Degrau", Size = Vector3.new(32, 0.5, 1), CFrame = cf * CFrame.new(0, F + 0.25, 28.5), Color = DARK, Material = M.WoodPlanks })
	local top = F + 1
	-- peles no chão onde ficam a Helena (x = -8.5) e o Ulf (x = 8.5); os NPCs ficam em z = 34 (NPCs.List)
	for _, x in { -8.5, 8.5 } do
		local sx = if x < 0 then -1 else 1
		part(model, { Name = "Pele", Size = Vector3.new(3.6, 0.08, 3), CFrame = cf * CFrame.new(x, top + 0.04, 34) * CFrame.Angles(0, math.rad(sx * 8), 0), Color = Color3.fromRGB(150, 120, 90), Material = M.Fabric, CanCollide = false })
		local desk = cf * CFrame.new(x, top, 31.4)
		part(model, { Name = "Mesinha", Size = Vector3.new(3.6, 0.3, 1.5), CFrame = desk * CFrame.new(0, 1.9, 0), Color = Color3.fromRGB(105, 70, 45), Material = M.WoodPlanks })
		for _, lx in { -1.5, 1.5 } do
			part(model, { Name = "Pe", Size = Vector3.new(0.35, 1.75, 0.35), CFrame = desk * CFrame.new(lx, 0.875, 0), Color = DARK, Material = M.Wood })
		end
		candle(model, desk * CFrame.new(-sx * 1.3, 2.05, 0.3), 0.55)
	end
	-- pergaminhos do Ulf; livro, tinteiro e pena da Helena
	for i = 0, 2 do
		part(model, { Name = "Pergaminho", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 0.3, 0.3), CFrame = cf * CFrame.new(8.5 - 0.3 + i * 0.5, top + 2.2, 31.3) * CFrame.Angles(0, math.rad(90 + i * 12), 0), Color = Color3.fromRGB(230, 215, 175), Material = M.SmoothPlastic })
	end
	part(model, { Name = "Livro", Size = Vector3.new(1.3, 0.25, 0.95), CFrame = cf * CFrame.new(-8.9, top + 2.18, 31.4) * CFrame.Angles(0, math.rad(-8), 0), Color = Color3.fromRGB(120, 40, 40), Material = M.Fabric })
	Props.column(model, cf * CFrame.new(-7.8, top + 2.05, 31.2), 0.3, 0.3, Color3.fromRGB(30, 30, 40), M.Glass)
	part(model, { Name = "Pena", Size = Vector3.new(0.05, 0.7, 0.15), CFrame = cf * CFrame.new(-7.8, top + 2.6, 31.2) * CFrame.Angles(0, 0, math.rad(20)), Color = Color3.fromRGB(235, 235, 230), Material = M.Fabric, CanCollide = false })
	-- estante de livros atrás da Helena e quadro de contratos atrás do Ulf
	Props.shelf(model, cf * CFrame.new(-14.5, top, 37.6), 4.6, 3, "books", rng)
	for _, x in { 12.7, 16.3 } do
		part(model, { Name = "PosteQuadro", Size = Vector3.new(0.4, 5.5, 0.4), CFrame = cf * CFrame.new(x, top + 2.75, 37.8), Color = DARK, Material = M.Wood })
	end
	local board = part(model, { Name = "QuadroContratos", Size = Vector3.new(3.6, 2.6, 0.3), CFrame = cf * CFrame.new(14.5, top + 3.8, 37.8), Color = Color3.fromRGB(130, 95, 60), Material = M.WoodPlanks })
	for i = 0, 3 do
		part(model, { Name = "Aviso", Size = Vector3.new(0.9, 1.1, 0.05), CFrame = cf * CFrame.new(13.3 + (i % 2) * 1.2 + (i // 2) * 0.6, top + 4.3 - (i // 2) * 1.2, 37.63) * CFrame.Angles(0, 0, math.rad((i - 1.5) * 5)), Color = Color3.fromRGB(235, 225, 195), Material = M.SmoothPlastic, CanCollide = false })
	end
	Props.readable(board, "Contratos da Guilda", BOARD_TEXT, 18)
	-- pedestais dos troféus (os itens entram depois de ampliar) e braseiros na frente do estrado
	for _, x in { -3.6, 3.6 } do
		Props.column(model, cf * CFrame.new(x, top, 30.4), 2.2, 1.4, STONE, M.Slate)
		Props.column(model, cf * CFrame.new(x, top + 2.2, 30.4), 0.25, 1.7, Color3.fromRGB(90, 86, 80), M.Slate)
	end
	for _, x in { -15.8, 15.8 } do
		brazier(model, cf * CFrame.new(x, F, 26.5))
	end

	-- ===== Mural de Honra e estandartes de honra (cores das 3 primeiras guildas da semana) =====
	local back = halfL - 1 -- face de dentro da parede do fundo
	part(model, { Name = "MolduraMural", Size = Vector3.new(15, 7, 0.2), CFrame = cf * CFrame.new(0, F + 5.4, back - 0.1), Color = DARK, Material = M.Wood })
	part(model, { Name = "MuralHonra", Size = Vector3.new(14, 6, 0.3), CFrame = cf * CFrame.new(0, F + 5.4, back - 0.35), Color = Color3.fromRGB(40, 32, 26), Material = M.Wood })
	local function honorBanner(name, x, height, width)
		local rod = cf * CFrame.new(x, T - 0.5, back - 0.3)
		part(model, { Name = "Vara", Size = Vector3.new(width + 0.6, 0.25, 0.25), CFrame = rod, Color = DARK, Material = M.Wood, CanCollide = false })
		part(model, { Name = name, Size = Vector3.new(width, height, 0.1), CFrame = rod * CFrame.new(0, -height / 2 - 0.1, 0.05), Color = Color3.fromRGB(90, 85, 80), Material = M.Fabric, CanCollide = false })
		part(model, { Name = "Franja", Size = Vector3.new(width + 0.05, 0.35, 0.12), CFrame = rod * CFrame.new(0, -height - 0.25, 0.05), Color = GOLD, Material = M.Fabric, CanCollide = false })
	end
	honorBanner("EstandarteHonra1", 0, 3.4, 4)
	honorBanner("EstandarteHonra2", -10.5, 7, 3)
	honorBanner("EstandarteHonra3", 10.5, 7, 3)

	-- ===== barril de hidromel (brinde) e canto das armas =====
	local meadCf = cf * CFrame.new(16.6, F + 1.85, -35.5)
	local mead = part(model, { Name = "BarrilHidromel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3.6, 2.7, 2.7), CFrame = meadCf, Color = Color3.fromRGB(112, 74, 42), Material = M.Wood })
	for _, dx in { -1.25, 1.25 } do
		part(model, { Name = "Aro", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.22, 2.8, 2.8), CFrame = meadCf * CFrame.new(dx, 0, 0), Color = IRON, Material = M.Metal, CanCollide = false })
		part(model, { Name = "Berco", Size = Vector3.new(0.5, 0.9, 2.6), CFrame = cf * CFrame.new(16.6 + dx * 0.9, F + 0.45, -35.5), Color = DARK, Material = M.Wood })
	end
	part(model, { Name = "Torneira", Size = Vector3.new(0.6, 0.22, 0.22), CFrame = meadCf * CFrame.new(-2.05, -0.7, 0), Color = Color3.fromRGB(170, 140, 80), Material = M.Metal, CanCollide = false })
	part(model, { Name = "Bica", Size = Vector3.new(0.16, 0.35, 0.16), CFrame = meadCf * CFrame.new(-2.25, -0.85, 0), Color = Color3.fromRGB(170, 140, 80), Material = M.Metal, CanCollide = false })
	Props.column(model, cf * CFrame.new(14.3, F, -35.5), 0.55, 0.45, Color3.fromRGB(120, 85, 50), M.Wood, { CanCollide = false })
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BrindeSalao"
	prompt.ActionText = "Brindar"
	prompt.ObjectText = "Barril de Hidromel"
	prompt.HoldDuration = 0.6
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = mead
	-- mesinha dos chifres de beber
	part(model, { Name = "Mesinha", Size = Vector3.new(2.4, 0.25, 1.6), CFrame = cf * CFrame.new(12.6, F + 1.9, -37.4), Color = Color3.fromRGB(105, 70, 45), Material = M.WoodPlanks })
	part(model, { Name = "Pe", Size = Vector3.new(0.4, 1.78, 0.4), CFrame = cf * CFrame.new(12.6, F + 0.89, -37.4), Color = DARK, Material = M.Wood })
	for i = 0, 2 do
		local horn = cf * CFrame.new(11.9 + i * 0.7, F + 2.2, -37.4) * CFrame.Angles(0, math.rad(80 + i * 10), math.rad(25))
		part(model, { Name = "Chifre", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.7, 0.36, 0.36), CFrame = horn, Color = Color3.fromRGB(225, 205, 160), Material = M.SmoothPlastic, CanCollide = false })
		part(model, { Name = "Ponta", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 0.22, 0.22), CFrame = horn * CFrame.new(0.5, 0.12, 0) * CFrame.Angles(0, 0, math.rad(25)), Color = Color3.fromRGB(90, 70, 50), Material = M.SmoothPlastic, CanCollide = false })
	end
	-- suporte de armas (lado esquerdo da entrada; as armas entram depois de ampliar)
	part(model, { Name = "BaseArmas", Size = Vector3.new(1.4, 0.3, 6), CFrame = cf * CFrame.new(-17.4, F + 0.15, -35.5), Color = DARK, Material = M.WoodPlanks })
	for _, z in { -38.2, -32.8 } do
		part(model, { Name = "PosteArmas", Size = Vector3.new(0.4, 3.8, 0.4), CFrame = cf * CFrame.new(-17.8, F + 1.9, z), Color = DARK, Material = M.Wood })
	end
	part(model, { Name = "TravessaArmas", Size = Vector3.new(0.3, 0.3, 5.8), CFrame = cf * CFrame.new(-17.8, F + 3.4, -35.5), Color = DARK, Material = M.Wood, CanCollide = false })

	model.Parent = parent
	Props.scaleModel(model, cf, K)

	-- ===== itens do jogo expostos, no tamanho real =====
	for i, z in { -28, -12, 4, 20 } do
		for j, sx in { -1, 1 } do
			local k = (i - 1) * 2 + j
			armorStand(model, at(sx * 17.3, F, z, sx * 90), ARMOR_SETS[k])
			panoply(model, at(sx * (halfW - 1), F + 8.6, z, sx * 90), WALL_WEAPONS[k], SHIELDS[k % #SHIELDS + 1])
		end
	end
	for i, baseId in RACK_WEAPONS do
		showItem(model, baseId, "Comum", at(-17.1, F + 0.3, -35.5 + (i - 3) * 1.05, -90) * CFrame.new(0, 0.75, 0) * CFrame.Angles(math.rad(15), 0, 0))
	end
	for i, trophy in TROPHIES do
		showItem(model, trophy[1], trophy[2], at(if i == 1 then -3.6 else 3.6, top + 2.45, 30.4, 180) * CFrame.new(0, 0.9, 0), true)
	end
	-- machado cravado no toco, do lado da lenha
	showItem(model, "machado_lenhador", "Comum", at(halfW + 3.6, stumpTop, -6.5, 30) * CFrame.Angles(0, 0, math.rad(130)) * CFrame.new(0, -3.1, 0))

	Placement.reserve(hall.x, hall.z, 72, "salao")
	local yard = cf * CFrame.new(0, 0, (-halfL - 12) * K)
	Placement.reserve(yard.X, yard.Z, 26, "salao")
	return model
end

return GuildHall
