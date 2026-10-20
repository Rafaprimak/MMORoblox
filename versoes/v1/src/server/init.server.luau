-- Ponto de entrada do servidor: monta o mundo e liga todos os sistemas.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Remotes = require(Shared.Remotes)

local MapBuilder = require(script.MapBuilder)
local DataService = require(script.DataService)
local PlayerService = require(script.PlayerService)
local QuestService = require(script.QuestService)
local EnemyService = require(script.EnemyService)
local LootService = require(script.LootService)
local ShopService = require(script.ShopService)

local function setupLighting()
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.2
	Lighting.Ambient = Color3.fromRGB(60, 60, 75)
	Lighting.OutdoorAmbient = Color3.fromRGB(130, 130, 150)
	for _, child in Lighting:GetChildren() do
		if child:IsA("PostEffect") or child:IsA("Atmosphere") then
			child:Destroy()
		end
	end
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(200, 190, 230)
	atmosphere.Decay = Color3.fromRGB(110, 90, 160)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1.2
	atmosphere.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.6
	bloom.Size = 24
	bloom.Threshold = 1.1
	bloom.Parent = Lighting
	local color = Instance.new("ColorCorrectionEffect")
	color.Saturation = 0.15
	color.Contrast = 0.05
	color.Parent = Lighting
end

setupLighting()
local map = MapBuilder.build()

-- Ligações entre sistemas
PlayerService.QuestHook = QuestService.track
PlayerService.QuestSummary = QuestService.summary

EnemyService.OnKilled = function(rec, contributors)
	local def = rec.def
	for player in contributors do
		PlayerService.addXP(player, def.xp)
		local gold = math.random(def.gold[1], def.gold[2])
		PlayerService.addGold(player, gold)
		Remotes.Fx:FireClient(player, "gold", rec.position + Vector3.new(0, rec.height, 0), gold)
		PlayerService.addKill(player)
		QuestService.track(player, "kill", rec.defId, 1)

		-- cada jogador que ajudou rola o próprio loot
		for _ = 1, def.drops or 1 do
			if math.random() <= def.dropChance then
				local item = Items.rollDrop(def.pool, def.level, "weight", def.minRarity)
				LootService.spawnDrop(player, item, rec.position)
			end
		end
	end
end
EnemyService.start()

-- Portais
local portalCooldown = {}
local function connectPortal(portal, onEnter)
	portal.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player or portalCooldown[player] then
			return
		end
		portalCooldown[player] = true
		task.delay(1.5, function()
			portalCooldown[player] = nil
		end)
		onEnter(player, character)
	end)
end

connectPortal(map.portalIn, function(player, character)
	local data = DataService.get(player)
	if data and data.level >= Config.PortalLevel then
		character:PivotTo(CFrame.new(Config.ArenaSpawn))
		Remotes.Notify:FireClient(player, { kind = "banner", text = "👑 COVIL DO REI GOBLIN", sub = "Desvie dos círculos vermelhos!", color = Color3.fromRGB(255, 80, 80) })
	else
		Remotes.Notify:FireClient(player, { kind = "message", text = ("O portal exige Nível %d!"):format(Config.PortalLevel) })
	end
end)

connectPortal(map.portalOut, function(_player, character)
	character:PivotTo(CFrame.new(Config.HubSpawn))
end)

-- Pedidos do cliente
Remotes.Request.OnServerInvoke = function(player, action, arg)
	if typeof(action) ~= "string" then
		return { ok = false }
	end
	if action == "sync" then
		PlayerService.markDirty(player)
		return { ok = true }
	elseif action == "equip" then
		return PlayerService.equip(player, arg)
	elseif action == "sell" then
		return PlayerService.sell(player, arg)
	elseif action == "sellJunk" then
		return PlayerService.sellJunk(player)
	elseif action == "upgrade" then
		return PlayerService.upgrade(player, arg)
	elseif action == "openChest" then
		return ShopService.openChest(player)
	elseif action == "dev" and RunService:IsStudio() then
		-- botões de teste: só funcionam dentro do Roblox Studio
		if arg == "xp" then
			PlayerService.addXP(player, 5000)
		elseif arg == "gold" then
			PlayerService.addGold(player, 5000)
		end
		return { ok = true }
	end
	return { ok = false, msg = "Ação inválida." }
end

-- Entrada e saída de jogadores
local function onPlayerAdded(player)
	PlayerService.onPlayerAdded(player)
	if player.Parent then
		QuestService.setup(player)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	PlayerService.onPlayerRemoving(player)
	QuestService.release(player)
	DataService.release(player)
	portalCooldown[player] = nil
end)

task.spawn(function()
	while true do
		task.wait(Config.AutosaveInterval)
		DataService.saveAll()
	end
end)

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		DataService.save(player)
	end
end)
