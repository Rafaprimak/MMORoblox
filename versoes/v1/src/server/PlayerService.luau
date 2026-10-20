-- Progressão do jogador: XP, níveis, ouro, inventário, equipamento e visual da armadura.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Rarities = require(Shared.Rarities)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local CombatService = require(script.Parent.CombatService)

local PlayerService = {}

-- Ganchos preenchidos pelo init (evita dependência circular com o QuestService)
PlayerService.QuestHook = function(_player, _kind, _target, _amount) end
PlayerService.QuestSummary = function(_player)
	return nil
end

local dirty = {}

function PlayerService.markDirty(player)
	dirty[player] = true
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

function PlayerService.getAttack(player)
	local data = DataService.get(player)
	if not data then
		return Config.BaseAttack
	end
	local weapon = PlayerService.getEquipped(player, "weapon")
	return Config.BaseAttack + data.level * Config.AttackPerLevel + (if weapon then Items.getPower(weapon) else 0)
end

function PlayerService.getMaxHealth(player)
	local data = DataService.get(player)
	if not data then
		return Config.BaseHealth
	end
	local armor = PlayerService.getEquipped(player, "armor")
	return Config.BaseHealth + data.level * Config.HealthPerLevel + (if armor then Items.getPower(armor) else 0)
end

CombatService.AttackProvider = PlayerService.getAttack
CombatService.WeaponProvider = function(player)
	return PlayerService.getEquipped(player, "weapon")
end

-- Peitoral blocado na cor da raridade
local function applyArmorVisual(character, item)
	local old = character:FindFirstChild("ArmaduraVisual")
	if old then
		old:Destroy()
	end
	if not item then
		return
	end
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if not torso then
		return
	end
	local rarity = Rarities.ById[item.rarity] or Rarities.List[1]
	local model = Instance.new("Model")
	model.Name = "ArmaduraVisual"

	local function plate(size, offset, color, material)
		local p = Instance.new("Part")
		p.Size = size
		p.CFrame = torso.CFrame * offset
		p.Color = color
		p.Material = material
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = torso
		weld.Part1 = p
		weld.Parent = p
		if rarity.rainbow and material == Enum.Material.Neon then
			CollectionService:AddTag(p, "Rainbow")
		end
		return p
	end

	local s = torso.Size
	local accentMaterial = if rarity.order >= 4 then Enum.Material.Neon else Enum.Material.Metal
	plate(s + Vector3.new(0.2, 0.05, 0.2), CFrame.new(), Color3.fromRGB(70, 70, 80), Enum.Material.Metal)
	plate(Vector3.new(s.X * 0.6, s.Y * 0.5, 0.15), CFrame.new(0, 0.1, -(s.Z / 2 + 0.15)), rarity.color, accentMaterial)
	if rarity.order >= 3 then
		for _, side in { -1, 1 } do
			plate(Vector3.new(1.0, 0.4, 1.3), CFrame.new(side * (s.X / 2 + 0.25), s.Y / 2 - 0.05, 0), rarity.color, accentMaterial)
		end
	end
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
	local maxHealth = PlayerService.getMaxHealth(player)
	local ratio = humanoid.Health / math.max(humanoid.MaxHealth, 1)
	humanoid.MaxHealth = maxHealth
	humanoid.Health = if options.heal then maxHealth else math.clamp(maxHealth * ratio, 1, maxHealth)
	if options.weapon then
		CombatService.giveWeapon(player, PlayerService.getEquipped(player, "weapon"))
	end
	if options.armor then
		applyArmorVisual(character, PlayerService.getEquipped(player, "armor"))
	end
end

local function updateLeaderstats(player, data)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return
	end
	leaderstats.Rank.Value = Config.getRank(data.level).name
	leaderstats["Nível"].Value = data.level
end

local function setupLeaderstats(player, data)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local rank = Instance.new("StringValue")
	rank.Name = "Rank"
	rank.Parent = leaderstats
	local level = Instance.new("IntValue")
	level.Name = "Nível"
	level.Parent = leaderstats
	leaderstats.Parent = player
	updateLeaderstats(player, data)
end

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
		leveled = true
	end
	if data.level >= Config.MaxLevel then
		data.xp = 0
	end
	if leveled then
		Remotes.Notify:FireClient(player, { kind = "levelup", level = data.level })
		local newRank = Config.getRank(data.level)
		if newRank.name ~= oldRank.name then
			Remotes.Notify:FireClient(player, { kind = "rankup", rank = newRank.name })
			Remotes.Notify:FireAllClients({ kind = "announce", text = ("⭐ %s alcançou o Rank %s!"):format(player.DisplayName, newRank.name), color = newRank.color })
		end
		PlayerService.refreshCharacter(player, { heal = true })
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

function PlayerService.addKill(player)
	local data = DataService.get(player)
	if data then
		data.stats.kills += 1
	end
end

-- options.silent = true: não mostra o popup de loot (usado pelo baú, que tem a própria animação)
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
		task.delay(if options.silent then 3.5 else 0.5, function()
			Remotes.Notify:FireAllClients(announcement)
		end)
	end

	-- equipa automaticamente se o slot estiver vazio
	if base and not data.equipped[base.slot] then
		data.equipped[base.slot] = item.uid
		PlayerService.refreshCharacter(player, { weapon = base.slot == "weapon", armor = base.slot == "armor" })
	end

	PlayerService.QuestHook(player, "rarity", nil, 0)
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
	PlayerService.refreshCharacter(player, { weapon = base.slot == "weapon", armor = base.slot == "armor" })
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
		if rarity and rarity.order <= 2 and not isEquipped(data, uid) then
			total += Items.getSellValue(item)
			count += 1
			data.inventory[uid] = nil
		end
	end
	data.gold += total
	PlayerService.markDirty(player)
	return { ok = true, count = count, gold = total }
end

function PlayerService.upgrade(player, uid)
	local data = DataService.get(player)
	if not data or typeof(uid) ~= "string" then
		return { ok = false }
	end
	local item = data.inventory[uid]
	if not item then
		return { ok = false, msg = "Item não encontrado." }
	end
	if item.upgrade >= Items.MaxUpgrade then
		return { ok = false, msg = "Este item já está no nível máximo!" }
	end
	local cost = Items.getUpgradeCost(item)
	if data.gold < cost then
		return { ok = false, msg = ("Ouro insuficiente! Precisa de %d."):format(cost) }
	end
	data.gold -= cost
	item.upgrade += 1
	PlayerService.refreshCharacter(player, { weapon = data.equipped.weapon == uid })
	PlayerService.QuestHook(player, "upgrade", nil, 1)
	PlayerService.markDirty(player)
	return { ok = true, upgrade = item.upgrade }
end

function PlayerService.sync(player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local inventory = {}
	for uid, item in data.inventory do
		table.insert(inventory, Items.describe(item, isEquipped(data, uid)))
	end
	Remotes.DataUpdate:FireClient(player, {
		level = data.level,
		xp = data.xp,
		xpNext = Config.xpToNext(data.level),
		gold = data.gold,
		attack = PlayerService.getAttack(player),
		maxHealth = PlayerService.getMaxHealth(player),
		inventory = inventory,
		maxInventory = Config.MaxInventory,
		chestCost = Config.ChestCost,
		quests = PlayerService.QuestSummary(player),
		isStudio = RunService:IsStudio(),
	})
end

local function onCharacterAdded(player, character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end
	character:WaitForChild("HumanoidRootPart", 10)
	if not (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")) then
		character:WaitForChild("UpperTorso", 3)
	end
	if player.Character ~= character then
		return
	end
	PlayerService.refreshCharacter(player, { heal = true, weapon = true, armor = true })
end

function PlayerService.onPlayerAdded(player)
	local data = DataService.load(player)
	if not player.Parent then
		return
	end

	-- jogador novo: ganha a espada de treino
	if next(data.inventory) == nil then
		local sword = Items.create("espada_treino", "Comum", 1)
		data.inventory[sword.uid] = sword
		data.equipped.weapon = sword.uid
	end
	for slot, uid in data.equipped do
		if not data.inventory[uid] then
			data.equipped[slot] = nil
		end
	end

	setupLeaderstats(player, data)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
	PlayerService.markDirty(player)
end

function PlayerService.onPlayerRemoving(player)
	dirty[player] = nil
	CombatService.release(player)
end

-- Envia o estado para o cliente no máximo ~7x por segundo (agrupa várias mudanças)
task.spawn(function()
	while true do
		task.wait(0.15)
		for player in dirty do
			dirty[player] = nil
			if player.Parent == Players then
				PlayerService.sync(player)
			end
		end
	end
end)

return PlayerService
