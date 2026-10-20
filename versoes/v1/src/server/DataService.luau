-- Carrega e salva o progresso dos jogadores (DataStore).
-- No Studio sem publicar o jogo, o DataStore não funciona: o progresso fica só na memória.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local DataService = {}

local store = nil
local okStore, storeError = pcall(function()
	store = DataStoreService:GetDataStore(Config.DataStoreName)
end)
if not okStore then
	warn("[DataService] DataStore indisponível (jogo não publicado?). O progresso NÃO será salvo.", storeError)
	store = nil
end

local profiles = {}
local blockedSaves = {} -- jogadores cujo carregamento falhou: não sobrescrever os dados reais

local function defaultData()
	return {
		version = 1,
		level = 1,
		xp = 0,
		gold = Config.StarterGold,
		inventory = {},
		equipped = {},
		story = { index = 1, progress = 0 },
		daily = { day = 0, quests = {}, bonusClaimed = false },
		stats = { kills = 0, chests = 0, bestRarity = 1 },
	}
end

-- Preenche campos que faltam (útil quando você adiciona coisas novas aos dados)
local function reconcile(data, template)
	for key, value in template do
		if data[key] == nil then
			data[key] = value
		elseif type(value) == "table" and type(data[key]) == "table" and key ~= "inventory" and key ~= "equipped" and key ~= "quests" then
			reconcile(data[key], value)
		end
	end
end

local function key(player)
	return "player_" .. player.UserId
end

function DataService.load(player)
	local data = nil
	if store then
		local success, result = pcall(function()
			return store:GetAsync(key(player))
		end)
		if success then
			data = result
		else
			warn("[DataService] Falha ao carregar dados de " .. player.Name .. ": " .. tostring(result))
			blockedSaves[player] = true
		end
	end
	if type(data) ~= "table" then
		data = defaultData()
	end
	reconcile(data, defaultData())
	profiles[player] = data
	return data
end

function DataService.get(player)
	return profiles[player]
end

function DataService.save(player)
	local data = profiles[player]
	if not data or not store or blockedSaves[player] then
		return
	end
	local success, err = pcall(function()
		store:SetAsync(key(player), data)
	end)
	if not success then
		warn("[DataService] Falha ao salvar dados de " .. player.Name .. ": " .. tostring(err))
	end
end

function DataService.release(player)
	DataService.save(player)
	profiles[player] = nil
	blockedSaves[player] = nil
end

function DataService.saveAll()
	for player in profiles do
		task.spawn(DataService.save, player)
	end
end

return DataService
