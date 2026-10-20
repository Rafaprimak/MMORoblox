-- Missões da história e diárias.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Quests = require(Shared.Quests)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local PlayerService = require(script.Parent.PlayerService)
local ShopService = require(script.Parent.ShopService)

local QuestService = {}

local DAY = 86400
local busy = {}
local queues = {}

local function today()
	return math.floor(os.time() / DAY)
end

local function ensureDaily(data)
	local day = today()
	if data.daily.day == day then
		return
	end
	local available = {}
	for _, def in Quests.DailyPool do
		if data.level >= (def.minLevel or 1) then
			table.insert(available, def)
		end
	end
	local chosen = {}
	for _ = 1, math.min(Quests.DailyCount, #available) do
		local def = table.remove(available, math.random(1, #available))
		table.insert(chosen, { id = def.id, progress = 0, done = false })
	end
	data.daily = { day = day, quests = chosen, bonusClaimed = false }
end

local function applies(def, kind, target)
	if def.type ~= kind then
		return false
	end
	if def.target == nil or def.target == "any" then
		return true
	end
	return def.target == target
end

local function nextProgress(def, data, current, amount)
	if def.type == "level" then
		return data.level
	end
	if def.type == "rarity" then
		return data.stats.bestRarity
	end
	return current + (amount or 1)
end

local function rewardText(reward)
	local parts = {}
	if reward.xp then
		table.insert(parts, "+" .. reward.xp .. " XP")
	end
	if reward.gold then
		table.insert(parts, "+" .. reward.gold .. " Ouro")
	end
	if reward.chest then
		table.insert(parts, "Baú grátis")
	end
	return table.concat(parts, "  •  ")
end

local function grantRewards(player, reward, title, category)
	Remotes.Notify:FireClient(player, { kind = "quest", title = title, category = category, reward = rewardText(reward) })
	if reward.xp then
		PlayerService.addXP(player, reward.xp)
	end
	if reward.gold then
		PlayerService.addGold(player, reward.gold)
	end
	if reward.chest then
		local result = ShopService.grantChest(player, false)
		if result.ok then
			task.delay(1.2, function()
				Remotes.Notify:FireClient(player, { kind = "chest", item = result.item })
			end)
		end
	end
end

local function process(player, kind, target, amount)
	local data = DataService.get(player)
	if not data then
		return
	end
	ensureDaily(data)
	local queue = queues[player]

	-- História (uma missão por vez, em sequência)
	local story = Quests.Story[data.story.index]
	if story and applies(story, kind, target) then
		data.story.progress = nextProgress(story, data, data.story.progress, amount)
		if data.story.progress >= story.amount then
			-- avança antes de dar a recompensa (a recompensa pode gerar novos eventos)
			data.story.index += 1
			data.story.progress = 0
			grantRewards(player, story.reward, story.text, "story")
			local nextStory = Quests.Story[data.story.index]
			if nextStory and (nextStory.type == "level" or nextStory.type == "rarity") then
				table.insert(queue, { nextStory.type, nil, 0 })
			end
		end
	end

	-- Diárias
	for _, entry in data.daily.quests do
		local def = Quests.DailyById[entry.id]
		if def and not entry.done and applies(def, kind, target) then
			entry.progress = nextProgress(def, data, entry.progress, amount)
			if entry.progress >= def.amount then
				entry.done = true
				grantRewards(player, def.reward, def.text, "daily")
			end
		end
	end

	-- Bônus por completar todas as diárias
	if not data.daily.bonusClaimed and #data.daily.quests > 0 then
		local allDone = true
		for _, entry in data.daily.quests do
			if not entry.done then
				allDone = false
				break
			end
		end
		if allDone then
			data.daily.bonusClaimed = true
			grantRewards(player, Quests.DailyBonus, "Todas as diárias concluídas!", "bonus")
		end
	end

	PlayerService.markDirty(player)
end

-- Registra um evento (matar, abrir baú, subir de nível...). Seguro contra chamadas aninhadas.
function QuestService.track(player, kind, target, amount)
	queues[player] = queues[player] or {}
	table.insert(queues[player], { kind, target, amount })
	if busy[player] then
		return
	end
	busy[player] = true
	while queues[player] and #queues[player] > 0 do
		local event = table.remove(queues[player], 1)
		local ok, err = pcall(process, player, event[1], event[2], event[3])
		if not ok then
			warn("[QuestService] " .. tostring(err))
		end
	end
	busy[player] = nil
end

function QuestService.summary(player)
	local data = DataService.get(player)
	if not data then
		return nil
	end
	ensureDaily(data)

	local function view(def, progress, done)
		local amount = def.amount
		if def.type == "rarity" then
			progress = if data.stats.bestRarity >= def.amount then 1 else 0
			amount = 1
		end
		return {
			text = def.text,
			progress = math.min(progress, amount),
			amount = amount,
			done = done or false,
			reward = rewardText(def.reward),
		}
	end

	local story = Quests.Story[data.story.index]
	local result = {
		story = if story then view(story, if story.type == "level" then data.level else data.story.progress) else nil,
		daily = {},
		dailyResetIn = DAY - (os.time() % DAY),
		dailyBonus = rewardText(Quests.DailyBonus),
		dailyBonusClaimed = data.daily.bonusClaimed,
	}
	for _, entry in data.daily.quests do
		local def = Quests.DailyById[entry.id]
		if def then
			table.insert(result.daily, view(def, entry.progress, entry.done))
		end
	end
	return result
end

function QuestService.setup(player)
	local data = DataService.get(player)
	if not data then
		return
	end
	ensureDaily(data)
	QuestService.track(player, "level", nil, 0)
	QuestService.track(player, "rarity", nil, 0)
end

function QuestService.release(player)
	busy[player] = nil
	queues[player] = nil
end

return QuestService
