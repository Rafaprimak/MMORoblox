-- Guildas (entre servidores):
--   * Registro (fonte da verdade): DataStore "Guildas_v1", chave "guilda_<id>":
--     { id, name, tag, icon, color = {r,g,b}, leader, members = { [userId] = { name, rank, joined, seen } },
--       bank = n, xp, week, weekly = { [metaId] = progresso }, claims = { [userId] = { [metaId] = true } },
--       log = { ... últimos 20 } }. Toda mudança é por UpdateAsync (atômica).
--   * Nomes únicos: DataStore "GuildasNomes_v1" (nome minúsculo → id).
--   * Ranking da semana: OrderedDataStore "GuildasSemana_<semana>" (id → pontos da semana).
--   * Perfil do jogador: data.guild = id (o registro manda: se ele não está nos membros, sai).
--   * Entre servidores: MessagingService "Guildas" { guild, kind = "chat" | "refresh" | "notice", ... }.
--   * Pontos: as ações dos membros (abates, chefes, masmorras, segredos...) somam XP da guilda e o progresso
--     das metas da semana; ficam num buffer por servidor e vão para o registro de minuto em minuto.
--   * Nível da guilda: +1% de XP e +1% de ouro por nível para os membros (até o nível 20).
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local TextService = game:GetService("TextService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Guilds = require(Shared.Guilds)

local DataService = require(script.Parent.DataService)
local PlayerService = require(script.Parent.PlayerService)
local ShopService = require(script.Parent.ShopService)

local GuildService = {}

local store, names = nil, nil
pcall(function()
	store = DataStoreService:GetDataStore("Guildas_v1")
	names = DataStoreService:GetDataStore("GuildasNomes_v1")
end)

local TOPIC = "Guildas"
local cache = {} -- [id] = { record, time }
local pending = {} -- [id] = { xp, weekly = { [meta] = n }, points }
local invites = {} -- [convidado] = { guild, from, time }
local busy = {} -- [player] = true
local rankingCache = { time = 0, list = {} }

local function available()
	return store ~= nil
end

local function key(id)
	return "guilda_" .. id
end

local function week()
	return Guilds.week(os.time())
end

local function rankOf(record, userId)
	local member = record and record.members[tostring(userId)]
	return member and member.rank or nil
end

local function canManage(record, userId)
	local rank = rankOf(record, userId)
	return rank == "lider" or rank == "oficial"
end

-- lê o registro (com cache de alguns segundos)
local function fetch(id, fresh)
	if not id or not available() then
		return nil
	end
	local entry = cache[id]
	if entry and not fresh and os.clock() - entry.time < 20 then
		return entry.record
	end
	local ok, record = pcall(store.GetAsync, store, key(id))
	if ok then
		cache[id] = { record = record, time = os.clock() }
		return record
	end
	return entry and entry.record or nil
end

-- muda o registro de forma atômica; fn(record) devolve true para gravar (ou false/nil para desistir)
local function update(id, fn)
	local result, ok = nil, false
	local success = pcall(function()
		store:UpdateAsync(key(id), function(record)
			if not record then
				ok = false
				return nil
			end
			-- semana nova: zera as metas e os resgates
			if record.week ~= week() then
				record.week = week()
				record.weekly = {}
				record.claims = {}
			end
			local changed, value = fn(record)
			ok = changed == true
			result = value
			if ok then
				return record
			end
			return nil
		end)
	end)
	if success and ok then
		local entry = cache[id]
		cache[id] = { record = entry and entry.record, time = 0 } -- força ler de novo
	end
	return success and ok, result
end

local function addLog(record, text)
	record.log = record.log or {}
	table.insert(record.log, 1, { t = os.time(), text = text })
	while #record.log > 20 do
		table.remove(record.log)
	end
end

local function publish(message)
	pcall(function()
		MessagingService:PublishAsync(TOPIC, HttpService:JSONEncode(message))
	end)
end

-- avisa todos os servidores que a guilda mudou (lista de membros, banco...)
local function refreshEverywhere(id)
	publish({ guild = id, kind = "refresh" })
end

local function onlineMembers(id)
	local list = {}
	for _, player in Players:GetPlayers() do
		local data = DataService.get(player)
		if data and data.guild == id then
			table.insert(list, player)
		end
	end
	return list
end

local function markMembers(id)
	cache[id] = nil
	for _, player in onlineMembers(id) do
		PlayerService.markDirty(player)
	end
end

-- texto passa pelo filtro do Roblox (obrigatório para texto de jogador visto por outros)
local function filtered(text, userId)
	local ok, result = pcall(function()
		local object = TextService:FilterStringAsync(text, userId, Enum.TextFilterContext.PublicChat)
		return object:GetNonChatStringForBroadcastAsync()
	end)
	return if ok then result else nil
end

-- marca [TAG] no nome em cima da cabeça
local function applyTag(player, record)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayName = if record then ("[%s] %s"):format(record.tag, player.DisplayName) else player.DisplayName
	end
end

-- ===================== CONSULTAS =====================

function GuildService.get(player)
	local data = DataService.get(player)
	return data and data.guild and fetch(data.guild) or nil
end

-- bônus do nível da guilda (gancho ExtraBonus do PlayerService)
function GuildService.applyBonus(_player, data, bonus)
	local record = data and data.guild and cache[data.guild] and cache[data.guild].record
	if record then
		local level = Guilds.level(record.xp or 0)
		bonus.xpGain = (bonus.xpGain or 0) + level * Guilds.BonusPerLevel
		bonus.goldFind = (bonus.goldFind or 0) + level * Guilds.BonusPerLevel
	end
end

-- registro do cache sem esperar a rede (o envio de dados para a interface não pode travar);
-- se estiver velho, atualiza em segundo plano
local refreshing = {}
local function peek(id)
	local entry = cache[id]
	if (not entry or os.clock() - entry.time > 20) and not refreshing[id] then
		refreshing[id] = true
		task.spawn(function()
			fetch(id, true)
			refreshing[id] = nil
			for _, player in onlineMembers(id) do
				PlayerService.markDirty(player)
			end
		end)
	end
	return entry and entry.record
end

-- payload para a interface
function GuildService.payload(player)
	local data = DataService.get(player)
	if not data then
		return nil
	end
	local invite = invites[player]
	local result = { invite = if invite and os.clock() - invite.time < 60 then { name = invite.name, from = invite.fromName } else nil }
	local record = data.guild and peek(data.guild)
	if not record then
		return result
	end
	local members = {}
	for userId, member in record.members do
		local online = Players:GetPlayerByUserId(tonumber(userId))
		table.insert(members, { id = tonumber(userId), name = member.name, rank = member.rank, online = online ~= nil, seen = member.seen or member.joined })
	end
	table.sort(members, function(a, b)
		local order = { lider = 1, oficial = 2, membro = 3 }
		if order[a.rank] ~= order[b.rank] then
			return order[a.rank] < order[b.rank]
		end
		return a.name < b.name
	end)
	local level = Guilds.level(record.xp or 0)
	local goals = {}
	local currentWeek = week()
	local claims = if record.week == currentWeek and record.claims then record.claims[tostring(player.UserId)] or {} else {}
	for _, goal in Guilds.goalsForWeek(currentWeek) do
		local progress = if record.week == currentWeek and record.weekly then record.weekly[goal.id] or 0 else 0
		table.insert(goals, { id = goal.id, text = goal.text, icon = goal.icon, target = goal.target, progress = progress, claimed = claims[goal.id] == true, gold = goal.gold })
	end
	result.guild = {
		id = record.id,
		name = record.name,
		tag = record.tag,
		icon = record.icon,
		color = record.color,
		level = level,
		xp = record.xp or 0,
		xpThis = Guilds.xpForLevel(level),
		xpNext = Guilds.xpForLevel(level + 1),
		bank = record.bank or 0,
		rank = rankOf(record, player.UserId),
		members = members,
		max = Guilds.MaxMembers,
		goals = goals,
		log = record.log or {},
		bonus = level * Guilds.BonusPerLevel,
	}
	return result
end

-- ===================== PONTOS (ações dos membros) =====================

-- chamado com todos os eventos de missão (init.server → questHook)
function GuildService.track(player, kind, amount)
	local data = DataService.get(player)
	if not data or not data.guild then
		return
	end
	local points = Guilds.Points[kind]
	local goals = Guilds.GoalEvents[kind]
	if not points and not goals then
		return
	end
	local buffer = pending[data.guild]
	if not buffer then
		buffer = { xp = 0, weekly = {}, points = 0 }
		pending[data.guild] = buffer
	end
	amount = amount or 1
	if points then
		buffer.xp += points * amount
		buffer.points += points * amount
	end
	for _, goalId in goals or {} do
		buffer.weekly[goalId] = (buffer.weekly[goalId] or 0) + amount
	end
end

local function flush()
	local currentWeek = week()
	for id, buffer in pending do
		pending[id] = nil
		local ok = update(id, function(record)
			record.xp = (record.xp or 0) + buffer.xp
			record.weekly = record.weekly or {}
			for goalId, amount in buffer.weekly do
				record.weekly[goalId] = (record.weekly[goalId] or 0) + amount
			end
			record.weekPoints = (if record.weekPointsWeek == currentWeek then record.weekPoints or 0 else 0) + buffer.points
			record.weekPointsWeek = currentWeek
			-- "visto por último" dos membros online aqui
			for _, player in onlineMembers(id) do
				local member = record.members[tostring(player.UserId)]
				if member then
					member.seen = os.time()
				end
			end
			return true, record.weekPoints
		end)
		if ok then
			local record = fetch(id, true)
			if record and record.weekPoints then
				pcall(function()
					DataStoreService:GetOrderedDataStore("GuildasSemana_" .. currentWeek):SetAsync(id, record.weekPoints)
				end)
			end
			markMembers(id)
		end
	end
end

-- ===================== PEDIDOS =====================

local function guard(player)
	if not available() then
		return nil, "Guildas indisponíveis agora (precisa do jogo publicado)."
	end
	local data = DataService.get(player)
	if not data then
		return nil, "Perfil não carregado."
	end
	if busy[player] then
		return nil, "Espere a operação anterior terminar."
	end
	return data
end

function GuildService.create(player, name, tag, icon)
	local data, err = guard(player)
	if not data then
		return { ok = false, msg = err }
	end
	if data.guild then
		return { ok = false, msg = "Saia da sua guilda antes de criar outra." }
	end
	if data.level < Guilds.CreateLevel then
		return { ok = false, msg = ("Criar guilda libera no nível %d."):format(Guilds.CreateLevel) }
	end
	if data.gold < Guilds.CreateCost then
		return { ok = false, msg = ("Criar uma guilda custa %d de ouro."):format(Guilds.CreateCost) }
	end
	if typeof(name) ~= "string" or typeof(tag) ~= "string" then
		return { ok = false, msg = "Nome inválido." }
	end
	name = string.gsub(name, "^%s+", "")
	name = string.gsub(name, "%s+$", "")
	tag = string.upper(tag)
	if utf8.len(name) == nil or utf8.len(name) < 3 or utf8.len(name) > 20 then
		return { ok = false, msg = "O nome precisa ter de 3 a 20 letras." }
	end
	if not string.match(tag, "^%u%u%u?%u?$") then
		return { ok = false, msg = "A sigla precisa ter de 2 a 4 letras (A-Z)." }
	end
	local cleanName, cleanTag = filtered(name, player.UserId), filtered(tag, player.UserId)
	if not cleanName or not cleanTag or cleanName ~= name or cleanTag ~= tag then
		return { ok = false, msg = "Esse nome não é permitido. Escolha outro." }
	end
	if typeof(icon) ~= "string" or not table.find(Guilds.Emblems, icon) then
		icon = Guilds.Emblems[1]
	end
	busy[player] = true
	local id = HttpService:GenerateGUID(false)
	-- reserva o nome (único)
	local reserved = false
	pcall(function()
		names:UpdateAsync(string.lower(name), function(current)
			if current then
				reserved = false
				return nil
			end
			reserved = true
			return id
		end)
	end)
	if not reserved then
		busy[player] = nil
		return { ok = false, msg = "Já existe uma guilda com esse nome." }
	end
	-- cobra e grava o perfil antes de criar
	data.gold -= Guilds.CreateCost
	data.guild = id
	if not DataService.save(player) then
		data.gold += Guilds.CreateCost
		data.guild = nil
		pcall(names.RemoveAsync, names, string.lower(name))
		busy[player] = nil
		return { ok = false, msg = "Não deu para salvar agora. Tente de novo." }
	end
	local record = {
		id = id,
		name = name,
		tag = tag,
		icon = icon,
		color = { 255, 205, 90 },
		leader = player.UserId,
		members = { [tostring(player.UserId)] = { name = player.DisplayName, rank = "lider", joined = os.time(), seen = os.time() } },
		bank = 0,
		xp = 0,
		week = week(),
		weekly = {},
		claims = {},
		log = { { t = os.time(), text = ("%s fundou a guilda."):format(player.DisplayName) } },
		created = os.time(),
	}
	local ok = pcall(function()
		store:SetAsync(key(id), record)
	end)
	busy[player] = nil
	if not ok then
		-- devolve (o registro não existe: o próximo acerto também limparia data.guild)
		data.gold += Guilds.CreateCost
		data.guild = nil
		DataService.save(player)
		return { ok = false, msg = "Não deu para criar agora. Seu ouro voltou." }
	end
	cache[id] = { record = record, time = os.clock() }
	applyTag(player, record)
	PlayerService.markDirty(player)
	GuildService.QuestHook(player, "guildJoin", nil, 1)
	return { ok = true, msg = ("Guilda [%s] %s fundada!"):format(tag, name) }
end

function GuildService.invite(player, targetId)
	local data, err = guard(player)
	if not data then
		return { ok = false, msg = err }
	end
	local record = data.guild and fetch(data.guild)
	if not record or not canManage(record, player.UserId) then
		return { ok = false, msg = "Só o líder ou oficiais podem convidar." }
	end
	local target = typeof(targetId) == "number" and Players:GetPlayerByUserId(targetId)
	local targetData = target and DataService.get(target)
	if not target or not targetData then
		return { ok = false, msg = "Jogador não encontrado neste servidor." }
	end
	if targetData.guild then
		return { ok = false, msg = "Esse jogador já tem guilda." }
	end
	local count = 0
	for _ in record.members do
		count += 1
	end
	if count >= Guilds.MaxMembers then
		return { ok = false, msg = "A guilda está cheia." }
	end
	invites[target] = { guild = record.id, name = record.name, from = player, fromName = player.DisplayName, time = os.clock() }
	Remotes.Notify:FireClient(target, { kind = "guildInvite", name = record.name, tag = record.tag, from = player.DisplayName })
	PlayerService.markDirty(target)
	return { ok = true, msg = ("Convite enviado para %s."):format(target.DisplayName) }
end

function GuildService.respond(player, accept)
	local data, err = guard(player)
	local invite = invites[player]
	invites[player] = nil
	if not data then
		return { ok = false, msg = err }
	end
	if not invite or os.clock() - invite.time > 60 then
		return { ok = false, msg = "O convite expirou." }
	end
	if accept ~= true then
		PlayerService.markDirty(player)
		return { ok = true }
	end
	if data.guild then
		return { ok = false, msg = "Você já tem guilda." }
	end
	busy[player] = true
	local ok = update(invite.guild, function(record)
		local count = 0
		for _ in record.members do
			count += 1
		end
		if count >= Guilds.MaxMembers then
			return false
		end
		record.members[tostring(player.UserId)] = { name = player.DisplayName, rank = "membro", joined = os.time(), seen = os.time() }
		addLog(record, ("%s entrou na guilda."):format(player.DisplayName))
		return true
	end)
	if ok then
		data.guild = invite.guild
		DataService.save(player)
	end
	busy[player] = nil
	if not ok then
		return { ok = false, msg = "Não deu para entrar (guilda cheia ou fora do ar)." }
	end
	local record = fetch(invite.guild, true)
	applyTag(player, record)
	refreshEverywhere(invite.guild)
	markMembers(invite.guild)
	GuildService.QuestHook(player, "guildJoin", nil, 1)
	return { ok = true, msg = ("Bem-vindo à %s!"):format(record and record.name or "guilda") }
end

local function removeMember(id, userId, logText)
	return update(id, function(record)
		local member = record.members[tostring(userId)]
		if not member then
			return false
		end
		record.members[tostring(userId)] = nil
		addLog(record, logText)
		-- líder saiu: o oficial (ou membro) mais antigo assume
		if record.leader == userId then
			local best, bestTime = nil, math.huge
			for otherId, other in record.members do
				local weight = (if other.rank == "oficial" then 0 else 1e10) + (other.joined or 0)
				if weight < bestTime then
					best, bestTime = otherId, weight
				end
			end
			if best then
				record.leader = tonumber(best)
				record.members[best].rank = "lider"
				addLog(record, ("%s agora lidera a guilda."):format(record.members[best].name))
			end
		end
		return true
	end)
end

function GuildService.leave(player)
	local data, err = guard(player)
	if not data then
		return { ok = false, msg = err }
	end
	local id = data.guild
	if not id then
		return { ok = false, msg = "Você não tem guilda." }
	end
	busy[player] = true
	removeMember(id, player.UserId, ("%s saiu da guilda."):format(player.DisplayName))
	data.guild = nil
	DataService.save(player)
	busy[player] = nil
	applyTag(player, nil)
	refreshEverywhere(id)
	markMembers(id)
	PlayerService.markDirty(player)
	return { ok = true, msg = "Você saiu da guilda." }
end

function GuildService.kick(player, targetId)
	local data, err = guard(player)
	if not data then
		return { ok = false, msg = err }
	end
	local record = data.guild and fetch(data.guild, true)
	if not record or typeof(targetId) ~= "number" then
		return { ok = false, msg = "Guilda não encontrada." }
	end
	local myRank, theirRank = rankOf(record, player.UserId), rankOf(record, targetId)
	if not theirRank or targetId == player.UserId then
		return { ok = false, msg = "Membro não encontrado." }
	end
	if not (myRank == "lider" or (myRank == "oficial" and theirRank == "membro")) then
		return { ok = false, msg = "Você não pode remover esse membro." }
	end
	local name = record.members[tostring(targetId)].name
	removeMember(record.id, targetId, ("%s foi removido por %s."):format(name, player.DisplayName))
	local target = Players:GetPlayerByUserId(targetId)
	local targetData = target and DataService.get(target)
	if targetData and targetData.guild == record.id then
		targetData.guild = nil
		applyTag(target, nil)
		Remotes.Notify:FireClient(target, { kind = "message", text = "Você foi removido da guilda." })
		PlayerService.markDirty(target)
	end
	refreshEverywhere(record.id)
	markMembers(record.id)
	return { ok = true }
end

-- líder muda o cargo: "oficial" | "membro" | "lider" (passa a liderança)
function GuildService.setRank(player, targetId, rank)
	local data, err = guard(player)
	if not data then
		return { ok = false, msg = err }
	end
	if typeof(targetId) ~= "number" or not (rank == "oficial" or rank == "membro" or rank == "lider") then
		return { ok = false, msg = "Cargo inválido." }
	end
	local ok = data.guild and update(data.guild, function(record)
		if record.leader ~= player.UserId or not record.members[tostring(targetId)] or targetId == player.UserId then
			return false
		end
		if rank == "lider" then
			record.members[tostring(player.UserId)].rank = "oficial"
			record.leader = targetId
		end
		record.members[tostring(targetId)].rank = rank
		addLog(record, ("%s agora é %s."):format(record.members[tostring(targetId)].name, Guilds.RankNames[rank]))
		return true
	end)
	if not ok then
		return { ok = false, msg = "Só o líder pode mudar cargos." }
	end
	refreshEverywhere(data.guild)
	markMembers(data.guild)
	return { ok = true }
end

-- banco: depositar (qualquer membro) e sacar (líder e oficiais)
function GuildService.bank(player, amount, withdraw)
	local data, err = guard(player)
	if not data then
		return { ok = false, msg = err }
	end
	if not data.guild or typeof(amount) ~= "number" or amount ~= amount then
		return { ok = false, msg = "Valor inválido." }
	end
	amount = math.floor(amount)
	if amount < 1 or amount > 100000000 then
		return { ok = false, msg = "Valor inválido." }
	end
	local id = data.guild
	busy[player] = true
	if withdraw == true then
		local ok = update(id, function(record)
			if not canManage(record, player.UserId) or (record.bank or 0) < amount then
				return false
			end
			record.bank -= amount
			addLog(record, ("%s sacou %d de ouro."):format(player.DisplayName, amount))
			return true
		end)
		if ok then
			data.gold += amount
			DataService.save(player)
		end
		busy[player] = nil
		PlayerService.markDirty(player)
		markMembers(id)
		return if ok then { ok = true } else { ok = false, msg = "Só líder e oficiais sacam, e o banco precisa ter o valor." }
	end
	if data.gold < amount then
		busy[player] = nil
		return { ok = false, msg = "Ouro insuficiente." }
	end
	-- deposita: tira do jogador e grava antes; se o banco falhar, devolve
	data.gold -= amount
	if not DataService.save(player) then
		data.gold += amount
		busy[player] = nil
		return { ok = false, msg = "Não deu para salvar agora. Tente de novo." }
	end
	local ok = update(id, function(record)
		if not record.members[tostring(player.UserId)] then
			return false
		end
		record.bank = (record.bank or 0) + amount
		addLog(record, ("%s depositou %d de ouro."):format(player.DisplayName, amount))
		return true
	end)
	if not ok then
		data.gold += amount
		DataService.save(player)
	end
	busy[player] = nil
	PlayerService.markDirty(player)
	markMembers(id)
	return if ok then { ok = true } else { ok = false, msg = "O banco não respondeu. Seu ouro voltou." }
end

-- resgata a recompensa de uma meta da semana (cada membro uma vez)
function GuildService.claim(player, goalId)
	local data, err = guard(player)
	if not data then
		return { ok = false, msg = err }
	end
	local goal = nil
	for _, candidate in Guilds.goalsForWeek(week()) do
		if candidate.id == goalId then
			goal = candidate
		end
	end
	if not data.guild or not goal then
		return { ok = false, msg = "Meta inválida." }
	end
	busy[player] = true
	local ok = update(data.guild, function(record)
		if not record.members[tostring(player.UserId)] or (record.weekly[goal.id] or 0) < goal.target then
			return false
		end
		local mine = record.claims[tostring(player.UserId)] or {}
		if mine[goal.id] then
			return false
		end
		mine[goal.id] = true
		record.claims[tostring(player.UserId)] = mine
		return true
	end)
	if ok then
		data.gold += goal.gold
		DataService.save(player)
		ShopService.grant(player, goal.chest or "bronze")
	end
	busy[player] = nil
	PlayerService.markDirty(player)
	return if ok then { ok = true, msg = ("+%d de ouro e um baú!"):format(goal.gold) } else { ok = false, msg = "Meta ainda não concluída (ou já resgatada)." }
end

-- chat da guilda (todos os servidores)
function GuildService.chat(player, text)
	local data = DataService.get(player)
	if not data or not data.guild or typeof(text) ~= "string" or #text == 0 then
		return { ok = false, msg = "Você não tem guilda." }
	end
	text = string.sub(text, 1, 200)
	local clean = filtered(text, player.UserId)
	if not clean then
		return { ok = false, msg = "Não deu para enviar agora." }
	end
	local message = { guild = data.guild, kind = "chat", from = player.DisplayName, text = clean }
	publish(message)
	-- (MessagingService também entrega neste servidor; se falhar, mostra pelo menos aqui)
	return { ok = true }
end

-- ranking da semana (top 20)
function GuildService.ranking(_player)
	if not available() then
		return { ok = false, msg = "Ranking indisponível." }
	end
	if os.clock() - rankingCache.time > 120 then
		local ok, pages = pcall(function()
			return DataStoreService:GetOrderedDataStore("GuildasSemana_" .. week()):GetSortedAsync(false, 20)
		end)
		if ok then
			local list = {}
			for position, entry in pages:GetCurrentPage() do
				local record = fetch(entry.key)
				table.insert(list, { position = position, name = record and record.name or "?", tag = record and record.tag or "?", points = entry.value, icon = record and record.icon })
			end
			rankingCache = { time = os.clock(), list = list }
		end
	end
	return { ok = true, list = rankingCache.list }
end

-- ===================== CICLO =====================

local function onMessage(packet)
	local ok, message = pcall(HttpService.JSONDecode, HttpService, packet.Data)
	if not ok or type(message) ~= "table" or not message.guild then
		return
	end
	local members = onlineMembers(message.guild)
	if #members == 0 then
		return
	end
	if message.kind == "chat" then
		for _, player in members do
			Remotes.Notify:FireClient(player, { kind = "guildChat", from = message.from, text = message.text })
		end
	elseif message.kind == "refresh" then
		markMembers(message.guild)
	end
end

-- confere se cada jogador online ainda está na guilda (expulso em outro servidor, guilda apagada...)
local function verify()
	for _, player in Players:GetPlayers() do
		local data = DataService.get(player)
		if data and data.guild then
			local record = fetch(data.guild, true)
			if record and not record.members[tostring(player.UserId)] then
				data.guild = nil
				applyTag(player, nil)
				PlayerService.markDirty(player)
			elseif record then
				applyTag(player, record)
			end
		end
	end
end

function GuildService.onPlayerReady(player)
	task.delay(3, function()
		local record = GuildService.get(player)
		applyTag(player, record)
		PlayerService.markDirty(player)
	end)
	player.CharacterAdded:Connect(function()
		task.wait(1)
		applyTag(player, GuildService.get(player))
	end)
end

function GuildService.onPlayerRemoving(player)
	invites[player] = nil
	busy[player] = nil
end

GuildService.QuestHook = function(_player, _kind, _target, _amount) end

function GuildService.start()
	-- bônus do nível da guilda junto com o dos pets (o gancho já tem o do PetService)
	local previous = PlayerService.ExtraBonus
	PlayerService.ExtraBonus = function(player, data, bonus)
		previous(player, data, bonus)
		GuildService.applyBonus(player, data, bonus)
	end
	-- em segundo plano: no Studio (ou com o serviço fora do ar) a assinatura pode demorar muito
	task.spawn(pcall, function()
		MessagingService:SubscribeAsync(TOPIC, onMessage)
	end)
	task.spawn(function()
		while true do
			task.wait(60)
			pcall(flush)
			pcall(verify)
		end
	end)
end

return GuildService
