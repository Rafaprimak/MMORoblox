-- Raide "Coração da Estrela": até 8 jogadores contra o Devorador de Estrelas numa arena longe do mapa.
--   * Portal no mapa (perto da Passagem do Norte) abre a janela da raide; sala com Pronto (como a masmorra).
--   * Fases pela vida do chefe (Raids.Phases): chuva de estrelas (círculos no chão debaixo dos jogadores,
--     dano imbloqueável), servos saindo das bordas e fúria (mais dano, estrelas mais rápidas).
--   * Quem morre volta para a arena. Tempo limite: Raids.TimeLimit.
--   * Prêmio semanal (uma vez por semana por jogador, data.raidWeek): baú Real, item Lendário+ e ouro.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Raids = require(Shared.Raids)
local World = require(Shared.World)
local Enemies = require(Shared.Enemies)
local Items = require(Shared.Items)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local PlayerService = require(script.Parent.PlayerService)
local EnemyService = require(script.Parent.EnemyService)
local LootService = require(script.Parent.LootService)
local ShopService = require(script.Parent.ShopService)
local AntiCheat = require(script.Parent.AntiCheat)
local Props = require(script.Parent.WorldGen.Props)

local RaidService = {}

RaidService.QuestHook = function(_player, _kind, _target, _amount) end

local ORIGIN = Vector3.new(12000, 300, 0)
local ARENA_RADIUS = 70
local COUNTDOWN = 5

local lobby = { members = {}, ready = {}, startsAt = nil }
local run = nil -- raide em andamento (uma por servidor)
local arena = nil

local function rootOf(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function portalPosition()
	return Vector3.new(Raids.PortalX, Raids.PortalY, Raids.PortalZ)
end

local function nearPortal(player)
	local root = rootOf(player)
	return root ~= nil and (root.Position - portalPosition()).Magnitude < 40
end

local function markAll(list)
	for _, player in list do
		PlayerService.markDirty(player)
	end
end

local function notify(list, message)
	for _, player in list do
		Remotes.Notify:FireClient(player, message)
	end
end

local function members()
	local list = {}
	if run then
		for player in run.members do
			table.insert(list, player)
		end
	end
	return list
end

-- ===================== MUNDO: PORTAL E ARENA =====================

local function part(parent, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		p[key] = value
	end
	p.Parent = parent
	return p
end

local STAR = Color3.fromRGB(255, 236, 170)
local MAGENTA = Color3.fromRGB(255, 110, 225)
local VIOLET = Color3.fromRGB(150, 70, 255)
local CYAN = Color3.fromRGB(120, 225, 255)
local SPACE_ROCK = Color3.fromRGB(52, 40, 66)

local function light(parentPart, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Parent = parentPart
	return l
end

local function sparkles(parentPart, color, rate)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	emitter.Lifetime = NumberRange.new(1.5, 3)
	emitter.Rate = rate
	emitter.Speed = NumberRange.new(1, 4)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = parentPart
	return emitter
end

-- cristal facetado (três peças giradas) com núcleo de luz
local function crystal(parent, cf, height, color)
	for k = 0, 2 do
		part(parent, { Name = "Cristal", Size = Vector3.new(height * 0.28, height * (1 - k * 0.2), height * 0.28), CFrame = cf * CFrame.Angles(0, k * 2.1, 0) * CFrame.new(k * 0.4, height * (1 - k * 0.2) / 2, 0) * CFrame.Angles(0.12 * k, 0, 0.1 * (k - 1)), Color = color, Material = Enum.Material.Glass, Transparency = 0.15 })
	end
	local core = part(parent, { Name = "Nucleo", Size = Vector3.new(height * 0.12, height * 0.6, height * 0.12), CFrame = cf * CFrame.new(0, height * 0.4, 0), Color = color, Material = Enum.Material.Neon, CanCollide = false })
	return core
end

-- ===================== PORTAL: A ESTRELA CAÍDA =====================
local function buildPortal()
	local model = Instance.new("Model")
	model.Name = "EstrelaCaida"
	local base = CFrame.new(portalPosition())
	-- chão queimado da cratera e borda de rochas viradas para fora
	part(model, { Name = "Cratera", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 40, 40), CFrame = base * CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(30, 24, 36), Material = Enum.Material.Basalt })
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		local h = 4 + (i % 3) * 2.5
		part(model, { Name = "Borda", Size = Vector3.new(6, h, 3), CFrame = base * CFrame.Angles(0, a, 0) * CFrame.new(0, h / 2 - 1, -20) * CFrame.Angles(math.rad(-35), 0, 0), Color = SPACE_ROCK:Lerp(Color3.new(0, 0, 0), (i % 2) * 0.2), Material = Enum.Material.Basalt })
	end
	-- rachaduras de luz saindo do meteoro
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2 + 0.2
		part(model, { Name = "Rachadura", Size = Vector3.new(0.5, 0.12, 9 + (i % 3) * 3), CFrame = base * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.66, -8), Color = if i % 2 == 0 then MAGENTA else VIOLET, Material = Enum.Material.Neon, CanCollide = false })
	end
	-- o meteoro: núcleo de estrela dentro de uma casca de cristal, meio enterrado
	local core = part(model, { Name = "Meteoro", Shape = Enum.PartType.Ball, Size = Vector3.one * 9, CFrame = base * CFrame.new(0, 2.5, 4), Color = STAR, Material = Enum.Material.Neon })
	part(model, { Name = "Casca", Shape = Enum.PartType.Ball, Size = Vector3.one * 12, CFrame = base * CFrame.new(0, 2.5, 4), Color = VIOLET, Material = Enum.Material.Glass, Transparency = 0.55, CanCollide = false })
	light(core, STAR, 60, 3)
	sparkles(core, STAR, 18)
	-- cristais flutuando em volta (giram)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		local shard = part(model, { Name = "Estilhaco", Size = Vector3.new(1.6, 4.5, 1.6), CFrame = base * CFrame.new(math.cos(a) * 11, 9 + (i % 3) * 3, 4 + math.sin(a) * 11) * CFrame.Angles(0.4, a, 0.3), Color = if i % 2 == 0 then CYAN else MAGENTA, Material = Enum.Material.Neon, CanCollide = false })
		CollectionService:AddTag(shard, "Spin")
	end
	-- feixe até o céu (dá para ver de qualquer canto do mapa)
	part(model, { Name = "Feixe", Shape = Enum.PartType.Cylinder, Size = Vector3.new(700, 5, 5), CFrame = base * CFrame.new(0, 350, 4) * CFrame.Angles(0, 0, math.rad(90)), Color = MAGENTA, Material = Enum.Material.Neon, Transparency = 0.45, CanCollide = false, CastShadow = false })
	part(model, { Name = "FeixeExterno", Shape = Enum.PartType.Cylinder, Size = Vector3.new(700, 11, 11), CFrame = base * CFrame.new(0, 350, 4) * CFrame.Angles(0, 0, math.rad(90)), Color = VIOLET, Material = Enum.Material.Neon, Transparency = 0.8, CanCollide = false, CastShadow = false })
	-- a fenda: anel vertical de cristais com o vórtice dentro (o prompt fica nele)
	local rift = base * CFrame.new(0, 0, -12)
	for i = 0, 19 do
		local a = i / 20 * math.pi * 2
		part(model, { Name = "Fenda", Size = Vector3.new(1.6, 3.2, 1.6), CFrame = rift * CFrame.new(math.cos(a) * 7.5, 9 + math.sin(a) * 9, 0) * CFrame.Angles(0, 0, a), Color = if i % 2 == 0 then VIOLET else CYAN, Material = Enum.Material.Neon, CanCollide = false })
	end
	local swirl = part(model, { Name = "Vortice", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 14, 14), CFrame = rift * CFrame.new(0, 9, 0) * CFrame.Angles(0, math.rad(90), 0) * CFrame.new(0, 0, 0), Color = Color3.fromRGB(40, 10, 70), Material = Enum.Material.Neon, Transparency = 0.25, CanCollide = false })
	swirl.Size = Vector3.new(0.4, 14, 18)
	light(swirl, VIOLET, 35, 2.5)
	sparkles(swirl, MAGENTA, 25)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PortalRaide"
	prompt.ActionText = "Atravessar a fenda"
	prompt.ObjectText = ("RAIDE: %s (nível %d+)"):format(Raids.Name, Raids.MinLevel)
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 18
	prompt.RequiresLineOfSight = false
	prompt.Parent = swirl
	local signX, signZ = portalPosition().X + 26, portalPosition().Z + 4
	Props.signpost(model, CFrame.new(signX, World.height(signX, signZ), signZ) * CFrame.Angles(0, math.rad(-90), 0), "Estrela Caída", ("%s\n\nRaide: nível %d+, de 2 a %d Hunters."):format(Raids.Text, Raids.MinLevel, Raids.MaxPlayers), Color3.fromRGB(255, 190, 245))
	local mundo = workspace:FindFirstChild("Mundo")
	-- sempre presente em todos os clientes: o feixe da estrela caída é visto de todo o mapa
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	model.Parent = mundo or workspace
end

-- ===================== ARENA: ILHA FLUTUANDO NO ESPAÇO =====================
local function buildArena()
	if arena then
		return arena
	end
	local model = Instance.new("Model")
	model.Name = "ArenaRaide"
	local center = CFrame.new(ORIGIN)
	local rng = Random.new(1999)
	-- piso de vidro estelar
	part(model, { Name = "Piso", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, ARENA_RADIUS * 2, ARENA_RADIUS * 2), CFrame = center * CFrame.new(0, -1.5, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(28, 22, 52), Material = Enum.Material.Glass })
	-- raiz de rocha flutuante (camadas afinando para baixo) com estalactites de cristal
	local radius, y = ARENA_RADIUS - 1, -3
	for layer = 1, 6 do
		local height = 7
		part(model, { Name = "Raiz", Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, radius * 2, radius * 2), CFrame = center * CFrame.new(rng:NextNumber(-3, 3), y - height / 2, rng:NextNumber(-3, 3)) * CFrame.Angles(0, 0, math.rad(90)), Color = SPACE_ROCK:Lerp(Color3.new(0, 0, 0), layer * 0.06), Material = Enum.Material.Rock })
		y -= height - 1
		radius *= 0.72
	end
	for i = 1, 14 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(10, ARENA_RADIUS - 12)
		local h = rng:NextNumber(8, 22)
		part(model, { Name = "Estalactite", Size = Vector3.new(2, h, 2), CFrame = center * CFrame.new(math.cos(a) * r, -4 - h / 2 - (1 - r / ARENA_RADIUS) * 18, math.sin(a) * r) * CFrame.Angles(0, a, math.rad(180)), Color = if i % 2 == 0 then MAGENTA else CYAN, Material = Enum.Material.Neon, CanCollide = false })
	end
	-- constelações no piso: estrelas ligadas por linhas de luz
	for _ = 1, 7 do
		local points = {}
		local origin = Vector2.new(rng:NextNumber(-48, 48), rng:NextNumber(-48, 48))
		for k = 1, rng:NextInteger(4, 6) do
			local point = origin + Vector2.new(rng:NextNumber(-12, 12), rng:NextNumber(-12, 12))
			points[k] = point
			part(model, { Name = "Estrela", Shape = Enum.PartType.Ball, Size = Vector3.one * rng:NextNumber(0.8, 1.4), CFrame = center * CFrame.new(point.X, 0.05, point.Y), Color = STAR, Material = Enum.Material.Neon, CanCollide = false })
		end
		for k = 1, #points - 1 do
			local a, b = points[k], points[k + 1]
			local mid = (a + b) / 2
			local length = (b - a).Magnitude
			part(model, { Name = "Linha", Size = Vector3.new(0.18, 0.08, length), CFrame = center * CFrame.new(mid.X, 0.04, mid.Y) * CFrame.Angles(0, math.atan2(-(b.X - a.X), -(b.Y - a.Y)), 0), Color = CYAN, Material = Enum.Material.Neon, Transparency = 0.35, CanCollide = false })
		end
	end
	-- selo no centro: anel e estrela de oito pontas
	part(model, { Name = "Selo", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 34, 34), CFrame = center * CFrame.new(0, 0.06, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = MAGENTA, Material = Enum.Material.Neon, Transparency = 0.55, CanCollide = false })
	part(model, { Name = "SeloInterno", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 30, 30), CFrame = center * CFrame.new(0, 0.07, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(28, 22, 52), Material = Enum.Material.Glass, CanCollide = false })
	for k = 0, 1 do
		part(model, { Name = "EstrelaSelo", Size = Vector3.new(18, 0.1, 18), CFrame = center * CFrame.new(0, 0.09, 0) * CFrame.Angles(0, math.rad(45 * k), 0), Color = VIOLET, Material = Enum.Material.Neon, Transparency = 0.5, CanCollide = false })
	end
	-- borda de cristais e muro invisível (ninguém cai)
	local segments = 28
	for i = 0, segments - 1 do
		local a = i / segments * math.pi * 2
		local frame = center * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -ARENA_RADIUS)
		part(model, { Name = "Muro", Size = Vector3.new(2 * ARENA_RADIUS * math.tan(math.pi / segments) + 1, 40, 2), CFrame = frame * CFrame.new(0, 20, 0), Transparency = 1 })
		part(model, { Name = "Borda", Size = Vector3.new(3, rng:NextNumber(2, 6), 2.4), CFrame = frame * CFrame.new(0, 1, 1) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), 0, rng:NextNumber(-0.3, 0.3)), Color = if i % 2 == 0 then VIOLET else CYAN, Material = Enum.Material.Glass, Transparency = 0.2 })
		-- pilares de cristal com orbe flutuante
		if i % 4 == 0 then
			local pillarCf = frame * CFrame.new(0, 0, 5)
			crystal(model, pillarCf, 20, if i % 8 == 0 then MAGENTA else CYAN)
			local orb = part(model, { Name = "Orbe", Shape = Enum.PartType.Ball, Size = Vector3.one * 3, CFrame = pillarCf * CFrame.new(0, 25, 0), Color = STAR, Material = Enum.Material.Neon, CanCollide = false })
			light(orb, STAR, 60, 3)
		end
	end
	-- "lua" estelar em cima do centro e anel de luzes no alto: a arena inteira bem iluminada
	local moon = part(model, { Name = "LuaEstelar", Shape = Enum.PartType.Ball, Size = Vector3.one * 10, CFrame = center * CFrame.new(0, 55, 0), Color = STAR, Material = Enum.Material.Neon, CanCollide = false, CastShadow = false })
	light(moon, STAR, 60, 4)
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		local lamp = part(model, { Name = "LuzDoAlto", Shape = Enum.PartType.Ball, Size = Vector3.one * 2, CFrame = center * CFrame.new(math.cos(a) * 38, 30, math.sin(a) * 38), Color = if k % 2 == 0 then CYAN else MAGENTA, Material = Enum.Material.Neon, CanCollide = false, CastShadow = false })
		light(lamp, Color3.fromRGB(230, 220, 255), 60, 2.5)
	end
	-- asteroides girando em volta e planetas ao longe
	for i = 1, 26 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(110, 230)
		local size = rng:NextNumber(5, 20)
		local rock = part(model, { Name = "Asteroide", Size = Vector3.new(size, size * rng:NextNumber(0.6, 1), size * rng:NextNumber(0.7, 1.2)), CFrame = center * CFrame.new(math.cos(a) * r, rng:NextNumber(-60, 70), math.sin(a) * r) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0), Color = SPACE_ROCK:Lerp(VIOLET, rng:NextNumber(0, 0.2)), Material = Enum.Material.Rock, CanCollide = false, CastShadow = false })
		if i % 3 == 0 then
			CollectionService:AddTag(rock, "Spin")
		end
	end
	for _, planet in { { 520, 160, -300, 140, Color3.fromRGB(120, 70, 200) }, { -480, 60, 360, 90, Color3.fromRGB(70, 150, 220) }, { 200, 260, 560, 60, Color3.fromRGB(255, 150, 90) } } do
		local cf = center * CFrame.new(planet[1], planet[2], planet[3])
		part(model, { Name = "Planeta", Shape = Enum.PartType.Ball, Size = Vector3.one * planet[4], CFrame = cf, Color = planet[5], Material = Enum.Material.SmoothPlastic, CanCollide = false, CastShadow = false })
		part(model, { Name = "Anel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, planet[4] * 1.8, planet[4] * 1.8), CFrame = cf * CFrame.Angles(0.4, 0, math.rad(80)), Color = planet[5]:Lerp(Color3.new(1, 1, 1), 0.4), Material = Enum.Material.Neon, Transparency = 0.6, CanCollide = false, CastShadow = false })
	end
	local container = workspace:FindFirstChild("Masmorras") or workspace
	model.Parent = container
	arena = model
	return model
end

-- ===================== LUTA =====================

local function arrival()
	return CFrame.new(ORIGIN + Vector3.new(math.random(-8, 8), 4, ARENA_RADIUS - 14))
end

local function teleport(player, cf)
	local character = player.Character
	if character and character:FindFirstChild("HumanoidRootPart") then
		AntiCheat.allowTeleport(player, 3, cf.Position)
		character:PivotTo(cf)
	end
end

local function finish(won)
	local current = run
	if not current then
		return
	end
	run = nil
	EnemyService.clearCamp(current.camp)
	local list = {}
	for player in current.members do
		table.insert(list, player)
	end
	notify(list, {
		kind = "banner",
		text = if won then "O DEVORADOR CAIU!" else "O TEMPO ACABOU...",
		sub = if won then "Voltando ao mundo em 20 segundos" else "A estrela se apagou. Tentem de novo!",
		color = if won then Color3.fromRGB(255, 215, 90) else Color3.fromRGB(200, 160, 220),
		duration = 6,
	})
	task.delay(if won then 20 else 4, function()
		for _, player in list do
			player:SetAttribute("Raid", nil)
			if player.Parent == Players then
				teleport(player, CFrame.new(portalPosition() + Vector3.new(0, 4, 14)))
				PlayerService.markDirty(player)
			end
		end
	end)
	markAll(list)
end

local function meteor(current, target)
	local root = rootOf(target)
	if not root then
		return
	end
	local position = Vector3.new(root.Position.X, ORIGIN.Y, root.Position.Z)
	local radius = 9
	Remotes.Fx:FireAllClients("telegraph", "circle", position, radius, current.meteorWindup)
	task.delay(current.meteorWindup, function()
		if run ~= current then
			return
		end
		Remotes.Fx:FireAllClients("explosion", position, radius, "fire")
		for player in current.members do
			local other = rootOf(player)
			if other and (Vector3.new(other.Position.X, ORIGIN.Y, other.Position.Z) - position).Magnitude <= radius then
				PlayerService.damagePlayer(player, current.meteorDamage, position, { unblockable = true })
			end
		end
	end)
end

local function spawnAdds(current)
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		local spot = ORIGIN + Vector3.new(math.cos(a) * (ARENA_RADIUS - 12), 0, math.sin(a) * (ARENA_RADIUS - 12))
		EnemyService.spawn(current.camp, if i % 3 == 0 then "golem" else "esqueleto_mago", { position = spot, levelBonus = 8, hpMult = 0.6 + 0.15 * current.size })
	end
end

-- Abre a fenda com a sala inteira ou, com soloPlayer (botão "Entrar sozinho"), só com esse jogador.
local function launch(soloPlayer)
	local group = {}
	for _, player in if soloPlayer then { soloPlayer } else lobby.members do
		if player.Parent == Players and player.Character then
			table.insert(group, player)
		end
	end
	if not soloPlayer then
		lobby = { members = {}, ready = {}, startsAt = nil }
	end
	if #group == 0 or run then
		return
	end
	buildArena()
	local camp = {
		id = "raide",
		center = Vector2.new(ORIGIN.X, ORIGIN.Z),
		radius = ARENA_RADIUS - 10,
		floorY = ORIGIN.Y,
		bounds = { ORIGIN.X - ARENA_RADIUS + 8, ORIGIN.X + ARENA_RADIUS - 8, ORIGIN.Z - ARENA_RADIUS + 8, ORIGIN.Z + ARENA_RADIUS - 8 },
		dungeon = true,
		raid = true,
	}
	local current = {
		members = {},
		camp = camp,
		size = #group,
		started = os.clock(),
		ends = workspace:GetServerTimeNow() + Raids.TimeLimit,
		phase = 0,
		meteorEvery = 7,
		meteorWindup = 2,
		meteorDamage = 95,
		nextMeteor = os.clock() + 10,
	}
	run = current
	for _, player in group do
		current.members[player] = true
		player:SetAttribute("Raid", true)
		player:SetAttribute("AutoFarm", false)
		teleport(player, arrival())
	end
	current.boss = EnemyService.spawn(camp, Raids.Boss, { position = ORIGIN + Vector3.new(0, 0, -20), hpMult = Raids.hpMult(#group), levelBonus = 0 })
	notify(group, { kind = "banner", text = "O DEVORADOR DE ESTRELAS DESPERTOU!", sub = "Tanque na frente, suporte atrás, e saiam dos círculos vermelhos!", color = Color3.fromRGB(190, 120, 255), duration = 5 })
	markAll(group)
end

-- ===================== PEDIDOS =====================

function RaidService.join(player)
	local data = DataService.get(player)
	if not data then
		return { ok = false }
	end
	if run then
		return { ok = false, msg = "Já tem um grupo lutando na raide. Espere terminar." }
	end
	if not nearPortal(player) then
		return { ok = false, msg = "Chegue perto do portal da raide." }
	end
	-- no Studio o nível não trava (para testar)
	if data.level < Raids.MinLevel and not RunService:IsStudio() then
		return { ok = false, msg = ("A raide libera no nível %d (você está no %d)."):format(Raids.MinLevel, data.level) }
	end
	if player:GetAttribute("Dungeon") then
		return { ok = false, msg = "Saia da masmorra primeiro." }
	end
	if table.find(lobby.members, player) then
		return { ok = true }
	end
	if #lobby.members >= Raids.MaxPlayers then
		return { ok = false, msg = "A sala está cheia (8)." }
	end
	table.insert(lobby.members, player)
	markAll(lobby.members)
	return { ok = true }
end

-- Entra sozinho na hora (a vida do chefe cai pelo tamanho do grupo: Raids.hpMult(1)).
function RaidService.solo(player)
	local data = DataService.get(player)
	if not data then
		return { ok = false }
	end
	if run then
		return { ok = false, msg = "Já tem um grupo lutando na raide. Espere terminar." }
	end
	if not nearPortal(player) then
		return { ok = false, msg = "Chegue perto do portal da raide." }
	end
	if data.level < Raids.MinLevel and not RunService:IsStudio() then
		return { ok = false, msg = ("A raide libera no nível %d (você está no %d)."):format(Raids.MinLevel, data.level) }
	end
	if player:GetAttribute("Dungeon") or player:GetAttribute("Arena") then
		return { ok = false, msg = "Termine a luta atual primeiro." }
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return { ok = false, msg = "Você precisa estar vivo." }
	end
	local index = table.find(lobby.members, player)
	if index then
		table.remove(lobby.members, index)
		lobby.ready[player] = nil
		lobby.startsAt = nil
		markAll(lobby.members)
	end
	local ok, err = pcall(launch, player)
	if not ok or not run or not run.members[player] then
		warn("[Raide] Falha ao entrar sozinho: " .. tostring(err))
		return { ok = false, msg = "Não foi possível abrir a fenda. Tente de novo." }
	end
	return { ok = true }
end

function RaidService.leave(player)
	local index = table.find(lobby.members, player)
	if index then
		table.remove(lobby.members, index)
		lobby.ready[player] = nil
		lobby.startsAt = nil
		markAll(lobby.members)
	end
	PlayerService.markDirty(player)
	return { ok = true }
end

function RaidService.setReady(player, value)
	if not table.find(lobby.members, player) then
		return { ok = false, msg = "Entre na sala primeiro." }
	end
	lobby.ready[player] = value == true
	local all = #lobby.members > 0
	for _, member in lobby.members do
		if not lobby.ready[member] then
			all = false
		end
	end
	-- fora do Studio precisa de pelo menos 2 jogadores
	if #lobby.members < 2 and not RunService:IsStudio() then
		all = false
	end
	lobby.startsAt = if all then os.clock() + COUNTDOWN else nil
	markAll(lobby.members)
	return { ok = true }
end

function RaidService.exit(player)
	if run and run.members[player] then
		run.members[player] = nil
		player:SetAttribute("Raid", nil)
		teleport(player, CFrame.new(portalPosition() + Vector3.new(0, 4, 14)))
		local anyone = next(run.members) ~= nil
		if not anyone then
			finish(false)
		end
		PlayerService.markDirty(player)
	end
	return { ok = true }
end

-- resumo para a interface
function RaidService.summary(player)
	local data = DataService.get(player)
	local names, flags = {}, {}
	for _, member in lobby.members do
		table.insert(names, member.DisplayName)
		table.insert(flags, lobby.ready[member] == true)
	end
	local result = {
		inLobby = table.find(lobby.members, player) ~= nil,
		members = names,
		ready = flags,
		me = lobby.ready[player] == true,
		startsIn = if lobby.startsAt then math.max(0, math.ceil(lobby.startsAt - os.clock())) else nil,
		busy = run ~= nil,
		claimed = data ~= nil and data.raidWeek == Raids.week(),
	}
	if run and run.members[player] then
		result.active = true
		result.phase = run.phase
		result.endsIn = math.max(0, math.floor(run.ends - workspace:GetServerTimeNow()))
	end
	return result
end

-- ===================== GANCHOS =====================

-- chamado pelo init.server no OnKilled de qualquer inimigo
function RaidService.onKilled(rec)
	local current = run
	if not current or rec ~= current.boss then
		return
	end
	local week = Raids.week()
	for player in current.members do
		local data = DataService.get(player)
		if data and player.Parent == Players then
			RaidService.QuestHook(player, "raid", nil, 1)
			if data.raidWeek ~= week then
				data.raidWeek = week
				ShopService.grant(player, "real")
				PlayerService.addGold(player, 3000)
				local def = Enemies.Defs[Raids.Boss]
				local item = Items.rollDrop(def.pool, def.level + 2, "weight", 5)
				LootService.spawnDrop(player, item, rec.pos)
				Remotes.Notify:FireClient(player, { kind = "banner", text = "PRÊMIO DA SEMANA!", sub = "Baú Real, um item Lendário (no chão) e 3.000 de ouro", color = Color3.fromRGB(255, 215, 90), duration = 6 })
			end
		end
	end
	finish(true)
end

function RaidService.onCharacterAdded(player, character)
	if not run or not run.members[player] then
		return
	end
	task.defer(function()
		character:WaitForChild("HumanoidRootPart", 5)
		if run and run.members[player] then
			teleport(player, arrival())
		end
	end)
end

function RaidService.onPlayerRemoving(player)
	RaidService.leave(player)
	if run and run.members[player] then
		run.members[player] = nil
		if next(run.members) == nil then
			finish(false)
		end
	end
end

function RaidService.init()
	pcall(buildPortal)
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if prompt.Name == "PortalRaide" and nearPortal(player) then
			Remotes.Notify:FireClient(player, { kind = "raidPortal" })
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			-- contagem da sala
			if lobby.startsAt and os.clock() >= lobby.startsAt then
				pcall(launch)
			end
			local current = run
			if current then
				local boss = current.boss
				if workspace:GetServerTimeNow() > current.ends then
					finish(false)
				elseif boss and not boss.dead then
					local ratio = boss.hp / math.max(boss.maxHp, 1)
					local nextPhase = Raids.Phases[current.phase + 1]
					if nextPhase and ratio <= nextPhase.at then
						current.phase += 1
						notify(members(), { kind = "banner", text = string.upper(nextPhase.name), sub = nextPhase.text, color = Color3.fromRGB(255, 120, 90), duration = 4 })
						if current.phase == 2 then
							spawnAdds(current)
						elseif current.phase == 3 then
							boss.damageMult *= 1.35
							current.meteorEvery = 4.5
							current.meteorWindup = 1.6
						end
						markAll(members())
					end
					-- chuva de estrelas (a partir da fase 1)
					if current.phase >= 1 and os.clock() >= current.nextMeteor then
						current.nextMeteor = os.clock() + current.meteorEvery
						local list = members()
						for _ = 1, math.min(3, #list) do
							meteor(current, list[math.random(1, #list)])
						end
					end
				end
			end
		end
	end)
end

return RaidService
