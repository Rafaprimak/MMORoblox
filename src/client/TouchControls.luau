-- Controles de toque (só celular/tablet): um leque para o polegar direito em volta do botão de ataque.
-- Anel de dentro (perto do polegar): esquiva, pesado (segurar), bloquear (segurar) e correr (segurar).
-- Anel de fora: as 4 habilidades (os quadros do HUD, com recarga, vêm para cá), travar a mira e montar.
-- Segurar o ataque repete o combo sozinho (sem o bônus de ritmo: o toque no tempo certo continua valendo mais).
-- O pulo padrão do Roblox some e vira o botão do canto, para não ficar embaixo do leque.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Controller = require(script.Parent.Controller)
local LockOn = require(script.Parent.LockOn)

local TouchControls = {}

local player = Players.LocalPlayer
local SIZE = Vector2.new(320, 320) -- leque em unidades de projeto (a UIScale ajusta à tela)
local CENTER = Vector2.new(232, 222) -- centro do botão de ataque
local HOLD_DELAY = Config.RhythmWindow + 0.06 -- segurando: o próximo golpe sai logo depois da janela de ritmo

local gui, cluster, scale = nil, nil, nil
local attackHeld = false
local wasAttacking, lastAttackEnd = false, 0
local pressed = {} -- [InputObject] = função de soltar
local lockButton = nil

local function polar(angle, radius)
	local a = math.rad(angle)
	return CENTER + Vector2.new(math.cos(a), -math.sin(a)) * radius
end

-- botão redondo; onBegin no toque, onEnd ao soltar (mesmo arrastando o dedo para fora)
local function roundButton(name, at, size, iconName, color, onBegin, onEnd)
	local frame = UI.new("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(at.X, at.Y),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.25,
		Parent = cluster,
	}, { UI.corner(size), UI.stroke(color, 2.5, 0.15) })
	local pop = UI.new("UIScale", { Parent = frame })
	if iconName then
		UI.icon(iconName, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.56, 0.56), Color = color, Parent = frame })
	end
	local hit = UI.new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = frame })
	TouchControls.bindPress(hit, function()
		pop.Scale = 0.9
		frame.BackgroundTransparency = 0.05
		onBegin()
	end, function()
		pop.Scale = 1
		frame.BackgroundTransparency = 0.25
		if onEnd then
			onEnd()
		end
	end)
	return frame
end

-- liga um botão ao toque: começa ao encostar, termina ao soltar ou cancelar
function TouchControls.bindPress(button, onBegin, onEnd)
	button.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		if pressed[input] then
			return
		end
		local connection
		local function release()
			if pressed[input] then
				pressed[input] = nil
				if connection then
					connection:Disconnect()
				end
				onEnd()
			end
		end
		pressed[input] = release
		connection = input:GetPropertyChangedSignal("UserInputState"):Connect(function()
			if input.UserInputState == Enum.UserInputState.End or input.UserInputState == Enum.UserInputState.Cancel then
				release()
			end
		end)
		onBegin()
	end)
end

local function releaseAll()
	for _, release in pressed do
		release()
	end
end

-- esconde o pulo padrão do Roblox (ele reaparece quando o personagem renasce)
local function hideDefaultJump()
	local touchGui = player:FindFirstChild("PlayerGui") and player.PlayerGui:FindFirstChild("TouchGui")
	local frame = touchGui and touchGui:FindFirstChild("TouchControlFrame")
	local jump = frame and frame:FindFirstChild("JumpButton")
	if jump and jump.Visible then
		jump.Visible = false
	end
end

local function fit()
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(800, 400)
	scale.Scale = math.clamp(math.min(viewport.Y / 440, viewport.X / 760), 0.7, 1.1)
end

-- abilitySlots: os quadros de habilidade do HUD ({ frame, button, ... } por espaço 1..4)
function TouchControls.init(abilitySlots)
	if not UI.touchOnly() then
		return
	end
	gui = UI.new("ScreenGui", { Name = "ControlesToque", ResetOnSpawn = false, DisplayOrder = -1, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })
	cluster = UI.new("Frame", { Name = "Leque", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -8, 1, -8), Size = UDim2.fromOffset(SIZE.X, SIZE.Y), BackgroundTransparency = 1, Parent = gui })
	scale = UI.new("UIScale", { Parent = cluster })
	fit()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)

	local touch = Controller.touch
	-- ícones: "crossed-swords", "wind-slap", "explosion-rays", "checked-shield", "run", "archery-target", "horse-head"
	local attack = roundButton("Atacar", CENTER, 108, "crossed-swords", UI.Colors.Gold, function()
		attackHeld = true
		touch.attack()
	end, function()
		attackHeld = false
	end)
	UI.new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 140, 120)), Rotation = 90, Parent = attack })
	roundButton("Esquivar", polar(180, 95), 66, "wind-slap", Color3.fromRGB(150, 220, 255), touch.dodge)
	roundButton("Pesado", polar(135, 95), 66, "explosion-rays", Color3.fromRGB(255, 150, 60), touch.heavyStart, touch.heavyRelease)
	roundButton("Bloquear", polar(90, 95), 66, "checked-shield", Color3.fromRGB(170, 190, 255), function()
		touch.block(true)
	end, function()
		touch.block(false)
	end)
	roundButton("Correr", polar(225, 95), 52, "run", UI.Colors.Stamina, function()
		touch.sprint(true)
	end, function()
		touch.sprint(false)
	end)
	lockButton = roundButton("Travar", polar(82, 168), 46, "archery-target", UI.Colors.Text, LockOn.toggle)
	roundButton("Montar", Vector2.new(290, 140), 46, "horse-head", UI.Colors.Text, function()
		State.action("mount")
	end)
	local jump = roundButton("Pular", Vector2.new(290, 290), 56, nil, UI.Colors.Text, function()
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Jump = true
		end
	end)
	UI.label({ Text = "▲", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamBlack, TextSize = 26, Parent = jump }, { UI.textStroke(2) })

	-- habilidades: os quadros do HUD (ícone, recarga, custo) vêm para o anel de fora; tocar já usa
	for slot, info in abilitySlots do
		local at = polar(190 - (slot - 1) * 27, 168)
		info.frame.AnchorPoint = Vector2.new(0.5, 0.5)
		info.frame.Position = UDim2.fromOffset(at.X, at.Y)
		info.frame.Size = UDim2.fromOffset(60, 60)
		info.frame.Parent = cluster
		TouchControls.bindPress(info.button, function()
			Controller.useAbility(slot)
		end, function() end)
	end

	-- segurar o ataque repete o combo; travar a mira acende o botão
	RunService.Heartbeat:Connect(function()
		local attacking = Controller.isAttacking()
		if wasAttacking and not attacking then
			lastAttackEnd = os.clock()
		end
		wasAttacking = attacking
		if attackHeld and not attacking and os.clock() - lastAttackEnd >= HOLD_DELAY then
			touch.attack()
			lastAttackEnd = os.clock() -- golpe que não saiu (sem estamina, guarda): tenta de novo depois
		end
		local stroke = lockButton:FindFirstChildOfClass("UIStroke")
		stroke.Color = if LockOn.target() then UI.Colors.Red else UI.Colors.Text
		hideDefaultJump()
		cluster.Visible = player.Character ~= nil
	end)
	player.CharacterRemoving:Connect(releaseAll)
end

return TouchControls
