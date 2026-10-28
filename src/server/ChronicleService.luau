-- Crônicas: reputação com as facções (Factions) e páginas do diário de lore (Lore).
--   * Tudo sobe pelos eventos de missão (init.server → questHook → ChronicleService.track) e pelas missões
--     entregues (QuestService.OnComplete → onQuestDone: facção de quem deu a missão + reward.faction).
--   * Subiu de degrau: recompensa na hora (ouro, baú e, nos degraus altos, título).
--   * Perfil: data.factions[id] = reputação, data.factionTiers[id] = último degrau recompensado,
--     data.lore[pageId] = true.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Factions = require(Shared.Factions)
local Lore = require(Shared.Lore)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local PlayerService = require(script.Parent.PlayerService)
local ShopService = require(script.Parent.ShopService)

local ChronicleService = {}

local function addRep(player, data, factionId, amount)
	local faction = Factions.ById[factionId]
	if not faction or amount <= 0 then
		return
	end
	local before = data.factions[factionId] or 0
	local after = before + amount
	data.factions[factionId] = after
	local tier = Factions.tier(after)
	local rewarded = data.factionTiers[factionId] or 1
	while rewarded < tier do
		rewarded += 1
		local info = Factions.Tiers[rewarded]
		local reward = info.reward or {}
		if reward.gold then
			PlayerService.addGold(player, reward.gold)
		end
		if reward.chest then
			ShopService.grant(player, reward.chest)
		end
		local extra = ""
		if reward.title then
			local titleId = Factions.titleId(factionId, reward.title)
			data.progress.titles[titleId] = true
			extra = "  •  título novo!"
		end
		Remotes.Notify:FireClient(player, {
			kind = "banner",
			text = ("%s: %s!"):format(string.upper(faction.name), string.upper(info.name)),
			sub = ("+%d de ouro e um baú%s"):format(reward.gold or 0, extra),
			color = faction.color,
			duration = 5,
		})
	end
	data.factionTiers[factionId] = rewarded
	PlayerService.markDirty(player)
end

local function unlockPage(player, data, page)
	if data.lore[page.id] then
		return
	end
	data.lore[page.id] = true
	Remotes.Notify:FireClient(player, { kind = "banner", text = "NOVA PÁGINA NAS CRÔNICAS", sub = ("\"%s\"  •  leia nas Crônicas (tecla Y)"):format(page.title), color = Color3.fromRGB(230, 205, 150), duration = 5 })
	PlayerService.markDirty(player)
end

-- todos os eventos de missão passam por aqui
function ChronicleService.track(player, kind, target, amount)
	local data = DataService.get(player)
	if not data then
		return
	end
	local gains = Factions.Events[kind]
	if gains then
		for factionId, points in gains do
			addRep(player, data, factionId, points * (amount or 1))
		end
	end
	for _, page in Lore.Pages do
		local unlock = page.unlock
		if unlock[1] == kind and (unlock[2] == nil or unlock[2] == target) then
			unlockPage(player, data, page)
		end
	end
end

-- missão entregue: reputação para a facção de quem deu (+ a da recompensa, se tiver)
function ChronicleService.onQuestDone(player, def)
	local data = DataService.get(player)
	if not data or type(def) ~= "table" then
		return
	end
	local factionId = def.giver and Factions.QuestGivers[def.giver]
	if factionId and not def.daily then
		addRep(player, data, factionId, Factions.QuestRep)
	end
	local reward = def.reward
	if reward and reward.faction and Factions.ById[reward.faction.id] then
		addRep(player, data, reward.faction.id, reward.faction.amount or 0)
	end
end

-- resumo para a interface
function ChronicleService.summary(player)
	local data = DataService.get(player)
	if not data then
		return nil
	end
	return { factions = data.factions, lore = data.lore }
end

return ChronicleService
