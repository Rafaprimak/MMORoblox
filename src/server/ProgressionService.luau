-- Progressão viciante: login diário em sequência, Passe do Hunter, conquistas com títulos e marcos de nível.
-- Tudo é contado a partir dos ganchos de missão (QuestHook), que o init também repassa para cá.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Progression = require(Shared.Progression)
local Items = require(Shared.Items)
local Pets = require(Shared.Pets)
local Chests = require(Shared.Chests)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local PlayerService = require(script.Parent.PlayerService)
local ShopService = require(script.Parent.ShopService)
local PetService = require(script.Parent.PetService)

local ProgressionService = {}

local function today()
	return math.floor(os.time() / 86400)
end

local function progress(player)
	local data = DataService.get(player)
	return data and data.progress, data
end

local function setTitleAttribute(player, data)
	local title = Progression.Titles[data.progress.title or ""]
	player:SetAttribute("Title", if title then title.name else nil)
	player:SetAttribute("TitleId", if title then data.progress.title else nil)
end

-- ===================== RECOMPENSAS =====================

function ProgressionService.grant(player, reward, label)
	local p, data = progress(player)
	if not p or not reward then
		return
	end
	if reward.gold then
		PlayerService.addGold(player, reward.gold)
	end
	for id, count in reward.materials or {} do
		PlayerService.addMaterial(player, id, count, true)
	end
	for id, count in reward.consumables or {} do
		PlayerService.addConsumable(player, id, count, true)
	end
	if reward.egg and Pets.Eggs[reward.egg] then
		PetService.give(player, Pets.rollEgg(reward.egg), reward.egg)
	end
	if reward.chest then
		ShopService.grant(player, reward.chest)
	end
	if reward.title and Progression.Titles[reward.title] and not p.titles[reward.title] then
		p.titles[reward.title] = true
		Remotes.Notify:FireClient(player, { kind = "banner", text = "🏷 Título novo: " .. Progression.Titles[reward.title].name, sub = "Equipe na Jornada (tecla K)", color = Progression.Titles[reward.title].color, duration = 4 })
	end
	if reward.passXp then
		ProgressionService.addPassXp(player, reward.passXp)
	end
	if label then
		Remotes.Notify:FireClient(player, { kind = "reward", title = label, text = Progression.rewardText(reward, Items, Pets, Chests) })
	end
	PlayerService.markDirty(player)
	local _ = data
end

-- ===================== PASSE =====================

function ProgressionService.addPassXp(player, amount)
	local p = progress(player)
	if not p or amount <= 0 then
		return
	end
	local pass = p.pass
	pass.xp += amount
	while pass.tier < Progression.PassMaxTier and pass.xp >= Progression.passXpFor(pass.tier + 1) do
		pass.xp -= Progression.passXpFor(pass.tier + 1)
		pass.tier += 1
		Remotes.Notify:FireClient(player, { kind = "passTier", tier = pass.tier })
	end
	-- passe completo: cada 2.000 de XP extra vira ouro
	if pass.tier >= Progression.PassMaxTier and pass.xp >= 2000 then
		local bonus = math.floor(pass.xp / 2000)
		pass.xp -= bonus * 2000
		PlayerService.addGold(player, bonus * 500)
	end
	PlayerService.markDirty(player)
end

function ProgressionService.claimPass(player)
	local p = progress(player)
	if not p then
		return { ok = false, msg = "Dados indisponíveis." }
	end
	local pass = p.pass
	if pass.claimed >= pass.tier then
		return { ok = false, msg = "Nada para resgatar. Continue jogando para subir de tier!" }
	end
	local total = {}
	while pass.claimed < pass.tier do
		pass.claimed += 1
		local reward = Progression.passReward(pass.claimed)
		ProgressionService.grant(player, reward)
		table.insert(total, pass.claimed)
	end
	Remotes.Notify:FireClient(player, { kind = "reward", title = ("Passe do Hunter: %d recompensa(s)!"):format(#total), text = "Tiers " .. table.concat(total, ", ") })
	return { ok = true, count = #total }
end

-- ===================== LOGIN DIÁRIO =====================

local function loginState(p)
	local login = p.login
	local day = today()
	if login.day == day then
		return false, login.streak
	end
	-- perdeu um dia: recomeça
	local streak = if login.day == day - 1 then login.streak else 0
	return true, streak
end

function ProgressionService.claimLogin(player)
	local p = progress(player)
	if not p then
		return { ok = false, msg = "Dados indisponíveis." }
	end
	local canClaim, streak = loginState(p)
	if not canClaim then
		return { ok = false, msg = "Você já resgatou hoje. Volte amanhã!" }
	end
	local nextDay = (streak % #Progression.Login) + 1
	p.login.day = today()
	p.login.streak = nextDay
	ProgressionService.grant(player, Progression.Login[nextDay], ("Recompensa diária: dia %d!"):format(nextDay))
	return { ok = true, day = nextDay }
end

-- ===================== CONQUISTAS =====================

local function bumpAchievements(player, p, kind, target, amount)
	for _, achievement in Progression.Achievements do
		if achievement.event == kind and (achievement.target == nil or achievement.target == target) then
			local current = p.counters[achievement.id] or 0
			local value
			if achievement.mode == "max" then
				value = math.max(current, amount or 0)
			else
				value = current + (amount or 1)
			end
			p.counters[achievement.id] = value
			-- tiers alcançados agora
			local tier = p.achievements[achievement.id] or 0
			while tier < #achievement.tiers and value >= achievement.tiers[tier + 1] do
				tier += 1
				p.achievements[achievement.id] = tier
				local reward = table.clone(Progression.AchievementRewards[tier])
				if tier == #achievement.tiers then
					reward.title = achievement.title
				end
				Remotes.Notify:FireClient(player, { kind = "achievement", id = achievement.id, tier = tier })
				ProgressionService.grant(player, reward)
			end
		end
	end
end

-- Recebe todos os eventos de missão (kill, parry, gather, craft...)
function ProgressionService.track(player, kind, target, amount)
	local p = progress(player)
	if not p or type(kind) ~= "string" then
		return
	end
	amount = if type(amount) == "number" then amount else 1
	if kind == "level" then
		local _, data = progress(player)
		amount = data.level
	end
	bumpAchievements(player, p, kind, target, amount)
	local passXp = Progression.PassXp[kind]
	if passXp and kind ~= "kill" then
		ProgressionService.addPassXp(player, passXp * (if kind == "level" then 1 else math.max(amount, 1)))
	end
	if kind == "level" then
		ProgressionService.onLevel(player, amount)
	end
end

function ProgressionService.onKill(player, rec)
	local key = if rec.def.boss then "killBoss" elseif rec.elite then "killElite" else "kill"
	ProgressionService.addPassXp(player, Progression.PassXp[key] + math.floor(rec.level / 3))
end

function ProgressionService.onQuestDone(player, daily)
	local p = progress(player)
	if not p then
		return
	end
	bumpAchievements(player, p, "questDone", nil, 1)
	ProgressionService.addPassXp(player, if daily then Progression.PassXp.daily else Progression.PassXp.quest)
end

-- marcos de nível (entregues na hora)
function ProgressionService.onLevel(player, level)
	local p = progress(player)
	if not p or type(level) ~= "number" then
		return
	end
	for milestone, reward in Progression.LevelRewards do
		if level >= milestone and not p.levelRewards[tostring(milestone)] then
			p.levelRewards[tostring(milestone)] = true
			ProgressionService.grant(player, reward, ("Marco do nível %d!"):format(milestone))
		end
	end
end

-- ===================== TÍTULOS =====================

function ProgressionService.setTitle(player, titleId)
	local p, data = progress(player)
	if not p then
		return { ok = false }
	end
	if titleId ~= "" and not (type(titleId) == "string" and p.titles[titleId]) then
		return { ok = false, msg = "Você ainda não tem esse título." }
	end
	p.title = titleId
	setTitleAttribute(player, data)
	PlayerService.markDirty(player)
	return { ok = true }
end

-- ===================== SINCRONIZAÇÃO =====================

function ProgressionService.summary(player)
	local p, data = progress(player)
	if not p then
		return nil
	end
	local canLogin, streak = loginState(p)
	local achievements = {}
	for _, achievement in Progression.Achievements do
		table.insert(achievements, { id = achievement.id, value = p.counters[achievement.id] or 0, tier = p.achievements[achievement.id] or 0 })
	end
	local titles = { "novato" }
	for id in p.titles do
		table.insert(titles, id)
	end
	return {
		login = { canClaim = canLogin, streak = streak, nextDay = (streak % #Progression.Login) + 1 },
		pass = { tier = p.pass.tier, xp = p.pass.xp, need = if p.pass.tier >= Progression.PassMaxTier then 2000 else Progression.passXpFor(p.pass.tier + 1), claimed = p.pass.claimed },
		achievements = achievements,
		titles = titles,
		title = p.title or "",
		level = data.level,
	}
end

function ProgressionService.onPlayerReady(player)
	local p, data = progress(player)
	if not p then
		return
	end
	p.titles.novato = true
	setTitleAttribute(player, data)
	-- jogadores antigos: entrega os marcos de nível que já passaram
	task.delay(6, function()
		if player.Parent == Players then
			ProgressionService.onLevel(player, data.level)
		end
	end)
end

return ProgressionService
