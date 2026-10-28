-- Ferramentas de administrador e configuração remota.
--   * Quem é admin: dono do jogo (ou cargo >= Config.AdminGroupRank no grupo dono), IDs em Config.Admins e
--     todo mundo no Studio. Atributo "Admin" no jogador liga o botão do painel no cliente.
--   * Configuração remota (RemoteConfig): DataStore "ConfigRemota_v1", aplicada em todos os servidores na
--     hora pelo MessagingService ("Admin") e relida a cada 2 min (segurança se uma mensagem se perder).
--   * Comandos: anúncio global (filtrado), expulsar, banir (DataStore "Banidos_v1", com prazo), desbanir,
--     dar ouro/XP, ir até/trazer jogador, chefe de mundo, invasão, evento sazonal.
--   * Tudo fica registrado em "AdminLog_v1" (últimas 100 ações).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local TextService = game:GetService("TextService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local RemoteConfig = require(Shared.RemoteConfig)
local Arena = require(Shared.Arena)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local PlayerService = require(script.Parent.PlayerService)
local EnemyService = require(script.Parent.EnemyService)
local AntiCheat = require(script.Parent.AntiCheat)
local WorldEventService = require(script.Parent.WorldEventService)
local EventService = require(script.Parent.EventService)

local AdminService = {}

local TOPIC = "Admin"
local values = RemoteConfig.defaults()
local logCache = {}

local function store(name)
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(name)
	end)
	return if ok then result else nil
end

function AdminService.isAdmin(player)
	if RunService:IsStudio() then
		return true
	end
	if table.find(Config.Admins, player.UserId) then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId
	end
	local ok, rank = pcall(function()
		return player:GetRankInGroup(game.CreatorId)
	end)
	return ok and rank >= Config.AdminGroupRank
end

-- ===================== CONFIGURAÇÃO REMOTA =====================

-- aplica os valores nos sistemas (só no servidor; o cliente não precisa deles)
local function apply()
	EnemyService.GlobalHpMult = values.enemyHpMult
	EnemyService.GlobalDamageMult = values.enemyDamageMult
	Arena.DamageMult = values.arenaDamage
	PlayerService.ArenaHealMult = values.arenaHeal
	Config.WorldBossInterval = values.worldBossMinutes * 60
	workspace:SetAttribute("Motd", if values.motd ~= "" then values.motd else nil)
	for _, player in Players:GetPlayers() do
		PlayerService.markDirty(player)
	end
end

-- XP, ouro e drop entram como bônus (gancho ExtraBonus, junto com pets, guilda e evento)
function AdminService.applyBonus(_player, _data, bonus)
	bonus.xpGain = (bonus.xpGain or 0) + (values.xpMult - 1)
	bonus.goldFind = (bonus.goldFind or 0) + (values.goldMult - 1)
	bonus.dropFind = (bonus.dropFind or 0) + (values.dropMult - 1)
end

local function loadConfig()
	local configStore = store("ConfigRemota_v1")
	if not configStore then
		return
	end
	local ok, saved = pcall(function()
		return configStore:GetAsync("atual")
	end)
	if ok and type(saved) == "table" then
		local fresh = RemoteConfig.defaults()
		for key, value in saved do
			local valid = RemoteConfig.validate(key, value)
			if valid ~= nil then
				fresh[key] = valid
			end
		end
		values = fresh
		apply()
	end
end

local function publish(message)
	task.spawn(function()
		pcall(function()
			MessagingService:PublishAsync(TOPIC, HttpService:JSONEncode(message))
		end)
	end)
end

-- ===================== REGISTRO =====================

local function log(admin, action, detail)
	local entry = { t = os.time(), admin = admin.DisplayName, action = action, detail = detail or "" }
	table.insert(logCache, 1, entry)
	while #logCache > 100 do
		table.remove(logCache)
	end
	task.spawn(function()
		local logStore = store("AdminLog_v1")
		if not logStore then
			return
		end
		pcall(function()
			logStore:UpdateAsync("log", function(list)
				list = if type(list) == "table" then list else {}
				table.insert(list, 1, entry)
				while #list > 100 do
					table.remove(list)
				end
				return list
			end)
		end)
	end)
end

local function loadLog()
	local logStore = store("AdminLog_v1")
	if not logStore then
		return
	end
	local ok, list = pcall(function()
		return logStore:GetAsync("log")
	end)
	if ok and type(list) == "table" then
		logCache = list
	end
end

-- ===================== BANIMENTO =====================

local function banKey(userId)
	return "u" .. tostring(userId)
end

-- chamado antes de carregar o perfil; devolve true se o jogador foi expulso
function AdminService.checkBan(player)
	local banStore = store("Banidos_v1")
	if not banStore then
		return false
	end
	local ok, ban = pcall(function()
		return banStore:GetAsync(banKey(player.UserId))
	end)
	if ok and type(ban) == "table" and (ban["until"] == 0 or ban["until"] > os.time()) then
		local untilText = if ban["until"] == 0 then "para sempre" else ("até %s (UTC)"):format(os.date("!%d/%m/%Y %H:%M", ban["until"]))
		player:Kick(("Você foi banido %s. Motivo: %s"):format(untilText, ban.reason or "—"))
		return true
	end
	return false
end

local function findPlayer(name)
	if type(name) ~= "string" or name == "" then
		return nil
	end
	local lower = string.lower(name)
	for _, player in Players:GetPlayers() do
		if string.lower(player.Name) == lower or string.lower(player.DisplayName) == lower then
			return player
		end
	end
	for _, player in Players:GetPlayers() do
		if string.find(string.lower(player.Name), lower, 1, true) or string.find(string.lower(player.DisplayName), lower, 1, true) then
			return player
		end
	end
	return nil
end

local function resolveUserId(target)
	local online = findPlayer(target)
	if online then
		return online.UserId, online.Name
	end
	local asNumber = tonumber(target)
	if asNumber then
		return asNumber, tostring(asNumber)
	end
	local ok, userId = pcall(function()
		return Players:GetUserIdFromNameAsync(target)
	end)
	if ok and userId then
		return userId, target
	end
	return nil
end

local function rootOf(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

-- ===================== MENSAGENS ENTRE SERVIDORES =====================

local function onMessage(message)
	local ok, data = pcall(function()
		return HttpService:JSONDecode(message.Data)
	end)
	if not ok or type(data) ~= "table" then
		return
	end
	if data.kind == "config" then
		loadConfig()
	elseif data.kind == "announce" and type(data.text) == "string" then
		Remotes.Notify:FireAllClients({ kind = "banner", text = "AVISO DA EQUIPE", sub = data.text, color = Color3.fromRGB(255, 200, 90), duration = 8 })
	elseif data.kind == "kick" and type(data.userId) == "number" then
		local player = Players:GetPlayerByUserId(data.userId)
		if player then
			player:Kick(data.reason or "Você foi removido por um administrador.")
		end
	end
end

-- ===================== PEDIDOS =====================

local handlers = {}

function handlers.state(_admin)
	local list = {}
	for _, player in Players:GetPlayers() do
		local data = DataService.get(player)
		table.insert(list, {
			name = player.Name,
			display = player.DisplayName,
			userId = player.UserId,
			level = if data then data.level else 0,
			class = if data then data.class or "" else "",
			gold = if data then data.gold else 0,
		})
	end
	local config = {}
	for _, field in RemoteConfig.Fields do
		config[field.key] = values[field.key]
	end
	local logs = {}
	for i = 1, math.min(40, #logCache) do
		table.insert(logs, logCache[i])
	end
	return { ok = true, players = list, config = config, log = logs, jobId = game.JobId, uptime = math.floor(workspace.DistributedGameTime) }
end

function handlers.setConfig(admin, changes)
	if type(changes) ~= "table" then
		return { ok = false, msg = "Nada para salvar." }
	end
	local fresh = table.clone(values)
	local changed = {}
	for key, value in changes do
		local valid = RemoteConfig.validate(key, value)
		if valid == nil then
			return { ok = false, msg = ("Valor inválido em %s."):format(tostring(key)) }
		end
		if valid ~= fresh[key] then
			fresh[key] = valid
			table.insert(changed, ("%s=%s"):format(key, tostring(valid)))
		end
	end
	if #changed == 0 then
		return { ok = true, msg = "Nada mudou." }
	end
	values = fresh
	apply()
	local configStore = store("ConfigRemota_v1")
	if configStore then
		pcall(function()
			configStore:SetAsync("atual", values)
		end)
	end
	publish({ kind = "config" })
	log(admin, "config", table.concat(changed, ", "))
	return { ok = true, msg = "Configuração salva em todos os servidores." }
end

function handlers.announce(admin, text)
	if type(text) ~= "string" or #text < 2 then
		return { ok = false, msg = "Escreva o aviso." }
	end
	text = string.sub(text, 1, 160)
	local ok, filtered = pcall(function()
		return TextService:FilterStringAsync(text, admin.UserId, Enum.TextFilterContext.PublicChat):GetNonChatStringForBroadcastAsync()
	end)
	if not ok then
		return { ok = false, msg = "O filtro de texto do Roblox falhou. Tente de novo." }
	end
	-- aparece aqui na hora e nos outros servidores pelo MessagingService
	onMessage({ Data = HttpService:JSONEncode({ kind = "announce", text = filtered }) })
	publish({ kind = "announce", text = filtered, from = game.JobId })
	log(admin, "aviso", filtered)
	return { ok = true }
end

function handlers.kick(admin, args)
	local target = findPlayer(type(args) == "table" and args.target)
	if not target then
		return { ok = false, msg = "Jogador não está neste servidor." }
	end
	local reason = type(args.reason) == "string" and string.sub(args.reason, 1, 120) or "Removido por um administrador."
	log(admin, "expulsar", target.Name .. ": " .. reason)
	target:Kick(reason)
	return { ok = true, msg = target.Name .. " foi expulso." }
end

function handlers.ban(admin, args)
	if type(args) ~= "table" then
		return { ok = false, msg = "Dados inválidos." }
	end
	local userId, name = resolveUserId(args.target)
	if not userId then
		return { ok = false, msg = "Jogador não encontrado." }
	end
	if userId == admin.UserId then
		return { ok = false, msg = "Você não pode se banir." }
	end
	local hours = math.clamp(tonumber(args.hours) or 0, 0, 24 * 365)
	local reason = type(args.reason) == "string" and string.sub(args.reason, 1, 120) or "Quebra das regras."
	local banStore = store("Banidos_v1")
	if not banStore then
		return { ok = false, msg = "DataStore indisponível (publique o jogo)." }
	end
	local ok = pcall(function()
		banStore:SetAsync(banKey(userId), { ["until"] = if hours > 0 then os.time() + hours * 3600 else 0, reason = reason, by = admin.UserId })
	end)
	if not ok then
		return { ok = false, msg = "Não deu para salvar o banimento. Tente de novo." }
	end
	local message = ("Você foi banido. Motivo: %s"):format(reason)
	onMessage({ Data = HttpService:JSONEncode({ kind = "kick", userId = userId, reason = message }) })
	publish({ kind = "kick", userId = userId, reason = message })
	log(admin, "banir", ("%s (%d) %s: %s"):format(name, userId, if hours > 0 then hours .. " h" else "para sempre", reason))
	return { ok = true, msg = name .. " foi banido." }
end

function handlers.unban(admin, args)
	local userId, name = resolveUserId(type(args) == "table" and args.target or args)
	if not userId then
		return { ok = false, msg = "Jogador não encontrado." }
	end
	local banStore = store("Banidos_v1")
	if not banStore then
		return { ok = false, msg = "DataStore indisponível (publique o jogo)." }
	end
	pcall(function()
		banStore:RemoveAsync(banKey(userId))
	end)
	log(admin, "desbanir", ("%s (%d)"):format(name, userId))
	return { ok = true, msg = name .. " foi desbanido." }
end

function handlers.give(admin, args)
	local target = findPlayer(type(args) == "table" and args.target)
	if not target then
		return { ok = false, msg = "Jogador não está neste servidor." }
	end
	local gold = math.clamp(math.floor(tonumber(args.gold) or 0), 0, 1000000)
	local xp = math.clamp(math.floor(tonumber(args.xp) or 0), 0, 1000000)
	if gold > 0 then
		PlayerService.addGold(target, gold)
	end
	if xp > 0 then
		PlayerService.addXP(target, xp)
	end
	Remotes.Notify:FireClient(target, { kind = "banner", text = "PRESENTE DA EQUIPE", sub = ("+%d ouro  +%d XP"):format(gold, xp), color = Color3.fromRGB(255, 200, 90), duration = 4 })
	log(admin, "dar", ("%s: %d ouro, %d XP"):format(target.Name, gold, xp))
	return { ok = true, msg = "Entregue." }
end

function handlers.visit(admin, args)
	local target = findPlayer(type(args) == "table" and args.target)
	local from, to = rootOf(admin), target and rootOf(target)
	if not from or not to then
		return { ok = false, msg = "Jogador não encontrado." }
	end
	AntiCheat.allowTeleport(admin, 3)
	admin.Character:PivotTo(to.CFrame * CFrame.new(0, 0, 5))
	log(admin, "ir", target.Name)
	return { ok = true }
end

function handlers.bring(admin, args)
	local target = findPlayer(type(args) == "table" and args.target)
	local from, to = rootOf(admin), target and rootOf(target)
	if not from or not to then
		return { ok = false, msg = "Jogador não encontrado." }
	end
	if target:GetAttribute("Arena") or target:GetAttribute("Dungeon") or target:GetAttribute("Raid") then
		return { ok = false, msg = "Ele está numa arena, masmorra ou raide." }
	end
	AntiCheat.allowTeleport(target, 3)
	target.Character:PivotTo(from.CFrame * CFrame.new(0, 0, -5))
	log(admin, "trazer", target.Name)
	return { ok = true }
end

function handlers.worldboss(admin)
	WorldEventService.forceBoss()
	log(admin, "chefe de mundo")
	return { ok = true }
end

function handlers.invasion(admin)
	WorldEventService.forceInvasion()
	log(admin, "invasão")
	return { ok = true }
end

function handlers.event(admin)
	local event = EventService.cycle()
	log(admin, "evento", if event then event.name else "calendário")
	return { ok = true, msg = if event then "Evento forçado neste servidor: " .. event.name else "Evento pelo calendário de novo." }
end

function AdminService.handle(player, sub, args)
	if not AdminService.isAdmin(player) then
		return { ok = false, msg = "Só administradores." }
	end
	local handler = type(sub) == "string" and handlers[sub]
	if not handler then
		return { ok = false, msg = "Comando inválido." }
	end
	return handler(player, args)
end

-- ===================== GANCHOS =====================

function AdminService.onPlayerReady(player)
	if AdminService.isAdmin(player) then
		player:SetAttribute("Admin", true)
	end
	local motd = values.motd
	if motd ~= "" then
		task.delay(4, function()
			if player.Parent == Players then
				Remotes.Notify:FireClient(player, { kind = "banner", text = "MENSAGEM DO DIA", sub = motd, color = Color3.fromRGB(255, 200, 90), duration = 7 })
			end
		end)
	end
end

function AdminService.start()
	local previous = PlayerService.ExtraBonus
	PlayerService.ExtraBonus = function(player, data, bonus)
		previous(player, data, bonus)
		AdminService.applyBonus(player, data, bonus)
	end
	apply()
	task.spawn(function()
		loadConfig()
		loadLog()
	end)
	pcall(function()
		MessagingService:SubscribeAsync(TOPIC, function(message)
			local ok, data = pcall(function()
				return HttpService:JSONDecode(message.Data)
			end)
			-- o próprio servidor já mostrou o aviso na hora
			if ok and type(data) == "table" and data.kind == "announce" and data.from == game.JobId then
				return
			end
			onMessage(message)
		end)
	end)
	task.spawn(function()
		while true do
			task.wait(120)
			loadConfig()
		end
	end)
end

return AdminService
