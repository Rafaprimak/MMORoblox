-- Ícone 3D de item: ViewportFrame com o modelo de ItemModels (o mesmo da mão e do chão), luz suave,
-- fundo com brilho da raridade e, se pedido, girando devagar. Os modelos ficam guardados por base e
-- raridade (monta uma vez, depois só clona).
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ItemModels = require(Shared.ItemModels)
local Rarities = require(Shared.Rarities)

local UI = require(script.Parent.UI)

local ItemIcon = {}

local templates = {}
local spinning = {} -- [model] = { center, angle }

local function template(baseId, rarityId)
	local key = tostring(baseId) .. "|" .. tostring(rarityId)
	local cached = templates[key]
	if cached then
		return cached
	end
	local model = ItemModels.build(baseId, rarityId, { anchored = true })
	-- vira o item para a pose de vitrine, em volta do centro dele
	local cf = model:GetBoundingBox()
	local rotation = ItemModels.displayRotation(baseId)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CFrame = CFrame.new(cf.Position) * rotation * CFrame.new(cf.Position):Inverse() * part.CFrame
		end
	end
	templates[key] = model
	return model
end

-- props: Size, Position, AnchorPoint, ZIndex, LayoutOrder, spin (gira), glow (fundo com brilho da raridade)
function ItemIcon.new(parent, baseId, rarityId, props)
	props = props or {}
	local rarity = Rarities.ById[rarityId] or Rarities.List[1]
	local holder = UI.new("Frame", {
		Name = "IconeItem",
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		LayoutOrder = props.LayoutOrder,
		BackgroundTransparency = 1,
		ZIndex = props.ZIndex or 1,
		Parent = parent,
	})
	if props.glow ~= false then
		-- brilho redondo da raridade atrás do item
		UI.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.95, 0.95),
			BackgroundColor3 = rarity.color,
			BackgroundTransparency = 0.55,
			ZIndex = holder.ZIndex,
			Parent = holder,
		}, {
			UI.corner(999),
			UI.new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.6, 0.75), NumberSequenceKeypoint.new(1, 1) }), Rotation = 0 }),
			UI.new("UIAspectRatioConstraint", { AspectRatio = 1 }),
		})
	end
	local viewport = UI.new("ViewportFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(165, 160, 175),
		LightColor = Color3.fromRGB(255, 244, 228),
		LightDirection = Vector3.new(-0.45, -1, 0.55),
		ZIndex = holder.ZIndex + 1,
		Parent = holder,
	}, { UI.new("UIAspectRatioConstraint", { AspectRatio = 1 }) })
	viewport.AnchorPoint = Vector2.new(0.5, 0.5)
	viewport.Position = UDim2.fromScale(0.5, 0.5)
	local model = template(baseId, rarityId):Clone()
	model.Parent = viewport
	local camera = Instance.new("Camera")
	camera.FieldOfView = 26
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local cf, size = model:GetBoundingBox()
	local radius = size.Magnitude / 2
	local distance = radius / math.sin(math.rad(camera.FieldOfView / 2)) * 0.85
	camera.CFrame = CFrame.lookAt(cf.Position + Vector3.new(0, radius * 0.08, -distance), cf.Position)
	if props.spin then
		spinning[model] = { center = cf.Position, angle = 0, start = model:GetPivot() }
		model.Destroying:Connect(function()
			spinning[model] = nil
		end)
	end
	return holder, model
end

RunService.RenderStepped:Connect(function(dt)
	for model, info in spinning do
		if model.Parent == nil then
			spinning[model] = nil
		else
			info.angle += dt * 0.9
			model:PivotTo(CFrame.new(info.center) * CFrame.Angles(0, info.angle, 0) * CFrame.new(info.center):Inverse() * info.start)
		end
	end
end)

return ItemIcon
