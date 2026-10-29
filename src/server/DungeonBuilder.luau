-- Geometria das masmorras: salas temáticas com portas em arco, corredores com grade, teto com estalactites
-- ou abóbadas, tochas e decoração por tipo de sala. Só monta peças; a lógica (inimigos, grades, baús)
-- fica no DungeonService. Convenções: o piso de toda sala fica em floorY (centro.Y); paredes ficam por
-- fora do retângulo do piso; nada do enfeite fica no meio da sala (lugar da luta).
local Props = require(script.Parent.WorldGen.Props)

local DungeonBuilder = {}

local M = Enum.Material

local WALL_HEIGHT = 30
local OPEN_W = 16 -- largura do vão das portas
local OPEN_STRAIGHT = 10 -- altura reta do vão antes do arco
local OPEN_H = OPEN_STRAIGHT + OPEN_W / 2 -- topo do arco
DungeonBuilder.WallHeight = WALL_HEIGHT
DungeonBuilder.OpenWidth = OPEN_W
DungeonBuilder.OpenHeight = OPEN_H

-- Temas: cores, materiais, luz das tochas e os tipos de sala sorteados
local THEMES = {
	caverna = {
		floor = Color3.fromRGB(92, 78, 64), floorAlt = Color3.fromRGB(78, 66, 54), floorMaterial = M.Slate,
		wall = Color3.fromRGB(104, 90, 76), wallAlt = Color3.fromRGB(86, 74, 62), wallMaterial = M.Rock,
		trim = Color3.fromRGB(70, 58, 48), ceiling = Color3.fromRGB(60, 52, 44),
		accent = Color3.fromRGB(255, 160, 70), light = Color3.fromRGB(255, 170, 90), banner = Color3.fromRGB(120, 140, 60),
		kinds = { "mina", "cristais", "acampamento", "fungos" },
	},
	cripta = {
		floor = Color3.fromRGB(86, 84, 96), floorAlt = Color3.fromRGB(62, 60, 72), floorMaterial = M.Slate,
		wall = Color3.fromRGB(96, 94, 108), wallAlt = Color3.fromRGB(78, 76, 90), wallMaterial = M.Brick,
		trim = Color3.fromRGB(60, 58, 70), ceiling = Color3.fromRGB(48, 46, 56),
		accent = Color3.fromRGB(150, 130, 255), light = Color3.fromRGB(255, 190, 120), banner = Color3.fromRGB(90, 40, 110),
		kinds = { "salao", "ossuario", "capela", "catacumba" },
	},
	abismo = {
		floor = Color3.fromRGB(44, 38, 40), floorAlt = Color3.fromRGB(32, 28, 30), floorMaterial = M.Basalt,
		wall = Color3.fromRGB(54, 46, 46), wallAlt = Color3.fromRGB(40, 34, 34), wallMaterial = M.Basalt,
		trim = Color3.fromRGB(28, 24, 24), ceiling = Color3.fromRGB(26, 22, 22),
		accent = Color3.fromRGB(255, 100, 30), light = Color3.fromRGB(255, 130, 60), banner = Color3.fromRGB(150, 40, 20),
		kinds = { "lago", "basalto", "forja", "obsidiana" },
	},
}
DungeonBuilder.Themes = THEMES

local function block(parent, name, size, cframe, color, material, extra)
	local props = { Name = name, Size = size, CFrame = cframe, Color = color, Material = material }
	if extra then
		for key, value in extra do
			props[key] = value
		end
	end
	return Props.part(parent, props)
end
DungeonBuilder.block = block

local function ball(parent, name, diameter, cframe, color, material, extra)
	local props = extra or {}
	props.Shape = Enum.PartType.Ball
	return block(parent, name, Vector3.one * diameter, cframe, color, material, props)
end

local function wedge(parent, name, size, cframe, color, material, extra)
	local props = extra or {}
	props.Shape = Enum.PartType.Wedge
	return block(parent, name, size, cframe, color, material, props)
end

-- tocha de parede: suporte, cabo e chama com luz (cf: -Z aponta para dentro da sala)
function DungeonBuilder.torch(parent, cf, theme)
	block(parent, "SuporteTocha", Vector3.new(0.5, 0.5, 1.3), cf * CFrame.new(0, 0, -0.65), Color3.fromRGB(40, 40, 45), M.Metal)
	block(parent, "Tocha", Vector3.new(0.55, 1.7, 0.55), cf * CFrame.new(0, 0.6, -1.25) * CFrame.Angles(math.rad(-15), 0, 0), Color3.fromRGB(90, 60, 35), M.Wood)
	local flame = Props.fire(parent, (cf * CFrame.new(0, 1.35, -1.45)).Position, 0.6)
	local light = flame:FindFirstChildOfClass("PointLight")
	if light then
		light.Color = theme.light
		light.Range = 24
		light.Brightness = 1.6
		light.Shadows = false
	end
end

-- ===================== PAREDES COM ARCO =====================

-- Parede de comprimento "length" (eixo X local), espessura 2 em Z; o -Z local aponta para dentro da sala.
-- Com vão: dois lados, verga acima do arco, pedras do arco (aduelas), cantos fechados e colunas no vão.
local function wall(parent, theme, cf, length, open)
	local dark = theme.trim
	if not open then
		block(parent, "Parede", Vector3.new(length, WALL_HEIGHT, 2), cf * CFrame.new(0, WALL_HEIGHT / 2, 0), theme.wall, theme.wallMaterial)
	else
		local side = (length - OPEN_W) / 2
		for _, s in { -1, 1 } do
			block(parent, "Parede", Vector3.new(side, WALL_HEIGHT, 2), cf * CFrame.new(s * (OPEN_W / 2 + side / 2), WALL_HEIGHT / 2, 0), theme.wall, theme.wallMaterial)
			-- colunas do vão, saindo um pouco das duas faces
			block(parent, "ColunaPorta", Vector3.new(1.6, OPEN_STRAIGHT, 3), cf * CFrame.new(s * (OPEN_W / 2 - 0.8), OPEN_STRAIGHT / 2, 0), dark, M.Slate)
			block(parent, "Capitel", Vector3.new(2.2, 0.8, 3.4), cf * CFrame.new(s * (OPEN_W / 2 - 0.8), OPEN_STRAIGHT + 0.4, 0), dark:Lerp(Color3.new(1, 1, 1), 0.08), M.Slate)
			-- canto entre o arco e a verga
			block(parent, "Canto", Vector3.new(3.2, 3.2, 2), cf * CFrame.new(s * (OPEN_W / 2 - 1.6), OPEN_H - 1.6, 0), theme.wall, theme.wallMaterial)
		end
		local above = WALL_HEIGHT - OPEN_H
		block(parent, "Verga", Vector3.new(OPEN_W, above, 2), cf * CFrame.new(0, OPEN_H + above / 2, 0), theme.wall, theme.wallMaterial)
		-- aduelas do arco (semicírculo) e pedra-chave
		local radius = OPEN_W / 2
		local count = 9
		for i = 0, count - 1 do
			local angle = math.pi * (i + 0.5) / count
			local x, y = math.cos(angle) * (radius - 0.6), OPEN_STRAIGHT + math.sin(angle) * (radius - 0.6)
			block(parent, "Aduela", Vector3.new(2.0, 1.6, 2.8), cf * CFrame.new(x, y, 0) * CFrame.Angles(0, 0, angle - math.pi / 2), if i % 2 == 0 then dark else dark:Lerp(Color3.new(1, 1, 1), 0.1), M.Slate)
		end
		block(parent, "PedraChave", Vector3.new(1.6, 2.2, 3.2), cf * CFrame.new(0, OPEN_H - 0.6, 0), theme.accent:Lerp(dark, 0.6), M.Slate)
	end
	-- rodapé (sem atravessar o vão) e cornija na face de dentro
	if open then
		local side = (length - OPEN_W) / 2 - 1.6
		for _, s in { -1, 1 } do
			block(parent, "Rodape", Vector3.new(side, 1.4, 0.6), cf * CFrame.new(s * (OPEN_W / 2 + 1.6 + side / 2), 0.7, -1.3), dark, M.Slate)
		end
	else
		block(parent, "Rodape", Vector3.new(length, 1.4, 0.6), cf * CFrame.new(0, 0.7, -1.3), dark, M.Slate)
	end
	block(parent, "Cornija", Vector3.new(length, 1, 0.8), cf * CFrame.new(0, WALL_HEIGHT - 0.5, -1.4), dark, M.Slate)
end

-- ===================== PISO E TETO =====================

local function buildFloor(parent, theme, themeId, cf, width, depth, rng)
	if themeId == "cripta" then
		local nx, nz = math.max(1, math.floor(width / 8)), math.max(1, math.floor(depth / 8))
		for i = 0, nx - 1 do
			for j = 0, nz - 1 do
				local x = -width / 2 + (i + 0.5) * (width / nx)
				local z = -depth / 2 + (j + 0.5) * (depth / nz)
				block(parent, "Ladrilho", Vector3.new(width / nx, 2, depth / nz), cf * CFrame.new(x, -1, z), if (i + j) % 2 == 0 then theme.floor else theme.floorAlt, theme.floorMaterial)
			end
		end
	else
		block(parent, "Piso", Vector3.new(width, 2, depth), cf * CFrame.new(0, -1, 0), theme.floor, theme.floorMaterial)
		-- manchas de pedra e terra (finas, por cima)
		for _ = 1, math.floor(width * depth / 260) do
			local w = rng:NextNumber(4, 10)
			block(parent, "Mancha", Vector3.new(w, 0.08, w * rng:NextNumber(0.6, 1.2)), cf * CFrame.new(rng:NextNumber(-width / 2 + w, width / 2 - w), 0.04, rng:NextNumber(-depth / 2 + w, depth / 2 - w)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), if rng:NextNumber() < 0.5 then theme.floorAlt else theme.floor:Lerp(Color3.new(1, 1, 1), 0.06), theme.floorMaterial, { CanCollide = false })
		end
	end
end

local function buildCeiling(parent, theme, themeId, cf, width, depth, rng)
	block(parent, "Teto", Vector3.new(width + 4, 2, depth + 4), cf * CFrame.new(0, WALL_HEIGHT + 1, 0), theme.ceiling, theme.wallMaterial)
	if themeId == "cripta" then
		-- abóbada: nervuras atravessando o teto, com mãos-francesas de pedra nas pontas
		local ribs = math.floor(depth / 14)
		for i = 1, ribs do
			local z = -depth / 2 + i * depth / (ribs + 1)
			block(parent, "Nervura", Vector3.new(width, 1.4, 1.4), cf * CFrame.new(0, WALL_HEIGHT - 0.7, z), theme.trim, M.Slate)
			for _, s in { -1, 1 } do
				wedge(parent, "Misula", Vector3.new(1.4, 4, 4), cf * CFrame.new(s * (width / 2 - 2), WALL_HEIGHT - 3.4, z) * CFrame.Angles(0, math.rad(s * -90), math.rad(180)), theme.trim, M.Slate)
			end
		end
	else
		-- estalactites penduradas
		for _ = 1, math.floor(width * depth / 160) do
			local length = rng:NextNumber(2, 6)
			local x, z = rng:NextNumber(-width / 2 + 2, width / 2 - 2), rng:NextNumber(-depth / 2 + 2, depth / 2 - 2)
			local p = wedge(parent, "Estalactite", Vector3.new(rng:NextNumber(0.8, 1.8), length, rng:NextNumber(0.8, 1.8)), cf * CFrame.new(x, WALL_HEIGHT - length / 2, z) * CFrame.Angles(math.rad(180), rng:NextNumber(0, 3), 0), theme.wallAlt, theme.wallMaterial, { CanCollide = false })
			local _ = p
		end
		for i = 1, math.floor(depth / 18) do
			block(parent, "Viga", Vector3.new(width, 1.4, 1.4), cf * CFrame.new(0, WALL_HEIGHT - 0.7, -depth / 2 + i * depth / (math.floor(depth / 18) + 1)), if themeId == "abismo" then theme.trim else Color3.fromRGB(80, 56, 36), if themeId == "abismo" then M.Basalt else M.Wood)
		end
	end
end

-- ===================== DECORAÇÃO POR TIPO DE SALA =====================

local decor = {}

-- pontos encostados nas paredes (sem cair nos vãos das portas)
local function wallSpots(cf, width, depth, openings, inset, step)
	local spots = {}
	local function blocked(side, along)
		return openings[side] and math.abs(along) < OPEN_W / 2 + 4
	end
	for _, side in { "west", "east" } do
		local sign = if side == "east" then 1 else -1
		for z = -depth / 2 + step / 2, depth / 2 - step / 2, step do
			if not blocked(side, z) then
				table.insert(spots, cf * CFrame.new(sign * (width / 2 - inset), 0, z) * CFrame.Angles(0, math.rad(sign * 90), 0))
			end
		end
	end
	for _, side in { "north", "south" } do
		local sign = if side == "south" then 1 else -1
		for x = -width / 2 + step / 2, width / 2 - step / 2, step do
			if not blocked(side, x) then
				table.insert(spots, cf * CFrame.new(x, 0, sign * (depth / 2 - inset)) * CFrame.Angles(0, if sign > 0 then 0 else math.pi, 0))
			end
		end
	end
	-- -Z de cada ponto aponta para o centro da sala
	return spots
end

local function pick(list, rng)
	return list[rng:NextInteger(1, #list)]
end

function decor.mina(parent, theme, cf, width, depth, openings, rng)
	-- escoras de mina com lampiões, trilho no chão, carrinhos com minério e veios nas paredes
	for _, spot in wallSpots(cf, width, depth, openings, 1.2, 14) do
		block(parent, "Escora", Vector3.new(1.3, WALL_HEIGHT - 2, 1.3), spot * CFrame.new(0, (WALL_HEIGHT - 2) / 2, 0), Color3.fromRGB(95, 66, 40), M.Wood)
		local lamp = block(parent, "Lampiao", Vector3.new(0.7, 0.9, 0.7), spot * CFrame.new(0, 9, -1.3), Color3.fromRGB(255, 200, 120), M.Neon, { CanCollide = false })
		block(parent, "Gancho", Vector3.new(0.15, 0.15, 1.2), spot * CFrame.new(0, 9.7, -0.7), Color3.fromRGB(40, 40, 45), M.Metal)
		Props.light(lamp, theme.light, 16, 1.2)
	end
	for _, s in { -1, 1 } do
		block(parent, "Trilho", Vector3.new(0.3, 0.2, depth), cf * CFrame.new(s * 1.6 - width / 2 + 7, 0.1, 0), Color3.fromRGB(70, 70, 78), M.Metal, { CanCollide = false })
	end
	for i = 0, math.floor(depth / 3) do
		block(parent, "Dormente", Vector3.new(4.2, 0.15, 0.8), cf * CFrame.new(-width / 2 + 7, 0.05, -depth / 2 + i * 3), Color3.fromRGB(80, 56, 36), M.Wood, { CanCollide = false })
	end
	for k = 0, 1 do
		local cart = cf * CFrame.new(-width / 2 + 7, 0, -depth / 4 + k * depth / 2)
		block(parent, "Carrinho", Vector3.new(3.4, 2, 4.4), cart * CFrame.new(0, 1.6, 0), Color3.fromRGB(80, 70, 60), M.Metal)
		for _, s in { -1, 1 } do
			for _, z in { -1.4, 1.4 } do
				block(parent, "Roda", Vector3.new(0.3, 1.2, 1.2), cart * CFrame.new(s * 1.75, 0.6, z) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(40, 40, 45), M.Metal, { Shape = Enum.PartType.Cylinder })
			end
		end
		for _ = 1, 5 do
			ball(parent, "Minerio", rng:NextNumber(0.8, 1.3), cart * CFrame.new(rng:NextNumber(-1.2, 1.2), 2.8, rng:NextNumber(-1.6, 1.6)), pick({ Color3.fromRGB(190, 120, 60), Color3.fromRGB(150, 150, 165), Color3.fromRGB(110, 200, 255) }, rng), M.Slate)
		end
	end
	for _ = 1, 6 do
		local spot = pick(wallSpots(cf, width, depth, openings, 0.3, 10), rng)
		block(parent, "Veio", Vector3.new(rng:NextNumber(1.5, 3), rng:NextNumber(0.8, 1.6), 0.4), spot * CFrame.new(0, rng:NextNumber(3, 10), 0.1) * CFrame.Angles(0, 0, rng:NextNumber(-0.6, 0.6)), pick({ Color3.fromRGB(200, 130, 60), Color3.fromRGB(110, 200, 255) }, rng), M.Neon)
	end
end

function decor.cristais(parent, theme, cf, width, depth, openings, rng)
	-- aglomerados de cristal gigantes nos cantos, poça brilhante e estalagmites
	for _, corner in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		local base = cf * CFrame.new(corner[1] * (width / 2 - 6), 0, corner[2] * (depth / 2 - 6))
		local color = pick({ Color3.fromRGB(110, 210, 255), Color3.fromRGB(200, 120, 255), Color3.fromRGB(120, 255, 200) }, rng)
		for k = 0, 4 do
			local height = rng:NextNumber(4, 11)
			local crystal = block(parent, "Cristal", Vector3.new(rng:NextNumber(1.2, 2.4), height, rng:NextNumber(1.2, 2.4)), base * CFrame.new(rng:NextNumber(-2.5, 2.5), height / 2 - 0.5, rng:NextNumber(-2.5, 2.5)) * CFrame.Angles(rng:NextNumber(-0.35, 0.35), rng:NextNumber(0, 3), rng:NextNumber(-0.35, 0.35)), color, M.Neon, { Transparency = 0.15 })
			if k == 0 then
				Props.light(crystal, color, 24, 1.8)
			end
		end
	end
	local pool = cf * CFrame.new(rng:NextNumber(-width / 4, width / 4), 0.04, depth / 2 - 10)
	block(parent, "Poca", Vector3.new(0.08, 9, 9), pool * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(60, 140, 200), M.Glass, { Shape = Enum.PartType.Cylinder, Transparency = 0.25, CanCollide = false })
	for _ = 1, 8 do
		local spot = pick(wallSpots(cf, width, depth, openings, rng:NextNumber(2, 5), 8), rng)
		local height = rng:NextNumber(2, 5)
		wedge(parent, "Estalagmite", Vector3.new(1.4, height, 1.4), spot * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), theme.wallAlt, theme.wallMaterial)
	end
end

function decor.acampamento(parent, theme, cf, width, depth, openings, rng)
	-- tendas, fogueira, caixotes, estandartes e um suporte de armas dos goblins
	local spots = wallSpots(cf, width, depth, openings, 6, 16)
	for i = 1, math.min(2, #spots) do
		Props.tent(parent, spots[i] * CFrame.Angles(0, math.pi, 0), pick({ Color3.fromRGB(120, 90, 60), Color3.fromRGB(90, 110, 60) }, rng))
	end
	local fire = cf * CFrame.new(width / 2 - 10, 0, -depth / 2 + 10)
	for i = 0, 7 do
		ball(parent, "PedraFogueira", 0.9, fire * CFrame.Angles(0, i * math.pi / 4, 0) * CFrame.new(0, 0.3, -1.6), theme.wallAlt, M.Slate)
	end
	Props.fire(parent, (fire * CFrame.new(0, 0.2, 0)).Position, 1.2)
	for i = 1, #spots do
		if i > 2 and rng:NextNumber() < 0.5 then
			Props.crate(parent, spots[i] * CFrame.new(0, 0, 2), rng:NextNumber(1.8, 2.6))
			if rng:NextNumber() < 0.5 then
				Props.barrel(parent, spots[i] * CFrame.new(2.6, 0, 2), 0.9)
			end
		end
	end
	for _, spot in wallSpots(cf, width, depth, openings, 0.3, 20) do
		Props.banner(parent, spot * CFrame.new(0, WALL_HEIGHT - 6, -0.2), theme.banner)
	end
end

function decor.fungos(parent, theme, cf, width, depth, openings, rng)
	-- cogumelos gigantes que brilham, tufos pequenos e musgo no chão
	for _, spot in wallSpots(cf, width, depth, openings, 4, 11) do
		if rng:NextNumber() < 0.7 then
			local height = rng:NextNumber(4, 9)
			local color = pick({ Color3.fromRGB(90, 160, 255), Color3.fromRGB(190, 90, 255), Color3.fromRGB(80, 255, 170) }, rng)
			block(parent, "Talo", Vector3.new(height, 1.2, 1.2), spot * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(225, 215, 195), M.SmoothPlastic, { Shape = Enum.PartType.Cylinder })
			local cap = block(parent, "Chapeu", Vector3.new(1.4, height * 0.75, height * 0.75), spot * CFrame.new(0, height + 0.4, 0) * CFrame.Angles(0, 0, math.rad(90)), color, M.Neon, { Shape = Enum.PartType.Cylinder })
			Props.light(cap, color, 18, 1.4)
			for _ = 1, 3 do
				ball(parent, "Cogumelo", rng:NextNumber(0.6, 1.1), spot * CFrame.new(rng:NextNumber(-3, 3), 0.3, rng:NextNumber(-3, 0)), color, M.Neon)
			end
		end
	end
	for _ = 1, 10 do
		block(parent, "Musgo", Vector3.new(rng:NextNumber(3, 7), 0.1, rng:NextNumber(3, 7)), cf * CFrame.new(rng:NextNumber(-width / 2 + 4, width / 2 - 4), 0.05, rng:NextNumber(-depth / 2 + 4, depth / 2 - 4)), Color3.fromRGB(60, 90, 50), M.Grass, { CanCollide = false })
	end
end

local function chandelier(parent, theme, cf)
	block(parent, "Corrente", Vector3.new(0.2, 6, 0.2), cf * CFrame.new(0, 3, 0), Color3.fromRGB(40, 40, 45), M.Metal)
	for i = 0, 11 do
		local angle = i / 12 * math.pi * 2
		block(parent, "Aro", Vector3.new(1.3, 0.25, 0.25), cf * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -2.4), Color3.fromRGB(50, 45, 40), M.Metal)
		if i % 2 == 0 then
			block(parent, "Vela", Vector3.new(0.3, 0.7, 0.3), cf * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0.45, -2.4), Color3.fromRGB(240, 235, 210), M.SmoothPlastic, { CanCollide = false })
			block(parent, "Chama", Vector3.new(0.2, 0.35, 0.2), cf * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0.95, -2.4), Color3.fromRGB(255, 200, 100), M.Neon, { CanCollide = false })
		end
	end
	local glow = block(parent, "LuzLustre", Vector3.one * 0.4, cf * CFrame.new(0, 0.5, 0), Color3.fromRGB(255, 210, 140), M.Neon, { CanCollide = false, Transparency = 1 })
	Props.light(glow, theme.light, 30, 1.4, true)
end

function decor.salao(parent, theme, cf, width, depth, openings, rng)
	-- duas fileiras de pilares, sarcófagos, tapete no meio e lustres
	local rows = math.floor(depth / 18)
	for i = 1, rows do
		local z = -depth / 2 + i * depth / (rows + 1)
		for _, s in { -1, 1 } do
			local base = cf * CFrame.new(s * (width / 2 - 8), 0, z)
			block(parent, "BasePilar", Vector3.new(3.8, 1.2, 3.8), base * CFrame.new(0, 0.6, 0), theme.trim, M.Slate)
			Props.column(parent, base * CFrame.new(0, 1.2, 0), WALL_HEIGHT - 2.4, 2.8, theme.wall:Lerp(Color3.new(1, 1, 1), 0.12), M.Marble)
			block(parent, "Capitel", Vector3.new(3.8, 1.2, 3.8), base * CFrame.new(0, WALL_HEIGHT - 0.6, 0), theme.trim, M.Slate)
		end
	end
	for _, spot in wallSpots(cf, width, depth, openings, 2.4, 16) do
		if rng:NextNumber() < 0.55 then
			block(parent, "Sarcofago", Vector3.new(6.5, 2.2, 3), spot * CFrame.new(0, 1.1, 0), Color3.fromRGB(120, 115, 128), M.Slate)
			block(parent, "Tampa", Vector3.new(6.8, 0.55, 3.3), spot * CFrame.new(0, 2.5, 0) * CFrame.Angles(0, if rng:NextNumber() < 0.3 then 0.2 else 0, 0), Color3.fromRGB(145, 140, 150), M.Marble)
			block(parent, "Figura", Vector3.new(4, 0.4, 1.4), spot * CFrame.new(0, 2.95, 0), Color3.fromRGB(160, 155, 165), M.Marble)
		end
	end
	block(parent, "Tapete", Vector3.new(7, 0.08, depth - 8), cf * CFrame.new(0, 0.04, 0), theme.banner, M.Fabric, { CanCollide = false })
	block(parent, "BordaTapete", Vector3.new(7.6, 0.06, depth - 7.4), cf * CFrame.new(0, 0.02, 0), Color3.fromRGB(200, 170, 90), M.Fabric, { CanCollide = false })
	for i = 1, 2 do
		chandelier(parent, theme, cf * CFrame.new(0, WALL_HEIGHT - 9, -depth / 2 + i * depth / 3))
	end
end

function decor.ossuario(parent, theme, cf, width, depth, openings, rng)
	-- paredes cheias de nichos com crânios, pilhas de ossos e velas no chão
	for _, spot in wallSpots(cf, width, depth, openings, 0.15, 5) do
		for row = 0, 3 do
			local niche = spot * CFrame.new(0, 3 + row * 4, 0)
			block(parent, "Nicho", Vector3.new(3.6, 2.4, 0.3), niche * CFrame.new(0, 0, 0.05), Color3.fromRGB(25, 22, 28), M.SmoothPlastic)
			block(parent, "Prateleira", Vector3.new(4.2, 0.35, 1.2), niche * CFrame.new(0, -1.35, -0.4), theme.trim, M.Slate)
			for k = -1, 1 do
				if rng:NextNumber() < 0.75 then
					ball(parent, "Cranio", 0.8, niche * CFrame.new(k * 1.1, -0.75, -0.35), Color3.fromRGB(230, 222, 200), M.SmoothPlastic)
				end
			end
		end
	end
	for _ = 1, 6 do
		local spot = cf * CFrame.new(rng:NextNumber(-width / 2 + 5, width / 2 - 5), 0, rng:NextNumber(-depth / 2 + 5, depth / 2 - 5))
		if (spot.Position - cf.Position).Magnitude > 14 then
			for _ = 1, 7 do
				block(parent, "Osso", Vector3.new(0.35, 0.35, rng:NextNumber(1.2, 2.2)), spot * CFrame.new(rng:NextNumber(-1, 1), rng:NextNumber(0.2, 0.8), rng:NextNumber(-1, 1)) * CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 6), 0), Color3.fromRGB(230, 222, 200), M.SmoothPlastic, { CanCollide = false })
			end
			for k = 0, 2 do
				block(parent, "Vela", Vector3.new(0.4, 1.2 - k * 0.3, 0.4), spot * CFrame.new(1.8, 0.6, k * 0.6), Color3.fromRGB(240, 235, 210), M.SmoothPlastic, { CanCollide = false })
			end
			local flame = block(parent, "Chama", Vector3.new(0.25, 0.4, 0.25), spot * CFrame.new(1.8, 1.4, 0), Color3.fromRGB(255, 200, 100), M.Neon, { CanCollide = false })
			Props.light(flame, theme.light, 12, 1)
		end
	end
end

function decor.capela(parent, theme, cf, width, depth, openings, rng)
	-- bancos em fileiras, altar com velas no fundo, vitrais coloridos e estátuas
	local back = if openings.south then -1 else 1
	local altar = cf * CFrame.new(0, 0, back * (depth / 2 - 6))
	block(parent, "Altar", Vector3.new(10, 3, 3.6), altar * CFrame.new(0, 1.5, 0), Color3.fromRGB(200, 195, 205), M.Marble)
	block(parent, "Toalha", Vector3.new(10.4, 0.1, 3.8), altar * CFrame.new(0, 3.05, 0), theme.banner, M.Fabric)
	for k = -2, 2 do
		block(parent, "Vela", Vector3.new(0.4, 1.4, 0.4), altar * CFrame.new(k * 1.8, 3.8, 0), Color3.fromRGB(240, 235, 210), M.SmoothPlastic, { CanCollide = false })
		local flame = block(parent, "Chama", Vector3.new(0.25, 0.45, 0.25), altar * CFrame.new(k * 1.8, 4.75, 0), Color3.fromRGB(255, 200, 100), M.Neon, { CanCollide = false })
		if k == 0 then
			Props.light(flame, theme.light, 20, 1.6)
		end
	end
	for row = 0, math.floor(depth / 10) - 2 do
		for _, s in { -1, 1 } do
			local pew = cf * CFrame.new(s * (width / 2 - 9), 0, -back * (depth / 2 - 10) + back * row * 7)
			block(parent, "Banco", Vector3.new(9, 0.5, 2), pew * CFrame.new(0, 1.4, 0), Color3.fromRGB(70, 48, 32), M.WoodPlanks)
			block(parent, "Encosto", Vector3.new(9, 2, 0.4), pew * CFrame.new(0, 2.4, -back * 0.9), Color3.fromRGB(70, 48, 32), M.WoodPlanks)
			for _, x in { -4, 4 } do
				block(parent, "Pe", Vector3.new(0.4, 1.4, 1.6), pew * CFrame.new(x, 0.7, 0), Color3.fromRGB(55, 38, 26), M.Wood)
			end
		end
	end
	for _, spot in wallSpots(cf, width, depth, openings, 0.2, 14) do
		local glass = block(parent, "Vitral", Vector3.new(3.2, 8, 0.3), spot * CFrame.new(0, 14, 0), pick({ Color3.fromRGB(150, 60, 200), Color3.fromRGB(60, 120, 220), Color3.fromRGB(220, 80, 80), Color3.fromRGB(240, 200, 80) }, rng), M.Neon, { Transparency = 0.25 })
		block(parent, "MolduraVitral", Vector3.new(3.8, 0.4, 0.5), spot * CFrame.new(0, 18.2, -0.1), theme.trim, M.Slate)
		block(parent, "MolduraVitral", Vector3.new(3.8, 0.4, 0.5), spot * CFrame.new(0, 9.8, -0.1), theme.trim, M.Slate)
		local _ = glass
	end
	for _, s in { -1, 1 } do
		local statue = altar * CFrame.new(s * 8, 0, 0)
		block(parent, "Pedestal", Vector3.new(2.4, 1.6, 2.4), statue * CFrame.new(0, 0.8, 0), theme.trim, M.Slate)
		block(parent, "Corpo", Vector3.new(1.8, 3.6, 1.2), statue * CFrame.new(0, 3.4, 0), Color3.fromRGB(190, 185, 195), M.Marble)
		ball(parent, "Cabeca", 1.2, statue * CFrame.new(0, 5.8, 0), Color3.fromRGB(190, 185, 195), M.Marble)
		block(parent, "Asa", Vector3.new(0.3, 3, 2), statue * CFrame.new(s * 1.1, 4, 0.6) * CFrame.Angles(0, 0, math.rad(s * 20)), Color3.fromRGB(200, 195, 205), M.Marble)
	end
end

function decor.catacumba(parent, theme, cf, width, depth, openings, rng)
	-- caixões em pé nas paredes, pilares quebrados, entulho e teias
	for _, spot in wallSpots(cf, width, depth, openings, 1.4, 6) do
		if rng:NextNumber() < 0.6 then
			block(parent, "Caixao", Vector3.new(2.4, 6, 1.4), spot * CFrame.new(0, 3, 0) * CFrame.Angles(0, 0, rng:NextNumber(-0.05, 0.05)), Color3.fromRGB(70, 48, 32), M.WoodPlanks)
			block(parent, "Cruz", Vector3.new(0.3, 2.2, 0.15), spot * CFrame.new(0, 4, -0.75), Color3.fromRGB(180, 170, 140), M.Metal)
			block(parent, "Cruz", Vector3.new(1.2, 0.3, 0.15), spot * CFrame.new(0, 4.4, -0.75), Color3.fromRGB(180, 170, 140), M.Metal)
		end
	end
	for _ = 1, 4 do
		local spot = cf * CFrame.new((if rng:NextNumber() < 0.5 then -1 else 1) * (width / 2 - 8), 0, rng:NextNumber(-depth / 2 + 8, depth / 2 - 8))
		local height = rng:NextNumber(4, 12)
		Props.column(parent, spot, height, 2.6, theme.wall, M.Slate)
		for _ = 1, 4 do
			block(parent, "Entulho", Vector3.new(rng:NextNumber(0.8, 1.8), rng:NextNumber(0.6, 1.2), rng:NextNumber(0.8, 1.8)), spot * CFrame.new(rng:NextNumber(-3, 3), 0.4, rng:NextNumber(-3, 3)) * CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 3), 0), theme.wallAlt, M.Slate)
		end
	end
	for _, corner in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		block(parent, "Teia", Vector3.new(0.1, 7, 7), cf * CFrame.new(corner[1] * (width / 2 - 2.4), WALL_HEIGHT - 2.4, corner[2] * (depth / 2 - 2.4)) * CFrame.Angles(0, math.rad(corner[1] * corner[2] * 45), math.rad(45)), Color3.fromRGB(235, 235, 240), M.SmoothPlastic, { Transparency = 0.65, CanCollide = false })
	end
end

local function lavaPool(parent, cf, size)
	local lava = block(parent, "Lava", Vector3.new(0.1, size, size), cf * CFrame.new(0, 0.05, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 100, 30), M.Neon, { Shape = Enum.PartType.Cylinder, CanCollide = false })
	block(parent, "BordaLava", Vector3.new(0.3, size + 1.2, size + 1.2), cf * CFrame.new(0, 0.02, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(30, 24, 22), M.Basalt, { Shape = Enum.PartType.Cylinder, CanCollide = false })
	Props.light(lava, Color3.fromRGB(255, 110, 40), size * 2.5, 2)
	return lava
end

function decor.lago(parent, theme, cf, width, depth, openings, rng)
	-- canal de lava numa lateral e poças nos cantos (só visual; o chão continua firme)
	local side = if rng:NextNumber() < 0.5 then -1 else 1
	local channel = block(parent, "Canal", Vector3.new(6, 0.12, depth - 6), cf * CFrame.new(side * (width / 2 - 5), 0.06, 0), Color3.fromRGB(255, 100, 30), M.Neon, { CanCollide = false })
	Props.light(channel, Color3.fromRGB(255, 110, 40), 30, 2)
	for _, s in { -1, 1 } do
		block(parent, "MargemCanal", Vector3.new(0.8, 0.6, depth - 6), cf * CFrame.new(side * (width / 2 - 5) + s * 3.4, 0.3, 0), Color3.fromRGB(30, 24, 22), M.Basalt)
	end
	for _, corner in { { -1, -1 }, { 1, 1 } } do
		lavaPool(parent, cf * CFrame.new(-side * corner[1] * (width / 2 - 9), 0, corner[2] * (depth / 2 - 9)), rng:NextNumber(6, 9))
	end
end

function decor.basalto(parent, theme, cf, width, depth, openings, rng)
	-- colunas hexagonais de basalto de alturas diferentes nas paredes
	for _, spot in wallSpots(cf, width, depth, openings, 3, 5) do
		for k = 0, 1 do
			local height = rng:NextNumber(3, 14)
			block(parent, "Coluna", Vector3.new(height, 2.4, 2.4), spot * CFrame.new(rng:NextNumber(-1.5, 1.5), height / 2, k * -2.2) * CFrame.Angles(0, 0, math.rad(90)), theme.wall:Lerp(theme.wallAlt, rng:NextNumber()), M.Basalt, { Shape = Enum.PartType.Cylinder })
		end
	end
	for _ = 1, 8 do
		block(parent, "Rachadura", Vector3.new(0.5, 0.05, rng:NextNumber(4, 10)), cf * CFrame.new(rng:NextNumber(-width / 2 + 4, width / 2 - 4), 0.03, rng:NextNumber(-depth / 2 + 4, depth / 2 - 4)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Color3.fromRGB(255, 120, 40), M.Neon, { CanCollide = false })
	end
end

function decor.forja(parent, theme, cf, width, depth, openings, rng)
	-- bigornas, caldeirões de lava, correntes do teto e suportes de armas
	for i, spot in wallSpots(cf, width, depth, openings, 4, 14) do
		if i % 2 == 0 then
			block(parent, "Toco", Vector3.new(1.8, 1.4, 1.8), spot * CFrame.new(0, 0.7, 0), Color3.fromRGB(60, 45, 35), M.Wood)
			block(parent, "Bigorna", Vector3.new(2.8, 0.7, 1.2), spot * CFrame.new(0, 1.75, 0), Color3.fromRGB(60, 60, 68), M.Metal)
		else
			Props.column(parent, spot, 2.4, 3.4, Color3.fromRGB(40, 36, 36), M.Metal)
			local lava = block(parent, "LavaCaldeirao", Vector3.new(0.2, 3, 3), spot * CFrame.new(0, 2.3, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 110, 40), M.Neon, { Shape = Enum.PartType.Cylinder })
			Props.light(lava, Color3.fromRGB(255, 120, 50), 20, 1.8)
		end
	end
	for _ = 1, 6 do
		local x, z = rng:NextNumber(-width / 2 + 6, width / 2 - 6), rng:NextNumber(-depth / 2 + 6, depth / 2 - 6)
		local length = rng:NextNumber(6, 14)
		for k = 0, math.floor(length / 1.2) do
			block(parent, "Elo", Vector3.new(0.5, 1.1, 0.2), cf * CFrame.new(x, WALL_HEIGHT - 0.6 - k * 1.1, z) * CFrame.Angles(0, if k % 2 == 0 then 0 else math.rad(90), 0), Color3.fromRGB(50, 48, 52), M.Metal, { CanCollide = false })
		end
	end
end

function decor.obsidiana(parent, theme, cf, width, depth, openings, rng)
	-- espinhos de obsidiana em grupos e rachaduras de lava no chão
	for _, spot in wallSpots(cf, width, depth, openings, 3, 7) do
		for _ = 1, 3 do
			local height = rng:NextNumber(2, 7)
			wedge(parent, "Espinho", Vector3.new(rng:NextNumber(0.8, 1.6), height, rng:NextNumber(0.8, 1.6)), spot * CFrame.new(rng:NextNumber(-2, 2), height / 2, rng:NextNumber(-1, 1)) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 3), 0), Color3.fromRGB(20, 16, 24), M.Glass, { Transparency = 0.1 })
		end
	end
	for _ = 1, 10 do
		block(parent, "Rachadura", Vector3.new(0.4, 0.05, rng:NextNumber(5, 12)), cf * CFrame.new(rng:NextNumber(-width / 2 + 4, width / 2 - 4), 0.03, rng:NextNumber(-depth / 2 + 4, depth / 2 - 4)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Color3.fromRGB(255, 120, 40), M.Neon, { CanCollide = false })
	end
end

-- arena do chefe: trono, braseiros, anel de pilares e runas no chão
function decor.chefe(parent, theme, cf, width, depth, openings, rng)
	local back = if openings.south then -1 else 1
	local throne = cf * CFrame.new(0, 0, back * (depth / 2 - 7))
	block(parent, "Estrado", Vector3.new(16, 1.6, 8), throne * CFrame.new(0, 0.8, 0), theme.trim, M.Slate)
	block(parent, "Degrau", Vector3.new(18, 0.8, 10), throne * CFrame.new(0, 0.4, 0), theme.trim:Lerp(Color3.new(1, 1, 1), 0.08), M.Slate)
	block(parent, "Trono", Vector3.new(6, 11, 2), throne * CFrame.new(0, 7, back * 2.5), theme.wallAlt, M.Slate)
	block(parent, "Encosto", Vector3.new(7, 1.6, 2.4), throne * CFrame.new(0, 12.4, back * 2.5), theme.accent, M.Neon)
	for i = 0, 15 do
		local angle = i / 16 * math.pi * 2
		block(parent, "Runa", Vector3.new(2.6, 0.06, 0.9), cf * CFrame.new(math.cos(angle) * 22, 0.03, math.sin(angle) * 22) * CFrame.Angles(0, -angle, 0), theme.accent, M.Neon, { CanCollide = false, Transparency = 0.25 })
	end
	for i = 0, 7 do
		local angle = (i + 0.5) / 8 * math.pi * 2
		local base = cf * CFrame.new(math.cos(angle) * (math.min(width, depth) / 2 - 7), 0, math.sin(angle) * (math.min(width, depth) / 2 - 7))
		Props.column(parent, base, WALL_HEIGHT, 3.2, theme.wall:Lerp(Color3.new(1, 1, 1), 0.08), if theme.wallMaterial == M.Brick then M.Marble else theme.wallMaterial)
		if i % 2 == 0 then
			Props.column(parent, base * CFrame.new(0, 0, 0) * CFrame.new(math.cos(angle) * -3.5, 0, math.sin(angle) * -3.5), 4, 1.6, Color3.fromRGB(45, 40, 40), M.Metal)
			Props.fire(parent, (base * CFrame.new(math.cos(angle) * -3.5, 4.2, math.sin(angle) * -3.5)).Position, 1.4)
		end
	end
	for _, spot in wallSpots(cf, width, depth, openings, 0.3, 22) do
		Props.banner(parent, spot * CFrame.new(0, WALL_HEIGHT - 5, -0.2), theme.banner)
	end
end

-- salas pequenas do lado (tesouro, biblioteca, santuário): enfeites leves
function decor.lateral(parent, theme, cf, width, depth, openings, rng)
	for _, spot in wallSpots(cf, width, depth, openings, 1.2, 9) do
		if rng:NextNumber() < 0.6 then
			Props.shelf(parent, spot * CFrame.new(0, 0, 0.6), 6, 3, pick({ "books", "potions", "goods" }, rng), rng)
		end
	end
	for _ = 1, 6 do
		ball(parent, "Moeda", 0.6, cf * CFrame.new(rng:NextNumber(-4, 4), 0.25, rng:NextNumber(-4, 4)), Color3.fromRGB(240, 200, 70), M.Metal, { CanCollide = false })
	end
end

-- ===================== SALA =====================

-- openings = { north = bool, south = bool, east = bool, west = bool } (norte = -Z)
function DungeonBuilder.room(parent, themeId, center, width, depth, openings, rng, kind)
	local theme = THEMES[themeId] or THEMES.cripta
	local cf = CFrame.new(center)
	buildFloor(parent, theme, themeId, cf, width, depth, rng)
	-- paredes: norte/sul cobrem os cantos; leste/oeste ficam entre elas (o -Z local aponta para dentro)
	local function wallCf(offset, inward)
		local position = center + offset + Vector3.new(0, 0, 0)
		return CFrame.lookAt(position, position + inward)
	end
	wall(parent, theme, wallCf(Vector3.new(0, 0, -depth / 2 - 1), Vector3.new(0, 0, 1)), width + 4, openings.north)
	wall(parent, theme, wallCf(Vector3.new(0, 0, depth / 2 + 1), Vector3.new(0, 0, -1)), width + 4, openings.south)
	wall(parent, theme, wallCf(Vector3.new(width / 2 + 1, 0, 0), Vector3.new(-1, 0, 0)), depth, openings.east)
	wall(parent, theme, wallCf(Vector3.new(-width / 2 - 1, 0, 0), Vector3.new(1, 0, 0)), depth, openings.west)
	buildCeiling(parent, theme, themeId, cf, width, depth, rng)
	-- tochas nas paredes (fora dos vãos)
	for _, spot in wallSpots(cf, width, depth, openings, 0.1, 20) do
		DungeonBuilder.torch(parent, spot * CFrame.new(0, 9, 0), theme)
	end
	local builder = decor[kind or ""]
	if builder then
		builder(parent, theme, cf, width, depth, openings, rng)
	end
	return cf
end

-- tipo de sala sorteado do tema
function DungeonBuilder.randomKind(themeId, rng)
	local theme = THEMES[themeId] or THEMES.cripta
	return theme.kinds[rng:NextInteger(1, #theme.kinds)]
end

-- ===================== CORREDOR E GRADE =====================

-- Corredor reto de "from" a "to" (pontos nas faces de fora das paredes das duas salas, na altura do piso).
-- Com grade: uma grade de ferro perto de "from" (sobe com DungeonBuilder.openGate).
function DungeonBuilder.corridor(parent, themeId, from, to, withGate)
	local theme = THEMES[themeId] or THEMES.cripta
	local length = (to - from).Magnitude
	local cf = CFrame.lookAt((from + to) / 2, to)
	-- o piso entra 2 studs em cada parede (embaixo dos vãos)
	block(parent, "PisoCorredor", Vector3.new(OPEN_W, 2, length + 4), cf * CFrame.new(0, -1, 0), theme.floorAlt, theme.floorMaterial)
	for _, s in { -1, 1 } do
		block(parent, "ParedeCorredor", Vector3.new(2, OPEN_H, length), cf * CFrame.new(s * (OPEN_W / 2 + 1), OPEN_H / 2, 0), theme.wall, theme.wallMaterial)
		block(parent, "RodapeCorredor", Vector3.new(0.5, 1.2, length), cf * CFrame.new(s * (OPEN_W / 2 - 0.25), 0.6, 0), theme.trim, M.Slate)
		local wallCf = cf * CFrame.new(s * (OPEN_W / 2 - 0.1), 8, 0) * CFrame.Angles(0, math.rad(s * 90), 0)
		DungeonBuilder.torch(parent, wallCf, theme)
	end
	block(parent, "TetoCorredor", Vector3.new(OPEN_W + 4, 2, length), cf * CFrame.new(0, OPEN_H + 1, 0), theme.ceiling, theme.wallMaterial)
	for k = 1, math.floor(length / 8) do
		block(parent, "Arco", Vector3.new(OPEN_W, 1.2, 1.2), cf * CFrame.new(0, OPEN_H - 0.6, -length / 2 + k * length / (math.floor(length / 8) + 1)), theme.trim, M.Slate)
	end
	if not withGate then
		return nil
	end
	local gate = Instance.new("Model")
	gate.Name = "Grade"
	local gateCf = cf * CFrame.new(0, 0, length / 2 - 2.5)
	for i = 0, 10 do
		block(gate, "Barra", Vector3.new(0.5, OPEN_H - 0.5, 0.5), gateCf * CFrame.new(-OPEN_W / 2 + 0.8 + i * (OPEN_W - 1.6) / 10, (OPEN_H - 0.5) / 2, 0), Color3.fromRGB(55, 55, 62), M.Metal)
		wedge(gate, "Ponta", Vector3.new(0.5, 0.8, 0.5), gateCf * CFrame.new(-OPEN_W / 2 + 0.8 + i * (OPEN_W - 1.6) / 10, -0.2, 0) * CFrame.Angles(math.rad(180), 0, 0), Color3.fromRGB(55, 55, 62), M.Metal)
	end
	for _, y in { 3, 9, OPEN_H - 2 } do
		block(gate, "Travessa", Vector3.new(OPEN_W - 0.4, 0.6, 0.7), gateCf * CFrame.new(0, y, 0), Color3.fromRGB(45, 45, 52), M.Metal)
	end
	block(gate, "Bloqueio", Vector3.new(OPEN_W, OPEN_H, 1), gateCf * CFrame.new(0, OPEN_H / 2, 0), Color3.new(0, 0, 0), M.SmoothPlastic, { Transparency = 1 })
	gate.Parent = parent
	return gate
end

function DungeonBuilder.openGate(gate)
	if not gate or not gate.Parent then
		return
	end
	for _, piece in gate:GetDescendants() do
		if piece:IsA("BasePart") then
			piece.CanCollide = false
			game:GetService("TweenService"):Create(piece, TweenInfo.new(1.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = piece.CFrame - Vector3.new(0, OPEN_H + 1, 0) }):Play()
		end
	end
	task.delay(2, function()
		gate:Destroy()
	end)
end

-- ===================== ESCADA =====================

-- Escada descendo para o próximo andar. O piso da sala é maciço (não dá para cavar), então a escada fica
-- num poço elevado: degraus sobem pela frente (-Z) até a borda e, dentro do poço, descem até o fundo escuro
-- com o portal brilhando, sob um arco. Retorna a peça brilhante (prompt).
function DungeonBuilder.stairs(parent, themeId, cf)
	local theme = THEMES[themeId] or THEMES.cripta
	local TOP = 3.6 -- altura da borda do poço
	local STEPS = 6
	local rise = TOP / STEPS
	local stone = theme.floorAlt
	-- subida pela frente: cada degrau é um bloco maciço do chão até o topo dele
	for i = 0, STEPS - 1 do
		local h = (i + 1) * rise
		block(parent, "DegrauSubida", Vector3.new(11, h, 1), cf * CFrame.new(0, h / 2, -9 + i + 0.5), stone, M.Slate)
	end
	-- paredes do poço (o vão por dentro: x de -4 a 4, z de -2 a 8)
	for _, sx in { -1, 1 } do
		block(parent, "BordaPoco", Vector3.new(1.5, TOP, 12.5), cf * CFrame.new(sx * 4.75, TOP / 2, 3.25), theme.trim, M.Slate)
	end
	block(parent, "BordaPoco", Vector3.new(8, TOP, 1), cf * CFrame.new(0, TOP / 2, -2.5), theme.trim, M.Slate)
	block(parent, "BordaPoco", Vector3.new(8, TOP, 1.5), cf * CFrame.new(0, TOP / 2, 8.75), theme.trim, M.Slate)
	-- descida por dentro: degraus cada vez mais fundos e mais escuros
	local down = 5
	local depth = 8 / down
	for i = 0, down - 1 do
		local h = TOP - (i + 1) * rise
		block(parent, "DegrauEscada", Vector3.new(8, h, depth), cf * CFrame.new(0, h / 2, -2 + (i + 0.5) * depth), stone:Lerp(Color3.new(0, 0, 0), 0.15 + i * 0.13), M.Slate)
	end
	-- fundo: boca escura na parede do fim (parece que a escada continua para baixo)
	local hole = block(parent, "Fundo", Vector3.new(7, TOP - 0.4, 0.2), cf * CFrame.new(0, (TOP - 0.4) / 2, 7.9), Color3.fromRGB(6, 4, 4), M.SmoothPlastic, { CanCollide = false })
	Props.light(hole, theme.accent, 18, 1.6)
	-- arco sobre o fundo e colunas com fogo na frente
	for _, sx in { -1, 1 } do
		Props.column(parent, cf * CFrame.new(sx * 4.75, TOP, 8.75), 5, 1.4, theme.trim, M.Slate)
		Props.column(parent, cf * CFrame.new(sx * 4.75, TOP, -2.5), 1.6, 1, theme.trim, M.Slate)
		Props.fire(parent, (cf * CFrame.new(sx * 4.75, TOP + 1.7, -2.5)).Position, 0.6)
	end
	block(parent, "Arco", Vector3.new(11, 1.2, 1.6), cf * CFrame.new(0, TOP + 5.6, 8.75), theme.trim, M.Slate)
	return block(parent, "Brilho", Vector3.new(8, 0.1, 1.6), cf * CFrame.new(0, 0.05, 7), theme.accent, M.Neon, { Transparency = 0.45, CanCollide = false })
end

return DungeonBuilder
