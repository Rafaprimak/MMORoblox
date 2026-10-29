-- Pets: chocar ovos (ouro, no Otto), equipar, soltar, XP por abate e bônus nos atributos.
-- O pet equipado vira atributos do jogador ("Pet", "PetLevel") e o cliente desenha o modelo.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Pets = require(Shared.Pets)
local NPCs = require(Shared.NPCs)
local Remotes = require(Shared.Remotes)
local Rarities = require(Shared.Rarities)

local DataService = require(script.Parent.DataService)
local PlayerService = require(script.Parent.PlayerService)

local PetService = {}

PetService.QuestHook = function(_player, _kind, _target, _amount) end

local rng = Random.new()

local function fail(msg)
	return { ok = false, msg = msg }
end

local function nearOtto(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local npc = NPCs.ById.otto
	if not root or not npc then
		return false
	end
	local dx, dz = root.Position.X - npc.x, root.Position.Z - npc.z
	return dx * dx + dz * dz < 45 * 45
end

local function count(data)
	local total = 0
	for _ in data.pets do
		total += 1
	end
	return total
end

local function applyAttributes(player, data)
	local entry = data.pet and data.pets[data.pet]
	player:SetAttribute("Pet", if entry then entry.id else nil)
	player:SetAttribute("PetLevel", if entry then entry.level else nil)
end

-- adiciona um pet novo (ovo ou drop) e avisa o jogador
function PetService.give(player, petId, source, force)
	local data = DataService.get(player)
	local def = Pets.List[petId]
	if not data or not def then
		return nil
	end
	if count(data) >= Pets.MaxOwned and not force then
		Remotes.Notify:FireClient(player, { kind = "message", text = "Você tem pets demais! Solte algum para ganhar outro." })
		return nil
	end
	local uid = HttpService:GenerateGUID(false)
	data.pets[uid] = { id = petId, level = 1, xp = 0 }
	if not data.pet then
		data.pet = uid
		applyAttributes(player, data)
		PlayerService.refreshCharacter(player, {})
	end
	local rarity = Rarities.ById[def.rarity]
	Remotes.Notify:FireClient(player, { kind = "pet", pet = petId, source = source })
	if rarity and rarity.order >= 5 then
		Remotes.Notify:FireAllClients({ kind = "announce", text = ("%s conseguiu o pet %s!"):format(player.DisplayName, def.name), rarity = def.rarity })
	end
	PetService.QuestHook(player, "pet", petId, 1)
	PlayerService.markDirty(player)
	return uid
end

function PetService.buyEgg(player, eggId)
	local data = DataService.get(player)
	local egg = type(eggId) == "string" and Pets.Eggs[eggId]
	if not data or not egg then
		return fail("Ovo inválido.")
	end
	if egg.robux then
		return fail("Esse ovo é comprado com Robux.")
	end
	if not nearOtto(player) then
		return fail("Ovos são vendidos pelo Otto, na vila.")
	end
	if count(data) >= Pets.MaxOwned then
		return fail("Você tem pets demais! Solte algum primeiro.")
	end
	if data.gold < egg.price then
		return fail(("Precisa de %d de ouro."):format(egg.price))
	end
	data.gold -= egg.price
	local petId = Pets.rollEgg(eggId, rng)
	local uid = PetService.give(player, petId, eggId)
	return { ok = true, pet = petId, uid = uid }
end

-- Ovo ganho de recompensa: vai para a bolsa de baús (data.chestBag["ovo_<id>"]) e choca quando o jogador quiser
function PetService.storeEgg(player, eggId)
	local data = DataService.get(player)
	local egg = Pets.Eggs[eggId]
	if not data or not egg then
		return
	end
	local key = "ovo_" .. eggId
	data.chestBag[key] = (data.chestBag[key] or 0) + 1
	Remotes.Notify:FireClient(player, { kind = "message", text = ("%s guardado! Choque quando quiser em Baús (B), aba Guardados."):format(egg.name) })
	PlayerService.markDirty(player)
end

-- Choca um ovo guardado na bolsa
function PetService.hatchStored(player, eggId)
	local data = DataService.get(player)
	local egg = type(eggId) == "string" and Pets.Eggs[eggId]
	if not data or not egg then
		return fail("Ovo inválido.")
	end
	local key = "ovo_" .. eggId
	if (data.chestBag[key] or 0) <= 0 then
		return fail("Você não tem esse ovo guardado.")
	end
	if count(data) >= Pets.MaxOwned then
		return fail("Você tem pets demais! Solte algum primeiro.")
	end
	data.chestBag[key] -= 1
	if data.chestBag[key] <= 0 then
		data.chestBag[key] = nil
	end
	local petId = Pets.rollEgg(eggId, rng)
	local uid = PetService.give(player, petId, eggId, true)
	return { ok = true, pet = petId, uid = uid }
end

-- Ovo pago com Robux: choca sempre (mesmo com o limite de pets cheio)
function PetService.grantEgg(player, eggId)
	if not Pets.Eggs[eggId] or not DataService.get(player) then
		return nil
	end
	local petId = Pets.rollEgg(eggId, rng)
	return PetService.give(player, petId, eggId, true)
end

function PetService.equip(player, uid)
	local data = DataService.get(player)
	if not data or (uid ~= "" and not (type(uid) == "string" and data.pets[uid])) then
		return fail("Pet não encontrado.")
	end
	data.pet = if uid == "" then nil else uid
	applyAttributes(player, data)
	PlayerService.refreshCharacter(player, {})
	PlayerService.markDirty(player)
	return { ok = true }
end

-- Soltar o pet devolve um pouco de ouro (pela raridade e nível)
function PetService.release(player, uid)
	local data = DataService.get(player)
	local entry = data and type(uid) == "string" and data.pets[uid]
	if not entry then
		return fail("Pet não encontrado.")
	end
	local def = Pets.List[entry.id]
	local rarity = def and Rarities.ById[def.rarity]
	local gold = math.floor(40 * (rarity and rarity.mult or 1) ^ 2 * (1 + 0.2 * (entry.level - 1)))
	data.pets[uid] = nil
	if data.pet == uid then
		data.pet = nil
		applyAttributes(player, data)
	end
	PlayerService.addGold(player, gold)
	PlayerService.refreshCharacter(player, {})
	PlayerService.markDirty(player)
	return { ok = true, gold = gold }
end

-- XP do pet equipado (por abate)
function PetService.addXP(player, amount)
	local data = DataService.get(player)
	local entry = data and data.pet and data.pets[data.pet]
	if not entry or entry.level >= Pets.MaxLevel then
		return
	end
	entry.xp += amount
	local leveled = false
	while entry.level < Pets.MaxLevel and entry.xp >= Pets.xpToNext(entry.level) do
		entry.xp -= Pets.xpToNext(entry.level)
		entry.level += 1
		leveled = true
	end
	if leveled then
		local def = Pets.List[entry.id]
		Remotes.Notify:FireClient(player, { kind = "banner", text = ("%s subiu para o nível %d!"):format(def.name, entry.level), sub = "Os bônus do pet ficaram mais fortes", color = Color3.fromRGB(150, 255, 200), duration = 3 })
		applyAttributes(player, data)
		PlayerService.refreshCharacter(player, {})
	end
	PlayerService.markDirty(player)
end

-- Drop raro de ovo: Elites (0,6%) e chefes (4%)
function PetService.rollDrop(player, rec)
	local chance = if rec.def.boss then 0.04 elseif rec.elite then 0.006 else 0
	if chance > 0 and rng:NextNumber() < chance then
		local eggId = if rec.def.boss then "raro" else "comum"
		PetService.give(player, Pets.rollEgg(eggId, rng), "drop")
	end
end

-- dados para a interface
function PetService.summary(data)
	local list = {}
	for uid, entry in data.pets do
		table.insert(list, { uid = uid, id = entry.id, level = entry.level, xp = entry.xp, xpNext = Pets.xpToNext(entry.level), equipped = data.pet == uid })
	end
	return list
end

function PetService.init()
	-- bônus do pet equipado entra nos atributos
	PlayerService.ExtraBonus = function(_player, data, bonus)
		local entry = data.pet and data.pets and data.pets[data.pet]
		if entry then
			PlayerService.addBonus(bonus, Pets.stats(entry.id, entry.level))
		end
	end
end

function PetService.onPlayerReady(player)
	local data = DataService.get(player)
	if data then
		applyAttributes(player, data)
	end
end

return PetService
