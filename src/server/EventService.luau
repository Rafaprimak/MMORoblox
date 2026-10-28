-- Eventos sazonais (Seasons.Events): enfeites na Vila Aurora, bônus do evento e uma meta de abates que dá
-- o título do evento (uma vez por ano por jogador, data.events["<evento>_<ano>"]).
--   * workspace "Evento" = id do evento ativo (o cliente lê para mostrar o cartão na Jornada).
--   * No Studio o botão "Evento" (painel de teste) passa por todos os eventos (workspace "EventoForcado").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Seasons = require(Shared.Seasons)
local World = require(Shared.World)
local TownPlan = require(Shared.TownPlan)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local PlayerService = require(script.Parent.PlayerService)
local ProgressionService = require(script.Parent.ProgressionService)
local Props = require(script.Parent.WorldGen.Props)

local EventService = {}

local current = nil -- evento com enfeites montados
local decor = nil
local isNight = function()
	return workspace:GetAttribute("Night") == true
end

local K = World.PropScale
local Y = World.TownHeight

local function rel(x, z)
	return World.TownCenter.X + x * K, World.TownCenter.Z + z * K
end

local function part(parent, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		p[key] = value
	end
	p.Parent = parent
	return p
end

local function light(parentPart, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Parent = parentPart
	return l
end

-- pontos ao pé dos postes (dos dois lados da rua), como na construção da vila
local function lampSpots()
	local spots = {}
	local offset = (TownPlan.StreetHalf + TownPlan.SidewalkOuter) / 2
	for _, lamp in TownPlan.Lamps do
		for _, side in { -1, 1 } do
			local x, z
			if lamp[1] == "z" then
				x, z = side * offset, lamp[2] + 1.6
			else
				x, z = lamp[2] + 1.6, side * offset
			end
			local wx, wz = rel(x, z)
			table.insert(spots, Vector3.new(wx, Y, wz))
		end
	end
	return spots
end

-- peça grande e invisível em cima da vila soltando partículas (neve, confete)
local function sky(model, color, texture, rate, speed, size)
	local wx, wz = rel(0, 0)
	local emitterPart = part(model, { Name = "CeuEvento", Size = Vector3.new(TownPlan.Radius * K * 1.6, 1, TownPlan.Radius * K * 1.6), CFrame = CFrame.new(wx, Y + 60, wz), Transparency = 1 })
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = color
	emitter.Texture = texture
	emitter.Rate = rate
	emitter.Lifetime = NumberRange.new(10, 14)
	emitter.Speed = NumberRange.new(speed, speed * 1.6)
	emitter.SpreadAngle = Vector2.new(20, 20)
	emitter.Acceleration = Vector3.new(0, -2, 0)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-90, 90)
	emitter.Size = NumberSequence.new(size)
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.Parent = emitterPart
end

-- ===================== ENFEITES =====================

local function lantern(model, position, color)
	local ball = part(model, { Name = "Lanterna", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.9, CFrame = CFrame.new(position), Color = color, Material = Enum.Material.Neon, Transparency = 0.15 })
	light(ball, color, 9, 0.8)
end

local function christmasTree(model, base, height)
	part(model, { Name = "Tronco", Shape = Enum.PartType.Cylinder, Size = Vector3.new(height * 0.15, height * 0.08, height * 0.08), CFrame = CFrame.new(base + Vector3.new(0, height * 0.075, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(100, 70, 45), Material = Enum.Material.Wood, CanCollide = true })
	local layers = 6
	for i = 1, layers do
		local t = (i - 1) / layers
		local radius = height * 0.32 * (1 - t * 0.85)
		local y = height * (0.15 + t * 0.7)
		part(model, { Name = "Copa", Shape = Enum.PartType.Cylinder, Size = Vector3.new(height * 0.14, radius * 2, radius * 2), CFrame = CFrame.new(base + Vector3.new(0, y, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(40, 110, 60):Lerp(Color3.fromRGB(60, 140, 80), t), Material = Enum.Material.Grass })
		-- bolas coloridas na borda de cada camada
		local balls = math.max(4, math.floor(radius * 1.2))
		for k = 1, balls do
			local a = k / balls * math.pi * 2 + i
			local colors = { Color3.fromRGB(230, 50, 50), Color3.fromRGB(255, 210, 60), Color3.fromRGB(80, 150, 255), Color3.fromRGB(240, 240, 255) }
			part(model, { Name = "Bola", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.7, CFrame = CFrame.new(base + Vector3.new(math.cos(a) * radius * 0.95, y - height * 0.05, math.sin(a) * radius * 0.95)), Color = colors[k % #colors + 1], Material = Enum.Material.Neon })
		end
	end
	local star = part(model, { Name = "Estrela", Size = Vector3.new(1.6, 1.6, 0.4), CFrame = CFrame.new(base + Vector3.new(0, height * 0.95, 0)) * CFrame.Angles(0, 0, math.rad(45)), Color = Color3.fromRGB(255, 220, 90), Material = Enum.Material.Neon })
	part(model, { Name = "Estrela2", Size = Vector3.new(1.6, 1.6, 0.4), CFrame = star.CFrame * CFrame.Angles(0, 0, math.rad(45)), Color = Color3.fromRGB(255, 220, 90), Material = Enum.Material.Neon })
	light(star, Color3.fromRGB(255, 220, 140), 30, 2)
end

local function gift(model, position, size, color)
	part(model, { Name = "Presente", Size = Vector3.one * size, CFrame = CFrame.new(position + Vector3.new(0, size / 2, 0)) * CFrame.Angles(0, math.random() * 6, 0), Color = color, Material = Enum.Material.SmoothPlastic, CanCollide = true })
	part(model, { Name = "Fita", Size = Vector3.new(size * 1.02, size * 1.02, size * 0.2), CFrame = CFrame.new(position + Vector3.new(0, size / 2, 0)), Color = Color3.fromRGB(255, 220, 90), Material = Enum.Material.Metal })
end

local function christmas(model)
	local wx, wz = rel(0, 17)
	local base = Vector3.new(wx, Y, wz)
	christmasTree(model, base, 20)
	local colors = { Color3.fromRGB(200, 40, 40), Color3.fromRGB(40, 120, 200), Color3.fromRGB(60, 160, 80), Color3.fromRGB(150, 60, 180) }
	for k = 1, 8 do
		local a = k / 8 * math.pi * 2
		gift(model, base + Vector3.new(math.cos(a) * 5.5, 0, math.sin(a) * 5.5), 1 + (k % 3) * 0.4, colors[k % #colors + 1])
	end
	-- pisca-pisca nos postes
	for i, spot in lampSpots() do
		local colors2 = { Color3.fromRGB(255, 80, 80), Color3.fromRGB(90, 220, 110), Color3.fromRGB(255, 220, 90), Color3.fromRGB(90, 160, 255) }
		lantern(model, spot + Vector3.new(0, 4 + (i % 3) * 1.5, 0), colors2[i % #colors2 + 1])
	end
	sky(model, ColorSequence.new(Color3.new(1, 1, 1)), "rbxasset://textures/particles/sparkles_main.dds", 60, 4, 0.5)
end

local function flagLine(model, from, to, colors)
	local count = math.max(4, math.floor((to - from).Magnitude / 2.2))
	for i = 1, count do
		local t = (i - 0.5) / count
		local sag = math.sin(t * math.pi) * 1.8
		local p = from:Lerp(to, t) - Vector3.new(0, sag, 0)
		local direction = (to - from).Unit
		part(model, { Name = "Bandeirinha", Size = Vector3.new(1.1, 1.1, 0.06), CFrame = CFrame.lookAt(p, p + direction:Cross(Vector3.yAxis)) * CFrame.new(0, -0.5, 0) * CFrame.Angles(0, 0, math.rad(45)), Color = colors[i % #colors + 1], Material = Enum.Material.Fabric })
	end
end

local function festiveFlags(model, colors)
	-- fileiras cruzando a praça e as ruas principais, bem acima das bandeirinhas da vila
	local h = Y + 13
	local P = TownPlan.PlazaHalf
	local lines = {
		{ { -P, -P }, { P, P } }, { { P, -P }, { -P, P } },
		{ { -P, 0 }, { P, 0 } }, { { 0, -P }, { 0, P } },
		{ { -6, -60 }, { 6, -60 } }, { { -6, -80 }, { 6, -80 } }, { { 60, -6 }, { 60, 6 } }, { { -60, -6 }, { -60, 6 } },
	}
	for _, line in lines do
		local ax, az = rel(line[1][1], line[1][2])
		local bx, bz = rel(line[2][1], line[2][2])
		flagLine(model, Vector3.new(ax, h, az), Vector3.new(bx, h, bz), colors)
	end
end

local function carnival(model)
	local colors = { Color3.fromRGB(255, 60, 160), Color3.fromRGB(255, 220, 40), Color3.fromRGB(60, 200, 255), Color3.fromRGB(120, 230, 90), Color3.fromRGB(180, 90, 255) }
	festiveFlags(model, colors)
	for i, spot in lampSpots() do
		lantern(model, spot + Vector3.new(0, 4, 0), colors[i % #colors + 1])
	end
	sky(model, ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 160)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 220, 40)), ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 200, 255)) }), "rbxasset://textures/particles/sparkles_main.dds", 40, 5, 0.4)
end

local function bonfire(model, base)
	for k = 1, 8 do
		local a = k / 8 * math.pi * 2
		part(model, { Name = "Lenha", Shape = Enum.PartType.Cylinder, Size = Vector3.new(6, 0.7, 0.7), CFrame = CFrame.new(base + Vector3.new(math.cos(a) * 0.8, 2.2, math.sin(a) * 0.8)) * CFrame.Angles(0, -a, math.rad(65)), Color = Color3.fromRGB(100, 70, 45), Material = Enum.Material.Wood })
	end
	for k = 1, 10 do
		local a = k / 10 * math.pi * 2
		part(model, { Name = "Pedra", Size = Vector3.new(1, 0.7, 1), CFrame = CFrame.new(base + Vector3.new(math.cos(a) * 3, 0.35, math.sin(a) * 3)) * CFrame.Angles(0, a, 0), Color = Color3.fromRGB(120, 115, 110), Material = Enum.Material.Slate, CanCollide = true })
	end
	local core = part(model, { Name = "Brasa", Size = Vector3.new(2, 1, 2), CFrame = CFrame.new(base + Vector3.new(0, 0.6, 0)), Color = Color3.fromRGB(255, 120, 30), Material = Enum.Material.Neon })
	local fire = Instance.new("Fire")
	fire.Size = 12
	fire.Heat = 18
	fire.Parent = core
	light(core, Color3.fromRGB(255, 160, 70), 40, 2.5)
end

local function junina(model)
	local colors = { Color3.fromRGB(255, 70, 70), Color3.fromRGB(255, 210, 50), Color3.fromRGB(60, 160, 255), Color3.fromRGB(90, 200, 90), Color3.fromRGB(255, 140, 40) }
	festiveFlags(model, colors)
	local wx, wz = rel(0, 17)
	bonfire(model, Vector3.new(wx, Y, wz))
end

-- Halloween sem enfeites (pedido do dono do jogo): o evento fica só com o bônus e a meta
local BUILDERS = { natal = christmas, carnaval = carnival, junina = junina }

local function setDecor(event)
	if decor then
		decor:Destroy()
		decor = nil
	end
	if not event or not BUILDERS[event.id] then
		return
	end
	local model = Instance.new("Model")
	model.Name = "EnfeitesEvento"
	local ok, err = pcall(BUILDERS[event.id], model)
	if not ok then
		warn("[Evento] enfeites:", err)
	end
	-- luzes dos enfeites só acendem à noite (como os postes)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant:FindFirstChildOfClass("PointLight") then
			Props.nightLight(descendant)
		end
	end
	model.Parent = workspace
	decor = model
end

-- ===================== REGRAS =====================

function EventService.active()
	return Seasons.activeEvent(os.time(), workspace:GetAttribute("EventoForcado"))
end

local function progressOf(player, event)
	local data = DataService.get(player)
	if not data then
		return nil
	end
	local key = Seasons.eventKey(event)
	data.events[key] = data.events[key] or { kills = 0, done = false }
	return data.events[key]
end

-- bônus do evento (encadeado no gancho ExtraBonus do PlayerService)
function EventService.applyBonus(_player, _data, bonus)
	local event = current
	if not event then
		return
	end
	local extra = event.bonus or {}
	if extra.xp then
		bonus.xpGain = (bonus.xpGain or 0) + extra.xp
	end
	if extra.nightXp and isNight() then
		bonus.xpGain = (bonus.xpGain or 0) + extra.nightXp
	end
	if extra.gold then
		bonus.goldFind = (bonus.goldFind or 0) + extra.gold
	end
	if extra.drop then
		bonus.dropFind = (bonus.dropFind or 0) + extra.drop
	end
end

-- abate (chamado pelo init para cada jogador que ajudou)
function EventService.onKill(player)
	local event = current
	if not event then
		return
	end
	local entry = progressOf(player, event)
	if not entry or entry.done then
		return
	end
	entry.kills += 1
	if entry.kills >= event.goal then
		entry.done = true
		local reward = table.clone(event.reward or {})
		reward.title = event.title
		ProgressionService.grant(player, reward, event.name .. ": meta completa!")
	end
	PlayerService.markDirty(player)
end

function EventService.summary(player)
	local event = current
	if not event then
		return nil
	end
	local entry = progressOf(player, event)
	return {
		id = event.id,
		kills = if entry then entry.kills else 0,
		done = entry ~= nil and entry.done,
	}
end

-- Studio: passa para o próximo evento (e depois volta para o calendário)
function EventService.cycle()
	local forced = workspace:GetAttribute("EventoForcado")
	local index = 0
	for i, event in Seasons.Events do
		if event.id == forced then
			index = i
		end
	end
	local nextEvent = Seasons.Events[index + 1]
	workspace:SetAttribute("EventoForcado", if nextEvent then nextEvent.id else nil)
	EventService.refresh()
	return nextEvent
end

function EventService.refresh()
	local event = EventService.active()
	if (event and event.id) == (current and current.id) then
		return
	end
	current = event
	workspace:SetAttribute("Evento", if event then event.id else nil)
	setDecor(event)
	for _, player in Players:GetPlayers() do
		PlayerService.markDirty(player)
		if event then
			Remotes.Notify:FireClient(player, { kind = "banner", text = string.upper(event.name), sub = "Evento da temporada! Veja na Jornada (tecla K)", color = event.color, duration = 5 })
		end
	end
end

function EventService.onPlayerReady(player)
	local event = current
	if event then
		task.delay(6, function()
			if player.Parent == Players and current == event then
				Remotes.Notify:FireClient(player, { kind = "banner", text = string.upper(event.name), sub = "Evento da temporada! Veja na Jornada (tecla K)", color = event.color, duration = 5 })
			end
		end)
	end
end

function EventService.start()
	local previous = PlayerService.ExtraBonus
	PlayerService.ExtraBonus = function(player, data, bonus)
		previous(player, data, bonus)
		EventService.applyBonus(player, data, bonus)
	end
	EventService.refresh()
	task.spawn(function()
		while true do
			task.wait(60)
			pcall(EventService.refresh)
		end
	end)
end

return EventService
