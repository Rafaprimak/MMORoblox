-- Missões: aceitar com o NPC, acompanhar objetivos variados, entregar e receber recompensas.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local World = require(Shared.World)
local Quests = require(Shared.Quests)
local NPCs = require(Shared.NPCs)
local Items = require(Shared.Items)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local PlayerService = require(script.Parent.PlayerService)
local SkillService = require(script.Parent.SkillService)
local ShopService = require(script.Parent.ShopService)

local QuestService = {}

local DAY = 86400

local function today()
	return math.floor(os.time() / DAY)
end

local function nearNpc(player, npcId, distance)
	local npc = NPCs.ById[npcId]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not npc or not root then
		return false
	end
	local dx, dz = root.Position.X - npc.x, root.Position.Z - npc.z
	return dx * dx + dz * dz <= (distance or 45) ^ 2
end

local function ensureDaily(data)
	local day = today()
	if data.daily.day == day then
		return
	end
	local available = {}
	for _, def in Quests.DailyPool do
		if data.level >= (def.minLevel or 1) then
			table.insert(available, def.id)
		end
	end
	local offered = {}
	for _ = 1, math.min(Config.DailyCount, #available) do
		table.insert(offered, table.remove(available, math.random(1, #available)))
	end
	-- remove contratos ativos de dias anteriores
	for qid, entry in data.quests.active do
		if entry.daily then
			data.quests.active[qid] = nil
		end
	end
	data.daily = { day = day, offered = offered, done = {}, bonusClaimed = false }
end

-- Progresso atual de um objetivo (alguns são calculados na hora)
local function progressOf(player, data, objective, stored)
	local kind = objective.type
	if kind == "deliver" then
		return math.min(data.materials[objective.item] or 0, objective.amount)
	elseif kind == "level" then
		return math.min(data.level, objective.amount)
	elseif kind == "mastery" then
		return math.min(SkillService.bestMastery(player), objective.amount)
	elseif kind == "discover" then
		return if data.discovered[objective.target] then objective.amount else stored or 0
	elseif kind == "poi" and objective.target then
		-- local já descoberto antes de aceitar a missão também conta
		return if data.poi[objective.target] then objective.amount else stored or 0
	elseif kind == "poiSecret" and objective.target then
		return if data.poiSecrets[objective.target] then objective.amount else stored or 0
	end
	return math.min(stored or 0, objective.amount)
end

local function isComplete(player, data, def, entry)
	for i, objective in def.objectives do
		if progressOf(player, data, objective, entry.p[i]) < objective.amount then
			return false
		end
	end
	return true
end

local function canAccept(data, def)
	if def.daily then
		return table.find(data.daily.offered, def.id) ~= nil and not data.daily.done[def.id] and not data.quests.active[def.id]
	end
	if data.quests.done[def.id] or data.quests.active[def.id] then
		return false
	end
	if def.requires.level and data.level < def.requires.level then
		return false
	end
	for _, required in def.requires.quests or {} do
		if not data.quests.done[required] then
			return false
		end
	end
	return true
end

local function matches(objective, kind, target)
	if objective.type ~= kind then
		return false
	end
	if kind == "kill" or kind == "hit" then
		return objective.target == "any" or objective.target == target
	elseif kind == "gather" then
		return objective.item == target
	elseif kind == "craft" then
		return objective.item == target
	elseif kind == "talk" then
		return objective.npc == target
	elseif kind == "explore" then
		return objective.location == target
	elseif kind == "discover" then
		return objective.target == target
	elseif kind == "poi" or kind == "poiSecret" or kind == "poiChest" then
		return objective.target == nil or objective.target == target
	end
	return true
end

-- Missão concluída (ProgressionService conta para conquistas e passe)
QuestService.OnComplete = function(_player, _daily) end

local function grantReward(player, reward, title, category, def)
	QuestService.OnComplete(player, category == "daily", def)
	Remotes.Notify:FireClient(player, { kind = "quest", title = title, category = category, reward = Quests.rewardText(reward) })
	if reward.xp then
		PlayerService.addXP(player, reward.xp)
	end
	if reward.gold then
		PlayerService.addGold(player, reward.gold)
	end
	for id, count in reward.consumables or {} do
		PlayerService.addConsumable(player, id, count)
	end
	for id, count in reward.materials or {} do
		PlayerService.addMaterial(player, id, count)
	end
	if reward.chest then
		ShopService.grant(player, reward.chest)
	end
end

local function complete(player, data, def)
	data.quests.active[def.id] = nil
	if def.daily then
		data.daily.done[def.id] = true
	else
		data.quests.done[def.id] = true
	end
	if data.quests.tracked == def.id then
		data.quests.tracked = next(data.quests.active)
	end
	grantReward(player, def.reward, def.name, if def.daily then "daily" else def.chain or "side", def)
	-- bônus das diárias
	if def.daily and not data.daily.bonusClaimed then
		local allDone = #data.daily.offered > 0
		for _, qid in data.daily.offered do
			if not data.daily.done[qid] then
				allDone = false
			end
		end
		if allDone then
			data.daily.bonusClaimed = true
			grantReward(player, Quests.DailyBonus, "Todos os contratos do dia!", "bonus")
		end
	end
	PlayerService.markDirty(player)
end

-- Avisa quando uma missão fica pronta para entregar (ou completa sozinha se não tiver NPC de entrega)
local function checkReady(player, data, qid)
	local def = Quests.ById[qid]
	local entry = data.quests.active[qid]
	if not def or not entry then
		return
	end
	local ready = isComplete(player, data, def, entry)
	if ready and not entry.ready then
		entry.ready = true
		if def.turnIn then
			local npc = NPCs.ById[def.turnIn]
			Remotes.Notify:FireClient(player, { kind = "questReady", title = def.name, npc = if npc then npc.name else "" })
		else
			complete(player, data, def)
		end
	elseif not ready then
		entry.ready = false
	end
end

function QuestService.event(player, kind, target, amount)
	local data = DataService.get(player)
	if not data then
		return
	end
	amount = amount or 1
	local changed = false
	for qid, entry in data.quests.active do
		local def = Quests.ById[qid]
		if def then
			for i, objective in def.objectives do
				if matches(objective, kind, target) then
					local before = entry.p[i] or 0
					if kind == "upgradeTo" then
						entry.p[i] = math.max(before, amount)
					elseif kind == "talk" or kind == "explore" or kind == "discover" then
						entry.p[i] = objective.amount
					else
						entry.p[i] = before + amount
					end
					if entry.p[i] ~= before then
						changed = true
					end
				end
			end
		end
	end
	-- recalcula objetivos derivados (entregas, nível, maestria) e conclusões
	for qid in data.quests.active do
		checkReady(player, data, qid)
	end
	if changed or kind == "gather" or kind == "level" then
		PlayerService.markDirty(player)
	end
end

function QuestService.accept(player, qid)
	local data = DataService.get(player)
	local def = typeof(qid) == "string" and Quests.ById[qid]
	if not data or not def then
		return { ok = false, msg = "Missão inválida." }
	end
	ensureDaily(data)
	if not canAccept(data, def) then
		return { ok = false, msg = "Você não pode aceitar esta missão agora." }
	end
	if not nearNpc(player, def.giver) then
		return { ok = false, msg = "Fale com quem oferece a missão." }
	end
	local count = 0
	for _ in data.quests.active do
		count += 1
	end
	if count >= Config.MaxActiveQuests then
		return { ok = false, msg = "Você já tem missões demais ativas." }
	end
	local progress = {}
	for i in def.objectives do
		progress[i] = 0
	end
	data.quests.active[qid] = { p = progress, daily = def.daily == true }
	if not data.quests.tracked then
		data.quests.tracked = qid
	end
	if def.grantsMount and not data.mount then
		data.mount = true
		Remotes.Notify:FireClient(player, { kind = "banner", text = "Montaria liberada!", sub = "Aperte H para montar e desmontar", color = Color3.fromRGB(230, 190, 120) })
	end
	Remotes.Notify:FireClient(player, { kind = "questAccepted", title = def.name })
	checkReady(player, data, qid)
	PlayerService.markDirty(player)
	return { ok = true }
end

function QuestService.turnIn(player, qid)
	local data = DataService.get(player)
	local def = typeof(qid) == "string" and Quests.ById[qid]
	local entry = def and data and data.quests.active[qid]
	if not entry then
		return { ok = false, msg = "Missão não está ativa." }
	end
	if not isComplete(player, data, def, entry) then
		return { ok = false, msg = "Ainda faltam objetivos." }
	end
	if def.turnIn and not nearNpc(player, def.turnIn) then
		return { ok = false, msg = "Entregue a missão para " .. NPCs.ById[def.turnIn].name .. "." }
	end
	-- consome os itens de entrega
	local cost = { materials = {} }
	for _, objective in def.objectives do
		if objective.type == "deliver" then
			cost.materials[objective.item] = (cost.materials[objective.item] or 0) + objective.amount
		end
	end
	local ok, msg = PlayerService.payCost(player, cost)
	if not ok then
		return { ok = false, msg = msg }
	end
	complete(player, data, def)
	return { ok = true }
end

function QuestService.abandon(player, qid)
	local data = DataService.get(player)
	if data and typeof(qid) == "string" and data.quests.active[qid] then
		data.quests.active[qid] = nil
		if data.quests.tracked == qid then
			data.quests.tracked = next(data.quests.active)
		end
		PlayerService.markDirty(player)
		return { ok = true }
	end
	return { ok = false }
end

function QuestService.track(player, qid)
	local data = DataService.get(player)
	if data and typeof(qid) == "string" and data.quests.active[qid] then
		data.quests.tracked = qid
		PlayerService.markDirty(player)
		return { ok = true }
	end
	return { ok = false }
end

function QuestService.summary(player)
	local data = DataService.get(player)
	if not data then
		return nil
	end
	ensureDaily(data)
	local active = {}
	for qid, entry in data.quests.active do
		local def = Quests.ById[qid]
		if def then
			local objectives = {}
			for i, objective in def.objectives do
				objectives[i] = { progress = progressOf(player, data, objective, entry.p[i]), amount = objective.amount }
			end
			table.insert(active, { id = qid, objectives = objectives, ready = isComplete(player, data, def, entry) })
		end
	end
	local available = {}
	for _, def in Quests.List do
		if canAccept(data, def) then
			available[def.giver] = available[def.giver] or {}
			table.insert(available[def.giver], def.id)
		end
	end
	for _, qid in data.daily.offered do
		local def = Quests.ById[qid]
		if def and canAccept(data, def) then
			available.quadro = available.quadro or {}
			table.insert(available.quadro, qid)
		end
	end
	return {
		active = active,
		tracked = data.quests.tracked,
		available = available,
		done = data.quests.done,
		daily = { offered = data.daily.offered, done = data.daily.done, bonusClaimed = data.daily.bonusClaimed, resetIn = DAY - (os.time() % DAY) },
	}
end

function QuestService.setup(player)
	local data = DataService.get(player)
	if data then
		ensureDaily(data)
		QuestService.event(player, "level", nil, 0)
	end
end

-- Exploração: verifica a posição dos jogadores a cada segundo
task.spawn(function()
	while true do
		task.wait(1)
		for _, player in Players:GetPlayers() do
			local data = DataService.get(player)
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if data and root then
				for qid in data.quests.active do
					local def = Quests.ById[qid]
					for _, objective in (def and def.objectives or {}) do
						if objective.type == "explore" then
							local loc = World.Locations[objective.location]
							if loc then
								local dx, dz = root.Position.X - loc.x, root.Position.Z - loc.z
								if dx * dx + dz * dz <= loc.radius * loc.radius then
									QuestService.event(player, "explore", objective.location, 1)
								end
							end
						end
					end
				end
			end
		end
	end
end)

-- nomes de itens para mensagens
QuestService.itemName = function(id)
	local def = Items.Materials[id] or Items.Consumables[id]
	return if def then def.name else id
end

return QuestService
