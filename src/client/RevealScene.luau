-- Cena 3D de revelação (no fundo da tela): uma cópia do SEU personagem abre o baú ou vê o ovo chocar.
-- Usa ViewportFrame + WorldModel (as juntas Motor6D funcionam lá dentro), câmera própria e peças
-- animadas por código. Partículas não aparecem em ViewportFrame, então brilho e raios são peças neon.
--
-- Baú:  local scene = RevealScene.chest(parent, chestColor)  → ajoelha e mexe no baú (antecipação)
--       scene:open(rarityColor, big)  → tampa abre, feixe de luz, item sobe e o personagem ergue o item
-- Ovo:  RevealScene.egg(parent, eggColor, petId)  → ovo balança, racha, explode e o pet aparece
-- Sempre chame scene:destroy() no fim.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PetRenderer = require(script.Parent.PetRenderer)

local RevealScene = {}
RevealScene.__index = RevealScene

local function R(x, y, z)
	return CFrame.Angles(math.rad(x or 0), math.rad(y or 0), math.rad(z or 0))
end

local function smooth(t)
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function newPart(parent, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

local JOINTS = {
	RS = { "RightUpperArm", "RightShoulder" },
	RE = { "RightLowerArm", "RightElbow" },
	LS = { "LeftUpperArm", "LeftShoulder" },
	LE = { "LeftLowerArm", "LeftElbow" },
	W = { "UpperTorso", "Waist" },
	N = { "Head", "Neck" },
	RT = { "LowerTorso", "Root" },
	RH = { "RightUpperLeg", "RightHip" },
	LH = { "LeftUpperLeg", "LeftHip" },
	RK = { "RightLowerLeg", "RightKnee" },
	LK = { "LeftLowerLeg", "LeftKnee" },
}

-- Copia o personagem do jogador para dentro da cena (sem scripts, raiz ancorada)
local function cloneCharacter(worldModel, rootCFrame)
	local character = Players.LocalPlayer.Character
	if not character then
		return nil
	end
	local old = character.Archivable
	character.Archivable = true
	local ok, copy = pcall(function()
		return character:Clone()
	end)
	character.Archivable = old
	if not ok or not copy then
		return nil
	end
	for _, item in copy:GetDescendants() do
		if item:IsA("Script") or item:IsA("LocalScript") or item:IsA("BillboardGui") or item:IsA("ParticleEmitter") or item:IsA("Sound") then
			item:Destroy()
		elseif item:IsA("BasePart") then
			item.CanCollide = false
			item.Anchored = false
		end
	end
	local humanoid = copy:FindFirstChildOfClass("Humanoid")
	local root = copy:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		copy:Destroy()
		return nil
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	root.Anchored = true
	local height = humanoid.HipHeight + root.Size.Y / 2
	root.CFrame = rootCFrame * CFrame.new(0, height, 0)
	copy.Parent = worldModel
	local motors = {}
	for key, path in JOINTS do
		local part = copy:FindFirstChild(path[1])
		local motor = part and part:FindFirstChild(path[2])
		if motor and motor:IsA("Motor6D") then
			motors[key] = motor
		end
	end
	return { model = copy, motors = motors, root = root }
end

local function pose(actor, joints)
	if not actor then
		return
	end
	for key, motor in actor.motors do
		motor.Transform = joints[key] or CFrame.identity
	end
end

-- mistura duas poses (tabelas de juntas)
local function blend(a, b, t)
	local result = {}
	for key, cf in a do
		result[key] = cf:Lerp(b[key] or CFrame.identity, t)
	end
	for key, cf in b do
		if not result[key] then
			result[key] = CFrame.identity:Lerp(cf, t)
		end
	end
	return result
end

local STAND = {}
local KNEEL = { RT = CFrame.new(0, -1.1, 0) * R(-12), RH = R(70), RK = R(-80), LH = R(-10), LK = R(-75), RS = R(25), LS = R(25), N = R(-15) }
local REACH = { RT = CFrame.new(0, -1.1, 0) * R(-22), RH = R(70), RK = R(-80), LH = R(-10), LK = R(-75), RS = R(75, 0, 10), LS = R(75, 0, -10), RE = R(25), LE = R(25), N = R(-20) }
local LIFT = { RS = R(175, 0, 8), RE = R(10), LS = R(30, 0, -20), N = R(18), RT = R(4) }
local CHEER = { RS = R(160, 0, 35), LS = R(160, 0, -35), N = R(15), RT = CFrame.new(0, 0.3, 0) }
local LEAN = { RT = R(-14), RS = R(50, 0, 15), LS = R(50, 0, -15), RE = R(40), LE = R(40), N = R(-12) }

-- monta a viewport, câmera e luz
local function stage(parent)
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "CenaRevelacao"
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(150, 140, 160)
	viewport.LightColor = Color3.fromRGB(255, 240, 220)
	viewport.LightDirection = Vector3.new(-0.5, -1, -0.6)
	viewport.ZIndex = 2
	viewport.Parent = parent
	local worldModel = Instance.new("WorldModel")
	worldModel.Parent = viewport
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	-- chão circular e luz de palco
	newPart(worldModel, Vector3.new(0.4, 16, 16), CFrame.new(0, -0.2, 1.5) * R(0, 0, 90), Color3.fromRGB(60, 50, 70), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	return viewport, worldModel, camera
end

local function makeChest(worldModel, color)
	local base = CFrame.new(0, 0, 0)
	local body = newPart(worldModel, Vector3.new(2.6, 1.6, 1.8), base * CFrame.new(0, 0.8, 0), Color3.fromRGB(110, 75, 45), Enum.Material.Wood)
	local bands = {}
	for _, x in { -0.95, 0.95 } do
		table.insert(bands, newPart(worldModel, Vector3.new(0.25, 1.65, 1.85), base * CFrame.new(x, 0.8, 0), color, Enum.Material.Metal))
	end
	local hinge = base * CFrame.new(0, 1.6, 0.9) -- dobradiça atrás
	local lid = newPart(worldModel, Vector3.new(2.7, 0.7, 1.9), hinge * CFrame.new(0, 0.35, -0.95), color:Lerp(Color3.fromRGB(110, 75, 45), 0.4), Enum.Material.Wood)
	local lock = newPart(worldModel, Vector3.new(0.45, 0.5, 0.15), base * CFrame.new(0, 1.45, -0.95), Color3.fromRGB(255, 210, 80), Enum.Material.Metal)
	local inner = newPart(worldModel, Vector3.new(2.2, 0.1, 1.4), base * CFrame.new(0, 1.55, 0), Color3.fromRGB(255, 240, 180), Enum.Material.Neon)
	inner.Transparency = 1
	return { body = body, bands = bands, lid = lid, lock = lock, inner = inner, hinge = hinge, base = base }
end

-- ===================== BAÚ =====================

function RevealScene.chest(parent, chestColor)
	local self = setmetatable({}, RevealScene)
	self.viewport, self.world, self.camera = stage(parent)
	self.chest = makeChest(self.world, chestColor or Color3.fromRGB(205, 130, 70))
	self.actor = cloneCharacter(self.world, CFrame.new(0, 0, 2.6))
	self.camera.CFrame = CFrame.lookAt(Vector3.new(5.5, 4.2, -9), Vector3.new(0, 2.2, 1))
	self.start = os.clock()
	self.phase = "antecipacao"
	self.connection = RunService.RenderStepped:Connect(function()
		self:update()
	end)
	return self
end

function RevealScene:update()
	local now = os.clock()
	local t = now - self.start
	if self.phase == "antecipacao" then
		-- ajoelha e mexe no baú, que treme cada vez mais
		local kneel = smooth(t / 0.5)
		local fiddle = math.sin(now * 9) * 0.15
		local joints = blend(STAND, REACH, kneel)
		joints.RS = (joints.RS or CFrame.identity) * R(fiddle * 40)
		joints.LS = (joints.LS or CFrame.identity) * R(-fiddle * 40)
		pose(self.actor, joints)
		local shake = math.min(t / 4, 1) * 0.06
		local jitter = R(0, 0, math.sin(now * 40) * shake * 40)
		self.chest.body.CFrame = self.chest.base * CFrame.new(0, 0.8, 0) * jitter
		self.chest.lid.CFrame = self.chest.hinge * jitter * CFrame.new(0, 0.35, -0.95)
		self.camera.CFrame = CFrame.lookAt(Vector3.new(5.5 - t * 0.15, 4.2, -9 + t * 0.2), Vector3.new(0, 2, 1))
	elseif self.phase == "abrindo" then
		local open = smooth(t / 0.35)
		self.chest.lid.CFrame = self.chest.hinge * R(-115 * open) * CFrame.new(0, 0.35, -0.95)
		self.chest.body.CFrame = self.chest.base * CFrame.new(0, 0.8, 0)
		self.chest.inner.Transparency = 1 - open * 0.9
		-- feixe de luz e item subindo
		if self.beam then
			local grow = smooth(t / 0.4)
			self.beam.Size = Vector3.new(14 * grow, 1.4 + grow * 0.6, 1.4 + grow * 0.6)
			self.beam.CFrame = CFrame.new(0, 1.6 + 7 * grow, 0) * R(0, 0, 90)
			self.beam.Transparency = 0.25 + smooth((t - 1.2) / 0.8) * 0.75
			self.flash.Size = Vector3.one * (1 + smooth(t / 0.25) * 6)
			self.flash.Transparency = smooth(t / 0.5)
		end
		local rise = smooth((t - 0.3) / 0.7)
		local lift = smooth((t - 1.0) / 0.5)
		local stand = smooth((t - 0.6) / 0.5)
		local joints = blend(blend(REACH, STAND, stand), LIFT, lift)
		pose(self.actor, joints)
		if self.item then
			local handPos = Vector3.new(0.9, 7.6, 2.4)
			local pos = Vector3.new(0, 1.6, 0):Lerp(Vector3.new(0, 4.2, 0.6), rise):Lerp(handPos, lift)
			self.item.CFrame = CFrame.new(pos) * R(now * 120, now * 90, 0)
			self.halo.CFrame = CFrame.new(pos)
			self.halo.Size = Vector3.one * (2.2 + math.sin(now * 6) * 0.25)
		end
		self.camera.CFrame = CFrame.lookAt(Vector3.new(4.8, 4.4 + lift * 0.8, -8.4), Vector3.new(0, 2.6 + lift * 1.8, 1))
	end
end

-- dispara a abertura e espera terminar (~1,6 s)
function RevealScene:open(color, big)
	self.phase = "abrindo"
	self.start = os.clock()
	self.beam = newPart(self.world, Vector3.new(0.1, 1.4, 1.4), CFrame.new(0, 1.6, 0) * R(0, 0, 90), color, Enum.Material.Neon, Enum.PartType.Cylinder)
	self.beam.Transparency = 0.25
	self.flash = newPart(self.world, Vector3.one, CFrame.new(0, 2, 0), Color3.new(1, 1, 1), Enum.Material.Neon, Enum.PartType.Ball)
	self.item = newPart(self.world, Vector3.one * (if big then 1.1 else 0.9), CFrame.new(0, 1.6, 0), color, Enum.Material.Neon)
	self.halo = newPart(self.world, Vector3.one * 2.2, CFrame.new(0, 1.6, 0), color, Enum.Material.ForceField, Enum.PartType.Ball)
	self.viewport.Ambient = color:Lerp(Color3.fromRGB(150, 140, 160), 0.5)
	task.wait(1.6)
end

-- ===================== OVO =====================

function RevealScene.egg(parent, eggColor, petId)
	local self = setmetatable({}, RevealScene)
	self.viewport, self.world, self.camera = stage(parent)
	self.actor = cloneCharacter(self.world, CFrame.new(0, 0, 3))
	self.camera.CFrame = CFrame.lookAt(Vector3.new(4.5, 3.8, -8.5), Vector3.new(0, 2.2, 1))
	local egg = newPart(self.world, Vector3.new(2.2, 2.8, 2.2), CFrame.new(0, 1.4, 0), eggColor, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	local spots = {}
	for i = 1, 4 do
		local a = i * 1.7
		table.insert(spots, newPart(self.world, Vector3.one * 0.5, CFrame.new(math.cos(a) * 1.0, 1.2 + (i % 2) * 0.7, math.sin(a) * 1.0 - 0.3), eggColor:Lerp(Color3.new(1, 1, 1), 0.5), Enum.Material.SmoothPlastic, Enum.PartType.Ball))
	end
	local cracks = {}
	for i = 1, 4 do
		local crack = newPart(self.world, Vector3.new(0.08, 0.9, 0.08), CFrame.new(-0.6 + i * 0.3, 1.6 + (i % 2) * 0.4, -1.05) * R(0, 0, if i % 2 == 0 then 35 else -35), Color3.fromRGB(255, 250, 200), Enum.Material.Neon)
		crack.Transparency = 1
		table.insert(cracks, crack)
	end
	-- pet (montado pelo PetRenderer e movido para a cena)
	local pet = PetRenderer.build(petId, 1)
	if pet then
		pet.model.Parent = self.world
		for _, entry in pet.pieces do
			entry.part.Transparency = 1
		end
	end
	local start = os.clock()
	local burst = false
	local halves = {}
	self.connection = RunService.RenderStepped:Connect(function()
		local now = os.clock()
		local t = now - start
		if t < 1.6 then
			-- balança cada vez mais forte e racha
			local strength = smooth(t / 1.6)
			local wobble = R(0, 0, math.sin(now * (10 + strength * 14)) * (6 + strength * 16))
			egg.CFrame = CFrame.new(0, 1.4, 0) * wobble
			for i, spot in spots do
				local a = i * 1.7
				spot.CFrame = CFrame.new(0, 1.4, 0) * wobble * CFrame.new(math.cos(a) * 1.0, -0.2 + (i % 2) * 0.7, math.sin(a) * 1.0 - 0.3)
			end
			for i, crack in cracks do
				crack.Transparency = if t > 0.35 * i then 0 else 1
				crack.CFrame = CFrame.new(0, 1.4, 0) * wobble * CFrame.new(-0.6 + i * 0.3, 0.2 + (i % 2) * 0.4, -1.05) * R(0, 0, if i % 2 == 0 then 35 else -35)
			end
			pose(self.actor, blend(STAND, LEAN, smooth(t / 0.6)))
		else
			if not burst then
				burst = true
				egg.Transparency = 1
				for _, spot in spots do
					spot.Transparency = 1
				end
				for _, crack in cracks do
					crack.Transparency = 1
				end
				for _, side in { -1, 1 } do
					table.insert(halves, { part = newPart(self.world, Vector3.new(1.1, 1.4, 2.2), CFrame.new(side * 0.55, 1.4, 0), eggColor, Enum.Material.SmoothPlastic), side = side })
				end
				self.flash = newPart(self.world, Vector3.one, CFrame.new(0, 1.6, 0), Color3.new(1, 1, 1), Enum.Material.Neon, Enum.PartType.Ball)
				if pet then
					for _, entry in pet.pieces do
						entry.part.Transparency = if entry.part.Name == "Halo" then 0.6 else 0
					end
				end
			end
			local k = t - 1.6
			for _, half in halves do
				half.part.CFrame = CFrame.new(half.side * (0.55 + k * 4), 1.4 + k * 3 - k * k * 6, -k) * R(0, 0, half.side * k * 200)
				half.part.Transparency = smooth((k - 0.5) / 0.4)
			end
			if self.flash then
				self.flash.Size = Vector3.one * (1 + smooth(k / 0.25) * 7)
				self.flash.Transparency = smooth(k / 0.45)
			end
			if pet then
				local hop = math.abs(math.sin(k * 7)) * math.max(0, 1 - k * 0.6) * 1.2
				local base = CFrame.new(0, hop + (if pet.def.fly then 1.6 else 0), 0) * R(0, 180 + math.sin(k * 2) * 25, 0)
				for _, entry in pet.pieces do
					entry.part.CFrame = base * entry.offset
				end
			end
			pose(self.actor, blend(LEAN, CHEER, smooth(k / 0.4)))
		end
	end)
	return self
end

function RevealScene:destroy()
	if self.connection then
		self.connection:Disconnect()
		self.connection = nil
	end
	if self.viewport then
		self.viewport:Destroy()
		self.viewport = nil
	end
end

return RevealScene
