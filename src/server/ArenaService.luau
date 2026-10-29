-- Arena PvP "Coliseu de Aurora": Duelo 1x1 e Equipes 3x3, melhor de 3 rodadas, pontuação por temporada.
--   * Fila de qualquer lugar (janela da Arena); quando fecha o número, todos vão para um coliseu longe do mapa
--     (até 4 lutas ao mesmo tempo, uma em cada coliseu). Na volta, cada um retorna para onde estava.
--   * O dano entre jogadores reaproveita TODO o combate: o EnemyService pede ao gancho Proxies os oponentes
--     do atacante e eles viram "alvos" (registro com proxy = true). O dano vai para PlayerService.damagePlayer
--     (esquiva perfeita, aparar, bloqueio e perks de defesa valem) com Arena.DamageMult e sem morte:
--     quem chega a 1 de vida cai e assiste do alto até a próxima rodada.
--   * Sem poções na arena; curas valem menos (Arena.HealMult). Curas e escudos só no próprio time (IsAlly).
--   * Pontos (Elo) em data.arena, ranking da temporada em OrderedDataStore "Arena_T<temporada>",
--     títulos ao alcançar cada divisão.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Arena = require(Shared.Arena)
local Seasons = require(Shared.Seasons)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local PlayerService = require(script.Parent.PlayerService)
local CombatService = require(script.Parent.CombatService)
local AntiCheat = require(script.Parent.AntiCheat)
local TravelService = require(script.Parent.TravelService)
local ProgressionService = require(script.Parent.ProgressionService)

local ArenaService = {}

ArenaService.QuestHook = function(_player, _kind, _target, _amount) end

local ORIGIN = Vector3.new(-12000, 300, 0)
local SLOT_SPACING = 400
local MAX_SLOTS = 4
local RADIUS = 44

local queues = { duelo = {}, equipes = {} } -- [modo] = { { player, since } }
local matchOf = {} -- [player] = partida
local proxies = {} -- [player] = registro de alvo
local arenas = {} -- [slot] = Model
local busySlots = {} -- [slot] = partida
local nextMatchId = 0

local function rootOf(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function humanoidOf(player)
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

-- dados da arena do jogador, já na temporada atual (a pontuação volta para perto de 1000 a cada temporada)
local function arenaData(player)
	local data = DataService.get(player)
	if not data then
		return nil
	end
	local season = Seasons.index()
	local arena = data.arena
	if arena.season ~= season then
		local previous = arena.rating or Arena.StartRating
		arena.season = season
		arena.rating = math.floor(Arena.StartRating + (previous - Arena.StartRating) * 0.5)
		arena.best = arena.rating
		arena.wins = 0
		arena.losses = 0
	end
	return arena, data
end

local function teamOf(match, player)
	for index, team in match.teams do
		if table.find(team, player) then
			return index
		end
	end
	return nil
end

local function everyone(match)
	local list = {}
	for _, team in match.teams do
		for _, player in team do
			table.insert(list, player)
		end
	end
	return list
end

local function notifyAll(match, message)
	for _, player in everyone(match) do
		if player.Parent == Players then
			Remotes.Notify:FireClient(player, message)
		end
	end
end

local function markAll(match)
	for _, player in everyone(match) do
		PlayerService.markDirty(player)
	end
end

local function teleport(player, cf)
	local character = player.Character
	if character and character:FindFirstChild("HumanoidRootPart") then
		AntiCheat.allowTeleport(player, 3, cf.Position)
		character:PivotTo(cf)
	end
end

-- ===================== COLISEU =====================

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

local SAND = Color3.fromRGB(214, 186, 140)
local STONE = Color3.fromRGB(170, 160, 145)
local STONE_DARK = Color3.fromRGB(110, 102, 92)
local TEAM_COLORS = { Color3.fromRGB(70, 140, 255), Color3.fromRGB(255, 80, 70) }
local GOLD = Color3.fromRGB(255, 205, 90)

local function centerOf(slot)
	return ORIGIN + Vector3.new((slot - 1) * SLOT_SPACING, 0, 0)
end

local function brazier(model, cf)
	part(model, { Name = "Pe", Shape = Enum.PartType.Cylinder, Size = Vector3.new(5, 1.2, 1.2), CFrame = cf * CFrame.new(0, 2.5, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = STONE_DARK, Material = Enum.Material.Slate })
	part(model, { Name = "Bacia", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 3.4, 3.4), CFrame = cf * CFrame.new(0, 5.4, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(90, 70, 50), Material = Enum.Material.Metal })
	local flame = part(model, { Name = "Chama", Size = Vector3.new(1.6, 1.6, 1.6), CFrame = cf * CFrame.new(0, 6.6, 0), Color = Color3.fromRGB(255, 150, 40), Material = Enum.Material.Neon, Transparency = 0.3, CanCollide = false })
	local fire = Instance.new("Fire")
	fire.Size = 5
	fire.Heat = 9
	fire.Parent = flame
	local l = Instance.new("PointLight")
	l.Color = Color3.fromRGB(255, 170, 80)
	l.Range = 26
	l.Brightness = 1.6
	l.Parent = flame
end

local function buildArena(slot)
	if arenas[slot] then
		return arenas[slot]
	end
	local model = Instance.new("Model")
	model.Name = "Coliseu" .. slot
	local center = CFrame.new(centerOf(slot))
	local rng = Random.new(777 + slot)
	-- piso de areia com anéis de pedra e o brasão no centro
	part(model, { Name = "Piso", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, RADIUS * 2 + 4, RADIUS * 2 + 4), CFrame = center * CFrame.new(0, -2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = SAND, Material = Enum.Material.Sand })
	part(model, { Name = "Anel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 30, 30), CFrame = center * CFrame.new(0, 0.05, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = STONE, Material = Enum.Material.Cobblestone, CanCollide = false })
	part(model, { Name = "AnelInterno", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 26, 26), CFrame = center * CFrame.new(0, 0.06, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = SAND:Lerp(STONE, 0.3), Material = Enum.Material.Sand, CanCollide = false })
	for k = 0, 1 do
		part(model, { Name = "Brasao", Size = Vector3.new(12, 0.1, 2), CFrame = center * CFrame.new(0, 0.1, 0) * CFrame.Angles(0, math.rad(45 + 90 * k), 0), Color = GOLD, Material = Enum.Material.Metal, CanCollide = false })
	end
	-- metades coloridas: cada time nasce do seu lado
	for team = 1, 2 do
		local z = if team == 1 then -(RADIUS - 8) else RADIUS - 8
		part(model, { Name = "Base" .. team, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, 14, 14), CFrame = center * CFrame.new(0, 0.08, z) * CFrame.Angles(0, 0, math.rad(90)), Color = TEAM_COLORS[team], Material = Enum.Material.Neon, Transparency = 0.6, CanCollide = false })
	end
	-- muro circular (alto o bastante para ninguém sair) e arquibancadas em degraus
	local segments = 32
	for i = 0, segments - 1 do
		local a = i / segments * math.pi * 2
		local frame = center * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -(RADIUS + 1))
		local width = 2 * (RADIUS + 1) * math.tan(math.pi / segments) + 0.6
		part(model, { Name = "Muro", Size = Vector3.new(width, 9, 2.5), CFrame = frame * CFrame.new(0, 4.5, 0), Color = STONE, Material = Enum.Material.Brick })
		part(model, { Name = "Barreira", Size = Vector3.new(width, 40, 2), CFrame = frame * CFrame.new(0, 29, 0), Transparency = 1 })
		for step = 1, 5 do
			local stepFrame = center * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -(RADIUS + 1 + step * 4))
			local stepWidth = 2 * (RADIUS + 1 + step * 4) * math.tan(math.pi / segments) + 0.8
			part(model, { Name = "Degrau", Size = Vector3.new(stepWidth, 9 + step * 3, 4), CFrame = stepFrame * CFrame.new(0, (9 + step * 3) / 2, 0), Color = if step % 2 == 0 then STONE else STONE:Lerp(STONE_DARK, 0.25), Material = Enum.Material.Slate })
		end
		-- colunas, estandartes dos dois times e braseiros
		if i % 4 == 0 then
			local columnFrame = center * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -(RADIUS + 26))
			part(model, { Name = "Coluna", Shape = Enum.PartType.Cylinder, Size = Vector3.new(34, 3.4, 3.4), CFrame = columnFrame * CFrame.new(0, 17, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = STONE, Material = Enum.Material.Marble })
			part(model, { Name = "Capitel", Size = Vector3.new(4.6, 1.4, 4.6), CFrame = columnFrame * CFrame.new(0, 34.6, 0), Color = STONE_DARK, Material = Enum.Material.Marble })
			local team = if i % 8 == 0 then 1 else 2
			part(model, { Name = "Estandarte", Size = Vector3.new(3, 9, 0.2), CFrame = frame * CFrame.new(0, 4.5, 1.35), Color = TEAM_COLORS[team], Material = Enum.Material.Fabric, CanCollide = false })
			part(model, { Name = "Faixa", Size = Vector3.new(3, 0.6, 0.25), CFrame = frame * CFrame.new(0, 8.4, 1.4), Color = GOLD, Material = Enum.Material.Metal, CanCollide = false })
		end
		if i % 4 == 2 then
			brazier(model, center * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -(RADIUS - 3)))
		end
	end
	-- arcos de entrada dos dois times
	for team = 1, 2 do
		local gate = center * CFrame.Angles(0, if team == 1 then 0 else math.pi, 0) * CFrame.new(0, 0, -(RADIUS + 1))
		for side = -1, 1, 2 do
			part(model, { Name = "Pilar", Size = Vector3.new(2.5, 14, 3.5), CFrame = gate * CFrame.new(side * 6, 7, 0), Color = STONE_DARK, Material = Enum.Material.Slate })
		end
		part(model, { Name = "Verga", Size = Vector3.new(14.5, 2.5, 3.5), CFrame = gate * CFrame.new(0, 15.25, 0), Color = STONE_DARK, Material = Enum.Material.Slate })
		part(model, { Name = "Grade", Size = Vector3.new(9.5, 14, 0.4), CFrame = gate * CFrame.new(0, 7, -0.6), Color = Color3.fromRGB(60, 55, 50), Material = Enum.Material.DiamondPlate, Transparency = 0.3 })
		part(model, { Name = "Bandeira", Size = Vector3.new(6, 4, 0.2), CFrame = gate * CFrame.new(0, 19, 0), Color = TEAM_COLORS[team], Material = Enum.Material.Fabric, CanCollide = false })
	end
	-- plataforma dos que caíram (assistem do alto, fora da luta)
	part(model, { Name = "Camarote", Size = Vector3.new(20, 1, 12), CFrame = center * CFrame.new(0, 26, RADIUS + 18), Color = STONE_DARK, Material = Enum.Material.Marble })
	part(model, { Name = "Toldo", Size = Vector3.new(22, 0.4, 14), CFrame = center * CFrame.new(0, 36, RADIUS + 18), Color = Color3.fromRGB(150, 40, 40), Material = Enum.Material.Fabric, CanCollide = false })
	for side = -1, 1, 2 do
		part(model, { Name = "MuretaCamarote", Size = Vector3.new(0.8, 3, 12), CFrame = center * CFrame.new(side * 10, 28, RADIUS + 18), Color = STONE, Material = Enum.Material.Marble })
	end
	part(model, { Name = "MuretaFrente", Size = Vector3.new(20, 3, 0.8), CFrame = center * CFrame.new(0, 28, RADIUS + 12), Color = STONE, Material = Enum.Material.Marble })
	-- pedras soltas e manchas na areia
	for _ = 1, 10 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(16, RADIUS - 6)
		part(model, { Name = "Mancha", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.06, rng:NextNumber(3, 7), rng:NextNumber(3, 7)), CFrame = center * CFrame.new(math.cos(a) * r, 0.03, math.sin(a) * r) * CFrame.Angles(0, 0, math.rad(90)), Color = SAND:Lerp(STONE_DARK, 0.25), Material = Enum.Material.Sand, CanCollide = false })
	end
	local container = workspace:FindFirstChild("Masmorras") or workspace
	model.Parent = container
	arenas[slot] = model
	return model
end

-- ===================== ALVOS (JOGADOR COMO "INIMIGO") =====================

local function proxyOf(player)
	local proxy = proxies[player]
	if not proxy then
		proxy = { proxy = true, player = player, height = 5.5, radius = 1.4, dots = {}, threat = {}, damageBy = {}, staggerUntil = 0, stunUntil = 0, def = { name = player.DisplayName, behavior = "player" } }
		proxies[player] = proxy
	end
	local root = rootOf(player)
	local humanoid = humanoidOf(player)
	local match = matchOf[player]
	if root and humanoid then
		local look = root.CFrame.LookVector
		proxy.root = root
		proxy.pos = root.Position - Vector3.new(0, 3, 0)
		proxy.yaw = math.atan2(-look.X, -look.Z)
		proxy.hp = humanoid.Health
		proxy.maxHp = humanoid.MaxHealth
		proxy.dead = humanoid.Health <= 1 or (match ~= nil and match.downed[player] == true)
	else
		proxy.dead = true
		proxy.pos = proxy.pos or Vector3.zero
		proxy.yaw = proxy.yaw or 0
		proxy.hp, proxy.maxHp = 0, 1
	end
	return proxy
end

function ArenaService.proxies(attacker)
	local match = matchOf[attacker]
	if not match then
		return nil
	end
	local list = {}
	if match.state ~= "live" or match.downed[attacker] then
		return list
	end
	local myTeam = teamOf(match, attacker)
	for index, team in match.teams do
		if index ~= myTeam then
			for _, player in team do
				if not match.downed[player] then
					local proxy = proxyOf(player)
					if not proxy.dead then
						table.insert(list, proxy)
					end
				end
			end
		end
	end
	return list
end

function ArenaService.isAlly(player, other)
	local match = matchOf[player]
	local otherMatch = matchOf[other]
	if not match and not otherMatch then
		return true
	end
	return match == otherMatch and teamOf(match, player) == teamOf(match, other)
end

local checkRound -- declarada abaixo

-- jogador chegou a 1 de vida: sai da rodada e assiste do camarote
local function down(match, player, by)
	if match.downed[player] then
		return
	end
	match.downed[player] = true
	local humanoid = humanoidOf(player)
	if humanoid then
		humanoid.Health = math.max(humanoid.Health, 1)
	end
	notifyAll(match, { kind = "message", text = ("%s derrubou %s!"):format(if by then by.DisplayName else "A arena", player.DisplayName) })
	Remotes.Notify:FireClient(player, { kind = "banner", text = "VOCÊ CAIU", sub = "Assista do camarote até a próxima rodada", color = Color3.fromRGB(220, 120, 120), duration = 3 })
	task.delay(0.8, function()
		if matchOf[player] == match and match.downed[player] then
			teleport(player, CFrame.new(match.center + Vector3.new(math.random(-6, 6), 29, RADIUS + 18)))
		end
	end)
	markAll(match)
	checkRound(match)
end

function ArenaService.proxyDamage(rec, amount, attacker, info)
	local target = rec.player
	local match = matchOf[attacker]
	if not match or matchOf[target] ~= match or match.state ~= "live" or match.downed[target] or match.downed[attacker] then
		return 0
	end
	if teamOf(match, attacker) == teamOf(match, target) then
		return 0
	end
	local humanoid = humanoidOf(target)
	if not humanoid or humanoid.Health <= 1 then
		return 0
	end
	local before = humanoid.Health
	local attackerRoot = rootOf(attacker)
	local origin = info.fromPosition or (if attackerRoot then attackerRoot.Position else rec.pos)
	PlayerService.damagePlayer(target, amount * Arena.DamageMult, origin, {
		source = proxyOf(attacker),
		unblockable = info.dot == true or info.perk == true,
		nonLethal = true,
	})
	local dealt = math.max(0, before - humanoid.Health)
	if dealt > 0 then
		local team = teamOf(match, attacker)
		match.damage[team] += dealt
		Remotes.Fx:FireAllClients("hit", rec.root, math.floor(dealt + 0.5), info.crit == true, attacker, info.color, nil, info.element or (if info.dot then "dot" else nil))
		if info.stun and not info.dot then
			CombatService.interrupt(target, math.min(info.stun, 0.6))
		end
		if humanoid.Health <= 1 then
			down(match, target, attacker)
		end
	end
	return dealt
end

-- veneno e queimadura entre jogadores: ticks de meio segundo
function ArenaService.proxyDot(rec, attacker, dps, duration, kind)
	local target = rec.player
	local key = kind .. ":" .. attacker.UserId
	rec.dots[key] = os.clock() + duration
	if rec.dots[key .. ":running"] then
		return
	end
	rec.dots[key .. ":running"] = true
	task.spawn(function()
		while os.clock() < (rec.dots[key] or 0) and matchOf[target] ~= nil and target.Parent == Players do
			task.wait(0.5)
			ArenaService.proxyDamage(proxyOf(target), dps * 0.5, attacker, { dot = true, element = kind })
		end
		rec.dots[key .. ":running"] = nil
	end)
end

-- golpe aparado: quem atacou fica sem atacar por um instante
function ArenaService.proxyParried(rec, _player)
	CombatService.interrupt(rec.player, 1)
	Remotes.Fx:FireClient(rec.player, "guardBreak")
end

-- ===================== PARTIDA =====================

local function spawnFrame(match, team, index)
	local side = if team == 1 then -1 else 1
	local position = match.center + Vector3.new((index - 2) * 6, 3.5, side * (RADIUS - 8))
	return CFrame.lookAt(position, Vector3.new(match.center.X, position.Y, match.center.Z))
end

local function refill(player)
	local humanoid = humanoidOf(player)
	if humanoid and humanoid.Health > 0 then
		humanoid.Health = humanoid.MaxHealth
	end
	PlayerService.restoreMana(player, 1)
	local s = PlayerService.getState(player)
	if s then
		s.stamina = PlayerService.getStats(player).maxStamina
	end
	local proxy = proxies[player]
	if proxy then
		proxy.dots = {}
	end
end

local startRound -- declarada abaixo

local function releaseMatch(match)
	busySlots[match.slot] = nil
	for _, player in everyone(match) do
		if matchOf[player] == match then
			matchOf[player] = nil
			player:SetAttribute("Arena", nil)
			player:SetAttribute("ArenaTeam", nil)
		end
	end
end

-- grava a pontuação no ranking da temporada (só funciona com o jogo publicado)
local function saveRanking(player, rating)
	task.spawn(function()
		pcall(function()
			DataStoreService:GetOrderedDataStore("Arena_T" .. Seasons.index()):SetAsync(tostring(player.UserId), rating)
			DataStoreService:GetDataStore("ArenaNomes"):SetAsync(tostring(player.UserId), player.DisplayName)
		end)
	end)
end

local function endMatch(match, winner)
	if match.state == "over" then
		return
	end
	match.state = "over"
	-- média de pontos de cada time (antes da partida)
	local averages = {}
	for index in match.teams do
		local sum, count = 0, 0
		for _, player in match.original[index] do
			sum += match.ratings[player] or Arena.StartRating
			count += 1
		end
		averages[index] = if count > 0 then sum / count else Arena.StartRating
	end
	for index, team in match.original do
		local won = index == winner
		local opponent = averages[if index == 1 then 2 else 1]
		for _, player in team do
			-- quem desistiu já perdeu os pontos ao sair
			if player.Parent ~= Players or match.quitters[player] then
				continue
			end
			local arena = arenaData(player)
			if not arena then
				continue
			end
			local before = arena.rating
			local delta = Arena.delta(match.ratings[player] or before, opponent, won)
			arena.rating = math.max(0, before + delta)
			arena.best = math.max(arena.best, arena.rating)
			if won then
				arena.wins += 1
			else
				arena.losses += 1
			end
			table.insert(arena.history, 1, { mode = match.mode, won = won, delta = delta, score = ("%d x %d"):format(match.score[index], match.score[if index == 1 then 2 else 1]), time = os.time() })
			while #arena.history > 10 do
				table.remove(arena.history)
			end
			local reward = if won then Arena.Rewards.win else Arena.Rewards.loss
			PlayerService.addGold(player, reward.gold)
			PlayerService.addXP(player, reward.xp)
			ArenaService.QuestHook(player, "arena", match.mode, 1)
			if won then
				ArenaService.QuestHook(player, "arenaWin", match.mode, 1)
			end
			-- título da divisão alcançada (fica para sempre)
			local division, divisionIndex = Arena.division(arena.rating)
			for i = 1, divisionIndex do
				local title = Arena.Divisions[i].title
				if title then
					ProgressionService.grant(player, { title = title })
				end
			end
			saveRanking(player, arena.rating)
			Remotes.Notify:FireClient(player, {
				kind = "banner",
				text = if won then "VITÓRIA!" else "DERROTA",
				sub = ("%s%d pontos  •  %s (%d)  •  +%d ouro"):format(if delta >= 0 then "+" else "", delta, division.name, arena.rating, reward.gold),
				color = if won then GOLD else Color3.fromRGB(200, 130, 130),
				duration = 5,
			})
			PlayerService.markDirty(player)
		end
	end
	task.delay(5, function()
		for _, player in everyone(match) do
			if player.Parent == Players and matchOf[player] == match then
				teleport(player, match.returnTo[player] or CFrame.new(0, 60, 0))
				refill(player)
			end
		end
		releaseMatch(match)
		markAll(match)
	end)
end

local function endRound(match, winner)
	if match.state ~= "live" then
		return
	end
	match.state = "between"
	match.score[winner] += 1
	local names = {}
	for _, player in match.teams[winner] do
		table.insert(names, player.DisplayName)
	end
	notifyAll(match, { kind = "banner", text = ("RODADA %d: %s"):format(match.round, if winner == 1 then "TIME AZUL" else "TIME VERMELHO"), sub = ("Placar %d x %d  •  %s"):format(match.score[1], match.score[2], table.concat(names, ", ")), color = TEAM_COLORS[winner], duration = 3 })
	markAll(match)
	if match.score[winner] >= Arena.RoundsToWin then
		task.delay(2, endMatch, match, winner)
	else
		task.delay(3.5, function()
			if match.state == "between" then
				startRound(match)
			end
		end)
	end
end

-- algum time ficou sem ninguém de pé (ou sem ninguém na partida)?
function checkRound(match)
	if match.state ~= "live" then
		return
	end
	local standing = { 0, 0 }
	for index, team in match.teams do
		for _, player in team do
			if not match.downed[player] and player.Parent == Players then
				standing[index] += 1
			end
		end
	end
	if standing[1] == 0 and standing[2] == 0 then
		endRound(match, if match.damage[1] >= match.damage[2] then 1 else 2)
	elseif standing[1] == 0 then
		endRound(match, 2)
	elseif standing[2] == 0 then
		endRound(match, 1)
	end
end

function startRound(match)
	match.round += 1
	match.state = "countdown"
	match.downed = {}
	match.damage = { 0, 0 }
	for index, team in match.teams do
		for i, player in team do
			refill(player)
			teleport(player, spawnFrame(match, index, i))
		end
	end
	match.startsAt = os.clock() + Arena.Countdown
	match.roundEnds = nil
	notifyAll(match, { kind = "banner", text = ("RODADA %d"):format(match.round), sub = ("Placar %d x %d  •  prepare-se..."):format(match.score[1], match.score[2]), color = GOLD, duration = 3 })
	markAll(match)
end

local function startMatch(mode, teams)
	local slot = nil
	for i = 1, MAX_SLOTS do
		if not busySlots[i] then
			slot = i
			break
		end
	end
	if not slot then
		return false
	end
	buildArena(slot)
	nextMatchId += 1
	local match = {
		id = nextMatchId,
		mode = mode,
		slot = slot,
		center = centerOf(slot),
		teams = teams,
		original = { table.clone(teams[1]), table.clone(teams[2]) },
		score = { 0, 0 },
		round = 0,
		state = "countdown",
		downed = {},
		damage = { 0, 0 },
		returnTo = {},
		ratings = {},
		quitters = {},
	}
	busySlots[slot] = match
	for index, team in teams do
		for _, player in team do
			local root = rootOf(player)
			match.returnTo[player] = if root then root.CFrame + Vector3.new(0, 1, 0) else nil
			local arena = arenaData(player)
			match.ratings[player] = if arena then arena.rating else Arena.StartRating
			matchOf[player] = match
			TravelService.dismount(player)
			player:SetAttribute("Arena", match.id)
			player:SetAttribute("ArenaTeam", index)
			player:SetAttribute("AutoFarm", false)
		end
	end
	notifyAll(match, { kind = "banner", text = string.upper(Arena.Modes[mode].name), sub = "Melhor de 3 rodadas. Esquiva, aparar e bloqueio valem!", color = GOLD, duration = 4 })
	startRound(match)
	return true
end

-- ===================== FILA =====================

local function removeFromQueues(player)
	for _, queue in queues do
		for i = #queue, 1, -1 do
			if queue[i].player == player then
				table.remove(queue, i)
			end
		end
	end
end

local function queuedMode(player)
	for mode, queue in queues do
		for _, entry in queue do
			if entry.player == player then
				return mode, entry.since
			end
		end
	end
	return nil
end

-- monta os dois times: mais perto em pontos, divididos em "serpentina" (1,2,2,1,1,2)
local function tryMatch(mode)
	local queue = queues[mode]
	local size = Arena.Modes[mode].teamSize
	-- tira quem saiu do jogo ou já está em luta
	for i = #queue, 1, -1 do
		local player = queue[i].player
		if player.Parent ~= Players or matchOf[player] or not rootOf(player) or player:GetAttribute("Dungeon") or player:GetAttribute("Raid") then
			table.remove(queue, i)
		end
	end
	if #queue < size * 2 then
		return
	end
	-- o mais antigo na fila escolhe primeiro; os outros são os mais parecidos em pontos
	local anchor = queue[1]
	local anchorRating = (arenaData(anchor.player) or { rating = Arena.StartRating }).rating
	local others = {}
	for i = 2, #queue do
		local arena = arenaData(queue[i].player)
		table.insert(others, { entry = queue[i], diff = math.abs((if arena then arena.rating else Arena.StartRating) - anchorRating), rating = if arena then arena.rating else Arena.StartRating })
	end
	table.sort(others, function(a, b)
		return a.diff < b.diff
	end)
	local picked = { { player = anchor.player, rating = anchorRating } }
	for i = 1, size * 2 - 1 do
		table.insert(picked, { player = others[i].entry.player, rating = others[i].rating })
	end
	table.sort(picked, function(a, b)
		return a.rating > b.rating
	end)
	local teams = { {}, {} }
	local order = { 1, 2, 2, 1, 1, 2 }
	for i, entry in picked do
		table.insert(teams[order[i]], entry.player)
	end
	for _, entry in picked do
		removeFromQueues(entry.player)
	end
	if not startMatch(mode, teams) then
		-- sem coliseu livre: volta todo mundo para o começo da fila
		for i = #picked, 1, -1 do
			table.insert(queue, 1, { player = picked[i].player, since = os.clock() })
		end
	end
end

-- ===================== PEDIDOS =====================

function ArenaService.join(player, mode)
	if not Arena.Modes[mode] then
		return { ok = false, msg = "Modo inválido." }
	end
	local data = DataService.get(player)
	if not data then
		return { ok = false, msg = "Dados indisponíveis." }
	end
	if data.level < Arena.MinLevel then
		return { ok = false, msg = ("A arena libera no nível %d."):format(Arena.MinLevel) }
	end
	if matchOf[player] then
		return { ok = false, msg = "Você já está numa luta." }
	end
	if player:GetAttribute("Dungeon") or player:GetAttribute("Raid") then
		return { ok = false, msg = "Saia da masmorra ou da raide primeiro." }
	end
	removeFromQueues(player)
	table.insert(queues[mode], { player = player, since = os.clock() })
	Remotes.Notify:FireClient(player, { kind = "message", text = ("Na fila de %s. Pode continuar jogando: você será chamado."):format(Arena.Modes[mode].name) })
	PlayerService.markDirty(player)
	return { ok = true }
end

function ArenaService.leaveQueue(player)
	removeFromQueues(player)
	PlayerService.markDirty(player)
	return { ok = true }
end

-- sair da luta = desistir (o time perde se ficar sem ninguém)
function ArenaService.forfeit(player)
	local match = matchOf[player]
	if not match then
		return { ok = false, msg = "Você não está numa luta." }
	end
	local team = teamOf(match, player)
	match.quitters[player] = true
	if team then
		local list = match.teams[team]
		table.remove(list, table.find(list, player))
	end
	matchOf[player] = nil
	player:SetAttribute("Arena", nil)
	player:SetAttribute("ArenaTeam", nil)
	if player.Parent == Players then
		teleport(player, match.returnTo[player] or CFrame.new(0, 60, 0))
		refill(player)
		-- quem desiste perde como derrota
		local arena = arenaData(player)
		if arena and match.state ~= "over" then
			local opponent = 0
			local count = 0
			for _, other in match.original[if team == 1 then 2 else 1] do
				opponent += match.ratings[other] or Arena.StartRating
				count += 1
			end
			local delta = Arena.delta(arena.rating, if count > 0 then opponent / count else Arena.StartRating, false)
			arena.rating = math.max(0, arena.rating + delta)
			arena.losses += 1
			table.insert(arena.history, 1, { mode = match.mode, won = false, delta = delta, score = "desistiu", time = os.time() })
			while #arena.history > 10 do
				table.remove(arena.history)
			end
			saveRanking(player, arena.rating)
		end
		PlayerService.markDirty(player)
	end
	if team and #match.teams[team] == 0 and match.state ~= "over" then
		match.state = "live"
		endMatch(match, if team == 1 then 2 else 1)
	else
		checkRound(match)
	end
	markAll(match)
	return { ok = true }
end

-- ranking da temporada (top 20), guardado por 60 s
local rankingCache = nil
function ArenaService.ranking(_player)
	if rankingCache and os.clock() - rankingCache.time < 60 then
		return { ok = true, list = rankingCache.list }
	end
	local list = {}
	local ok = pcall(function()
		local page = DataStoreService:GetOrderedDataStore("Arena_T" .. Seasons.index()):GetSortedAsync(false, 20):GetCurrentPage()
		local names = DataStoreService:GetDataStore("ArenaNomes")
		for position, entry in page do
			local name = names:GetAsync(entry.key)
			table.insert(list, { position = position, rating = entry.value, name = if type(name) == "string" then name else "?" })
		end
	end)
	if not ok then
		return { ok = false, msg = "Ranking indisponível (precisa do jogo publicado)." }
	end
	rankingCache = { time = os.clock(), list = list }
	return { ok = true, list = list }
end

-- resumo para a interface
function ArenaService.summary(player)
	local data = DataService.get(player)
	if not data then
		return nil
	end
	local arena = arenaData(player)
	local mode, since = queuedMode(player)
	local queueSizes = {}
	for id, queue in queues do
		queueSizes[id] = #queue
	end
	local division = Arena.division(arena.rating)
	local result = {
		rating = arena.rating,
		best = arena.best,
		wins = arena.wins,
		losses = arena.losses,
		division = division.id,
		history = arena.history,
		queued = mode,
		waiting = if since then math.floor(os.clock() - since) else nil,
		queues = queueSizes,
	}
	local match = matchOf[player]
	if match then
		local team = teamOf(match, player)
		local teams = {}
		for index, list in match.teams do
			local members = {}
			for _, member in list do
				local humanoid = humanoidOf(member)
				table.insert(members, {
					name = member.DisplayName,
					hp = if humanoid then math.floor(humanoid.Health / math.max(humanoid.MaxHealth, 1) * 100) else 0,
					down = match.downed[member] == true,
				})
			end
			teams[index] = members
		end
		result.match = {
			mode = match.mode,
			team = team,
			round = match.round,
			score = match.score,
			state = match.state,
			teams = teams,
			startsIn = if match.state == "countdown" and match.startsAt then math.max(0, math.ceil(match.startsAt - os.clock())) else nil,
			endsIn = if match.state == "live" and match.roundEnds then math.max(0, math.floor(match.roundEnds - os.clock())) else nil,
		}
	end
	return result
end

-- ===================== GANCHOS =====================

function ArenaService.onCharacterAdded(player, character)
	local match = matchOf[player]
	if not match then
		return
	end
	-- morreu de alguma outra forma: volta como caído (assistindo) até a próxima rodada
	task.defer(function()
		character:WaitForChild("HumanoidRootPart", 5)
		if matchOf[player] == match and match.state ~= "over" then
			match.downed[player] = true
			teleport(player, CFrame.new(match.center + Vector3.new(0, 29, RADIUS + 18)))
			checkRound(match)
		end
	end)
end

function ArenaService.onPlayerRemoving(player)
	removeFromQueues(player)
	if matchOf[player] then
		ArenaService.forfeit(player)
	end
	proxies[player] = nil
end

function ArenaService.init()
	task.spawn(function()
		local tick = 0
		while true do
			task.wait(0.25)
			tick += 1
			-- partidas: contagem, tempo da rodada, quem caiu da arena
			for _, match in busySlots do
				if match.state == "countdown" and match.startsAt and os.clock() >= match.startsAt then
					match.state = "live"
					match.roundEnds = os.clock() + Arena.RoundTime
					notifyAll(match, { kind = "banner", text = "LUTEM!", sub = ("Rodada %d"):format(match.round), color = Color3.fromRGB(255, 120, 80), duration = 1.5 })
					markAll(match)
				elseif match.state == "live" then
					for _, player in everyone(match) do
						local root = rootOf(player)
						local humanoid = humanoidOf(player)
						if not match.downed[player] and humanoid and (humanoid.Health <= 1 or (root and root.Position.Y < match.center.Y - 20)) then
							down(match, player, nil)
						end
					end
					if match.state == "live" and os.clock() >= (match.roundEnds or math.huge) then
						-- tempo acabou: ganha quem tem mais vida somada (em %); empate vai pelo dano causado
						local health = { 0, 0 }
						for index, team in match.teams do
							for _, player in team do
								local humanoid = humanoidOf(player)
								if humanoid and not match.downed[player] then
									health[index] += humanoid.Health / math.max(humanoid.MaxHealth, 1)
								end
							end
						end
						local winner = if math.abs(health[1] - health[2]) > 0.001 then (if health[1] > health[2] then 1 else 2) else (if match.damage[1] >= match.damage[2] then 1 else 2)
						endRound(match, winner)
					end
				end
				-- painel (vida dos times e tempo) duas vezes por segundo
				if tick % 2 == 0 and match.state ~= "over" then
					markAll(match)
				end
			end
			-- fila: tenta montar lutas a cada segundo
			if tick % 4 == 0 then
				for mode in queues do
					pcall(tryMatch, mode)
				end
			end
		end
	end)
end

return ArenaService
