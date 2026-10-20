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
ClassSelect.init()
HUD.init(screen, {
	onInventory = Inventory.toggle,
	onCharacter = Character.toggle,
	onQuests = QuestLog.toggle,
	onMap = MapWindow.toggle,
	onChest = Chest.toggle,
	onAbility = function(slot)
		local aim, point = Controller.getAim()
		State.action("ability", slot, aim, point)
	end,
})
WorldMarkers.init()

Controller.isBlocked = function()
	return Window.anyOpen() or ClassSelect.isOpen()
end
Controller.onNoStamina = function()
	HUD.flashStamina()
	Popups.message("Sem estamina!", UI.Colors.Stamina)
end
Controller.init()

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
	classes = function()
		Window.closeAll()
		ClassSelect.open(true)
	end,
}

-- ===================== EVENTOS DO SERVIDOR =====================

Remotes.DataUpdate.OnClientEvent:Connect(function(data)
	State.set(data)
	HUD.update(data)
	if data.class == nil and not ClassSelect.isOpen() then
		ClassSelect.open(false)
	end
end)

Remotes.Notify.OnClientEvent:Connect(function(notification)
	if notification.kind == "chest" then
		Chest.reveal(notification.item, notification.chest)
	else
		Popups.handle(notification)
	end
end)

local FX_HANDLERS = {
	hit = Fx.hit,
	death = Fx.death,
	gold = Fx.gold,
	xp = Fx.xp,
	hurt = Fx.hurt,
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
		MapWindow.toggle()
	elseif key == Enum.KeyCode.B then
		Chest.toggle()
	end
end)

-- O Roblox usa I/O para zoom da câmera; esta ligação tem prioridade maior e "engole" a tecla I
ContextActionService:BindActionAtPriority("AbrirInventario", function(_, inputState)
	if inputState == Enum.UserInputState.Begin and not UserInputService:GetFocusedTextBox() then
		Inventory.toggle()
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
