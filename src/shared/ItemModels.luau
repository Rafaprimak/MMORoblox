-- Modelos 3D de todos os itens (blocados, sem malhas), usados em três lugares:
--   servidor: arma presa na mão (WeaponModels) e item caído no chão (LootService)
--   cliente: ícone 3D nas janelas (ItemIcon) e o item que o personagem ergue na cena do baú
-- Cada base tem um visual próprio em ItemModels.Looks (cores, formato, detalhes); a raridade muda as
-- gemas, os detalhes brilhantes e, do Épico para cima, partes em neon. Armas: cabo na origem e a
-- ponta subindo em +Y. Equipamentos: centrados na origem, com a frente virada para -Z.
local CollectionService = game:GetService("CollectionService")

local Items = require(script.Parent.Items)
local Rarities = require(script.Parent.Rarities)

local ItemModels = {}

local M = Enum.Material

-- ===================== PALETA =====================
local C = {
	copper = Color3.fromRGB(190, 118, 60),
	iron = Color3.fromRGB(118, 120, 130),
	steel = Color3.fromRGB(168, 172, 184),
	darkSteel = Color3.fromRGB(62, 64, 76),
	silver = Color3.fromRGB(215, 218, 228),
	gold = Color3.fromRGB(226, 184, 72),
	wood = Color3.fromRGB(112, 74, 42),
	darkWood = Color3.fromRGB(70, 45, 28),
	paleWood = Color3.fromRGB(196, 160, 110),
	leather = Color3.fromRGB(122, 78, 44),
	darkLeather = Color3.fromRGB(58, 38, 26),
	cloth = Color3.fromRGB(70, 90, 150),
	bone = Color3.fromRGB(232, 222, 196),
	obsidian = Color3.fromRGB(34, 30, 38),
	lava = Color3.fromRGB(255, 104, 32),
	void = Color3.fromRGB(130, 60, 220),
	spectral = Color3.fromRGB(175, 195, 255),
	crimson = Color3.fromRGB(190, 30, 45),
	jade = Color3.fromRGB(70, 200, 150),
	stone = Color3.fromRGB(128, 122, 112),
	crystal = Color3.fromRGB(110, 210, 255),
	sun = Color3.fromRGB(255, 220, 110),
	star = Color3.fromRGB(200, 220, 255),
	red = Color3.fromRGB(190, 40, 40),
}
ItemModels.Palette = C

-- ===================== VISUAL DE CADA BASE =====================
-- Campos comuns: metal (cor principal), mat (material), trim (detalhes), glow (cor de neon fixa;
-- sem ela a raridade decide), style (formato). Ver cada construtor para os campos extras.
local L = {
	-- espadas
	espada_treino = { style = "wood", metal = C.paleWood, mat = M.Wood, trim = C.darkWood, length = 2.6 },
	espada_cobre = { style = "cross", metal = C.copper, trim = C.darkWood },
	lamina_guardiao = { style = "wide", metal = C.steel, trim = C.gold, width = 0.56, glow = Color3.fromRGB(80, 150, 255) },
	espada_runica = { style = "wings", metal = Color3.fromRGB(150, 170, 200), trim = C.silver, runes = Color3.fromRGB(110, 200, 255), length = 3.4 },
	ceifa_espectral = { style = "wings", metal = C.spectral, mat = M.Glass, trim = C.darkSteel, runes = Color3.fromRGB(180, 140, 255), transparency = 0.25, curve = true, length = 3.4 },
	lamina_eclipse = { style = "disc", metal = C.obsidian, mat = M.Slate, trim = C.gold, edge = C.gold, runes = Color3.fromRGB(255, 200, 90), length = 3.6, unique = true },
	-- katanas
	katana_errante = { metal = C.steel, edge = C.silver, tsuba = "round", wrap = C.darkLeather },
	katana_sombria = { metal = Color3.fromRGB(45, 42, 55), edge = Color3.fromRGB(170, 90, 255), tsuba = "square", wrap = Color3.fromRGB(40, 20, 60) },
	katana_lua = { metal = Color3.fromRGB(150, 30, 40), edge = Color3.fromRGB(255, 120, 120), tsuba = "flower", wrap = C.crimson, moon = true },
	katana_espectral = { metal = C.spectral, mat = M.Glass, edge = Color3.fromRGB(200, 170, 255), tsuba = "round", wrap = C.obsidian, transparency = 0.25 },
	-- adagas
	adaga_treino = { style = "straight", metal = C.paleWood, mat = M.Wood, trim = C.darkWood },
	adaga_cobre = { style = "straight", metal = C.copper, trim = C.darkWood },
	presas_gemeas = { style = "fang", metal = C.bone, mat = M.SmoothPlastic, trim = C.darkLeather, twin = true },
	adagas_vazio = { style = "curved", metal = Color3.fromRGB(50, 30, 80), edge = C.void, twin = true, glow = C.void },
	faca_saqueador = { style = "serrated", metal = C.iron, trim = C.leather },
	adagas_brasa = { style = "curved", metal = C.obsidian, mat = M.Slate, edge = C.lava, twin = true, glow = C.lava },
	adagas_capitao = { style = "serrated", metal = C.gold, mat = M.Foil, edge = C.crimson, twin = true, glow = C.crimson, unique = true },
	-- machados
	machado_lenhador = { style = "single", metal = C.iron, handle = C.wood },
	machado_berserker = { style = "double", metal = C.darkSteel, handle = C.darkWood, wrap = C.crimson },
	machado_tempestade = { style = "double", metal = Color3.fromRGB(150, 170, 210), handle = C.darkSteel, glow = Color3.fromRGB(120, 210, 255), lightning = true },
	machado_tunel = { style = "jagged", metal = Color3.fromRGB(110, 100, 90), handle = C.wood, wrap = C.leather },
	-- martelos e maças
	martelo_pedra = { style = "stone", metal = C.stone, mat = M.Slate, handle = C.wood },
	maca_peregrino = { style = "mace", metal = C.iron, handle = C.darkWood },
	martelo_gigante = { style = "giant", metal = C.darkSteel, handle = C.darkWood, trim = C.gold },
	martelo_trovao = { style = "rune", metal = Color3.fromRGB(150, 160, 190), handle = C.darkSteel, trim = C.gold, glow = Color3.fromRGB(120, 210, 255), lightning = true },
	martelo_magma = { style = "core", metal = C.obsidian, mat = M.Basalt, handle = C.darkSteel, glow = C.lava },
	martelo_colosso = { style = "core", metal = Color3.fromRGB(95, 60, 50), mat = M.Slate, handle = C.obsidian, trim = C.gold, glow = Color3.fromRGB(255, 160, 60), big = true, unique = true },
	-- lanças
	lanca_cacador = { tip = "leaf", metal = C.iron, shaft = C.wood, tassel = C.red },
	lanca_draconica = { tip = "dragon", metal = Color3.fromRGB(170, 50, 40), shaft = C.darkWood, tassel = C.gold, trim = C.gold },
	lanca_celestial = { tip = "celestial", metal = C.silver, shaft = Color3.fromRGB(240, 235, 225), tassel = Color3.fromRGB(120, 180, 255), trim = C.gold, glow = C.sun },
	lanca_magma = { tip = "obsidian", metal = C.obsidian, mat = M.Basalt, shaft = C.darkSteel, tassel = C.lava, glow = C.lava },
	-- arcos
	arco_treino = { style = "simple", limb = C.paleWood, grip = C.darkLeather },
	arco_curto = { style = "simple", limb = C.wood, grip = C.leather, tips = C.iron },
	arco_longo = { style = "elven", limb = Color3.fromRGB(225, 215, 190), grip = C.jade, tips = C.gold, long = true },
	arco_fenix = { style = "phoenix", limb = Color3.fromRGB(200, 60, 30), grip = C.gold, tips = C.lava, glow = Color3.fromRGB(255, 150, 50) },
	arco_tunel = { style = "root", limb = C.darkWood, grip = C.leather, tips = C.bone },
	arco_luto = { style = "bone", limb = C.bone, grip = C.obsidian, tips = C.darkSteel, glow = Color3.fromRGB(160, 120, 255) },
	arco_viuva = { style = "spider", limb = Color3.fromRGB(40, 30, 50), grip = Color3.fromRGB(110, 40, 140), tips = Color3.fromRGB(170, 60, 220), glow = Color3.fromRGB(150, 255, 120), unique = true },
	-- cajados
	cajado_treino = { top = "knob", shaft = C.paleWood },
	cajado_aprendiz = { top = "orb", shaft = C.wood, trim = C.iron },
	cajado_arcano = { top = "crystal", shaft = C.darkWood, trim = C.silver, glow = Color3.fromRGB(150, 110, 255) },
	cetro_luz = { top = "sun", shaft = Color3.fromRGB(240, 232, 215), trim = C.gold, glow = C.sun },
	cajado_estelar = { top = "star", shaft = Color3.fromRGB(40, 45, 80), trim = C.silver, glow = C.star },
	cajado_cristal = { top = "cluster", shaft = C.darkWood, trim = C.iron, glow = C.crystal },
	cetro_ossos = { top = "skull", shaft = C.bone, trim = C.darkSteel, glow = Color3.fromRGB(120, 255, 170) },
	cajado_magma = { top = "magma", shaft = C.obsidian, trim = C.darkSteel, glow = C.lava },
	cajado_vazio = { top = "void", shaft = Color3.fromRGB(30, 20, 45), trim = Color3.fromRGB(200, 170, 255), glow = C.void, unique = true },

	-- armaduras
	colete_couro = { style = "leather", main = C.leather, trim = C.darkLeather },
	manto_aprendiz = { style = "robe", main = Color3.fromRGB(80, 100, 170), trim = Color3.fromRGB(220, 200, 140) },
	cota_malha = { style = "mail", main = C.iron, trim = C.leather },
	armadura_placas = { style = "plate", main = C.steel, trim = C.gold },
	manto_arcano = { style = "robe", main = Color3.fromRGB(90, 50, 150), trim = C.gold, glow = Color3.fromRGB(170, 120, 255) },
	couraca_sombria = { style = "leather", main = Color3.fromRGB(40, 36, 50), trim = Color3.fromRGB(120, 60, 160), hood = true },
	armadura_dragao = { style = "dragon", main = Color3.fromRGB(150, 40, 35), trim = C.gold },
	manto_estelar = { style = "robe", main = Color3.fromRGB(30, 35, 75), trim = C.silver, glow = C.star, stars = true },
	couraca_vento = { style = "plate", main = Color3.fromRGB(150, 210, 200), trim = C.silver, light = true },
	colete_tunel = { style = "leather", main = Color3.fromRGB(110, 95, 70), trim = C.iron, straps = true },
	mortalha_cripta = { style = "robe", main = Color3.fromRGB(70, 72, 80), trim = C.bone, glow = Color3.fromRGB(120, 255, 170), tattered = true },
	casca_abissal = { style = "dragon", main = C.obsidian, trim = C.darkSteel, glow = C.lava },
	couraca_guardiao = { style = "plate", main = Color3.fromRGB(95, 92, 120), trim = C.gold, glow = Color3.fromRGB(120, 200, 255), heavy = true, unique = true },
	-- elmos
	elmo_couro = { style = "cap", main = C.leather, trim = C.darkLeather },
	capuz_aprendiz = { style = "hood", main = Color3.fromRGB(80, 100, 170), trim = Color3.fromRGB(220, 200, 140) },
	elmo_ferro = { style = "iron", main = C.iron, trim = C.darkSteel },
	capuz_sombrio = { style = "hood", main = Color3.fromRGB(40, 36, 50), trim = Color3.fromRGB(120, 60, 160), eyes = Color3.fromRGB(170, 90, 255) },
	elmo_dragao = { style = "horned", main = Color3.fromRGB(150, 40, 35), trim = C.gold },
	coroa_arcana = { style = "crown", main = C.silver, trim = Color3.fromRGB(150, 110, 255), glow = Color3.fromRGB(170, 120, 255) },
	capuz_saqueador = { style = "hood", main = Color3.fromRGB(100, 85, 60), trim = C.iron, eyes = Color3.fromRGB(255, 200, 80) },
	elmo_vigia = { style = "iron", main = Color3.fromRGB(85, 88, 98), trim = C.bone, glow = Color3.fromRGB(120, 255, 170) },
	elmo_magma = { style = "horned", main = C.obsidian, trim = C.darkSteel, glow = C.lava },
	coroa_rei_goblin = { style = "crown", main = C.gold, trim = Color3.fromRGB(80, 150, 50), glow = Color3.fromRGB(120, 255, 90), big = true, unique = true },
	-- botas
	botas_couro = { style = "leather", main = C.leather, trim = C.darkLeather },
	sandalias_monge = { style = "sandal", main = C.paleWood, trim = C.leather },
	botas_ferro = { style = "iron", main = C.iron, trim = C.darkSteel },
	botas_vento = { style = "wing", main = Color3.fromRGB(160, 210, 220), trim = C.silver },
	grevas_dragao = { style = "dragon", main = Color3.fromRGB(150, 40, 35), trim = C.gold },
	botas_estelares = { style = "wing", main = Color3.fromRGB(35, 40, 80), trim = C.silver, glow = C.star },
	botas_tunel = { style = "leather", main = Color3.fromRGB(105, 90, 66), trim = C.iron },
	grevas_vigia = { style = "iron", main = Color3.fromRGB(85, 88, 98), trim = C.bone, glow = Color3.fromRGB(120, 255, 170) },
	botas_brasa = { style = "dragon", main = C.obsidian, trim = C.darkSteel, glow = C.lava },
	-- amuletos
	amuleto_cobre = { pendant = "coin", main = C.copper, chain = C.copper },
	amuleto_vida = { pendant = "heart", main = C.silver, chain = C.silver, gem = Color3.fromRGB(255, 80, 110) },
	amuleto_lua = { pendant = "moon", main = C.silver, chain = C.silver, gem = Color3.fromRGB(170, 200, 255) },
	amuleto_sabio = { pendant = "eye", main = C.gold, chain = C.gold, gem = C.jade },
	amuleto_dragao = { pendant = "claw", main = C.gold, chain = C.gold, gem = Color3.fromRGB(255, 70, 50) },
	amuleto_alma = { pendant = "souls", main = C.darkSteel, chain = C.silver, gem = Color3.fromRGB(120, 255, 170) },
	-- anéis
	anel_cobre = { band = C.copper },
	anel_vampiro = { band = C.darkSteel, gem = C.crimson, fangs = true },
	anel_guardiao = { band = C.silver, gem = Color3.fromRGB(80, 150, 255), shield = true },
	anel_tempestade = { band = C.silver, gem = Color3.fromRGB(120, 210, 255), spikes = true },
	anel_rei = { band = C.gold, gem = Color3.fromRGB(255, 70, 70), crown = true },
	anel_saqueador = { band = C.iron, gem = C.gold },
	anel_magma = { band = C.obsidian, gem = C.lava, spikes = true },
	anel_lich = { band = C.bone, gem = Color3.fromRGB(150, 110, 255), skull = true, unique = true },
}
ItemModels.Looks = L

-- ===================== CONSTRUÇÃO =====================

local function newBuilder(model, rarity)
	local b = { model = model, glowing = {}, rarity = rarity }
	-- peça genérica; opts: shape ("Ball", "Cylinder", "Wedge"), glow, transparency
	function b.add(size, cf, color, material, opts)
		local p = Instance.new("Part")
		p.Name = "Peca"
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material or M.Metal
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if opts then
			if opts.shape then
				p.Shape = Enum.PartType[opts.shape]
			end
			if opts.transparency then
				p.Transparency = opts.transparency
			end
			if opts.glow then
				table.insert(b.glowing, p)
			end
		end
		p.Parent = model
		return p
	end
	function b.ball(diameter, cf, color, material, glow)
		return b.add(Vector3.one * diameter, cf, color, material, { shape = "Ball", glow = glow })
	end
	function b.wedge(size, cf, color, material, glow)
		return b.add(size, cf, color, material, { shape = "Wedge", glow = glow })
	end
	-- cilindro em pé (eixo Y)
	function b.cyl(height, diameter, cf, color, material, glow)
		return b.add(Vector3.new(height, diameter, diameter), cf * CFrame.Angles(0, 0, math.rad(90)), color, material, { shape = "Cylinder", glow = glow })
	end
	-- gema da raridade (neon do Épico para cima)
	function b.gem(diameter, cf, color)
		local order = rarity.order
		return b.ball(diameter, cf, color or rarity.color, if order >= 3 then M.Neon else M.Glass, true)
	end
	-- anel feito de segmentos (deitado no plano XZ, ou em pé com rotate)
	function b.ring(radius, thickness, segments, cf, color, material, glow)
		for i = 0, segments - 1 do
			local angle = i / segments * math.pi * 2
			local length = 2 * radius * math.tan(math.pi / segments) + 0.02
			b.add(Vector3.new(length, thickness, thickness), cf * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -radius), color, material, { glow = glow })
		end
	end
	return b
end

local function glowColor(look, rarity)
	return look.glow or rarity.color
end

local function glowMaterial(look, rarity)
	return if look.glow or rarity.order >= 4 then M.Neon else M.Metal
end

-- cabo enrolado em couro + pomo
local function grip(b, length, y, color)
	for i = 0, math.floor(length / 0.28) - 1 do
		b.add(Vector3.new(0.34, 0.12, 0.34), CFrame.new(0, y - length / 2 + 0.14 + i * 0.28, 0) * CFrame.Angles(0, math.rad(45 * (i % 2)), 0), color or C.darkLeather, M.Fabric)
	end
end

-- lâmina: centro + fios em cunha + sulco + ponta (+ runas, serrilha, curva)
local function blade(b, look, rarity, width, length, y, thickness)
	thickness = thickness or 0.12
	local color = look.metal
	local material = look.mat or M.Metal
	if rarity.order >= 6 and not look.mat then
		color = color:Lerp(rarity.color, 0.25)
	end
	local tOpts = { transparency = look.transparency }
	b.add(Vector3.new(width * 0.5, length, thickness), CFrame.new(0, y, 0), color, material, tOpts)
	local edge = look.edge or color:Lerp(Color3.new(1, 1, 1), 0.3)
	for _, side in { -1, 1 } do
		local w = b.wedge(Vector3.new(thickness * 0.8, length, width * 0.3), CFrame.new(side * width * 0.4, y, 0) * CFrame.Angles(0, math.rad(side * 90), 0), edge, if look.edge and look.glow then M.Neon else material)
		w.Transparency = look.transparency or 0
	end
	b.add(Vector3.new(width * 0.12, length * 0.75, thickness + 0.02), CFrame.new(0, y - length * 0.05, 0), glowColor(look, rarity), glowMaterial(look, rarity), { glow = true })
	-- ponta (curva puxa a ponta para o lado)
	local tipCf = CFrame.new(0, y + length / 2 + width * 0.45, 0) * (if look.curve then CFrame.Angles(0, 0, math.rad(-18)) else CFrame.identity)
	for _, side in { -1, 1 } do
		local w = b.wedge(Vector3.new(thickness, width * 0.9, width * 0.5), tipCf * CFrame.new(side * width * 0.25, 0, 0) * CFrame.Angles(0, math.rad(side * 90), 0), color, material)
		w.Transparency = look.transparency or 0
	end
	if look.runes then
		for i = 0, 3 do
			b.add(Vector3.new(width * 0.18, 0.16, thickness + 0.05), CFrame.new(0, y - length * 0.35 + i * length * 0.22, 0) * CFrame.Angles(0, 0, math.rad(45)), look.runes, M.Neon, { glow = true })
		end
	end
	if look.style == "serrated" then
		for i = 0, 4 do
			b.wedge(Vector3.new(thickness * 0.8, 0.25, 0.18), CFrame.new(width * 0.6, y - length * 0.4 + i * length * 0.18, 0) * CFrame.Angles(0, math.rad(90), 0), edge, material)
		end
	end
end

-- ===================== ARMAS =====================
local weapon = {}

function weapon.sword(b, look, rarity)
	local trim = look.trim or C.darkSteel
	local width, length = look.width or 0.42, look.length or 3.1
	if look.style == "wood" then
		grip(b, 0.9, 0.05, C.leather)
		b.add(Vector3.new(1.0, 0.2, 0.32), CFrame.new(0, 0.62, 0), trim, M.Wood)
		b.add(Vector3.new(0.34, length, 0.22), CFrame.new(0, 0.72 + length / 2, 0), look.metal, M.Wood)
		b.wedge(Vector3.new(0.22, 0.4, 0.34), CFrame.new(0, 0.92 + length, 0), look.metal, M.Wood)
		return 0.9 + length, 0.9
	end
	grip(b, 0.9, 0.05)
	b.gem(0.32, CFrame.new(0, -0.5, 0))
	if look.style == "wide" then
		b.add(Vector3.new(1.9, 0.3, 0.42), CFrame.new(0, 0.62, 0), trim, M.Metal)
		for _, s in { -1, 1 } do
			b.wedge(Vector3.new(0.4, 0.5, 0.4), CFrame.new(s * 0.82, 0.32, 0) * CFrame.Angles(math.rad(180), math.rad(s * 90), 0), trim, M.Metal)
		end
		b.add(Vector3.new(0.6, 0.6, 0.5), CFrame.new(0, 0.7, 0) * CFrame.Angles(0, 0, math.rad(45)), trim, M.Metal)
		b.gem(0.32, CFrame.new(0, 0.7, -0.26), look.glow)
	elseif look.style == "wings" then
		b.add(Vector3.new(1.2, 0.22, 0.38), CFrame.new(0, 0.62, 0), trim, M.Metal)
		for _, s in { -1, 1 } do
			b.wedge(Vector3.new(0.18, 0.9, 0.55), CFrame.new(s * 0.75, 0.95, 0) * CFrame.Angles(0, math.rad(s * 90), math.rad(s * -25)), trim, M.Metal)
			b.wedge(Vector3.new(0.14, 0.6, 0.35), CFrame.new(s * 1.0, 0.75, 0) * CFrame.Angles(0, math.rad(s * 90), math.rad(s * -55)), trim, M.Metal)
		end
		b.gem(0.26, CFrame.new(0, 0.66, -0.22))
	elseif look.style == "disc" then
		-- disco solar atrás da guarda (lâmina do eclipse)
		b.add(Vector3.new(0.18, 1.5, 1.5), CFrame.new(0, 0.72, 0) * CFrame.Angles(0, math.rad(90), 0), trim, M.Foil, { shape = "Cylinder" })
		b.add(Vector3.new(0.22, 1.05, 1.05), CFrame.new(0, 0.72, 0) * CFrame.Angles(0, math.rad(90), 0), C.obsidian, M.Slate, { shape = "Cylinder" })
		b.add(Vector3.new(0.26, 0.5, 0.5), CFrame.new(0, 0.72, 0) * CFrame.Angles(0, math.rad(90), 0), look.runes or rarity.color, M.Neon, { shape = "Cylinder", glow = true })
		for i = 0, 7 do
			b.wedge(Vector3.new(0.1, 0.35, 0.2), CFrame.new(0, 0.72, 0) * CFrame.Angles(0, 0, i * math.pi / 4) * CFrame.new(0, 0.9, 0), trim, M.Foil)
		end
	else -- cross
		b.add(Vector3.new(1.5, 0.22, 0.38), CFrame.new(0, 0.62, 0), trim, M.Metal)
		for _, s in { -1, 1 } do
			b.ball(0.3, CFrame.new(s * 0.78, 0.62, 0), trim, M.Metal)
		end
		b.gem(0.22, CFrame.new(0, 0.62, -0.2))
	end
	blade(b, look, rarity, width, length, 0.75 + length / 2)
	return 0.75 + length + width, 0.9
end

function weapon.katana(b, look, rarity)
	grip(b, 1.1, 0.0, look.wrap)
	for i = 0, 3 do
		b.add(Vector3.new(0.36, 0.06, 0.36), CFrame.new(0, -0.4 + i * 0.28, 0) * CFrame.Angles(0, math.rad(45), 0), C.gold, M.Metal)
	end
	if look.tsuba == "square" then
		b.add(Vector3.new(0.7, 0.1, 0.6), CFrame.new(0, 0.62, 0), C.darkSteel, M.Metal)
	elseif look.tsuba == "flower" then
		for i = 0, 4 do
			b.add(Vector3.new(0.34, 0.1, 0.34), CFrame.new(0, 0.62, 0) * CFrame.Angles(0, i * math.pi * 0.4, 0) * CFrame.new(0, 0, -0.22), C.gold, M.Metal)
		end
	else
		b.add(Vector3.new(0.1, 0.72, 0.72), CFrame.new(0, 0.62, 0) * CFrame.Angles(0, 0, math.rad(90)), C.darkSteel, M.Metal, { shape = "Cylinder" })
	end
	b.add(Vector3.new(0.75, 0.04, 0.75), CFrame.new(0, 0.68, 0), C.gold, M.Metal)
	b.add(Vector3.new(0.18, 0.25, 0.14), CFrame.new(0, 0.82, 0), C.gold, M.Metal)
	local color, material = look.metal, look.mat or M.Metal
	for i = 0, 7 do
		local y = 1.2 + i * 0.47
		local p = b.add(Vector3.new(0.17, 0.5, 0.08), CFrame.new(0.02 + i * 0.012, y, 0) * CFrame.Angles(0, 0, math.rad(-2 - i * 0.4)), color, material)
		p.Transparency = look.transparency or 0
		b.add(Vector3.new(0.05, 0.5, 0.1), CFrame.new(-0.07 + i * 0.012, y, 0) * CFrame.Angles(0, 0, math.rad(-2 - i * 0.4)), look.edge or rarity.color, if rarity.order >= 4 or look.transparency then M.Neon else M.Metal, { glow = true })
	end
	b.wedge(Vector3.new(0.08, 0.45, 0.18), CFrame.new(0.13, 5.0, 0) * CFrame.Angles(0, math.rad(90), 0), color, material)
	if look.moon then
		b.add(Vector3.new(0.05, 0.4, 0.4), CFrame.new(0, 2.3, -0.06) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(255, 220, 220), M.Neon, { shape = "Cylinder", glow = true })
	end
	return 4.95, 0.9
end

local function oneDagger(b, look, rarity, cf)
	local add = function(size, offset, color, material, opts)
		return b.add(size, cf * offset, color, material, opts)
	end
	for i = 0, 2 do
		add(Vector3.new(0.3, 0.12, 0.3), CFrame.new(0, -0.15 + i * 0.25, 0) * CFrame.Angles(0, math.rad(45 * (i % 2)), 0), look.trim or C.darkLeather, M.Fabric)
	end
	b.ball(0.24, cf * CFrame.new(0, -0.34, 0), rarity.color, if rarity.order >= 3 then M.Neon else M.Glass, true)
	add(Vector3.new(0.85, 0.14, 0.26), CFrame.new(0, 0.48, 0) * CFrame.Angles(0, 0, math.rad(8)), look.trim or C.darkSteel, M.Metal)
	local color, material = look.metal, look.mat or M.Metal
	local edge = look.edge or color:Lerp(Color3.new(1, 1, 1), 0.3)
	if look.style == "fang" or look.style == "curved" then
		for i = 0, 3 do
			local p = add(Vector3.new(0.3 - i * 0.05, 0.42, 0.1), CFrame.new(i * 0.07, 0.75 + i * 0.36, 0) * CFrame.Angles(0, 0, math.rad(-8 - i * 7)), color, material)
			p.Transparency = look.transparency or 0
			add(Vector3.new(0.05, 0.42, 0.11), CFrame.new(i * 0.07 - 0.16 + i * 0.02, 0.75 + i * 0.36, 0) * CFrame.Angles(0, 0, math.rad(-8 - i * 7)), edge, if look.glow then M.Neon else M.Metal, { glow = true })
		end
		return 2.2, 0.6
	end
	add(Vector3.new(0.18, 1.3, 0.1), CFrame.new(0, 1.2, 0), color, material)
	for _, s in { -1, 1 } do
		add(Vector3.new(0.08, 1.3, 0.1), CFrame.new(s * 0.12, 1.2, 0), edge, if look.glow then M.Neon else material, { glow = look.glow ~= nil })
	end
	local tip = add(Vector3.new(0.1, 0.35, 0.32), CFrame.new(0, 2.02, 0) * CFrame.Angles(0, math.rad(90), 0), color, material)
	tip.Shape = Enum.PartType.Wedge
	if look.style == "serrated" then
		for i = 0, 4 do
			local w = add(Vector3.new(0.08, 0.2, 0.16), CFrame.new(0.2, 0.7 + i * 0.25, 0) * CFrame.Angles(0, math.rad(90), 0), edge, material)
			w.Shape = Enum.PartType.Wedge
		end
	end
	return 2.25, 0.6
end

function weapon.dagger(b, look, rarity)
	local tip, start = oneDagger(b, look, rarity, CFrame.identity)
	if look.twin and not b.held then
		-- segunda adaga cruzada atrás (só aparece no ícone e no chão; na mão fica junto da primeira)
		oneDagger(b, look, rarity, CFrame.new(0.3, 0.2, 0.25) * CFrame.Angles(0, 0, math.rad(-28)))
	end
	return tip, start
end

function weapon.axe(b, look, rarity)
	local metal, material = look.metal, look.mat or M.Metal
	b.add(Vector3.new(0.28, 3.6, 0.28), CFrame.new(0, 1.7, 0), look.handle or C.wood, M.Wood)
	grip(b, 1.0, 0.1, look.wrap)
	b.add(Vector3.new(0.38, 0.5, 0.38), CFrame.new(0, 2.85, 0), C.darkSteel, M.Metal)
	b.wedge(Vector3.new(0.3, 0.35, 0.3), CFrame.new(0, 3.65, 0), C.darkSteel, M.Metal)
	local accent = glowColor(look, rarity)
	local function bit(side, jagged)
		b.add(Vector3.new(0.9, 0.9, 0.18), CFrame.new(side * 0.55, 2.95, 0), metal, material)
		b.wedge(Vector3.new(0.18, 0.75, 0.75), CFrame.new(side * 1.12, 3.38, 0) * CFrame.Angles(0, math.rad(side * 90), 0), metal, material)
		b.wedge(Vector3.new(0.18, 0.75, 0.75), CFrame.new(side * 1.12, 2.52, 0) * CFrame.Angles(0, math.rad(side * 90), math.rad(180)), metal, material)
		b.add(Vector3.new(0.12, 1.7, 0.2), CFrame.new(side * 1.48, 2.95, 0), accent, glowMaterial(look, rarity), { glow = true })
		if jagged then
			for i = 0, 2 do
				b.wedge(Vector3.new(0.16, 0.3, 0.3), CFrame.new(side * 1.62, 2.5 + i * 0.45, 0) * CFrame.Angles(0, math.rad(side * 90), 0), metal:Lerp(Color3.new(0, 0, 0), 0.2), material)
			end
		end
	end
	if look.style == "double" then
		bit(1)
		bit(-1)
	else
		bit(1, look.style == "jagged")
		b.wedge(Vector3.new(0.2, 0.5, 0.45), CFrame.new(-0.35, 2.95, 0) * CFrame.Angles(0, math.rad(-90), 0), C.darkSteel, M.Metal)
	end
	if look.lightning then
		for i = 0, 2 do
			b.add(Vector3.new(0.08, 0.5, 0.22), CFrame.new(0.6 + (i % 2) * 0.15, 2.6 + i * 0.35, 0) * CFrame.Angles(0, 0, math.rad(if i % 2 == 0 then 30 else -30)), look.glow, M.Neon, { glow = true })
		end
	end
	return 3.75, 2.3
end

function weapon.hammer(b, look, rarity)
	local metal, material = look.metal, look.mat or M.Metal
	local trim = look.trim or C.darkSteel
	local style = look.style
	local handleLength = if look.big then 4 else 3.4
	b.add(Vector3.new(0.3, handleLength, 0.3), CFrame.new(0, handleLength / 2, 0), look.handle or C.wood, M.Wood)
	grip(b, 1.1, 0.1)
	b.ball(0.4, CFrame.new(0, -0.55, 0), trim, M.Metal)
	local y = handleLength + 0.25
	local accent = glowColor(look, rarity)
	if style == "mace" then
		b.ball(1.2, CFrame.new(0, y, 0), metal, material)
		for i = 0, 5 do
			b.wedge(Vector3.new(0.14, 0.9, 0.5), CFrame.new(0, y, 0) * CFrame.Angles(0, i * math.pi / 3, 0) * CFrame.new(0, 0, -0.6) * CFrame.Angles(0, math.rad(90), 0), metal:Lerp(Color3.new(1, 1, 1), 0.15), material)
		end
		b.gem(0.32, CFrame.new(0, y + 0.65, 0))
		return y + 0.8, y - 0.6
	elseif style == "stone" then
		b.add(Vector3.new(1.8, 1.2, 1.2), CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(4)), metal, material)
		b.add(Vector3.new(1.0, 1.25, 1.25), CFrame.new(0.2, y + 0.05, 0) * CFrame.Angles(math.rad(8), 0, 0), metal:Lerp(Color3.new(0, 0, 0), 0.15), material)
		for _, s in { -1, 1 } do
			b.add(Vector3.new(0.2, 1.3, 1.3), CFrame.new(s * 0.35, y, 0), C.leather, M.Fabric)
		end
		return y + 0.7, y - 0.6
	end
	local w = if style == "giant" or look.big then 2.4 else 2.0
	local h = if style == "giant" or look.big then 1.6 else 1.3
	b.add(Vector3.new(w, h, h), CFrame.new(0, y, 0), metal, material)
	for _, s in { -1, 1 } do
		b.add(Vector3.new(0.25, h + 0.15, h + 0.15), CFrame.new(s * w * 0.35, y, 0), trim, M.Metal)
		b.add(Vector3.new(0.3, h * 0.75, h * 0.75), CFrame.new(s * (w / 2 + 0.12), y, 0), metal:Lerp(Color3.new(1, 1, 1), 0.2), material)
	end
	if style == "core" then
		-- núcleo brilhando dentro de rachaduras
		b.add(Vector3.new(w * 0.5, h * 0.4, h + 0.05), CFrame.new(0, y, 0), accent, M.Neon, { glow = true })
		for i = 0, 3 do
			b.add(Vector3.new(0.08, h * 0.6, h + 0.04), CFrame.new(-w * 0.3 + i * w * 0.2, y + 0.1, 0) * CFrame.Angles(0, 0, math.rad(25 - i * 15)), accent, M.Neon, { glow = true })
		end
	elseif style == "rune" then
		for _, s in { -1, 1 } do
			b.add(Vector3.new(0.4, 0.4, 0.06), CFrame.new(s * 0.45, y, -h / 2 - 0.02) * CFrame.Angles(0, 0, math.rad(45)), accent, M.Neon, { glow = true })
		end
		if look.lightning then
			for i = 0, 2 do
				b.add(Vector3.new(0.08, 0.45, 0.08), CFrame.new(-0.2 + i * 0.2, y + h / 2 + 0.2, 0) * CFrame.Angles(0, 0, math.rad(if i % 2 == 0 then 25 else -25)), accent, M.Neon, { glow = true })
			end
		end
	else
		b.gem(0.36, CFrame.new(0, y, -h / 2 - 0.02))
	end
	b.wedge(Vector3.new(0.5, 0.6, 0.5), CFrame.new(0, y + h / 2 + 0.3, 0), trim, M.Metal)
	return y + 0.75, y - 0.75
end

function weapon.spear(b, look, rarity)
	local metal, material = look.metal, look.mat or M.Metal
	local trim = look.trim or C.darkSteel
	b.add(Vector3.new(0.24, 6.6, 0.24), CFrame.new(0, 1.4, 0), look.shaft or C.wood, M.Wood)
	for _, y in { -1.4, 0.1, 3.6 } do
		b.add(Vector3.new(0.32, 0.25, 0.32), CFrame.new(0, y, 0), trim, M.Metal)
	end
	b.wedge(Vector3.new(0.26, 0.4, 0.26), CFrame.new(0, -1.95, 0) * CFrame.Angles(math.rad(180), 0, 0), trim, M.Metal)
	b.add(Vector3.new(0.36, 0.5, 0.36), CFrame.new(0, 4.75, 0), trim, M.Metal)
	for i = 0, 5 do
		b.add(Vector3.new(0.08, 0.75, 0.08), CFrame.new(0, 4.3, 0) * CFrame.Angles(0, i * math.pi / 3, 0) * CFrame.new(0, 0, -0.18) * CFrame.Angles(math.rad(-14), 0, 0), look.tassel or C.red, M.Fabric)
	end
	local accent = glowColor(look, rarity)
	local tipLook = { metal = metal, mat = material, edge = look.edge, glow = look.glow }
	if look.tip == "dragon" then
		blade(b, tipLook, rarity, 0.44, 1.0, 5.5, 0.12)
		for _, s in { -1, 1 } do
			b.wedge(Vector3.new(0.1, 0.8, 0.6), CFrame.new(s * 0.45, 5.0, 0) * CFrame.Angles(0, math.rad(s * 90), math.rad(s * 35)), metal, material)
			b.wedge(Vector3.new(0.08, 0.5, 0.4), CFrame.new(s * 0.7, 4.75, 0) * CFrame.Angles(0, math.rad(s * 90), math.rad(s * 60)), trim, M.Metal)
		end
		b.gem(0.26, CFrame.new(0, 4.85, -0.2))
	elseif look.tip == "celestial" then
		blade(b, tipLook, rarity, 0.4, 1.2, 5.6, 0.1)
		b.ring(0.55, 0.08, 12, CFrame.new(0, 5.1, 0) * CFrame.Angles(math.rad(90), 0, 0), accent, M.Neon, true)
		for _, s in { -1, 1 } do
			b.wedge(Vector3.new(0.08, 0.6, 0.3), CFrame.new(s * 0.3, 4.95, 0) * CFrame.Angles(0, math.rad(s * 90), math.rad(180)), trim, M.Metal)
		end
	elseif look.tip == "obsidian" then
		b.add(Vector3.new(0.5, 1.2, 0.16), CFrame.new(0, 5.6, 0) * CFrame.Angles(0, 0, math.rad(6)), metal, material)
		b.wedge(Vector3.new(0.16, 0.6, 0.5), CFrame.new(0, 6.5, 0), metal, material)
		b.add(Vector3.new(0.08, 1.0, 0.18), CFrame.new(0.05, 5.6, 0) * CFrame.Angles(0, 0, math.rad(10)), accent, M.Neon, { glow = true })
		for _, s in { -1, 1 } do
			b.wedge(Vector3.new(0.12, 0.6, 0.35), CFrame.new(s * 0.35, 5.0, 0) * CFrame.Angles(0, math.rad(s * 90), math.rad(180)), metal, material)
		end
	else
		blade(b, tipLook, rarity, 0.38, 0.9, 5.4, 0.1)
		for _, s in { -1, 1 } do
			b.wedge(Vector3.new(0.08, 0.5, 0.3), CFrame.new(s * 0.32, 5.05, 0) * CFrame.Angles(0, math.rad(s * 90), math.rad(180)), metal, material)
		end
	end
	return 6.3, 4.4
end

function weapon.bow(b, look, rarity)
	local limb = look.limb or C.wood
	local style = look.style
	local reach = if look.long then 1.95 else 1.7
	local accent = glowColor(look, rarity)
	for _, side in { -1, 1 } do
		for i = 0, 3 do
			local t = i / 3
			local y = side * (0.45 + t * reach)
			local z = -0.15 - t * t * 0.55
			local size = if style == "root" then Vector3.new(0.26, 0.66, 0.26) else Vector3.new(0.2, 0.64, 0.22)
			b.add(size, CFrame.new(0, y, z) * CFrame.Angles(math.rad(side * (8 + t * 30)), 0, math.rad(if style == "root" then (i % 2) * 8 else 0)), limb, if style == "bone" then M.SmoothPlastic else M.Wood)
			if style == "elven" and i > 0 then
				b.add(Vector3.new(0.06, 0.5, 0.24), CFrame.new(0, y, z - 0.02) * CFrame.Angles(math.rad(side * (8 + t * 30)), 0, 0), look.tips or C.gold, M.Metal)
			elseif style == "bone" and i % 2 == 1 then
				b.ball(0.3, CFrame.new(0, y, z), C.bone:Lerp(Color3.new(1, 1, 1), 0.2), M.SmoothPlastic)
			end
		end
		local tipY, tipZ = side * (0.45 + reach + 0.4), -0.75
		b.add(Vector3.new(0.26, 0.4, 0.26), CFrame.new(0, tipY, tipZ), look.tips or accent, if look.glow or rarity.order >= 4 then M.Neon else M.Metal, { glow = true })
		if style == "phoenix" then
			-- penas de fogo saindo das pontas
			for k = 0, 2 do
				b.wedge(Vector3.new(0.06, 0.7, 0.4), CFrame.new(0, tipY - side * k * 0.4, tipZ - 0.25) * CFrame.Angles(math.rad(side * (30 + k * 20)), 0, 0), if k == 0 then look.glow else limb:Lerp(look.glow, 0.5), M.Neon, true)
			end
		elseif style == "spider" then
			-- patas de aranha
			for k = 1, 2 do
				b.add(Vector3.new(0.1, 0.9, 0.1), CFrame.new(0, side * (0.6 + k * 0.55), -0.45 - k * 0.15) * CFrame.Angles(math.rad(side * 60), 0, 0), limb, M.SmoothPlastic)
			end
		end
	end
	b.add(Vector3.new(0.3, 0.9, 0.3), CFrame.new(0, 0, -0.08), look.grip or C.darkLeather, M.Fabric)
	b.gem(0.22, CFrame.new(0, 0, -0.28))
	if style == "bone" or style == "spider" then
		b.ball(0.5, CFrame.new(0, 0.55, -0.25), if style == "bone" then C.bone else Color3.fromRGB(60, 40, 70), M.SmoothPlastic)
		b.ball(0.12, CFrame.new(0.1, 0.6, -0.48), accent, M.Neon, true)
		b.ball(0.12, CFrame.new(-0.1, 0.6, -0.48), accent, M.Neon, true)
	end
	local stringLength = (0.45 + reach + 0.4) * 2
	b.add(Vector3.new(0.04, stringLength, 0.04), CFrame.new(0, 0, 0.3), if look.glow then look.glow else Color3.fromRGB(235, 235, 235), if look.glow then M.Neon else M.SmoothPlastic)
	return 2.3, -2.3
end

function weapon.staff(b, look, rarity)
	local shaft = look.shaft or C.wood
	local trim = look.trim or C.iron
	local accent = glowColor(look, rarity)
	b.add(Vector3.new(0.3, 6, 0.3), CFrame.new(0, 1.5, 0), shaft, if look.top == "skull" then M.SmoothPlastic else M.Wood)
	for _, y in { -0.6, 1.4, 3.3 } do
		b.add(Vector3.new(0.38, 0.2, 0.38), CFrame.new(0, y, 0), trim, M.Metal)
	end
	b.wedge(Vector3.new(0.3, 0.35, 0.3), CFrame.new(0, -1.65, 0) * CFrame.Angles(math.rad(180), 0, 0), trim, M.Metal)
	local top = look.top
	local y = 5.0
	if top == "knob" then
		b.ball(0.7, CFrame.new(0, 4.6, 0), shaft:Lerp(Color3.new(0, 0, 0), 0.2), M.Wood)
		return 4.9, 4.2
	elseif top == "orb" then
		for i = 0, 3 do
			b.add(Vector3.new(0.14, 1.0, 0.14), CFrame.new(0, 4.6, 0) * CFrame.Angles(0, i * math.pi / 2, 0) * CFrame.new(0, 0, -0.38) * CFrame.Angles(math.rad(-20), 0, 0), shaft, M.Wood)
		end
		b.ball(0.75, CFrame.new(0, y, 0), accent, if rarity.order >= 3 then M.Neon else M.Glass, true)
	elseif top == "crystal" or top == "cluster" then
		for i = 0, 3 do
			b.add(Vector3.new(0.14, 1.2, 0.14), CFrame.new(0, 4.65, 0) * CFrame.Angles(0, i * math.pi / 2, 0) * CFrame.new(0, 0, -0.45) * CFrame.Angles(math.rad(-22), 0, 0), shaft:Lerp(trim, 0.3), M.Wood)
		end
		b.add(Vector3.new(0.75, 1.3, 0.75), CFrame.new(0, y, 0) * CFrame.Angles(0, math.rad(45), 0), accent, M.Neon, { glow = true })
		b.wedge(Vector3.new(0.75, 0.5, 0.75), CFrame.new(0, y + 0.9, 0) * CFrame.Angles(0, math.rad(45), 0), accent, M.Neon, true)
		if top == "cluster" then
			for i = 0, 2 do
				b.add(Vector3.new(0.35, 0.8, 0.35), CFrame.new(0, y - 0.2, 0) * CFrame.Angles(0, i * 2.1, math.rad(30)) * CFrame.new(0, 0.3, 0), accent:Lerp(Color3.new(1, 1, 1), 0.3), M.Neon, { glow = true })
			end
		end
	elseif top == "sun" then
		b.ball(0.8, CFrame.new(0, y, 0), accent, M.Neon, true)
		for i = 0, 7 do
			b.wedge(Vector3.new(0.08, 0.55, 0.3), CFrame.new(0, y, 0) * CFrame.Angles(0, 0, i * math.pi / 4) * CFrame.new(0, 0.7, 0), trim, M.Foil)
		end
		b.ring(0.62, 0.1, 14, CFrame.new(0, y, 0) * CFrame.Angles(math.rad(90), 0, 0), trim, M.Foil)
	elseif top == "star" then
		for i = 0, 4 do
			b.wedge(Vector3.new(0.14, 0.75, 0.4), CFrame.new(0, y, 0) * CFrame.Angles(0, 0, i * math.pi * 0.4) * CFrame.new(0, 0.5, 0), accent, M.Neon, true)
		end
		b.ball(0.5, CFrame.new(0, y, 0), Color3.new(1, 1, 1), M.Neon, true)
		b.ring(0.85, 0.06, 16, CFrame.new(0, y, 0) * CFrame.Angles(math.rad(70), 0, math.rad(20)), trim, M.Metal)
	elseif top == "skull" then
		b.ball(0.85, CFrame.new(0, y, 0), C.bone, M.SmoothPlastic)
		b.add(Vector3.new(0.55, 0.35, 0.5), CFrame.new(0, y - 0.38, -0.1), C.bone, M.SmoothPlastic)
		for _, s in { -1, 1 } do
			b.ball(0.2, CFrame.new(s * 0.18, y + 0.02, -0.36), accent, M.Neon, true)
		end
		for _, s in { -1, 1 } do
			b.wedge(Vector3.new(0.12, 0.7, 0.3), CFrame.new(s * 0.4, y + 0.55, 0) * CFrame.Angles(0, math.rad(s * 90), math.rad(s * -20)), C.bone, M.SmoothPlastic)
		end
	elseif top == "magma" then
		b.add(Vector3.new(0.9, 0.9, 0.9), CFrame.new(0, y, 0) * CFrame.Angles(math.rad(30), math.rad(45), 0), C.obsidian, M.Basalt)
		b.ball(0.6, CFrame.new(0, y, 0), accent, M.Neon, true)
		for i = 0, 3 do
			b.wedge(Vector3.new(0.14, 0.7, 0.3), CFrame.new(0, y, 0) * CFrame.Angles(0, i * math.pi / 2, 0) * CFrame.new(0, 0.3, -0.5) * CFrame.Angles(math.rad(-30), 0, 0), C.obsidian, M.Basalt)
		end
	elseif top == "void" then
		b.ring(0.7, 0.12, 14, CFrame.new(0, y, 0) * CFrame.Angles(math.rad(90), 0, 0), trim, M.Foil, true)
		b.ring(0.5, 0.08, 12, CFrame.new(0, y, 0) * CFrame.Angles(math.rad(90), math.rad(90), 0), accent, M.Neon, true)
		b.ball(0.55, CFrame.new(0, y, 0), Color3.fromRGB(10, 5, 20), M.Neon, true)
		for _, s in { -1, 1 } do
			b.wedge(Vector3.new(0.12, 1.0, 0.3), CFrame.new(s * 0.75, y - 0.4, 0) * CFrame.Angles(0, math.rad(s * 90), math.rad(180)), trim, M.Foil)
		end
	end
	if top ~= "sun" and top ~= "skull" then
		b.ball(1.35, CFrame.new(0, y, 0), accent, M.ForceField)
	end
	return 5.5, 4.4
end

-- ===================== EQUIPAMENTOS =====================
local gear = {}

function gear.armor(b, look, rarity)
	local main, trim = look.main, look.trim or C.darkSteel
	local accent = glowColor(look, rarity)
	local style = look.style
	local fabric = style == "robe"
	local material = if style == "plate" or style == "dragon" then M.Metal elseif style == "mail" then M.DiamondPlate elseif fabric then M.Fabric else M.Leather
	-- tronco (peito mais largo que a cintura)
	b.add(Vector3.new(2.2, 1.3, 1.15), CFrame.new(0, 0.55, 0), main, material)
	b.add(Vector3.new(1.9, 1.1, 1.05), CFrame.new(0, -0.6, 0), main:Lerp(Color3.new(0, 0, 0), 0.08), material)
	-- gola
	b.add(Vector3.new(1.1, 0.3, 1.0), CFrame.new(0, 1.3, 0), trim, if fabric then M.Fabric else M.Metal)
	-- cinto com fivela
	b.add(Vector3.new(2.0, 0.28, 1.12), CFrame.new(0, -0.95, 0), if fabric then trim else C.darkLeather, M.Leather)
	b.add(Vector3.new(0.4, 0.34, 0.1), CFrame.new(0, -0.95, -0.6), C.gold, M.Metal)
	if fabric then
		-- saia longa do manto + faixa central
		b.add(Vector3.new(2.1, 1.3, 1.2), CFrame.new(0, -1.75, 0.02), main, M.Fabric)
		b.add(Vector3.new(0.35, 2.4, 0.08), CFrame.new(0, -0.5, -0.62), trim, M.Fabric)
		for _, s in { -1, 1 } do
			b.add(Vector3.new(0.65, 0.45, 1.2), CFrame.new(s * 1.2, 1.0, 0), main:Lerp(Color3.new(1, 1, 1), 0.08), M.Fabric)
		end
		if look.stars then
			for i = 0, 5 do
				b.ball(0.12, CFrame.new(-0.7 + (i % 3) * 0.7, -1.4 + math.floor(i / 3) * 0.8, -0.62), accent, M.Neon, true)
			end
		end
		if look.tattered then
			for i = 0, 4 do
				b.wedge(Vector3.new(0.4, 0.4, 0.08), CFrame.new(-0.8 + i * 0.4, -2.55, -0.55) * CFrame.Angles(math.rad(180), 0, 0), main, M.Fabric)
			end
		end
		if look.glow then
			b.add(Vector3.new(0.5, 0.5, 0.06), CFrame.new(0, 0.55, -0.6) * CFrame.Angles(0, 0, math.rad(45)), accent, M.Neon, { glow = true })
		end
		return
	end
	-- ombreiras
	for _, s in { -1, 1 } do
		if style == "plate" or style == "dragon" then
			b.add(Vector3.new(0.9, 0.45, 1.3), CFrame.new(s * 1.3, 1.1, 0) * CFrame.Angles(0, 0, math.rad(s * -18)), main:Lerp(Color3.new(1, 1, 1), 0.1), M.Metal)
			b.add(Vector3.new(0.95, 0.12, 1.35), CFrame.new(s * 1.3, 0.88, 0) * CFrame.Angles(0, 0, math.rad(s * -18)), trim, M.Metal)
			if style == "dragon" or look.heavy then
				for k = 0, 1 do
					b.wedge(Vector3.new(0.18, 0.6, 0.35), CFrame.new(s * (1.2 + k * 0.3), 1.5, -0.2 + k * 0.35) * CFrame.Angles(0, math.rad(s * 90), math.rad(s * -20)), trim, M.Metal)
				end
			end
		else
			b.add(Vector3.new(0.7, 0.35, 1.15), CFrame.new(s * 1.2, 1.05, 0), main:Lerp(Color3.new(0, 0, 0), 0.15), material)
		end
	end
	if style == "plate" then
		-- peitoral em placas sobrepostas com rebites e o emblema
		for i = 0, 2 do
			b.add(Vector3.new(1.9 - i * 0.2, 0.42, 0.12), CFrame.new(0, 0.8 - i * 0.45, -0.6), main:Lerp(Color3.new(1, 1, 1), 0.12 - i * 0.04), M.Metal)
			for _, s in { -1, 1 } do
				b.ball(0.12, CFrame.new(s * (0.85 - i * 0.1), 0.8 - i * 0.45, -0.67), trim, M.Metal)
			end
		end
		b.add(Vector3.new(0.5, 0.5, 0.08), CFrame.new(0, 0.62, -0.69) * CFrame.Angles(0, 0, math.rad(45)), accent, glowMaterial(look, rarity), { glow = true })
		if look.light then
			for _, s in { -1, 1 } do
				b.wedge(Vector3.new(0.08, 0.8, 0.5), CFrame.new(s * 0.9, -0.3, -0.6) * CFrame.Angles(0, math.rad(s * 90), 0), C.silver, M.Metal)
			end
		end
	elseif style == "dragon" then
		-- escamas em fileiras
		for row = 0, 3 do
			for col = -2, 2 do
				b.wedge(Vector3.new(0.34, 0.3, 0.12), CFrame.new(col * 0.36 + (row % 2) * 0.18, 0.95 - row * 0.4, -0.62) * CFrame.Angles(math.rad(180), 0, 0), main:Lerp(trim, 0.15 * (row % 2)), M.Metal)
			end
		end
		b.add(Vector3.new(0.5, 0.5, 0.1), CFrame.new(0, -0.55, -0.62) * CFrame.Angles(0, 0, math.rad(45)), accent, glowMaterial(look, rarity), { glow = true })
	elseif style == "mail" then
		for i = 0, 4 do
			b.add(Vector3.new(2.0, 0.06, 1.18), CFrame.new(0, 1.0 - i * 0.45, 0), main:Lerp(Color3.new(1, 1, 1), 0.25), M.Metal)
		end
		b.add(Vector3.new(0.9, 2.0, 0.1), CFrame.new(0, 0, -0.6), trim, M.Leather)
	else -- couro
		for _, s in { -1, 1 } do
			b.add(Vector3.new(0.12, 2.2, 0.08), CFrame.new(s * 0.45, 0, -0.6) * CFrame.Angles(0, 0, math.rad(s * 18)), trim, M.Leather)
		end
		for i = 0, 3 do
			b.add(Vector3.new(0.12, 0.12, 0.06), CFrame.new(0, 0.8 - i * 0.4, -0.61), C.iron, M.Metal)
		end
		if look.straps then
			b.add(Vector3.new(2.25, 0.2, 1.2), CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.rad(25)), C.darkLeather, M.Leather)
			b.add(Vector3.new(0.5, 0.4, 0.3), CFrame.new(0.7, -0.6, -0.65), C.leather, M.Leather)
		end
		if look.hood then
			b.add(Vector3.new(1.3, 0.6, 0.5), CFrame.new(0, 1.35, 0.5), main, M.Fabric)
		end
	end
end

function gear.helmet(b, look, rarity)
	local main, trim = look.main, look.trim or C.darkSteel
	local accent = glowColor(look, rarity)
	local style = look.style
	if style == "hood" then
		b.ball(1.9, CFrame.new(0, 0.1, 0.1), main, M.Fabric)
		b.add(Vector3.new(1.95, 1.1, 1.0), CFrame.new(0, -0.5, 0.2), main, M.Fabric)
		b.wedge(Vector3.new(0.9, 0.7, 0.9), CFrame.new(0, 0.95, 0.6) * CFrame.Angles(math.rad(-30), 0, 0), main, M.Fabric)
		b.add(Vector3.new(1.3, 1.1, 0.2), CFrame.new(0, -0.1, -0.85), Color3.fromRGB(15, 12, 18), M.SmoothPlastic)
		b.add(Vector3.new(1.55, 0.2, 0.3), CFrame.new(0, 0.55, -0.8), trim, M.Fabric)
		if look.eyes then
			for _, s in { -1, 1 } do
				b.ball(0.18, CFrame.new(s * 0.25, 0.0, -0.95), look.eyes, M.Neon, true)
			end
		end
		return
	elseif style == "crown" then
		local radius = if look.big then 0.95 else 0.8
		b.ring(radius, 0.3, 16, CFrame.new(0, -0.2, 0), main, M.Foil)
		for i = 0, 7 do
			local angle = i / 8 * math.pi * 2
			local tall = i % 2 == 0
			b.wedge(Vector3.new(0.35, if tall then 0.75 else 0.45, 0.12), CFrame.new(0, 0.2, 0) * CFrame.Angles(0, angle, 0) * CFrame.new(0, if tall then 0.15 else 0, -radius), main, M.Foil)
			if tall then
				b.ball(0.2, CFrame.new(0, 0.2, 0) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0.6, -radius), accent, M.Neon, true)
			end
		end
		b.gem(0.32, CFrame.new(0, -0.2, -radius - 0.05), accent)
		if look.big then
			b.ring(radius - 0.05, 0.12, 16, CFrame.new(0, -0.45, 0), trim, M.Metal)
		end
		return
	end
	local material = if style == "cap" then M.Leather else M.Metal
	-- cúpula
	b.ball(1.9, CFrame.new(0, 0.15, 0), main, material)
	b.cyl(0.8, 1.98, CFrame.new(0, -0.35, 0), main, material)
	b.ring(1.0, 0.18, 16, CFrame.new(0, -0.55, 0), trim, if style == "cap" then M.Leather else M.Metal)
	if style == "cap" then
		for _, s in { -1, 1 } do
			b.add(Vector3.new(0.12, 0.8, 0.5), CFrame.new(s * 0.98, -0.75, 0), main, M.Leather)
		end
		b.add(Vector3.new(0.12, 1.2, 0.12), CFrame.new(0, 0.4, -0.85) * CFrame.Angles(math.rad(-20), 0, 0), trim, M.Leather)
		return
	end
	-- face com viseira e frestas
	b.add(Vector3.new(1.5, 1.0, 0.2), CFrame.new(0, -0.35, -0.92), main:Lerp(Color3.new(1, 1, 1), 0.08), M.Metal)
	b.add(Vector3.new(1.1, 0.12, 0.08), CFrame.new(0, -0.18, -1.03), Color3.fromRGB(15, 15, 18), M.SmoothPlastic)
	b.add(Vector3.new(0.12, 0.7, 0.08), CFrame.new(0, -0.5, -1.03), Color3.fromRGB(15, 15, 18), M.SmoothPlastic)
	b.add(Vector3.new(0.2, 1.4, 0.2), CFrame.new(0, 0.55, -0.6) * CFrame.Angles(math.rad(-35), 0, 0), trim, M.Metal)
	if look.glow then
		b.add(Vector3.new(0.9, 0.08, 0.06), CFrame.new(0, -0.18, -1.06), accent, M.Neon, { glow = true })
	end
	if style == "horned" then
		for _, s in { -1, 1 } do
			for k = 0, 2 do
				b.add(Vector3.new(0.3 - k * 0.07, 0.55, 0.3 - k * 0.07), CFrame.new(s * (0.95 + k * 0.25), 0.3 + k * 0.42, 0) * CFrame.Angles(0, 0, math.rad(s * (-40 + k * 25))), if k == 2 then accent else trim, if k == 2 and look.glow then M.Neon else M.Metal, { glow = k == 2 })
			end
		end
		b.wedge(Vector3.new(0.15, 0.6, 0.9), CFrame.new(0, 1.05, 0.1), trim, M.Metal)
	else
		b.gem(0.26, CFrame.new(0, 0.55, -0.95))
	end
end

function gear.boots(b, look, rarity)
	local main, trim = look.main, look.trim or C.darkSteel
	local accent = glowColor(look, rarity)
	local style = look.style
	for _, s in { -1, 1 } do
		local x = s * 0.6
		local cf = CFrame.new(x, 0, 0) * CFrame.Angles(0, math.rad(s * -8), 0)
		if style == "sandal" then
			b.add(Vector3.new(0.75, 0.15, 1.5), cf * CFrame.new(0, -0.9, -0.2), main, M.Wood)
			for k = 0, 2 do
				b.add(Vector3.new(0.78, 0.1, 0.12), cf * CFrame.new(0, -0.7 + k * 0.35, -0.5 + k * 0.25), trim, M.Leather)
			end
			b.add(Vector3.new(0.12, 1.1, 0.12), cf * CFrame.new(0, -0.35, 0.3), trim, M.Leather)
		else
			local material = if style == "iron" or style == "dragon" then M.Metal else M.Leather
			-- cano, pé e bico
			b.add(Vector3.new(0.75, 1.3, 0.8), cf * CFrame.new(0, -0.1, 0.1), main, material)
			b.add(Vector3.new(0.8, 0.55, 1.4), cf * CFrame.new(0, -0.65, -0.2), main:Lerp(Color3.new(0, 0, 0), 0.08), material)
			b.wedge(Vector3.new(0.8, 0.45, 0.45), cf * CFrame.new(0, -0.7, -1.05) * CFrame.Angles(0, math.rad(180), 0), main, material)
			b.add(Vector3.new(0.82, 0.14, 1.45), cf * CFrame.new(0, -0.95, -0.2), C.darkLeather, M.Leather)
			b.add(Vector3.new(0.85, 0.2, 0.85), cf * CFrame.new(0, 0.5, 0.1), trim, material)
			if style == "iron" or style == "dragon" then
				b.add(Vector3.new(0.6, 0.7, 0.12), cf * CFrame.new(0, -0.05, -0.33), main:Lerp(Color3.new(1, 1, 1), 0.15), M.Metal)
				if style == "dragon" then
					for k = 0, 2 do
						b.wedge(Vector3.new(0.12, 0.35, 0.3), cf * CFrame.new(0, 0.3 - k * 0.3, 0.55), trim, M.Metal)
					end
				end
				if look.glow then
					b.add(Vector3.new(0.4, 0.08, 0.06), cf * CFrame.new(0, -0.05, -0.4), accent, M.Neon, { glow = true })
				end
			elseif style == "wing" then
				for k = 0, 1 do
					b.wedge(Vector3.new(0.08, 0.7 - k * 0.2, 0.6), cf * CFrame.new(s * 0.42, 0.1 + k * 0.25, 0.25 + k * 0.1) * CFrame.Angles(0, 0, math.rad(s * 25)), if look.glow then accent else trim, if look.glow then M.Neon else M.Metal, k == 0)
				end
			else
				for k = 0, 1 do
					b.add(Vector3.new(0.8, 0.1, 0.84), cf * CFrame.new(0, 0.05 - k * 0.35, 0.1), C.darkLeather, M.Leather)
					b.add(Vector3.new(0.14, 0.14, 0.06), cf * CFrame.new(0.2, 0.05 - k * 0.35, -0.33), C.iron, M.Metal)
				end
			end
		end
	end
end

function gear.amulet(b, look, rarity)
	local main = look.main or C.gold
	local gemColor = look.gem or rarity.color
	-- corrente (contas em arco)
	for i = 0, 12 do
		local angle = math.rad(-150 + i * 25)
		b.ball(0.16, CFrame.new(math.sin(angle) * 1.0, math.cos(angle) * 1.0 + 0.6, 0), look.chain or main, M.Metal)
	end
	local cf = CFrame.new(0, -0.55, 0)
	local pendant = look.pendant
	if pendant == "coin" then
		b.add(Vector3.new(0.15, 1.0, 1.0), cf * CFrame.Angles(0, math.rad(90), 0), main, M.Metal, { shape = "Cylinder" })
		b.add(Vector3.new(0.18, 0.5, 0.5), cf * CFrame.Angles(0, math.rad(90), 0), main:Lerp(Color3.new(1, 1, 1), 0.2), M.Metal, { shape = "Cylinder" })
	elseif pendant == "heart" then
		for _, s in { -1, 1 } do
			b.ball(0.55, cf * CFrame.new(s * 0.2, 0.15, 0), gemColor, M.Neon, true)
		end
		b.wedge(Vector3.new(0.2, 0.5, 0.6), cf * CFrame.new(0, -0.25, 0) * CFrame.Angles(math.rad(180), math.rad(90), 0), gemColor, M.Neon, true)
		b.ring(0.48, 0.07, 12, cf * CFrame.Angles(math.rad(90), 0, 0), main, M.Metal)
	elseif pendant == "moon" then
		for i = 0, 6 do
			local angle = math.rad(40 + i * 40)
			b.add(Vector3.new(0.22, 0.28, 0.15), cf * CFrame.new(math.cos(angle) * 0.45, math.sin(angle) * 0.45, 0) * CFrame.Angles(0, 0, angle), main, M.Metal)
		end
		b.gem(0.3, cf * CFrame.new(0.1, 0, -0.05), gemColor)
	elseif pendant == "eye" then
		b.add(Vector3.new(0.9, 0.5, 0.15), cf, main, M.Metal)
		b.ball(0.4, cf * CFrame.new(0, 0, -0.06), gemColor, M.Neon, true)
		for _, s in { -1, 1 } do
			b.wedge(Vector3.new(0.12, 0.3, 0.3), cf * CFrame.new(s * 0.58, 0, 0) * CFrame.Angles(0, math.rad(s * 90), 0), main, M.Metal)
		end
	elseif pendant == "claw" then
		b.gem(0.45, cf, gemColor)
		for i = -1, 1 do
			b.wedge(Vector3.new(0.12, 0.7, 0.2), cf * CFrame.new(i * 0.28, -0.35, 0) * CFrame.Angles(math.rad(180), math.rad(90), math.rad(i * 15)), C.bone, M.SmoothPlastic)
		end
		b.ring(0.32, 0.08, 10, cf * CFrame.Angles(math.rad(90), 0, 0), main, M.Metal)
	else -- almas
		b.add(Vector3.new(0.7, 0.9, 0.3), cf, main, M.Slate)
		for i = 0, 2 do
			b.ball(0.2, cf * CFrame.new(-0.2 + i * 0.2, 0.1 - (i % 2) * 0.2, -0.17), gemColor, M.Neon, true)
		end
		b.wedge(Vector3.new(0.3, 0.3, 0.3), cf * CFrame.new(0, -0.6, 0) * CFrame.Angles(math.rad(180), 0, 0), main, M.Slate)
	end
end

function gear.ring(b, look, rarity)
	local band = look.band or C.gold
	local gemColor = look.gem or rarity.color
	-- aro em pé, de frente para a câmera
	b.ring(0.6, 0.18, 14, CFrame.Angles(math.rad(90), 0, 0), band, M.Metal)
	local top = CFrame.new(0, 0.68, 0)
	b.add(Vector3.new(0.5, 0.2, 0.4), top, band, M.Metal)
	if look.skull then
		b.ball(0.5, top * CFrame.new(0, 0.25, 0), C.bone, M.SmoothPlastic)
		for _, s in { -1, 1 } do
			b.ball(0.12, top * CFrame.new(s * 0.1, 0.27, -0.22), gemColor, M.Neon, true)
		end
	else
		b.gem(0.42, top * CFrame.new(0, 0.22, 0), gemColor)
	end
	if look.fangs then
		for _, s in { -1, 1 } do
			b.wedge(Vector3.new(0.08, 0.3, 0.12), top * CFrame.new(s * 0.18, 0.05, -0.2) * CFrame.Angles(math.rad(180), 0, 0), C.bone, M.SmoothPlastic)
		end
	elseif look.crown then
		for i = 0, 4 do
			b.wedge(Vector3.new(0.08, 0.22, 0.1), top * CFrame.new(0, 0.12, 0) * CFrame.Angles(0, i * math.pi * 0.4, 0) * CFrame.new(0, 0.2, -0.25), band, M.Metal)
		end
	elseif look.spikes then
		for _, s in { -1, 1 } do
			b.wedge(Vector3.new(0.1, 0.3, 0.2), top * CFrame.new(s * 0.32, 0.15, 0) * CFrame.Angles(0, math.rad(s * 90), math.rad(s * -30)), band, M.Metal)
		end
	elseif look.shield then
		b.add(Vector3.new(0.55, 0.06, 0.5), top * CFrame.new(0, 0.12, 0), band:Lerp(Color3.new(1, 1, 1), 0.2), M.Metal)
	end
end

-- ===================== NO CORPO (equipamento vestido) =====================
-- Peças do item vestido, presas nas partes do corpo R15. Cada peça: { part = "UpperTorso", size, cf
-- (relativo à parte do corpo), color, material, shape, glow, transparency }. O servidor solda.
-- Usa o mesmo visual (ItemModels.Looks) do ícone, então o que você vê no inventário é o que veste.
local worn = {}

local function wornList(sizes, rarity)
	local list = {}
	local w = {}
	function w.add(partName, size, cf, color, material, opts)
		if not sizes[partName] then
			return
		end
		local entry = { part = partName, size = size, cf = cf, color = color, material = material or M.Metal }
		if opts then
			entry.shape = opts.shape
			entry.glow = opts.glow
			entry.transparency = opts.transparency
		end
		table.insert(list, entry)
	end
	function w.ball(partName, diameter, cf, color, material, glow)
		w.add(partName, Vector3.one * diameter, cf, color, material, { shape = "Ball", glow = glow })
	end
	function w.wedge(partName, size, cf, color, material, glow)
		w.add(partName, size, cf, color, material, { shape = "Wedge", glow = glow })
	end
	function w.gem(partName, diameter, cf, color)
		w.ball(partName, diameter, cf, color or rarity.color, if rarity.order >= 3 then M.Neon else M.Glass, true)
	end
	w.list = list
	return w
end

local SIDES = { Left = -1, Right = 1 }

function worn.armor(w, look, rarity, sizes)
	local main, trim = look.main or C.steel, look.trim or C.darkSteel
	local accent = glowColor(look, rarity)
	local style = look.style or "plate"
	local fabric = style == "robe"
	local material = if style == "plate" or style == "dragon" then M.Metal elseif style == "mail" then M.DiamondPlate elseif fabric then M.Fabric else M.Leather
	local t = sizes.UpperTorso
	if not t then
		return
	end
	local front = -(t.Z / 2)
	-- casca do peito, gola e cinto
	w.add("UpperTorso", t + Vector3.new(0.18, 0.06, 0.18), CFrame.new(), main, material)
	w.add("UpperTorso", Vector3.new(t.X * 0.62, 0.26, t.Z + 0.26), CFrame.new(0, t.Y / 2 - 0.02, 0), trim, if fabric then M.Fabric else M.Metal)
	local lower = sizes.LowerTorso
	if lower then
		w.add("LowerTorso", lower + Vector3.new(0.2, 0.06, 0.2), CFrame.new(), main:Lerp(Color3.new(0, 0, 0), 0.1), material)
		w.add("LowerTorso", Vector3.new(lower.X + 0.28, 0.24, lower.Z + 0.28), CFrame.new(0, 0.05, 0), if fabric then trim else C.darkLeather, M.Leather)
		w.add("LowerTorso", Vector3.new(0.36, 0.3, 0.1), CFrame.new(0, 0.05, -(lower.Z / 2 + 0.17)), C.gold, M.Metal)
	end
	-- braços: ombreiras, mangas e braçadeiras
	for side, sign in SIDES do
		local upper = sizes[side .. "UpperArm"]
		local fore = sizes[side .. "LowerArm"]
		local upperName, foreName = side .. "UpperArm", side .. "LowerArm"
		if upper then
			if fabric then
				w.add(upperName, upper + Vector3.new(0.16, 0.0, 0.16), CFrame.new(0, 0.05, 0), main, M.Fabric)
				w.add(upperName, Vector3.new(upper.X + 0.35, 0.4, upper.Z + 0.35), CFrame.new(0, upper.Y / 2 - 0.15, 0), main:Lerp(Color3.new(1, 1, 1), 0.08), M.Fabric)
			elseif style == "plate" or style == "dragon" then
				local big = if look.heavy then 0.25 else 0
				w.add(upperName, Vector3.new(upper.X + 0.45 + big, 0.5 + big * 0.5, upper.Z + 0.45 + big), CFrame.new(sign * 0.08, upper.Y / 2 - 0.08, 0) * CFrame.Angles(0, 0, math.rad(-sign * 14)), main:Lerp(Color3.new(1, 1, 1), 0.1), M.Metal)
				w.add(upperName, Vector3.new(upper.X + 0.5 + big, 0.12, upper.Z + 0.5 + big), CFrame.new(sign * 0.08, upper.Y / 2 - 0.36, 0) * CFrame.Angles(0, 0, math.rad(-sign * 14)), trim, M.Metal)
				w.add(upperName, upper + Vector3.new(0.12, -0.3, 0.12), CFrame.new(0, -0.15, 0), main:Lerp(Color3.new(0, 0, 0), 0.1), M.Metal)
				if style == "dragon" or look.heavy then
					for k = 0, 1 do
						w.wedge(upperName, Vector3.new(0.14, 0.5, 0.3), CFrame.new(sign * (upper.X / 2 + 0.05), upper.Y / 2 + 0.2, -0.2 + k * 0.4) * CFrame.Angles(0, math.rad(sign * 90), math.rad(-sign * 20)), trim, M.Metal)
					end
				end
				if rarity.order >= 4 or look.glow then
					w.add(upperName, Vector3.new(upper.X + 0.52 + big, 0.06, 0.12), CFrame.new(sign * 0.08, upper.Y / 2 + 0.02, -(upper.Z / 2 + 0.22 + big / 2)), accent, M.Neon, { glow = true })
				end
			elseif style == "mail" then
				w.add(upperName, upper + Vector3.new(0.12, -0.1, 0.12), CFrame.new(0, 0.05, 0), main, M.DiamondPlate)
			else
				w.add(upperName, Vector3.new(upper.X + 0.3, 0.35, upper.Z + 0.3), CFrame.new(0, upper.Y / 2 - 0.12, 0), main:Lerp(Color3.new(0, 0, 0), 0.15), M.Leather)
			end
		end
		if fore then
			if fabric then
				-- manga larga que abre no punho
				w.add(foreName, Vector3.new(fore.X + 0.3, fore.Y * 0.7, fore.Z + 0.3), CFrame.new(0, -fore.Y * 0.1, 0), main, M.Fabric)
				w.add(foreName, Vector3.new(fore.X + 0.36, 0.16, fore.Z + 0.36), CFrame.new(0, -fore.Y * 0.45, 0), trim, M.Fabric)
			else
				w.add(foreName, Vector3.new(fore.X + 0.14, fore.Y * 0.5, fore.Z + 0.14), CFrame.new(0, -fore.Y * 0.12, 0), if style == "leather" then C.darkLeather else main, if style == "leather" then M.Leather else M.Metal)
				w.add(foreName, Vector3.new(fore.X + 0.18, 0.1, fore.Z + 0.18), CFrame.new(0, fore.Y * 0.12, 0), trim, M.Metal)
			end
		end
	end
	if fabric then
		-- faixa central, saia longa do manto, estrelas/rasgos/emblema
		w.add("UpperTorso", Vector3.new(0.34, t.Y + 0.05, 0.08), CFrame.new(0, 0, front - 0.12), trim, M.Fabric)
		if lower then
			w.add("LowerTorso", Vector3.new(lower.X + 0.4, 2.1, lower.Z + 0.4), CFrame.new(0, -1.05, 0.02), main, M.Fabric)
			w.add("LowerTorso", Vector3.new(0.34, 2.1, 0.08), CFrame.new(0, -1.05, -(lower.Z / 2 + 0.24)), trim, M.Fabric)
			w.add("LowerTorso", Vector3.new(lower.X + 0.44, 0.14, lower.Z + 0.44), CFrame.new(0, -2.05, 0.02), trim, M.Fabric)
			if look.tattered then
				for i = 0, 4 do
					w.wedge("LowerTorso", Vector3.new(0.36, 0.35, 0.08), CFrame.new(-0.8 + i * 0.4, -2.25, -(lower.Z / 2 + 0.2)) * CFrame.Angles(math.rad(180), 0, 0), main, M.Fabric)
				end
			end
		end
		if look.stars then
			for i = 0, 4 do
				w.ball("UpperTorso", 0.12, CFrame.new(-0.6 + (i % 3) * 0.6, 0.35 - math.floor(i / 3) * 0.6, front - 0.12), accent, M.Neon, true)
			end
		end
		if look.glow or rarity.order >= 4 then
			w.add("UpperTorso", Vector3.new(0.42, 0.42, 0.06), CFrame.new(0, 0.25, front - 0.17) * CFrame.Angles(0, 0, math.rad(45)), accent, M.Neon, { glow = true })
		end
	elseif style == "plate" then
		for i = 0, 2 do
			w.add("UpperTorso", Vector3.new(t.X * 0.82 - i * 0.12, t.Y * 0.26, 0.14), CFrame.new(0, t.Y * 0.28 - i * t.Y * 0.27, front - 0.12), main:Lerp(Color3.new(1, 1, 1), 0.14 - i * 0.04), M.Metal)
			for _, sign in { -1, 1 } do
				w.ball("UpperTorso", 0.12, CFrame.new(sign * (t.X * 0.36 - i * 0.06), t.Y * 0.28 - i * t.Y * 0.27, front - 0.2), trim, M.Metal)
			end
		end
		w.add("UpperTorso", Vector3.new(0.42, 0.42, 0.08), CFrame.new(0, t.Y * 0.14, front - 0.22) * CFrame.Angles(0, 0, math.rad(45)), accent, glowMaterial(look, rarity), { glow = true })
		if lower then
			-- placas de saia (tassets) na frente e atrás
			for _, z in { -1, 1 } do
				for _, sign in { -1, 1 } do
					w.add("LowerTorso", Vector3.new(lower.X * 0.42, 0.75, 0.12), CFrame.new(sign * lower.X * 0.24, -0.45, z * (lower.Z / 2 + 0.16)) * CFrame.Angles(math.rad(z * -8), 0, 0), main:Lerp(Color3.new(1, 1, 1), 0.08), M.Metal)
				end
			end
		end
		if look.light then
			for _, sign in { -1, 1 } do
				w.wedge("UpperTorso", Vector3.new(0.08, 0.9, 0.6), CFrame.new(sign * (t.X / 2 + 0.05), 0.1, t.Z / 2) * CFrame.Angles(0, math.rad(sign * 90), math.rad(sign * -20)), C.silver, M.Metal)
			end
		end
	elseif style == "dragon" then
		for row = 0, 3 do
			for col = -2, 2 do
				w.wedge("UpperTorso", Vector3.new(t.X * 0.17, t.Y * 0.22, 0.12), CFrame.new(col * t.X * 0.18 + (row % 2) * t.X * 0.09, t.Y * 0.32 - row * t.Y * 0.22, front - 0.12) * CFrame.Angles(math.rad(180), 0, 0), main:Lerp(trim, 0.15 * (row % 2)), M.Metal)
			end
		end
		w.add("UpperTorso", Vector3.new(0.4, 0.4, 0.1), CFrame.new(0, -t.Y * 0.38, front - 0.18) * CFrame.Angles(0, 0, math.rad(45)), accent, glowMaterial(look, rarity), { glow = true })
		for k = 0, 2 do
			w.wedge("UpperTorso", Vector3.new(0.12, 0.35, 0.3), CFrame.new(0, t.Y * 0.3 - k * 0.45, t.Z / 2 + 0.2), trim, M.Metal)
		end
	elseif style == "mail" then
		for i = 0, 3 do
			w.add("UpperTorso", Vector3.new(t.X + 0.22, 0.05, t.Z + 0.22), CFrame.new(0, t.Y * 0.35 - i * t.Y * 0.25, 0), main:Lerp(Color3.new(1, 1, 1), 0.3), M.Metal)
		end
		w.add("UpperTorso", Vector3.new(t.X * 0.42, t.Y + 0.05, 0.08), CFrame.new(0, 0, front - 0.13), trim, M.Leather)
		if lower then
			w.add("LowerTorso", Vector3.new(lower.X * 0.42, 1.0, 0.08), CFrame.new(0, -0.55, -(lower.Z / 2 + 0.15)), trim, M.Leather)
		end
	else -- couro
		for _, sign in { -1, 1 } do
			w.add("UpperTorso", Vector3.new(0.14, t.Y * 1.25, 0.08), CFrame.new(sign * t.X * 0.18, 0, front - 0.12) * CFrame.Angles(0, 0, math.rad(sign * 22)), trim, M.Leather)
		end
		for i = 0, 2 do
			w.add("UpperTorso", Vector3.new(0.13, 0.13, 0.06), CFrame.new(0, t.Y * 0.3 - i * t.Y * 0.28, front - 0.13), C.iron, M.Metal)
		end
		if look.straps then
			w.add("UpperTorso", Vector3.new(t.X * 1.2, 0.2, t.Z + 0.24), CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(32)), C.darkLeather, M.Leather)
		end
		if lower then
			w.add("LowerTorso", Vector3.new(0.45, 0.4, 0.28), CFrame.new(lower.X * 0.32, -0.25, -(lower.Z / 2 + 0.12)), C.leather, M.Leather)
		end
		if look.hood then
			w.add("UpperTorso", Vector3.new(t.X * 0.6, 0.55, 0.5), CFrame.new(0, t.Y / 2 + 0.15, t.Z / 2 + 0.05), main, M.Fabric)
		end
	end
	-- capa nas costas (Lendário para cima e Únicos)
	if rarity.order >= 5 then
		local cape = rarity.color:Lerp(Color3.new(0, 0, 0), if rarity.unique then 0.55 else 0.35)
		w.add("UpperTorso", Vector3.new(t.X * 0.95, 3.4, 0.12), CFrame.new(0, -1.15, t.Z / 2 + 0.22) * CFrame.Angles(math.rad(-6), 0, 0), cape, M.Fabric)
		w.add("UpperTorso", Vector3.new(t.X * 0.95, 0.15, 0.14), CFrame.new(0, -2.8, t.Z / 2 + 0.4) * CFrame.Angles(math.rad(-6), 0, 0), rarity.color, M.Neon, { glow = true })
		for _, sign in { -1, 1 } do
			w.ball("UpperTorso", 0.28, CFrame.new(sign * t.X * 0.38, t.Y / 2 - 0.1, front - 0.1), C.gold, M.Metal)
		end
	end
end

function worn.helmet(w, look, rarity, sizes)
	local h = sizes.Head
	if not h then
		return
	end
	local main, trim = look.main or C.iron, look.trim or C.darkSteel
	local accent = glowColor(look, rarity)
	local style = look.style or "iron"
	local front = -(h.Z / 2)
	if style == "hood" then
		w.add("Head", h + Vector3.new(0.36, 0.32, 0.42), CFrame.new(0, 0.12, 0.1), main, M.Fabric)
		w.wedge("Head", Vector3.new(h.X * 0.55, 0.6, 0.7), CFrame.new(0, h.Y / 2 + 0.05, h.Z / 2 + 0.2) * CFrame.Angles(math.rad(-35), 0, 0), main, M.Fabric)
		w.add("Head", Vector3.new(h.X + 0.42, 0.14, 0.12), CFrame.new(0, h.Y / 2 - 0.12, front - 0.16), trim, M.Fabric)
		for _, sign in { -1, 1 } do
			w.add("Head", Vector3.new(0.14, h.Y + 0.1, 0.12), CFrame.new(sign * (h.X / 2 + 0.12), 0, front - 0.12), trim, M.Fabric)
		end
		if look.eyes then
			for _, sign in { -1, 1 } do
				w.ball("Head", 0.12, CFrame.new(sign * h.X * 0.18, h.Y * 0.05, front - 0.04), look.eyes, M.Neon, true)
			end
		end
		return
	elseif style == "crown" then
		local radius = h.X / 2 + (if look.big then 0.14 else 0.06)
		local y = h.Y / 2 + 0.02
		for i = 0, 11 do
			local angle = i / 12 * math.pi * 2
			local length = 2 * radius * math.tan(math.pi / 12) + 0.02
			w.add("Head", Vector3.new(length, 0.3, 0.12), CFrame.new(0, y, 0) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -radius), main, M.Foil)
			if i % 2 == 0 then
				w.wedge("Head", Vector3.new(0.18, if i % 4 == 0 then 0.55 else 0.35, 0.1), CFrame.new(0, y + 0.3, 0) * CFrame.Angles(0, angle, 0) * CFrame.new(0, if i % 4 == 0 then 0.1 else 0, -radius), main, M.Foil)
			end
			if i % 4 == 0 then
				w.ball("Head", 0.14, CFrame.new(0, y + 0.55, 0) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -radius), accent, M.Neon, true)
			end
		end
		w.gem("Head", 0.24, CFrame.new(0, y, front - 0.1), accent)
		return
	end
	local material = if style == "cap" then M.Leather else M.Metal
	-- calota + aba
	w.add("Head", Vector3.new(h.X + 0.24, h.Y * 0.62, h.Z + 0.24), CFrame.new(0, h.Y * 0.24, 0.02), main, material)
	w.ball("Head", h.X + 0.22, CFrame.new(0, h.Y * 0.42, 0.02), main, material)
	w.add("Head", Vector3.new(h.X + 0.3, 0.16, h.Z + 0.3), CFrame.new(0, -0.02, 0.02), trim, material)
	if style == "cap" then
		for _, sign in { -1, 1 } do
			w.add("Head", Vector3.new(0.12, h.Y * 0.55, h.Z * 0.45), CFrame.new(sign * (h.X / 2 + 0.1), -h.Y * 0.2, 0.08), main, M.Leather)
		end
		w.add("Head", Vector3.new(0.12, 0.5, 0.12), CFrame.new(0, h.Y / 2 + 0.35, 0.1) * CFrame.Angles(math.rad(-25), 0, 0), trim, M.Leather)
		return
	end
	-- protetores: nariz, bochechas e nuca; crista em cima
	w.add("Head", Vector3.new(0.16, h.Y * 0.5, 0.12), CFrame.new(0, -h.Y * 0.18, front - 0.12), main, M.Metal)
	for _, sign in { -1, 1 } do
		w.add("Head", Vector3.new(0.12, h.Y * 0.6, h.Z * 0.62), CFrame.new(sign * (h.X / 2 + 0.11), -h.Y * 0.22, 0.04), main, M.Metal)
	end
	w.add("Head", Vector3.new(h.X + 0.1, h.Y * 0.5, 0.14), CFrame.new(0, -h.Y * 0.15, h.Z / 2 + 0.1), main:Lerp(Color3.new(0, 0, 0), 0.1), M.Metal)
	w.add("Head", Vector3.new(0.16, 0.3, h.Z + 0.3), CFrame.new(0, h.Y / 2 + 0.38, 0.02), trim, M.Metal)
	if look.glow then
		w.add("Head", Vector3.new(h.X + 0.32, 0.06, 0.06), CFrame.new(0, 0.06, front - 0.16), accent, M.Neon, { glow = true })
	else
		w.gem("Head", 0.2, CFrame.new(0, 0.08, front - 0.16))
	end
	if style == "horned" then
		for _, sign in { -1, 1 } do
			for k = 0, 2 do
				w.add("Head", Vector3.new(0.24 - k * 0.05, 0.45, 0.24 - k * 0.05), CFrame.new(sign * (h.X / 2 + 0.1 + k * 0.2), h.Y * 0.3 + k * 0.35, 0.05) * CFrame.Angles(0, 0, math.rad(sign * (-40 + k * 22))), if k == 2 then accent else trim, if k == 2 and look.glow then M.Neon else M.Metal, { glow = k == 2 })
			end
		end
	end
end

function worn.boots(w, look, rarity, sizes)
	local main, trim = look.main or C.leather, look.trim or C.darkLeather
	local accent = glowColor(look, rarity)
	local style = look.style or "leather"
	for side, sign in SIDES do
		local legName, footName = side .. "LowerLeg", side .. "Foot"
		local l, f = sizes[legName], sizes[footName]
		if style == "sandal" then
			if f then
				w.add(footName, Vector3.new(f.X + 0.1, 0.12, f.Z + 0.2), CFrame.new(0, -f.Y / 2 - 0.02, -0.05), main, M.Wood)
				for k = 0, 1 do
					w.add(footName, Vector3.new(f.X + 0.08, 0.08, 0.12), CFrame.new(0, 0, -f.Z * 0.25 + k * f.Z * 0.4), trim, M.Leather)
				end
			end
			if l then
				for k = 0, 2 do
					w.add(legName, Vector3.new(l.X + 0.06, 0.08, l.Z + 0.06), CFrame.new(0, -l.Y * 0.4 + k * 0.25, 0) * CFrame.Angles(0, 0, math.rad(if k % 2 == 0 then 12 else -12)), trim, M.Leather)
				end
			end
		else
			local material = if style == "iron" or style == "dragon" then M.Metal else M.Leather
			if l then
				w.add(legName, l + Vector3.new(0.14, -0.15, 0.14), CFrame.new(0, -0.08, 0), main, material)
				w.add(legName, Vector3.new(l.X + 0.26, 0.2, l.Z + 0.26), CFrame.new(0, l.Y / 2 - 0.2, 0), trim, material)
				if style == "iron" or style == "dragon" then
					w.add(legName, Vector3.new(l.X * 0.8, l.Y * 0.75, 0.14), CFrame.new(0, -0.05, -(l.Z / 2 + 0.12)), main:Lerp(Color3.new(1, 1, 1), 0.14), M.Metal)
					w.ball(legName, l.X * 0.7, CFrame.new(0, l.Y / 2 - 0.05, -(l.Z / 2 + 0.05)), main:Lerp(Color3.new(1, 1, 1), 0.1), M.Metal)
					if look.glow then
						w.add(legName, Vector3.new(0.08, l.Y * 0.6, 0.06), CFrame.new(0, -0.05, -(l.Z / 2 + 0.2)), accent, M.Neon, { glow = true })
					end
					if style == "dragon" then
						for k = 0, 2 do
							w.wedge(legName, Vector3.new(0.12, 0.3, 0.26), CFrame.new(0, l.Y * 0.3 - k * l.Y * 0.28, l.Z / 2 + 0.16), trim, M.Metal)
						end
					end
				elseif style == "wing" then
					for k = 0, 1 do
						w.wedge(legName, Vector3.new(0.08, 0.55 - k * 0.15, 0.5), CFrame.new(sign * (l.X / 2 + 0.12), l.Y * 0.1 + k * 0.22, 0.15) * CFrame.Angles(0, 0, math.rad(sign * 25)), if look.glow then accent else trim, if look.glow then M.Neon else M.Metal, k == 0)
					end
				else
					for k = 0, 1 do
						w.add(legName, Vector3.new(l.X + 0.2, 0.09, l.Z + 0.2), CFrame.new(0, -l.Y * 0.1 - k * l.Y * 0.3, 0), C.darkLeather, M.Leather)
						w.add(legName, Vector3.new(0.12, 0.12, 0.06), CFrame.new(sign * l.X * 0.2, -l.Y * 0.1 - k * l.Y * 0.3, -(l.Z / 2 + 0.11)), C.iron, M.Metal)
					end
				end
			end
			if f then
				w.add(footName, f + Vector3.new(0.14, 0.1, 0.16), CFrame.new(0, 0.02, -0.02), main:Lerp(Color3.new(0, 0, 0), 0.12), material)
				w.add(footName, Vector3.new(f.X + 0.16, 0.1, f.Z + 0.2), CFrame.new(0, -f.Y / 2 - 0.02, -0.02), C.darkLeather, M.Leather)
				if style == "iron" or style == "dragon" then
					for k = 0, 1 do
						w.add(footName, Vector3.new(f.X + 0.18, 0.08, f.Z * 0.2), CFrame.new(0, f.Y / 2, -f.Z * 0.15 - k * f.Z * 0.25), trim, M.Metal)
					end
				end
			end
		end
	end
end

function worn.amulet(w, look, rarity, sizes)
	local t = sizes.UpperTorso
	if not t then
		return
	end
	local main = look.main or C.gold
	local front = -(t.Z / 2) - 0.12
	-- corrente em V e o pingente no peito
	for _, sign in { -1, 1 } do
		w.add("UpperTorso", Vector3.new(0.06, t.Y * 0.5, 0.06), CFrame.new(sign * t.X * 0.12, t.Y * 0.25, front) * CFrame.Angles(0, 0, math.rad(sign * 25)), look.chain or main, M.Metal)
	end
	local cf = CFrame.new(0, -t.Y * 0.02, front - 0.02)
	w.add("UpperTorso", Vector3.new(0.08, 0.42, 0.42), cf * CFrame.Angles(0, math.rad(90), 0), main, M.Metal, { shape = "Cylinder" })
	w.gem("UpperTorso", 0.24, cf * CFrame.new(0, 0, -0.05), look.gem)
end

function worn.ring(w, look, rarity, sizes)
	local hand = sizes.RightHand
	if not hand then
		return
	end
	w.add("RightHand", Vector3.new(hand.X + 0.06, 0.1, hand.Z + 0.06), CFrame.new(0, -hand.Y * 0.15, 0), look.band or C.gold, M.Metal)
	w.gem("RightHand", 0.16, CFrame.new(0, -hand.Y * 0.15, -(hand.Z / 2 + 0.06)), look.gem)
end

-- Peças do item vestido. sizes = { [nome da parte do corpo] = Vector3 }
function ItemModels.worn(baseId, rarityId, sizes)
	local base = Items.Bases[baseId]
	local rarity = Rarities.ById[rarityId] or Rarities.List[1]
	local builder = base and worn[base.slot]
	if not builder then
		return {}
	end
	local w = wornList(sizes, rarity)
	builder(w, ItemModels.look(baseId), rarity, sizes)
	return w.list
end

-- ===================== API =====================

-- visual padrão de uma base sem entrada em Looks (por tipo e tier)
local function defaultLook(base)
	local tier = base.tier or 1
	local metal = if tier >= 3 then C.silver elseif tier == 2 then C.steel else C.iron
	if base.slot == "weapon" then
		return { style = "cross", metal = metal, tip = "leaf", top = "orb", limb = C.wood }
	elseif base.slot == "armor" then
		return { style = if tier >= 2 then "plate" else "leather", main = metal }
	elseif base.slot == "helmet" or base.slot == "boots" then
		return { style = if tier >= 2 then "iron" else "leather", main = metal }
	end
	return { main = C.gold, band = C.gold }
end

function ItemModels.look(baseId)
	local base = Items.Bases[baseId]
	return L[baseId] or (base and defaultLook(base)) or {}
end

-- Monta o modelo. Retorna model, info = { handle, tip, start, glowing } (tip/start: rastro das armas)
function ItemModels.build(baseId, rarityId, options)
	options = options or {}
	local base = Items.Bases[baseId]
	local rarity = Rarities.ById[rarityId] or Rarities.List[1]
	local model = Instance.new("Model")
	model.Name = "Item"
	local b = newBuilder(model, rarity)
	b.held = options.held == true -- na mão: sem a segunda adaga das duplas
	local look = ItemModels.look(baseId)
	local tip, start = 1, 0
	local handle
	if base and base.slot == "weapon" then
		handle = b.add(Vector3.new(0.3, 1.1, 0.3), CFrame.new(), C.darkLeather, M.Wood)
		handle.Name = "Cabo"
		local builder = weapon[base.weaponType] or weapon.sword
		tip, start = builder(b, look, rarity)
	elseif base then
		local builder = gear[base.slot]
		if builder then
			builder(b, look, rarity)
		end
		handle = model:FindFirstChildWhichIsA("BasePart")
	end
	-- Secreto: partes brilhantes em arco-íris; Único: aura de pontos em volta (só onde há partículas)
	if rarity.rainbow then
		for _, p in b.glowing do
			CollectionService:AddTag(p, "Rainbow")
		end
	end
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") then
			p.Anchored = options.anchored == true
		end
	end
	if handle then
		model.PrimaryPart = handle
	end
	return model, { handle = handle, tip = tip, start = start, glowing = b.glowing, look = look }
end

-- Rotação para mostrar o item de frente (ícones, chão, cena do baú)
function ItemModels.displayRotation(baseId)
	local base = Items.Bases[baseId]
	if not base then
		return CFrame.identity
	end
	if base.slot == "weapon" then
		if base.weaponType == "bow" then
			return CFrame.Angles(0, math.rad(-20), math.rad(-30))
		end
		return CFrame.Angles(0, math.rad(-15), math.rad(-45))
	end
	return CFrame.Angles(math.rad(8), math.rad(-25), 0)
end

return ItemModels
