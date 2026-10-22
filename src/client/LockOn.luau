-- Travar a mira no inimigo (estilo souls): a câmera fica atrás do jogador olhando para o alvo,
-- o personagem encara o alvo (andar vira "strafe") e golpes/habilidades miram nele.
--   T ou botão do meio do mouse = travar/destravar   •   "chicote" rápido do mouse para o lado = trocar de alvo
-- Se o alvo morrer, trava sozinho no próximo inimigo perto (ou solta).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local UI = require(script.Parent.UI)
local Sounds = require(script.Parent.Sounds)

local LockOn = {}

LockOn.onChanged = nil -- function(target ou nil)

local RANGE = 70 -- alcance para travar
local KEEP_RANGE = 95 -- solta se o alvo ficar mais longe que isso
local FLICK_PIXELS = 160
local FLICK_TIME = 0.22

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local target = nil
local marker = nil
local flick = { amount = 0, start = 0 }
local lastSwitch = 0

local function myRoot()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and humanoid and humanoid.Health > 0 then
		return root, humanoid
	end
	return nil
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function alive(enemyRoot)
	return enemyRoot ~= nil and enemyRoot.Parent ~= nil and not enemyRoot:GetAttribute("Dead") and (enemyRoot:GetAttribute("Hp") or 1) > 0
end

-- centro do alvo (um pouco acima do meio, onde fica o "peito")
function LockOn.aimPoint(enemyRoot)
	enemyRoot = enemyRoot or target
	if not enemyRoot then
		return nil
	end
	return enemyRoot.Position + Vector3.new(0, enemyRoot.Size.Y * 0.15, 0)
end

local function candidates()
	local folder = workspace:FindFirstChild("Inimigos")
	return if folder then folder:GetChildren() else {}
end

-- escolhe o inimigo mais "na frente da câmera" e perto; exclude = alvo atual (para trocar)
local function pick(exclude, side)
	local root = myRoot()
	if not root then
		return nil
	end
	local look = flat(camera.CFrame.LookVector)
	look = if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, -1)
	local right = flat(camera.CFrame.RightVector).Unit
	local best, bestScore = nil, math.huge
	for _, enemy in candidates() do
		if enemy:IsA("BasePart") and enemy ~= exclude and alive(enemy) then
			local offset = flat(enemy.Position - root.Position)
			local distance = offset.Magnitude
			if distance <= RANGE and distance > 0.1 then
				local direction = offset.Unit
				local facing = look:Dot(direction) -- 1 = bem na frente
				local lateral = right:Dot(direction)
				local valid = facing > -0.2
				if side then
					valid = valid and (lateral * side > 0.05)
				end
				if valid then
					local score = distance * (1.6 - facing) + (if side then math.abs(lateral) * 40 else 0)
					if score < bestScore then
						best, bestScore = enemy, score
					end
				end
			end
		end
	end
	return best
end

local function ensureMarker()
	if marker then
		return
	end
	marker = UI.new("BillboardGui", { Name = "AlvoTravado", Size = UDim2.fromOffset(34, 34), AlwaysOnTop = true, LightInfluence = 0 })
	local diamond = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(16, 16), Rotation = 45, BackgroundColor3 = Color3.fromRGB(255, 70, 60), Parent = marker }, { UI.stroke(Color3.new(1, 1, 1), 2) })
	UI.new("UIScale", { Name = "Pulso", Parent = diamond })
end

local function setTarget(enemyRoot)
	if target == enemyRoot then
		return
	end
	target = enemyRoot
	local _, humanoid = myRoot()
	if humanoid then
		humanoid.AutoRotate = target == nil
	end
	ensureMarker()
	if target then
		marker.Adornee = target
		marker.StudsOffset = Vector3.new(0, target.Size.Y * 0.15, 0)
		marker.Parent = player:WaitForChild("PlayerGui")
		Sounds.play("ping", 2.2, 0.25)
	else
		marker.Adornee = nil
		marker.Parent = nil
	end
	if LockOn.onChanged then
		LockOn.onChanged(target)
	end
end

function LockOn.target()
	if target and alive(target) then
		return target
	end
	return nil
end

function LockOn.toggle()
	if target then
		setTarget(nil)
		return
	end
	if player:GetAttribute("Mounted") then
		return
	end
	local found = pick(nil)
	if found then
		setTarget(found)
	end
end

function LockOn.switch(side)
	if not target then
		return
	end
	local found = pick(target, side)
	if found then
		setTarget(found)
		lastSwitch = os.clock()
	end
end

function LockOn.release()
	setTarget(nil)
end

function LockOn.init()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.T or input.UserInputType == Enum.UserInputType.MouseButton3 or input.KeyCode == Enum.KeyCode.ButtonR3 then
			LockOn.toggle()
		end
	end)
	-- trocar de alvo com um movimento rápido do mouse para o lado
	UserInputService.InputChanged:Connect(function(input)
		if not target or input.UserInputType ~= Enum.UserInputType.MouseMovement then
			return
		end
		local now = os.clock()
		if now - flick.start > FLICK_TIME then
			flick.start = now
			flick.amount = 0
		end
		flick.amount += input.Delta.X
		if math.abs(flick.amount) > FLICK_PIXELS and now - lastSwitch > 0.4 then
			LockOn.switch(if flick.amount > 0 then 1 else -1)
			flick.amount = 0
		end
	end)
	if UserInputService.TouchEnabled then
		local ContextActionService = game:GetService("ContextActionService")
		ContextActionService:BindAction("Travar", function(_, inputState)
			if inputState == Enum.UserInputState.Begin then
				LockOn.toggle()
			end
			return Enum.ContextActionResult.Pass
		end, true)
		ContextActionService:SetTitle("Travar", "🎯")
		ContextActionService:SetPosition("Travar", UDim2.new(1, -290, 1, -200))
	end

	-- câmera e rosto do personagem (roda depois da câmera padrão do Roblox)
	RunService:BindToRenderStep("TravarAlvo", Enum.RenderPriority.Camera.Value + 1, function(dt)
		if not target then
			return
		end
		local root = myRoot()
		if not root or player:GetAttribute("Mounted") then
			setTarget(nil)
			return
		end
		if not alive(target) then
			-- alvo morreu: passa para o próximo perto, se houver
			setTarget(pick(target))
			if not target then
				return
			end
		end
		local aim = LockOn.aimPoint()
		local toTarget = flat(aim - root.Position)
		if toTarget.Magnitude > KEEP_RANGE then
			setTarget(nil)
			return
		end
		if toTarget.Magnitude < 0.5 then
			return
		end
		local direction = toTarget.Unit
		-- personagem olha para o alvo
		root.CFrame = CFrame.lookAt(root.Position, root.Position + direction)
		-- câmera atrás do ombro, mantendo o zoom atual
		local focus = root.Position + Vector3.new(0, 2.5, 0)
		local zoom = math.clamp((camera.CFrame.Position - camera.Focus.Position).Magnitude, 10, 26)
		local desired = focus - direction * zoom + Vector3.new(0, zoom * 0.32 + 1.5, 0)
		local lookAt = focus:Lerp(aim, 0.5)
		local alpha = 1 - math.exp(-10 * dt)
		camera.CFrame = camera.CFrame:Lerp(CFrame.lookAt(desired, lookAt), alpha)
		-- pulso do marcador
		local pulse = marker and marker:FindFirstChildWhichIsA("Frame")
		local scale = pulse and pulse:FindFirstChild("Pulso")
		if scale then
			scale.Scale = 1 + math.sin(os.clock() * 8) * 0.12
		end
	end)

	player.CharacterAdded:Connect(function()
		target = nil
		if marker then
			marker.Parent = nil
		end
		if LockOn.onChanged then
			LockOn.onChanged(nil)
		end
	end)
end

return LockOn
