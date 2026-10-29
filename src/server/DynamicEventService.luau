-- Eventos dinâmicos pequenos no mundo aberto (preenchem o tempo entre as missões da história):
--   * FENDA DE MANA: uma fenda se abre e cospe monstros em 2 ondas.
--   * CARAVANA ATACADA: uma carroça tombada cercada de monstros; derrote todos.
--   * MORADOR CAPTURADO: monstros guardam um morador numa jaula; derrote os guardas e abra a jaula.
-- Aparecem perto de um jogador (longe da vila, fora de masmorra/raide/arena) a cada poucos minutos,
-- duram alguns minutos e dão XP pelo nível de quem participou (Config.xpToNext × fração) e ouro.
-- Quem ajudou (dano ou estava perto no fim) ganha a recompensa. Tudo é montado em
-- workspace.EventosDinamicos (feixe de luz + placa flutuante com o andamento).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local World = require(Shared.World)
local Points = require(Shared.Points)
local Enemies = require(Shared.Enemies)
local Remotes = require(Shared.Remotes)

local EnemyService = require(script.Parent.EnemyService)
local PlayerService = require(script.Parent.PlayerService)
local DataService = require(script.Parent.DataService)
local Props = require(script.Parent.WorldGen.Props)

local DynamicEventService = {}

DynamicEventService.QuestHook = function(_player, _kind, _target, _amount) end

local CHECK_EVERY = 20 -- segundos entre as checagens
local PLAYER_GAP = { 240, 420 } -- intervalo (s) entre eventos para o mesmo jogador
local MAX_ACTIVE = 4
local DURATION = 180
local REWARD_FRACTION = 0.1 -- do XP para o próximo nível de cada participante
local NEAR = 70 -- quem está perto no fim também ganha
local TOWN_CLEAR = 260 -- não acontece perto da vila

-- inimigos possíveis por nível do jogador (os que estão entre nível - 3 e nível + 1)
local ENEMY_LEVELS = {
	{ 1, "slime" }, { 3, "lobo" }, { 4, "javali" }, { 5, "caranguejo" }, { 6, "goblin" }, { 6, "goblin_arqueiro" },
	{ 8, "aranha" }, { 11, "esqueleto" }, { 12, "esqueleto_mago" }, { 14, "golem" },
}

local KINDS = {
	fenda = { name = "Fenda de Mana", text = "Uma fenda se abriu perto de você!", color = Color3.fromRGB(150, 110, 255), waves = 2 },
	caravana = { name = "Caravana Atacada", text = "Uma caravana está sendo atacada perto de você!", color = Color3.fromRGB(255, 170, 80), waves = 1 },
	resgate = { name = "Morador Capturado", text = "Monstros capturaram um morador perto de você!", color = Color3.fromRGB(120, 210, 255), waves = 1 },
}
local KIND_ORDER = { "fenda", "caravana", "resgate" }

local folder = nil
local active = {} -- lista de eventos
local nextFor = {} -- [player] = os.clock() do próximo evento possível
local counter = 0

local function part(parent, props)
	return Props.part(parent, props)
end

local function enemyChoices(level)
	local list = {}
	for _, entry in ENEMY_LEVELS do
		if entry[1] >= level - 3 and entry[1] <= level + 1 then
			table.insert(list, entry[2])
		end
	end
	if #list == 0 then
		table.insert(list, if level > 10 then "golem" else "slime")
	end
	return list
end

local function inSpecialPlace(player)
	return player:GetAttribute("Dungeon") ~= nil or player:GetAttribute("Raid") ~= nil or player:GetAttribute("Arena") ~= nil
end

local function rootOf(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart")
end

-- ponto bom perto do jogador: seco, plano, longe da vila e dos outros eventos
local function findSpot(position)
	for _ = 1, 6 do
		local angle = math.random() * math.pi * 2
		local distance = 45 + math.random() * 30
		local x, z = Points.resolve(position.X + math.cos(angle) * distance, position.Z + math.sin(angle) * distance, function(px, pz)
			if (Vector2.new(px, pz) - Vector2.new(World.TownCenter.X, World.TownCenter.Z)).Magnitude < TOWN_CLEAR then
				return false
			end
			for _, event in active do
				if (Vector2.new(px, pz) - event.center).Magnitude < 120 then
					return false
				end
			end
			return true
		end)
		local h = World.height(x, z)
		if h > World.SeaLevel + 1.5 and (Vector2.new(x, z) - Vector2.new(World.TownCenter.X, World.TownCenter.Z)).Magnitude >= TOWN_CLEAR then
			return x, z, h
		end
	end
	return nil
end

-- ===================== CENÁRIO =====================

local function buildRift(model, cf)
	local crystal = part(model, { Name = "Fenda", Size = Vector3.new(1.6, 9, 1.6), CFrame = cf * CFrame.new(0, 4.2, 0) * CFrame.Angles(0, 0, math.rad(8)), Color = Color3.fromRGB(150, 110, 255), Material = Enum.Material.Neon, Transparency = 0.15, CanCollide = false })
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2
		part(model, { Name = "Estilhaco", Size = Vector3.new(0.8, 2 + (i % 3), 0.8), CFrame = cf * CFrame.new(math.cos(a) * 3.2, 1, math.sin(a) * 3.2) * CFrame.Angles(math.rad(20), a, math.rad(15)), Color = Color3.fromRGB(110, 80, 200), Material = Enum.Material.Glass, Transparency = 0.2, CanCollide = false })
	end
	part(model, { Name = "Marca", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 12, 12), CFrame = cf * CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(60, 30, 90), Material = Enum.Material.Slate, CanCollide = false })
	Props.light(crystal, Color3.fromRGB(160, 120, 255), 24, 2)
	local sparks = Instance.new("ParticleEmitter")
	sparks.Color = ColorSequence.new(Color3.fromRGB(190, 160, 255))
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.4, 0)
	sparks.Lifetime = NumberRange.new(1, 1.6)
	sparks.Rate = 18
	sparks.Speed = NumberRange.new(2, 5)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Parent = crystal
	return crystal
end

local function buildCaravan(model, cf)
	Props.cart(model, cf * CFrame.Angles(0, 0, math.rad(12)))
	for i, offset in { { 4, 0, 2 }, { -4, 0, -1 }, { 3, 0, -4 } } do
		Props.crate(model, cf * CFrame.new(offset[1], offset[2], offset[3]) * CFrame.Angles(0, math.rad(i * 25), 0), 2 + i * 0.3)
	end
	local barrel = Props.barrel(model, cf * CFrame.new(-3, 0, 3.5) * CFrame.Angles(0, 0, math.rad(90)), 0.8)
	Props.flame(model, (cf * CFrame.new(1.5, 1.6, 0)).Position, 1.2, { light = 18, sparks = true })
	return barrel
end

local function buildCage(model, cf)
	local wood = Color3.fromRGB(90, 65, 40)
	part(model, { Name = "Piso", Size = Vector3.new(6, 0.4, 6), CFrame = cf * CFrame.new(0, 0.2, 0), Color = wood, Material = Enum.Material.WoodPlanks })
	part(model, { Name = "Teto", Size = Vector3.new(6.4, 0.5, 6.4), CFrame = cf * CFrame.new(0, 6.2, 0), Color = wood, Material = Enum.Material.Wood })
	for _, corner in { { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } } do
		part(model, { Name = "Poste", Size = Vector3.new(0.5, 6, 0.5), CFrame = cf * CFrame.new(corner[1] * 2.8, 3.2, corner[2] * 2.8), Color = wood, Material = Enum.Material.Wood })
	end
	local bars = {}
	for side = 0, 3 do
		local face = cf * CFrame.Angles(0, side * math.pi / 2, 0)
		for i = -2, 2 do
			local bar = part(model, { Name = "Grade", Size = Vector3.new(0.18, 5.6, 0.18), CFrame = face * CFrame.new(i * 1.05, 3.2, -2.8), Color = Color3.fromRGB(60, 60, 65), Material = Enum.Material.Metal })
			table.insert(bars, bar)
		end
	end
	-- o morador (blocado), sentado no canto
	local skin, shirt = Color3.fromRGB(230, 190, 150), Color3.fromRGB(150, 110, 70)
	part(model, { Name = "Pernas", Size = Vector3.new(1.6, 1, 2), CFrame = cf * CFrame.new(0, 0.9, 0.4), Color = Color3.fromRGB(70, 60, 50), CanCollide = false })
	part(model, { Name = "Tronco", Size = Vector3.new(1.8, 2, 1), CFrame = cf * CFrame.new(0, 2.4, 0.9), Color = shirt, Material = Enum.Material.Fabric, CanCollide = false })
	part(model, { Name = "Cabeca", Size = Vector3.new(1.1, 1.1, 1.1), CFrame = cf * CFrame.new(0, 4, 0.9), Color = skin, CanCollide = false })
	part(model, { Name = "Cabelo", Size = Vector3.new(1.2, 0.4, 1.2), CFrame = cf * CFrame.new(0, 4.6, 0.95), Color = Color3.fromRGB(110, 70, 40), CanCollide = false })
	local lock = part(model, { Name = "Cadeado", Size = Vector3.new(0.6, 0.7, 0.3), CFrame = cf * CFrame.new(0, 3, -3), Color = Color3.fromRGB(200, 170, 80), Material = Enum.Material.Metal, CanCollide = false })
	return lock, bars
end

local function buildMarker(model, position, color, title)
	-- feixe alto (visto de longe) e placa flutuante com o andamento
	local beam = part(model, { Name = "Feixe", Shape = Enum.PartType.Cylinder, Size = Vector3.new(70, 1.2, 1.2), CFrame = CFrame.new(position + Vector3.new(0, 35, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = color, Material = Enum.Material.Neon, Transparency = 0.55, CanCollide = false, CanQuery = false })
	local gui = Instance.new("BillboardGui")
	gui.Name = "Placa"
	gui.Size = UDim2.fromOffset(260, 56)
	gui.StudsOffsetWorldSpace = Vector3.new(0, -26, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 220
	gui.LightInfluence = 0
	gui.Parent = beam
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0, 28)
	name.Font = Enum.Font.GothamBold
	name.TextScaled = true
	name.TextColor3 = color
	name.TextStrokeTransparency = 0.3
	name.Text = title
	name.Parent = gui
	local status = Instance.new("TextLabel")
	status.Name = "Andamento"
	status.BackgroundTransparency = 1
	status.Position = UDim2.fromOffset(0, 28)
	status.Size = UDim2.new(1, 0, 0, 22)
	status.Font = Enum.Font.GothamMedium
	status.TextScaled = true
	status.TextColor3 = Color3.new(1, 1, 1)
	status.TextStrokeTransparency = 0.3
	status.Parent = gui
	return status
end

-- ===================== ANDAMENTO =====================

local function setStatus(event, text)
	if event.status then
		event.status.Text = text
	end
end

local function spawnWave(event)
	local count = 3 + math.min(3, event.players) + (if event.kind == "fenda" then 1 else 0)
	for i = 1, count do
		local enemyId = event.choices[(i - 1) % #event.choices + 1]
		local def = Enemies.Defs[enemyId]
		if def then
			EnemyService.spawn(event.camp, enemyId, {
				levelBonus = math.clamp(event.level - def.level, 0, 2),
				hpMult = 1.15 + 0.1 * event.players,
				forceElite = event.wave == event.waves and i == 1,
			})
		end
	end
end

local function finish(event, won)
	local index = table.find(active, event)
	if not index then
		return
	end
	table.remove(active, index)
	EnemyService.clearCamp(event.camp)
	if won then
		-- quem bateu ou estava perto no fim ganha
		for _, player in Players:GetPlayers() do
			local root = rootOf(player)
			if root and (root.Position - Vector3.new(event.center.X, root.Position.Y, event.center.Y)).Magnitude < NEAR then
				event.participants[player] = true
			end
		end
		for player in event.participants do
			local data = player.Parent == Players and DataService.get(player)
			if data then
				local xp = math.floor(Config.xpToNext(data.level) * REWARD_FRACTION)
				local gold = 40 + data.level * 12
				PlayerService.addXP(player, xp)
				PlayerService.addGold(player, gold)
				DynamicEventService.QuestHook(player, "dynamicEvent", event.kind, 1)
				Remotes.Notify:FireClient(player, { kind = "banner", text = KINDS[event.kind].name .. ": concluído!", sub = ("+%d XP e +%d de ouro"):format(xp, gold), color = KINDS[event.kind].color, duration = 4 })
			end
		end
		if event.kind == "resgate" then
			setStatus(event, "O morador agradece e corre para a vila!")
		else
			setStatus(event, "Concluído!")
		end
		task.delay(4, function()
			event.model:Destroy()
		end)
	else
		event.model:Destroy()
	end
end

local function startFor(player)
	if #active >= MAX_ACTIVE then
		return false
	end
	local root = rootOf(player)
	local data = DataService.get(player)
	if not root or not data or not data.class or inSpecialPlace(player) then
		return false
	end
	if (Vector2.new(root.Position.X, root.Position.Z) - Vector2.new(World.TownCenter.X, World.TownCenter.Z)).Magnitude < TOWN_CLEAR then
		return false
	end
	local x, z, h = findSpot(root.Position)
	if not x then
		return false
	end
	counter += 1
	local kind = KIND_ORDER[math.random(1, #KIND_ORDER)]
	local info = KINDS[kind]
	local model = Instance.new("Model")
	model.Name = "Evento_" .. counter
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local cf = CFrame.new(x, h, z) * CFrame.Angles(0, math.random() * math.pi * 2, 0)
	local event = {
		id = counter,
		kind = kind,
		center = Vector2.new(x, z),
		camp = { id = "dinamico_" .. counter, center = Vector2.new(x, z), radius = 16, dynamic = true },
		model = model,
		level = data.level,
		choices = enemyChoices(data.level),
		wave = 1,
		waves = info.waves,
		players = 0,
		participants = {},
		ends = os.clock() + DURATION,
	}
	for _, other in Players:GetPlayers() do
		local otherRoot = rootOf(other)
		if otherRoot and (otherRoot.Position - root.Position).Magnitude < 200 then
			event.players += 1
		end
	end
	if kind == "fenda" then
		buildRift(model, cf)
	elseif kind == "caravana" then
		buildCaravan(model, cf)
	else
		local lock, bars = buildCage(model, cf)
		event.bars = bars
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Abrir a jaula"
		prompt.ObjectText = "Morador capturado"
		prompt.HoldDuration = 1
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Enabled = false
		prompt.Parent = lock
		event.prompt = prompt
		prompt.Triggered:Connect(function(who)
			if table.find(active, event) and EnemyService.aliveInCamp(event.camp) == 0 then
				event.participants[who] = true
				prompt.Enabled = false
				for _, bar in event.bars do
					bar.Transparency = 1
					bar.CanCollide = false
				end
				finish(event, true)
			end
		end)
	end
	event.status = buildMarker(model, Vector3.new(x, h, z), info.color, info.name)
	model.Parent = folder
	spawnWave(event)
	table.insert(active, event)
	setStatus(event, if kind == "resgate" then "Derrote os guardas" else ("Onda %d de %d"):format(1, event.waves))
	-- aviso para quem está perto
	for _, other in Players:GetPlayers() do
		local otherRoot = rootOf(other)
		if otherRoot and (otherRoot.Position - Vector3.new(x, h, z)).Magnitude < 220 then
			Remotes.Notify:FireClient(other, { kind = "banner", text = "EVENTO: " .. info.name, sub = info.text .. " (siga o feixe de luz)", color = info.color, duration = 5 })
			nextFor[other] = os.clock() + math.random(PLAYER_GAP[1], PLAYER_GAP[2])
		end
	end
	return true
end

local function update(event)
	if os.clock() > event.ends then
		setStatus(event, "Os monstros foram embora...")
		finish(event, false)
		return
	end
	local alive = EnemyService.aliveInCamp(event.camp)
	local left = math.max(0, math.floor(event.ends - os.clock()))
	if alive > 0 then
		local label = if event.kind == "resgate" then "Derrote os guardas" else ("Onda %d de %d"):format(event.wave, event.waves)
		setStatus(event, ("%s  •  %d restante(s)  •  %d:%02d"):format(label, alive, left // 60, left % 60))
		return
	end
	if event.wave < event.waves then
		event.wave += 1
		spawnWave(event)
	elseif event.kind == "resgate" then
		event.prompt.Enabled = true
		setStatus(event, ("Abra a jaula!  •  %d:%02d"):format(left // 60, left % 60))
	else
		finish(event, true)
	end
end

-- ===================== GANCHOS =====================

-- chamado pelo init.server no OnKilled: quem ajudou entra na lista de participantes
function DynamicEventService.onKilled(rec, contributors)
	if not rec.camp or not rec.camp.dynamic then
		return
	end
	for _, event in active do
		if event.camp == rec.camp then
			for player in contributors do
				event.participants[player] = true
			end
		end
	end
end

-- teste no Studio: começa um evento perto do jogador agora
function DynamicEventService.force(player)
	return startFor(player)
end

function DynamicEventService.start()
	folder = Instance.new("Folder")
	folder.Name = "EventosDinamicos"
	folder.Parent = workspace
	Players.PlayerRemoving:Connect(function(player)
		nextFor[player] = nil
	end)
	task.spawn(function()
		local lastCheck = 0
		while true do
			task.wait(1)
			for i = #active, 1, -1 do
				local event = active[i]
				if event then
					local ok, err = pcall(update, event)
					if not ok then
						warn("[DynamicEventService] " .. tostring(err))
						pcall(finish, event, false)
					end
				end
			end
			if os.clock() - lastCheck >= CHECK_EVERY then
				lastCheck = os.clock()
				for _, player in Players:GetPlayers() do
					local due = nextFor[player]
					if not due then
						-- primeiro evento alguns minutos depois de entrar
						nextFor[player] = os.clock() + math.random(120, 200)
					elseif os.clock() >= due then
						local ok, started = pcall(startFor, player)
						-- não deu (vila, masmorra, sem lugar): tenta de novo daqui a pouco
						nextFor[player] = os.clock() + (if ok and started then math.random(PLAYER_GAP[1], PLAYER_GAP[2]) else 30)
					end
				end
			end
		end
	end)
end

return DynamicEventService
