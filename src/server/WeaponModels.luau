-- Arma presa na mão do personagem (com rastro para os golpes). O modelo vem de ItemModels (o mesmo
-- do ícone 3D e do item no chão); aqui só entram a solda, as partículas, a luz e o rastro.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Items)
local Rarities = require(Shared.Rarities)
local ItemModels = require(Shared.ItemModels)

local WeaponModels = {}

-- Como a arma fica na mão:
--  "blade": lâmina aponta para frente com o braço abaixado (espadas, machados...)
--  "pole":  fica em pé, ao longo do braço (lanças, cajados)
--  "bow":   arco na mão esquerda, na vertical ao mirar
local GRIP_STYLE = {
	sword = "blade", axe = "blade", hammer = "blade", katana = "blade", dagger = "blade",
	spear = "pole", staff = "pole", bow = "bow",
}

-- cor do fim do rastro por encantamento de elemento
local ELEMENT_TRAIL = {
	flamejante = Color3.fromRGB(255, 110, 30),
	vampirico = Color3.fromRGB(190, 20, 40),
	veloz = Color3.fromRGB(150, 230, 255),
	critico = Color3.fromRGB(255, 240, 140),
}

-- Monta a arma a partir do modelo compartilhado (ItemModels) e põe solda, brilho e rastro
local function build(item, rarity, element)
	local model, info = ItemModels.build(item.base, item.rarity, { held = true })
	model.Name = "Arma"
	local handle = info.handle
	local glowing = info.glowing
	local tip, start = info.tip, info.start
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
	local model, handle = build(item, rarity, item.enchant and item.enchant.id)
	model:SetAttribute("WeaponType", base.weaponType)
	local grip
	if style == "blade" then
		grip = CFrame.new(0, -0.25, -0.1) * CFrame.Angles(math.rad(-90), 0, 0)
	elseif style == "pole" then
		-- cajado: a mão segura um terço acima da ponta de baixo, com o cajado em pé
		grip = if base.weaponType == "staff" then CFrame.new(0, -1.1, 0) * CFrame.Angles(math.rad(-8), 0, 0) else CFrame.new(0, -0.2, 0)
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
