-- Jogador: atributos, recursos (vida/mana/estamina), classe, habilidades, inventário, materiais e sincronização.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Rarities = require(Shared.Rarities)
local Classes = require(Shared.Classes)
local Perks = require(Shared.Perks)
local Skills = require(Shared.Skills)
local WeaponStyles = require(Shared.WeaponStyles)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local SkillService = require(script.Parent.SkillService)
local WeaponModels = require(script.Parent.WeaponModels)

local PlayerService = {}

-- Ganchos preenchidos pelo init (evita dependências circulares)
PlayerService.QuestHook = function(_player, _kind, _target, _amount) end
PlayerService.QuestSummary = function(_player)
	return nil
end
PlayerService.OnDamaged = function(_player) end
PlayerService.OnParry = function(_player, _source) end -- source = registro do inimigo (ou nil)
PlayerService.ExtraSync = function(_player, _payload) end

local dirty = {}
local state = {} -- recursos em tempo real por jogador

function PlayerService.markDirty(player)
	dirty[player] = true
end

function PlayerService.getState(player)
	return state[player]
end

local function countInventory(data)
	local count = 0
	for _ in data.inventory do
		count += 1
	end
	return count
end

local function isEquipped(data, uid)
	for _, equippedUid in data.equipped do
		if equippedUid == uid then
			return true
		end
	end
	return false
end

function PlayerService.getEquipped(player, slot)
	local data = DataService.get(player)
	if not data then
		return nil
	end
	local uid = data.equipped[slot]
	return uid and data.inventory[uid]
end

-- ===================== ATRIBUTOS =====================

-- Esquiva perfeita (perk Ímpeto): ligado ao PerkService no init
PlayerService.OnPerfectDodge = function(_player) end

-- Perk Espinhos: devolve dano ao inimigo (ligado ao EnemyService no init)
PlayerService.OnThorns = function(_player, _source, _amount) end

-- Gancho para somar bônus de outros sistemas (pets, perks): function(player, data, bonus)
PlayerService.ExtraBonus = function(_player, _data, _bonus) end

local function addBonus(target, source, scale)
	for key, value in source do
		target[key] = (target[key] or 0) + value * (scale or 1)
	end
end
PlayerService.addBonus = addBonus

function PlayerService.getStats(player)
	local data = DataService.get(player)
	local stats = {
		maxHealth = Config.BaseHealth,
		maxMana = Config.BaseMana,
		maxStamina = Config.BaseStamina,
		attack = Config.BaseAttack,
		damageMult = 1,
		crit = Config.CritChance,
		critMult = Config.CritMultiplier,
		attackSpeed = 1,
		lifesteal = 0,
		burn = 0,
		regen = 0,
		defense = 0,
		weaponType = "sword",
		masteryId = "espadas",
		masteryLevel = 1,
		affinity = false,
		bonus = {},
		perks = {},
		damageReduction = 0,
	}
	if not data then
		return stats
	end
	local class = Classes.List[data.class]
	local weapon = PlayerService.getEquipped(player, "weapon")
	local weaponBase = weapon and Items.Bases[weapon.base]
	local weaponType = if weaponBase then weaponBase.weaponType else "sword"
	local masteryId = Skills.ByWeaponType[weaponType] or "espadas"
	local masteryLevel = SkillService.getLevel(player, masteryId)
	local style = WeaponStyles.get(weaponType)

	local function enchantStat(item, stat)
		if item and item.enchant then
			local def = Items.Enchants[item.enchant.id]
			if def and def.stat == stat then
				return Items.enchantValue(item.enchant)
			end
		end
		return 0
	end
	-- soma de um encantamento de "armadura" em todas as peças que não são arma
	local function gearEnchant(stat)
		local total = 0
		for _, slot in Items.SlotOrder do
			if slot ~= "weapon" then
				total += enchantStat(PlayerService.getEquipped(player, slot), stat)
			end
		end
		return total
	end

	-- peças de vida (armadura, elmo, botas) e de ataque (amuleto, anel); bônus fixos, stats e perks
	local armorPower, accessoryPower = 0, 0
	local armorBonus = { mana = 0, stamina = 0 }
	local bonus = Classes.talentStats(data.class, data.talents)
	local setCounts = {}
	for _, slot in Items.SlotOrder do
		local item = PlayerService.getEquipped(player, slot)
		local base = item and Items.Bases[item.base]
		if base then
			if slot ~= "weapon" then
				local slotInfo = Items.Slots[slot]
				if slotInfo and slotInfo.kind == "health" then
					armorPower += Items.getPower(item)
				else
					accessoryPower += Items.getPower(item)
				end
			end
			if base.bonus then
				armorBonus.mana += base.bonus.mana or 0
				armorBonus.stamina += base.bonus.stamina or 0
			end
			if base.set then
				setCounts[base.set] = (setCounts[base.set] or 0) + 1
			end
			local itemStats = Items.getStats(item)
			if itemStats then
				addBonus(bonus, itemStats)
			end
			for _, perkId in item.perks or {} do
				stats.perks[perkId] = (stats.perks[perkId] or 0) + 1
				local perk = Perks.List[perkId]
				if perk and perk.stats then
					addBonus(bonus, perk.stats)
				end
			end
		end
	end
	-- bônus de conjunto (2 e 4 peças)
	stats.sets = setCounts
	for setId, count in setCounts do
		local set = Items.Sets[setId]
		for pieces, setBonus in if set then set.bonuses else {} do
			if count >= pieces then
				addBonus(bonus, setBonus.stats or {})
				if setBonus.perk then
					stats.perks[setBonus.perk] = 1
				end
			end
		end
	end
	local level = data.level

	stats.maxHealth = math.floor(((Config.BaseHealth + level * Config.HealthPerLevel) * (class and class.health or 1) + armorPower) * (1 + gearEnchant("health")))
	stats.maxMana = math.floor(((Config.BaseMana + level * Config.ManaPerLevel) * (class and class.mana or 1) + armorBonus.mana) * (1 + gearEnchant("mana")))
	stats.maxStamina = math.floor((Config.BaseStamina * (class and class.stamina or 1) + armorBonus.stamina) * (1 + gearEnchant("stamina")))
	stats.attack = (Config.BaseAttack + level * Config.AttackPerLevel + (if weapon then Items.getPower(weapon) else 0) + accessoryPower) * (class and class.damage or 1)
	stats.affinity = class ~= nil and class.weapons[weaponType] == true
	stats.damageMult = (1 + masteryLevel * Config.MasteryDamagePerLevel) * (if stats.affinity then 1 + Config.AffinityBonus else 1) * (1 + enchantStat(weapon, "damage"))
	stats.crit = Config.CritChance + (class and class.crit or 0) + (style.crit or 0) + Skills.masteryCrit(masteryLevel) + enchantStat(weapon, "crit")
	stats.critMult = Config.CritMultiplier + Skills.masteryCritDamage(masteryLevel)
	stats.attackSpeed = 1 + Skills.masterySpeed(masteryLevel) + enchantStat(weapon, "speed")
	stats.lifesteal = enchantStat(weapon, "lifesteal")
	stats.burn = enchantStat(weapon, "burn")
	stats.regen = gearEnchant("regen")
	stats.defense = armorPower * 0.25

	-- talentos + acessórios + perks (somados acima) + bônus extras (pet: gancho ExtraBonus)
	PlayerService.ExtraBonus(player, data, bonus)
	stats.bonus = bonus
	stats.maxHealth = math.floor(stats.maxHealth * (1 + (bonus.health or 0)))
	stats.maxMana = math.floor(stats.maxMana * (1 + (bonus.mana or 0)))
	stats.maxStamina = math.floor(stats.maxStamina * (1 + (bonus.stamina or 0)))
	stats.damageMult *= 1 + (bonus.damage or 0)
	stats.crit += bonus.crit or 0
	stats.critMult += bonus.critDamage or 0
	stats.attackSpeed += bonus.attackSpeed or 0
	stats.lifesteal += bonus.lifesteal or 0
	stats.regen += bonus.regen or 0
	stats.damageReduction = math.clamp(bonus.defense or 0, 0, 0.6)
	stats.weaponType = weaponType
	stats.masteryId = masteryId
	stats.masteryLevel = masteryLevel
	return stats
end

-- ===================== RECURSOS =====================

local function newState(player)
	return {
		mana = 0,
		stamina = Config.BaseStamina,
		staminaBlockUntil = 0,
		sprinting = false,
		lastDamageAt = 0,
		iframesUntil = 0,
		buffs = {},
		potionCooldowns = {},
		mounted = false,
		nextCrit = false,
		blocking = false,
		blockStart = 0,
		dodgeStart = 0,
		perfectDodgeUsed = true,
		riposteUntil = 0,
		player = player,
	}
end

function PlayerService.spendStamina(player, amount)
	local s = state[player]
	if not s or s.stamina < amount then
		return false
	end
	s.stamina -= amount
	s.staminaBlockUntil = os.clock() + Config.StaminaRegenDelay
	player:SetAttribute("Stamina", math.floor(s.stamina))
	return true
end

function PlayerService.spendMana(player, amount)
	local s = state[player]
	if not s or s.mana < amount then
		return false
	end
	s.mana -= amount
	player:SetAttribute("Mana", math.floor(s.mana))
	return true
end

function PlayerService.setSprinting(player, value)
	local s = state[player]
	if s then
		s.sprinting = value == true and s.stamina > 5
	end
end

function PlayerService.addBuff(player, id, values, duration)
	local s = state[player]
	if not s then
		return
	end
	s.buffs[id] = { values = values, untilTime = os.clock() + duration }
	Remotes.Fx:FireClient(player, "buff", id, duration)
end

function PlayerService.buffValue(player, stat)
	local s = state[player]
	if not s then
		return 0
	end
	local total = 0
	local now = os.clock()
	for id, buff in s.buffs do
		if now > buff.untilTime then
			s.buffs[id] = nil
		elseif buff.values[stat] then
			total += buff.values[stat]
		end
	end
	return total
end

function PlayerService.inCombat(player)
	local s = state[player]
	return s ~= nil and os.clock() - s.lastDamageAt < Config.CombatTimeout
end

function PlayerService.markCombat(player)
	local s = state[player]
	if s then
		s.lastDamageAt = os.clock()
	end
end

function PlayerService.grantIFrames(player, duration)
	local s = state[player]
	if s then
		s.iframesUntil = math.max(s.iframesUntil, os.clock() + duration)
	end
end

-- ===================== DEFESA (bloquear, aparar, esquivar) =====================

function PlayerService.setBlocking(player, value)
	local s = state[player]
	if not s then
		return
	end
	if value and not s.blocking and s.stamina > 5 and not s.mounted then
		s.blocking = true
		s.blockStart = os.clock()
		s.sprinting = false
		Remotes.Fx:FireAllClients("block", player, true)
	elseif not value and s.blocking then
		s.blocking = false
		Remotes.Fx:FireAllClients("block", player, false)
	end
end

function PlayerService.startDodge(player)
	local s = state[player]
	if s then
		s.dodgeStart = os.clock()
		s.perfectDodgeUsed = false
		if s.blocking then
			PlayerService.setBlocking(player, false)
		end
	end
end

-- O próximo golpe depois de aparar é crítico e quebra mais postura
function PlayerService.consumeRiposte(player)
	local s = state[player]
	if s and os.clock() < s.riposteUntil then
		s.riposteUntil = 0
		return true
	end
	return false
end

local function facing(character, sourcePosition)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or typeof(sourcePosition) ~= "Vector3" then
		return true
	end
	local toSource = Vector3.new(sourcePosition.X - root.Position.X, 0, sourcePosition.Z - root.Position.Z)
	if toSource.Magnitude < 0.5 then
		return true
	end
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
	return look:Dot(toSource.Unit) > -0.2 -- ~100° para cada lado
end

-- Dano recebido pelo jogador.
-- options.unblockable = golpe que só dá para esquivar (investidas, pancadas em área)
-- Suporte: curou ou fortaleceu um aliado (conta como ajuda nas recompensas por alguns segundos)
function PlayerService.markSupport(player)
	local s = state[player]
	if s then
		s.lastSupport = os.clock()
	end
end

function PlayerService.recentlySupported(player, seconds)
	local s = state[player]
	return s ~= nil and os.clock() - (s.lastSupport or -100) <= seconds
end

-- options.source = registro do inimigo que atacou (para aparar)
-- Retorna "hit", "blocked", "parried" ou "evaded" (ou nil se o jogador não pode tomar dano)
function PlayerService.damagePlayer(player, amount, sourcePosition, options)
	options = options or {}
	local s = state[player]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not s or not humanoid or humanoid.Health <= 0 then
		return nil
	end
	local now = os.clock()
	if now < s.iframesUntil then
		if not s.perfectDodgeUsed and now - s.dodgeStart <= Config.PerfectDodgeWindow then
			-- esquiva perfeita: devolve estamina e o próximo golpe é crítico
			s.perfectDodgeUsed = true
			s.stamina = math.min(PlayerService.getStats(player).maxStamina, s.stamina + Config.PerfectDodgeStamina)
			s.nextCrit = true
			Remotes.Fx:FireClient(player, "perfectDodge")
			PlayerService.OnPerfectDodge(player)
			PlayerService.QuestHook(player, "perfectDodge", nil, 1)
		else
			Remotes.Fx:FireClient(player, "evaded")
		end
		return "evaded"
	end
	local stats = PlayerService.getStats(player)
	if s.blocking and not options.unblockable and facing(character, sourcePosition) then
		if now - s.blockStart <= Config.ParryWindow + (stats.bonus.parryWindow or 0) then
			-- APARAR: nenhum dano, inimigo desequilibrado, contra-ataque garantido
			s.riposteUntil = now + Config.RiposteTime
			s.stamina = math.min(PlayerService.getStats(player).maxStamina, s.stamina + 10)
			s.lastDamageAt = now
			Remotes.Fx:FireAllClients("parry", player, sourcePosition)
			PlayerService.OnParry(player, options.source)
			PlayerService.QuestHook(player, "parry", nil, 1)
			return "parried"
		end
		local blockedDamage = amount * Config.BlockReduction
		local cost = if stats.perks.bastiao then 0 else blockedDamage * Config.BlockStaminaPerDamage * (if stats.perks.muralha then 0.75 else 1)
		if stats.perks.bastiao and options.source and not options.ranged then
			PlayerService.OnThorns(player, options.source, blockedDamage * 0.4)
		end
		if s.stamina >= cost then
			s.stamina -= cost
			s.staminaBlockUntil = now + Config.StaminaRegenDelay
			amount -= blockedDamage
			Remotes.Fx:FireAllClients("blocked", player, sourcePosition)
		else
			-- estamina acabou: a guarda quebra e o golpe entra inteiro
			s.stamina = 0
			PlayerService.setBlocking(player, false)
			Remotes.Fx:FireClient(player, "guardBreak")
		end
	end
	local defense = stats.defense * (1 + PlayerService.buffValue(player, "defense"))
	local reduction = defense / (defense + 100)
	local level = (DataService.get(player) or {}).level or 1
	local newbie = Config.NewbieProtection[level] or 0
	local final = math.max(1, math.floor(amount * (1 - reduction) * (1 - stats.damageReduction) * (1 - newbie) * (if stats.perks.tirania then 0.85 else 1)))
	-- Único Filactério: o golpe fatal faz voltar com 50% da vida (a cada 120 s)
	if stats.perks.filacterio and final >= humanoid.Health and now >= (s.phylacteryAt or 0) then
		s.phylacteryAt = now + 120
		s.iframesUntil = now + 2
		humanoid.Health = humanoid.MaxHealth * 0.5
		Remotes.Fx:FireAllClients("heal", player, math.floor(humanoid.MaxHealth * 0.5))
		Remotes.Notify:FireClient(player, { kind = "banner", text = "💀 FILACTÉRIO!", sub = "Sua alma voltou ao corpo", color = Color3.fromRGB(170, 130, 255), duration = 2.5 })
		return "evaded"
	end
	-- perk Segunda Chance: o golpe fatal deixa com 1 de vida (a cada 90s)
	if stats.perks.segunda_chance and final >= humanoid.Health and now >= (s.secondChanceAt or 0) then
		final = math.max(0, math.floor(humanoid.Health) - 1)
		s.secondChanceAt = now + 90
		s.iframesUntil = now + 2
		Remotes.Notify:FireClient(player, { kind = "banner", text = "😇 SEGUNDA CHANCE!", sub = "Invencível por 2 segundos", color = Color3.fromRGB(255, 230, 140), duration = 2.5 })
	end
	-- perk Espinhos: devolve parte do dano corpo a corpo
	if stats.perks.espinhos and options.source and not options.ranged then
		PlayerService.OnThorns(player, options.source, final * 0.25 * stats.perks.espinhos)
	end
	humanoid:TakeDamage(final)
	s.lastDamageAt = now
	Remotes.Fx:FireClient(player, "hurt", final, sourcePosition)
	PlayerService.OnDamaged(player)
	return if s.blocking then "blocked" else "hit"
end

-- Devolve uma fração da mana máxima
function PlayerService.restoreMana(player, fraction)
	local s = state[player]
	if s then
		local stats = PlayerService.getStats(player)
		s.mana = math.min(stats.maxMana, s.mana + stats.maxMana * fraction)
	end
end

function PlayerService.heal(player, amount)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + amount)
	end
end

-- ===================== PERSONAGEM =====================

-- Visual dos equipamentos no personagem (armadura, elmo e botas), soldado nas partes do corpo.
-- O detalhe cresce com a raridade: ombreiras (Incomum+), detalhes brilhantes (Épico+) e capa (Lendário+).
local function gearPart(model, attachTo, size, offset, color, material, rarity, shape)
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = attachTo.CFrame * offset
	p.Color = color
	p.Material = material
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = attachTo
	weld.Part1 = p
	weld.Parent = p
	if rarity.rainbow and material == Enum.Material.Neon then
		CollectionService:AddTag(p, "Rainbow")
	end
	return p
end

local GEAR_VISUALS = {}

function GEAR_VISUALS.armor(character, item, rarity, base, model)
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local lower = character:FindFirstChild("LowerTorso")
	if not torso then
		return
	end
	local s = torso.Size
	local accentMaterial = if rarity.order >= 4 then Enum.Material.Neon else Enum.Material.Metal
	local isRobe = base.bonus and base.bonus.mana ~= nil
	local isLeather = base.bonus and base.bonus.stamina ~= nil
	local function plate(size, offset, color, material, shape)
		return gearPart(model, torso, size, offset, color, material, rarity, shape)
	end
	if isRobe then
		local cloth = Color3.fromRGB(60, 50, 110):Lerp(rarity.color, 0.25)
		plate(s + Vector3.new(0.15, 0.05, 0.15), CFrame.new(), cloth, Enum.Material.Fabric)
		plate(Vector3.new(0.35, s.Y, 0.12), CFrame.new(0, 0, -(s.Z / 2 + 0.1)), rarity.color, accentMaterial)
		plate(Vector3.new(s.X + 0.3, 0.3, s.Z + 0.3), CFrame.new(0, s.Y / 2 - 0.1, 0), rarity.color:Lerp(Color3.new(1, 1, 1), 0.3), Enum.Material.Fabric) -- gola
		if lower then
			-- saia do manto
			gearPart(model, lower, Vector3.new(lower.Size.X + 0.3, 1.6, lower.Size.Z + 0.3), CFrame.new(0, -0.6, 0), cloth, Enum.Material.Fabric, rarity)
			gearPart(model, lower, Vector3.new(0.3, 1.6, 0.1), CFrame.new(0, -0.6, -(lower.Size.Z / 2 + 0.16)), rarity.color, accentMaterial, rarity)
		end
	else
		local metal = if isLeather then Color3.fromRGB(110, 75, 50) else Color3.fromRGB(95, 95, 108):Lerp(rarity.color, 0.15)
		local material = if isLeather then Enum.Material.Fabric else Enum.Material.Metal
		plate(s + Vector3.new(0.2, 0.05, 0.2), CFrame.new(), metal, material)
		-- peitoral em camadas
		plate(Vector3.new(s.X * 0.75, s.Y * 0.55, 0.15), CFrame.new(0, 0.15, -(s.Z / 2 + 0.15)), metal:Lerp(Color3.new(1, 1, 1), 0.15), material)
		plate(Vector3.new(s.X * 0.45, s.Y * 0.3, 0.17), CFrame.new(0, 0.2, -(s.Z / 2 + 0.22)), rarity.color, accentMaterial)
		-- cinto com fivela
		plate(Vector3.new(s.X + 0.25, 0.28, s.Z + 0.25), CFrame.new(0, -s.Y / 2 + 0.15, 0), Color3.fromRGB(60, 40, 28), Enum.Material.Fabric)
		plate(Vector3.new(0.35, 0.3, 0.1), CFrame.new(0, -s.Y / 2 + 0.15, -(s.Z / 2 + 0.17)), Color3.fromRGB(220, 180, 70), Enum.Material.Metal)
		-- rebites
		for _, x in { -1, 1 } do
			plate(Vector3.one * 0.14, CFrame.new(x * s.X * 0.32, 0.45, -(s.Z / 2 + 0.25)), Color3.fromRGB(220, 180, 70), Enum.Material.Metal, Enum.PartType.Ball)
		end
	end
	-- ombreiras
	if rarity.order >= 2 then
		for _, side in { -1, 1 } do
			local shoulder = plate(Vector3.new(1.05, 0.45, 1.35), CFrame.new(side * (s.X / 2 + 0.25), s.Y / 2 - 0.05, 0) * CFrame.Angles(0, 0, math.rad(-side * 12)), if isRobe then rarity.color else Color3.fromRGB(100, 100, 115):Lerp(rarity.color, 0.4), if isRobe then Enum.Material.Fabric else Enum.Material.Metal)
			local _sh = shoulder
			if rarity.order >= 4 then
				plate(Vector3.new(1.1, 0.12, 1.4), CFrame.new(side * (s.X / 2 + 0.27), s.Y / 2 + 0.2, 0) * CFrame.Angles(0, 0, math.rad(-side * 12)), rarity.color, Enum.Material.Neon)
			end
		end
	end
	-- capa (Lendário+)
	if rarity.order >= 5 then
		local cape = plate(Vector3.new(s.X * 0.95, 3.4, 0.12), CFrame.new(0, -1.15, s.Z / 2 + 0.2) * CFrame.Angles(math.rad(-6), 0, 0), rarity.color:Lerp(Color3.new(0, 0, 0), 0.35), Enum.Material.Fabric)
		local _c = cape
		plate(Vector3.new(s.X * 0.95, 0.15, 0.14), CFrame.new(0, -2.8, s.Z / 2 + 0.38) * CFrame.Angles(math.rad(-6), 0, 0), rarity.color, Enum.Material.Neon)
	end
end

function GEAR_VISUALS.helmet(character, item, rarity, base, model)
	local head = character:FindFirstChild("Head")
	if not head then
		return
	end
	local s = head.Size
	local id = item.base
	local accentMaterial = if rarity.order >= 4 then Enum.Material.Neon else Enum.Material.Metal
	local function piece(size, offset, color, material, shape)
		return gearPart(model, head, size, offset, color, material, rarity, shape)
	end
	if id == "capuz_aprendiz" or id == "capuz_sombrio" then
		local cloth = if id == "capuz_sombrio" then Color3.fromRGB(35, 30, 45) else Color3.fromRGB(90, 70, 130)
		piece(Vector3.new(s.X + 0.35, s.Y + 0.3, s.Z + 0.4), CFrame.new(0, 0.12, 0.08), cloth, Enum.Material.Fabric)
		piece(Vector3.new(s.X * 0.6, 0.6, 0.6), CFrame.new(0, 0.1, s.Z / 2 + 0.3) * CFrame.Angles(math.rad(-30), 0, 0), cloth, Enum.Material.Fabric)
		piece(Vector3.new(s.X + 0.4, 0.12, 0.1), CFrame.new(0, -0.3, -(s.Z / 2 + 0.15)), rarity.color, accentMaterial)
	elseif id == "coroa_arcana" then
		piece(Vector3.new(s.X + 0.15, 0.35, s.Z + 0.15), CFrame.new(0, s.Y / 2 + 0.05, 0), Color3.fromRGB(220, 180, 70), Enum.Material.Metal)
		for i = 0, 4 do
			local angle = i / 5 * math.pi * 2
			piece(Vector3.new(0.18, 0.5, 0.18), CFrame.new(0, s.Y / 2 + 0.4, 0) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -(s.Z / 2)), Color3.fromRGB(220, 180, 70), Enum.Material.Metal)
		end
		piece(Vector3.one * 0.3, CFrame.new(0, s.Y / 2 + 0.1, -(s.Z / 2 + 0.1)), rarity.color, Enum.Material.Neon, Enum.PartType.Ball)
	else
		-- elmo de couro, ferro ou dragão
		local leather = id == "elmo_couro"
		local color = if leather then Color3.fromRGB(110, 75, 50) else Color3.fromRGB(110, 110, 122):Lerp(rarity.color, 0.15)
		local material = if leather then Enum.Material.Fabric else Enum.Material.Metal
		piece(Vector3.new(s.X + 0.25, s.Y * 0.75, s.Z + 0.25), CFrame.new(0, 0.25, 0), color, material)
		piece(Vector3.new(s.X + 0.3, 0.18, s.Z + 0.3), CFrame.new(0, -0.05, 0), rarity.color, accentMaterial)
		if not leather then
			-- protetor de nariz e laterais
			piece(Vector3.new(0.18, 0.6, 0.12), CFrame.new(0, -0.15, -(s.Z / 2 + 0.15)), color, material)
			for _, side in { -1, 1 } do
				piece(Vector3.new(0.12, 0.7, s.Z * 0.7), CFrame.new(side * (s.X / 2 + 0.12), -0.25, 0.05), color, material)
			end
			piece(Vector3.new(0.15, 0.35, s.Z + 0.1), CFrame.new(0, s.Y / 2 + 0.2, 0), rarity.color, accentMaterial) -- crista
		end
		if id == "elmo_dragao" then
			for _, side in { -1, 1 } do
				piece(Vector3.new(0.22, 0.9, 0.22), CFrame.new(side * 0.55, s.Y / 2 + 0.35, 0.1) * CFrame.Angles(math.rad(-25), 0, math.rad(-side * 30)), Color3.fromRGB(240, 230, 210), Enum.Material.SmoothPlastic)
				piece(Vector3.new(0.15, 0.5, 0.15), CFrame.new(side * 0.85, s.Y / 2 + 0.85, 0.25) * CFrame.Angles(math.rad(-40), 0, math.rad(-side * 15)), Color3.fromRGB(240, 230, 210), Enum.Material.SmoothPlastic)
			end
		end
	end
end

function GEAR_VISUALS.boots(character, item, rarity, base, model)
	local accentMaterial = if rarity.order >= 4 then Enum.Material.Neon else Enum.Material.Metal
	local leather = item.base == "botas_couro" or item.base == "sandalias_monge" or item.base == "botas_vento"
	local color = if leather then Color3.fromRGB(95, 65, 45) else Color3.fromRGB(100, 100, 112):Lerp(rarity.color, 0.15)
	local material = if leather then Enum.Material.Fabric else Enum.Material.Metal
	for _, side in { "Left", "Right" } do
		local shin = character:FindFirstChild(side .. "LowerLeg")
		local foot = character:FindFirstChild(side .. "Foot")
		if shin then
			gearPart(model, shin, shin.Size + Vector3.new(0.15, -0.2, 0.15), CFrame.new(0, -0.1, 0), color, material, rarity)
			gearPart(model, shin, Vector3.new(shin.Size.X + 0.2, 0.15, shin.Size.Z + 0.2), CFrame.new(0, shin.Size.Y / 2 - 0.25, 0), rarity.color, accentMaterial, rarity)
		end
		if foot then
			gearPart(model, foot, foot.Size + Vector3.new(0.12, 0.08, 0.12), CFrame.new(0, 0.02, 0), color:Lerp(Color3.new(0, 0, 0), 0.2), material, rarity)
		end
	end
	local _b = base
end

-- Aplica (ou remove) o visual de um espaço: "armor", "helmet" ou "boots"
local function applyGearVisual(character, slot, item)
	local name = "Visual_" .. slot
	local old = character:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	if slot == "armor" then
		local legacy = character:FindFirstChild("ArmaduraVisual")
		if legacy then
			legacy:Destroy()
		end
	end
	local builder = GEAR_VISUALS[slot]
	if not item or not builder then
		return
	end
	local rarity = Rarities.ById[item.rarity] or Rarities.List[1]
	local base = Items.Bases[item.base] or {}
	local model = Instance.new("Model")
	model.Name = name
	builder(character, item, rarity, base, model)
	model.Parent = character
end

function PlayerService.refreshCharacter(player, options)
	local data = DataService.get(player)
	local character = player.Character
	if not data or not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local stats = PlayerService.getStats(player)
	local ratio = humanoid.Health / math.max(humanoid.MaxHealth, 1)
	humanoid.MaxHealth = stats.maxHealth
	humanoid.Health = if options.heal then stats.maxHealth else math.clamp(stats.maxHealth * ratio, 1, stats.maxHealth)
	if options.weapon then
		WeaponModels.attach(character, PlayerService.getEquipped(player, "weapon"))
	end
	if options.armor then
		for _, slot in { "armor", "helmet", "boots" } do
			applyGearVisual(character, slot, PlayerService.getEquipped(player, slot))
		end
	end
	player:SetAttribute("MaxMana", stats.maxMana)
	player:SetAttribute("MaxStamina", stats.maxStamina)
	player:SetAttribute("WeaponType", stats.weaponType)
end

local function updateLeaderstats(player, data)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return
	end
	leaderstats.Rank.Value = Config.getRank(data.level).name
	leaderstats["Nível"].Value = data.level
	local class = Classes.List[data.class]
	leaderstats.Classe.Value = if class then class.name else "—"
end

local function setupLeaderstats(player, data)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local level = Instance.new("IntValue")
	level.Name = "Nível"
	level.Parent = leaderstats
	local rank = Instance.new("StringValue")
	rank.Name = "Rank"
	rank.Parent = leaderstats
	local class = Instance.new("StringValue")
	class.Name = "Classe"
	class.Parent = leaderstats
	leaderstats.Parent = player
	updateLeaderstats(player, data)
end

-- ===================== PROGRESSÃO =====================

function PlayerService.addXP(player, amount)
	local data = DataService.get(player)
	if not data or data.level >= Config.MaxLevel then
		return
	end
	local oldRank = Config.getRank(data.level)
	data.xp += amount
	local leveled = false
	while data.level < Config.MaxLevel and data.xp >= Config.xpToNext(data.level) do
		data.xp -= Config.xpToNext(data.level)
		data.level += 1
		data.skillPoints += Config.SkillPointsPerLevel
		leveled = true
		-- avisa sobre habilidade destravada
		for _, abilityId in Classes.allAbilities(data.class) do
			local ability = Classes.Abilities[abilityId]
			if ability.unlock == data.level then
				Remotes.Notify:FireClient(player, { kind = "ability", ability = abilityId, learn = ability.advanced == true })
			end
		end
	end
	if data.level >= Config.MaxLevel then
		data.xp = 0
	end
	if leveled then
		player:SetAttribute("Level", data.level)
		Remotes.Notify:FireClient(player, { kind = "levelup", level = data.level })
		local newRank = Config.getRank(data.level)
		if newRank.name ~= oldRank.name then
			Remotes.Notify:FireClient(player, { kind = "rankup", rank = newRank.name })
			Remotes.Notify:FireAllClients({ kind = "announce", text = ("⭐ %s alcançou o Rank %s!"):format(player.DisplayName, newRank.name), color = newRank.color })
		end
		PlayerService.refreshCharacter(player, { heal = true })
		local s = state[player]
		if s then
			local stats = PlayerService.getStats(player)
			s.mana = stats.maxMana
			s.stamina = stats.maxStamina
		end
		updateLeaderstats(player, data)
		PlayerService.QuestHook(player, "level", nil, 0)
	end
	PlayerService.markDirty(player)
end

function PlayerService.addGold(player, amount)
	local data = DataService.get(player)
	if not data then
		return
	end
	data.gold += amount
	PlayerService.markDirty(player)
end

function PlayerService.addMaterial(player, id, count, silent)
	local data = DataService.get(player)
	if not data or count <= 0 or not Items.Materials[id] then
		return
	end
	data.materials[id] = (data.materials[id] or 0) + count
	if not silent then
		Remotes.Notify:FireClient(player, { kind = "material", id = id, count = count })
	end
	PlayerService.QuestHook(player, "gather", id, count)
	PlayerService.markDirty(player)
end

function PlayerService.addConsumable(player, id, count, silent)
	local data = DataService.get(player)
	if not data or count <= 0 or not Items.Consumables[id] then
		return
	end
	data.consumables[id] = (data.consumables[id] or 0) + count
	if not silent then
		Remotes.Notify:FireClient(player, { kind = "consumable", id = id, count = count })
	end
	PlayerService.markDirty(player)
end

-- Verifica e remove um custo { gold = n, materials = { id = n } }. Retorna ok, mensagem
function PlayerService.payCost(player, cost)
	local data = DataService.get(player)
	if not data then
		return false, "Dados carregando..."
	end
	if (cost.gold or 0) > data.gold then
		return false, ("Ouro insuficiente! Precisa de %d."):format(cost.gold)
	end
	for id, amount in cost.materials or {} do
		if (data.materials[id] or 0) < amount then
			local def = Items.Materials[id]
			return false, ("Faltam materiais: %s (%d/%d)"):format(if def then def.name else id, data.materials[id] or 0, amount)
		end
	end
	data.gold -= cost.gold or 0
	for id, amount in cost.materials or {} do
		data.materials[id] -= amount
		if data.materials[id] <= 0 then
			data.materials[id] = nil
		end
	end
	PlayerService.markDirty(player)
	return true
end

-- options.silent = true: sem popup (baú e forja têm animação própria)
function PlayerService.addItem(player, item, options)
	options = options or {}
	local data = DataService.get(player)
	if not data then
		return
	end
	local rarity = Rarities.ById[item.rarity] or Rarities.List[1]
	local base = Items.Bases[item.base]

	if countInventory(data) >= Config.MaxInventory then
		local value = Items.getSellValue(item)
		data.gold += value
		Remotes.Notify:FireClient(player, { kind = "message", text = ("Inventário cheio! %s vendido por %d de ouro."):format(Items.displayName(item), value) })
		PlayerService.markDirty(player)
		return
	end

	data.inventory[item.uid] = item
	if rarity.order > data.stats.bestRarity then
		data.stats.bestRarity = rarity.order
	end
	if not options.silent then
		Remotes.Notify:FireClient(player, { kind = "loot", item = Items.describe(item, false) })
	end
	if rarity.order >= 6 then
		local announcement = { kind = "announce", text = ("🔥 %s conseguiu %s [%s]!"):format(player.DisplayName, Items.displayName(item), rarity.name), rarity = rarity.id }
		task.delay(if options.silent then 5 else 0.5, function()
			Remotes.Notify:FireAllClients(announcement)
		end)
	end
	if base and not data.equipped[base.slot] then
		data.equipped[base.slot] = item.uid
		PlayerService.refreshCharacter(player, { weapon = base.slot == "weapon", armor = base.slot == "armor" or base.slot == "helmet" or base.slot == "boots" })
	end
	PlayerService.markDirty(player)
end

function PlayerService.equip(player, uid)
	local data = DataService.get(player)
	if not data or typeof(uid) ~= "string" then
		return { ok = false }
	end
	local item = data.inventory[uid]
	local base = item and Items.Bases[item.base]
	if not base then
		return { ok = false, msg = "Item não encontrado." }
	end
	if data.equipped[base.slot] == uid then
		return { ok = true }
	end
	data.equipped[base.slot] = uid
	PlayerService.refreshCharacter(player, { weapon = base.slot == "weapon", armor = base.slot == "armor" or base.slot == "helmet" or base.slot == "boots" })
	PlayerService.QuestHook(player, "equip", nil, 1)
	PlayerService.markDirty(player)
	return { ok = true }
end

function PlayerService.sell(player, uid)
	local data = DataService.get(player)
	if not data or typeof(uid) ~= "string" then
		return { ok = false }
	end
	local item = data.inventory[uid]
	if not item then
		return { ok = false, msg = "Item não encontrado." }
	end
	if isEquipped(data, uid) then
		return { ok = false, msg = "Você não pode vender um item equipado." }
	end
	local value = Items.getSellValue(item)
	data.inventory[uid] = nil
	data.gold += value
	PlayerService.markDirty(player)
	return { ok = true, gold = value }
end

function PlayerService.sellJunk(player)
	local data = DataService.get(player)
	if not data then
		return { ok = false }
	end
	local count, total = 0, 0
	for uid, item in data.inventory do
		local rarity = Rarities.ById[item.rarity]
		if rarity and rarity.order <= 2 and not isEquipped(data, uid) and not item.enchant then
			total += Items.getSellValue(item)
			count += 1
			data.inventory[uid] = nil
		end
	end
	data.gold += total
	PlayerService.markDirty(player)
	return { ok = true, count = count, gold = total }
end

function PlayerService.removeItem(player, uid)
	local data = DataService.get(player)
	if data then
		data.inventory[uid] = nil
		PlayerService.markDirty(player)
	end
end

function PlayerService.isEquipped(player, uid)
	local data = DataService.get(player)
	return data ~= nil and isEquipped(data, uid)
end

-- ===================== CLASSE E HABILIDADES =====================

-- ===================== HABILIDADES E TALENTOS =====================

-- Rank da habilidade (0 = não pode usar). Básicas: rank 1 grátis ao atingir o nível.
-- Avançadas: precisam ser aprendidas com 1 ponto.
function PlayerService.abilityRank(player, abilityId)
	local data = DataService.get(player)
	local ability = Classes.Abilities[abilityId]
	if not data or not ability or data.level < ability.unlock then
		return 0
	end
	if ability.advanced then
		return data.abilityRanks[abilityId] or 0
	end
	return math.max(1, data.abilityRanks[abilityId] or 1)
end

function PlayerService.abilityCooldown(player, ability, rank)
	local stats = PlayerService.getStats(player)
	local reduction = math.clamp(stats.bonus.cooldown or 0, 0, 0.4)
	return Classes.rankCooldown(ability, rank) * (1 - reduction)
end

-- Multiplicador de ameaça (tanques geram mais; usado pelos inimigos para escolher o alvo)
function PlayerService.threatMultiplier(player)
	local data = DataService.get(player)
	local class = data and Classes.List[data.class]
	local stats = PlayerService.getStats(player)
	return math.max(0.2, (class and class.threat or 1) * (1 + (stats.bonus.threat or 0)))
end

-- As 4 habilidades das teclas 1 a 4 (padrão: as básicas da classe)
function PlayerService.getLoadout(player)
	local data = DataService.get(player)
	local class = data and Classes.List[data.class]
	if not class then
		return {}
	end
	local all = Classes.allAbilities(data.class)
	local result = {}
	for slot = 1, 4 do
		local id = data.loadout and data.loadout[slot]
		if type(id) == "string" and id ~= "" and table.find(all, id) and not table.find(result, id) then
			result[slot] = id
		else
			result[slot] = ""
		end
	end
	-- vazio de verdade só se o jogador tirou; primeira vez usa as básicas
	if not data.loadout or #data.loadout == 0 then
		for slot = 1, 4 do
			result[slot] = class.abilities[slot]
		end
	end
	return result
end

function PlayerService.setLoadout(player, slot, abilityId)
	local data = DataService.get(player)
	local class = data and Classes.List[data.class]
	if not class or typeof(slot) ~= "number" or slot < 1 or slot > 4 or slot % 1 ~= 0 then
		return { ok = false, msg = "Espaço inválido." }
	end
	local loadout = PlayerService.getLoadout(player)
	if abilityId == "" then
		loadout[slot] = ""
	else
		if type(abilityId) ~= "string" or not table.find(Classes.allAbilities(data.class), abilityId) then
			return { ok = false, msg = "Habilidade inválida." }
		end
		if PlayerService.abilityRank(player, abilityId) <= 0 then
			return { ok = false, msg = "Aprenda essa habilidade primeiro." }
		end
		-- se já estava em outro espaço, troca de lugar
		local previous = table.find(loadout, abilityId)
		if previous then
			loadout[previous] = loadout[slot]
		end
		loadout[slot] = abilityId
	end
	data.loadout = loadout
	PlayerService.markDirty(player)
	return { ok = true }
end

-- Aprende (avançada, rank 0 → 1) ou sobe o rank de uma habilidade
function PlayerService.rankAbility(player, abilityId)
	local data = DataService.get(player)
	local class = data and Classes.List[data.class]
	local ability = Classes.Abilities[abilityId]
	if not class or not ability or not table.find(Classes.allAbilities(data.class), abilityId) then
		return { ok = false, msg = "Habilidade inválida." }
	end
	if data.level < ability.unlock then
		return { ok = false, msg = ("Destrava no nível %d."):format(ability.unlock) }
	end
	local rank = PlayerService.abilityRank(player, abilityId)
	if rank >= Classes.MaxAbilityRank then
		return { ok = false, msg = "Rank máximo!" }
	end
	if data.skillPoints <= 0 then
		return { ok = false, msg = "Sem pontos de talento. Suba de nível!" }
	end
	data.skillPoints -= 1
	data.abilityRanks[abilityId] = rank + 1
	-- aprendeu agora: coloca num espaço vazio, se houver
	if rank == 0 then
		local loadout = PlayerService.getLoadout(player)
		local empty = table.find(loadout, "")
		if empty then
			loadout[empty] = abilityId
			data.loadout = loadout
		end
	end
	PlayerService.markDirty(player)
	return { ok = true, rank = rank + 1, learned = rank == 0 }
end

-- Compra um rank de passiva
function PlayerService.learnTalent(player, nodeId)
	local data = DataService.get(player)
	local passive = type(nodeId) == "string" and Classes.PassiveById[nodeId]
	if not data or not passive or passive.class ~= data.class then
		return { ok = false, msg = "Talento inválido." }
	end
	local rank = data.talents[nodeId] or 0
	if rank >= passive.max then
		return { ok = false, msg = "Rank máximo!" }
	end
	local needed = Classes.TierPoints[passive.tier] or 0
	if Classes.branchPoints(data.class, data.talents, passive.branch) < needed then
		return { ok = false, msg = ("Gaste %d pontos neste ramo para liberar."):format(needed) }
	end
	if data.skillPoints <= 0 then
		return { ok = false, msg = "Sem pontos de talento. Suba de nível!" }
	end
	data.skillPoints -= 1
	data.talents[nodeId] = rank + 1
	PlayerService.refreshCharacter(player, {})
	PlayerService.markDirty(player)
	return { ok = true }
end

local function refundAll(data)
	data.skillPoints = math.max(0, (data.level - 1) * Config.SkillPointsPerLevel)
	data.abilityRanks = {}
	data.talents = {}
	data.loadout = {}
end

-- Redistribuir todos os pontos (custa ouro a partir do nível 10)
function PlayerService.respec(player)
	local data = DataService.get(player)
	if not data or not data.class then
		return { ok = false, msg = "Escolha uma classe primeiro." }
	end
	local price = if data.level >= 10 then Classes.RespecPrice else 0
	if data.gold < price then
		return { ok = false, msg = ("Redistribuir custa %d de ouro."):format(price) }
	end
	data.gold -= price
	refundAll(data)
	PlayerService.refreshCharacter(player, {})
	PlayerService.markDirty(player)
	return { ok = true, msg = "Pontos devolvidos!" }
end

function PlayerService.chooseClass(player, classId)
	local data = DataService.get(player)
	local class = Classes.List[classId]
	if not data or not class then
		return { ok = false, msg = "Classe inválida." }
	end
	if data.class == classId then
		return { ok = false, msg = "Você já é " .. class.name .. "." }
	end
	if data.class ~= nil then
		if data.gold < Config.ClassChangePrice then
			return { ok = false, msg = ("Trocar de classe custa %d de ouro."):format(Config.ClassChangePrice) }
		end
		data.gold -= Config.ClassChangePrice
	end
	data.class = classId
	refundAll(data)
	local weapon = Items.create(class.starter, "Comum", 1)
	data.inventory[weapon.uid] = weapon
	data.equipped.weapon = weapon.uid
	player:SetAttribute("Class", classId)
	PlayerService.refreshCharacter(player, { weapon = true, heal = true })
	updateLeaderstats(player, data)
	PlayerService.QuestHook(player, "class", classId, 1)
	PlayerService.markDirty(player)
	return { ok = true }
end


-- ===================== POÇÕES =====================

function PlayerService.useConsumable(player, id)
	local data = DataService.get(player)
	local s = state[player]
	local def = Items.Consumables[id]
	if not data or not s or not def then
		return false
	end
	if (data.consumables[id] or 0) <= 0 then
		Remotes.Notify:FireClient(player, { kind = "message", text = "Você não tem " .. def.name .. "." })
		return false
	end
	local now = os.clock()
	if now < (s.potionCooldowns[id] or 0) then
		return false
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end
	local stats = PlayerService.getStats(player)
	if def.heal then
		PlayerService.heal(player, stats.maxHealth * def.heal)
	end
	if def.mana then
		s.mana = math.min(stats.maxMana, s.mana + stats.maxMana * def.mana)
	end
	if def.stamina then
		s.stamina = stats.maxStamina
	end
	if def.damageBuff then
		PlayerService.addBuff(player, "elixir", { damage = def.damageBuff }, def.buffTime)
	end
	if def.defenseBuff then
		PlayerService.addBuff(player, "tonico", { defense = def.defenseBuff }, def.buffTime)
	end
	data.consumables[id] -= 1
	if data.consumables[id] <= 0 then
		data.consumables[id] = nil
	end
	s.potionCooldowns[id] = now + def.cooldown
	Remotes.Fx:FireAllClients("potion", player, id)
	Remotes.Fx:FireClient(player, "potionCooldown", id, def.cooldown)
	PlayerService.markDirty(player)
	return true
end

-- ===================== SINCRONIZAÇÃO =====================

function PlayerService.sync(player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local inventory = {}
	for uid, item in data.inventory do
		table.insert(inventory, Items.describe(item, isEquipped(data, uid)))
	end
	local stats = PlayerService.getStats(player)
	local abilities = {}
	local tree = {}
	local class = Classes.List[data.class]
	if class then
		local loadout = PlayerService.getLoadout(player)
		for slot = 1, 4 do
			local abilityId = loadout[slot]
			local ability = Classes.Abilities[abilityId]
			if ability then
				local rank = PlayerService.abilityRank(player, abilityId)
				abilities[slot] = {
					id = abilityId,
					rank = rank,
					unlocked = rank > 0,
					cooldown = PlayerService.abilityCooldown(player, ability, math.max(rank, 1)),
				}
			else
				abilities[slot] = { id = "", rank = 0, unlocked = false, cooldown = 0 }
			end
		end
		for _, abilityId in Classes.allAbilities(data.class) do
			local ability = Classes.Abilities[abilityId]
			table.insert(tree, {
				id = abilityId,
				rank = PlayerService.abilityRank(player, abilityId),
				unlock = ability.unlock,
				advanced = ability.advanced == true,
				slot = table.find(loadout, abilityId) or 0,
			})
		end
	end
	local payload = {
		level = data.level,
		xp = data.xp,
		xpNext = Config.xpToNext(data.level),
		gold = data.gold,
		class = data.class,
		skillPoints = data.skillPoints,
		abilities = abilities,
		tree = tree,
		talents = data.talents,
		stats = {
			attack = math.floor(stats.attack * stats.damageMult),
			maxHealth = stats.maxHealth,
			maxMana = stats.maxMana,
			maxStamina = stats.maxStamina,
			crit = stats.crit,
			critMult = stats.critMult,
			defense = math.floor(stats.defense),
			attackSpeed = stats.attackSpeed,
			lifesteal = stats.lifesteal,
			weaponType = stats.weaponType,
			masteryId = stats.masteryId,
			masteryLevel = stats.masteryLevel,
			affinity = stats.affinity,
		},
		inventory = inventory,
		maxInventory = Config.MaxInventory,
		materials = data.materials,
		consumables = data.consumables,
		skills = data.skills,
		discovered = data.discovered,
		mount = data.mount,
		quests = PlayerService.QuestSummary(player),
		isStudio = RunService:IsStudio(),
		settings = data.settings,
		tutorial = data.tutorial,
	}
	PlayerService.ExtraSync(player, payload)
	Remotes.DataUpdate:FireClient(player, payload)
end

-- ===================== CONFIGURAÇÕES E TUTORIAL =====================

local SETTING_RANGES = { volume = { 0, 1 }, sensitivity = { 0.2, 3 }, quality = { 1, 3 } }

-- Salva as configurações do jogador (só as chaves conhecidas, com tipo e faixa validados)
function PlayerService.saveSettings(player, values)
	local data = DataService.get(player)
	if not data or type(values) ~= "table" then
		return { ok = false, msg = "Configurações inválidas." }
	end
	for key, default in Config.DefaultSettings do
		local value = values[key]
		if type(default) == "boolean" and type(value) == "boolean" then
			data.settings[key] = value
		elseif type(default) == "number" and type(value) == "number" then
			local number = tonumber(value) or default
			local range = SETTING_RANGES[key] or { 0, 1 }
			if number == number then -- descarta NaN
				data.settings[key] = math.clamp(number, range[1], range[2])
			end
		end
	end
	return { ok = true }
end

-- Marca um passo do tutorial como feito (ou pula o tutorial inteiro)
function PlayerService.tutorial(player, stepId)
	local data = DataService.get(player)
	if not data or type(stepId) ~= "string" or #stepId > 32 then
		return { ok = false }
	end
	if stepId == "skip" then
		data.tutorial.skipped = true
	elseif stepId == "restart" then
		data.tutorial.skipped = false
		data.tutorial.done = {}
	else
		data.tutorial.done[stepId] = true
	end
	PlayerService.markDirty(player)
	return { ok = true }
end

-- ===================== ENTRADA / SAÍDA =====================

local function onCharacterAdded(player, character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end
	character:WaitForChild("HumanoidRootPart", 10)
	character:WaitForChild("RightHand", 5)
	if player.Character ~= character then
		return
	end
	humanoid.WalkSpeed = Config.WalkSpeed
	local s = state[player]
	if s then
		s.mounted = false
		s.sprinting = false
		s.buffs = {}
		local stats = PlayerService.getStats(player)
		s.mana = stats.maxMana
		s.stamina = stats.maxStamina
	end
	PlayerService.refreshCharacter(player, { heal = true, weapon = true, armor = true })
end

function PlayerService.onPlayerAdded(player)
	local data = DataService.load(player)
	if not player.Parent then
		return nil
	end
	for slot, uid in data.equipped do
		if not data.inventory[uid] then
			data.equipped[slot] = nil
		end
	end
	state[player] = newState(player)
	player:SetAttribute("Level", data.level)
	player:SetAttribute("Class", data.class)
	setupLeaderstats(player, data)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
	PlayerService.markDirty(player)
	return data
end

function PlayerService.onPlayerRemoving(player)
	dirty[player] = nil
	state[player] = nil
end

-- Laço de recursos: regenera mana/estamina e aplica o gasto da corrida (10x por segundo)
task.spawn(function()
	local last = os.clock()
	while true do
		task.wait(0.1)
		local now = os.clock()
		local dt = now - last
		last = now
		for player, s in state do
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 and DataService.get(player) then
				local stats = PlayerService.getStats(player)
				local class = DataService.get(player).class
				local manaRegen = Config.ManaRegen * (if class == "mago" or class == "clerigo" then 2 else 1) * (1 + (stats.bonus.manaRegen or 0))
				s.mana = math.min(stats.maxMana, s.mana + manaRegen * dt)
				local moving = humanoid.MoveDirection.Magnitude > 0.1
				if s.blocking then
					s.staminaBlockUntil = now + 0.3
				elseif s.sprinting and moving and not s.mounted then
					s.stamina -= Config.SprintDrain * dt
					s.staminaBlockUntil = now + Config.StaminaRegenDelay * 0.5
					if s.stamina <= 0 then
						s.stamina = 0
						s.sprinting = false
						Remotes.Fx:FireClient(player, "exhausted")
					end
				elseif now > s.staminaBlockUntil then
					s.stamina = math.min(stats.maxStamina, s.stamina + Config.StaminaRegen * dt)
				end
				if stats.regen > 0 then
					PlayerService.heal(player, stats.maxHealth * stats.regen * dt)
				end
				-- fora de combate a vida volta rápido
				if now - (s.lastDamageAt or 0) > Config.OutOfCombatDelay and humanoid.Health < humanoid.MaxHealth then
					PlayerService.heal(player, stats.maxHealth * Config.OutOfCombatRegen * dt)
				end
				player:SetAttribute("Mana", math.floor(s.mana))
				player:SetAttribute("Stamina", math.floor(s.stamina))
				player:SetAttribute("MaxMana", stats.maxMana)
				player:SetAttribute("MaxStamina", stats.maxStamina)
			end
		end
	end
end)

-- Envia o estado completo ao cliente no máximo ~6x por segundo
task.spawn(function()
	while true do
		task.wait(0.16)
		for player in dirty do
			dirty[player] = nil
			if player.Parent == Players then
				PlayerService.sync(player)
			end
		end
	end
end)

return PlayerService
