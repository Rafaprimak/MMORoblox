-- Entorno dos locais de interesse: transforma cada local numa área de verdade, com várias construções
-- e detalhes em volta da peça principal (PointsOfInterest) e um SEGREDO escondido (prompt "SegredoLocal",
-- tratado pelo ExploreService; recompensa em Points[...].secret, uma vez por jogador).
-- Tudo é montado em unidades de projeto relativas ao centro (cf) e ampliado junto com o local; cada peça
-- é apoiada no chão de verdade com `ground(dx, dz)` (o chão em volta do local é aplainado pelo Points).
local CollectionService = game:GetService("CollectionService")

local Props = require(script.Parent.Props)

local PoiAreas = {}

local M = Enum.Material
local C = Props.Colors
local part = Props.part

local STONE = Color3.fromRGB(150, 145, 135)
local OLD_STONE = Color3.fromRGB(120, 118, 110)
local MOSS = Color3.fromRGB(85, 125, 60)
local RUNE = Color3.fromRGB(140, 200, 255)

-- ===================== AJUDANTES =====================

-- area = { cf, size, groundAt, model, rng }
local function ground(area, dx, dz, yaw)
	local world = area.cf * CFrame.new(dx * area.size, 0, dz * area.size)
	local y = (area.groundAt(world.X, world.Z) - area.cf.Y) / area.size
	return area.cf * CFrame.new(dx, y, dz) * CFrame.Angles(0, yaw or 0, 0)
end

-- giro para a frente (-Z) da peça olhar para o centro do local
local function faceCenter(dx, dz)
	return math.atan2(dx, dz)
end

-- pontos num anel (ângulo com um pouco de variação)
local function ring(area, count, radius, jitter, fn)
	local offset = area.rng:NextNumber(0, math.pi * 2)
	for i = 0, count - 1 do
		local a = offset + i / count * math.pi * 2 + area.rng:NextNumber(-jitter, jitter)
		local r = radius * area.rng:NextNumber(0.9, 1.1)
		fn(math.cos(a) * r, math.sin(a) * r, i)
	end
end

local function menhir(area, dx, dz, height, fallen)
	local cf = ground(area, dx, dz, faceCenter(dx, dz))
	local rng = area.rng
	if fallen then
		part(area.model, { Name = "MenirCaido", Size = Vector3.new(2.6, 2.2, height), CFrame = cf * CFrame.new(0, 1, 0) * CFrame.Angles(0, rng:NextNumber(-0.5, 0.5), 0), Color = OLD_STONE, Material = M.Slate })
		return
	end
	part(area.model, { Name = "Menir", Size = Vector3.new(2.6, height, 2.2), CFrame = cf * CFrame.new(0, height / 2 - 0.5, 0) * CFrame.Angles(rng:NextNumber(-0.06, 0.06), 0, rng:NextNumber(-0.06, 0.06)), Color = OLD_STONE:Lerp(STONE, rng:NextNumber()), Material = M.Slate })
	part(area.model, { Name = "Musgo", Size = Vector3.new(2.7, 0.3, 2.3), CFrame = cf * CFrame.new(0, height - 0.55, 0), Color = MOSS, Material = M.Grass, CanCollide = false })
end

local function brazier(area, dx, dz, color)
	local cf = ground(area, dx, dz)
	Props.column(area.model, cf, 2.6, 1, Color3.fromRGB(55, 50, 50), M.Metal)
	Props.column(area.model, cf * CFrame.new(0, 2.6, 0), 0.6, 2.2, Color3.fromRGB(65, 60, 58), M.Metal)
	local flame = Props.fire(area.model, (cf * CFrame.new(0, 3.2, 0)).Position, 0.8)
	if color and flame then
		flame.Color = color
		local light = flame:FindFirstChildOfClass("PointLight")
		if light then
			light.Color = color
		end
	end
end

local function brokenColumn(area, dx, dz)
	local rng = area.rng
	local cf = ground(area, dx, dz, rng:NextNumber(0, 6))
	local h = rng:NextNumber(3, 9)
	part(area.model, { Name = "BaseColuna", Size = Vector3.new(3, 0.8, 3), CFrame = cf * CFrame.new(0, 0.4, 0), Color = OLD_STONE, Material = M.Slate })
	Props.column(area.model, cf * CFrame.new(0, 0.8, 0), h, 2.1, STONE, M.Marble)
	if rng:NextNumber() < 0.5 then
		part(area.model, { Name = "Pedaco", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3.4, 2.1, 2.1), CFrame = cf * CFrame.new(2.6, 1, 0.5) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Color = STONE, Material = M.Marble })
	end
end

local function hay(area, dx, dz)
	local cf = ground(area, dx, dz, area.rng:NextNumber(0, 3))
	part(area.model, { Name = "Feno", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.2, 2.4, 2.4), CFrame = cf * CFrame.new(0, 1.2, 0) * CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(math.rad(90), 0, 0), Color = Color3.fromRGB(215, 185, 95), Material = M.Fabric })
end

local function deadTree(area, dx, dz, scale)
	Props.deadTree(area.model, ground(area, dx, dz, area.rng:NextNumber(0, 6)), scale or 0.9, area.rng)
end

-- objeto do segredo: discreto, o prompt só aparece bem perto
local function secret(area, cf, action, object)
	local holder = part(area.model, { Name = "Segredo", Size = Vector3.new(1.2, 0.6, 1.2), CFrame = cf, Transparency = 1, CanCollide = false })
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SegredoLocal"
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.HoldDuration = 1.2
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("PoiId", area.poi.id)
	prompt.Parent = holder
	return holder
end

local extras = {}

-- ===================== MOINHO: FAZENDA =====================
function extras.windmill(area)
	local m, rng = area.model, area.rng
	-- sede e celeiro virados para o moinho
	Props.house(m, ground(area, 18, 4, faceCenter(18, 4)), 10, 8, 5, Color3.fromRGB(225, 210, 180), Color3.fromRGB(140, 70, 50), rng)
	local barnCf = ground(area, -17, 8, faceCenter(-17, 8))
	Props.house(m, barnCf, 12, 10, 6, Color3.fromRGB(150, 55, 45), Color3.fromRGB(90, 70, 60), rng)
	-- plantação de trigo em fileiras, com cerca
	local field = ground(area, 0, -19)
	for row = 0, 5 do
		for col = 0, 6 do
			part(m, { Name = "Trigo", Size = Vector3.new(1.4, rng:NextNumber(1.2, 1.8), 0.6), CFrame = field * CFrame.new(-7 + col * 2.3, 0.7, -5 + row * 2), Color = Color3.fromRGB(220, 190, 90):Lerp(Color3.fromRGB(190, 165, 70), rng:NextNumber()), Material = M.Grass, CanCollide = false })
		end
	end
	local corners = { field * CFrame.new(-9, 0, -7), field * CFrame.new(9, 0, -7), field * CFrame.new(9, 0, 7), field * CFrame.new(-9, 0, 7) }
	for i = 1, 4 do
		if i ~= 4 then
			Props.fence(m, corners[i].Position, corners[i % 4 + 1].Position, 1.6, C.Wood)
		end
	end
	-- poço, carroça e fardos de feno
	Props.well(m, ground(area, 9, 15))
	Props.cart(m, ground(area, 14, -6, 0.6))
	for i = 0, 3 do
		hay(area, -13 + (i % 2) * 2.6, 15 + math.floor(i / 2) * 2.6)
	end
	Props.lamp(m, ground(area, 5, 9))
	-- segredo: no fardo de feno mais afastado
	hay(area, -20, 16)
	return secret(area, ground(area, -20, 16) * CFrame.new(0, 1.2, 0), "Revirar o feno", "Fardo mal amarrado")
end

-- ===================== CÍRCULO DE PEDRAS: SANTUÁRIO ANTIGO =====================
function extras.stonecircle(area)
	local secretSpot
	ring(area, 12, 19, 0.08, function(dx, dz, i)
		if i == 5 then
			menhir(area, dx, dz, 9)
			-- runa apagada no menir do segredo
			local cf = ground(area, dx, dz, faceCenter(dx, dz))
			part(area.model, { Name = "RunaApagada", Size = Vector3.new(1, 1, 0.12), CFrame = cf * CFrame.new(0, 4, -1.15) * CFrame.Angles(0, 0, math.rad(45)), Color = Color3.fromRGB(70, 80, 95), Material = M.Slate })
			secretSpot = cf * CFrame.new(0, 4, -1.6)
		else
			menhir(area, dx, dz, area.rng:NextNumber(6, 11), i % 5 == 2)
		end
	end)
	ring(area, 4, 12, 0, function(dx, dz)
		brazier(area, dx, dz, RUNE)
	end)
	-- trilha de lajes com runas que leva ao centro
	for k = 1, 6 do
		local cf = ground(area, 0, 13 + k * 2.6, 0)
		part(area.model, { Name = "Laje", Size = Vector3.new(3, 0.3, 2), CFrame = cf * CFrame.new(0, 0.15, 0), Color = OLD_STONE, Material = M.Slate })
		if k % 2 == 0 then
			part(area.model, { Name = "RunaLaje", Size = Vector3.new(0.8, 0.08, 0.8), CFrame = cf * CFrame.new(0, 0.32, 0) * CFrame.Angles(0, math.rad(45), 0), Color = RUNE, Material = M.Neon, CanCollide = false })
		end
	end
	return secret(area, secretSpot, "Tocar a runa apagada", "Menir antigo")
end

-- ===================== TORRE DE VIGIA: POSTO AVANÇADO =====================
function extras.watchtower(area)
	local m, rng = area.model, area.rng
	-- paliçada de troncos com portão
	local stakes = 34
	for i = 0, stakes - 1 do
		local a = i / stakes * math.pi * 2
		if not (a > 1.3 and a < 1.85) then
			local dx, dz = math.cos(a) * 17, math.sin(a) * 17
			local h = rng:NextNumber(5, 6.5)
			local cf = ground(area, dx, dz, a)
			part(m, { Name = "Estaca", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 1.3, 1.3), CFrame = cf * CFrame.new(0, h / 2 - 0.4, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = C.DarkWood:Lerp(C.Wood, rng:NextNumber()), Material = M.Wood })
			part(m, { Name = "Ponta", Size = Vector3.new(0.9, 0.9, 0.9), CFrame = cf * CFrame.new(0, h - 0.1, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)), Color = C.DarkWood, Material = M.Wood })
		end
	end
	-- alojamento, tendas, fogueira e suportes de armas
	Props.house(m, ground(area, -10, -7, faceCenter(-10, -7)), 9, 7, 4, Color3.fromRGB(120, 95, 70), Color3.fromRGB(80, 60, 45), rng)
	Props.tent(m, ground(area, 9, -9, faceCenter(9, -9)), Color3.fromRGB(150, 60, 50))
	Props.tent(m, ground(area, 12, 1, faceCenter(12, 1)), Color3.fromRGB(110, 95, 70))
	Props.campfire(m, ground(area, 6, 7))
	for k = 0, 2 do
		local cf = ground(area, -9 + k * 1.6, 9, 0)
		part(m, { Name = "Lanca", Size = Vector3.new(0.25, 6, 0.25), CFrame = cf * CFrame.new(0, 3, 0) * CFrame.Angles(math.rad(10), 0, 0), Color = C.Wood, Material = M.Wood })
		part(m, { Name = "PontaLanca", Size = Vector3.new(0.4, 0.9, 0.2), CFrame = cf * CFrame.new(0, 6.3, 0.5) * CFrame.Angles(math.rad(10), 0, 0), Color = Color3.fromRGB(170, 170, 175), Material = M.Metal })
	end
	part(m, { Name = "Suporte", Size = Vector3.new(5.4, 0.3, 0.6), CFrame = ground(area, -7.4, 9) * CFrame.new(0, 2.5, 0), Color = C.DarkWood, Material = M.Wood })
	for k = 0, 4 do
		Props.crate(m, ground(area, 13 + (k % 2) * 2.2, 8 + math.floor(k / 2) * 2.2, rng:NextNumber(0, 1)), rng:NextNumber(1.6, 2.2))
	end
	Props.banner(m, ground(area, -2, 15, 0), Color3.fromRGB(60, 80, 150))
	-- segredo: alçapão no chão perto da paliçada
	local hatch = ground(area, -13, 10, 0.4)
	part(m, { Name = "Alcapao", Size = Vector3.new(2.6, 0.2, 2.6), CFrame = hatch * CFrame.new(0, 0.1, 0), Color = C.DarkWood, Material = M.WoodPlanks })
	part(m, { Name = "Argola", Size = Vector3.new(0.5, 0.12, 0.5), CFrame = hatch * CFrame.new(0.8, 0.25, 0), Color = Color3.fromRGB(60, 60, 65), Material = M.Metal })
	return secret(area, hatch * CFrame.new(0, 0.6, 0), "Abrir o alçapão", "Tábuas soltas")
end

-- ===================== ESTÁTUA: PRAÇA DO HERÓI =====================
function extras.statue(area)
	local m, rng = area.model, area.rng
	local center = ground(area, 0, 0)
	part(m, { Name = "Praca", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 34, 34), CFrame = center * CFrame.new(0, 0.05, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(175, 170, 160), Material = M.Cobblestone })
	part(m, { Name = "Borda", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.7, 35, 35), CFrame = center * CFrame.new(0, -0.1, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = OLD_STONE, Material = M.Slate })
	local secretColumn
	ring(area, 8, 19, 0.05, function(dx, dz, i)
		brokenColumn(area, dx, dz)
		if i == 3 then
			secretColumn = ground(area, dx, dz, faceCenter(dx, dz))
		end
	end)
	ring(area, 4, 13, 0, function(dx, dz)
		Props.bench(m, ground(area, dx, dz, faceCenter(dx, dz) + math.pi))
	end)
	ring(area, 4, 16, 0, function(dx, dz)
		Props.lamp(m, ground(area, dx, dz))
	end)
	-- canteiros de flores na borda
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2 + 0.3
		Props.flowers(m, ground(area, math.cos(a) * 15, math.sin(a) * 15, a), rng)
	end
	part(m, { Name = "Rachadura", Size = Vector3.new(0.12, 2.4, 0.5), CFrame = secretColumn * CFrame.new(0, 2.2, -1.05), Color = Color3.fromRGB(40, 38, 36), Material = M.Slate })
	return secret(area, secretColumn * CFrame.new(0, 2, -1.6), "Examinar a rachadura", "Coluna rachada")
end

-- ===================== ACAMPAMENTO: CARAVANA ATACADA =====================
function extras.camp(area)
	local m, rng = area.model, area.rng
	ring(area, 3, 15, 0.25, function(dx, dz)
		Props.tent(m, ground(area, dx, dz, faceCenter(dx, dz)), Color3.fromRGB(130, 110, 80):Lerp(Color3.fromRGB(150, 60, 50), rng:NextNumber()))
	end)
	-- carroça tombada e carga espalhada
	local wagon = ground(area, -16, -4, 1.1)
	local cart = Props.cart(m, wagon)
	if cart and cart:IsA("Model") then
		cart:PivotTo(wagon * CFrame.new(0, 1.2, 0) * CFrame.Angles(0, 0, math.rad(80)))
	end
	for k = 0, 6 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(3, 8)
		if k % 2 == 0 then
			Props.crate(m, ground(area, -16 + math.cos(a) * r, -4 + math.sin(a) * r, rng:NextNumber(0, 3)), rng:NextNumber(1.4, 2.2))
		else
			Props.barrel(m, ground(area, -16 + math.cos(a) * r, -4 + math.sin(a) * r), 1)
		end
	end
	Props.campfire(m, ground(area, 10, 10))
	-- estandarte caído e flechas cravadas no chão
	local banner = ground(area, 4, -15, 0.4)
	part(m, { Name = "MastroCaido", Size = Vector3.new(0.35, 0.35, 8), CFrame = banner * CFrame.new(0, 0.2, 0), Color = C.Wood, Material = M.Wood })
	part(m, { Name = "Pano", Size = Vector3.new(2.6, 0.08, 3.4), CFrame = banner * CFrame.new(1.4, 0.1, -2), Color = Color3.fromRGB(120, 40, 40), Material = M.Fabric, CanCollide = false })
	for _ = 1, 9 do
		local cf = ground(area, rng:NextNumber(-18, 18), rng:NextNumber(-18, 18), rng:NextNumber(0, 6))
		part(m, { Name = "Flecha", Size = Vector3.new(0.12, 2, 0.12), CFrame = cf * CFrame.new(0, 0.7, 0) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), 0, rng:NextNumber(-0.5, 0.5)), Color = C.Wood, Material = M.Wood, CanCollide = false })
	end
	-- segredo: terra revolvida (algo enterrado)
	local mound = ground(area, 17, -12, 0.3)
	part(m, { Name = "TerraRevolvida", Size = Vector3.new(3.4, 0.7, 2.6), CFrame = mound * CFrame.new(0, 0.1, 0), Color = Color3.fromRGB(95, 70, 50), Material = M.Ground })
	part(m, { Name = "Pa", Size = Vector3.new(0.2, 3.6, 0.2), CFrame = mound * CFrame.new(1.8, 1.4, 0.8) * CFrame.Angles(0, 0, math.rad(-15)), Color = C.Wood, Material = M.Wood })
	return secret(area, mound * CFrame.new(0, 0.6, 0), "Cavar", "Terra revolvida")
end

-- ===================== OBSERVATÓRIO: ACADEMIA DOS ASTRÓLOGOS =====================
function extras.observatory(area)
	local m, rng = area.model, area.rng
	-- biblioteca em ruínas: paredes quebradas e estantes
	local library = ground(area, -20, 4, faceCenter(-20, 4))
	for k, wall in { { -4.5, 0, 0.8, 10 }, { 4.5, 0, 0.8, 10 }, { 0, 4.6, 9.8, 0.8 } } do
		local h = rng:NextNumber(3, 6) + k
		part(m, { Name = "ParedeRuina", Size = Vector3.new(wall[3], h, wall[4]), CFrame = library * CFrame.new(wall[1], h / 2, wall[2]), Color = OLD_STONE, Material = M.Brick })
	end
	Props.shelf(m, library * CFrame.new(0, 0, 3.6) * CFrame.Angles(0, math.pi, 0), 4, 3, "books", rng)
	for _ = 1, 6 do
		part(m, { Name = "Livro", Size = Vector3.new(1.1, 0.25, 0.8), CFrame = library * CFrame.new(rng:NextNumber(-3, 3), 0.15, rng:NextNumber(-3, 2)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), Color = Color3.fromRGB(120, 40, 60):Lerp(Color3.fromRGB(50, 70, 120), rng:NextNumber()) })
	end
	-- pedras do mapa estelar (constelações acesas à noite)
	ring(area, 5, 18, 0.1, function(dx, dz)
		local cf = ground(area, dx, dz, rng:NextNumber(0, 6))
		part(m, { Name = "MapaEstelar", Size = Vector3.new(3.4, 0.6, 3.4), CFrame = cf * CFrame.new(0, 0.3, 0), Color = Color3.fromRGB(60, 62, 80), Material = M.Slate })
		for _ = 1, 4 do
			Props.nightLight(part(m, { Name = "Estrela", Size = Vector3.new(0.3, 0.1, 0.3), CFrame = cf * CFrame.new(rng:NextNumber(-1.3, 1.3), 0.64, rng:NextNumber(-1.3, 1.3)), Color = Color3.fromRGB(200, 220, 255), Material = M.Neon, CanCollide = false }))
		end
	end)
	-- dois telescópios menores em plataformas
	for _, spot in { { 16, -10 }, { 10, 17 } } do
		local cf = ground(area, spot[1], spot[2], faceCenter(spot[1], spot[2]))
		part(m, { Name = "Plataforma", Size = Vector3.new(4, 1, 4), CFrame = cf * CFrame.new(0, 0.5, 0), Color = OLD_STONE, Material = M.Slate })
		Props.column(m, cf * CFrame.new(0, 1, 0), 2.4, 0.5, Color3.fromRGB(150, 120, 60), M.Metal)
		part(m, { Name = "Luneta", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, 0.9, 0.9), CFrame = cf * CFrame.new(0, 3.6, 0) * CFrame.Angles(0, math.rad(90), math.rad(35)), Color = Color3.fromRGB(170, 135, 70), Material = M.Metal })
	end
	-- segredo: um astrolábio de latão para alinhar
	local device = ground(area, -14, -14, 0.5)
	part(m, { Name = "Pedestal", Size = Vector3.new(1.4, 2.6, 1.4), CFrame = device * CFrame.new(0, 1.3, 0), Color = OLD_STONE, Material = M.Slate })
	local astrolabe = part(m, { Name = "Astrolabio", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 1.8, 1.8), CFrame = device * CFrame.new(0, 3.3, 0) * CFrame.Angles(0, 0, math.rad(70)), Color = Color3.fromRGB(190, 150, 70), Material = M.Metal, CanCollide = false })
	CollectionService:AddTag(astrolabe, "Spin")
	return secret(area, device * CFrame.new(0, 2.6, 0), "Alinhar a lente", "Astrolábio")
end

-- ===================== CEMITÉRIO: CAMPO DOS MORTOS =====================
function extras.graveyard(area)
	local m, rng = area.model, area.rng
	-- covas novas fora do muro, árvores secas e postes com lanterna
	for _ = 1, 10 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(17, 22)
		local dx, dz = math.cos(a) * r, math.sin(a) * r
		local cf = ground(area, dx, dz, faceCenter(dx, dz))
		part(m, { Name = "Cova", Size = Vector3.new(2, 0.5, 4), CFrame = cf * CFrame.new(0, 0.1, 0), Color = Color3.fromRGB(90, 72, 55), Material = M.Ground })
		part(m, { Name = "Cruz", Size = Vector3.new(0.3, 2.6, 0.3), CFrame = cf * CFrame.new(0, 1.3, -2.2), Color = C.Wood, Material = M.Wood })
		part(m, { Name = "Cruz", Size = Vector3.new(1.4, 0.3, 0.3), CFrame = cf * CFrame.new(0, 2.0, -2.2), Color = C.Wood, Material = M.Wood })
	end
	ring(area, 5, 24, 0.3, function(dx, dz)
		deadTree(area, dx, dz, 1)
	end)
	ring(area, 6, 15, 0.1, function(dx, dz)
		Props.lamp(m, ground(area, dx, dz))
	end)
	-- casa do coveiro
	Props.house(m, ground(area, 20, -10, faceCenter(20, -10)), 8, 7, 4, Color3.fromRGB(110, 105, 100), Color3.fromRGB(60, 55, 60), rng)
	local shovel = ground(area, 16, -6, 0.5)
	part(m, { Name = "Pa", Size = Vector3.new(0.2, 3.6, 0.2), CFrame = shovel * CFrame.new(0, 1.6, 0) * CFrame.Angles(0, 0, math.rad(12)), Color = C.Wood, Material = M.Wood })
	-- segredo: lápide sem nome, afastada
	local stone = ground(area, -21, 12, faceCenter(-21, 12))
	part(m, { Name = "LapideSemNome", Size = Vector3.new(2.2, 3, 0.6), CFrame = stone * CFrame.new(0, 1.3, 0) * CFrame.Angles(math.rad(-8), 0, 0), Color = Color3.fromRGB(95, 95, 105), Material = M.Slate })
	return secret(area, stone * CFrame.new(0, 1.4, -1), "Ler a lápide", "Lápide sem nome")
end

-- ===================== ALTAR: TEMPLO DA FLORESTA =====================
function extras.altar(area)
	local m, rng = area.model, area.rng
	-- pilares altos com trepadeiras
	ring(area, 6, 15, 0, function(dx, dz, i)
		local cf = ground(area, dx, dz, faceCenter(dx, dz))
		local h = if i % 3 == 2 then rng:NextNumber(4, 7) else rng:NextNumber(11, 15)
		part(m, { Name = "Pilar", Size = Vector3.new(2.4, h, 2.4), CFrame = cf * CFrame.new(0, h / 2, 0), Color = OLD_STONE, Material = M.Slate })
		part(m, { Name = "Capitel", Size = Vector3.new(3.2, 1, 3.2), CFrame = cf * CFrame.new(0, h + 0.5, 0), Color = STONE, Material = M.Slate })
		for v = 1, 3 do
			part(m, { Name = "Trepadeira", Size = Vector3.new(0.3, h * 0.4, 0.15), CFrame = cf * CFrame.new(rng:NextNumber(-0.9, 0.9), h * (0.2 + v * 0.18), -1.28), Color = MOSS, Material = M.Grass, CanCollide = false })
		end
	end)
	-- guardiões de pedra dos dois lados do caminho
	for _, side in { -1, 1 } do
		local cf = ground(area, side * 6, 20, math.pi)
		part(m, { Name = "Pedestal", Size = Vector3.new(3, 1.6, 3), CFrame = cf * CFrame.new(0, 0.8, 0), Color = OLD_STONE, Material = M.Slate })
		part(m, { Name = "Guardiao", Size = Vector3.new(2.2, 4, 1.6), CFrame = cf * CFrame.new(0, 3.6, 0), Color = STONE, Material = M.Slate })
		part(m, { Name = "Cabeca", Size = Vector3.new(1.4, 1.4, 1.4), CFrame = cf * CFrame.new(0, 6.3, 0), Color = STONE, Material = M.Slate })
		Props.nightLight(part(m, { Name = "Olhos", Size = Vector3.new(0.9, 0.2, 0.1), CFrame = cf * CFrame.new(0, 6.4, -0.72), Color = Color3.fromRGB(120, 255, 200), Material = M.Neon, CanCollide = false }))
	end
	-- caminho de degraus até o altar
	for k = 1, 7 do
		local cf = ground(area, 0, 8 + k * 2.2, 0)
		part(m, { Name = "Degrau", Size = Vector3.new(5, 0.4, 2), CFrame = cf * CFrame.new(0, 0.2, 0), Color = OLD_STONE:Lerp(MOSS, 0.2), Material = M.Slate })
	end
	ring(area, 4, 10, 0, function(dx, dz)
		brazier(area, dx, dz, Color3.fromRGB(120, 255, 190))
	end)
	-- cogumelos luminosos
	for _ = 1, 12 do
		local cf = ground(area, rng:NextNumber(-20, 20), rng:NextNumber(-20, 20))
		Props.column(m, cf, 0.6, 0.25, Color3.fromRGB(230, 225, 210), M.SmoothPlastic, { CanCollide = false })
		Props.nightLight(Props.column(m, cf * CFrame.new(0, 0.6, 0), 0.3, 0.9, Color3.fromRGB(110, 230, 255), M.Neon, { CanCollide = false }))
	end
	-- segredo: tigela de oferendas
	local bowl = ground(area, -11, -12, 0)
	part(m, { Name = "Pedestal", Size = Vector3.new(1.6, 2, 1.6), CFrame = bowl * CFrame.new(0, 1, 0), Color = OLD_STONE, Material = M.Slate })
	Props.column(m, bowl * CFrame.new(0, 2, 0), 0.5, 1.8, Color3.fromRGB(180, 150, 80), M.Metal)
	return secret(area, bowl * CFrame.new(0, 2.6, 0), "Deixar uma oferenda", "Tigela de oferendas")
end

-- ===================== NAUFRÁGIO: PRAIA DOS DESTROÇOS =====================
function extras.shipwreck(area)
	local m, rng = area.model, area.rng
	-- bote virado, mastro caído e tábuas espalhadas
	local boat = ground(area, 16, 8, 0.7)
	part(m, { Name = "Bote", Size = Vector3.new(3.4, 1.4, 7), CFrame = boat * CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.rad(170)), Color = C.Wood, Material = M.WoodPlanks })
	local mast = ground(area, -14, 10, 1.2)
	part(m, { Name = "MastroCaido", Shape = Enum.PartType.Cylinder, Size = Vector3.new(16, 1.1, 1.1), CFrame = mast * CFrame.new(0, 0.5, 0), Color = C.DarkWood, Material = M.Wood })
	part(m, { Name = "VelaRasgada", Size = Vector3.new(6, 0.1, 5), CFrame = mast * CFrame.new(-2, 0.2, 2.6), Color = Color3.fromRGB(225, 215, 190), Material = M.Fabric, CanCollide = false })
	for _ = 1, 14 do
		local cf = ground(area, rng:NextNumber(-20, 20), rng:NextNumber(-20, 20), rng:NextNumber(0, 6))
		part(m, { Name = "Tabua", Size = Vector3.new(rng:NextNumber(2, 4.5), 0.3, 0.8), CFrame = cf * CFrame.new(0, 0.15, 0) * CFrame.Angles(0, 0, rng:NextNumber(-0.1, 0.1)), Color = C.Plank:Lerp(C.DarkWood, rng:NextNumber()), Material = M.WoodPlanks, CanCollide = false })
	end
	-- carga que chegou à praia
	for k = 0, 5 do
		local cf = ground(area, -6 + k * 2.4, -17 + (k % 2) * 1.5, rng:NextNumber(0, 1))
		if k % 3 == 0 then
			Props.barrel(m, cf, 1)
		else
			Props.crate(m, cf, rng:NextNumber(1.6, 2.2))
		end
	end
	-- acampamento do náufrago
	Props.tent(m, ground(area, -18, -8, faceCenter(-18, -8)), Color3.fromRGB(190, 170, 130))
	Props.campfire(m, ground(area, -13, -12))
	local sign = ground(area, -10, -6, faceCenter(-10, -6))
	part(m, { Name = "Poste", Size = Vector3.new(0.3, 3, 0.3), CFrame = sign * CFrame.new(0, 1.5, 0), Color = C.Wood, Material = M.Wood })
	part(m, { Name = "Placa", Size = Vector3.new(2.4, 1.2, 0.2), CFrame = sign * CFrame.new(0, 2.6, 0), Color = C.Plank, Material = M.WoodPlanks })
	-- segredo: garrafa com mensagem na beira da água
	local bottle = ground(area, 20, -14, 0.8)
	part(m, { Name = "Garrafa", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.9, 0.4, 0.4), CFrame = bottle * CFrame.new(0, 0.2, 0), Color = Color3.fromRGB(120, 200, 160), Material = M.Glass, Transparency = 0.3, CanCollide = false })
	return secret(area, bottle * CFrame.new(0, 0.6, 0), "Pegar a garrafa", "Garrafa na areia")
end

-- Monta o entorno do local (model já contém a peça principal). Retorna a peça do segredo (ou nil).
function PoiAreas.build(model, cf, poi, rng, size, groundAt)
	local builder = extras[poi.kind]
	if not builder then
		return nil
	end
	local area = { model = model, cf = cf, poi = poi, rng = rng, size = size, groundAt = groundAt }
	return builder(area)
end

return PoiAreas
