-- Biblioteca de objetos do cenário (blocados, mas com variação de forma, cor e tamanho).
local CollectionService = game:GetService("CollectionService")

local ExternalModels = require(script.Parent.ExternalModels)

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

-- Texto gravado numa face da peça (placas de loja, poste de placa). faces = { Enum.NormalId... }
function Props.engrave(target, text, color, faces)
	for _, face in faces or { Enum.NormalId.Front } do
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Gravado"
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 60
		gui.LightInfluence = 0.6
		gui.MaxDistance = 140
		gui.Parent = target
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(0.92, 0, 0.8, 0)
		label.Position = UDim2.fromScale(0.04, 0.1)
		label.FontFace = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold)
		label.TextScaled = true
		label.TextColor3 = color
		label.Text = text
		label.Parent = gui
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = Color3.fromRGB(30, 20, 12)
		stroke.Parent = label
	end
end

-- Peça que dá para ler (E perto dela): o cliente abre a placa com título e texto (SignReader)
function Props.readable(target, title, text)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "LerPlaca"
	prompt.ActionText = "Ler"
	prompt.ObjectText = title
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt:SetAttribute("Titulo", title)
	prompt:SetAttribute("Texto", text)
	prompt.Parent = target
	return prompt
end

-- Poste de madeira com placa (título gravado dos dois lados, texto para ler). groundCf: chão, frente em -Z
function Props.signpost(parent, groundCf, title, text, color)
	local model = Instance.new("Model")
	model.Name = "Placa_" .. title
	local wood = Color3.fromRGB(112, 74, 42)
	local dark = Color3.fromRGB(70, 45, 28)
	part(model, { Name = "Poste", Size = Vector3.new(0.45, 6.2, 0.45), CFrame = groundCf * CFrame.new(0, 3.1, 0), Color = dark, Material = Enum.Material.Wood, CanCollide = false })
	local board = part(model, { Name = "Tabua", Size = Vector3.new(5.2, 2.2, 0.3), CFrame = groundCf * CFrame.new(0, 5.0, 0), Color = wood, Material = Enum.Material.WoodPlanks, CanCollide = false })
	part(model, { Name = "Moldura", Size = Vector3.new(5.5, 0.25, 0.4), CFrame = groundCf * CFrame.new(0, 6.2, 0), Color = dark, Material = Enum.Material.Wood, CanCollide = false })
	part(model, { Name = "Moldura", Size = Vector3.new(5.5, 0.25, 0.4), CFrame = groundCf * CFrame.new(0, 3.8, 0), Color = dark, Material = Enum.Material.Wood, CanCollide = false })
	part(model, { Name = "Telhadinho", Size = Vector3.new(5.9, 0.2, 0.9), CFrame = groundCf * CFrame.new(0, 6.5, 0), Color = Color3.fromRGB(120, 50, 40), Material = Enum.Material.WoodPlanks, CanCollide = false })
	Props.engrave(board, title, color or Color3.fromRGB(255, 225, 150), { Enum.NormalId.Front, Enum.NormalId.Back })
	Props.readable(board, title, text)
	model.Parent = parent
	return model
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
	local external = ExternalModels.place("oak", parent, ground, scale, rng)
	if external then
		return external
	end
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
	local external = not snowy and ExternalModels.place("pine", parent, ground, scale, rng)
	if external then
		return external
	end
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
	local external = ExternalModels.place("deadTree", parent, ground, scale, rng)
	if external then
		return external
	end
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
	local external = ExternalModels.place("palm", parent, ground, scale, rng)
	if external then
		return external
	end
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
	local external = not color and ExternalModels.place("rock", parent, ground, scale, rng)
	if external then
		return external
	end
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
	local external = ExternalModels.place("bush", parent, ground, scale, rng)
	if external then
		return external
	end
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
	-- Telhado de duas águas com fileiras de telhas sobrepostas (tons alternados), cumeeira,
	-- tábuas de acabamento nas pontas e oitões triangulares. Largura no eixo X local (caimento),
	-- profundidade no eixo Z local (cumeeira). Retorna a altura (rise).
	local angle = math.rad(pitch)
	local half = width / 2 + 0.8
	local length = half / math.cos(angle)
	local rise = math.tan(angle) * half
	local dark = color:Lerp(Color3.new(0, 0, 0), 0.14)
	local step, rowLength = 1.15, 1.6
	local rows = math.max(2, math.ceil((length - 0.3) / step))
	for _, side in { -1, 1 } do
		-- direção da beira até a cumeeira e normal para fora do telhado
		local dirX, dirY = -side * math.cos(angle), math.sin(angle)
		local normalX, normalY = side * math.sin(angle), math.cos(angle)
		for i = 0, rows - 1 do
			local along = math.min(i * step + rowLength / 2, length - rowLength / 2 + 0.2)
			local lift = 0.18 + (rows - i) * 0.03 -- fileiras de baixo ficam por cima (sobreposição)
			local x = side * half + dirX * along + normalX * lift
			local y = dirY * along + normalY * lift
			part(parent, {
				Name = "Telhado",
				Size = Vector3.new(rowLength, 0.32, depth + 1.6),
				CFrame = cf * CFrame.new(x, y, 0) * CFrame.Angles(0, 0, -side * angle),
				Color = if i % 2 == 0 then color else dark,
				Material = M.Slate,
			})
		end
		-- tábuas de acabamento nas pontas do telhado
		for _, zSide in { -1, 1 } do
			part(parent, {
				Name = "Testeira",
				Size = Vector3.new(length + 0.4, 0.4, 0.3),
				CFrame = cf * CFrame.new(side * half / 2 + normalX * 0.45, rise / 2 + normalY * 0.45, zSide * (depth / 2 + 0.85)) * CFrame.Angles(0, 0, -side * angle),
				Color = C.DarkWood,
				Material = M.Wood,
			})
		end
	end
	-- cumeeira
	part(parent, { Name = "Cumeeira", Size = Vector3.new(1.0, 0.55, depth + 1.9), CFrame = cf * CFrame.new(0, rise + 0.45, 0), Color = dark:Lerp(Color3.new(0, 0, 0), 0.2), Material = M.Slate })
	-- oitões triangulares (duas cunhas por ponta)
	for _, zSide in { -1, 1 } do
		for _, xSide in { -1, 1 } do
			local wedge = part(parent, {
				Name = "Oitao",
				Size = Vector3.new(0.4, rise, width / 2),
				CFrame = cf * CFrame.new(xSide * width / 4, rise / 2, zSide * depth / 2) * CFrame.Angles(0, math.rad(if xSide < 0 then 90 else -90), 0),
				Color = C.Plank,
				Material = M.WoodPlanks,
			})
			wedge.Shape = Enum.PartType.Wedge
		end
	end
	return rise
end

-- Casa simples: base de pedra, paredes de madeira, porta na frente (-Z), janelas, telhado e chaminé
-- Janela de fachada: vidro que acende à noite, travessas, moldura, peitoril de pedra, venezianas
-- (opcionais) e floreira. "face" fica na superfície de fora da parede, com -Z apontando para fora.
local SHUTTER_COLORS = { Color3.fromRGB(70, 110, 80), Color3.fromRGB(60, 90, 140), Color3.fromRGB(140, 60, 55), Color3.fromRGB(120, 95, 60) }

function Props.facadeWindow(model, face, width, height, options)
	options = options or {}
	local trim = options.trim or C.DarkWood
	Props.nightWindow(part(model, { Name = "Janela", Size = Vector3.new(width, height, 0.2), CFrame = face * CFrame.new(0, 0, -0.05), Color = Color3.fromRGB(255, 220, 140), Material = M.Neon }))
	part(model, { Name = "Cruz", Size = Vector3.new(0.14, height, 0.12), CFrame = face * CFrame.new(0, 0, -0.21), Color = trim, Material = M.Wood })
	part(model, { Name = "Cruz", Size = Vector3.new(width, 0.14, 0.1), CFrame = face * CFrame.new(0, 0, -0.2), Color = trim, Material = M.Wood })
	-- moldura (verga em cima e montantes dos lados) e peitoril de pedra
	part(model, { Name = "Moldura", Size = Vector3.new(width + 0.7, 0.28, 0.3), CFrame = face * CFrame.new(0, height / 2 + 0.14, -0.15), Color = trim, Material = M.Wood })
	for _, side in { -1, 1 } do
		part(model, { Name = "Moldura", Size = Vector3.new(0.28, height, 0.3), CFrame = face * CFrame.new(side * (width / 2 + 0.14), 0, -0.15), Color = trim, Material = M.Wood })
	end
	part(model, { Name = "Peitoril", Size = Vector3.new(width + 0.9, 0.22, 0.55), CFrame = face * CFrame.new(0, -height / 2 - 0.11, -0.27), Color = C.Stone, Material = M.Slate })
	-- venezianas abertas, encostadas na parede, com ripas
	if options.shutters then
		local leaf = width / 2 + 0.1
		for _, side in { -1, 1 } do
			local shutter = face * CFrame.new(side * (width / 2 + 0.3 + leaf / 2), 0, -0.07)
			part(model, { Name = "Veneziana", Size = Vector3.new(leaf, height + 0.2, 0.12), CFrame = shutter, Color = options.shutters, Material = M.WoodPlanks })
			for _, y in { -0.25, 0.25 } do
				part(model, { Name = "Ripa", Size = Vector3.new(leaf - 0.15, 0.08, 0.05), CFrame = shutter * CFrame.new(0, y * height, -0.08), Color = options.shutters:Lerp(Color3.new(0, 0, 0), 0.3), Material = M.Wood })
			end
		end
	end
	if options.rng then
		Props.flowerBox(model, face * CFrame.new(0, -height / 2 - 0.55, -0.45), width + 0.4, options.rng)
	end
end

-- Casa: alicerce de pedra, paredes de tábuas, vigas de canto, janelas com venezianas e floreiras,
-- porta recuada com batentes e verga de pedra, alpendre de duas águas, lampião, telhado de telhas
-- e chaminé. Nenhuma peça cruza o vão da porta. A frente fica em -Z.
function Props.house(parent, cf, width, depth, wallHeight, wallColor, roofColor, rng)
	local model = Instance.new("Model")
	model.Name = "Casa"
	part(model, { Name = "Base", Size = Vector3.new(width + 1, 1, depth + 1), CFrame = cf * CFrame.new(0, 0.5, 0), Color = C.DarkStone, Material = M.Cobblestone })
	local wallY = 1 + wallHeight / 2
	local thickness = 0.8
	local front = -depth / 2
	local doorWidth, doorHeight = 3, 5
	local jamb, lintel = 0.5, 0.6
	local opening = doorWidth / 2 + jamb -- até onde vão os batentes (a parede da frente começa aí)
	local sideWidth = width / 2 - opening
	local shutters = if rng then SHUTTER_COLORS[rng:NextInteger(1, #SHUTTER_COLORS)] else SHUTTER_COLORS[1]
	-- fundo e laterais (com alicerce de pedra por fora)
	part(model, { Name = "Parede", Size = Vector3.new(width, wallHeight, thickness), CFrame = cf * CFrame.new(0, wallY, depth / 2 - thickness / 2), Color = wallColor, Material = M.WoodPlanks })
	part(model, { Name = "Alicerce", Size = Vector3.new(width + 0.3, 1.4, thickness + 0.3), CFrame = cf * CFrame.new(0, 1.7, depth / 2 - thickness / 2), Color = C.Stone, Material = M.Cobblestone })
	for _, side in { -1, 1 } do
		part(model, { Name = "Parede", Size = Vector3.new(thickness, wallHeight, depth), CFrame = cf * CFrame.new(side * (width / 2 - thickness / 2), wallY, 0), Color = wallColor, Material = M.WoodPlanks })
		part(model, { Name = "Alicerce", Size = Vector3.new(thickness + 0.3, 1.4, depth + 0.3), CFrame = cf * CFrame.new(side * (width / 2 - thickness / 2), 1.7, 0), Color = C.Stone, Material = M.Cobblestone })
		Props.facadeWindow(model, cf * CFrame.new(side * width / 2, wallY + 0.4, 0) * CFrame.Angles(0, math.rad(-side * 90), 0), 2.2, 2, { shutters = shutters, rng = rng })
	end
	-- frente: paredes dos lados da porta, parede acima da verga
	for _, side in { -1, 1 } do
		local x = side * (opening + sideWidth / 2)
		part(model, { Name = "Parede", Size = Vector3.new(sideWidth, wallHeight, thickness), CFrame = cf * CFrame.new(x, wallY, front + thickness / 2), Color = wallColor, Material = M.WoodPlanks })
		part(model, { Name = "Alicerce", Size = Vector3.new(sideWidth, 1.4, thickness + 0.3), CFrame = cf * CFrame.new(x, 1.7, front + thickness / 2), Color = C.Stone, Material = M.Cobblestone })
		-- janelinha da frente (só nas casas largas)
		if sideWidth >= 4 then
			Props.facadeWindow(model, cf * CFrame.new(side * (opening + sideWidth / 2 + 0.2), wallY + 0.4, front), 1.4, 1.8, { rng = rng })
		end
	end
	local aboveDoor = wallHeight - doorHeight - lintel
	part(model, { Name = "Verga", Size = Vector3.new(opening * 2, aboveDoor, thickness), CFrame = cf * CFrame.new(0, 1 + doorHeight + lintel + aboveDoor / 2, front + thickness / 2), Color = wallColor, Material = M.WoodPlanks })
	-- moldura de pedra da porta: batentes, verga e pedra-chave (encaixados, sem atravessar nada)
	for _, side in { -1, 1 } do
		part(model, { Name = "Batente", Size = Vector3.new(jamb, doorHeight, thickness + 0.3), CFrame = cf * CFrame.new(side * (doorWidth / 2 + jamb / 2), 1 + doorHeight / 2, front + thickness / 2), Color = C.Stone, Material = M.Slate })
	end
	part(model, { Name = "VergaPedra", Size = Vector3.new(opening * 2 + 0.6, lintel, thickness + 0.4), CFrame = cf * CFrame.new(0, 1 + doorHeight + lintel / 2, front + thickness / 2), Color = C.Stone, Material = M.Slate })
	part(model, { Name = "PedraChave", Size = Vector3.new(0.7, lintel + 0.25, thickness + 0.55), CFrame = cf * CFrame.new(0, 1 + doorHeight + lintel / 2 + 0.05, front + thickness / 2), Color = C.Stone:Lerp(Color3.new(1, 1, 1), 0.15), Material = M.Slate })
	part(model, { Name = "Soleira", Size = Vector3.new(doorWidth, 0.15, thickness), CFrame = cf * CFrame.new(0, 1.075, front + thickness / 2), Color = C.Stone, Material = M.Slate })
	-- porta de tábuas recuada no vão, com travessas, frestas, dobradiças e maçaneta
	local doorZ = front + 0.45
	local doorH = doorHeight - 0.15
	part(model, { Name = "Porta", Size = Vector3.new(doorWidth, doorH, 0.3), CFrame = cf * CFrame.new(0, 1.15 + doorH / 2, doorZ), Color = C.DarkWood, Material = M.WoodPlanks })
	for _, x in { -0.75, 0.75 } do
		part(model, { Name = "Fresta", Size = Vector3.new(0.06, doorH - 0.3, 0.05), CFrame = cf * CFrame.new(x, 1.15 + doorH / 2, doorZ - 0.17), Color = Color3.fromRGB(40, 28, 20), Material = M.Wood })
	end
	for _, y in { 2.2, 4.9 } do
		part(model, { Name = "Travessa", Size = Vector3.new(doorWidth - 0.2, 0.3, 0.1), CFrame = cf * CFrame.new(0, y, doorZ - 0.2), Color = C.Wood, Material = M.Wood })
		part(model, { Name = "Dobradica", Size = Vector3.new(1.0, 0.18, 0.06), CFrame = cf * CFrame.new(-doorWidth / 2 + 0.55, y, doorZ - 0.28), Color = Color3.fromRGB(45, 45, 50), Material = M.Metal })
	end
	part(model, { Name = "Macaneta", Size = Vector3.one * 0.3, Shape = Enum.PartType.Ball, CFrame = cf * CFrame.new(doorWidth / 2 - 0.45, 3.5, doorZ - 0.25), Color = C.Gold, Material = M.Metal })
	-- degrau e capacho na entrada
	part(model, { Name = "Degrau", Size = Vector3.new(doorWidth + 1, 0.5, 1.2), CFrame = cf * CFrame.new(0, 0.25, front - 1.1), Color = C.Stone, Material = M.Slate })
	part(model, { Name = "Capacho", Size = Vector3.new(doorWidth - 0.4, 0.08, 0.9), CFrame = cf * CFrame.new(0, 0.54, front - 1.1), Color = Color3.fromRGB(150, 60, 50), Material = M.Fabric, CanCollide = false })
	-- alpendre de duas águas sobre a porta, com mãos-francesas
	local hoodHalf, hoodAngle, hoodDepth = opening + 0.4, math.rad(20), 1.6
	local hoodZ = front - 0.15 - hoodDepth / 2
	local hoodBase = 1 + doorHeight + lintel + 0.15
	local hoodRise = math.tan(hoodAngle) * hoodHalf
	for _, side in { -1, 1 } do
		part(model, {
			Name = "Alpendre",
			Size = Vector3.new(hoodHalf / math.cos(hoodAngle) + 0.1, 0.22, hoodDepth),
			CFrame = cf * CFrame.new(side * hoodHalf / 2, hoodBase + hoodRise / 2 + 0.11, hoodZ) * CFrame.Angles(0, 0, -side * hoodAngle),
			Color = roofColor,
			Material = M.Slate,
		})
		part(model, { Name = "MaoFrancesa", Size = Vector3.new(0.22, 0.22, 1.6), CFrame = cf * CFrame.new(side * (hoodHalf - 0.2), hoodBase - 0.55, front - 0.55) * CFrame.Angles(math.rad(45), 0, 0), Color = C.DarkWood, Material = M.Wood })
	end
	part(model, { Name = "CumeeiraAlpendre", Size = Vector3.new(0.35, 0.3, hoodDepth + 0.1), CFrame = cf * CFrame.new(0, hoodBase + hoodRise + 0.2, hoodZ), Color = roofColor:Lerp(Color3.new(0, 0, 0), 0.3), Material = M.Slate })
	-- lampião ao lado da porta (acende à noite)
	part(model, { Name = "Suporte", Size = Vector3.new(0.15, 0.15, 0.8), CFrame = cf * CFrame.new(opening + 0.65, 5.6, front - 0.4), Color = Color3.fromRGB(40, 40, 45), Material = M.Metal })
	local doorLamp = part(model, { Name = "Lampiao", Size = Vector3.new(0.55, 0.75, 0.55), CFrame = cf * CFrame.new(opening + 0.65, 5.15, front - 0.7), Color = Color3.fromRGB(255, 210, 140), Material = M.Neon, CanCollide = false })
	part(model, { Name = "TampaLampiao", Size = Vector3.new(0.75, 0.15, 0.75), CFrame = cf * CFrame.new(opening + 0.65, 5.6, front - 0.7), Color = Color3.fromRGB(40, 40, 45), Material = M.Metal })
	Props.light(doorLamp, Color3.fromRGB(255, 200, 140), 14, 1.2)
	Props.nightLight(doorLamp)
	-- vigas de canto e cinta de madeira no alto das paredes (acima das janelas e do alpendre)
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			part(model, { Name = "Viga", Size = Vector3.new(1, wallHeight, 1), CFrame = cf * CFrame.new(x * width / 2, wallY, z * depth / 2), Color = C.DarkWood, Material = M.Wood })
		end
	end
	part(model, { Name = "Cinta", Size = Vector3.new(width + 0.25, 0.4, depth + 0.25), CFrame = cf * CFrame.new(0, wallHeight + 0.4, 0), Color = C.DarkWood, Material = M.Wood })
	local roofBase = cf * CFrame.new(0, 1 + wallHeight, 0) * CFrame.Angles(0, math.rad(90), 0)
	local rise = Props.roof(model, roofBase, depth, width, 32, roofColor)
	if rng and rng:NextNumber() < 0.7 then
		local chimney = part(model, { Name = "Chamine", Size = Vector3.new(1.6, rise + 3, 1.6), CFrame = cf * CFrame.new(width / 4, 1 + wallHeight + (rise + 3) / 2, depth / 4), Color = Color3.fromRGB(140, 80, 65), Material = M.Brick })
		part(model, { Name = "TampaChamine", Size = Vector3.new(2.1, 0.35, 2.1), CFrame = cf * CFrame.new(width / 4, 1 + wallHeight + rise + 3, depth / 4), Color = C.DarkStone, Material = M.Slate })
		Props.smoke(chimney, 1.5)
	end
	model.Parent = parent
	return model
end

-- Construção com interior: a porta fica em z = 0 (frente, -Z) e o salão vai para +Z.
-- Base com degrau na entrada, piso de tábuas, paredes com vão da porta, janelas com moldura,
-- vigas, telhado, luzes internas e chaminé opcional. Retorna o modelo.
-- options: doorWidth, doorHeight, floor ("planks", "stone", "checker"), floorColor, wallMaterial,
-- roofMaterial, trim (cor das vigas), timbered (vigas cruzadas de enxaimel), chimney (offset x),
-- lights (lista de posições locais)
function Props.building(parent, cf, width, depth, wallHeight, wallColor, roofColor, options)
	options = options or {}
	local model = Instance.new("Model")
	model.Name = options.name or "Construcao"
	local doorWidth = options.doorWidth or 4
	local doorHeight = options.doorHeight or 6.5
	local thickness = 0.8
	local wallMaterial = options.wallMaterial or M.WoodPlanks
	local trim = options.trim or C.DarkWood
	local center = cf * CFrame.new(0, 0, depth / 2)
	-- base de pedra + piso de tábuas
	part(model, { Name = "Base", Size = Vector3.new(width + 1.2, 1, depth + 1.2), CFrame = center * CFrame.new(0, 0.5, 0), Color = C.DarkStone, Material = M.Cobblestone })
	local floorKind = options.floor or "planks"
	if floorKind == "checker" then
		-- piso quadriculado (ladrilhos claros e escuros)
		local tile = 2.5
		local nx, nz = math.floor((width - thickness) / tile), math.floor((depth - thickness) / tile)
		for i = 0, nx - 1 do
			for j = 0, nz - 1 do
				local dark = (i + j) % 2 == 0
				part(model, { Name = "Ladrilho", Size = Vector3.new(tile, 0.2, tile), CFrame = center * CFrame.new(-nx * tile / 2 + (i + 0.5) * tile, 1.1, -nz * tile / 2 + (j + 0.5) * tile), Color = if dark then Color3.fromRGB(60, 55, 65) else Color3.fromRGB(235, 230, 220), Material = M.Marble })
			end
		end
	else
		part(model, { Name = "Piso", Size = Vector3.new(width - thickness, 0.2, depth - thickness), CFrame = center * CFrame.new(0, 1.1, 0), Color = options.floorColor or (if floorKind == "stone" then Color3.fromRGB(110, 105, 100) else C.Plank), Material = if floorKind == "stone" then M.Slate else M.WoodPlanks })
	end
	-- degrau e rampinha na entrada
	part(model, { Name = "Degrau", Size = Vector3.new(doorWidth + 1.5, 0.5, 1.6), CFrame = cf * CFrame.new(0, 0.25, -1.4), Color = C.Stone, Material = M.Cobblestone })
	local wallY = 1 + wallHeight / 2
	-- fundo
	part(model, { Name = "Parede", Size = Vector3.new(width, wallHeight, thickness), CFrame = cf * CFrame.new(0, wallY, depth - thickness / 2), Color = wallColor, Material = wallMaterial })
	-- laterais
	for _, side in { -1, 1 } do
		part(model, { Name = "Parede", Size = Vector3.new(thickness, wallHeight, depth), CFrame = center * CFrame.new(side * (width / 2 - thickness / 2), wallY, 0), Color = wallColor, Material = wallMaterial })
		-- rodapé de pedra por fora
		part(model, { Name = "Rodape", Size = Vector3.new(thickness + 0.3, 1.2, depth + 0.3), CFrame = center * CFrame.new(side * (width / 2 - thickness / 2), 1.6, 0), Color = C.Stone, Material = M.Cobblestone })
	end
	-- frente com vão da porta. Cada peça ocupa a sua faixa, sem sobreposição:
	-- vão (doorWidth) | batentes (jamb) | paredes até os cantos; verga de madeira em cima dos
	-- batentes e parede acima da verga. Isso evita faces brigando (o "tremido" na batente).
	local jamb, lintel = 0.6, 0.8
	local opening = doorWidth / 2 + jamb
	local sideWidth = width / 2 - opening
	for _, side in { -1, 1 } do
		local x = side * (opening + sideWidth / 2)
		part(model, { Name = "Parede", Size = Vector3.new(sideWidth, wallHeight, thickness), CFrame = cf * CFrame.new(x, wallY, thickness / 2), Color = wallColor, Material = wallMaterial })
		part(model, { Name = "Rodape", Size = Vector3.new(sideWidth, 1.2, thickness + 0.3), CFrame = cf * CFrame.new(x, 1.6, thickness / 2), Color = C.Stone, Material = M.Cobblestone })
		part(model, { Name = "Batente", Size = Vector3.new(jamb, doorHeight, thickness + 0.3), CFrame = cf * CFrame.new(side * (doorWidth / 2 + jamb / 2), 1 + doorHeight / 2, thickness / 2), Color = trim, Material = M.Wood })
		-- mísula embaixo da ponta da verga
		part(model, { Name = "Misula", Size = Vector3.new(0.45, 0.45, 0.65), CFrame = cf * CFrame.new(side * (opening + 0.2), 1 + doorHeight - 0.225, -0.325), Color = trim, Material = M.Wood })
	end
	local aboveDoor = wallHeight - doorHeight - lintel
	part(model, { Name = "Verga", Size = Vector3.new(opening * 2, aboveDoor, thickness), CFrame = cf * CFrame.new(0, 1 + doorHeight + lintel + aboveDoor / 2, thickness / 2), Color = wallColor, Material = wallMaterial })
	part(model, { Name = "VergaViga", Size = Vector3.new(opening * 2 + 0.8, lintel, thickness + 0.5), CFrame = cf * CFrame.new(0, 1 + doorHeight + lintel / 2, thickness / 2), Color = trim, Material = M.Wood })
	part(model, { Name = "Soleira", Size = Vector3.new(doorWidth, 0.25, thickness), CFrame = cf * CFrame.new(0, 1.125, thickness / 2), Color = C.Stone, Material = M.Slate })
	-- janelas com moldura e vidro (laterais e fundo)
	local function window(frame)
		part(model, { Name = "Moldura", Size = Vector3.new(3.2, 3.2, 0.3), CFrame = frame, Color = trim, Material = M.Wood })
		Props.nightWindow(part(model, { Name = "Vidro", Size = Vector3.new(2.6, 2.6, 0.35), CFrame = frame, Color = Color3.fromRGB(255, 225, 160), Material = M.Neon, Transparency = 0.2 }))
		part(model, { Name = "Cruz", Size = Vector3.new(0.2, 2.6, 0.4), CFrame = frame, Color = trim, Material = M.Wood })
		part(model, { Name = "Cruz", Size = Vector3.new(2.6, 0.2, 0.4), CFrame = frame, Color = trim, Material = M.Wood })
	end
	-- janelas da frente centradas na parede que sobra entre a verga e a viga de canto
	local frontX = (opening + 0.4 + width / 2 - 0.5) / 2
	local frontRoom = width / 2 - 0.5 - (opening + 0.4)
	for _, side in { -1, 1 } do
		for _, z in { depth * 0.3, depth * 0.72 } do
			window(cf * CFrame.new(side * (width / 2), wallY + 0.6, z) * CFrame.Angles(0, math.rad(90), 0))
		end
		if frontRoom >= 3.6 then
			window(cf * CFrame.new(side * frontX, wallY + 0.6, 0))
			part(model, { Name = "Peitoril", Size = Vector3.new(3.6, 0.25, 0.6), CFrame = cf * CFrame.new(side * frontX, wallY + 0.6 - 1.725, -0.3), Color = C.Stone, Material = M.Slate })
		end
	end
	window(cf * CFrame.new(0, wallY + 0.6, depth))
	-- vigas de canto e viga de topo
	for _, x in { -1, 1 } do
		for _, z in { 0, depth } do
			part(model, { Name = "Viga", Size = Vector3.new(1, wallHeight + 0.4, 1), CFrame = cf * CFrame.new(x * width / 2, wallY, z), Color = trim, Material = M.Wood })
		end
		part(model, { Name = "VigaTopo", Size = Vector3.new(0.8, 0.8, depth + 1), CFrame = center * CFrame.new(x * width / 2, 1 + wallHeight, 0), Color = trim, Material = M.Wood })
	end
	part(model, { Name = "VigaTopo", Size = Vector3.new(width + 1, 0.8, 0.8), CFrame = cf * CFrame.new(0, 1 + wallHeight, 0), Color = trim, Material = M.Wood })
	part(model, { Name = "VigaTopo", Size = Vector3.new(width + 1, 0.8, 0.8), CFrame = cf * CFrame.new(0, 1 + wallHeight, depth), Color = trim, Material = M.Wood })
	-- vigas do teto (vistas de dentro)
	for i = 1, 3 do
		part(model, { Name = "Caibro", Size = Vector3.new(width - 1, 0.5, 0.5), CFrame = cf * CFrame.new(0, wallHeight + 0.4, depth * i / 4), Color = trim, Material = M.Wood })
	end
	local roofBase = center * CFrame.new(0, 1 + wallHeight, 0) * CFrame.Angles(0, math.rad(90), 0)
	local rise = Props.roof(model, roofBase, depth + 1, width + 1, 30, roofColor)
	if options.roofMaterial then
		for _, roofPart in model:GetChildren() do
			if roofPart.Name == "Telhado" then
				roofPart.Material = options.roofMaterial
			end
		end
	end
	-- enxaimel: vigas cruzadas nas paredes laterais (por fora)
	if options.timbered then
		for _, sideX in { -1, 1 } do
			for _, zc in { depth * 0.18, depth * 0.5, depth * 0.82 } do
				part(model, { Name = "Enxaimel", Size = Vector3.new(0.3, 0.5, wallHeight * 0.95), CFrame = cf * CFrame.new(sideX * (width / 2 + 0.1), wallY, zc) * CFrame.Angles(math.rad(45), 0, 0), Color = trim, Material = M.Wood })
			end
			part(model, { Name = "Enxaimel", Size = Vector3.new(0.3, 0.5, depth), CFrame = center * CFrame.new(sideX * (width / 2 + 0.1), wallY - 0.5, 0), Color = trim, Material = M.Wood })
		end
	end
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

-- ===================== VIDA DA VILA (enfeites) =====================

-- Janela que acende à noite (vidro azulado de dia, luz quente à noite)
function Props.nightWindow(windowPart)
	windowPart:SetAttribute("OffColor", Color3.fromRGB(120, 150, 175))
	Props.nightLight(windowPart)
	return windowPart
end

-- Floreira com flores coloridas (embaixo de janelas e em canteiros)
function Props.flowerBox(parent, cf, width, rng)
	part(parent, { Name = "Floreira", Size = Vector3.new(width, 0.6, 0.8), CFrame = cf, Color = C.DarkWood, Material = M.WoodPlanks })
	part(parent, { Name = "Terra", Size = Vector3.new(width - 0.2, 0.1, 0.6), CFrame = cf * CFrame.new(0, 0.32, 0), Color = Color3.fromRGB(80, 55, 35), Material = M.Ground, CanCollide = false })
	local x = -width / 2 + 0.35
	while x < width / 2 - 0.2 do
		local color = Color3.fromHSV(rng:NextNumber(), 0.6, 1)
		Props.ball(parent, (cf * CFrame.new(x, 0.6 + rng:NextNumber(0, 0.2), 0)).Position, 0.45, color, M.SmoothPlastic, { CanCollide = false })
		part(parent, { Name = "Folha", Size = Vector3.new(0.35, 0.25, 0.35), CFrame = cf * CFrame.new(x + 0.2, 0.45, 0.1), Color = Color3.fromRGB(70, 150, 60), Material = M.Grass, CanCollide = false })
		x += rng:NextNumber(0.45, 0.7)
	end
end

-- Banco de praça (madeira com pés de ferro)
function Props.bench(parent, cf)
	local model = Instance.new("Model")
	model.Name = "Banco"
	for i = 0, 2 do
		part(model, { Name = "Ripa", Size = Vector3.new(4.5, 0.18, 0.4), CFrame = cf * CFrame.new(0, 1.1, -0.45 + i * 0.45), Color = C.Plank, Material = M.WoodPlanks })
	end
	for i = 0, 1 do
		part(model, { Name = "Encosto", Size = Vector3.new(4.5, 0.3, 0.15), CFrame = cf * CFrame.new(0, 1.55 + i * 0.4, 0.6) * CFrame.Angles(math.rad(-10), 0, 0), Color = C.Plank, Material = M.WoodPlanks })
	end
	for _, x in { -1.9, 1.9 } do
		part(model, { Name = "Pe", Size = Vector3.new(0.2, 1.1, 1.3), CFrame = cf * CFrame.new(x, 0.55, 0), Color = Color3.fromRGB(45, 45, 50), Material = M.Metal })
		part(model, { Name = "Apoio", Size = Vector3.new(0.2, 1.1, 0.2), CFrame = cf * CFrame.new(x, 1.7, 0.65) * CFrame.Angles(math.rad(-10), 0, 0), Color = Color3.fromRGB(45, 45, 50), Material = M.Metal })
	end
	model.Parent = parent
	return model
end

-- Poço com telhadinho, balde e manivela
function Props.well(parent, cf)
	local model = Instance.new("Model")
	model.Name = "Poco"
	Props.column(model, cf, 2.6, 5.4, C.Stone, M.Cobblestone)
	part(model, { Name = "Agua", Size = Vector3.new(0.2, 4.2, 4.2), Shape = Enum.PartType.Cylinder, CFrame = cf * CFrame.new(0, 2.2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(50, 110, 150), Material = M.Glass, Transparency = 0.2, CanCollide = false })
	for _, x in { -2.2, 2.2 } do
		part(model, { Name = "Poste", Size = Vector3.new(0.45, 5, 0.45), CFrame = cf * CFrame.new(x, 5, 0), Color = C.DarkWood, Material = M.Wood })
	end
	part(model, { Name = "Manivela", Size = Vector3.new(4.8, 0.35, 0.35), CFrame = cf * CFrame.new(0, 6.2, 0), Color = C.Wood, Material = M.Wood })
	part(model, { Name = "Corda", Size = Vector3.new(0.1, 2.4, 0.1), CFrame = cf * CFrame.new(0, 5, 0), Color = Color3.fromRGB(190, 160, 110), Material = M.Fabric })
	part(model, { Name = "Balde", Size = Vector3.new(0.8, 0.8, 0.8), CFrame = cf * CFrame.new(0, 3.6, 0), Color = Color3.fromRGB(120, 80, 50), Material = M.WoodPlanks })
	Props.roof(model, cf * CFrame.new(0, 7.4, 0), 5.6, 3.4, 30, C.Roof)
	model.Parent = parent
	return model
end

-- Barraca de feira com toldo e mercadorias (frutas, pães, peixes...)
local STALL_GOODS = {
	{ Color3.fromRGB(220, 40, 40), Color3.fromRGB(250, 170, 40), Color3.fromRGB(110, 200, 60) }, -- frutas
	{ Color3.fromRGB(215, 160, 90), Color3.fromRGB(190, 130, 70), Color3.fromRGB(235, 200, 140) }, -- pães
	{ Color3.fromRGB(150, 170, 190), Color3.fromRGB(120, 150, 180), Color3.fromRGB(170, 190, 210) }, -- peixes
	{ Color3.fromRGB(200, 60, 160), Color3.fromRGB(80, 160, 230), Color3.fromRGB(250, 220, 80) }, -- tecidos
}
function Props.marketStall(parent, cf, kind, awningColor)
	local model = Instance.new("Model")
	model.Name = "Barraca"
	part(model, { Name = "Balcao", Size = Vector3.new(6, 1.7, 2.2), CFrame = cf * CFrame.new(0, 0.85, 0), Color = C.Plank, Material = M.WoodPlanks })
	part(model, { Name = "Tampo", Size = Vector3.new(6.3, 0.25, 2.5), CFrame = cf * CFrame.new(0, 1.8, 0), Color = C.DarkWood, Material = M.Wood })
	for _, x in { -2.9, 2.9 } do
		for _, z in { -1.1, 1.1 } do
			part(model, { Name = "Poste", Size = Vector3.new(0.3, 5.4, 0.3), CFrame = cf * CFrame.new(x, 2.7, z), Color = C.DarkWood, Material = M.Wood })
		end
	end
	for i = 0, 5 do
		local color = if i % 2 == 0 then awningColor else Color3.fromRGB(245, 235, 220)
		part(model, { Name = "Toldo", Size = Vector3.new(1.08, 0.2, 3.4), CFrame = cf * CFrame.new(-2.7 + i * 1.08, 5.5, -0.2) * CFrame.Angles(math.rad(-14), 0, 0), Color = color, Material = M.Fabric })
		-- franja
		part(model, { Name = "Franja", Size = Vector3.new(1.0, 0.45, 0.08), CFrame = cf * CFrame.new(-2.7 + i * 1.08, 4.9, -1.85), Color = color, Material = M.Fabric, CanCollide = false })
	end
	local goods = STALL_GOODS[kind] or STALL_GOODS[1]
	for i = 0, 8 do
		local x = -2.4 + (i % 5) * 1.2
		local z = if i < 5 then -0.5 else 0.5
		local color = goods[i % #goods + 1]
		if kind == 3 then
			part(model, { Name = "Peixe", Size = Vector3.new(0.4, 0.3, 1.0), CFrame = cf * CFrame.new(x, 2.08, z) * CFrame.Angles(0, math.rad(20 * (i % 3 - 1)), 0), Color = color, Material = M.SmoothPlastic })
		elseif kind == 4 then
			part(model, { Name = "Tecido", Size = Vector3.new(0.9, 0.35, 0.8), CFrame = cf * CFrame.new(x, 2.08, z), Color = color, Material = M.Fabric })
		else
			for j = 0, 2 do
				Props.ball(model, (cf * CFrame.new(x + (j - 1) * 0.3, 2.15 + (if j == 1 then 0.2 else 0), z)).Position, 0.45, color, if kind == 2 then M.Sand else M.SmoothPlastic, { CanCollide = false })
			end
		end
	end
	Props.crate(model, cf * CFrame.new(3.6, 0, 1), 1.6)
	Props.barrel(model, cf * CFrame.new(-3.6, 0, 1))
	model.Parent = parent
	return model
end

-- Varal de bandeirinhas entre dois pontos (corda com triângulos coloridos)
function Props.bunting(parent, fromPos, toPos, sag)
	local model = Instance.new("Model")
	model.Name = "Bandeirinhas"
	local length = (toPos - fromPos).Magnitude
	local count = math.max(3, math.floor(length / 1.6))
	local colors = { Color3.fromRGB(230, 60, 60), Color3.fromRGB(250, 200, 50), Color3.fromRGB(70, 160, 230), Color3.fromRGB(100, 200, 90), Color3.fromRGB(240, 130, 200) }
	local previous = fromPos
	for i = 1, count do
		local t = i / count
		local point = fromPos:Lerp(toPos, t) - Vector3.new(0, math.sin(t * math.pi) * (sag or 1.5), 0)
		part(model, { Name = "Corda", Size = Vector3.new(0.08, 0.08, (point - previous).Magnitude), CFrame = CFrame.lookAt((point + previous) / 2, point), Color = Color3.fromRGB(230, 220, 200), Material = M.Fabric, CanCollide = false })
		if i < count then
			local flag = part(model, { Name = "Bandeira", Size = Vector3.new(0.05, 0.9, 0.8), CFrame = CFrame.lookAt(point, point + (toPos - fromPos).Unit) * CFrame.new(0, -0.45, 0) * CFrame.Angles(0, math.rad(90), math.rad(180)), Color = colors[i % #colors + 1], Material = M.Fabric, CanCollide = false })
			flag.Shape = Enum.PartType.Wedge
		end
		previous = point
	end
	model.Parent = parent
	return model
end

-- Carroça com feno e roda
function Props.cart(parent, cf)
	local model = Instance.new("Model")
	model.Name = "Carroca"
	part(model, { Name = "Caixa", Size = Vector3.new(3.4, 1.2, 5), CFrame = cf * CFrame.new(0, 2.1, 0), Color = C.Wood, Material = M.WoodPlanks })
	part(model, { Name = "Feno", Size = Vector3.new(3, 1.2, 4.4), CFrame = cf * CFrame.new(0, 3.1, 0), Color = Color3.fromRGB(220, 190, 90), Material = M.Fabric })
	for _, x in { -1.9, 1.9 } do
		for _, z in { -1.5, 1.5 } do
			part(model, { Name = "Roda", Size = Vector3.new(0.3, 2.2, 2.2), Shape = Enum.PartType.Cylinder, CFrame = cf * CFrame.new(x, 1.1, z), Color = C.DarkWood, Material = M.Wood })
		end
	end
	for _, x in { -0.6, 0.6 } do
		part(model, { Name = "Timao", Size = Vector3.new(0.2, 0.2, 3), CFrame = cf * CFrame.new(x, 1.6, -3.8) * CFrame.Angles(math.rad(10), 0, 0), Color = C.DarkWood, Material = M.Wood })
	end
	model.Parent = parent
	return model
end

-- Varal com roupas
function Props.laundry(parent, cf, rng)
	local model = Instance.new("Model")
	model.Name = "Varal"
	for _, x in { -4, 4 } do
		part(model, { Name = "Poste", Size = Vector3.new(0.3, 5, 0.3), CFrame = cf * CFrame.new(x, 2.5, 0), Color = C.DarkWood, Material = M.Wood })
	end
	part(model, { Name = "Corda", Size = Vector3.new(8, 0.06, 0.06), CFrame = cf * CFrame.new(0, 4.7, 0), Color = Color3.fromRGB(230, 220, 200), Material = M.Fabric, CanCollide = false })
	for i = 0, 3 do
		local w = rng:NextNumber(1.0, 1.5)
		local h = rng:NextNumber(1.2, 1.9)
		part(model, { Name = "Roupa", Size = Vector3.new(w, h, 0.06), CFrame = cf * CFrame.new(-2.8 + i * 1.85, 4.7 - h / 2, 0), Color = Color3.fromHSV(rng:NextNumber(), 0.45, 0.9), Material = M.Fabric, CanCollide = false })
	end
	model.Parent = parent
	return model
end

-- Galinheiro (casinha com rampa e cerquinha)
function Props.coop(parent, cf)
	local model = Instance.new("Model")
	model.Name = "Galinheiro"
	part(model, { Name = "Casinha", Size = Vector3.new(4, 3, 3.2), CFrame = cf * CFrame.new(0, 2.3, 0), Color = Color3.fromRGB(170, 90, 60), Material = M.WoodPlanks })
	for _, x in { -1.6, 1.6 } do
		for _, z in { -1.3, 1.3 } do
			part(model, { Name = "Pe", Size = Vector3.new(0.3, 0.8, 0.3), CFrame = cf * CFrame.new(x, 0.4, z), Color = C.DarkWood, Material = M.Wood })
		end
	end
	part(model, { Name = "Portinha", Size = Vector3.new(0.9, 1.1, 0.1), CFrame = cf * CFrame.new(0, 1.9, -1.62), Color = Color3.fromRGB(40, 25, 20) })
	part(model, { Name = "Rampa", Size = Vector3.new(0.9, 0.12, 2.2), CFrame = cf * CFrame.new(0, 0.7, -2.5) * CFrame.Angles(math.rad(28), 0, 0), Color = C.Plank, Material = M.WoodPlanks })
	Props.roof(model, cf * CFrame.new(0, 3.8, 0), 4.6, 3.6, 30, C.Roof)
	part(model, { Name = "Palha", Size = Vector3.new(5, 0.2, 4), CFrame = cf * CFrame.new(0, 0.1, -2), Color = Color3.fromRGB(220, 190, 100), Material = M.Fabric, CanCollide = false })
	model.Parent = parent
	return model
end

-- Estandarte pendurado (pano com borda e emblema)
function Props.banner(parent, cf, color)
	part(parent, { Name = "Mastro", Size = Vector3.new(2.4, 0.2, 0.2), CFrame = cf, Color = C.DarkWood, Material = M.Wood })
	part(parent, { Name = "Estandarte", Size = Vector3.new(2, 4, 0.1), CFrame = cf * CFrame.new(0, -2.1, 0), Color = color, Material = M.Fabric, CanCollide = false })
	part(parent, { Name = "Borda", Size = Vector3.new(2.05, 0.3, 0.12), CFrame = cf * CFrame.new(0, -4.0, 0), Color = C.Gold, Material = M.Fabric, CanCollide = false })
	Props.ball(parent, (cf * CFrame.new(0, -1.8, -0.08)).Position, 0.9, C.Gold, M.Metal, { CanCollide = false })
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
