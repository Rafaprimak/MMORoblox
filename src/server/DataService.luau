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
local blockedSaves = {} -- carregamento falhou: não sobrescrever os dados reais

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
	abilityRanks = true, talents = true, loadout = true, pets = true, counters = true, achievements = true, titles = true, levelRewards = true, active = true, done = true, offered = true, discovered = true,
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
