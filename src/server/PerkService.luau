-- Gatilhos dos perks dos equipamentos (ver o módulo Perks). Os perks de stats fixos são somados em
-- PlayerService.getStats; aqui ficam os que dependem do que acontece na luta.
-- Quem chama: CombatService.dealDamage (modify/afterHit), init (onKill, onParry, onPerfectDodge)
-- e CombatService.heavyRelease (onFullCharge). Danos extras dos perks vão direto no EnemyService
-- (com info.perk = true) para não dispararem perks de novo.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local PlayerService = require(script.Parent.PlayerService)
local EnemyService = require(script.Parent.EnemyService)

local PerkService = {}

local states = {}

local function getState(player)
	local s = states[player]
	if not s then
		s = { furiaStacks = 0, furiaUntil = 0, clipHits = 0, clipUntil = 0, parryUntil = 0, dodgeUntil = 0, combatStart = 0, lastHit = 0, hitCount = 0 }
		states[player] = s
	end
	return s
end

local function healthRatio(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.MaxHealth <= 0 then
		return 1
	end
	return humanoid.Health / humanoid.MaxHealth
end

-- Multiplica o dano (e a postura) antes de aplicar. Retorna dano, multiplicador de postura.
function PerkService.modify(player, rec, damage, info, stats)
	local perks = stats.perks
	if not perks or next(perks) == nil or info.dot or info.perk then
		return damage, 1
	end
	local s = getState(player)
	local now = os.clock()
	local mult, postureMult = 1, 1
	-- tempo em luta (Frenesi)
	if now - s.lastHit > 5 then
		s.combatStart = now
	end
	s.lastHit = now

	if perks.furia_crescente and now < s.furiaUntil then
		mult *= 1 + 0.08 * s.furiaStacks
	end
	if perks.golpe_final and s.clipHits > 0 and now < s.clipUntil then
		mult *= 1.25
		s.clipHits -= 1
	end
	if perks.ritmo_perfeito and info.rhythm then
		mult *= 1.2
	end
	if perks.contragolpe and now < s.parryUntil then
		mult *= 1.4
	end
	if perks.abertura and rec.hp >= rec.maxHp then
		mult *= 1.5
	end
	if perks.carrasco and rec.hp < rec.maxHp * 0.3 then
		mult *= 1.3
	end
	if perks.frenesi_combate and now - s.combatStart >= 8 then
		mult *= 1.15
	end
	if perks.impeto and now < s.dodgeUntil then
		mult *= 1.3
	end
	local ratio = healthRatio(player)
	if perks.sede_sangue then
		mult *= 1 + math.floor((1 - ratio) * 20) * 0.01
	end
	if perks.adrenalina and ratio < 0.3 then
		mult *= 1.2
	end
	if perks.quebra_escudo then
		postureMult *= 1.35
	end
	return damage * mult, postureMult
end

-- Efeitos depois de acertar (eco, raio, veneno, queimadura)
function PerkService.afterHit(player, rec, dealt, info, stats, crit)
	local perks = stats.perks
	if not perks or next(perks) == nil or info.dot or info.perk or dealt <= 0 then
		return
	end
	if perks.eco and math.random() < 0.15 then
		task.delay(0.12, function()
			if not rec.dead then
				EnemyService.damage(rec, dealt * 0.5, player, { perk = true, color = Color3.fromRGB(180, 220, 255) })
			end
		end)
	end
	if perks.tempestade and crit then
		local count = 0
		for _, other in EnemyService.inRadius(rec.pos, 14, nil, player) do
			if other ~= rec and not other.dead and count < 2 then
				count += 1
				Remotes.Fx:FireAllClients("chain", EnemyService.centerOf(rec), EnemyService.centerOf(other))
				EnemyService.damage(other, dealt * 0.6, player, { perk = true, element = "arcane" })
			end
		end
	end
	-- ===== Únicos =====
	local s = getState(player)
	s.hitCount += 1
	if perks.eclipse and s.hitCount % 5 == 0 then
		local center = rec.pos
		Remotes.Fx:FireAllClients("explosion", center, 10, "shadow")
		for _, other in EnemyService.inRadius(center, 10, nil, player) do
			EnemyService.damage(other, stats.attack * stats.damageMult * 1.5, player, { perk = true, element = "shadow", knockback = 5, fromPosition = center })
		end
	end
	if perks.terremoto and s.hitCount % 4 == 0 then
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local center = if root then root.Position - Vector3.new(0, 2.5, 0) else rec.pos
		Remotes.Fx:FireAllClients("explosion", center, 12, "earth")
		for _, other in EnemyService.inRadius(center, 12, nil, player) do
			EnemyService.damage(other, stats.attack * stats.damageMult * 1.1, player, { perk = true, element = "earth", posture = 25, knockback = 6, fromPosition = center })
		end
	end
	if perks.sangria then
		EnemyService.applyDot(rec, player, dealt * 0.1, 3, "burn")
	end
	-- raide: Chuva Estelar (uma estrela cai no alvo)
	if perks.chuva_estelar and not info.perk and math.random() < 0.12 then
		local center = rec.pos
		Remotes.Fx:FireAllClients("meteor", center, 8, 0.35)
		task.delay(0.35, function()
			Remotes.Fx:FireAllClients("explosion", center, 8, "holy")
			for _, other in EnemyService.inRadius(center, 8, nil, player) do
				EnemyService.damage(other, stats.attack * stats.damageMult * 1.2, player, { perk = true, element = "holy", posture = 15, fromPosition = center })
			end
		end)
	end
	if perks.teia_viuva then
		EnemyService.applyDot(rec, player, dealt * 0.06, 4, "poison")
		if crit then
			local count = 0
			for _, other in EnemyService.inRadius(rec.pos, 16, nil, player) do
				if other ~= rec and not other.dead and count < 3 then
					count += 1
					Remotes.Fx:FireAllClients("chain", EnemyService.centerOf(rec), EnemyService.centerOf(other))
					EnemyService.damage(other, dealt * 0.6, player, { perk = true, element = "poison" })
				end
			end
		end
	end
	if perks.lamina_toxica and math.random() < 0.25 then
		EnemyService.applyDot(rec, player, dealt * 0.15, 4, "poison")
	end
	if perks.brasa_viva and math.random() < 0.25 then
		EnemyService.applyDot(rec, player, dealt * 0.15, 3, "burn")
	end
end

-- Chamado para quem deu o golpe final
function PerkService.onKill(player, rec)
	local stats = PlayerService.getStats(player)
	local perks = stats.perks
	if not perks or next(perks) == nil then
		return
	end
	local s = getState(player)
	local now = os.clock()
	if perks.furia_crescente then
		s.furiaStacks = if now < s.furiaUntil then math.min(3, s.furiaStacks + 1) else 1
		s.furiaUntil = now + 6
		Remotes.Fx:FireClient(player, "buff", "furia_crescente", 6)
	end
	if perks.golpe_final then
		s.clipHits = 3
		s.clipUntil = now + 8
	end
	local healFraction = (if perks.sanguessuga then 0.06 else 0) + (if perks.recuperacao then 0.03 else 0) + (if perks.pacto_espectral then 0.05 else 0)
	-- Único Abismo Arcano: mana de volta e vórtice
	if perks.abismo_arcano then
		PlayerService.restoreMana(player, 0.15)
		local center = rec.pos
		Remotes.Fx:FireAllClients("explosion", center, 10, "arcane")
		for _, other in EnemyService.inRadius(center, 10, nil, player) do
			if other ~= rec and not other.dead then
				EnemyService.damage(other, stats.attack * stats.damageMult * 1.2, player, { perk = true, element = "arcane", knockback = -6, fromPosition = center })
			end
		end
	end
	-- conjunto Fúria do Abismo: Erupção
	if perks.erupcao then
		local center = rec.pos
		Remotes.Fx:FireAllClients("explosion", center, 9, "fire")
		for _, other in EnemyService.inRadius(center, 9, nil, player) do
			if other ~= rec and not other.dead then
				EnemyService.damage(other, stats.attack * stats.damageMult * 0.8, player, { perk = true, element = "fire", knockback = 6, fromPosition = center })
			end
		end
	end
	if healFraction > 0 then
		PlayerService.heal(player, stats.maxHealth * healFraction)
		Remotes.Fx:FireAllClients("heal", player, math.floor(stats.maxHealth * healFraction))
	end
	if perks.explosao_fatal then
		local center = rec.pos
		local damage = stats.attack * stats.damageMult * 0.6
		Remotes.Fx:FireAllClients("explosion", center, 8, "fire")
		for _, other in EnemyService.inRadius(center, 8, nil, player) do
			if other ~= rec and not other.dead then
				EnemyService.damage(other, damage, player, { perk = true, element = "fire", knockback = 6, fromPosition = center })
			end
		end
	end
end

function PerkService.onParry(player)
	getState(player).parryUntil = os.clock() + 4
end

function PerkService.onPerfectDodge(player)
	getState(player).dodgeUntil = os.clock() + 3
end

-- Golpe pesado carregado ao máximo (Impacto Brutal)
function PerkService.onFullCharge(player, delay)
	local stats = PlayerService.getStats(player)
	if not stats.perks.impacto_brutal then
		return
	end
	task.delay(delay or 0.25, function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		local center = root.Position - Vector3.new(0, 2.5, 0)
		Remotes.Fx:FireAllClients("explosion", center, 11, "earth")
		for _, rec in EnemyService.inRadius(root.Position, 11, nil, player) do
			EnemyService.damage(rec, stats.attack * stats.damageMult * 0.7, player, { perk = true, element = "earth", knockback = 10, fromPosition = root.Position, posture = 15 })
		end
	end)
end

Players.PlayerRemoving:Connect(function(player)
	states[player] = nil
end)

return PerkService
