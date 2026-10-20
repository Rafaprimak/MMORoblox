-- Constrói o mapa inteiro com blocos (modelagem "blocada" para testes).
-- Para trocar por arte final depois, basta substituir estas funções por modelos prontos.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Enemies = require(Shared.Enemies)

local MapBuilder = {}

local GROUND = Config.GroundY
local rng = Random.new(2026) -- semente fixa: o mapa sai sempre igual

local COLORS = {
	Grass = Color3.fromRGB(95, 170, 75),
	Stone = Color3.fromRGB(150, 150, 160),
	DarkStone = Color3.fromRGB(85, 85, 95),
	Path = Color3.fromRGB(175, 155, 115),
	Wood = Color3.fromRGB(110, 75, 45),
	DarkWood = Color3.fromRGB(70, 45, 28),
	Leaves = Color3.fromRGB(55, 135, 60),
	Portal = Color3.fromRGB(150, 70, 255),
	PortalBack = Color3.fromRGB(70, 160, 255),
	Gold = Color3.fromRGB(255, 200, 50),
	Fire = Color3.fromRGB(255, 120, 30),
}

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	if props.Shape then
		p.Shape = props.Shape
	end
	for key, value in props do
		if key ~= "Parent" and key ~= "Shape" then
			p[key] = value
		end
	end
	p.Parent = props.Parent
	return p
end

-- Disco plano (cilindro deitado) com o topo na altura topY
local function disc(parent, name, center, radius, thickness, color, material, topY)
	topY = topY or GROUND
	return part({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(thickness, radius * 2, radius * 2),
		CFrame = CFrame.new(center.X, topY - thickness / 2, center.Z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material or Enum.Material.Grass,
		Parent = parent,
	})
end

local function path(parent, from, to, width)
	local a = Vector3.new(from.X, GROUND - 0.15, from.Z)
	local b = Vector3.new(to.X, GROUND - 0.15, to.Z)
	return part({
		Name = "Caminho",
		Size = Vector3.new(width, 0.2, (b - a).Magnitude),
		CFrame = CFrame.lookAt((a + b) / 2, b),
		Color = COLORS.Path,
		Material = Enum.Material.Sand,
		Parent = parent,
	})
end

local function light(parentPart, color, range, brightness)
	local pointLight = Instance.new("PointLight")
	pointLight.Color = color
	pointLight.Range = range
	pointLight.Brightness = brightness or 1.5
	pointLight.Parent = parentPart
	return pointLight
end

local function textGui(board, face, title, subtitle, titleColor)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = board

	local titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.Position = UDim2.new(0, 10, 0.08, 0)
	titleLabel.Size = UDim2.new(1, -20, if subtitle then 0.52 else 0.84, 0)
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.TextScaled = true
	titleLabel.TextColor3 = titleColor or Color3.new(1, 1, 1)
	titleLabel.Text = title
	titleLabel.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Parent = titleLabel

	if subtitle then
		local subLabel = Instance.new("TextLabel")
		subLabel.BackgroundTransparency = 1
		subLabel.Position = UDim2.new(0, 10, 0.62, 0)
		subLabel.Size = UDim2.new(1, -20, 0.3, 0)
		subLabel.Font = Enum.Font.GothamBold
		subLabel.TextScaled = true
		subLabel.TextColor3 = Color3.fromRGB(230, 220, 200)
		subLabel.Text = subtitle
		subLabel.Parent = gui
	end
end

local function sign(parent, position, yaw, title, subtitle, titleColor)
	local base = CFrame.new(position.X, GROUND, position.Z) * CFrame.Angles(0, yaw or 0, 0)
	for _, x in { -5, 5 } do
		part({ Name = "Poste", Size = Vector3.new(0.7, 7, 0.7), CFrame = base * CFrame.new(x, 3.5, 0), Color = COLORS.Wood, Material = Enum.Material.Wood, Parent = parent })
	end
	local board = part({ Name = "Placa", Size = Vector3.new(14, 4.5, 0.5), CFrame = base * CFrame.new(0, 7, 0), Color = Color3.fromRGB(60, 40, 25), Material = Enum.Material.Wood, Parent = parent })
	textGui(board, Enum.NormalId.Front, title, subtitle, titleColor)
	textGui(board, Enum.NormalId.Back, title, subtitle, titleColor)
end

local function billboard(adornee, text, color, offsetY)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(240, 50)
	gui.StudsOffset = Vector3.new(0, offsetY or 4, 0)
	gui.MaxDistance = 120
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

local function prompt(parentPart, name, actionText, objectText)
	local proximityPrompt = Instance.new("ProximityPrompt")
	proximityPrompt.Name = name
	proximityPrompt.ActionText = actionText
	proximityPrompt.ObjectText = objectText
	proximityPrompt.HoldDuration = 0
	proximityPrompt.MaxActivationDistance = 12
	proximityPrompt.RequiresLineOfSight = false
	proximityPrompt.Parent = parentPart
	return proximityPrompt
end

local function yawTowards(direction)
	return math.atan2(-direction.X, -direction.Z)
end

local function tree(parent, position, height)
	part({ Name = "Tronco", Size = Vector3.new(1.6, height, 1.6), CFrame = CFrame.new(position.X, GROUND + height / 2, position.Z), Color = COLORS.Wood, Material = Enum.Material.Wood, Parent = parent })
	part({ Name = "Folhas", Size = Vector3.new(7, 5, 7), CFrame = CFrame.new(position.X, GROUND + height + 1.5, position.Z), Color = COLORS.Leaves, Material = Enum.Material.Grass, Parent = parent })
	part({ Name = "Folhas", Size = Vector3.new(4.5, 3, 4.5), CFrame = CFrame.new(position.X, GROUND + height + 5, position.Z), Color = COLORS.Leaves:Lerp(Color3.new(1, 1, 1), 0.12), Material = Enum.Material.Grass, Parent = parent })
end

local function randomPointInRing(center, minDistance, maxDistance)
	local angle = rng:NextNumber() * math.pi * 2
	local distance = rng:NextNumber(minDistance, maxDistance)
	return Vector3.new(center.X + math.cos(angle) * distance, GROUND, center.Z + math.sin(angle) * distance)
end

local function buildGround(parent)
	part({ Name = "Chao", Size = Vector3.new(800, 4, 800), CFrame = CFrame.new(0, -2, -150), Color = COLORS.Grass, Material = Enum.Material.Grass, Parent = parent })
	-- paredes invisíveis nas bordas
	local walls = {
		{ Vector3.new(0, 100, -550), Vector3.new(800, 200, 2) },
		{ Vector3.new(0, 100, 250), Vector3.new(800, 200, 2) },
		{ Vector3.new(-400, 100, -150), Vector3.new(2, 200, 800) },
		{ Vector3.new(400, 100, -150), Vector3.new(2, 200, 800) },
	}
	for _, wall in walls do
		part({ Name = "Limite", Size = wall[2], CFrame = CFrame.new(wall[1]), Transparency = 1, Parent = parent })
	end
end

local function buildHub(parent)
	disc(parent, "PracaBorda", Vector3.zero, 40, 1, COLORS.DarkStone, Enum.Material.Slate, GROUND - 0.05)
	disc(parent, "Praca", Vector3.zero, 37, 1, COLORS.Stone, Enum.Material.Cobblestone, GROUND)

	-- Spawn
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(10, 0.4, 10)
	spawn.CFrame = CFrame.new(Config.HubSpawn.X, GROUND + 0.2, Config.HubSpawn.Z)
	spawn.Color = Color3.fromRGB(90, 140, 255)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = parent

	-- Obelisco central
	local o = Vector3.new(0, GROUND, -8)
	part({ Name = "ObeliscoBase", Size = Vector3.new(8, 1.5, 8), CFrame = CFrame.new(o + Vector3.new(0, 0.75, 0)), Color = COLORS.DarkStone, Material = Enum.Material.Slate, Parent = parent })
	part({ Name = "Obelisco", Size = Vector3.new(3.5, 18, 3.5), CFrame = CFrame.new(o + Vector3.new(0, 10.5, 0)), Color = Color3.fromRGB(40, 40, 55), Material = Enum.Material.Slate, Parent = parent })
	for _, side in { -1, 1 } do
		part({ Name = "Runa", Size = Vector3.new(0.3, 14, 0.6), CFrame = CFrame.new(o + Vector3.new(side * 1.8, 10.5, 0)), Color = COLORS.Portal, Material = Enum.Material.Neon, Parent = parent })
	end
	local crystal = part({ Name = "Cristal", Size = Vector3.new(3, 3, 3), CFrame = CFrame.new(o + Vector3.new(0, 23, 0)) * CFrame.Angles(math.rad(45), 0, math.rad(45)), Color = COLORS.Portal, Material = Enum.Material.Neon, CanCollide = false, Parent = parent })
	light(crystal, COLORS.Portal, 30, 2)
	CollectionService:AddTag(crystal, "Spin")

	-- Baú do Hunter
	local c = Vector3.new(16, GROUND, 2)
	part({ Name = "Pedestal", Size = Vector3.new(6, 1.5, 5), CFrame = CFrame.new(c + Vector3.new(0, 0.75, 0)), Color = COLORS.DarkStone, Material = Enum.Material.Slate, Parent = parent })
	local chest = part({ Name = "Bau", Size = Vector3.new(4, 2.2, 2.8), CFrame = CFrame.new(c + Vector3.new(0, 2.6, 0)), Color = COLORS.Wood, Material = Enum.Material.Wood, Parent = parent })
	part({ Name = "Tampa", Size = Vector3.new(4.1, 0.9, 2.9), CFrame = CFrame.new(c + Vector3.new(0, 4.15, 0)), Color = COLORS.DarkWood, Material = Enum.Material.Wood, Parent = parent })
	for _, x in { -1.3, 1.3 } do
		part({ Name = "Faixa", Size = Vector3.new(0.4, 3.2, 3.0), CFrame = CFrame.new(c + Vector3.new(x, 3.0, 0)), Color = COLORS.Gold, Material = Enum.Material.Neon, Parent = parent })
	end
	part({ Name = "Fechadura", Size = Vector3.new(0.7, 0.8, 0.3), CFrame = CFrame.new(c + Vector3.new(0, 3.3, 1.5)), Color = COLORS.Gold, Material = Enum.Material.Neon, Parent = parent })
	light(chest, COLORS.Gold, 14, 1.5)
	billboard(chest, "🎁 BAÚ DO HUNTER", COLORS.Gold, 4.5)
	prompt(chest, "ChestPrompt", "Abrir", "Baú do Hunter")

	-- Forja
	local f = Vector3.new(-16, GROUND, 2)
	part({ Name = "BigornaBase", Size = Vector3.new(2.4, 1.6, 2), CFrame = CFrame.new(f + Vector3.new(0, 0.8, 0)), Color = Color3.fromRGB(45, 45, 50), Material = Enum.Material.Metal, Parent = parent })
	local anvil = part({ Name = "Bigorna", Size = Vector3.new(4, 1, 2), CFrame = CFrame.new(f + Vector3.new(0, 2.1, 0)), Color = Color3.fromRGB(70, 70, 78), Material = Enum.Material.Metal, Parent = parent })
	part({ Name = "Fornalha", Size = Vector3.new(5, 5, 4), CFrame = CFrame.new(f + Vector3.new(-1, 2.5, -5)), Color = Color3.fromRGB(110, 60, 50), Material = Enum.Material.Brick, Parent = parent })
	local fire = part({ Name = "Fogo", Size = Vector3.new(2.6, 1.8, 0.4), CFrame = CFrame.new(f + Vector3.new(-1, 1.8, -2.9)), Color = COLORS.Fire, Material = Enum.Material.Neon, Parent = parent })
	light(fire, COLORS.Fire, 16, 2)
	billboard(anvil, "🔨 FORJA", COLORS.Fire, 4)
	prompt(anvil, "ForgePrompt", "Aprimorar itens", "Forja")

	-- Mestre da Guilda (NPC)
	local n = Vector3.new(-9, GROUND, -16)
	local robe = Color3.fromRGB(50, 70, 160)
	for _, x in { -0.5, 0.5 } do
		part({ Name = "Perna", Size = Vector3.new(0.9, 2, 1), CFrame = CFrame.new(n + Vector3.new(x, 1, 0)), Color = Color3.fromRGB(40, 40, 60), Parent = parent })
	end
	local body = part({ Name = "Corpo", Size = Vector3.new(2.2, 2.4, 1.2), CFrame = CFrame.new(n + Vector3.new(0, 3.2, 0)), Color = robe, Parent = parent })
	for _, x in { -1.5, 1.5 } do
		part({ Name = "Braco", Size = Vector3.new(0.8, 2.2, 0.9), CFrame = CFrame.new(n + Vector3.new(x, 3.2, 0)), Color = robe, Parent = parent })
	end
	part({ Name = "Cabeca", Size = Vector3.new(1.4, 1.4, 1.4), CFrame = CFrame.new(n + Vector3.new(0, 5.1, 0)), Color = Color3.fromRGB(235, 190, 150), Parent = parent })
	part({ Name = "Chapeu", Size = Vector3.new(2.2, 0.3, 2.2), CFrame = CFrame.new(n + Vector3.new(0, 5.9, 0)), Color = Color3.fromRGB(30, 30, 50), Parent = parent })
	part({ Name = "Chapeu", Size = Vector3.new(1.2, 1.3, 1.2), CFrame = CFrame.new(n + Vector3.new(0, 6.6, 0)), Color = Color3.fromRGB(30, 30, 50), Parent = parent })
	billboard(body, "❗ Mestre da Guilda", Color3.fromRGB(255, 230, 80), 5.5)
	prompt(body, "GuildPrompt", "Falar", "Mestre da Guilda")

	-- Postes de luz
	for i = 0, 7 do
		local angle = math.rad(22.5 + i * 45)
		local pos = Vector3.new(math.cos(angle) * 34, GROUND, math.sin(angle) * 34)
		part({ Name = "Poste", Size = Vector3.new(0.6, 9, 0.6), CFrame = CFrame.new(pos + Vector3.new(0, 4.5, 0)), Color = Color3.fromRGB(35, 35, 40), Material = Enum.Material.Metal, Parent = parent })
		local lamp = part({ Name = "Lampada", Size = Vector3.new(1.4, 1.4, 1.4), CFrame = CFrame.new(pos + Vector3.new(0, 9.5, 0)), Color = Color3.fromRGB(255, 220, 150), Material = Enum.Material.Neon, Parent = parent })
		light(lamp, Color3.fromRGB(255, 210, 150), 20, 1.2)
	end

	sign(parent, Vector3.new(0, 0, 32), 0, "CIDADE DOS HUNTERS", "Baú à direita • Forja à esquerda", COLORS.Gold)
end

local function buildZones(parent)
	for _, zone in Enemies.Zones do
		if zone.isArena then
			continue
		end
		local material = if zone.id == "ruinas" then Enum.Material.Slate elseif zone.id == "floresta" then Enum.Material.LeafyGrass else Enum.Material.Grass
		disc(parent, zone.name, zone.center, zone.radius + 6, 1, zone.groundColor, material)

		-- placa virada para a cidade
		local toHub = Vector3.new(-zone.center.X, 0, -zone.center.Z).Unit
		local sideways = Vector3.new(-toHub.Z, 0, toHub.X)
		local signPos = zone.center + toHub * (zone.radius + 12) + sideways * 12 -- ao lado do caminho
		local def = Enemies.Defs[zone.enemy]
		sign(parent, signPos, yawTowards(toHub), string.upper(zone.name), ("%s Nv. %d • Recomendado Nv. %d+"):format(def.name, def.level, zone.minLevel))
	end
end

local function buildSlimeField(parent, zone)
	for _ = 1, 14 do
		local pos = randomPointInRing(zone.center, 12, zone.radius)
		local size = rng:NextNumber(2, 5)
		part({
			Name = "Pedra",
			Size = Vector3.new(size, size * 0.7, size * 1.2),
			CFrame = CFrame.new(pos + Vector3.new(0, size * 0.3, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), rng:NextNumber(-0.2, 0.2)),
			Color = Color3.fromRGB(130, 130, 135),
			Material = Enum.Material.Rock,
			Parent = parent,
		})
	end
	for _ = 1, 30 do
		local pos = randomPointInRing(zone.center, 4, zone.radius)
		local flowerColor = Color3.fromHSV(rng:NextNumber(), 0.6, 1)
		part({ Name = "Flor", Size = Vector3.new(0.6, 0.6, 0.6), CFrame = CFrame.new(pos + Vector3.new(0, 0.3, 0)), Color = flowerColor, Material = Enum.Material.Neon, CanCollide = false, Parent = parent })
	end
end

local function buildForest(parent, zone)
	for _ = 1, 40 do
		tree(parent, randomPointInRing(zone.center, 14, zone.radius + 4), rng:NextNumber(6, 11))
	end
end

local function buildRuins(parent, zone)
	local stone = Color3.fromRGB(120, 118, 112)
	for _ = 1, 22 do
		local pos = randomPointInRing(zone.center, 12, zone.radius)
		local height = rng:NextNumber(4, 14)
		part({ Name = "Pilar", Size = Vector3.new(2.5, height, 2.5), CFrame = CFrame.new(pos + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), Color = stone, Material = Enum.Material.Slate, Parent = parent })
	end
	for _ = 1, 6 do
		local pos = randomPointInRing(zone.center, 12, zone.radius)
		part({ Name = "PilarCaido", Size = Vector3.new(2.5, 2.5, rng:NextNumber(8, 12)), CFrame = CFrame.new(pos + Vector3.new(0, 1.25, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), Color = stone, Material = Enum.Material.Slate, Parent = parent })
	end
	for _ = 1, 5 do
		local pos = randomPointInRing(zone.center, 20, zone.radius)
		part({ Name = "Muro", Size = Vector3.new(10, rng:NextNumber(3, 6), 1.5), CFrame = CFrame.new(pos + Vector3.new(0, 2, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), Color = stone:Lerp(Color3.new(0, 0, 0), 0.15), Material = Enum.Material.Brick, Parent = parent })
	end
end

local function portalFrame(parent, center, innerName, innerColor)
	part({ Name = "Plataforma", Size = Vector3.new(24, 1, 10), CFrame = CFrame.new(center + Vector3.new(0, 0.5, 0)), Color = COLORS.DarkStone, Material = Enum.Material.Slate, Parent = parent })
	for _, x in { -7, 7 } do
		part({ Name = "Coluna", Size = Vector3.new(3, 18, 3), CFrame = CFrame.new(center + Vector3.new(x, 10, 0)), Color = Color3.fromRGB(45, 40, 60), Material = Enum.Material.Slate, Parent = parent })
	end
	part({ Name = "Arco", Size = Vector3.new(17, 3, 3), CFrame = CFrame.new(center + Vector3.new(0, 20.5, 0)), Color = Color3.fromRGB(45, 40, 60), Material = Enum.Material.Slate, Parent = parent })
	local inner = part({ Name = innerName, Size = Vector3.new(11, 17, 0.6), CFrame = CFrame.new(center + Vector3.new(0, 9.5, 0)), Color = innerColor, Material = Enum.Material.Neon, Transparency = 0.25, CanCollide = false, Parent = parent })
	light(inner, innerColor, 25, 2)
	local particles = Instance.new("ParticleEmitter")
	particles.Color = ColorSequence.new(innerColor)
	particles.LightEmission = 1
	particles.Size = NumberSequence.new(0.6, 0)
	particles.Lifetime = NumberRange.new(1, 2)
	particles.Rate = 25
	particles.Speed = NumberRange.new(1, 3)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.Parent = inner
	return inner
end

local function buildArena(parent, zone)
	local c = zone.center
	disc(parent, "ArenaChao", c, zone.radius + 8, 6, Color3.fromRGB(70, 45, 45), Enum.Material.Slate)
	local wallRadius = zone.radius + 6
	for i = 0, 23 do
		local angle = i / 24 * math.pi * 2
		local pos = Vector3.new(c.X + math.cos(angle) * wallRadius, GROUND + 5, c.Z + math.sin(angle) * wallRadius)
		part({ Name = "Muralha", Size = Vector3.new(15, 10, 2.5), CFrame = CFrame.lookAt(pos, Vector3.new(c.X, pos.Y, c.Z)), Color = Color3.fromRGB(60, 50, 50), Material = Enum.Material.Brick, Parent = parent })
	end
	for i = 0, 7 do
		local angle = (i + 0.5) / 8 * math.pi * 2
		local pos = Vector3.new(c.X + math.cos(angle) * (wallRadius - 3), GROUND, c.Z + math.sin(angle) * (wallRadius - 3))
		part({ Name = "Tocha", Size = Vector3.new(1, 7, 1), CFrame = CFrame.new(pos + Vector3.new(0, 3.5, 0)), Color = COLORS.DarkWood, Material = Enum.Material.Wood, Parent = parent })
		local flame = part({ Name = "Chama", Size = Vector3.new(1.3, 1.3, 1.3), CFrame = CFrame.new(pos + Vector3.new(0, 7.6, 0)), Color = COLORS.Fire, Material = Enum.Material.Neon, CanCollide = false, Parent = parent })
		light(flame, COLORS.Fire, 22, 2)
	end
	return portalFrame(parent, Vector3.new(c.X, GROUND, c.Z + zone.radius - 4), "PortalSaida", COLORS.PortalBack)
end

function MapBuilder.build()
	local map = Instance.new("Folder")
	map.Name = "Mapa"

	buildGround(map)
	buildHub(map)
	buildZones(map)

	local zones = {}
	for _, zone in Enemies.Zones do
		zones[zone.id] = zone
	end

	path(map, Vector3.new(0, 0, -30), Vector3.new(0, 0, -335), 10)
	path(map, Vector3.new(20, 0, -25), zones.floresta.center, 8)
	path(map, Vector3.new(-20, 0, -25), zones.ruinas.center, 8)

	buildSlimeField(map, zones.campo)
	buildForest(map, zones.floresta)
	buildRuins(map, zones.ruinas)

	local portalIn = portalFrame(map, Vector3.new(0, GROUND, -340), "PortalEntrada", COLORS.Portal)
	sign(map, Vector3.new(15, 0, -326), math.pi, "PORTAL DO REI GOBLIN", ("Requer Nível %d • Chefe Nv. 15"):format(Config.PortalLevel), Color3.fromRGB(255, 120, 255))
	local portalOut = buildArena(map, zones.arena)

	map.Parent = workspace
	return { portalIn = portalIn, portalOut = portalOut }
end

return MapBuilder
