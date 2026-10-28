-- Carrega e salva o progresso dos jogadores (DataStore), à prova de duplicação:
--   * TRAVA DE SESSÃO: o registro guarda qual servidor está com o perfil aberto (lock = { jobId, time }).
--     Outro servidor só abre o perfil depois que o primeiro solta (ao sair) ou se a trava ficar velha
--     (servidor que caiu sem soltar). Assim não dá para duplicar itens trocando de servidor rápido.
--   * Toda gravação usa UpdateAsync e NUNCA escreve num perfil travado por outro servidor.
--   * Novas tentativas com espera crescente quando o Roblox falha.
--   * Cópia de segurança (DataStoreName .. "_backup") a cada saída do jogo.
--   * Saves antigos (dados "soltos", sem trava) são lidos normalmente e migrados.
-- No Studio sem acesso às APIs o DataStore não funciona: o progresso fica só na memória.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local DataService = {}

local RECORD_FORMAT = 3
local LOCK_STALE = 5 * 60 -- trava sem renovar há 5 min = servidor caiu; pode tomar
local LOAD_ATTEMPTS = 8 -- tentativas de abrir um perfil travado (uma a cada ~4 s)
local RETRIES = 3 -- novas tentativas quando a API do Roblox falha

local store, backupStore = nil, nil
local okStore, storeError = pcall(function()
	store = DataStoreService:GetDataStore(Config.DataStoreName)
	backupStore = DataStoreService:GetDataStore(Config.DataStoreName .. "_backup")
end)
if not okStore then
	warn("[DataService] DataStore indisponível (jogo não publicado?). O progresso NÃO será salvo.", storeError)
	store, backupStore = nil, nil
end

local profiles = {}
local blockedSaves = {} -- perfil não foi aberto direito: nunca escrever por cima dos dados reais
local releasing = {} -- [player] = true enquanto a última gravação está acontecendo
local releasingUsers = {} -- [UserId] = true: quem voltou para ESTE servidor espera a saída terminar de gravar

function DataService.defaultData()
	return {
		version = 2,
		level = 1,
		xp = 0,
		gold = Config.StarterGold,
		class = nil,
		skillPoints = 0,
		abilityRanks = {},
		talents = {},
		loadout = {},
		pets = {},
		poi = {},
		poiChests = {},
		poiSecrets = {}, -- [localId] = true: segredo do local já encontrado
		dungeons = {}, -- [masmorraId] = maior andar limpo (recorde)
		purchases = {}, -- [PurchaseId] = true (compras com Robux já entregues; evita entregar duas vezes)
		tradeLog = {}, -- últimas 20 trocas com outros jogadores
		market = { selling = {}, buying = {} }, -- mercado: custódia dos anúncios e das compras em andamento
		progress = {
			counters = {},
			achievements = {},
			titles = {},
			levelRewards = {},
			pass = { xp = 0, tier = 0, claimed = 0 },
			login = { day = 0, streak = 0 },
			title = "",
		},
		inventory = {},
		equipped = {},
		materials = {},
		consumables = {},
		skills = {},
		quests = { active = {}, done = {}, tracked = nil },
		daily = { day = 0, offered = {}, done = {}, bonusClaimed = false },
		discovered = {},
		mount = false,
		stats = { kills = 0, chests = 0, bestRarity = 1, crafted = 0 },
		settings = table.clone(Config.DefaultSettings),
		tutorial = { done = {}, skipped = false },
	}
end

-- Campos que são dicionários livres (não devem ser "completados" com o modelo)
local FREE_KEYS = {
	inventory = true, equipped = true, materials = true, consumables = true, skills = true,
	abilityRanks = true, talents = true, loadout = true, pets = true, poi = true, poiChests = true, poiSecrets = true, counters = true, achievements = true, titles = true, levelRewards = true, active = true, done = true, offered = true, discovered = true,
	dungeons = true, purchases = true, tradeLog = true, selling = true, buying = true,
}

local function reconcile(data, template)
	for key, value in template do
		if data[key] == nil then
			data[key] = value
		elseif type(value) == "table" and type(data[key]) == "table" and not FREE_KEYS[key] then
			reconcile(data[key], value)
		end
	end
end

local function key(player)
	return "player_" .. player.UserId
end

-- registro guardado: { format = 3, data = {...}, lock = { jobId, time } | nil, savedAt }
-- (saves antigos eram os dados direto, sem envelope)
local function normalize(stored)
	if type(stored) ~= "table" then
		return { format = RECORD_FORMAT }
	end
	if stored.format == RECORD_FORMAT then
		return stored
	end
	return { format = RECORD_FORMAT, data = stored }
end

local function lockedByOther(record)
	local lock = record.lock
	return lock ~= nil and lock.jobId ~= game.JobId and os.time() - (lock.time or 0) < LOCK_STALE
end

-- chama a API com novas tentativas (1 s, 2 s, 4 s)
local function withRetries(label, fn)
	local lastError
	for attempt = 1, RETRIES do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastError = result
		warn(("[DataService] %s falhou (tentativa %d/%d): %s"):format(label, attempt, RETRIES, tostring(result)))
		task.wait(2 ^ (attempt - 1))
	end
	return false, lastError
end

-- Abre o perfil travando a sessão. Retorna os dados (ou nil se o jogador teve que sair).
function DataService.load(player)
	local data = nil
	local waited = os.clock()
	while releasingUsers[player.UserId] and os.clock() - waited < 15 do
		task.wait(0.25)
	end
	if store then
		local opened = false
		for attempt = 1, LOAD_ATTEMPTS do
			local busy = false
			local ok, record = withRetries("Carregar " .. player.Name, function()
				return store:UpdateAsync(key(player), function(stored)
					local record = normalize(stored)
					busy = lockedByOther(record) -- (o Roblox pode chamar esta função mais de uma vez)
					if busy then
						return nil -- não mexe: outro servidor ainda está com o perfil
					end
					record.lock = { jobId = game.JobId, time = os.time() }
					return record
				end)
			end)
			if not ok then
				break
			end
			if not busy then
				data = record and record.data
				opened = true
				break
			end
			if player.Parent ~= Players then
				return nil
			end
			-- o outro servidor está salvando a saída; espera um pouco
			task.wait(4)
		end
		if not opened then
			if RunService:IsStudio() then
				warn("[DataService] Não foi possível abrir o perfil no Studio; jogando sem salvar.")
				blockedSaves[player] = true
			else
				player:Kick("Seu progresso ainda está sendo salvo em outro servidor. Entre de novo em alguns segundos.")
				return nil
			end
		end
	end
	if type(data) ~= "table" or data.version ~= 2 then
		data = DataService.defaultData()
	end
	reconcile(data, DataService.defaultData())
	profiles[player] = data
	return data
end

function DataService.get(player)
	return profiles[player]
end

-- Grava (e renova a trava). release = true solta o perfil para outros servidores.
local function write(player, data, release)
	if not store then
		return true -- save desligado (Studio sem publicar): nada a perder
	end
	if blockedSaves[player] then
		return false -- perfil não abriu direito ou foi tomado: não grava (e quem depende disso, como o mercado, desiste)
	end
	local stolen = false
	local ok = withRetries("Salvar " .. player.Name, function()
		store:UpdateAsync(key(player), function(stored)
			local record = normalize(stored)
			if lockedByOther(record) then
				stolen = true
				return nil -- outro servidor tomou o perfil (este servidor travou/caiu): não sobrescreve
			end
			record.data = data
			record.savedAt = os.time()
			record.lock = if release then nil else { jobId = game.JobId, time = os.time() }
			return record
		end)
	end)
	if stolen then
		warn(("[DataService] O perfil de %s está aberto em outro servidor; este não grava mais."):format(player.Name))
		blockedSaves[player] = true
		if player.Parent == Players then
			player:Kick("Seu perfil foi aberto em outro servidor.")
		end
		return false
	end
	return ok
end

-- grava agora; retorna true se gravou (ou se o save está desligado, como no Studio sem publicar)
function DataService.save(player)
	local data = profiles[player]
	if not data or releasing[player] then
		return false
	end
	return write(player, data, false) == true
end

-- Saída do jogador: grava, solta a trava e faz a cópia de segurança
function DataService.release(player)
	local data = profiles[player]
	if not data or releasing[player] then
		return -- (a saída e o fechamento do servidor podem chamar ao mesmo tempo)
	end
	releasing[player] = true
	releasingUsers[player.UserId] = true
	local saved = write(player, data, true)
	if saved and backupStore and not blockedSaves[player] then
		pcall(function()
			backupStore:SetAsync(key(player), { data = data, savedAt = os.time() })
		end)
	end
	profiles[player] = nil
	blockedSaves[player] = nil
	releasing[player] = nil
	releasingUsers[player.UserId] = nil
end

function DataService.saveAll()
	for player in profiles do
		task.spawn(DataService.save, player)
	end
end

-- servidor fechando: solta todos os perfis e espera terminar (o Roblox dá ~30 s)
function DataService.releaseAll()
	local pending = 0
	for player in profiles do
		pending += 1
		task.spawn(function()
			DataService.release(player)
			pending -= 1
		end)
	end
	local start = os.clock()
	while pending > 0 and os.clock() - start < 25 do
		task.wait(0.2)
	end
end

return DataService
