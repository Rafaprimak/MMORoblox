-- Armas (Tools blocadas) e ataque do jogador. Segure o clique para atacar sem parar.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Rarities = require(Shared.Rarities)

local EnemyService = require(script.Parent.EnemyService)

local CombatService = {}

-- Preenchidos pelo PlayerService (evita dependência circular)
CombatService.AttackProvider = function(_player)
	return Config.BaseAttack
end
CombatService.WeaponProvider = function(_player)
	return nil
end

local lastAttack = {}

local WOOD = Color3.fromRGB(90, 60, 35)
local STEEL = Color3.fromRGB(95, 95, 105)

local function makePart(parent, size, cframe, color, material)
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.Metal
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Monta o visual da arma soldado no Handle. A lâmina aponta para +Y do Handle.
local function buildVisual(tool, handle, shape, rarity)
	local accent = rarity.color
	local accentMaterial = if rarity.order >= 4 then Enum.Material.Neon else Enum.Material.Metal
	local glowing = {}

	local function add(size, offset, color, material)
		local p = makePart(tool, size, handle.CFrame * offset, color, material)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = p
		weld.Parent = p
		return p
	end

	if shape == "sword" then
		add(Vector3.new(1.4, 0.25, 0.45), CFrame.new(0, 0.7, 0), STEEL, Enum.Material.Metal)
		table.insert(glowing, add(Vector3.new(0.34, 3.4, 0.14), CFrame.new(0, 2.5, 0), accent, accentMaterial))
	elseif shape == "katana" then
		add(Vector3.new(0.7, 0.12, 0.7), CFrame.new(0, 0.66, 0), Color3.fromRGB(40, 40, 40), Enum.Material.Metal)
		table.insert(glowing, add(Vector3.new(0.22, 4.2, 0.1), CFrame.new(0, 2.8, 0) * CFrame.Angles(0, 0, math.rad(-4)), accent, accentMaterial))
	elseif shape == "axe" then
		add(Vector3.new(0.3, 3.2, 0.3), CFrame.new(0, 1.8, 0), WOOD, Enum.Material.Wood)
		table.insert(glowing, add(Vector3.new(1.5, 1.3, 0.22), CFrame.new(0.7, 3.0, 0), accent, accentMaterial))
	elseif shape == "spear" then
		add(Vector3.new(0.26, 5.5, 0.26), CFrame.new(0, 2.4, 0), WOOD, Enum.Material.Wood)
		table.insert(glowing, add(Vector3.new(0.6, 0.6, 0.18), CFrame.new(0, 5.4, 0) * CFrame.Angles(0, 0, math.rad(45)), accent, accentMaterial))
		table.insert(glowing, add(Vector3.new(0.3, 1.2, 0.12), CFrame.new(0, 5.9, 0), accent, accentMaterial))
	elseif shape == "hammer" then
		add(Vector3.new(0.32, 3.4, 0.32), CFrame.new(0, 1.9, 0), WOOD, Enum.Material.Wood)
		table.insert(glowing, add(Vector3.new(2.2, 1.4, 1.4), CFrame.new(0, 3.8, 0), accent, accentMaterial))
	else
		table.insert(glowing, add(Vector3.new(0.34, 3.4, 0.14), CFrame.new(0, 2.5, 0), accent, accentMaterial))
	end
	return glowing
end

function CombatService.attack(player, tool)
	local now = os.clock()
	if lastAttack[player] and now - lastAttack[player] < Config.AttackCooldown - 0.05 then
		return
	end
	lastAttack[player] = now

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end

	-- animação padrão de golpe do Roblox
	local animation = Instance.new("StringValue")
	animation.Name = "toolanim"
	animation.Value = "Slash"
	animation.Parent = tool
	Debris:AddItem(animation, 1)

	local handle = tool:FindFirstChild("Handle")
	local swing = handle and handle:FindFirstChild("Swing")
	if swing then
		swing.PlaybackSpeed = 0.9 + math.random() * 0.25
		swing:Play()
	end

	local item = CombatService.WeaponProvider(player)
	local base = item and Items.Bases[item.base] or {}
	local range = Config.AttackRange + (base.range or 0)
	local targets = EnemyService.getTargets(root.Position, root.CFrame.LookVector, range, base.cleave or 1)
	local attack = CombatService.AttackProvider(player)

	for _, rec in targets do
		local crit = math.random() < Config.CritChance + (base.crit or 0)
		local damage = attack * (0.9 + math.random() * 0.2)
		if crit then
			damage *= Config.CritMultiplier
		end
		EnemyService.damage(rec, math.max(1, math.floor(damage)), player, crit, root.Position)
	end
end

function CombatService.buildTool(player, item)
	local base = Items.Bases[item.base] or {}
	local rarity = Rarities.ById[item.rarity] or Rarities.List[1]

	local tool = Instance.new("Tool")
	tool.Name = Items.displayName(item)
	tool.ToolTip = ("%s • Poder %d"):format(rarity.name, Items.getPower(item))
	tool.CanBeDropped = false
	tool.RequiresHandle = true

	local handle = makePart(tool, Vector3.new(0.35, 1.2, 0.35), CFrame.new(), Color3.fromRGB(70, 45, 30), Enum.Material.Wood)
	handle.Name = "Handle"

	local glowing = buildVisual(tool, handle, base.shape, rarity)
	for _, p in glowing do
		if rarity.rainbow then
			CollectionService:AddTag(p, "Rainbow")
		end
		if rarity.order >= 5 then
			local sparkles = Instance.new("ParticleEmitter")
			sparkles.Color = ColorSequence.new(rarity.color)
			sparkles.LightEmission = 1
			sparkles.Size = NumberSequence.new(0.25, 0)
			sparkles.Lifetime = NumberRange.new(0.4, 0.8)
			sparkles.Rate = 12
			sparkles.Speed = NumberRange.new(0.5, 1.5)
			sparkles.SpreadAngle = Vector2.new(180, 180)
			sparkles.Parent = p
		end
	end
	if rarity.order >= 4 and glowing[1] then
		local glow = Instance.new("PointLight")
		glow.Color = rarity.color
		glow.Range = 6 + rarity.order
		glow.Brightness = 1.5
		glow.Parent = glowing[1]
	end

	local swing = Instance.new("Sound")
	swing.Name = "Swing"
	swing.SoundId = "rbxasset://sounds/swordslash.wav"
	swing.Volume = 0.5
	swing.Parent = handle

	-- segurar o clique = ataque contínuo
	local holding = false
	local looping = false
	tool.Activated:Connect(function()
		holding = true
		if looping then
			return
		end
		looping = true
		while holding and tool.Parent ~= nil and tool.Parent == player.Character do
			CombatService.attack(player, tool)
			task.wait(Config.AttackCooldown)
		end
		looping = false
	end)
	tool.Deactivated:Connect(function()
		holding = false
	end)
	tool.Unequipped:Connect(function()
		holding = false
	end)

	return tool
end

function CombatService.giveWeapon(player, item)
	local character = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 5)
	if not character or not backpack then
		return
	end
	for _, container in { backpack, character } do
		for _, child in container:GetChildren() do
			if child:IsA("Tool") then
				child:Destroy()
			end
		end
	end
	if not item then
		return
	end
	local tool = CombatService.buildTool(player, item)
	tool.Parent = backpack
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		humanoid:EquipTool(tool)
	end
end

function CombatService.release(player)
	lastAttack[player] = nil
end

return CombatService
