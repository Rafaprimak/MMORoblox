-- Biblioteca de objetos do cenário (blocados, mas com variação de forma, cor e tamanho).
local CollectionService = game:GetService("CollectionService")

local Props = {}

local M = Enum.Material

Props.Colors = {
	Wood = Color3.fromRGB(110, 75, 45),
	DarkWood = Color3.fromRGB(75, 50, 32),
	Plank = Color3.fromRGB(160, 120, 80),
	Stone = Color3.fromRGB(150, 148, 142),
	DarkStone = Color3.fromRGB(95, 95, 100),
	Roof = Color3.fromRGB(150, 60, 45),
	Leaves = Color3.fromRGB(70, 140, 60),
	Gold = Color3.fromRGB(255, 200, 60),
	Fire = Color3.fromRGB(255, 130, 40),
}
local C = Props.Colors

function Props.part(parent, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = M.SmoothPlastic
	if props.Shape then
		p.Shape = props.Shape
	end
	for key, value in props do
		if key ~= "Shape" then
			p[key] = value
		end
	end
	p.Parent = parent
	return p
end
local part = Props.part

-- Cilindro em pé (o eixo do cilindro do Roblox é X, então gira 90° em Z)
function Props.column(parent, base, height, diameter, color, material, extra)
	local props = {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = base * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material or M.SmoothPlastic,
	}
	if extra then
		for key, value in extra do
			props[key] = value
		end
	end
	return part(parent, props)
end

function Props.ball(parent, position, diameter, color, material, extra)
	local props = { Shape = Enum.PartType.Ball, Size = Vector3.one * diameter, CFrame = CFrame.new(position), Color = color, Material = material or M.SmoothPlastic }
	if extra then
		for key, value in extra do
			props[key] = value
		end
	end
	return part(parent, props)
end

-- Amplia um modelo inteiro (peças, luzes, partículas) a partir de um ponto fixo.
-- Use o ponto no chão como pivô para a base continuar encostada no terreno.
function Props.scaleModel(model, pivot, factor)
	if not model or factor == 1 then
		return model
	end
	model.WorldPivot = pivot
	model:ScaleTo(factor)
	return model
end

-- Peça que só acende à noite (o cliente liga a luz e o neon quando escurece)
function Props.nightLight(lampPart)
	CollectionService:AddTag(lampPart, "NightLight")
	return lampPart
end

function Props.light(parentPart, color, range, brightness, shadows)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness or 1.5
	light.Shadows = shadows == true
	light.Parent = parentPart
	return light
end

function Props.fire(parent, position, size)
	size = size or 1
	local flame = part(parent, { Name = "Chama", Size = Vector3.new(1, 1.4, 1) * size, CFrame = CFrame.new(position + Vector3.new(0, 0.7 * size, 0)), Color = C.Fire, Material = M.Neon, CanCollide = false, Transparency = 0.15 })
	Props.light(flame, C.Fire, 18 * size, 2)
	local particles = Instance.new("ParticleEmitter")
	particles.Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 70, 20))
	particles.LightEmission = 1
	particles.Size = NumberSequence.new(0.8 * size, 0)
	particles.Lifetime = NumberRange.new(0.5, 1)
	particles.Rate = 18
	particles.Speed = NumberRange.new(2, 4)
	particles.SpreadAngle = Vector2.new(15, 15)
	particles.Parent = flame
	return flame
end

function Props.smoke(parentPart, rate)
	local smoke = Instance.new("ParticleEmitter")
	smoke.Color = ColorSequence.new(Color3.fromRGB(120, 120, 120))
	smoke.Transparency = NumberSequence.new(0.4, 1)
	smoke.Size = NumberSequence.new(1.5, 5)
	smoke.Lifetime = NumberRange.new(3, 5)
	smoke.Rate = rate or 3
	smoke.Speed = NumberRange.new(2, 4)
	smoke.SpreadAngle = Vector2.new(10, 10)
	smoke.Parent = parentPart
	return smoke
end

function Props.billboard(adornee, text, color, offsetY, maxDistance)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(260, 46)
	gui.StudsOffset = Vector3.new(0, offsetY or 4, 0)
	gui.MaxDistance = maxDistance or 90
	gui.LightInfluence = 0
	gui.Parent = adornee
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = text
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Parent = label
	return gui
end

-- ===================== NATUREZA =====================

function Props.oak(parent, ground, scale, rng)
	local model = Instance.new("Model")
	model.Name = "Carvalho"
	local trunkHeight = (7 + rng:NextNumber() * 3) * scale
	local bark = C.Wood:Lerp(C.DarkWood, rng:NextNumber() * 0.5)
	-- tronco afinando em 2 partes, levemente torto
	local lean = CFrame.Angles(rng:NextNumber(-0.06, 0.06), 0, rng:NextNumber(-0.06, 0.06))
	Props.column(model, ground * CFrame.new(0, -0.5, 0), trunkHeight * 0.55 + 0.5, 2.0 * scale, bark, M.Wood)
	local upper = ground * CFrame.new(0, trunkHeight * 0.55, 0) * lean
	Props.column(model, upper, trunkHeight * 0.5, 1.5 * scale, bark, M.Wood)
	-- raízes
	for i = 0, 2 do
		local angle = i * math.pi * 2 / 3 + rng:NextNumber(0, 1)
		part(model, { Name = "Raiz", Size = Vector3.new(0.8, 0.9, 2.4) * scale, CFrame = ground * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0.2 * scale, -1.2 * scale) * CFrame.Angles(math.rad(-20), 0, 0), Color = bark, Material = M.Wood })
	end
	-- dois galhos
	local top = upper * CFrame.new(0, trunkHeight * 0.45, 0)
	for _, side in { -1, 1 } do
		part(model, { Name = "Galho", Size = Vector3.new(0.6, 0.6, 3.4) * scale, CFrame = upper * CFrame.new(0, trunkHeight * 0.3, 0) * CFrame.Angles(0, side * 1.4 + rng:NextNumber(-0.3, 0.3), 0) * CFrame.Angles(math.rad(40), 0, 0) * CFrame.new(0, 0, -1.4 * scale), Color = bark, Material = M.Wood, CanCollide = false })
	end
	-- copa em três tons (sombra embaixo, luz em cima)
	local leafColor = C.Leaves:Lerp(Color3.fromRGB(110, 170, 60), rng:NextNumber() * 0.6)
	local dark = leafColor:Lerp(Color3.new(0, 0, 0), 0.18)
	local light = leafColor:Lerp(Color3.fromRGB(200, 230, 120), 0.25)
	Props.ball(model, top.Position + Vector3.new(0, 1.5 * scale, 0), 9 * scale, leafColor, M.Grass, { CanCollide = false })
	for i = 1, 4 do
		local angle = rng:NextNumber() * math.pi * 2
		local low = i <= 2
		local offset = Vector3.new(math.cos(angle) * 3.4 * scale, (if low then -0.6 else 1.6) * scale + rng:NextNumber(0, 1) * scale, math.sin(angle) * 3.4 * scale)
		Props.ball(model, top.Position + offset, (5 + rng:NextNumber() * 2.2) * scale, if low then dark else leafColor, M.Grass, { CanCollide = false })
	end
	Props.ball(model, top.Position + Vector3.new(rng:NextNumber(-1, 1), 4.6, rng:NextNumber(-1, 1)) * scale, 4.6 * scale, light, M.Grass, { CanCollide = false })
	model.Parent = parent
	return model
end

function Props.pine(parent, ground, scale, rng, snowy)
	local model = Instance.new("Model")
	model.Name = "Pinheiro"
	local trunkHeight = 3 * scale
	Props.column(model, ground * CFrame.new(0, -0.5, 0), trunkHeight + 0.5, 1.4 * scale, C.DarkWood, M.Wood)
	local green = Color3.fromRGB(40, 95, 55):Lerp(Color3.fromRGB(60, 120, 70), rng:NextNumber())
	local layers = 5
	for i = 1, layers do
		local diameter = (9.5 - i * 1.55) * scale
		local y = trunkHeight + (i - 1) * 2.2 * scale
		local shade = if i % 2 == 0 then green:Lerp(Color3.new(0, 0, 0), 0.12) else green
		local isSnow = snowy and i >= layers - 1
		-- camada (disco) + aba mais fina embaixo para parecer um cone
		Props.column(model, ground * CFrame.new(0, y, 0) * CFrame.Angles(0, i * 0.5, 0), 1.6 * scale, diameter, if isSnow then Color3.fromRGB(235, 240, 245) else shade, if isSnow then M.Snow else M.Grass, { CanCollide = false })
		Props.column(model, ground * CFrame.new(0, y + 1.6 * scale, 0), 1.2 * scale, diameter * 0.72, if isSnow then Color3.fromRGB(240, 244, 248) else shade:Lerp(Color3.fromRGB(90, 150, 90), 0.15), if isSnow then M.Snow else M.Grass, { CanCollide = false })
	end
	Props.ball(model, (ground * CFrame.new(0, trunkHeight + layers * 2.2 * scale + 0.6, 0)).Position, 1.5 * scale, if snowy then Color3.fromRGB(240, 245, 250) else green, M.Grass, { CanCollide = false })
	model.Parent = parent
	return model
end

function Props.deadTree(parent, ground, scale, rng)
	local model = Instance.new("Model")
	model.Name = "ArvoreSeca"
	local color = Color3.fromRGB(95, 80, 65)
	local height = (6 + rng:NextNumber() * 4) * scale
	Props.column(model, ground * CFrame.new(0, -0.5, 0), height, 1.3 * scale, color, M.Wood)
	for i = 1, 3 do
		local angle = rng:NextNumber() * math.pi * 2
		local y = height * (0.45 + i * 0.15)
		part(model, {
			Name = "Galho",
			Size = Vector3.new(0.5, 0.5, 3.5) * scale,
			CFrame = ground * CFrame.new(0, y, 0) * CFrame.Angles(0, angle, 0) * CFrame.Angles(math.rad(35), 0, 0) * CFrame.new(0, 0, -1.6 * scale),
			Color = color,
			Material = M.Wood,
			CanCollide = false,
		})
	end
	model.Parent = parent
	return model
end

function Props.palm(parent, ground, scale, rng)
	local model = Instance.new("Model")
	model.Name = "Palmeira"
	local lean = rng:NextNumber(-0.25, 0.25)
	local cf = ground * CFrame.Angles(lean, rng:NextNumber() * 6, 0)
	local segment = 2.2 * scale
	for i = 1, 5 do
		part(model, { Name = "Tronco", Size = Vector3.new(0.9, segment, 0.9) * Vector3.new(scale, 1, scale), CFrame = cf * CFrame.new(0, segment * (i - 0.5), 0), Color = Color3.fromRGB(140, 110, 70), Material = M.Wood })
		cf *= CFrame.Angles(0.06, 0, 0)
	end
	local top = cf * CFrame.new(0, segment * 5, 0)
	for i = 1, 6 do
		part(model, {
			Name = "Folha",
			Size = Vector3.new(1.4, 0.2, 5) * scale,
			CFrame = top * CFrame.Angles(0, i * math.pi / 3, 0) * CFrame.Angles(math.rad(-25), 0, 0) * CFrame.new(0, 0, -2.4 * scale),
			Color = Color3.fromRGB(70, 150, 60),
			Material = M.Grass,
			CanCollide = false,
		})
	end
	model.Parent = parent
	return model
end

function Props.rock(parent, ground, scale, rng, color)
	local model = Instance.new("Model")
	model.Name = "Pedra"
	color = color or Color3.fromRGB(125, 122, 118)
	local count = rng:NextInteger(1, 3)
	for i = 1, count do
		local size = Vector3.new(rng:NextNumber(2, 4), rng:NextNumber(1.5, 3), rng:NextNumber(2, 4)) * scale * (if i == 1 then 1 else 0.6)
		local offset = if i == 1 then Vector3.zero else Vector3.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2)) * scale
		part(model, {
			Name = "Rocha",
			Size = size,
			CFrame = ground * CFrame.new(offset + Vector3.new(0, size.Y * 0.25, 0)) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 3), rng:NextNumber(-0.3, 0.3)),
			Color = color:Lerp(Color3.new(0, 0, 0), rng:NextNumber() * 0.15),
			Material = M.Rock,
		})
		-- musgo em cima da pedra principal
		if i == 1 and rng:NextNumber() < 0.45 then
			part(model, { Name = "Musgo", Size = Vector3.new(size.X * 0.8, 0.25, size.Z * 0.8), CFrame = ground * CFrame.new(0, size.Y * 0.75, 0) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Color = Color3.fromRGB(80, 130, 60), Material = M.Grass, CanCollide = false })
		end
	end
	-- pedrinhas em volta
	for _ = 1, rng:NextInteger(0, 3) do
		local pebble = rng:NextNumber(0.5, 1.0) * scale
		part(model, { Name = "Pedrinha", Size = Vector3.new(pebble, pebble * 0.6, pebble), CFrame = ground * CFrame.new(rng:NextNumber(-3, 3) * scale, pebble * 0.2, rng:NextNumber(-3, 3) * scale) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Color = color:Lerp(Color3.new(0, 0, 0), 0.1), Material = M.Rock, CanCollide = false })
	end
	model.Parent = parent
	return model
end

function Props.bush(parent, ground, scale, rng)
	local model = Instance.new("Model")
	model.Name = "Arbusto"
	local color = Color3.fromRGB(60, 130, 55):Lerp(Color3.fromRGB(90, 150, 60), rng:NextNumber())
	for i = 1, rng:NextInteger(1, 3) do
		local offset = Vector3.new(rng:NextNumber(-1.2, 1.2), 0.8, rng:NextNumber(-1.2, 1.2)) * scale
		Props.ball(model, (ground * CFrame.new(offset)).Position, rng:NextNumber(2.2, 3.4) * scale, color, M.Grass, { CanCollide = false })
	end
	if rng:NextNumber() < 0.3 then
		for _ = 1, 3 do
			local offset = Vector3.new(rng:NextNumber(-1.3, 1.3), rng:NextNumber(1, 2), rng:NextNumber(-1.3, 1.3)) * scale
			Props.ball(model, (ground * CFrame.new(offset)).Position, 0.45, Color3.fromRGB(220, 40, 60), M.SmoothPlastic, { CanCollide = false })
		end
	end
	model.Parent = parent
	return model
end

function Props.flowers(parent, ground, rng)
	local model = Instance.new("Model")
	model.Name = "Flores"
	local hue = rng:NextNumber()
	for _ = 1, 4 do
		local offset = Vector3.new(rng:NextNumber(-1.5, 1.5), 0, rng:NextNumber(-1.5, 1.5))
		local stem = ground * CFrame.new(offset)
		part(model, { Name = "Caule", Size = Vector3.new(0.12, 0.9, 0.12), CFrame = stem * CFrame.new(0, 0.45, 0), Color = Color3.fromRGB(60, 140, 50), CanCollide = false })
		Props.ball(model, (stem * CFrame.new(0, 0.95, 0)).Position, 0.45, Color3.fromHSV((hue + rng:NextNumber() * 0.1) % 1, 0.55, 1), M.SmoothPlastic, { CanCollide = false })
	end
	model.Parent = parent
	return model
end

-- ===================== CONSTRUÇÕES =====================

-- Telhado de duas águas feito com duas placas inclinadas (a cumeeira fica no eixo Z local)
function Props.roof(parent, cf, width, depth, pitch, color)
	local angle = math.rad(pitch)
	local half = width / 2 + 0.8
	local length = half / math.cos(angle)
	local rise = math.tan(angle) * half
	for _, side in { -1, 1 } do
		part(parent, {
			Name = "Telhado",
			Size = Vector3.new(length, 0.6, depth + 1.6),
			CFrame = cf * CFrame.new(side * half / 2, rise / 2, 0) * CFrame.Angles(0, 0, -side * angle),
			Color = color,
			Material = M.Slate,
		})
	end
	-- oitões (triângulos aproximados por degraus)
	for _, zSide in { -1, 1 } do
		for i = 1, 3 do
			local w = width * (1 - (i - 0.5) / 3)
			part(parent, {
				Name = "Oitao",
				Size = Vector3.new(w, rise / 3, 0.4),
				CFrame = cf * CFrame.new(0, (i - 0.5) * rise / 3, zSide * depth / 2),
				Color = C.Plank,
				Material = M.WoodPlanks,
			})
		end
	end
	return rise
end

-- Casa simples: base de pedra, paredes de madeira, porta na frente (-Z), janelas, telhado e chaminé
function Props.house(parent, cf, width, depth, wallHeight, wallColor, roofColor, rng)
	local model = Instance.new("Model")
	model.Name = "Casa"
	part(model, { Name = "Base", Size = Vector3.new(width + 1, 1, depth + 1), CFrame = cf * CFrame.new(0, 0.5, 0), Color = C.DarkStone, Material = M.Cobblestone })
	local wallY = 1 + wallHeight / 2
	local thickness = 0.8
	-- fundo e laterais
	part(model, { Name = "Parede", Size = Vector3.new(width, wallHeight, thickness), CFrame = cf * CFrame.new(0, wallY, depth / 2 - thickness / 2), Color = wallColor, Material = M.WoodPlanks })
	for _, side in { -1, 1 } do
		part(model, { Name = "Parede", Size = Vector3.new(thickness, wallHeight, depth), CFrame = cf * CFrame.new(side * (width / 2 - thickness / 2), wallY, 0), Color = wallColor, Material = M.WoodPlanks })
		part(model, { Name = "Janela", Size = Vector3.new(0.2, 2, 2.4), CFrame = cf * CFrame.new(side * (width / 2 + 0.05), wallY + 0.5, 0), Color = Color3.fromRGB(255, 220, 140), Material = M.Neon, Transparency = 0.35 })
	end
	-- frente com porta
	local doorWidth = 3
	local sideWidth = (width - doorWidth) / 2
	for _, side in { -1, 1 } do
		part(model, { Name = "Parede", Size = Vector3.new(sideWidth, wallHeight, thickness), CFrame = cf * CFrame.new(side * (doorWidth / 2 + sideWidth / 2), wallY, -depth / 2 + thickness / 2), Color = wallColor, Material = M.WoodPlanks })
	end
	part(model, { Name = "Verga", Size = Vector3.new(doorWidth, wallHeight - 5, thickness), CFrame = cf * CFrame.new(0, 1 + 5 + (wallHeight - 5) / 2, -depth / 2 + thickness / 2), Color = wallColor, Material = M.WoodPlanks })
	part(model, { Name = "Porta", Size = Vector3.new(doorWidth, 5, 0.3), CFrame = cf * CFrame.new(0, 3.5, -depth / 2 + 0.2), Color = C.DarkWood, Material = M.Wood })
	-- vigas de canto
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			part(model, { Name = "Viga", Size = Vector3.new(1, wallHeight, 1), CFrame = cf * CFrame.new(x * width / 2, wallY, z * depth / 2), Color = C.DarkWood, Material = M.Wood })
		end
	end
	local roofBase = cf * CFrame.new(0, 1 + wallHeight, 0) * CFrame.Angles(0, math.rad(90), 0)
	local rise = Props.roof(model, roofBase, depth, width, 32, roofColor)
	if rng and rng:NextNumber() < 0.7 then
		local chimney = part(model, { Name = "Chamine", Size = Vector3.new(1.6, rise + 3, 1.6), CFrame = cf * CFrame.new(width / 4, 1 + wallHeight + (rise + 3) / 2, depth / 4), Color = C.DarkStone, Material = M.Brick })
		Props.smoke(chimney, 1.5)
	end
	model.Parent = parent
	return model
end

-- Construção com interior: a porta fica em z = 0 (frente, -Z) e o salão vai para +Z.
-- Base com degrau na entrada, piso de tábuas, paredes com vão da porta, janelas com moldura,
-- vigas, telhado, luzes internas e chaminé opcional. Retorna o modelo.
-- options: doorWidth, doorHeight, floorColor, chimney (offset x), lights (lista de posições locais)
function Props.building(parent, cf, width, depth, wallHeight, wallColor, roofColor, options)
	options = options or {}
	local model = Instance.new("Model")
	model.Name = options.name or "Construcao"
	local doorWidth = options.doorWidth or 4
	local doorHeight = options.doorHeight or 6.5
	local thickness = 0.8
	local center = cf * CFrame.new(0, 0, depth / 2)
	-- base de pedra + piso de tábuas
	part(model, { Name = "Base", Size = Vector3.new(width + 1.2, 1, depth + 1.2), CFrame = center * CFrame.new(0, 0.5, 0), Color = C.DarkStone, Material = M.Cobblestone })
	part(model, { Name = "Piso", Size = Vector3.new(width - thickness, 0.2, depth - thickness), CFrame = center * CFrame.new(0, 1.1, 0), Color = options.floorColor or C.Plank, Material = M.WoodPlanks })
	-- degrau e rampinha na entrada
	part(model, { Name = "Degrau", Size = Vector3.new(doorWidth + 1.5, 0.5, 1.6), CFrame = cf * CFrame.new(0, 0.25, -1.4), Color = C.Stone, Material = M.Cobblestone })
	local wallY = 1 + wallHeight / 2
	-- fundo
	part(model, { Name = "Parede", Size = Vector3.new(width, wallHeight, thickness), CFrame = cf * CFrame.new(0, wallY, depth - thickness / 2), Color = wallColor, Material = M.WoodPlanks })
	-- laterais
	for _, side in { -1, 1 } do
		part(model, { Name = "Parede", Size = Vector3.new(thickness, wallHeight, depth), CFrame = center * CFrame.new(side * (width / 2 - thickness / 2), wallY, 0), Color = wallColor, Material = M.WoodPlanks })
		-- rodapé de pedra por fora
		part(model, { Name = "Rodape", Size = Vector3.new(thickness + 0.3, 1.2, depth + 0.3), CFrame = center * CFrame.new(side * (width / 2 - thickness / 2), 1.6, 0), Color = C.Stone, Material = M.Cobblestone })
	end
	-- frente com vão da porta
	local sideWidth = (width - doorWidth) / 2
	for _, side in { -1, 1 } do
		part(model, { Name = "Parede", Size = Vector3.new(sideWidth, wallHeight, thickness), CFrame = cf * CFrame.new(side * (doorWidth / 2 + sideWidth / 2), wallY, thickness / 2), Color = wallColor, Material = M.WoodPlanks })
		-- batente
		part(model, { Name = "Batente", Size = Vector3.new(0.5, doorHeight + 0.5, thickness + 0.4), CFrame = cf * CFrame.new(side * (doorWidth / 2 + 0.25), 1 + (doorHeight + 0.5) / 2, thickness / 2), Color = C.DarkWood, Material = M.Wood })
	end
	part(model, { Name = "Verga", Size = Vector3.new(doorWidth + 1, wallHeight - doorHeight, thickness), CFrame = cf * CFrame.new(0, 1 + doorHeight + (wallHeight - doorHeight) / 2, thickness / 2), Color = wallColor, Material = M.WoodPlanks })
	part(model, { Name = "VergaViga", Size = Vector3.new(doorWidth + 1.4, 0.6, thickness + 0.4), CFrame = cf * CFrame.new(0, 1 + doorHeight + 0.3, thickness / 2), Color = C.DarkWood, Material = M.Wood })
	-- porta aberta (girada para dentro, presa no batente esquerdo)
	part(model, { Name = "Porta", Size = Vector3.new(doorWidth * 0.5, doorHeight, 0.3), CFrame = cf * CFrame.new(-doorWidth / 2, 1 + doorHeight / 2, thickness) * CFrame.Angles(0, math.rad(-80), 0) * CFrame.new(doorWidth * 0.25, 0, 0), Color = C.DarkWood, Material = M.Wood })
	-- janelas com moldura e vidro (laterais e fundo)
	local function window(frame)
		part(model, { Name = "Moldura", Size = Vector3.new(3.2, 3.2, 0.3), CFrame = frame, Color = C.DarkWood, Material = M.Wood })
		part(model, { Name = "Vidro", Size = Vector3.new(2.6, 2.6, 0.35), CFrame = frame, Color = Color3.fromRGB(255, 225, 160), Material = M.Glass, Transparency = 0.35 })
		part(model, { Name = "Cruz", Size = Vector3.new(0.2, 2.6, 0.4), CFrame = frame, Color = C.DarkWood, Material = M.Wood })
		part(model, { Name = "Cruz", Size = Vector3.new(2.6, 0.2, 0.4), CFrame = frame, Color = C.DarkWood, Material = M.Wood })
	end
	for _, side in { -1, 1 } do
		for _, z in { depth * 0.3, depth * 0.72 } do
			window(cf * CFrame.new(side * (width / 2), wallY + 0.6, z) * CFrame.Angles(0, math.rad(90), 0))
		end
		window(cf * CFrame.new(side * width / 4, wallY + 0.6, 0))
	end
	window(cf * CFrame.new(0, wallY + 0.6, depth))
	-- vigas de canto e viga de topo
	for _, x in { -1, 1 } do
		for _, z in { 0, depth } do
			part(model, { Name = "Viga", Size = Vector3.new(1, wallHeight + 0.4, 1), CFrame = cf * CFrame.new(x * width / 2, wallY, z), Color = C.DarkWood, Material = M.Wood })
		end
		part(model, { Name = "VigaTopo", Size = Vector3.new(0.8, 0.8, depth + 1), CFrame = center * CFrame.new(x * width / 2, 1 + wallHeight, 0), Color = C.DarkWood, Material = M.Wood })
	end
	part(model, { Name = "VigaTopo", Size = Vector3.new(width + 1, 0.8, 0.8), CFrame = cf * CFrame.new(0, 1 + wallHeight, 0), Color = C.DarkWood, Material = M.Wood })
	part(model, { Name = "VigaTopo", Size = Vector3.new(width + 1, 0.8, 0.8), CFrame = cf * CFrame.new(0, 1 + wallHeight, depth), Color = C.DarkWood, Material = M.Wood })
	-- vigas do teto (vistas de dentro)
	for i = 1, 3 do
		part(model, { Name = "Caibro", Size = Vector3.new(width - 1, 0.5, 0.5), CFrame = cf * CFrame.new(0, wallHeight + 0.4, depth * i / 4), Color = C.DarkWood, Material = M.Wood })
	end
	local roofBase = center * CFrame.new(0, 1 + wallHeight, 0) * CFrame.Angles(0, math.rad(90), 0)
	local rise = Props.roof(model, roofBase, depth + 1, width + 1, 30, roofColor)
	if options.chimney then
		local chimney = part(model, { Name = "Chamine", Size = Vector3.new(1.8, rise + 4, 1.8), CFrame = cf * CFrame.new(options.chimney, 1 + wallHeight + (rise + 4) / 2 - 1, depth * 0.75), Color = C.DarkStone, Material = M.Brick })
		Props.smoke(chimney, 2)
	end
	-- luzes internas (penduradas nos caibros)
	for _, position in options.lights or { Vector3.new(0, wallHeight - 1, depth * 0.35), Vector3.new(0, wallHeight - 1, depth * 0.75) } do
		part(model, { Name = "Corrente", Size = Vector3.new(0.15, 1.2, 0.15), CFrame = cf * CFrame.new(position + Vector3.new(0, 0.9, 0)), Color = Color3.fromRGB(50, 50, 55), Material = M.Metal })
		local lantern = part(model, { Name = "Lampiao", Size = Vector3.new(0.9, 1.1, 0.9), CFrame = cf * CFrame.new(position), Color = Color3.fromRGB(255, 210, 140), Material = M.Neon, CanCollide = false })
		Props.light(lantern, Color3.fromRGB(255, 200, 140), 22, 1.6, true)
	end
	model.Parent = parent
	return model
end

-- Prateleira de parede com objetos coloridos (frascos, livros, mercadorias)
function Props.shelf(parent, cf, width, rows, kind, rng)
	local model = Instance.new("Model")
	model.Name = "Prateleira"
	part(model, { Name = "Fundo", Size = Vector3.new(width, rows * 1.8 + 0.4, 0.3), CFrame = cf * CFrame.new(0, (rows * 1.8 + 0.4) / 2, 0.6), Color = C.DarkWood, Material = M.Wood })
	for row = 0, rows do
		part(model, { Name = "Tabua", Size = Vector3.new(width, 0.25, 1.2), CFrame = cf * CFrame.new(0, 0.2 + row * 1.8, 0), Color = C.Wood, Material = M.WoodPlanks })
	end
	for _, side in { -1, 1 } do
		part(model, { Name = "Lado", Size = Vector3.new(0.3, rows * 1.8 + 0.4, 1.2), CFrame = cf * CFrame.new(side * width / 2, (rows * 1.8 + 0.4) / 2, 0), Color = C.DarkWood, Material = M.Wood })
	end
	for row = 0, rows - 1 do
		local x = -width / 2 + 0.6
		while x < width / 2 - 0.6 do
			local y = 0.35 + row * 1.8
			if kind == "potions" then
				local color = Color3.fromHSV(rng:NextNumber(), 0.7, 1)
				local h = rng:NextNumber(0.6, 1.1)
				part(model, { Name = "Frasco", Size = Vector3.new(0.45, h, 0.45), CFrame = cf * CFrame.new(x, y + h / 2, -0.1), Color = color, Material = M.Glass, Transparency = 0.15 })
				part(model, { Name = "Rolha", Size = Vector3.new(0.25, 0.2, 0.25), CFrame = cf * CFrame.new(x, y + h + 0.1, -0.1), Color = C.Wood, Material = M.Wood })
				x += rng:NextNumber(0.6, 0.9)
			elseif kind == "books" then
				local h = rng:NextNumber(1.0, 1.45)
				local w = rng:NextNumber(0.25, 0.4)
				part(model, { Name = "Livro", Size = Vector3.new(w, h, 0.9), CFrame = cf * CFrame.new(x, y + h / 2, 0) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-6, 6))), Color = Color3.fromHSV(rng:NextNumber(), 0.55, rng:NextNumber(0.35, 0.7)), Material = M.SmoothPlastic })
				x += w + 0.05
			else
				local size = rng:NextNumber(0.6, 1.0)
				part(model, { Name = "Mercadoria", Size = Vector3.new(size, size * 0.8, size), CFrame = cf * CFrame.new(x, y + size * 0.4, -0.1), Color = Color3.fromHSV(rng:NextNumber(), 0.5, 0.85), Material = if rng:NextNumber() < 0.5 then M.Fabric else M.WoodPlanks })
				x += size + 0.2
			end
		end
	end
	model.Parent = parent
	return model
end

-- Mesa simples (tampo e 4 pés)
function Props.table(parent, cf, width, depth, height, color)
	local model = Instance.new("Model")
	model.Name = "Mesa"
	part(model, { Name = "Tampo", Size = Vector3.new(width, 0.35, depth), CFrame = cf * CFrame.new(0, height, 0), Color = color or C.Plank, Material = M.WoodPlanks })
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			part(model, { Name = "Pe", Size = Vector3.new(0.35, height, 0.35), CFrame = cf * CFrame.new(x * (width / 2 - 0.3), height / 2, z * (depth / 2 - 0.3)), Color = C.DarkWood, Material = M.Wood })
		end
	end
	model.Parent = parent
	return model
end

-- Tapete retangular com borda
function Props.rug(parent, cf, width, depth, color, border)
	part(parent, { Name = "Tapete", Size = Vector3.new(width, 0.08, depth), CFrame = cf * CFrame.new(0, 1.24, 0), Color = border or C.Gold, Material = M.Fabric, CanCollide = false })
	part(parent, { Name = "Tapete", Size = Vector3.new(width - 0.6, 0.1, depth - 0.6), CFrame = cf * CFrame.new(0, 1.26, 0), Color = color, Material = M.Fabric, CanCollide = false })
end

function Props.fence(parent, fromPos, toPos, height, color)
	local model = Instance.new("Model")
	model.Name = "Cerca"
	local length = (toPos - fromPos).Magnitude
	local posts = math.max(2, math.floor(length / 4) + 1)
	for i = 0, posts - 1 do
		local position = fromPos:Lerp(toPos, i / (posts - 1))
		part(model, { Name = "Mourao", Size = Vector3.new(0.5, height, 0.5), CFrame = CFrame.new(position + Vector3.new(0, height / 2 - 0.3, 0)), Color = color or C.Wood, Material = M.Wood })
	end
	for _, y in { height * 0.4, height * 0.8 } do
		part(model, { Name = "Travessa", Size = Vector3.new(0.25, 0.35, length), CFrame = CFrame.lookAt((fromPos + toPos) / 2 + Vector3.new(0, y, 0), toPos + Vector3.new(0, y, 0)), Color = color or C.Wood, Material = M.Wood })
	end
	model.Parent = parent
	return model
end

function Props.lamp(parent, ground)
	local model = Instance.new("Model")
	model.Name = "Poste"
	part(model, { Name = "Haste", Size = Vector3.new(0.5, 8, 0.5), CFrame = ground * CFrame.new(0, 4, 0), Color = Color3.fromRGB(40, 40, 45), Material = M.Metal })
	part(model, { Name = "Braco", Size = Vector3.new(0.3, 0.3, 1.6), CFrame = ground * CFrame.new(0, 7.8, -0.7), Color = Color3.fromRGB(40, 40, 45), Material = M.Metal })
	local lamp = part(model, { Name = "Lampiao", Size = Vector3.new(0.9, 1.1, 0.9), CFrame = ground * CFrame.new(0, 7.2, -1.4), Color = Color3.fromRGB(255, 220, 150), Material = M.Neon, CanCollide = false })
	Props.light(lamp, Color3.fromRGB(255, 200, 140), 22, 1.4)
	Props.nightLight(lamp)
	model.Parent = parent
	return model
end

function Props.crate(parent, cf, size)
	size = size or 2.5
	return part(parent, { Name = "Caixa", Size = Vector3.one * size, CFrame = cf * CFrame.new(0, size / 2, 0), Color = C.Plank, Material = M.WoodPlanks })
end

function Props.barrel(parent, cf, scale)
	scale = scale or 1
	local barrel = Props.column(parent, cf, 3 * scale, 2.2 * scale, C.Wood, M.Wood)
	barrel.Name = "Barril"
	return barrel
end

function Props.tent(parent, cf, color)
	local model = Instance.new("Model")
	model.Name = "Tenda"
	local angle = math.rad(50)
	for _, side in { -1, 1 } do
		part(model, {
			Name = "Lona",
			Size = Vector3.new(5, 0.25, 6),
			CFrame = cf * CFrame.new(side * 1.6, 1.9, 0) * CFrame.Angles(0, 0, -side * angle),
			Color = color,
			Material = M.Fabric,
		})
	end
	part(model, { Name = "Mastro", Size = Vector3.new(0.3, 0.3, 6.6), CFrame = cf * CFrame.new(0, 3.8, 0), Color = C.DarkWood, Material = M.Wood })
	model.Parent = parent
	return model
end

function Props.campfire(parent, ground)
	local model = Instance.new("Model")
	model.Name = "Fogueira"
	for i = 1, 6 do
		local angle = i / 6 * math.pi * 2
		Props.ball(model, (ground * CFrame.new(math.cos(angle) * 1.6, 0.3, math.sin(angle) * 1.6)).Position, 0.9, C.DarkStone, M.Rock)
	end
	for i = 1, 3 do
		part(model, { Name = "Lenha", Size = Vector3.new(0.4, 0.4, 2.6), CFrame = ground * CFrame.new(0, 0.4, 0) * CFrame.Angles(0, i * math.pi / 3, 0), Color = C.DarkWood, Material = M.Wood })
	end
	Props.fire(model, (ground * CFrame.new(0, 0.4, 0)).Position, 1.1)
	model.Parent = parent
	return model
end

return Props
