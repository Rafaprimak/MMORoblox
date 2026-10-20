-- Controles: correr (Shift), esquivar (Q), atacar (clique / segurar), pesado (botão direito ou R),
-- habilidades (1-4), poções (Z X V), montaria (H). No celular aparecem botões na tela.
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

local Controller = {}

Controller.isBlocked = function()
	return false
end -- preenchido pelo init (janelas abertas)
Controller.onNoStamina = function() end

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local sprintHeld = false
local attackHeld = false
local comboIndex = 0
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

local function currentSpeed()
	if player:GetAttribute("Mounted") then
		return Config.MountSpeed
	end
	if sprintHeld and (player:GetAttribute("Stamina") or 0) > 1 then
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
end

-- ===================== ATAQUES =====================

local function weaponStyle()
	local data = State.data
	local weaponType = (data and data.stats and data.stats.weaponType) or player:GetAttribute("WeaponType") or "sword"
	return WeaponStyles.get(weaponType), data and data.stats
end

local function attack(heavy)
	if Controller.isBlocked() then
		return
	end
	local character = parts()
	if not character then
		return
	end
	local now = os.clock()
	if now < lockUntil then
		return
	end
	local style, stats = weaponStyle()
	local mastery = stats and stats.masteryLevel or 1
	local speed = stats and stats.attackSpeed or 1
	local move
	if heavy then
		move = style.heavy
		if mastery < (move.masteryReq or 0) then
			State.onError(("Ataque pesado destrava na maestria %d da arma."):format(move.masteryReq))
			lockUntil = now + 0.3
			return
		end
		if (player:GetAttribute("Stamina") or 0) < (move.stamina or 0) then
			Controller.onNoStamina()
			return
		end
	else
		if now - lastMoveEnd <= Config.ComboWindow then
			comboIndex += 1
		else
			comboIndex = 1
		end
		if comboIndex > #style.combo or (style.combo[comboIndex].masteryReq or 0) > mastery then
			comboIndex = 1
		end
		move = style.combo[comboIndex]
	end
	local aim = Controller.getAim()
	face(aim)
	local duration = move.duration / speed
	lockUntil = now + duration
	lastMoveEnd = lockUntil
	Animator.play(character, move.pose, duration, true)
	if move.lunge and move.lunge > 0 then
		task.delay(move.windup / speed * 0.5, Controller.dash, flat(aim), move.lunge, 0.12)
	end
	if heavy then
		State.action("heavy", aim)
	else
		State.action("attack", comboIndex, aim)
	end
end

local function dodge()
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
	if (player:GetAttribute("Stamina") or 0) < Config.DodgeCost then
		Controller.onNoStamina()
		return
	end
	lastDodge = now
	local direction = humanoid.MoveDirection
	if direction.Magnitude < 0.1 then
		direction = -root.CFrame.LookVector
	end
	Controller.dash(direction, Config.DodgeSpeed, Config.DodgeDuration)
	Animator.play(character, "dodge", Config.DodgeDuration + 0.1)
	Sounds.play("swing", 0.7, 0.3)
	State.action("dodge")
end

local function useAbility(slot)
	if Controller.isBlocked() then
		return
	end
	local character = parts()
	local data = State.data
	if not character or not data or not data.abilities then
		return
	end
	local ability = data.abilities[slot]
	if not ability then
		return
	end
	if os.clock() < (abilityLocalCooldown[slot] or 0) then
		return
	end
	local aim, point = Controller.getAim()
	face(aim)
	State.action("ability", slot, aim, point)
end

function Controller.setCooldown(slot, duration)
	abilityLocalCooldown[slot] = os.clock() + duration
end

function Controller.cast(abilityId, pose)
	local character = parts()
	if character and pose then
		Animator.play(character, pose, 0.6, pose ~= "roar" and pose ~= "castBig")
	end
end

-- ===================== ENTRADAS =====================

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
			attackHeld = true
			attack(false)
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.R then
			attack(true)
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
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			attackHeld = false
		end
	end)

	-- botões de toque (aparecem só no celular)
	local function touchAction(name, title, position, callback, holdable)
		ContextActionService:BindAction(name, function(_, inputState)
			if inputState == Enum.UserInputState.Begin then
				callback(true)
			elseif inputState == Enum.UserInputState.End and holdable then
				callback(false)
			end
			return Enum.ContextActionResult.Pass
		end, true)
		ContextActionService:SetTitle(name, title)
		ContextActionService:SetPosition(name, position)
	end
	if UserInputService.TouchEnabled then
		touchAction("Atacar", "⚔", UDim2.new(1, -95, 1, -170), function(down)
			attackHeld = down
			if down then
				attack(false)
			end
		end, true)
		touchAction("Pesado", "💥", UDim2.new(1, -160, 1, -130), function()
			attack(true)
		end)
		touchAction("Esquivar", "↩", UDim2.new(1, -160, 1, -200), function()
			dodge()
		end)
		touchAction("Correr", "🏃", UDim2.new(1, -95, 1, -240), function(down)
			setSprint(down)
		end, true)
		touchAction("Montar", "🐴", UDim2.new(1, -230, 1, -240), function()
			State.action("mount")
		end)
		for slot = 1, 4 do
			touchAction("Habilidade" .. slot, tostring(slot), UDim2.new(1, -60 - slot * 62, 1, -310), function()
				useAbility(slot)
			end)
		end
	end

	-- segurar o ataque repete o combo; velocidade conforme corrida/montaria
	RunService.Heartbeat:Connect(function()
		if attackHeld and os.clock() >= lockUntil then
			attack(false)
		end
		local _, _, humanoid = parts()
		if humanoid then
			local speed = currentSpeed()
			if humanoid.WalkSpeed ~= speed then
				humanoid.WalkSpeed = speed
			end
		end
		if sprintHeld and (player:GetAttribute("Stamina") or 0) <= 0 then
			setSprint(false)
		end
	end)
end

return Controller
