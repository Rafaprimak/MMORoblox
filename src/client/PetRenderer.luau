-- Desenha e anima os pets de todos os jogadores (atributos "Pet" e "PetLevel" do dono).
-- Cada modelo é feito de peças com um "papel" (perna, asa, cauda...) animado por código:
-- patinhas andando, asas batendo, slime quicando, flutuar e seguir o dono suavemente.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Pets = require(Shared.Pets)

local UI = require(script.Parent.UI)

local PetRenderer = {}

local folder = Instance.new("Folder")
folder.Name = "Pets"
folder.Parent = workspace

local active = {} -- [player] = rec
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local EYE = Color3.fromRGB(25, 25, 30)

-- ===================== MODELOS =====================

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

-- cada peça: { part, offset = CFrame em relação à raiz, role = "body"/"legFL"/... , pivot = ponto de giro }
local function piece(list, part, offset, role, pivot)
	table.insert(list, { part = part, offset = offset, role = role or "static", pivot = pivot or Vector3.zero })
end

local function eyes(model, list, headOffset, spread, size)
	for _, x in { -spread, spread } do
		local eye = newPart(model, Vector3.one * size, EYE, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		piece(list, eye, headOffset * CFrame.new(x, 0, 0), "head")
		local shine = newPart(model, Vector3.one * size * 0.35, Color3.new(1, 1, 1), Enum.Material.Neon, Enum.PartType.Ball)
		piece(list, shine, headOffset * CFrame.new(x + size * 0.15, size * 0.18, -size * 0.3), "head")
	end
end

local BUILDERS = {}

function BUILDERS.slime(model, def, list)
	local body = newPart(model, Vector3.new(2.2, 1.8, 2.2), def.color, Enum.Material.Glass, Enum.PartType.Ball)
	body.Transparency = 0.15
	piece(list, body, CFrame.new(0, 0.9, 0), "squish")
	local core = newPart(model, Vector3.one * 0.8, def.accent, Enum.Material.Neon, Enum.PartType.Ball)
	piece(list, core, CFrame.new(0, 0.8, 0), "squish")
	eyes(model, list, CFrame.new(0, 1.1, -1), 0.4, 0.32)
	return 0
end

function BUILDERS.quadruped(model, def, list)
	local body = newPart(model, Vector3.new(1.3, 1.0, 2.1), def.color)
	piece(list, body, CFrame.new(0, 1.15, 0), "body")
	local belly = newPart(model, Vector3.new(1.0, 0.3, 1.6), def.accent)
	piece(list, belly, CFrame.new(0, 0.7, 0), "body")
	local head = newPart(model, Vector3.new(1.15, 1.0, 1.0), def.color)
	piece(list, head, CFrame.new(0, 1.85, -1.15), "head")
	local snout = newPart(model, Vector3.new(0.6, 0.45, 0.45), def.accent)
	piece(list, snout, CFrame.new(0, 1.7, -1.75), "head")
	local nose = newPart(model, Vector3.new(0.22, 0.18, 0.12), EYE)
	piece(list, nose, CFrame.new(0, 1.85, -1.98), "head")
	eyes(model, list, CFrame.new(0, 2.0, -1.66), 0.28, 0.2)
	for _, x in { -0.35, 0.35 } do
		if def.ears == "floppy" then
			local ear = newPart(model, Vector3.new(0.25, 0.7, 0.45), def.color:Lerp(Color3.new(0, 0, 0), 0.25))
			piece(list, ear, CFrame.new(x * 1.6, 1.95, -1.1) * CFrame.Angles(0, 0, math.rad(x > 0 and -15 or 15)), "head")
		else
			local ear = newPart(model, Vector3.new(0.3, 0.5, 0.25), def.color, nil, Enum.PartType.Wedge)
			piece(list, ear, CFrame.new(x, 2.55, -1.1), "head")
		end
	end
	local legs = { { "legFL", -0.4, -0.7 }, { "legFR", 0.4, -0.7 }, { "legBL", -0.4, 0.7 }, { "legBR", 0.4, 0.7 } }
	for _, leg in legs do
		local part = newPart(model, Vector3.new(0.35, 0.75, 0.35), def.color:Lerp(Color3.new(0, 0, 0), 0.15))
		piece(list, part, CFrame.new(leg[2], 0.4, leg[3]), leg[1], Vector3.new(0, 0.35, 0))
	end
	local tailSize = if def.tail == "big" then Vector3.new(0.55, 0.55, 1.2) else Vector3.new(0.22, 0.22, 0.9)
	local tail = newPart(model, tailSize, def.color)
	piece(list, tail, CFrame.new(0, 1.45, 1.35) * CFrame.Angles(math.rad(-30), 0, 0), "tail", Vector3.new(0, 0, -tailSize.Z / 2))
	if def.tail == "big" then
		local tip = newPart(model, Vector3.new(0.5, 0.5, 0.4), def.accent)
		piece(list, tip, CFrame.new(0, 1.85, 1.95) * CFrame.Angles(math.rad(-30), 0, 0), "tail", Vector3.new(0, -0.4, -1))
	end
	return 0
end

function BUILDERS.bunny(model, def, list)
	local body = newPart(model, Vector3.new(1.4, 1.3, 1.6), def.color, nil, Enum.PartType.Ball)
	piece(list, body, CFrame.new(0, 0.75, 0), "body")
	local head = newPart(model, Vector3.new(1.1, 1.0, 1.0), def.color, nil, Enum.PartType.Ball)
	piece(list, head, CFrame.new(0, 1.55, -0.6), "head")
	eyes(model, list, CFrame.new(0, 1.65, -1.05), 0.25, 0.2)
	local nose = newPart(model, Vector3.new(0.18, 0.14, 0.1), def.accent)
	piece(list, nose, CFrame.new(0, 1.48, -1.1), "head")
	for _, x in { -0.25, 0.25 } do
		local ear = newPart(model, Vector3.new(0.28, 1.1, 0.18), def.color)
		piece(list, ear, CFrame.new(x, 2.4, -0.5) * CFrame.Angles(0, 0, math.rad(x > 0 and -10 or 10)), "ears", Vector3.new(0, -0.5, 0))
		local inner = newPart(model, Vector3.new(0.14, 0.8, 0.05), def.accent)
		piece(list, inner, CFrame.new(x, 2.4, -0.6) * CFrame.Angles(0, 0, math.rad(x > 0 and -10 or 10)), "ears", Vector3.new(0, -0.5, 0.1))
	end
	local tail = newPart(model, Vector3.one * 0.45, Color3.new(1, 1, 1), nil, Enum.PartType.Ball)
	piece(list, tail, CFrame.new(0, 0.85, 0.85), "body")
	return 0
end

function BUILDERS.bird(model, def, list)
	local body = newPart(model, Vector3.new(1.2, 1.3, 1.3), def.color, nil, Enum.PartType.Ball)
	piece(list, body, CFrame.new(0, 0, 0), "body")
	local face = newPart(model, Vector3.new(1.0, 0.9, 0.3), def.accent)
	piece(list, face, CFrame.new(0, 0.25, -0.55), "head")
	eyes(model, list, CFrame.new(0, 0.35, -0.72), 0.24, 0.26)
	local beak = newPart(model, Vector3.new(0.22, 0.28, 0.3), Color3.fromRGB(255, 190, 60), nil, Enum.PartType.Wedge)
	piece(list, beak, CFrame.new(0, 0.05, -0.8) * CFrame.Angles(math.rad(180), 0, 0), "head")
	for _, side in { -1, 1 } do
		local wing = newPart(model, Vector3.new(1.0, 0.15, 0.8), def.color:Lerp(def.accent, 0.3))
		piece(list, wing, CFrame.new(side * 0.95, 0.1, 0.1), if side < 0 then "wingL" else "wingR", Vector3.new(-side * 0.5, 0, 0))
	end
	local tail = newPart(model, Vector3.new(0.6, 0.12, 0.6), def.accent)
	piece(list, tail, CFrame.new(0, -0.3, 0.75) * CFrame.Angles(math.rad(25), 0, 0), "tail", Vector3.new(0, 0, -0.3))
	return 2.6
end

function BUILDERS.turtle(model, def, list)
	local shell = newPart(model, Vector3.new(1.9, 1.0, 2.2), def.accent, Enum.Material.Wood, Enum.PartType.Ball)
	piece(list, shell, CFrame.new(0, 0.85, 0), "body")
	local rim = newPart(model, Vector3.new(2.0, 0.25, 2.3), def.color)
	piece(list, rim, CFrame.new(0, 0.5, 0), "body")
	local head = newPart(model, Vector3.new(0.7, 0.6, 0.7), def.color, nil, Enum.PartType.Ball)
	piece(list, head, CFrame.new(0, 0.75, -1.35), "head")
	eyes(model, list, CFrame.new(0, 0.85, -1.62), 0.18, 0.15)
	for _, leg in { { "legFL", -0.7, -0.7 }, { "legFR", 0.7, -0.7 }, { "legBL", -0.7, 0.7 }, { "legBR", 0.7, 0.7 } } do
		local part = newPart(model, Vector3.new(0.45, 0.45, 0.5), def.color)
		piece(list, part, CFrame.new(leg[2], 0.3, leg[3]), leg[1], Vector3.new(0, 0.2, 0))
	end
	return 0
end

function BUILDERS.golem(model, def, list)
	local body = newPart(model, Vector3.new(1.6, 1.4, 1.1), def.color, Enum.Material.Slate)
	piece(list, body, CFrame.new(0, 1.4, 0), "body")
	local head = newPart(model, Vector3.new(1.0, 0.8, 0.9), def.color, Enum.Material.Slate)
	piece(list, head, CFrame.new(0, 2.5, -0.05), "head")
	for _, x in { -0.22, 0.22 } do
		local eye = newPart(model, Vector3.new(0.2, 0.12, 0.08), def.accent, Enum.Material.Neon)
		piece(list, eye, CFrame.new(x, 2.55, -0.52), "head")
	end
	local gem = newPart(model, Vector3.new(0.45, 0.45, 0.12), def.accent, Enum.Material.Neon)
	piece(list, gem, CFrame.new(0, 1.5, -0.58), "body")
	for _, side in { -1, 1 } do
		local arm = newPart(model, Vector3.new(0.5, 1.2, 0.55), def.color, Enum.Material.Slate)
		piece(list, arm, CFrame.new(side * 1.1, 1.3, 0), if side < 0 then "legFL" else "legFR", Vector3.new(0, 0.5, 0))
		local leg = newPart(model, Vector3.new(0.55, 0.7, 0.6), def.color, Enum.Material.Slate)
		piece(list, leg, CFrame.new(side * 0.45, 0.35, 0), if side < 0 then "legBL" else "legBR", Vector3.new(0, 0.3, 0))
	end
	return 0
end

function BUILDERS.wisp(model, def, list)
	local core = newPart(model, Vector3.one * 0.9, def.color, Enum.Material.Neon, Enum.PartType.Ball)
	piece(list, core, CFrame.new(), "squish")
	local halo = newPart(model, Vector3.one * 1.6, def.accent, Enum.Material.ForceField, Enum.PartType.Ball)
	piece(list, halo, CFrame.new(), "squish")
	for _, side in { -1, 1 } do
		local wing = newPart(model, Vector3.new(0.9, 0.05, 0.6), def.accent, Enum.Material.Neon)
		wing.Transparency = 0.4
		piece(list, wing, CFrame.new(side * 0.7, 0.2, 0.2), if side < 0 then "wingL" else "wingR", Vector3.new(-side * 0.45, 0, 0))
	end
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Color = ColorSequence.new(def.color, def.accent)
	sparkles.LightEmission = 1
	sparkles.Size = NumberSequence.new(0.2, 0)
	sparkles.Lifetime = NumberRange.new(0.5, 1)
	sparkles.Rate = 12
	sparkles.Speed = NumberRange.new(0.3, 0.8)
	sparkles.Parent = core
	return 3
end

function BUILDERS.dragon(model, def, list)
	local body = newPart(model, Vector3.new(1.1, 1.0, 1.7), def.color)
	piece(list, body, CFrame.new(0, 0, 0), "body")
	local belly = newPart(model, Vector3.new(0.8, 0.3, 1.3), def.accent)
	piece(list, belly, CFrame.new(0, -0.4, 0), "body")
	local head = newPart(model, Vector3.new(0.9, 0.8, 0.9), def.color)
	piece(list, head, CFrame.new(0, 0.55, -1.1), "head")
	local snout = newPart(model, Vector3.new(0.6, 0.4, 0.55), def.color)
	piece(list, snout, CFrame.new(0, 0.4, -1.65), "head")
	eyes(model, list, CFrame.new(0, 0.75, -1.5), 0.25, 0.18)
	for _, x in { -0.25, 0.25 } do
		local horn = newPart(model, Vector3.new(0.15, 0.5, 0.15), def.accent)
		piece(list, horn, CFrame.new(x, 1.1, -0.95) * CFrame.Angles(math.rad(-25), 0, 0), "head")
	end
	for _, side in { -1, 1 } do
		local wing = newPart(model, Vector3.new(1.5, 0.1, 1.1), def.accent:Lerp(def.color, 0.4))
		piece(list, wing, CFrame.new(side * 1.2, 0.35, 0.1), if side < 0 then "wingL" else "wingR", Vector3.new(-side * 0.75, 0, 0))
	end
	local tail = newPart(model, Vector3.new(0.35, 0.35, 1.4), def.color)
	piece(list, tail, CFrame.new(0, -0.1, 1.45), "tail", Vector3.new(0, 0, -0.7))
	local fire = newPart(model, Vector3.one * 0.4, Color3.fromRGB(255, 200, 80), Enum.Material.Neon, Enum.PartType.Ball)
	piece(list, fire, CFrame.new(0, 0, 2.2), "tail", Vector3.new(0, 0, -1.45))
	return 3
end

local function build(petId, level)
	local def = Pets.List[petId]
	if not def then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "Pet_" .. petId
	local list = {}
	local builder = BUILDERS[def.shape] or BUILDERS.slime
	local hover = builder(model, def, list)
	if def.glow and list[1] then
		local light = Instance.new("PointLight")
		light.Color = def.color
		light.Range = 8
		light.Brightness = 1.2
		light.Parent = list[1].part
	end
	-- nível em cima do pet
	local tag = UI.new("BillboardGui", { Size = UDim2.fromOffset(90, 18), StudsOffset = Vector3.new(0, 2.6, 0), MaxDistance = 45, LightInfluence = 0, Adornee = list[1].part, Parent = list[1].part })
	local label = UI.label({ Text = ("%s Nv. %d"):format(def.name, level or 1), Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Color3.fromRGB(220, 255, 230), Parent = tag }, { UI.textStroke(1) })
	model.Parent = folder
	return { model = model, pieces = list, def = def, hover = hover, label = label }
end

-- ===================== ANIMAÇÃO =====================

local function animate(entry, t, moving, flying)
	local role = entry.role
	local walk = if moving then math.sin(t * 14) else 0
	local angle = CFrame.identity
	if role == "legFL" or role == "legBR" then
		angle = CFrame.Angles(walk * 0.7, 0, 0)
	elseif role == "legFR" or role == "legBL" then
		angle = CFrame.Angles(-walk * 0.7, 0, 0)
	elseif role == "wingL" then
		angle = CFrame.Angles(0, 0, math.sin(t * (if moving then 16 else 9)) * 0.7)
	elseif role == "wingR" then
		angle = CFrame.Angles(0, 0, -math.sin(t * (if moving then 16 else 9)) * 0.7)
	elseif role == "tail" then
		angle = CFrame.Angles(0, math.sin(t * (if moving then 10 else 4)) * 0.35, 0)
	elseif role == "head" then
		angle = CFrame.Angles(math.sin(t * 2) * 0.05, math.sin(t * 0.7) * 0.12, 0)
	elseif role == "ears" then
		angle = CFrame.Angles(math.sin(t * 3) * 0.12 + (if moving then 0.25 else 0), 0, 0)
	end
	if angle == CFrame.identity then
		return entry.offset
	end
	-- gira em volta do pivô da peça
	local pivot = entry.pivot
	return entry.offset * CFrame.new(pivot) * angle * CFrame.new(-pivot)
end

local function groundY(position, owner)
	rayParams.FilterDescendantsInstances = { folder, owner.Character, workspace:FindFirstChild("Efeitos") }
	local result = workspace:Raycast(position + Vector3.new(0, 12, 0), Vector3.new(0, -40, 0), rayParams)
	return if result then result.Position.Y else nil
end

local function update(owner, rec, dt, now)
	local character = owner.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		rec.model.Parent = nil
		return
	end
	rec.model.Parent = folder
	local flying = rec.def.fly == true
	-- alvo: atrás e ao lado do dono
	local side = if rec.side then rec.side else 1
	local goal = (root.CFrame * CFrame.new(2.6 * side, 0, 2.8)).Position
	local position = rec.position or goal
	if (position - goal).Magnitude > 60 then
		position = goal
	end
	local offset = Vector3.new(goal.X - position.X, 0, goal.Z - position.Z)
	local distance = offset.Magnitude
	local moving = distance > 0.6
	if moving then
		local speed = math.clamp(distance * 4, 6, 60)
		position += offset.Unit * math.min(distance, speed * dt)
	end
	-- altura: chão (com pulinho) ou flutuando ao lado do dono
	local y
	if flying then
		y = root.Position.Y + 0.8 + math.sin(now * 2.4) * 0.35
	else
		rec.groundTimer = (rec.groundTimer or 0) - dt
		if rec.groundTimer <= 0 or not rec.ground then
			rec.groundTimer = 0.15
			rec.ground = groundY(position, owner) or (root.Position.Y - 3)
		end
		local hop = if moving and rec.def.shape ~= "turtle" then math.abs(math.sin(now * 9)) * 0.45 else 0
		y = rec.ground + hop
	end
	position = Vector3.new(position.X, y, position.Z)
	rec.position = position
	-- olha para onde anda (ou para a frente do dono parado)
	local look = if moving then offset.Unit else root.CFrame.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude < 0.01 then
		look = Vector3.new(0, 0, -1)
	end
	local targetYaw = math.atan2(-look.X, -look.Z)
	rec.yaw = rec.yaw or targetYaw
	local delta = (targetYaw - rec.yaw + math.pi) % (2 * math.pi) - math.pi
	rec.yaw += delta * math.min(1, dt * 8)
	local base = CFrame.new(position) * CFrame.Angles(0, rec.yaw, 0)
	-- slime: achata e estica
	local parts, frames = {}, {}
	for _, entry in rec.pieces do
		local cf = base * animate(entry, now + rec.phase, moving, flying)
		if entry.role == "squish" then
			local squish = math.sin(now * (if moving then 12 else 4)) * (if moving then 0.18 else 0.07)
			cf = base * CFrame.new(0, squish * 0.5, 0) * entry.offset
			entry.part.Size = entry.baseSize * Vector3.new(1 - squish * 0.5, 1 + squish, 1 - squish * 0.5)
		end
		table.insert(parts, entry.part)
		table.insert(frames, cf)
	end
	workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
end

local function refresh(owner)
	local old = active[owner]
	local petId = owner:GetAttribute("Pet")
	local level = owner:GetAttribute("PetLevel") or 1
	if old and old.id == petId then
		old.label.Text = ("%s Nv. %d"):format(old.def.name, level)
		return
	end
	if old then
		old.model:Destroy()
		active[owner] = nil
	end
	if not petId then
		return
	end
	local rec = build(petId, level)
	if not rec then
		return
	end
	for _, entry in rec.pieces do
		entry.baseSize = entry.part.Size
	end
	rec.id = petId
	rec.phase = math.random() * 10
	rec.side = if owner == Players.LocalPlayer then 1 else -1
	active[owner] = rec
end

local function watch(owner)
	owner:GetAttributeChangedSignal("Pet"):Connect(function()
		refresh(owner)
	end)
	owner:GetAttributeChangedSignal("PetLevel"):Connect(function()
		refresh(owner)
	end)
	refresh(owner)
end

function PetRenderer.init()
	for _, owner in Players:GetPlayers() do
		watch(owner)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(owner)
		local rec = active[owner]
		if rec then
			rec.model:Destroy()
			active[owner] = nil
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()
		for owner, rec in active do
			update(owner, rec, math.min(dt, 0.1), now)
		end
	end)
end

-- modelo de exemplo (para a janela de pets)
PetRenderer.build = build

return PetRenderer
