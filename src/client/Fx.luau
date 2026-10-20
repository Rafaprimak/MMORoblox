-- Efeitos visuais: números de dano, avisos no chão, projéteis, explosões, tremida de câmera, arco-íris.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rarities = require(Shared.Rarities)
local Items = require(Shared.Items)
local Skills = require(Shared.Skills)

local UI = require(script.Parent.UI)
local Sounds = require(script.Parent.Sounds)
local Prefs = require(script.Parent.Prefs)
local EnemyRenderer = require(script.Parent.EnemyRenderer)

local Fx = {}

local player = Players.LocalPlayer
local shakeUntil, shakeStrength, shaking = 0, 0, false
local rainbowGuis = setmetatable({}, { __mode = "k" })
local hurtFrame = nil
local projectiles = {}
local effects = Instance.new("Folder")
effects.Name = "Efeitos"
effects.Parent = workspace

local STYLE_COLORS = {
	fire = Color3.fromRGB(255, 120, 40),
	ice = Color3.fromRGB(140, 220, 255),
	arcane = Color3.fromRGB(180, 110, 255),
	earth = Color3.fromRGB(170, 130, 90),
	slash = Color3.fromRGB(240, 240, 255),
	roar = Color3.fromRGB(255, 200, 60),
	spikes = Color3.fromRGB(160, 160, 170),
	shadow = Color3.fromRGB(120, 60, 170),
	summon = Color3.fromRGB(255, 70, 50),
	arrow = Color3.fromRGB(230, 220, 190),
	arrowBig = Color3.fromRGB(255, 240, 180),
	dagger = Color3.fromRGB(200, 200, 220),
	enemyArrow = Color3.fromRGB(200, 120, 80),
	enemyMagic = Color3.fromRGB(210, 80, 255),
	travel = Color3.fromRGB(110, 200, 255),
}

function Fx.styleColor(style)
	return STYLE_COLORS[style] or Color3.new(1, 1, 1)
end

local function effectPart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
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
	p.Parent = effects
	return p
end

local function getRoot()
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

function Fx.shake(duration, strength)
	if not Prefs.get("shake") then
		return
	end
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

function Fx.floatingText(position, text, color, height, duration)
	local jitter = Vector3.new((math.random() - 0.5) * 2, (math.random() - 0.5), (math.random() - 0.5) * 2)
	local anchor = effectPart({ Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, CFrame = CFrame.new(position + jitter) })
	local gui = UI.new("BillboardGui", { Size = UDim2.fromOffset(height * 5, height), AlwaysOnTop = true, LightInfluence = 0, Adornee = anchor, Parent = anchor })
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

-- Faíscas do impacto por elemento (todos veem). Definido depois de "burst" e "ring".
local impactAt = nil

-- Golpe em inimigo: pisca branco e faíscas para todos; número só para quem bateu
function Fx.hit(root, amount, crit, attacker, color, tag, element)
	if typeof(root) ~= "Instance" then
		return
	end
	EnemyRenderer.flash(root)
	if impactAt and element ~= "dot" then
		impactAt(root.Position, element, crit)
	end
	if attacker ~= player then
		return
	end
	local position = EnemyRenderer.topPosition(root)
	local numbers = Prefs.get("damageNumbers")
	if tag == "counter" then
		if numbers then
			Fx.floatingText(position + Vector3.new(0, 2, 0), "CONTRA-ATAQUE", Color3.fromRGB(120, 220, 255), 24, 0.8)
		end
		color = color or Color3.fromRGB(120, 220, 255)
	elseif tag == "staggered" then
		color = color or Color3.fromRGB(255, 160, 50)
	end
	if crit then
		if numbers then
			Fx.floatingText(position, UI.formatNumber(amount) .. "!", color or Color3.fromRGB(255, 210, 40), 48, 0.9)
		end
		Sounds.play("crit", 1 + math.random() * 0.2, 0.4)
		Fx.shake(0.12, 0.35)
	else
		if numbers then
			Fx.floatingText(position, UI.formatNumber(amount), color or Color3.new(1, 1, 1), 32, 0.7)
		end
		Sounds.play("swing", 1.4 + math.random() * 0.3, 0.12)
	end
end

function Fx.gold(position, amount)
	Fx.floatingText(position + Vector3.new(0, 1.5, 0), "+" .. amount .. " 💰", UI.Colors.Gold, 26, 1)
end

function Fx.xp(position, amount)
	Fx.floatingText(position + Vector3.new(0, 2.5, 0), "+" .. amount .. " XP", UI.Colors.Xp, 24, 1.1)
end

local function ring(position, radius, color, duration, thickness)
	local p = effectPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(thickness or 0.4, 1, 1),
		CFrame = CFrame.new(position + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.25,
	})
	TweenService:Create(p, TweenInfo.new(duration or 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(thickness or 0.4, radius * 2, radius * 2), Transparency = 1 }):Play()
	Debris:AddItem(p, (duration or 0.4) + 0.05)
end

local function burst(position, color, count, speed, size)
	for _ = 1, count do
		local s = (size or 0.6) * (0.6 + math.random() * 0.8)
		local piece = Instance.new("Part")
		piece.Size = Vector3.new(s, s, s)
		piece.Color = color
		piece.Material = Enum.Material.Neon
		piece.CanQuery = false
		piece.CanTouch = false
		piece.CanCollide = false
		piece.CastShadow = false
		piece.CFrame = CFrame.new(position) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		piece.Parent = effects
		local direction = Vector3.new(math.random() - 0.5, math.random() * 0.8 + 0.2, math.random() - 0.5)
		piece.AssemblyLinearVelocity = direction.Unit * (speed or 25) * (0.6 + math.random() * 0.8)
		TweenService:Create(piece, TweenInfo.new(0.7), { Transparency = 1, Size = Vector3.new(0.1, 0.1, 0.1) }):Play()
		Debris:AddItem(piece, 0.75)
	end
end
Fx.burst = burst

-- elemento → cor, quantidade e tamanho das faíscas
local IMPACTS = {
	fire = { color = Color3.fromRGB(255, 130, 40), count = 7, size = 0.5, flash = true },
	ice = { color = Color3.fromRGB(160, 230, 255), count = 6, size = 0.7, ring = true },
	arcane = { color = Color3.fromRGB(190, 120, 255), count = 5, size = 0.45, ring = true },
	shadow = { color = Color3.fromRGB(110, 50, 170), count = 6, size = 0.5 },
	blood = { color = Color3.fromRGB(200, 30, 50), count = 5, size = 0.4 },
	earth = { color = Color3.fromRGB(170, 130, 90), count = 7, size = 0.6 },
	roar = { color = Color3.fromRGB(255, 200, 60), count = 5, size = 0.45 },
	slash = { color = Color3.fromRGB(240, 240, 255), count = 4, size = 0.35 },
}
local PHYSICAL = { color = Color3.fromRGB(255, 245, 220), count = 3, size = 0.3 }

impactAt = function(position, element, crit)
	local info = IMPACTS[element] or PHYSICAL
	local count = info.count + (if crit then 4 else 0)
	burst(position, info.color, count, if crit then 26 else 18, info.size)
	if info.flash or crit then
		local flash = effectPart({ Shape = Enum.PartType.Ball, Size = Vector3.one, CFrame = CFrame.new(position), Color = info.color, Material = Enum.Material.Neon, Transparency = 0.2 })
		TweenService:Create(flash, TweenInfo.new(0.18), { Size = Vector3.one * (if crit then 4.5 else 3), Transparency = 1 }):Play()
		Debris:AddItem(flash, 0.22)
	end
	if info.ring then
		ring(position - Vector3.new(0, 1.5, 0), 4, info.color, 0.3, 0.25)
	end
end

-- ===================== COMBATE DINÂMICO =====================

local function characterRoot(target)
	local character = target and target.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

-- "Soco" no campo de visão (sensação de impacto)
local function fovPunch(amount, duration)
	if not Prefs.get("shake") then
		return
	end
	local camera = workspace.CurrentCamera
	local base = 70
	camera.FieldOfView = base - amount
	TweenService:Create(camera, TweenInfo.new(duration or 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = base }):Play()
end

function Fx.parry(who, sourcePosition)
	local root = characterRoot(who)
	if not root then
		return
	end
	local point = root.Position + root.CFrame.LookVector * 2.5 + Vector3.new(0, 1, 0)
	if typeof(sourcePosition) == "Vector3" then
		point = root.Position:Lerp(sourcePosition + Vector3.new(0, 2, 0), 0.4)
	end
	burst(point, Color3.fromRGB(255, 240, 160), 18, 32, 0.45)
	ring(root.Position - Vector3.new(0, 2.5, 0), 9, Color3.fromRGB(255, 230, 120), 0.35, 0.3)
	local flash = effectPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 1.5, CFrame = CFrame.new(point), Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon, Transparency = 0 })
	TweenService:Create(flash, TweenInfo.new(0.25), { Size = Vector3.one * 7, Transparency = 1 }):Play()
	Debris:AddItem(flash, 0.3)
	if who == player then
		Fx.floatingText(root.Position + Vector3.new(0, 4, 0), "APARADO!", Color3.fromRGB(255, 230, 100), 44, 0.9)
		Sounds.play("crit", 1.7, 0.6)
		task.delay(0.05, Sounds.play, "ping", 2.4, 0.5)
		Fx.shake(0.15, 0.4)
		fovPunch(8, 0.4)
	else
		Sounds.playAt(root, "crit", 1.7, 0.5)
	end
end

function Fx.blocked(who, _sourcePosition)
	local root = characterRoot(who)
	if not root then
		return
	end
	burst(root.Position + root.CFrame.LookVector * 2 + Vector3.new(0, 1, 0), Color3.fromRGB(200, 200, 210), 6, 18, 0.3)
	if who == player then
		Fx.floatingText(root.Position + Vector3.new(0, 3.5, 0), "Bloqueado", Color3.fromRGB(200, 200, 215), 24, 0.6)
		Sounds.play("swing", 0.6, 0.35)
		Fx.shake(0.08, 0.15)
	end
end

function Fx.guardBreak()
	local root = characterRoot(player)
	if root then
		Fx.floatingText(root.Position + Vector3.new(0, 4, 0), "GUARDA QUEBRADA!", Color3.fromRGB(255, 80, 80), 34, 0.9)
	end
	Sounds.play("crit", 0.5, 0.5)
	Fx.shake(0.3, 0.6)
end

function Fx.perfectDodge()
	local root = characterRoot(player)
	if not root then
		return
	end
	Fx.floatingText(root.Position + Vector3.new(0, 4, 0), "ESQUIVA PERFEITA!", Color3.fromRGB(120, 210, 255), 36, 1)
	ring(root.Position - Vector3.new(0, 2.5, 0), 10, Color3.fromRGB(120, 210, 255), 0.45, 0.25)
	burst(root.Position, Color3.fromRGB(150, 220, 255), 10, 14, 0.35)
	Sounds.play("ping", 2.6, 0.5)
	fovPunch(6, 0.5)
end

function Fx.rhythm()
	local root = characterRoot(player)
	if root then
		Fx.floatingText(root.Position + Vector3.new(0, 3.2, 0), "RITMO!", Color3.fromRGB(120, 255, 140), 22, 0.55)
	end
	Sounds.play("ping", 2.8, 0.18)
end

function Fx.fumble()
	local root = characterRoot(player)
	if root then
		Fx.floatingText(root.Position + Vector3.new(0, 3.2, 0), "cedo demais", Color3.fromRGB(190, 190, 200), 20, 0.5)
	end
end

function Fx.stagger(root, attacker)
	if typeof(root) ~= "Instance" then
		return
	end
	local position = EnemyRenderer.topPosition(root)
	Fx.floatingText(position + Vector3.new(0, 1.5, 0), "QUEBRA DE GUARDA!", Color3.fromRGB(255, 200, 60), 40, 1.1)
	burst(position, Color3.fromRGB(255, 210, 80), 16, 26, 0.5)
	ring(position - Vector3.new(0, 1, 0), 7, Color3.fromRGB(255, 220, 90), 0.4, 0.3)
	if attacker == player then
		Sounds.play("crit", 0.75, 0.7)
		Fx.shake(0.2, 0.45)
		fovPunch(5, 0.35)
	end
end

function Fx.death(position, color, scale)
	scale = scale or 1
	local flash = effectPart({ Shape = Enum.PartType.Ball, Size = Vector3.one, CFrame = CFrame.new(position), Color = color, Material = Enum.Material.Neon, Transparency = 0.2 })
	TweenService:Create(flash, TweenInfo.new(0.3), { Size = Vector3.one * 8 * scale, Transparency = 1 }):Play()
	Debris:AddItem(flash, 0.35)
	burst(position, color, math.floor(10 * scale), 28, 0.7 * scale)
	ring(position - Vector3.new(0, 1, 0), 6 * scale, Color3.new(1, 1, 1), 0.35)
end

function Fx.hurt(amount, _source)
	if hurtFrame then
		hurtFrame.BackgroundTransparency = 0.6
		TweenService:Create(hurtFrame, TweenInfo.new(0.45), { BackgroundTransparency = 1 }):Play()
	end
	Fx.shake(0.12, 0.3)
	local root = getRoot()
	if root and amount then
		Fx.floatingText(root.Position + Vector3.new(0, 3, 0), "-" .. UI.formatNumber(amount), Color3.fromRGB(255, 80, 80), 28, 0.8)
	end
end

function Fx.evaded()
	local root = getRoot()
	if root then
		Fx.floatingText(root.Position + Vector3.new(0, 3.5, 0), "ESQUIVOU!", Color3.fromRGB(150, 230, 255), 30, 0.8)
	end
	Sounds.play("ping", 2.2, 0.25)
end

-- Aviso no chão (círculo ou linha) que vai enchendo até o golpe
function Fx.telegraph(shape, position, size, duration, direction)
	local color = Color3.fromRGB(255, 50, 40)
	local y = position.Y + 0.25
	if shape == "circle" then
		local radius = size
		local outline = effectPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, radius * 2, radius * 2), CFrame = CFrame.new(position.X, y, position.Z) * CFrame.Angles(0, 0, math.rad(90)), Color = color, Material = Enum.Material.Neon, Transparency = 0.75 })
		local fill = effectPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 0.5, 0.5), CFrame = CFrame.new(position.X, y + 0.02, position.Z) * CFrame.Angles(0, 0, math.rad(90)), Color = color, Material = Enum.Material.Neon, Transparency = 0.45 })
		TweenService:Create(fill, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = Vector3.new(0.2, radius * 2, radius * 2) }):Play()
		Debris:AddItem(outline, duration + 0.05)
		Debris:AddItem(fill, duration + 0.05)
	elseif shape == "line" then
		local width, length = size.X, size.Z
		local dir = if typeof(direction) == "Vector3" and direction.Magnitude > 0 then direction.Unit else Vector3.new(0, 0, -1)
		local start = Vector3.new(position.X, y, position.Z)
		local center = start + dir * length / 2
		local outline = effectPart({ Size = Vector3.new(width, 0.15, length), CFrame = CFrame.lookAt(center, center + dir), Color = color, Material = Enum.Material.Neon, Transparency = 0.75 })
		local fill = effectPart({ Size = Vector3.new(width, 0.2, 0.2), CFrame = CFrame.lookAt(start, start + dir), Color = color, Material = Enum.Material.Neon, Transparency = 0.45 })
		TweenService:Create(fill, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = Vector3.new(width, 0.2, length), CFrame = CFrame.lookAt(center, center + dir) }):Play()
		Debris:AddItem(outline, duration + 0.05)
		Debris:AddItem(fill, duration + 0.05)
	end
end

function Fx.explosion(position, radius, style)
	local color = Fx.styleColor(style)
	ring(position, radius, color, 0.45, 0.5)
	local sphere = effectPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 2, CFrame = CFrame.new(position + Vector3.new(0, 1, 0)), Color = color, Material = Enum.Material.Neon, Transparency = 0.3 })
	TweenService:Create(sphere, TweenInfo.new(0.35), { Size = Vector3.one * radius * 1.4, Transparency = 1 }):Play()
	Debris:AddItem(sphere, 0.4)
	burst(position + Vector3.new(0, 1, 0), color, math.clamp(math.floor(radius), 6, 18), 20 + radius * 2, 0.6)
	local root = getRoot()
	if root and (root.Position - position).Magnitude < radius * 3 then
		Fx.shake(0.25, math.clamp(radius / 20, 0.15, 0.7))
	end
	if style == "earth" or style == "fire" then
		Sounds.play("explosion", 1 + math.random() * 0.2, 0.35)
	end
end

-- ===================== PROJÉTEIS =====================

local function projectileModel(style)
	local color = Fx.styleColor(style)
	if style == "arrow" or style == "arrowBig" or style == "enemyArrow" or style == "dagger" then
		local length = if style == "arrowBig" then 4 elseif style == "dagger" then 1.6 else 3
		local p = effectPart({ Size = Vector3.new(0.25, 0.25, length), Color = color, Material = if style == "arrowBig" then Enum.Material.Neon else Enum.Material.SmoothPlastic })
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, 0.12, length / 2)
		a0.Parent = p
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -0.12, length / 2)
		a1.Parent = p
		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Lifetime = 0.15
		trail.Color = ColorSequence.new(color)
		trail.Transparency = NumberSequence.new(0.3, 1)
		trail.Parent = p
		return p
	end
	local size = if style == "fire" then 2 elseif style == "enemyMagic" then 1.4 else 1.3
	local p = effectPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * size, Color = color, Material = Enum.Material.Neon })
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 10
	light.Brightness = 2
	light.Parent = p
	local particles = Instance.new("ParticleEmitter")
	particles.Color = ColorSequence.new(color)
	particles.LightEmission = 1
	particles.Size = NumberSequence.new(size * 0.6, 0)
	particles.Lifetime = NumberRange.new(0.2, 0.4)
	particles.Rate = 40
	particles.Speed = NumberRange.new(0, 1)
	particles.Parent = p
	return p
end

function Fx.projectile(id, origin, direction, speed, range, style)
	local part = projectileModel(style)
	part.CFrame = CFrame.lookAt(origin, origin + direction)
	projectiles[id] = { part = part, origin = origin, direction = direction, speed = speed, range = range, start = os.clock() }
	if style == "arrow" or style == "arrowBig" then
		Sounds.play("swing", 1.8, 0.15)
	end
end

function Fx.projectileEnd(id, position, explodeRadius, style)
	local projectile = projectiles[id]
	if projectile then
		projectiles[id] = nil
		projectile.part:Destroy()
	end
	if explodeRadius and explodeRadius > 0 then
		Fx.explosion(position, explodeRadius, style)
	else
		burst(position, Fx.styleColor(style), 4, 10, 0.3)
	end
end

function Fx.rain(center, radius, duration)
	ring(center, radius, Fx.styleColor("arrow"), duration, 0.2)
	local count = math.floor(duration * 25)
	for i = 1, count do
		task.delay(i / count * duration, function()
			local angle = math.random() * math.pi * 2
			local r = math.sqrt(math.random()) * radius
			local target = center + Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r)
			local arrow = effectPart({ Size = Vector3.new(0.2, 0.2, 2.6), Color = Fx.styleColor("arrow"), CFrame = CFrame.lookAt(target + Vector3.new(0, 30, 0), target) })
			TweenService:Create(arrow, TweenInfo.new(0.25, Enum.EasingStyle.Linear), { CFrame = CFrame.lookAt(target + Vector3.new(0, 1, 0), target - Vector3.new(0, 1, 0)) }):Play()
			Debris:AddItem(arrow, 0.6)
		end)
	end
end

function Fx.meteor(center, radius, delay)
	Fx.telegraph("circle", center, radius, delay)
	local rock = effectPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 7, Color = Color3.fromRGB(255, 110, 30), Material = Enum.Material.Neon, CFrame = CFrame.new(center + Vector3.new(30, 90, 30)) })
	local fire = Instance.new("Fire")
	fire.Size = 12
	fire.Heat = 20
	fire.Parent = rock
	TweenService:Create(rock, TweenInfo.new(delay, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = CFrame.new(center + Vector3.new(0, 2, 0)) }):Play()
	Debris:AddItem(rock, delay + 0.05)
end

function Fx.blink(from, to, style)
	local color = Fx.styleColor(style or "arcane")
	burst(from, color, 10, 18, 0.5)
	burst(to, color, 10, 18, 0.5)
	ring(to - Vector3.new(0, 2.5, 0), 6, color, 0.4)
	Sounds.play("ping", 1.6, 0.3)
end

function Fx.gather(position, color, skill)
	burst(position + Vector3.new(0, 1.5, 0), color, 8, 15, 0.4)
	local root = getRoot()
	if root and (root.Position - position).Magnitude < 20 then
		Sounds.play(if skill == "mineracao" then "crit" else "ping", if skill == "mineracao" then 1.4 else 1.8, 0.3)
	end
end

function Fx.drop(_position, rarityId)
	local rarity = Rarities.ById[rarityId] or Rarities.List[1]
	Sounds.play("ping", 0.7 + rarity.order * 0.12, 0.3 + rarity.order * 0.06)
	if rarity.order >= 4 then
		Fx.shake(0.2, 0.3)
	end
end

function Fx.potion(target, id)
	local character = target and target.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local color = if id == "pocao_mana" then UI.Colors.Mana elseif id == "pocao_vigor" then UI.Colors.Stamina elseif id == "elixir_forca" then Color3.fromRGB(255, 120, 40) else Color3.fromRGB(110, 255, 120)
	ring(root.Position - Vector3.new(0, 2.5, 0), 5, color, 0.5)
	burst(root.Position, color, 8, 10, 0.35)
	if target == player then
		Sounds.play("ping", 1.2, 0.4)
	end
end

function Fx.levelUp()
	local root = getRoot()
	if not root then
		return
	end
	ring(root.Position - Vector3.new(0, 2.8, 0), 14, UI.Colors.Gold, 0.7)
	local pillar = effectPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(14, 4, 4), CFrame = CFrame.new(root.Position + Vector3.new(0, 4, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = UI.Colors.Gold, Material = Enum.Material.Neon, Transparency = 0.4 })
	TweenService:Create(pillar, TweenInfo.new(0.8), { Size = Vector3.new(40, 0.3, 0.3), Transparency = 1 }):Play()
	Debris:AddItem(pillar, 0.85)
	burst(root.Position, UI.Colors.Gold, 16, 30, 0.5)
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
		local now = os.clock()
		-- tremida de câmera
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			if now < shakeUntil then
				humanoid.CameraOffset = Vector3.new((math.random() - 0.5) * shakeStrength, (math.random() - 0.5) * shakeStrength, 0)
				shaking = true
			elseif shaking then
				humanoid.CameraOffset = Vector3.zero
				shaking = false
			end
		end
		-- projéteis
		for id, projectile in projectiles do
			local traveled = (now - projectile.start) * projectile.speed
			if traveled > projectile.range + 5 then
				projectiles[id] = nil
				projectile.part:Destroy()
			else
				local position = projectile.origin + projectile.direction * traveled
				projectile.part.CFrame = CFrame.lookAt(position, position + projectile.direction)
			end
		end
		-- arco-íris (raridade Secreta)
		local color = Color3.fromHSV((now * 0.3) % 1, 0.75, 1)
		for _, part in CollectionService:GetTagged("Rainbow") do
			if part:IsA("BasePart") then
				part.Color = color
			end
		end
		for guiObject, property in rainbowGuis do
			guiObject[property] = color
		end
		-- objetos que giram
		for _, part in CollectionService:GetTagged("Spin") do
			if part:IsA("BasePart") then
				part.CFrame *= CFrame.Angles(0, dt * 1.2, 0)
			end
		end
	end)
end

-- nomes para mensagens
function Fx.materialLabel(id)
	local def = Items.Materials[id] or Items.Consumables[id]
	return if def then def.icon .. " " .. def.name else id
end

function Fx.skillLabel(id)
	local def = Skills.List[id]
	return if def then def.icon .. " " .. def.name else id
end

return Fx
