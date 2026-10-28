-- XP e níveis das perícias (maestrias de arma e profissões).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Skills = require(Shared.Skills)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)

local SkillService = {}

-- Ganchos preenchidos pelo init
SkillService.OnChanged = function(_player) end
SkillService.OnLevelUp = function(_player, _skillId, _level) end

local function entry(data, skillId)
	local skill = data.skills[skillId]
	if not skill then
		skill = { level = 1, xp = 0 }
		data.skills[skillId] = skill
	end
	return skill
end

function SkillService.getLevel(player, skillId)
	local data = DataService.get(player)
	if not data then
		return 1
	end
	local skill = data.skills[skillId]
	return if skill then skill.level else 1
end

function SkillService.addXP(player, skillId, amount)
	local data = DataService.get(player)
	local def = Skills.List[skillId]
	if not data or not def or amount <= 0 then
		return
	end
	local skill = entry(data, skillId)
	if skill.level >= Config.SkillMaxLevel then
		return
	end
	skill.xp += amount
	local leveled = false
	while skill.level < Config.SkillMaxLevel and skill.xp >= Config.skillXpToNext(skill.level) do
		skill.xp -= Config.skillXpToNext(skill.level)
		skill.level += 1
		leveled = true
		local perk = nil
		if def.kind == "mastery" then
			for _, p in Skills.MasteryPerks do
				if p.level == skill.level then
					perk = p.text
				end
			end
		end
		Remotes.Notify:FireClient(player, { kind = "skillup", skill = skillId, level = skill.level, perk = perk })
		SkillService.OnLevelUp(player, skillId, skill.level)
	end
	SkillService.OnChanged(player, leveled)
end

-- Teste no Studio: todas as maestrias e profissões no nível máximo (sem um aviso por nível)
function SkillService.maxAll(player)
	local data = DataService.get(player)
	if not data then
		return
	end
	for skillId in Skills.List do
		local skill = entry(data, skillId)
		if skill.level < Config.SkillMaxLevel then
			skill.level = Config.SkillMaxLevel
			skill.xp = 0
			SkillService.OnLevelUp(player, skillId, skill.level)
		end
	end
	SkillService.OnChanged(player, true)
end

function SkillService.bestMastery(player)
	local data = DataService.get(player)
	if not data then
		return 1
	end
	local best = 1
	for _, id in Skills.MasteryOrder do
		local skill = data.skills[id]
		if skill and skill.level > best then
			best = skill.level
		end
	end
	return best
end

return SkillService
