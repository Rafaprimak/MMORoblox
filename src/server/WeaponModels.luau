-- Modelos das armas presas na mão do personagem (com rastro para os golpes).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Items)
local Rarities = require(Shared.Rarities)

local WeaponModels = {}

local WOOD = Color3.fromRGB(90, 60, 35)
local STEEL = Color3.fromRGB(150, 150, 160)
local GRIP = Color3.fromRGB(60, 40, 28)

-- Como a arma fica na mão:
--  "blade": lâmina aponta para frente com o braço abaixado (espadas, machados...)
--  "pole":  fica em pé, ao longo do braço (lanças, cajados)
--  "bow":   arco na mão esquerda, na vertical ao mirar
local GRIP_STYLE = {
	sword = "blade", axe = "blade", hammer = "blade", katana = "blade", dagger = "blade",
	spear = "pole", staff = "pole", bow = "bow",
}

local function newPart(model, size, cf, color, material, name)
	local p = Instance.new("Part")
	p.Name = name or "Peca"
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Metal
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- Constrói o modelo com o cabo na origem e a lâmina subindo em +Y.
-- Retorna model, handle, tipEnd (Y da ponta), bladeStart (Y onde começa o rastro)
-- cor do fim do rastro por encantamento de elemento
local ELEMENT_TRAIL = {
	flamejante = Color3.fromRGB(255, 110, 30),
	vampirico = Color3.fromRGB(190, 20, 40),
	veloz = Color3.fromRGB(150, 230, 255),
	critico = Color3.fromRGB(255, 240, 140),
}

local function build(weaponType, rarity, element)
	local model = Instance.new("Model")
	model.Name = "Arma"
	local accent = rarity.color
	local accentMaterial = if rarity.order >= 4 then Enum.Material.Neon else Enum.Material.Metal
	local handle = newPart(model, Vector3.new(0.3, 1.1, 0.3), CFrame.new(), GRIP, Enum.Material.Wood, "Cabo")
	local glowing = {}
	local function add(size, offset, color, material, glow)
		local p = newPart(model, size, offset, color, material)
		if glow then
			table.insert(glowing, p)
		end
		return p
	end
	local tip, start = 4, 1
	if weaponType == "sword" then
		add(Vector3.new(1.3, 0.22, 0.4), CFrame.new(0, 0.65, 0), STEEL)
		add(Vector3.new(0.32, 3.3, 0.12), CFrame.new(0, 2.4, 0), accent, accentMaterial, true)
		tip, start = 4.05, 0.9
	elseif weaponType == "katana" then
		add(Vector3.new(0.6, 0.1, 0.6), CFrame.new(0, 0.6, 0), Color3.fromRGB(40, 40, 40))
		add(Vector3.new(0.2, 4.1, 0.09), CFrame.new(0.06, 2.7, 0) * CFrame.Angles(0, 0, math.rad(-3)), accent, accentMaterial, true)
		tip, start = 4.75, 0.8
	elseif weaponType == "dagger" then
		add(Vector3.new(0.8, 0.15, 0.3), CFrame.new(0, 0.6, 0), STEEL)
		add(Vector3.new(0.26, 1.6, 0.1), CFrame.new(0, 1.45, 0), accent, accentMaterial, true)
		tip, start = 2.25, 0.7
	elseif weaponType == "axe" then
		add(Vector3.new(0.28, 3.2, 0.28), CFrame.new(0, 1.6, 0), WOOD, Enum.Material.Wood)
		add(Vector3.new(1.5, 1.3, 0.2), CFrame.new(0.7, 2.8, 0), accent, accentMaterial, true)
		tip, start = 3.4, 2.2
	elseif weaponType == "hammer" then
		add(Vector3.new(0.3, 3.4, 0.3), CFrame.new(0, 1.7, 0), WOOD, Enum.Material.Wood)
		add(Vector3.new(2.2, 1.4, 1.4), CFrame.new(0, 3.6, 0), accent, accentMaterial, true)
		tip, start = 4.3, 2.9
	elseif weaponType == "spear" then
		add(Vector3.new(0.24, 6.5, 0.24), CFrame.new(0, 1.4, 0), WOOD, Enum.Material.Wood)
		add(Vector3.new(0.55, 0.55, 0.15), CFrame.new(0, 4.8, 0) * CFrame.Angles(0, 0, math.rad(45)), accent, accentMaterial, true)
		add(Vector3.new(0.28, 1.2, 0.1), CFrame.new(0, 5.4, 0), accent, accentMaterial, true)
		tip, start = 6, 4.2
	elseif weaponType == "staff" then
		add(Vector3.new(0.3, 6, 0.3), CFrame.new(0, 1.5, 0), WOOD, Enum.Material.Wood)
		add(Vector3.new(0.9, 0.9, 0.9), CFrame.new(0, 4.9, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)), accent, Enum.Material.Neon, true)
		for i = 0, 2 do
			add(Vector3.new(0.15, 1.1, 0.15), CFrame.new(0, 4.6, 0) * CFrame.Angles(0, i * math.pi * 2 / 3, 0) * CFrame.new(0, 0, -0.55) * CFrame.Angles(math.rad(-20), 0, 0), WOOD, Enum.Material.Wood)
		end
		tip, start = 5.4, 4.4
	elseif weaponType == "bow" then
		for _, side in { -1, 1 } do
			add(Vector3.new(0.22, 2.2, 0.22), CFrame.new(0, side * 1.25, -0.25) * CFrame.Angles(math.rad(side * 18), 0, 0), WOOD, Enum.Material.Wood)
			add(Vector3.new(0.28, 0.5, 0.28), CFrame.new(0, side * 2.3, -0.65), accent, accentMaterial, true)
		end
		add(Vector3.new(0.05, 4.6, 0.05), CFrame.new(0, 0, 0.35), Color3.fromRGB(235, 235, 235), Enum.Material.SmoothPlastic)
		tip, start = 2.3, -2.3
	end

	for _, p in model:GetChildren() do
		if p ~= handle and p:IsA("BasePart") then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = p
			weld.Parent = p
		end
	end
	for _, p in glowing do
		if rarity.rainbow then
			CollectionService:AddTag(p, "Rainbow")
		end
		if rarity.order >= 5 then
			local sparkles = Instance.new("ParticleEmitter")
			sparkles.Color = ColorSequence.new(rarity.color)
			sparkles.LightEmission = 1
			sparkles.Size = NumberSequence.new(0.22, 0)
			sparkles.Lifetime = NumberRange.new(0.4, 0.8)
			sparkles.Rate = 10
			sparkles.Speed = NumberRange.new(0.5, 1.5)
			sparkles.SpreadAngle = Vector2.new(180, 180)
			sparkles.Parent = p
		end
	end
	if rarity.order >= 4 and glowing[1] then
		local light = Instance.new("PointLight")
		light.Color = rarity.color
		light.Range = 6 + rarity.order
		light.Brightness = 1.4
		light.Parent = glowing[1]
	end

	-- rastro do golpe (ligado pelo cliente durante os ataques)
	local a0 = Instance.new("Attachment")
	a0.Name = "TrailStart"
	a0.Position = Vector3.new(0, start, 0)
	a0.Parent = handle
	local a1 = Instance.new("Attachment")
	a1.Name = "TrailEnd"
	a1.Position = Vector3.new(0, tip, 0)
	a1.Parent = handle
	-- quanto mais rara, mais longo, brilhante e colorido; encantamento de elemento tinge o fim do rastro
	local order = rarity.order
	local main = rarity.color:Lerp(Color3.new(1, 1, 1), if order <= 2 then 0.45 else 0.15)
	local tail = ELEMENT_TRAIL[element or ""] or rarity.color
	local trail = Instance.new("Trail")
	trail.Name = "Rastro"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	if rarity.rainbow then
		trail.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
			ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 230, 80)),
			ColorSequenceKeypoint.new(0.66, Color3.fromRGB(80, 220, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 90, 255)),
		})
	else
		trail.Color = ColorSequence.new(main, tail)
	end
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, if order >= 4 then 0.05 else 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.WidthScale = NumberSequence.new(1, if order >= 5 then 0.6 else 0.2)
	trail.Lifetime = 0.14 + order * 0.025
	trail.LightEmission = math.min(0.3 + order * 0.12, 1)
	trail.FaceCamera = true
	trail.Enabled = false
	trail.Parent = handle
	-- Lendário ou melhor: faíscas na ponta durante o golpe
	if order >= 5 then
		local sparks = Instance.new("ParticleEmitter")
		sparks.Name = "FaiscasGolpe"
		sparks.Color = if rarity.rainbow then trail.Color else ColorSequence.new(rarity.color, tail)
		sparks.LightEmission = 1
		sparks.Size = NumberSequence.new(0.28, 0)
		sparks.Lifetime = NumberRange.new(0.2, 0.45)
		sparks.Rate = 45
		sparks.Speed = NumberRange.new(2, 5)
		sparks.SpreadAngle = Vector2.new(180, 180)
		sparks.Enabled = false
		sparks.Parent = a1
	end

	model.PrimaryPart = handle
	return model, handle
end

function WeaponModels.attach(character, item)
	local old = character:FindFirstChild("Arma")
	if old then
		old:Destroy()
	end
	if not item then
		return nil
	end
	local base = Items.Bases[item.base]
	local rarity = Rarities.ById[item.rarity] or Rarities.List[1]
	if not base or base.slot ~= "weapon" then
		return nil
	end
	local style = GRIP_STYLE[base.weaponType] or "blade"
	local hand = if style == "bow" then character:FindFirstChild("LeftHand") or character:FindFirstChild("Left Arm") else character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if not hand then
		return nil
	end
	local model, handle = build(base.weaponType, rarity, item.enchant and item.enchant.id)
	model:SetAttribute("WeaponType", base.weaponType)
	local grip
	if style == "blade" then
		grip = CFrame.new(0, -0.25, -0.1) * CFrame.Angles(math.rad(-90), 0, 0)
	elseif style == "pole" then
		grip = CFrame.new(0, -0.2, 0)
	else
		grip = CFrame.new(0, -0.2, 0) * CFrame.Angles(math.rad(90), 0, 0)
	end
	model:PivotTo(hand.CFrame * grip)
	local weld = Instance.new("Weld")
	weld.Name = "PegadaArma"
	weld.Part0 = hand
	weld.Part1 = handle
	weld.C0 = grip
	weld.Parent = handle
	model.Parent = character
	return model
end

return WeaponModels
