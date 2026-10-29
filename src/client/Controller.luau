-- Controles do combate dinâmico:
--   Clique  = golpe leve. Clique de novo QUANDO O GOLPE TERMINA para emendar o combo ("Ritmo!").
--             Clicar cedo demais quebra o combo — spam não funciona.
--   R       = segure para carregar o golpe pesado, solte para golpear (maestria 5)
--   F       = segure para bloquear; aperte logo antes do golpe inimigo para APARAR
--   Q       = esquiva (rolamento com invencibilidade); no último instante = esquiva perfeita
--   Shift   = correr      1-4 = habilidades      Z X V = poções      H = montaria
--   T / botão do meio = travar a mira no inimigo (LockOn)
-- No celular aparecem botões na tela para cada ação.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local WeaponStyles = require(Shared.WeaponStyles)

local State = require(script.Parent.State)
local Animator = require(script.Parent.Animator)
local Sounds = require(script.Parent.Sounds)
local LockOn = require(script.Parent.LockOn)
local UI = require(script.Parent.UI)

local Controller = {}

-- Ganchos preenchidos pelo init
Controller.isBlocked = function()
	return false
end -- janelas abertas
Controller.onNoStamina = function() end
Controller.onAttack = function(_duration) end -- HUD mostra a barra de ritmo
Controller.onFumble = function() end -- clicou cedo demais
Controller.onCharge = function(_active) end -- HUD mostra a barra de carga
Controller.onEvent = function(_name) end -- "dodge", "block", "sprint" (usado pelo tutorial)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local sprintHeld = false
local blocking = false
local charging = false
local comboIndex = 0
local comboBroken = false
local lockStart = 0
local lockUntil = 0
local lastMoveEnd = 0
local lastDodge = 0
local abilityLocalCooldown = {}

local aimParams = RaycastParams.new()
aimParams.FilterType = Enum.RaycastFilterType.Exclude

local function parts()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and humanoid and humanoid.Health > 0 then
		return character, root, humanoid
	end
	return nil
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

-- Direção e ponto mirados (mouse no PC; câmera no celular/controle)
function Controller.getAim()
	local character, root = parts()
	if not root then
		return Vector3.new(0, 0, -1), Vector3.zero
	end
	local origin = root.Position + Vector3.new(0, 1.2, 0)
	-- Auto Caçar: mira no inimigo escolhido por ele
	if Controller.autoAimPoint then
		local direction = Controller.autoAimPoint - origin
		if flat(direction).Magnitude < 0.5 then
			direction = root.CFrame.LookVector
		end
		return direction.Unit, Controller.autoAimPoint
	end
	-- mira travada: tudo vai no alvo
	local locked = LockOn.target()
	if locked then
		local point = LockOn.aimPoint(locked)
		local direction = point - origin
		if flat(direction).Magnitude < 0.5 then
			direction = root.CFrame.LookVector
		end
		return direction.Unit, point
	end
	if UserInputService.MouseEnabled and not UserInputService.TouchEnabled then
		local effects = workspace:FindFirstChild("Efeitos")
		local drops = workspace:FindFirstChild("Drops")
		aimParams.FilterDescendantsInstances = { character, effects, drops }
		local mouse = UserInputService:GetMouseLocation()
		local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
		local result = workspace:Raycast(ray.Origin, ray.Direction * 600, aimParams)
		local point = if result then result.Position else ray.Origin + ray.Direction * 250
		local direction = point - origin
		if flat(direction).Magnitude < 1.5 then
			direction = root.CFrame.LookVector
		end
		return direction.Unit, point
	end
	local look = camera.CFrame.LookVector
	return look, root.Position + flat(look).Unit * 30
end

local function face(direction)
	local _, root = parts()
	local horizontal = flat(direction)
	if root and horizontal.Magnitude > 0.01 then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + horizontal.Unit)
	end
end

-- Impulso horizontal (esquiva, investidas). A gravidade continua agindo.
function Controller.dash(direction, speed, duration)
	local _, root = parts()
	if not root then
		return
	end
	local attachment = root:FindFirstChild("RootAttachment")
	local horizontal = flat(direction)
	if not attachment or horizontal.Magnitude < 0.01 then
		return
	end
	horizontal = horizontal.Unit
	local ok = pcall(function()
		local velocity = Instance.new("LinearVelocity")
		velocity.Attachment0 = attachment
		velocity.RelativeTo = Enum.ActuatorRelativeTo.World
		velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
		velocity.PrimaryTangentAxis = Vector3.new(1, 0, 0)
		velocity.SecondaryTangentAxis = Vector3.new(0, 0, 1)
		velocity.PlaneVelocity = Vector2.new(horizontal.X * speed, horizontal.Z * speed)
		velocity.MaxForce = 200000
		velocity.Parent = root
		Debris:AddItem(velocity, duration)
	end)
	if not ok then
		root.AssemblyLinearVelocity = horizontal * speed + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
	end
end

function Controller.jump(power)
	local _, root = parts()
	if root then
		root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, power, root.AssemblyLinearVelocity.Z)
	end
end

local function stamina()
	return player:GetAttribute("Stamina") or 0
end

local function currentSpeed()
	if player:GetAttribute("Mounted") then
		return Config.MountSpeed
	end
	if blocking then
		return Config.BlockWalkSpeed
	end
	if charging then
		return Config.BlockWalkSpeed + 2
	end
	if sprintHeld and stamina() > 1 then
		return Config.SprintSpeed
	end
	return Config.WalkSpeed
end

local function setSprint(on)
	if sprintHeld == on then
		return
	end
	sprintHeld = on
	State.action("sprint", on)
	if on then
		Controller.onEvent("sprint")
	end
end

local function weaponStyle()
	local data = State.data
	local weaponType = (data and data.stats and data.stats.weaponType) or player:GetAttribute("WeaponType") or "sword"
	return WeaponStyles.get(weaponType), data and data.stats, weaponType
end

-- ===================== GUARDA =====================

local function setBlock(on)
	local character = parts()
	if on == blocking then
		return
	end
	if on then
		if not character or Controller.isBlocked() or charging or stamina() < 5 or player:GetAttribute("Mounted") then
			return
		end
		blocking = true
		Animator.hold(character, "block")
		Controller.onEvent("block")
	else
		blocking = false
		if character then
			Animator.stop(character)
		end
	end
	State.action("block", on)
end

-- ===================== GOLPES =====================

local function lightAttack()
	if Controller.isBlocked() or blocking or charging then
		return
	end
	local character = parts()
	if not character then
		return
	end
	local now = os.clock()
	if now < lockUntil then
		-- clicou durante o golpe: cedo demais quebra o combo
		if now < lockStart + (lockUntil - lockStart) * Config.FumbleFraction and not comboBroken then
			comboBroken = true
			Controller.onFumble()
		end
		return
	end
	local style, stats = weaponStyle()
	local mastery = stats and stats.masteryLevel or 1
	local speed = stats and stats.attackSpeed or 1
	if comboBroken or now - lastMoveEnd > Config.ComboWindow then
		comboIndex = 1
	else
		comboIndex += 1
	end
	comboBroken = false
	if comboIndex > #style.combo or (style.combo[comboIndex].masteryReq or 0) > mastery then
		comboIndex = 1
	end
	local move = style.combo[comboIndex]
	if stamina() < (move.stamina or 0) then
		Controller.onNoStamina()
		return
	end
	local aim = Controller.getAim()
	face(aim)
	local duration = move.duration / speed
	lockStart = now
	lockUntil = now + duration
	lastMoveEnd = lockUntil
	Animator.play(character, move.pose, duration, true)
	-- golpe do combo: som curto e baixo, com tom variando (não cansa no clique repetido)
	Sounds.play(if move.pose == "bow" then "bow" else "swing", 0.95 + math.random() * 0.3, if move.pose == "bow" then 0.3 else 0.2)
	Controller.onAttack(duration)
	State.action("attack", comboIndex, aim)
end

local function chargePose(weaponType)
	if weaponType == "bow" then
		return "bow", 0.5
	elseif weaponType == "staff" then
		return "castBig", 0.45
	end
	return "charge", 1
end

local function startHeavy()
	if Controller.isBlocked() or blocking or charging then
		return
	end
	local character = parts()
	if not character or os.clock() < lockUntil then
		return
	end
	local style, stats, weaponType = weaponStyle()
	local mastery = stats and stats.masteryLevel or 1
	if mastery < (style.heavy.masteryReq or 0) then
		State.onError(("Ataque pesado destrava na maestria %d da arma."):format(style.heavy.masteryReq))
		return
	end
	if stamina() < (style.heavy.stamina or 0) then
		Controller.onNoStamina()
		return
	end
	charging = true
	local pose, t = chargePose(weaponType)
	Animator.hold(character, pose, t)
	Sounds.play("charge", 1, 0.45)
	Controller.onCharge(true)
	State.action("heavyStart")
end

local function releaseHeavy()
	if not charging then
		return
	end
	charging = false
	Controller.onCharge(false)
	local character = parts()
	if not character then
		return
	end
	Animator.stop(character)
	local style, stats = weaponStyle()
	local move = style.heavy
	local aim = Controller.getAim()
	face(aim)
	local duration = move.duration / (stats and stats.attackSpeed or 1)
	local now = os.clock()
	lockStart = now
	lockUntil = now + duration
	lastMoveEnd = 0 -- o pesado encerra o combo
	Animator.play(character, move.pose, duration, true)
	Sounds.play("swingHeavy", 0.8, 0.45)
	State.action("heavy", aim)
end

local function dodge(forcedDirection)
	if Controller.isBlocked() then
		return
	end
	local character, root, humanoid = parts()
	if not character then
		return
	end
	local now = os.clock()
	if now - lastDodge < Config.DodgeCooldown then
		return
	end
	if stamina() < Config.DodgeCost then
		Controller.onNoStamina()
		return
	end
	lastDodge = now
	-- esquivar cancela guarda, carga e o golpe em andamento
	if blocking then
		blocking = false
		Animator.stop(character)
	end
	if charging then
		charging = false
		Controller.onCharge(false)
		Animator.stop(character)
	end
	lockUntil = 0
	comboIndex = 0
	local direction = if typeof(forcedDirection) == "Vector3" and forcedDirection.Magnitude > 0.1 then forcedDirection.Unit else humanoid.MoveDirection
	if direction.Magnitude < 0.1 then
		direction = -root.CFrame.LookVector
	end
	Controller.dash(direction, Config.DodgeSpeed, Config.DodgeDuration)
	Animator.play(character, "dodge", Config.DodgeDuration + 0.1)
	Controller.onEvent("dodge")
	Sounds.play("dodge", 0.9, 0.35)
	State.action("dodge")
end

local function useAbility(slot)
	if Controller.isBlocked() or charging then
		return
	end
	local character = parts()
	local data = State.data
	if not character or not data or not data.abilities then
		return
	end
	if not data.abilities[slot] then
		return
	end
	if os.clock() < (abilityLocalCooldown[slot] or 0) then
		return
	end
	if blocking then
		setBlock(false)
	end
	local aim, point = Controller.getAim()
	face(aim)
	State.action("ability", slot, aim, point)
end
Controller.useAbility = useAbility

function Controller.setCooldown(slot, duration)
	abilityLocalCooldown[slot] = os.clock() + duration
end

function Controller.cast(_abilityId, pose)
	local character = parts()
	if character and pose then
		Animator.play(character, pose, 0.6, pose ~= "roar" and pose ~= "castBig")
		Sounds.play("cast", 1, 0.4)
	end
end

function Controller.isBlocking()
	return blocking
end

function Controller.isCharging()
	return charging
end

-- O servidor derrubou a guarda (estamina acabou)
function Controller.forceStopBlock()
	if blocking then
		blocking = false
		local character = parts()
		if character then
			Animator.stop(character)
		end
	end
end

-- ===================== ENTRADAS =====================

-- Auto Caçar: golpe de combo mirando num ponto (respeita o ritmo: só sai quando o golpe anterior acaba)
Controller.autoAimPoint = nil
function Controller.autoAttack(point)
	Controller.autoAimPoint = point
	lightAttack()
	Controller.autoAimPoint = nil
end

-- Auto: esquiva numa direção e guarda (aparar) com a mesma animação e regras do jogador
function Controller.autoDodge(direction)
	dodge(direction)
end

function Controller.autoBlock(on)
	setBlock(on == true)
end

-- true enquanto um golpe está em andamento
function Controller.isAttacking()
	return os.clock() < lockUntil
end

local KEY_ABILITY = { [Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3, [Enum.KeyCode.Four] = 4 }
local KEY_POTION = { [Enum.KeyCode.Z] = "pocao_vida", [Enum.KeyCode.X] = "pocao_mana", [Enum.KeyCode.V] = "pocao_vigor" }

function Controller.init()
	UserInputService.InputBegan:Connect(function(input, processed)
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			setSprint(true)
			return
		end
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			lightAttack()
		elseif input.KeyCode == Enum.KeyCode.R then
			startHeavy()
		elseif input.KeyCode == Enum.KeyCode.F then
			setBlock(true)
		elseif input.KeyCode == Enum.KeyCode.Q then
			dodge()
		elseif KEY_ABILITY[input.KeyCode] then
			useAbility(KEY_ABILITY[input.KeyCode])
		elseif KEY_POTION[input.KeyCode] then
			State.action("potion", KEY_POTION[input.KeyCode])
		elseif input.KeyCode == Enum.KeyCode.H then
			State.action("mount")
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			setSprint(false)
		elseif input.KeyCode == Enum.KeyCode.R then
			releaseHeavy()
		elseif input.KeyCode == Enum.KeyCode.F then
			setBlock(false)
		end
	end)

	-- botões de toque (aparecem só no celular)
	local function touchAction(name, title, position, onBegin, onEnd)
		ContextActionService:BindAction(name, function(_, inputState)
			if inputState == Enum.UserInputState.Begin then
				onBegin()
			elseif inputState == Enum.UserInputState.End and onEnd then
				onEnd()
			end
			return Enum.ContextActionResult.Pass
		end, true)
		ContextActionService:SetPosition(name, position)
		-- título curto (número) ou ícone do atlas desenhado dentro do botão
		local button = ContextActionService:GetButton(name)
		if button and #title > 2 then
			ContextActionService:SetTitle(name, "")
			UI.icon(title, { Size = UDim2.fromScale(0.58, 0.58), Position = UDim2.fromScale(0.21, 0.21), Parent = button })
		else
			ContextActionService:SetTitle(name, title)
		end
	end
	if UserInputService.TouchEnabled then
		touchAction("Atacar", "crossed-swords", UDim2.new(1, -95, 1, -170), lightAttack)
		touchAction("Pesado", "explosion-rays", UDim2.new(1, -160, 1, -130), startHeavy, releaseHeavy)
		touchAction("Bloquear", "checked-shield", UDim2.new(1, -225, 1, -150), function()
			setBlock(true)
		end, function()
			setBlock(false)
		end)
		touchAction("Esquivar", "wind-slap", UDim2.new(1, -160, 1, -200), dodge)
		touchAction("Correr", "run", UDim2.new(1, -95, 1, -240), function()
			setSprint(true)
		end, function()
			setSprint(false)
		end)
		touchAction("Montar", "horse-head", UDim2.new(1, -230, 1, -240), function()
			State.action("mount")
		end)
		for slot = 1, 4 do
			touchAction("Habilidade" .. slot, tostring(slot), UDim2.new(1, -60 - slot * 62, 1, -310), function()
				useAbility(slot)
			end)
		end
	end

	-- velocidade conforme corrida/guarda/montaria
	RunService.Heartbeat:Connect(function()
		local _, _, humanoid = parts()
		if humanoid then
			local speed = currentSpeed()
			if humanoid.WalkSpeed ~= speed then
				humanoid.WalkSpeed = speed
			end
		end
		if sprintHeld and stamina() <= 0 then
			setSprint(false)
		end
		if blocking and stamina() <= 0 then
			setBlock(false)
		end
	end)

	-- ao renascer, limpa estados
	player.CharacterAdded:Connect(function()
		blocking = false
		charging = false
		lockUntil = 0
		Controller.onCharge(false)
	end)
end

return Controller
