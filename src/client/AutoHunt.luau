-- Auto Caçar (só VIP; o servidor libera o atributo "AutoFarm"). Enquanto ligado, o personagem procura o
-- inimigo vivo mais perto dentro de RANGE do ponto onde foi ligado, anda até ele, ataca no ritmo do
-- combo, toma poção de vida quando está mal e volta para o ponto quando não há ninguém por perto.
-- Mexer o personagem (WASD, setas, analógico, pulo) desliga.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Enemies = require(Shared.Enemies)

local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Controller = require(script.Parent.Controller)
local Popups = require(script.Parent.Popups)

local AutoHunt = {}

local RANGE = 70 -- até onde ele vai buscar inimigos a partir do ponto de partida
local REACH = { bow = 34, staff = 30 } -- alcance de ataque por arma (o resto: corpo a corpo)
local MELEE_REACH = 6.5
local POTION_AT = 0.35

local player = Players.LocalPlayer
local anchor = nil
local banner
local lastPotion = 0

local MOVE_KEYS = {
	[Enum.KeyCode.W] = true, [Enum.KeyCode.A] = true, [Enum.KeyCode.S] = true, [Enum.KeyCode.D] = true,
	[Enum.KeyCode.Up] = true, [Enum.KeyCode.Down] = true, [Enum.KeyCode.Left] = true, [Enum.KeyCode.Right] = true,
	[Enum.KeyCode.Space] = true,
}

function AutoHunt.isOn()
	return player:GetAttribute("AutoFarm") == true
end

function AutoHunt.toggle()
	if AutoHunt.isOn() then
		State.request("autoFarm", false)
		return
	end
	if not player:GetAttribute("Vip") then
		if Config.VipGamePassId > 0 then
			MarketplaceService:PromptGamePassPurchase(player, Config.VipGamePassId)
		else
			Popups.message("O Auto Caçar é exclusivo para VIP (o VIP ainda não está à venda).", UI.Colors.Gold)
		end
		return
	end
	State.request("autoFarm", true)
end

local function nearestEnemy(origin)
	local folder = workspace:FindFirstChild("Inimigos")
	local best, bestDistance = nil, math.huge
	for _, root in if folder then folder:GetChildren() else {} do
		local def = Enemies.Defs[root:GetAttribute("Type") or ""]
		if root:IsA("BasePart") and def and def.behavior ~= "dummy" and not root:GetAttribute("Dead") then
			if anchor and (root.Position - anchor).Magnitude <= RANGE then
				local distance = (root.Position - origin).Magnitude
				if distance < bestDistance then
					best, bestDistance = root, distance
				end
			end
		end
	end
	return best, bestDistance
end

local function step()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	anchor = anchor or root.Position
	-- poção de vida quando está mal
	if humanoid.Health / humanoid.MaxHealth < POTION_AT and os.clock() - lastPotion > 6 and State.data and (State.data.consumables.pocao_vida or 0) > 0 then
		lastPotion = os.clock()
		State.action("potion", "pocao_vida")
	end
	local target, distance = nearestEnemy(root.Position)
	if not target then
		if (root.Position - anchor).Magnitude > 8 then
			humanoid:MoveTo(anchor)
		end
		return
	end
	local weaponType = player:GetAttribute("WeaponType")
	local reach = REACH[weaponType or ""] or MELEE_REACH
	local radius = target.Size.X / 2
	if distance > reach + radius then
		-- chega perto (para um pouco antes, para não ficar dentro do inimigo)
		local direction = (root.Position - target.Position) * Vector3.new(1, 0, 1)
		local stop = if direction.Magnitude > 0.1 then target.Position + direction.Unit * (radius + reach * 0.6) else target.Position
		humanoid:MoveTo(Vector3.new(stop.X, root.Position.Y, stop.Z))
	else
		humanoid:MoveTo(root.Position)
		if not Controller.isAttacking() then
			Controller.autoAttack(target.Position)
		end
	end
end

function AutoHunt.init(screen)
	banner = UI.new("Frame", {
		Name = "AutoCacar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 100),
		Size = UDim2.fromOffset(360, 34),
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.15,
		Visible = false,
		Parent = screen,
	}, { UI.corner(10) })
	UI.ornate(banner, UI.Colors.Trim, 3)
	UI.label({ Text = "⚔ AUTO CAÇAR (VIP)  •  mova-se ou aperte N para parar", Size = UDim2.new(1, -16, 1, 0), Position = UDim2.fromOffset(8, 0), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = UI.Colors.Gold, Parent = banner }, { UI.textStroke(1) })

	player:GetAttributeChangedSignal("AutoFarm"):Connect(function()
		local on = AutoHunt.isOn()
		banner.Visible = on
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		anchor = if on and root then root.Position else nil
		if not on then
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid and root then
				humanoid:MoveTo(root.Position)
			end
		end
	end)
	-- mexer o personagem desliga
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.N then
			AutoHunt.toggle()
		elseif AutoHunt.isOn() and (MOVE_KEYS[input.KeyCode] or input.KeyCode == Enum.KeyCode.Thumbstick1) then
			State.request("autoFarm", false)
		end
	end)
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		if not AutoHunt.isOn() then
			return
		end
		accumulator += dt
		if accumulator < 0.15 then
			return
		end
		accumulator = 0
		step()
	end)
end

return AutoHunt
