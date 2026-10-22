-- Vida da vila no cliente: moradores andando e conversando, galinhas, gatos e cachorro, pássaros
-- voando, borboletas de dia e vaga-lumes à noite. As posições vêm do módulo Townsfolk (determinístico
-- pelo relógio do servidor), então todos os jogadores veem a mesma cena sem tráfego de rede.
-- Só atualiza quando o jogador está perto da vila.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared.World)
local Townsfolk = require(Shared.Townsfolk)

local UI = require(script.Parent.UI)

local TownLife = {}

local ACTIVE_RANGE = 320 -- studs do centro da vila
local folder = Instance.new("Folder")
folder.Name = "VidaDaVila"

local BLACK = Color3.fromRGB(25, 25, 30)
local villagers = {}
local critters = {}
local birds = {}
local butterflies = {}
local fireflies = {}

local function newPart(model, size, color, material, shape)
	local p = Instance.new("Part")
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = model
	return p
end

-- peça com papel (role) e ponto de giro (pivot), em coordenadas locais (pés na origem, frente em -Z)
local function piece(list, part, offset, role, pivot)
	table.insert(list, { part = part, offset = offset, role = role or "body", pivot = pivot or Vector3.zero })
end

-- ===================== MORADORES =====================

local function buildVillager(def)
	local model = Instance.new("Model")
	model.Name = def.name
	local list = {}
	local scale = if def.child then 0.72 else 1.15
	local function add(size, position, color, role, pivot, material, shape, rotation)
		local p = newPart(model, size * scale, color, material, shape)
		piece(list, p, CFrame.new(position * scale) * (rotation or CFrame.identity), role, (pivot or Vector3.zero) * scale)
		return p
	end
	-- pernas e sapatos
	for _, side in { -1, 1 } do
		local role = if side < 0 then "legL" else "legR"
		local pivot = Vector3.new(side * 0.35, 1.6, 0)
		add(Vector3.new(0.6, 1.5, 0.6), Vector3.new(side * 0.35, 0.85, 0), def.pants, role, pivot)
		add(Vector3.new(0.62, 0.3, 0.8), Vector3.new(side * 0.35, 0.15, -0.08), Color3.fromRGB(60, 40, 30), role, pivot)
	end
	-- tronco (vestido ou camisa) e cinto
	add(Vector3.new(1.6, 1.6, 0.8), Vector3.new(0, 2.4, 0), def.shirt, "torso")
	if def.dress then
		add(Vector3.new(1.75, 1.2, 1.0), Vector3.new(0, 1.5, 0), def.shirt:Lerp(BLACK, 0.12), "torso", nil, Enum.Material.Fabric)
		add(Vector3.new(1.65, 0.2, 0.85), Vector3.new(0, 2.05, 0), Color3.fromRGB(245, 240, 225), "torso")
	else
		add(Vector3.new(1.65, 0.22, 0.85), Vector3.new(0, 1.7, 0), Color3.fromRGB(70, 45, 30), "torso")
	end
	-- braços e mãos
	for _, side in { -1, 1 } do
		local role = if side < 0 then "armL" else "armR"
		local pivot = Vector3.new(side * 1.05, 3.1, 0)
		add(Vector3.new(0.5, 1.4, 0.5), Vector3.new(side * 1.05, 2.5, 0), def.shirt, role, pivot)
		add(Vector3.new(0.45, 0.4, 0.45), Vector3.new(side * 1.05, 1.65, 0), def.skin, role, pivot)
	end
	-- cabeça, olhos, boca e cabelo
	local neck = Vector3.new(0, 3.2, 0)
	add(Vector3.new(1.1, 1.1, 1.1), Vector3.new(0, 3.75, 0), def.skin, "head", neck)
	for _, x in { -0.22, 0.22 } do
		add(Vector3.new(0.14, 0.2, 0.06), Vector3.new(x, 3.82, -0.56), BLACK, "head", neck)
	end
	add(Vector3.new(0.35, 0.07, 0.06), Vector3.new(0, 3.5, -0.56), Color3.fromRGB(150, 70, 60), "head", neck)
	add(Vector3.new(1.16, 0.32, 1.16), Vector3.new(0, 4.3, 0.02), def.hair, "head", neck)
	add(Vector3.new(1.16, if def.dress then 1.0 else 0.7, 0.28), Vector3.new(0, if def.dress then 3.7 else 3.9, 0.48), def.hair, "head", neck)
	if def.old then
		add(Vector3.new(0.5, 0.18, 0.08), Vector3.new(0, 3.62, -0.58), Color3.fromRGB(220, 220, 225), "head", neck) -- bigode
	end
	-- chapéus
	if def.hat == "cap" then
		add(Vector3.new(1.2, 0.35, 1.2), Vector3.new(0, 4.45, 0), def.shirt:Lerp(BLACK, 0.3), "head", neck)
		add(Vector3.new(1.0, 0.1, 0.6), Vector3.new(0, 4.3, -0.75), def.shirt:Lerp(BLACK, 0.3), "head", neck)
	elseif def.hat == "straw" then
		add(Vector3.new(0.12, 2.0, 2.0), Vector3.new(0, 4.4, 0), Color3.fromRGB(225, 195, 110), "head", neck, Enum.Material.Fabric, Enum.PartType.Cylinder, CFrame.Angles(0, 0, math.rad(90)))
		add(Vector3.new(0.45, 1.1, 1.1), Vector3.new(0, 4.6, 0), Color3.fromRGB(225, 195, 110), "head", neck, Enum.Material.Fabric, Enum.PartType.Cylinder, CFrame.Angles(0, 0, math.rad(90)))
	elseif def.hat == "helmet" then
		add(Vector3.new(1.25, 0.6, 1.25), Vector3.new(0, 4.4, 0), Color3.fromRGB(150, 150, 160), "head", neck, Enum.Material.Metal)
		add(Vector3.new(0.16, 0.4, 1.0), Vector3.new(0, 4.8, 0), Color3.fromRGB(180, 40, 40), "head", neck, Enum.Material.Fabric)
	elseif def.hat == "bandana" then
		add(Vector3.new(1.2, 0.3, 1.2), Vector3.new(0, 4.25, 0), Color3.fromRGB(170, 40, 40), "head", neck, Enum.Material.Fabric)
	elseif def.hat == "scarf" then
		add(Vector3.new(1.22, 0.9, 1.22), Vector3.new(0, 4.1, 0.05), Color3.fromRGB(230, 120, 140), "head", neck, Enum.Material.Fabric)
	end
	-- acessórios
	if def.guard then
		add(Vector3.new(0.18, 5.2, 0.18), Vector3.new(1.05, 3.0, -0.2), Color3.fromRGB(100, 70, 40), "armR", Vector3.new(1.05, 3.1, 0), Enum.Material.Wood)
		add(Vector3.new(0.3, 0.7, 0.12), Vector3.new(1.05, 5.8, -0.2), Color3.fromRGB(170, 170, 180), "armR", Vector3.new(1.05, 3.1, 0), Enum.Material.Metal)
		add(Vector3.new(0.2, 1.4, 1.1), Vector3.new(-1.4, 2.4, 0), Color3.fromRGB(40, 70, 150), "armL", Vector3.new(-1.05, 3.1, 0))
		add(Vector3.new(0.22, 0.5, 0.5), Vector3.new(-1.42, 2.4, 0), Color3.fromRGB(230, 190, 80), "armL", Vector3.new(-1.05, 3.1, 0), Enum.Material.Metal)
	end
	if def.basket then
		add(Vector3.new(0.9, 0.6, 0.7), Vector3.new(-1.05, 1.5, -0.3), Color3.fromRGB(170, 120, 60), "armL", Vector3.new(-1.05, 3.1, 0), Enum.Material.WoodPlanks)
		for i = -1, 1 do
			add(Vector3.one * 0.3, Vector3.new(-1.05 + i * 0.25, 1.9, -0.3), Color3.fromRGB(220, 50, 50), "armL", Vector3.new(-1.05, 3.1, 0), nil, Enum.PartType.Ball)
		end
	end
	-- balão de fala
	local head = list[#list].part
	for _, entry in list do
		if entry.role == "head" then
			head = entry.part
			break
		end
	end
	local bubble = UI.new("BillboardGui", { Size = UDim2.fromOffset(240, 46), StudsOffset = Vector3.new(0, 3.2 * scale, 0), MaxDistance = 45, LightInfluence = 0, Enabled = false, Adornee = head, Parent = head })
	local frame = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 252, 240), BackgroundTransparency = 0.05, Parent = bubble }, { UI.corner(10), UI.stroke(Color3.fromRGB(90, 70, 50), 1.5) })
	local text = UI.label({ Text = "", Position = UDim2.fromOffset(8, 4), Size = UDim2.new(1, -16, 1, -8), TextScaled = true, TextWrapped = true, TextColor3 = Color3.fromRGB(50, 40, 30), Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center, Parent = frame })
	local nameTag = UI.new("BillboardGui", { Size = UDim2.fromOffset(120, 16), StudsOffset = Vector3.new(0, 1.3 * scale, 0), MaxDistance = 30, LightInfluence = 0, Adornee = head, Parent = head })
	UI.label({ Text = def.name, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Color3.fromRGB(230, 225, 210), Parent = nameTag }, { UI.textStroke(1) })
	model.Parent = folder
	return { model = model, pieces = list, def = def, bubble = bubble, text = text, yaw = 0 }
end

local function villagerPose(entry, t, walking, talking, def)
	local role = entry.role
	local swing = if walking then math.sin(t * (if def.child then 11 else 8)) else 0
	local angle
	if role == "legL" then
		angle = CFrame.Angles(swing * 0.6, 0, 0)
	elseif role == "legR" then
		angle = CFrame.Angles(-swing * 0.6, 0, 0)
	elseif role == "armL" then
		angle = if def.basket then CFrame.Angles(math.rad(10), 0, 0) else CFrame.Angles(-swing * 0.5, 0, math.rad(4))
	elseif role == "armR" then
		if def.guard then
			angle = CFrame.Angles(math.rad(10), 0, 0)
		elseif talking then
			angle = CFrame.Angles(math.rad(35 + math.sin(t * 3) * 20), 0, math.rad(-10))
		else
			angle = CFrame.Angles(swing * 0.5, 0, math.rad(-4))
		end
	elseif role == "head" then
		angle = CFrame.Angles(math.sin(t * 0.9) * 0.06, if walking then 0 else math.sin(t * 0.5) * 0.4, 0)
	elseif role == "torso" and def.old then
		angle = CFrame.Angles(math.rad(-10), 0, 0)
	end
	if not angle then
		return entry.offset
	end
	local pivot = entry.pivot
	return CFrame.new(pivot) * angle * CFrame.new(-pivot) * entry.offset
end

-- ===================== ANIMAIS =====================

local function buildCritter(def)
	local model = Instance.new("Model")
	model.Name = def.kind
	local list = {}
	local function add(size, position, color, role, pivot, material, shape, rotation)
		local p = newPart(model, size, color, material, shape)
		piece(list, p, CFrame.new(position) * (rotation or CFrame.identity), role, pivot)
		return p
	end
	if def.kind == "galinha" then
		add(Vector3.new(0.9, 0.85, 1.1), Vector3.new(0, 0.85, 0), def.color, "body", nil, nil, Enum.PartType.Ball)
		add(Vector3.new(0.3, 0.6, 0.5), Vector3.new(0, 1.1, 0.6), def.color, "body", nil, nil, nil, CFrame.Angles(math.rad(-30), 0, 0))
		local neck = Vector3.new(0, 1.1, -0.35)
		add(Vector3.one * 0.55, Vector3.new(0, 1.45, -0.5), def.color, "head", neck, nil, Enum.PartType.Ball)
		add(Vector3.new(0.12, 0.25, 0.3), Vector3.new(0, 1.78, -0.48), Color3.fromRGB(220, 40, 40), "head", neck)
		add(Vector3.new(0.14, 0.12, 0.22), Vector3.new(0, 1.42, -0.82), Color3.fromRGB(250, 190, 50), "head", neck)
		for _, x in { -0.18, 0.18 } do
			add(Vector3.new(0.06, 0.08, 0.06), Vector3.new(x, 1.52, -0.72), BLACK, "head", neck)
			add(Vector3.new(0.08, 0.5, 0.08), Vector3.new(x, 0.25, 0), Color3.fromRGB(250, 190, 50), if x < 0 then "legL" else "legR", Vector3.new(x, 0.5, 0))
		end
	else
		-- gato / cachorro
		local dog = def.kind == "cachorro"
		local size = if dog then 1.25 else 0.9
		local function scaled(v)
			return v * size
		end
		add(scaled(Vector3.new(0.9, 0.75, 1.6)), scaled(Vector3.new(0, 0.95, 0)), def.color, "body")
		local neck = scaled(Vector3.new(0, 1.2, -0.7))
		add(scaled(Vector3.new(0.85, 0.75, 0.75)), scaled(Vector3.new(0, 1.5, -1.0)), def.color, "head", neck)
		add(scaled(Vector3.new(0.45, 0.35, 0.35)), scaled(Vector3.new(0, 1.35, -1.45)), def.color:Lerp(Color3.new(1, 1, 1), 0.3), "head", neck)
		add(scaled(Vector3.new(0.15, 0.12, 0.08)), scaled(Vector3.new(0, 1.45, -1.63)), BLACK, "head", neck)
		for _, x in { -0.22, 0.22 } do
			add(scaled(Vector3.new(0.1, 0.14, 0.05)), scaled(Vector3.new(x, 1.62, -1.38)), BLACK, "head", neck)
			if dog then
				add(scaled(Vector3.new(0.2, 0.5, 0.35)), scaled(Vector3.new(x * 2.1, 1.6, -0.95)), def.color:Lerp(BLACK, 0.25), "head", neck)
			else
				add(scaled(Vector3.new(0.22, 0.35, 0.18)), scaled(Vector3.new(x * 1.3, 2.0, -0.95)), def.color, "head", neck, nil, Enum.PartType.Wedge)
			end
		end
		for _, leg in { { "legFL", -0.3, -0.55 }, { "legFR", 0.3, -0.55 }, { "legBL", -0.3, 0.55 }, { "legBR", 0.3, 0.55 } } do
			add(scaled(Vector3.new(0.25, 0.6, 0.25)), scaled(Vector3.new(leg[2], 0.3, leg[3])), def.color:Lerp(BLACK, 0.1), leg[1], scaled(Vector3.new(leg[2], 0.6, leg[3])))
		end
		add(scaled(Vector3.new(0.15, 0.15, 0.9)), scaled(Vector3.new(0, 1.3, 1.1)), def.color, "tail", scaled(Vector3.new(0, 1.1, 0.75)), nil, nil, CFrame.Angles(math.rad(if dog then 30 else 50), 0, 0))
	end
	model.Parent = folder
	return { model = model, pieces = list, def = def, yaw = 0 }
end

local function critterPose(entry, t, moving, kind)
	local role = entry.role
	local walk = if moving then math.sin(t * 13) else 0
	local angle
	if role == "legFL" or role == "legBR" or role == "legL" then
		angle = CFrame.Angles(walk * 0.6, 0, 0)
	elseif role == "legFR" or role == "legBL" or role == "legR" then
		angle = CFrame.Angles(-walk * 0.6, 0, 0)
	elseif role == "tail" then
		angle = CFrame.Angles(0, math.sin(t * (if kind == "cachorro" then 9 else 2.5)) * 0.5, 0)
	elseif role == "head" then
		if kind == "galinha" and not moving then
			-- bicando o chão
			local peck = math.max(0, math.sin(t * 5)) ^ 3
			angle = CFrame.Angles(math.rad(-70 * peck), 0, 0)
		else
			angle = CFrame.Angles(0, math.sin(t * 0.8) * 0.35, 0)
		end
	end
	if not angle then
		return entry.offset
	end
	local pivot = entry.pivot
	return CFrame.new(pivot) * angle * CFrame.new(-pivot) * entry.offset
end

-- ===================== PÁSSAROS, BORBOLETAS E VAGA-LUMES =====================

local function buildBird()
	local model = Instance.new("Model")
	model.Name = "Passaro"
	local body = newPart(model, Vector3.new(0.45, 0.35, 1.0), Color3.fromRGB(50, 50, 60))
	local wings = {}
	for _, side in { -1, 1 } do
		table.insert(wings, { part = newPart(model, Vector3.new(1.3, 0.08, 0.55), Color3.fromRGB(70, 70, 80)), side = side })
	end
	model.Parent = folder
	return { model = model, body = body, wings = wings, phase = math.random() * 10, radius = math.random(45, 85), height = math.random(38, 55), speed = 0.12 + math.random() * 0.08 }
end

local function buildButterfly()
	local model = Instance.new("Model")
	model.Name = "Borboleta"
	local color = Color3.fromHSV(math.random(), 0.6, 1)
	local wings = {}
	for _, side in { -1, 1 } do
		table.insert(wings, { part = newPart(model, Vector3.new(0.45, 0.04, 0.4), color, Enum.Material.Neon), side = side })
	end
	model.Parent = folder
	local angle = math.random(0, 359)
	return { model = model, wings = wings, center = Townsfolk.point(angle, math.random(12, 40)), phase = math.random() * 10 }
end

local function buildFireflies()
	for i = 1, 8 do
		local anchor = newPart(folder, Vector3.one * 0.2, Color3.new(1, 1, 1))
		anchor.Transparency = 1
		anchor.Position = Townsfolk.point(i * 45 + 10, 25 + (i % 3) * 10) + Vector3.new(0, 3, 0)
		local emitter = Instance.new("ParticleEmitter")
		emitter.Color = ColorSequence.new(Color3.fromRGB(220, 255, 120))
		emitter.LightEmission = 1
		emitter.LightInfluence = 0
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.25), NumberSequenceKeypoint.new(1, 0) })
		emitter.Lifetime = NumberRange.new(2, 4)
		emitter.Rate = 3
		emitter.Speed = NumberRange.new(0.3, 1)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Acceleration = Vector3.new(0, 0.3, 0)
		emitter.Shape = Enum.ParticleEmitterShape.Box
		emitter.Enabled = false
		emitter.Parent = anchor
		anchor.Size = Vector3.new(14, 4, 14)
		table.insert(fireflies, emitter)
	end
end

-- ===================== LAÇO =====================

local function yawTowards(direction, current, dt)
	if direction.Magnitude < 0.01 then
		return current
	end
	local target = math.atan2(-direction.X, -direction.Z)
	local delta = (target - current + math.pi) % (2 * math.pi) - math.pi
	return current + delta * math.min(1, dt * 6)
end

local function update(dt)
	local t = workspace:GetServerTimeNow()
	local now = os.clock()
	local night = workspace:GetAttribute("Night") == true
	local parts, frames = {}, {}

	for index, rec in villagers do
		local position, direction, walking, stopIndex = Townsfolk.villagerState(index, t)
		rec.yaw = yawTowards(if walking then direction else (direction * 0.0001), rec.yaw, dt)
		local talking = not walking and stopIndex % 3 == 0
		rec.bubble.Enabled = talking
		if talking then
			rec.text.Text = Townsfolk.Lines[(stopIndex * 7 + index) % #Townsfolk.Lines + 1]
		end
		local bob = if walking then math.abs(math.sin(now * 8)) * 0.12 else 0
		local base = CFrame.new(position + Vector3.new(0, bob, 0)) * CFrame.Angles(0, rec.yaw, 0)
		for _, entry in rec.pieces do
			table.insert(parts, entry.part)
			table.insert(frames, base * villagerPose(entry, now + index, walking, talking, rec.def))
		end
	end

	for index, rec in critters do
		local position, direction, moving = Townsfolk.critterState(index, t)
		rec.yaw = yawTowards(direction, rec.yaw, dt)
		local hop = if moving and rec.def.kind == "galinha" then math.abs(math.sin(now * 12)) * 0.15 else 0
		local base = CFrame.new(position + Vector3.new(0, hop, 0)) * CFrame.Angles(0, rec.yaw, 0)
		for _, entry in rec.pieces do
			table.insert(parts, entry.part)
			table.insert(frames, base * critterPose(entry, now + index * 1.7, moving, rec.def.kind))
		end
	end

	-- pássaros só de dia, voando em círculos sobre a vila
	for _, bird in birds do
		bird.model.Parent = if night then nil else folder
		if not night then
			local angle = now * bird.speed + bird.phase
			local center = World.TownCenter
			local position = Vector3.new(center.X + math.cos(angle) * bird.radius, World.TownHeight + bird.height + math.sin(now * 0.7 + bird.phase) * 3, center.Z + math.sin(angle) * bird.radius)
			local forward = Vector3.new(-math.sin(angle), 0, math.cos(angle))
			local cf = CFrame.lookAt(position, position + forward) * CFrame.Angles(0, 0, math.rad(-12))
			table.insert(parts, bird.body)
			table.insert(frames, cf)
			local flap = math.sin(now * 9 + bird.phase) * 0.6
			for _, wing in bird.wings do
				table.insert(parts, wing.part)
				table.insert(frames, cf * CFrame.new(wing.side * 0.2, 0, 0) * CFrame.Angles(0, 0, wing.side * flap) * CFrame.new(wing.side * 0.6, 0, 0))
			end
		end
	end

	-- borboletas de dia
	for _, fly in butterflies do
		fly.model.Parent = if night then nil else folder
		if not night then
			local k = now * 0.6 + fly.phase
			local position = fly.center + Vector3.new(math.sin(k) * 4, 2.5 + math.sin(k * 2.3) * 1.2, math.cos(k * 1.3) * 4)
			local cf = CFrame.new(position) * CFrame.Angles(0, k, 0)
			local flap = math.abs(math.sin(now * 18 + fly.phase)) * 1.2
			for _, wing in fly.wings do
				table.insert(parts, wing.part)
				table.insert(frames, cf * CFrame.Angles(0, 0, wing.side * flap) * CFrame.new(wing.side * 0.22, 0, 0))
			end
		end
	end

	for _, emitter in fireflies do
		emitter.Enabled = night
	end

	if #parts > 0 then
		workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

function TownLife.init()
	for _, def in Townsfolk.Villagers do
		table.insert(villagers, buildVillager(def))
	end
	for _, def in Townsfolk.Critters do
		table.insert(critters, buildCritter(def))
	end
	for _ = 1, 7 do
		table.insert(birds, buildBird())
	end
	for _ = 1, 8 do
		table.insert(butterflies, buildButterfly())
	end
	buildFireflies()

	local player = Players.LocalPlayer
	RunService.RenderStepped:Connect(function(dt)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local near = root ~= nil and (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(World.TownCenter.X, 0, World.TownCenter.Z)).Magnitude < ACTIVE_RANGE
		if not near then
			folder.Parent = nil
			return
		end
		folder.Parent = workspace
		update(math.min(dt, 0.1))
	end)
end

return TownLife
