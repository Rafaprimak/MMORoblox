-- Ponto de entrada do cliente: monta a interface e liga os eventos do servidor.
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local Loading = require(script.Loading)
Loading.init()

local UI = require(script.UI)
local State = require(script.State)
local Window = require(script.Window)
local Fx = require(script.Fx)
local Popups = require(script.Popups)
local Animator = require(script.Animator)
local EnemyRenderer = require(script.EnemyRenderer)
local Controller = require(script.Controller)
local HUD = require(script.HUD)
local Inventory = require(script.Inventory)
local Character = require(script.Character)
local QuestLog = require(script.QuestLog)
local Dialog = require(script.Dialog)
local Services = require(script.Services)
local Chest = require(script.Chest)
local MapWindow = require(script.MapWindow)
local ClassSelect = require(script.ClassSelect)
local WorldMarkers = require(script.WorldMarkers)
local Prefs = require(script.Prefs)
local Sky = require(script.Sky)
local Auras = require(script.Auras)
local SettingsWindow = require(script.SettingsWindow)
local Tutorial = require(script.Tutorial)
local LockOn = require(script.LockOn)
local PetRenderer = require(script.PetRenderer)
local PetsWindow = require(script.PetsWindow)
local JourneyWindow = require(script.JourneyWindow)
local Ambience = require(script.Ambience)
local TownLife = require(script.TownLife)
local Juice = require(script.Juice)
local DungeonWindow = require(script.DungeonWindow)
local DetailCulling = require(script.DetailCulling)
local Sounds = require(script.Sounds)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
end)

local screen = UI.new("ScreenGui", { Name = "HunterHUD", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = playerGui })

State.onError = function(text)
	Popups.message(text)
end

Fx.init(screen)
Popups.init(screen)
Animator.init()
EnemyRenderer.init()
Inventory.init(screen)
Character.init(screen)
QuestLog.init(screen)
Dialog.init(screen)
Services.init(screen)
Chest.init(screen)
MapWindow.init(screen)
SettingsWindow.init(screen)
PetsWindow.init(screen)
JourneyWindow.init(screen)
DungeonWindow.init(screen)
PetRenderer.init()
ClassSelect.init()
Sky.init()
Sounds.preload()
Ambience.init()
TownLife.init()
Juice.init()
DetailCulling.init()
Auras.init()

local function toggleInventory()
	Inventory.toggle()
	Tutorial.event("inventory")
end
local function toggleMap()
	MapWindow.toggle()
	Tutorial.event("map")
end

HUD.init(screen, {
	onInventory = toggleInventory,
	onCharacter = Character.toggle,
	onQuests = QuestLog.toggle,
	onMap = toggleMap,
	onChest = Chest.toggle,
	onSettings = SettingsWindow.toggle,
	onPets = PetsWindow.toggle,
	onJourney = JourneyWindow.toggle,
	onAbility = function(slot)
		local aim, point = Controller.getAim()
		State.action("ability", slot, aim, point)
	end,
})
WorldMarkers.init()
Tutorial.init(screen)
SettingsWindow.onRestartTutorial = Tutorial.restart
Tutorial.onFinished = function()
	Popups.banner("🎓 Tutorial concluído!", "Agora é com você, Hunter. Boa caçada!", UI.Colors.Gold, 4)
end

Controller.isBlocked = function()
	return Window.anyOpen() or ClassSelect.isOpen()
end
Controller.onNoStamina = function()
	HUD.flashStamina()
	Popups.message("Sem estamina!", UI.Colors.Stamina)
end
Controller.onAttack = function(duration)
	if Prefs.get("rhythmBar") then
		HUD.showAttackCue(duration)
	end
end
Controller.onFumble = function()
	HUD.flashFumble()
	Fx.fumble()
end
Controller.onCharge = HUD.setCharge
Controller.onEvent = Tutorial.event
Controller.init()
LockOn.init()

Services.openChest = Chest.open
Dialog.services = {
	forge = function()
		Services.open("forge")
	end,
	enchant = function()
		Services.open("enchant")
	end,
	alchemy = function()
		Services.open("alchemy")
	end,
	shop = function()
		Services.open("shop")
	end,
	stable = function()
		Services.open("stable")
	end,
	chest = Chest.open,
	pets = PetsWindow.openEggs,
	dungeon = DungeonWindow.openShop,
	classes = function()
		Window.closeAll()
		ClassSelect.open(true)
	end,
}

-- ===================== EVENTOS DO SERVIDOR =====================

Remotes.DataUpdate.OnClientEvent:Connect(function(data)
	Prefs.load(data.settings)
	State.set(data)
	HUD.update(data)
	if data.class == nil and not ClassSelect.isOpen() then
		ClassSelect.open(false)
	end
end)

Remotes.Notify.OnClientEvent:Connect(function(notification)
	if notification.kind == "chest" then
		Chest.reveal(notification.item, notification.chest)
	elseif notification.kind == "dungeonPortal" then
		DungeonWindow.openPortal(notification.id)
	elseif notification.kind == "pet" then
		PetsWindow.announce(notification)
	elseif notification.kind == "passTier" or notification.kind == "achievement" or notification.kind == "reward" then
		JourneyWindow.notify(notification)
	else
		Popups.handle(notification)
	end
end)

local FX_HANDLERS = {
	hit = function(root, amount, crit, attacker, ...)
		Fx.hit(root, amount, crit, attacker, ...)
		if attacker == player then
			Ambience.combatPing()
		end
	end,
	death = Fx.death,
	gold = Fx.gold,
	xp = Fx.xp,
	hurt = function(amount, source)
		Fx.hurt(amount, source)
		Ambience.combatPing()
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		Animator.flinch(player.Character, if humanoid then 0.4 + (amount or 0) / math.max(humanoid.MaxHealth, 1) * 4 else 1)
	end,
	evaded = Fx.evaded,
	telegraph = Fx.telegraph,
	explosion = Fx.explosion,
	projectile = Fx.projectile,
	projectileEnd = Fx.projectileEnd,
	rain = Fx.rain,
	meteor = Fx.meteor,
	blink = Fx.blink,
	gather = Fx.gather,
	drop = Fx.drop,
	potion = Fx.potion,
	potionCooldown = HUD.setPotionCooldown,
	buff = HUD.addBuff,
	selfDash = Controller.dash,
	selfJump = Controller.jump,
	cooldown = function(slot, duration)
		HUD.setCooldown(slot, duration)
		Controller.setCooldown(slot, duration)
	end,
	swing = function(who, pose, duration)
		if who ~= player then
			Animator.playForPlayer(who, pose, duration, true)
		end
	end,
	cast = function(who, _abilityId, pose)
		if who == player then
			Controller.cast(_abilityId, pose)
		else
			Animator.playForPlayer(who, pose, 0.6, true)
		end
	end,
	dodge = function(who)
		if who ~= player then
			Animator.playForPlayer(who, "dodge", 0.35)
		end
	end,
	noStamina = function()
		HUD.flashStamina()
		Popups.message("Sem estamina!", UI.Colors.Stamina)
	end,
	exhausted = HUD.flashStamina,
	noMana = function()
		Popups.message("Sem mana!", UI.Colors.Mana)
	end,
	-- suporte e tanque
	heal = Fx.heal,
	sanctuary = Fx.sanctuary,
	taunted = Fx.taunted,
	chain = Fx.chain,
	-- combate dinâmico
	parry = Fx.parry,
	blocked = Fx.blocked,
	perfectDodge = Fx.perfectDodge,
	rhythm = function(...)
		Fx.rhythm(...)
		Tutorial.event("rhythm")
	end,
	stagger = Fx.stagger,
	guardBreak = function()
		Fx.guardBreak()
		Controller.forceStopBlock()
	end,
	block = function(who, on)
		if who ~= player then
			if on then
				Animator.holdForPlayer(who, "block")
			else
				Animator.stopForPlayer(who)
			end
		end
	end,
	charge = function(who, on)
		if who ~= player then
			if on then
				Animator.holdForPlayer(who, "charge")
			else
				Animator.stopForPlayer(who)
			end
		end
	end,
}

Remotes.Fx.OnClientEvent:Connect(function(kind, ...)
	local handler = FX_HANDLERS[kind]
	if handler then
		local ok, err = pcall(handler, ...)
		if not ok then
			warn("[Fx] " .. tostring(kind) .. ": " .. tostring(err))
		end
	end
end)

-- ===================== TECLAS E INTERAÇÕES =====================

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	local key = input.KeyCode
	if key == Enum.KeyCode.C then
		Character.toggle()
	elseif key == Enum.KeyCode.J then
		QuestLog.toggle()
	elseif key == Enum.KeyCode.M then
		toggleMap()
	elseif key == Enum.KeyCode.P then
		SettingsWindow.toggle()
	elseif key == Enum.KeyCode.G then
		PetsWindow.toggle()
	elseif key == Enum.KeyCode.K then
		JourneyWindow.toggle()
	elseif key == Enum.KeyCode.B then
		Chest.toggle()
	end
end)

-- O Roblox usa I/O para zoom da câmera; esta ligação tem prioridade maior e "engole" a tecla I
ContextActionService:BindActionAtPriority("AbrirInventario", function(_, inputState)
	if inputState == Enum.UserInputState.Begin and not UserInputService:GetFocusedTextBox() then
		toggleInventory()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.ContextActionPriority.High.Value + 10, Enum.KeyCode.I)

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "NPCPrompt" then
		Dialog.open(prompt:GetAttribute("NpcId"))
	elseif prompt.Name == "WaystonePrompt" then
		MapWindow.open()
	end
end)

-- pede o estado inicial (caso o primeiro envio tenha chegado antes dos listeners)
task.spawn(function()
	State.request("sync")
end)
