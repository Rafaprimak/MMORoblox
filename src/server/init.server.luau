-- Ponto de entrada do servidor: gera o mundo e liga todos os sistemas.
local Players = game:GetService("Players")
Players.CharacterAutoLoads = false -- os personagens só nascem quando o mundo estiver pronto

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local World = require(Shared.World)
local Items = require(Shared.Items)
local Enemies = require(Shared.Enemies)
local Remotes = require(Shared.Remotes)

local WorldGen = require(script.WorldGen)
local DataService = require(script.DataService)
local AntiCheat = require(script.AntiCheat)
local SkillService = require(script.SkillService)
local PlayerService = require(script.PlayerService)
local EnemyService = require(script.EnemyService)
local ProjectileService = require(script.ProjectileService)
local CombatService = require(script.CombatService)
local AbilityService = require(script.AbilityService)
local LootService = require(script.LootService)
local ResourceService = require(script.ResourceService)
local CraftingService = require(script.CraftingService)
local ShopService = require(script.ShopService)
local QuestService = require(script.QuestService)
local TravelService = require(script.TravelService)
local NPCService = require(script.NPCService)
local DayNightService = require(script.DayNightService)
local PerkService = require(script.PerkService)
local PetService = require(script.PetService)
local ProgressionService = require(script.ProgressionService)
local ExploreService = require(script.ExploreService)
local DungeonService = require(script.DungeonService)
local VipService = require(script.VipService)
local PlaytimeService = require(script.PlaytimeService)
local MonetizationService = require(script.MonetizationService)
local FusionService = require(script.FusionService)
local TradeService = require(script.TradeService)
local PartyService = require(script.PartyService)
local MarketService = require(script.MarketService)
local GuildService = require(script.GuildService)
local ChronicleService = require(script.ChronicleService)
local RaidService = require(script.RaidService)
local ArenaService = require(script.ArenaService)
local EventService = require(script.EventService)
local AdminService = require(script.AdminService)
local WorldEventService = require(script.WorldEventService)

workspace:SetAttribute("WorldReady", false)
workspace:SetAttribute("WorldStatus", "Preparando o mundo")
workspace:SetAttribute("WorldProgress", 0)

-- ===================== LIGAÇÕES ENTRE SISTEMAS =====================
-- todo evento de missão também conta para conquistas e Passe do Hunter
local function questHook(player, kind, target, amount)
	QuestService.event(player, kind, target, amount)
	ProgressionService.track(player, kind, target, amount)
	GuildService.track(player, kind, amount)
	ChronicleService.track(player, kind, target, amount)
end
QuestService.OnComplete = function(player, daily, def)
	ProgressionService.onQuestDone(player, daily)
	ChronicleService.onQuestDone(player, def)
end
PlayerService.QuestHook = questHook
PlayerService.QuestSummary = QuestService.summary
PlayerService.OnDamaged = TravelService.onDamaged
PlayerService.OnStarCore = function(player, position)
	for _, rec in EnemyService.inRadius(position, 14, nil, player) do
		EnemyService.damage(rec, 1, player, { perk = true, knockback = 16, stun = 1, fromPosition = position, element = "holy" })
	end
end
PlayerService.OnParry = function(player, source)
	if source then
		EnemyService.parried(source, player)
	end
	PerkService.onParry(player)
end
PlayerService.OnPerfectDodge = PerkService.onPerfectDodge
PlayerService.OnThorns = function(player, source, amount)
	if source and not source.dead then
		EnemyService.damage(source, amount, player, { perk = true, color = Color3.fromRGB(120, 200, 90) })
	end
end
CombatService.QuestHook = questHook
CombatService.BeforeAction = TravelService.dismount
AbilityService.QuestHook = questHook
CraftingService.QuestHook = questHook
ShopService.QuestHook = questHook
TravelService.QuestHook = questHook
NPCService.QuestHook = questHook
PetService.QuestHook = questHook
ExploreService.QuestHook = questHook
MarketService.QuestHook = questHook
GuildService.QuestHook = questHook
WorldEventService.QuestHook = questHook
RaidService.QuestHook = questHook
ArenaService.QuestHook = questHook
-- Arena PvP: os oponentes viram alvos do combate (ver EnemyService.Proxies)
EnemyService.Proxies = ArenaService.proxies
EnemyService.ProxyDamage = ArenaService.proxyDamage
EnemyService.ProxyDot = ArenaService.proxyDot
EnemyService.ProxyParried = ArenaService.proxyParried
AbilityService.IsAlly = ArenaService.isAlly
DungeonService.QuestHook = questHook
FusionService.QuestHook = questHook
PetService.init()
PlayerService.ExtraSync = function(player, payload)
	local data = DataService.get(player)
	if data then
		payload.pets = PetService.summary(data)
		payload.progress = ProgressionService.summary(player)
		payload.poi = data.poi
		payload.poiChests = data.poiChests
		payload.dungeon = DungeonService.summary(player)
		payload.playtime = PlaytimeService.summary(player)
		payload.trade = TradeService.summary(player)
		payload.party = PartyService.payload(player)
		payload.guild = GuildService.payload(player)
		payload.chronicle = ChronicleService.summary(player)
		payload.raid = RaidService.summary(player)
		payload.arena = ArenaService.summary(player)
		payload.event = EventService.summary(player)
		payload.poiSecrets = data.poiSecrets
	end
end
EnemyService.FireProjectile = ProjectileService.fire

SkillService.OnChanged = function(player, leveled)
	PlayerService.markDirty(player)
	if leveled then
		PlayerService.refreshCharacter(player, {})
		questHook(player, "mastery", nil, 0)
	end
end

EnemyService.OnHit = function(rec, player)
	questHook(player, "hit", rec.id, 1)
end

EnemyService.OnStagger = function(_rec, player)
	questHook(player, "stagger", nil, 1)
end

EnemyService.OnKilled = function(rec, contributors)
	local def = rec.def
	if rec.lastHitBy and rec.lastHitBy.Parent then
		PerkService.onKill(rec.lastHitBy, rec)
	end
	-- suportes que curaram/fortaleceram alguém nos últimos 12s e estão perto também ganham a recompensa
	for _, other in Players:GetPlayers() do
		local character = other.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not contributors[other] and root and (root.Position - rec.pos).Magnitude < 70 and PlayerService.recentlySupported(other, 12) then
			contributors[other] = 0
		end
	end
	-- grupo: colegas vivos perto do abate também ganham a recompensa (e o próprio loot)
	for player in table.clone(contributors) do
		for _, mate in PartyService.nearbyMembers(player, rec.pos) do
			if contributors[mate] == nil then
				contributors[mate] = 0
			end
		end
	end
	WorldEventService.onKilled(rec, contributors)
	RaidService.onKilled(rec)
	local night = DayNightService.isNight()
	local rewardMult = (if night then 1 + Config.NightRewardBonus else 1) * (rec.rewardMult or 1)
	for player in contributors do
		local bonus = PlayerService.getStats(player).bonus
		local playerData = DataService.get(player)
		local gapFactor = Config.xpLevelFactor(playerData and playerData.level or 1, rec.level)
		local xp = math.floor(def.xp * (if rec.elite then 3 else 1) * rewardMult * (1 + (bonus.xpGain or 0)) * gapFactor * PartyService.xpBonus(player, rec.pos))
		PlayerService.addXP(player, xp)
		local gold = math.floor(math.random(def.gold[1], def.gold[2]) * (if rec.elite then 3 else 1) * rewardMult * (1 + (bonus.goldFind or 0)))
		if gold > 0 then
			PlayerService.addGold(player, gold)
			Remotes.Fx:FireClient(player, "gold", EnemyService.centerOf(rec) + Vector3.new(0, rec.height / 2, 0), gold)
		end
		Remotes.Fx:FireClient(player, "xp", EnemyService.centerOf(rec) + Vector3.new(0, rec.height / 2 + 1.5, 0), xp)
		local data = DataService.get(player)
		if data then
			data.stats.kills += 1
		end
		local stats = PlayerService.getStats(player)
		SkillService.addXP(player, stats.masteryId, 8 + def.level)
		questHook(player, "kill", rec.id, 1)

		LootService.rollMaterials(player, def.drops, if rec.elite then 2 else 1)
		DungeonService.onEnemyKilled(player, rec)
		PetService.addXP(player, math.ceil(def.xp * 0.5) + 1)
		ProgressionService.onKill(player, rec)
		EventService.onKill(player)
		PetService.rollDrop(player, rec)
		-- Únicos: cada jogador que ajudou tem a sua chance (andar 20 das masmorras: dobro)
		if def.uniques and not rec.summoned then
			local chance = Enemies.UniqueChance * (if rec.camp and rec.camp.floor == 20 then 2 else 1)
			if math.random() < chance then
				local owner = DataService.get(player)
				local unique = Items.create(def.uniques[math.random(1, #def.uniques)], "Unico", math.max(rec.level, owner and owner.level or 1))
				LootService.spawnDrop(player, unique, rec.pos)
				Remotes.Notify:FireAllClients({ kind = "announce", text = ("%s encontrou um item ÚNICO: %s!"):format(player.DisplayName, Items.displayName(unique)), rarity = "Unico" })
			end
		end
		local rolls = (def.equipDrops or 1) + (if rec.elite then 1 else 0)
		for _ = 1, rolls do
			if math.random() <= def.dropChance * (if rec.elite then 3 else 1) * (if night then 1 + Config.NightDropBonus else 1) * (1 + (bonus.dropFind or 0)) then
				local minRarity = math.max(def.minRarity or 1, if rec.elite then 2 else 1)
				local item = Items.rollDrop(def.pool, rec.level, "weight", minRarity)
				LootService.spawnDrop(player, item, rec.pos)
			end
		end
	end
end

-- ===================== AÇÕES DO CLIENTE =====================
Remotes.Action.OnServerEvent:Connect(function(player, action, a, b, c)
	if typeof(action) ~= "string" or not DataService.get(player) or not AntiCheat.allow(player, "action") or not AntiCheat.validArgs(a, b, c) then
		return
	end
	if action == "attack" then
		CombatService.attack(player, a, b)
	elseif action == "heavyStart" then
		CombatService.heavyStart(player)
	elseif action == "heavy" then
		CombatService.heavyRelease(player, a)
	elseif action == "block" then
		CombatService.block(player, a == true)
	elseif action == "dodge" then
		CombatService.dodge(player)
	elseif action == "sprint" then
		PlayerService.setSprinting(player, a == true)
	elseif action == "ability" then
		AbilityService.cast(player, a, b, c)
	elseif action == "potion" then
		PlayerService.useConsumable(player, a)
	elseif action == "mount" then
		TravelService.toggleMount(player)
	elseif action == "talk" then
		if AntiCheat.nearNpc(player, a) then
			NPCService.talk(player, a)
		end
	end
end)

local function devGift(player, kind)
	if kind == "xp" then
		PlayerService.addXP(player, 5000)
	elseif kind == "gold" then
		PlayerService.addGold(player, 5000)
	elseif kind == "materials" then
		for id in Items.Materials do
			PlayerService.addMaterial(player, id, 10, true)
		end
		for id in Items.Consumables do
			PlayerService.addConsumable(player, id, 5, true)
		end
	elseif kind == "night" then
		DayNightService.skip()
	elseif kind == "worldboss" then
		WorldEventService.forceBoss()
	elseif kind == "invasion" then
		WorldEventService.forceInvasion()
	elseif kind == "event" then
		local event = EventService.cycle()
		Remotes.Notify:FireClient(player, { kind = "message", text = if event then "Evento forçado: " .. event.name else "Evento pelo calendário de novo." })
	elseif kind == "skills" then
		for _, id in { "mineracao", "herbalismo", "lenhador", "ferraria", "alquimia", "encantamento" } do
			SkillService.addXP(player, id, 3000)
		end
		local stats = PlayerService.getStats(player)
		SkillService.addXP(player, stats.masteryId, 3000)
	end
	PlayerService.markDirty(player)
	return { ok = true }
end

Remotes.Request.OnServerInvoke = function(player, action, a, b)
	if not AntiCheat.allow(player, "request") then
		return { ok = false, msg = "Calma! Muitos pedidos seguidos." }
	end
	if typeof(action) ~= "string" or not DataService.get(player) or not AntiCheat.validArgs(a, b) then
		return { ok = false }
	end
	-- serviços de NPC só funcionam perto dele
	local service = AntiCheat.ServiceActions[action]
	if service and not AntiCheat.nearService(player, service) then
		return { ok = false, msg = "Chegue mais perto do NPC para usar este serviço." }
	end
	if action == "sync" then
		PlayerService.markDirty(player)
		return { ok = true }
	elseif action == "equip" then
		return PlayerService.equip(player, a)
	elseif action == "sell" then
		return PlayerService.sell(player, a)
	elseif action == "sellJunk" then
		return PlayerService.sellJunk(player)
	elseif action == "chooseClass" then
		return PlayerService.chooseClass(player, a)
	elseif action == "rankAbility" then
		return PlayerService.rankAbility(player, a)
	elseif action == "setLoadout" then
		return PlayerService.setLoadout(player, a, b)
	elseif action == "learnTalent" then
		return PlayerService.learnTalent(player, a)
	elseif action == "respec" then
		return PlayerService.respec(player)
	elseif action == "forge" then
		return CraftingService.forge(player, a)
	elseif action == "upgrade" then
		return CraftingService.upgrade(player, a)
	elseif action == "reforge" then
		return CraftingService.reforge(player, a)
	elseif action == "claimLogin" then
		return ProgressionService.claimLogin(player)
	elseif action == "claimPass" then
		return ProgressionService.claimPass(player)
	elseif action == "setTitle" then
		return ProgressionService.setTitle(player, a)
	elseif action == "buyEgg" then
		return PetService.buyEgg(player, a)
	elseif action == "equipPet" then
		return PetService.equip(player, a)
	elseif action == "releasePet" then
		return PetService.release(player, a)
	elseif action == "enchant" then
		return CraftingService.enchant(player, a)
	elseif action == "disassemble" then
		return CraftingService.disassemble(player, a)
	elseif action == "alchemy" then
		return CraftingService.alchemy(player, a)
	elseif action == "buy" then
		return CraftingService.buy(player, a, b)
	elseif action == "sellMaterial" then
		return CraftingService.sellMaterial(player, a, b)
	elseif action == "openChest" then
		return ShopService.open(player, a)
	elseif action == "acceptQuest" then
		return QuestService.accept(player, a)
	elseif action == "turnInQuest" then
		return QuestService.turnIn(player, a)
	elseif action == "abandonQuest" then
		return QuestService.abandon(player, a)
	elseif action == "trackQuest" then
		return QuestService.track(player, a)
	elseif action == "travel" then
		return TravelService.travel(player, a)
	elseif action == "buyMount" then
		return TravelService.buyMount(player)
	elseif action == "settings" then
		return PlayerService.saveSettings(player, a)
	elseif action == "dungeonJoin" then
		return DungeonService.join(player, a)
	elseif action == "dungeonLeaveLobby" then
		return DungeonService.leaveLobby(player)
	elseif action == "fuse" then
		return FusionService.fuse(player, a)
	elseif action == "tradeInvite" then
		return TradeService.invite(player, a)
	elseif action == "tradeRespond" then
		return TradeService.respond(player, a, b)
	elseif action == "tradeOffer" then
		return TradeService.setOffer(player, a)
	elseif action == "tradeReady" then
		return TradeService.setReady(player, a)
	elseif action == "tradeConfirm" then
		return TradeService.confirm(player)
	elseif action == "tradeCancel" then
		return TradeService.cancel(player)
	elseif action == "partyInvite" then
		return PartyService.invite(player, a)
	elseif action == "partyRespond" then
		return PartyService.respond(player, a, b)
	elseif action == "partyLeave" then
		return PartyService.leave(player)
	elseif action == "partyKick" then
		return PartyService.kick(player, a)
	elseif action == "partyLooking" then
		return PartyService.setLooking(player, a, b)
	elseif action == "partyList" then
		return PartyService.lookingList(player)
	elseif action == "marketSell" then
		return MarketService.sell(player, a, b)
	elseif action == "marketBuy" then
		return MarketService.buy(player, a)
	elseif action == "marketCancel" then
		return MarketService.cancel(player, a)
	elseif action == "marketBrowse" then
		return MarketService.browse(player, a)
	elseif action == "marketMine" then
		return MarketService.mine(player)
	elseif action == "guildCreate" then
		local form = if type(a) == "table" then a else {}
		return GuildService.create(player, form.name, form.tag, form.icon)
	elseif action == "guildInvite" then
		return GuildService.invite(player, a)
	elseif action == "guildRespond" then
		return GuildService.respond(player, a)
	elseif action == "guildLeave" then
		return GuildService.leave(player)
	elseif action == "guildKick" then
		return GuildService.kick(player, a)
	elseif action == "guildRank" then
		return GuildService.setRank(player, a, b)
	elseif action == "guildBank" then
		return GuildService.bank(player, a, b)
	elseif action == "guildClaim" then
		return GuildService.claim(player, a)
	elseif action == "guildChat" then
		return GuildService.chat(player, a)
	elseif action == "guildRanking" then
		return GuildService.ranking(player)
	elseif action == "dungeonRanking" then
		return DungeonService.ranking(player, a)
	elseif action == "raidJoin" then
		return RaidService.join(player)
	elseif action == "raidLeave" then
		return RaidService.leave(player)
	elseif action == "raidReady" then
		return RaidService.setReady(player, a)
	elseif action == "raidExit" then
		return RaidService.exit(player)
	elseif action == "arenaJoin" then
		return ArenaService.join(player, a)
	elseif action == "arenaLeave" then
		return ArenaService.leaveQueue(player)
	elseif action == "arenaForfeit" then
		return ArenaService.forfeit(player)
	elseif action == "arenaRanking" then
		return ArenaService.ranking(player)
	elseif action == "admin" then
		return AdminService.handle(player, a, b)
	elseif action == "claimPlaytime" then
		return PlaytimeService.claim(player, a)
	elseif action == "autoFarm" then
		return VipService.setAutoFarm(player, a, b)
	elseif action == "afkRejoin" then
		return VipService.afkRejoin(player)
	elseif action == "devPremium" then
		return MonetizationService.devGrant(player, a)
	elseif action == "dungeonReady" then
		return DungeonService.setReady(player, a)
	elseif action == "dungeonExit" then
		return DungeonService.leave(player, true)
	elseif action == "dungeonBuy" then
		return DungeonService.buy(player, a)
	elseif action == "dungeonBuyLoot" then
		return DungeonService.buyLoot(player, a)
	elseif action == "tutorial" then
		return PlayerService.tutorial(player, a)
	elseif action == "dev" and RunService:IsStudio() then
		return devGift(player, a)
	end
	return { ok = false, msg = "Ação inválida." }
end

-- ===================== JOGADORES =====================
local worldReady = false

local function spawnCharacter(player)
	if player.Parent ~= Players then
		return
	end
	player:LoadCharacter()
end

local function onPlayerAdded(player)
	if AdminService.checkBan(player) then
		return
	end
	local data = PlayerService.onPlayerAdded(player)
	if not data then
		return
	end
	QuestService.setup(player)
	MarketService.onProfileLoaded(player)
	GuildService.onPlayerReady(player)
	VipService.onPlayerAdded(player)
	PlaytimeService.onPlayerAdded(player)
	PetService.onPlayerReady(player)
	ProgressionService.onPlayerReady(player)
	EventService.onPlayerReady(player)
	AdminService.onPlayerReady(player)
	player.CharacterAdded:Connect(function(character)
		-- StreamingEnabled: personagens sempre presentes em todos os clientes (auras, pets, grupo, troca
		-- e animações dependem do CharacterAdded; são poucos modelos, o custo é pequeno)
		pcall(function()
			character.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
		end)
		player:SetAttribute("Mounted", false)
		AntiCheat.onCharacterAdded(player)
		DungeonService.onCharacterAdded(player, character)
		RaidService.onCharacterAdded(player, character)
		ArenaService.onCharacterAdded(player, character)
		VipService.onCharacterAdded(player, character)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid then
			humanoid.Died:Connect(function()
				TravelService.dismount(player)
				task.delay(4, spawnCharacter, player)
			end)
		end
	end)
	while not worldReady do
		task.wait(0.25)
	end
	spawnCharacter(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	TradeService.onPlayerRemoving(player)
	PartyService.onPlayerRemoving(player)
	MarketService.onPlayerRemoving(player)
	GuildService.onPlayerRemoving(player)
	RaidService.onPlayerRemoving(player)
	ArenaService.onPlayerRemoving(player)
	PlaytimeService.onPlayerRemoving(player)
	DungeonService.onPlayerRemoving(player)
	TravelService.dismount(player)
	PlayerService.onPlayerRemoving(player)
	DataService.release(player)
end)

task.spawn(function()
	while true do
		task.wait(Config.AutosaveInterval)
		DataService.saveAll()
	end
end)

-- servidor fechando: grava e solta todos os perfis (e espera terminar)
game:BindToClose(function()
	DataService.releaseAll()
end)

-- ===================== MUNDO =====================
local built = WorldGen.build(function(status, fraction)
	workspace:SetAttribute("WorldStatus", status)
	workspace:SetAttribute("WorldProgress", fraction)
end)

local spawn = Instance.new("SpawnLocation")
spawn.Name = "Spawn"
spawn.Anchored = true
spawn.Neutral = true
spawn.Duration = 0
spawn.CanCollide = false
spawn.Transparency = 1
spawn.Size = Vector3.new(6, 1, 6)
spawn.CFrame = CFrame.new(World.TownCenter.X, World.TownHeight + 0.5, World.TownCenter.Z + 16 * World.PropScale)
spawn.Parent = workspace

-- Cada etapa roda protegida e com tempo-limite: um serviço que trava (DataStore/MessagingService fora
-- do ar, Studio sem publicar) não pode impedir o mundo de abrir. Etapas que não esperam nada terminam
-- na hora, então a ordem continua a mesma.
local function safely(name, fn, ...)
	local args = table.pack(...)
	local done = false
	task.spawn(function()
		local ok, err = pcall(fn, table.unpack(args, 1, args.n))
		if not ok then
			warn(("[Servidor] Falha em %s: %s"):format(name, tostring(err)))
		end
		done = true
	end)
	local started = os.clock()
	while not done do
		if os.clock() - started > 10 then
			warn(("[Servidor] %s está demorando demais; o jogo segue sem esperar."):format(name))
			return
		end
		task.wait()
	end
end
safely("NPCs", NPCService.spawn, built.board)
safely("Recursos", ResourceService.init)
safely("Projéteis", ProjectileService.start)
safely("Dia e noite", DayNightService.start)
safely("Inimigos", EnemyService.start)
safely("Viagem", TravelService.init, built.horse)
safely("Locais de interesse", ExploreService.start)
safely("Masmorras", DungeonService.init)
safely("Robux", MonetizationService.init)
safely("Anti-trapaça", AntiCheat.start)
safely("Eventos do mundo", WorldEventService.start)
safely("Mercado", MarketService.start)
safely("Guildas", GuildService.start)
safely("Raide", RaidService.init)
safely("Arena", ArenaService.init)
safely("Eventos sazonais", EventService.start)
safely("Admin", AdminService.start)

-- StreamingEnabled: cada árvore/pedra chega inteira no cliente (e o DetailCulling trata o modelo todo)
pcall(function()
	local nature = workspace:FindFirstChild("Mundo") and workspace.Mundo:FindFirstChild("Natureza")
	if nature then
		for _, child in nature:GetChildren() do
			if child:IsA("Model") then
				child.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
			end
		end
	end
end)

worldReady = true
workspace:SetAttribute("WorldReady", true)
print("[Servidor] Mundo pronto!")
