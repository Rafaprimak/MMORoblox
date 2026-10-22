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
	local M = Enum.Material
	local tier = rarity.order
	-- metal da lâmina melhora com a raridade; detalhes (guarda, gema) usam a cor da raridade
	local bladeColor = if tier >= 5 then accent:Lerp(Color3.new(1, 1, 1), 0.35) elseif tier >= 3 then STEEL:Lerp(accent, 0.25) else STEEL
	local bladeMaterial = if tier >= 6 then M.Neon elseif tier >= 4 then M.Foil else M.Metal
	local GOLD = Color3.fromRGB(220, 180, 70)
	local trim = if tier >= 3 then GOLD else Color3.fromRGB(90, 90, 100)
	local function wedge(size, offset, color, material, glow)
		local p = add(size, offset, color, material, glow)
		p.Shape = Enum.PartType.Wedge
		return p
	end
	local function ball(size, offset, color, material, glow)
		local p = add(Vector3.one * size, offset, color, material, glow)
		p.Shape = Enum.PartType.Ball
		return p
	end
	-- cabo enrolado em couro + pomo
	local function grip(length, y)
		for i = 0, math.floor(length / 0.28) - 1 do
			add(Vector3.new(0.34, 0.12, 0.34), CFrame.new(0, y - length / 2 + 0.14 + i * 0.28, 0) * CFrame.Angles(0, math.rad(45 * (i % 2)), 0), Color3.fromRGB(45, 30, 22), M.Fabric)
		end
	end
	local function gem(offset, size)
		ball(size or 0.3, offset, accent, M.Neon, true)
	end
	-- lâmina com fio afiado (centro + duas bordas em cunha) e ponta em cunha
	local function blade(width, length, y, thickness)
		thickness = thickness or 0.12
		add(Vector3.new(width * 0.5, length, thickness), CFrame.new(0, y, 0), bladeColor, bladeMaterial, tier >= 4)
		for _, side in { -1, 1 } do
			wedge(Vector3.new(thickness * 0.8, length, width * 0.3), CFrame.new(side * width * 0.4, y, 0) * CFrame.Angles(0, math.rad(side * 90), 0), bladeColor:Lerp(Color3.new(1, 1, 1), 0.3), bladeMaterial)
		end
		-- sulco central
		add(Vector3.new(width * 0.12, length * 0.75, thickness + 0.02), CFrame.new(0, y - length * 0.05, 0), accent, if tier >= 4 then M.Neon else M.Metal, tier >= 4)
		-- ponta
		for _, side in { -1, 1 } do
			wedge(Vector3.new(thickness, width * 0.9, width * 0.5), CFrame.new(side * width * 0.25, y + length / 2 + width * 0.45, 0) * CFrame.Angles(0, math.rad(side * 90), 0), bladeColor, bladeMaterial)
		end
	end

	if weaponType == "sword" then
		grip(0.9, 0.05)
		gem(CFrame.new(0, -0.5, 0), 0.32)
		add(Vector3.new(1.5, 0.22, 0.38), CFrame.new(0, 0.62, 0), trim, M.Metal)
		for _, side in { -1, 1 } do
			ball(0.3, CFrame.new(side * 0.78, 0.62, 0), trim, M.Metal)
		end
		gem(CFrame.new(0, 0.62, -0.2), 0.22)
		blade(0.42, 3.1, 2.3)
		tip, start = 4.2, 0.9
	elseif weaponType == "katana" then
		grip(1.1, 0.0)
		add(Vector3.new(0.7, 0.1, 0.7), CFrame.new(0, 0.62, 0), Color3.fromRGB(35, 35, 40), M.Metal) -- tsuba
		add(Vector3.new(0.75, 0.04, 0.75), CFrame.new(0, 0.68, 0), trim, M.Metal)
		add(Vector3.new(0.18, 0.25, 0.14), CFrame.new(0, 0.82, 0), trim, M.Metal) -- habaki
		for i = 0, 7 do
			local y = 1.2 + i * 0.47
			add(Vector3.new(0.17, 0.5, 0.08), CFrame.new(0.02 + i * 0.012, y, 0) * CFrame.Angles(0, 0, math.rad(-2 - i * 0.4)), bladeColor, bladeMaterial, tier >= 4)
			add(Vector3.new(0.05, 0.5, 0.1), CFrame.new(-0.07 + i * 0.012, y, 0) * CFrame.Angles(0, 0, math.rad(-2 - i * 0.4)), accent, if tier >= 4 then M.Neon else M.Metal, tier >= 4)
		end
		wedge(Vector3.new(0.08, 0.45, 0.18), CFrame.new(0.13, 5.0, 0) * CFrame.Angles(0, math.rad(90), 0), bladeColor, bladeMaterial)
		tip, start = 4.95, 0.9
	elseif weaponType == "dagger" then
		grip(0.7, 0.1)
		gem(CFrame.new(0, -0.32, 0), 0.24)
		add(Vector3.new(0.9, 0.14, 0.28), CFrame.new(0, 0.55, 0) * CFrame.Angles(0, 0, math.rad(8)), trim, M.Metal)
		blade(0.32, 1.35, 1.32, 0.1)
		tip, start = 2.3, 0.7
	elseif weaponType == "axe" then
		add(Vector3.new(0.28, 3.4, 0.28), CFrame.new(0, 1.7, 0), WOOD, M.Wood)
		grip(1.0, 0.1)
		add(Vector3.new(0.36, 0.5, 0.36), CFrame.new(0, 2.85, 0), trim, M.Metal) -- anel
		-- lâmina curva em leque (três peças) + contrapeso
		add(Vector3.new(0.9, 0.9, 0.18), CFrame.new(0.55, 2.95, 0), bladeColor, bladeMaterial, tier >= 4)
		wedge(Vector3.new(0.18, 0.7, 0.7), CFrame.new(1.1, 3.35, 0) * CFrame.Angles(0, math.rad(90), 0), bladeColor, bladeMaterial)
		wedge(Vector3.new(0.18, 0.7, 0.7), CFrame.new(1.1, 2.55, 0) * CFrame.Angles(0, math.rad(90), math.rad(180)), bladeColor, bladeMaterial)
		add(Vector3.new(0.12, 1.6, 0.2), CFrame.new(1.45, 2.95, 0), accent, if tier >= 4 then M.Neon else M.Metal, true)
		wedge(Vector3.new(0.2, 0.5, 0.45), CFrame.new(-0.35, 2.95, 0) * CFrame.Angles(0, math.rad(-90), 0), trim, M.Metal)
		tip, start = 3.7, 2.3
	elseif weaponType == "hammer" then
		add(Vector3.new(0.3, 3.4, 0.3), CFrame.new(0, 1.7, 0), WOOD, M.Wood)
		grip(1.1, 0.1)
		local head = add(Vector3.new(2.0, 1.3, 1.3), CFrame.new(0, 3.65, 0), bladeColor:Lerp(Color3.fromRGB(80, 80, 90), 0.4), M.Metal, false)
		local _h = head
		for _, side in { -1, 1 } do
			add(Vector3.new(0.25, 1.45, 1.45), CFrame.new(side * 0.7, 3.65, 0), trim, M.Metal) -- bandas
			add(Vector3.new(0.3, 1.0, 1.0), CFrame.new(side * 1.12, 3.65, 0), bladeColor, bladeMaterial, tier >= 4) -- faces
		end
		gem(CFrame.new(0, 3.65, -0.66), 0.35)
		wedge(Vector3.new(0.5, 0.6, 0.5), CFrame.new(0, 4.6, 0), trim, M.Metal) -- ponta de cima
		tip, start = 4.4, 2.9
	elseif weaponType == "spear" then
		add(Vector3.new(0.24, 6.6, 0.24), CFrame.new(0, 1.4, 0), WOOD, M.Wood)
		for _, y in { -1.4, 0.1, 3.6 } do
			add(Vector3.new(0.32, 0.25, 0.32), CFrame.new(0, y, 0), trim, M.Metal)
		end
		add(Vector3.new(0.35, 0.5, 0.35), CFrame.new(0, 4.75, 0), trim, M.Metal)
		-- franja (borla) abaixo da ponta
		for i = 0, 3 do
			add(Vector3.new(0.08, 0.7, 0.08), CFrame.new(0, 4.3, 0) * CFrame.Angles(0, i * math.pi / 2, 0) * CFrame.new(0, 0, -0.18) * CFrame.Angles(math.rad(-12), 0, 0), Color3.fromRGB(200, 40, 40), M.Fabric)
		end
		blade(0.38, 0.9, 5.4, 0.1)
		for _, side in { -1, 1 } do
			wedge(Vector3.new(0.08, 0.5, 0.3), CFrame.new(side * 0.32, 5.05, 0) * CFrame.Angles(0, math.rad(side * 90), math.rad(180)), bladeColor, bladeMaterial)
		end
		tip, start = 6.2, 4.4
	elseif weaponType == "staff" then
		add(Vector3.new(0.3, 6, 0.3), CFrame.new(0, 1.5, 0), WOOD, M.Wood)
		-- nós da madeira e anéis
		for _, y in { -0.6, 1.4, 3.3 } do
			add(Vector3.new(0.38, 0.2, 0.38), CFrame.new(0, y, 0), trim, M.Metal)
		end
		-- garras segurando o cristal
		for i = 0, 3 do
			add(Vector3.new(0.14, 1.2, 0.14), CFrame.new(0, 4.65, 0) * CFrame.Angles(0, i * math.pi / 2, 0) * CFrame.new(0, 0, -0.45) * CFrame.Angles(math.rad(-22), 0, 0), WOOD:Lerp(trim, 0.3), M.Wood)
		end
		local crystal = add(Vector3.new(0.75, 1.2, 0.75), CFrame.new(0, 5.0, 0) * CFrame.Angles(0, math.rad(45), 0), accent, M.Neon, true)
		local _c = crystal
		ball(1.35, CFrame.new(0, 5.0, 0), accent, M.ForceField, false)
		tip, start = 5.5, 4.4
	elseif weaponType == "bow" then
		-- arco em segmentos curvos com pontas reforçadas
		for _, side in { -1, 1 } do
			for i = 0, 3 do
				local t = i / 3
				local y = side * (0.45 + t * 1.7)
				local z = -0.15 - t * t * 0.55
				add(Vector3.new(0.2, 0.62, 0.22), CFrame.new(0, y, z) * CFrame.Angles(math.rad(side * (8 + t * 30)), 0, 0), WOOD, M.Wood)
			end
			add(Vector3.new(0.26, 0.4, 0.26), CFrame.new(0, side * 2.3, -0.72), accent, if tier >= 4 then M.Neon else M.Metal, true)
		end
		add(Vector3.new(0.3, 0.9, 0.3), CFrame.new(0, 0, -0.08), Color3.fromRGB(45, 30, 22), M.Fabric) -- empunhadura
		gem(CFrame.new(0, 0, -0.28), 0.22)
		add(Vector3.new(0.04, 4.55, 0.04), CFrame.new(0, 0, 0.3), Color3.fromRGB(235, 235, 235), M.SmoothPlastic)
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
