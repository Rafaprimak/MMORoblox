-- Ponto de entrada do cliente: monta a interface e escuta o servidor.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local UI = require(script.UI)
local Fx = require(script.Fx)
local Popups = require(script.Popups)
local HUD = require(script.HUD)
local Inventory = require(script.Inventory)
local Chest = require(script.Chest)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screen = UI.new("ScreenGui", {
	Name = "HunterHUD",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = playerGui,
})

Fx.init(screen)
Popups.init(screen)
Inventory.init(screen)
Chest.init(screen)
Inventory.onOpen = Chest.close
Chest.onOpen = Inventory.close

HUD.init(screen, {
	onInventory = Inventory.toggle,
	onChest = Chest.toggle,
	onDev = function(kind)
		Remotes.Request:InvokeServer("dev", kind)
	end,
})

local state = nil

Remotes.DataUpdate.OnClientEvent:Connect(function(data)
	state = data
	HUD.update(data)
	Inventory.update(data)
	Chest.update(data)
end)

Remotes.Notify.OnClientEvent:Connect(function(notification)
	if notification.kind == "chest" then
		Chest.reveal(notification.item, false)
	else
		Popups.handle(notification)
	end
end)

Remotes.Damage.OnClientEvent:Connect(Fx.damageNumber)
Remotes.Fx.OnClientEvent:Connect(Fx.handle)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.I then
		Inventory.toggle()
	elseif input.KeyCode == Enum.KeyCode.B then
		Chest.toggle()
	end
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "ChestPrompt" then
		Chest.open()
	elseif prompt.Name == "ForgePrompt" then
		Inventory.open()
	elseif prompt.Name == "GuildPrompt" then
		local story = state and state.quests and state.quests.story
		local speech = if story then ('"Hunter, sua missão agora: %s."'):format(story.text) else '"Você completou tudo... por enquanto."'
		Popups.banner("❗ Mestre da Guilda", speech, UI.Colors.Accent, 5)
	end
end)

-- pede o estado inicial (caso o primeiro envio tenha chegado antes dos listeners)
task.spawn(function()
	pcall(function()
		Remotes.Request:InvokeServer("sync")
	end)
end)
