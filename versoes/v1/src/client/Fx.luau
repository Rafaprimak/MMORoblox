-- Efeitos visuais locais: números de dano, explosão de morte, tremida de câmera, arco-íris.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rarities = require(Shared.Rarities)

local UI = require(script.Parent.UI)
local Sounds = require(script.Parent.Sounds)

local Fx = {}

local player = Players.LocalPlayer
local shakeUntil, shakeStrength, shaking = 0, 0, false
local rainbowGuis = setmetatable({}, { __mode = "k" })
local hurtFrame = nil

local function effectPart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props.Shape then
		p.Shape = props.Shape
	end
	for key, value in props do
		if key ~= "Shape" then
			p[key] = value
		end
	end
	p.Parent = workspace
	return p
end

local function getRoot()
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

function Fx.shake(duration, strength)
	local now = os.clock()
	if now > shakeUntil then
		shakeStrength = strength
	else
		shakeStrength = math.max(shakeStrength, strength)
	end
	shakeUntil = math.max(shakeUntil, now + duration)
end

function Fx.registerRainbow(guiObject, property)
	rainbowGuis[guiObject] = property
end

function Fx.unregisterRainbow(guiObject)
	rainbowGuis[guiObject] = nil
end

local function floatingText(position, text, color, height, duration)
	local jitter = Vector3.new((math.random() - 0.5) * 2, (math.random() - 0.5), (math.random() - 0.5) * 2)
	local anchor = effectPart({ Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, CFrame = CFrame.new(position + jitter) })
	local gui = UI.new("BillboardGui", {
		Size = UDim2.fromOffset(height * 4, height),
		AlwaysOnTop = true,
		LightInfluence = 0,
		Adornee = anchor,
		Parent = anchor,
	})
	local label = UI.new("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = color,
		Font = Enum.Font.GothamBlack,
		TextScaled = true,
		Parent = gui,
	})
	local stroke = UI.textStroke(2)
	stroke.Parent = label
	local scale = UI.new("UIScale", { Scale = 0.2, Parent = label })
	TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(gui, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffset = Vector3.new(0, 3, 0) }):Play()
	task.delay(duration * 0.55, function()
		TweenService:Create(label, TweenInfo.new(duration * 0.45), { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, TweenInfo.new(duration * 0.45), { Transparency = 1 }):Play()
	end)
	Debris:AddItem(anchor, duration + 0.1)
end

function Fx.damageNumber(position, amount, crit)
	if crit then
		floatingText(position, UI.formatNumber(amount) .. "!", Color3.fromRGB(255, 210, 40), 46, 0.9)
		Sounds.play("crit", 1 + math.random() * 0.2, 0.4)
		Fx.shake(0.12, 0.35)
	else
		floatingText(position, UI.formatNumber(amount), Color3.new(1, 1, 1), 32, 0.7)
	end
end

function Fx.gold(position, amount)
	floatingText(position + Vector3.new(0, 1.5, 0), "+" .. amount .. " 💰", UI.Colors.Gold, 26, 1)
end

function Fx.death(position, color, scale)
	scale = scale or 1
	local flash = effectPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(position),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.2,
	})
	TweenService:Create(flash, TweenInfo.new(0.3), { Size = Vector3.one * 8 * scale, Transparency = 1 }):Play()
	Debris:AddItem(flash, 0.35)

	for _ = 1, math.floor(8 * scale) do
		local size = (0.4 + math.random() * 0.6) * scale
		local piece = Instance.new("Part")
		piece.Size = Vector3.new(size, size, size)
		piece.Color = color
		piece.Material = Enum.Material.SmoothPlastic
		piece.CanQuery = false
		piece.CanTouch = false
		piece.CFrame = CFrame.new(position) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		piece.Parent = workspace
		local direction = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5)
		if direction.Magnitude < 0.01 then
			direction = Vector3.new(1, 0, 0)
		end
		piece.AssemblyLinearVelocity = direction.Unit * (12 + math.random() * 14) * math.sqrt(scale) + Vector3.new(0, 25 + math.random() * 15, 0)
		piece.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 20
		task.delay(0.9, function()
			TweenService:Create(piece, TweenInfo.new(0.5), { Transparency = 1 }):Play()
		end)
		Debris:AddItem(piece, 1.5)
	end
end

function Fx.hurt(_amount)
	if hurtFrame then
		hurtFrame.BackgroundTransparency = 0.65
		TweenService:Create(hurtFrame, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
	end
	Fx.shake(0.1, 0.25)
end

function Fx.slam(position, radius)
	local ring = effectPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, radius * 2, radius * 2),
		CFrame = CFrame.new(position + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(255, 120, 60),
		Material = Enum.Material.Neon,
		Transparency = 0.3,
	})
	TweenService:Create(ring, TweenInfo.new(0.4), { Size = Vector3.new(0.4, radius * 2.6, radius * 2.6), Transparency = 1 }):Play()
	Debris:AddItem(ring, 0.45)
	local root = getRoot()
	if root and (root.Position - position).Magnitude < radius * 3 then
		Fx.shake(0.35, 0.9)
	end
end

function Fx.drop(_position, rarityId)
	local rarity = Rarities.ById[rarityId] or Rarities.List[1]
	Sounds.play("ping", 0.7 + rarity.order * 0.12, 0.3 + rarity.order * 0.06)
	if rarity.order >= 4 then
		Fx.shake(0.2, 0.3)
	end
end

function Fx.levelUp()
	local root = getRoot()
	if not root then
		return
	end
	local ring = effectPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 2, 2),
		CFrame = CFrame.new(root.Position - Vector3.new(0, 2.8, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = UI.Colors.Gold,
		Material = Enum.Material.Neon,
		Transparency = 0.2,
	})
	TweenService:Create(ring, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.3, 26, 26), Transparency = 1 }):Play()
	Debris:AddItem(ring, 0.75)
	local pillar = effectPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(14, 4, 4),
		CFrame = CFrame.new(root.Position + Vector3.new(0, 4, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = UI.Colors.Gold,
		Material = Enum.Material.Neon,
		Transparency = 0.4,
	})
	TweenService:Create(pillar, TweenInfo.new(0.8), { Size = Vector3.new(40, 0.3, 0.3), Transparency = 1 }):Play()
	Debris:AddItem(pillar, 0.85)
end

function Fx.handle(kind, ...)
	if kind == "death" then
		Fx.death(...)
	elseif kind == "gold" then
		Fx.gold(...)
	elseif kind == "hurt" then
		Fx.hurt(...)
	elseif kind == "slam" then
		Fx.slam(...)
	elseif kind == "drop" then
		Fx.drop(...)
	end
end

function Fx.init(screen)
	hurtFrame = UI.new("Frame", {
		Name = "Dano",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(200, 0, 0),
		BackgroundTransparency = 1,
		ZIndex = 0,
		Parent = screen,
	})

	RunService.RenderStepped:Connect(function(dt)
		-- tremida de câmera
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			if os.clock() < shakeUntil then
				humanoid.CameraOffset = Vector3.new((math.random() - 0.5) * shakeStrength, (math.random() - 0.5) * shakeStrength, 0)
				shaking = true
			elseif shaking then
				humanoid.CameraOffset = Vector3.zero
				shaking = false
			end
		end

		-- itens "Secretos" ficam arco-íris
		local color = Color3.fromHSV((os.clock() * 0.3) % 1, 0.75, 1)
		for _, part in CollectionService:GetTagged("Rainbow") do
			if part:IsA("BasePart") then
				part.Color = color
			end
		end
		for guiObject, property in rainbowGuis do
			guiObject[property] = color
		end

		-- objetos decorativos que giram
		for _, part in CollectionService:GetTagged("Spin") do
			if part:IsA("BasePart") then
				part.CFrame *= CFrame.Angles(0, dt * 1.2, 0)
			end
		end
	end)
end

return Fx
