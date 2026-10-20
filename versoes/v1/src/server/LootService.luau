-- Drops no chão com feixe de luz na cor da raridade. Só o dono pode pegar.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Rarities = require(Shared.Rarities)
local Remotes = require(Shared.Remotes)

local PlayerService = require(script.Parent.PlayerService)

local LootService = {}

local drops = {}
local folder = Instance.new("Folder")
folder.Name = "Drops"
folder.Parent = workspace

local function effectPart(parent, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.Neon
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
	p.Parent = parent
	return p
end

function LootService.spawnDrop(player, item, position)
	local rarity = Rarities.ById[item.rarity] or Rarities.List[1]
	local angle = math.random() * math.pi * 2
	local distance = 2 + math.random() * 3
	local target = Vector3.new(position.X + math.cos(angle) * distance, Config.GroundY + 1, position.Z + math.sin(angle) * distance)

	local model = Instance.new("Model")
	model.Name = "Drop_" .. player.Name

	local gem = effectPart(model, {
		Name = "Gema",
		Size = Vector3.new(1.2, 1.2, 1.2),
		Color = rarity.color,
		CFrame = CFrame.new(position + Vector3.new(0, 3, 0)) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
	})
	local beamHeight = 4 + rarity.order * 4
	local beamWidth = 0.5 + rarity.order * 0.12
	local beam = effectPart(model, {
		Name = "Feixe",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(beamHeight, beamWidth, beamWidth),
		Color = rarity.color,
		Transparency = 0.55,
		CFrame = CFrame.new(target + Vector3.new(0, beamHeight / 2 - 1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
	})
	local glow = Instance.new("PointLight")
	glow.Color = rarity.color
	glow.Range = 6 + rarity.order * 2
	glow.Brightness = 2
	glow.Parent = gem

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 30)
	gui.StudsOffset = Vector3.new(0, 2, 0)
	gui.MaxDistance = 60
	gui.AlwaysOnTop = rarity.order >= 4
	gui.LightInfluence = 0
	gui.Parent = gem
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = rarity.color
	label.Text = ("%s [%s]"):format(Items.displayName(item), rarity.name)
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1.5
	stroke.Parent = label

	if rarity.rainbow then
		CollectionService:AddTag(gem, "Rainbow")
		CollectionService:AddTag(beam, "Rainbow")
	end

	model.Parent = folder
	TweenService:Create(gem, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = CFrame.new(target) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
	}):Play()

	Remotes.Fx:FireClient(player, "drop", target, item.rarity)

	table.insert(drops, {
		owner = player,
		item = item,
		model = model,
		position = target,
		ready = os.clock() + 0.5,
		expire = os.clock() + Config.LootAutoCollect,
	})
end

-- Coleta: chegando perto ou automaticamente depois de alguns segundos (nada se perde)
task.spawn(function()
	while true do
		task.wait(0.15)
		local now = os.clock()
		for i = #drops, 1, -1 do
			local drop = drops[i]
			if drop.owner.Parent ~= Players then
				drop.model:Destroy()
				table.remove(drops, i)
				continue
			end
			if now < drop.ready then
				continue
			end
			local character = drop.owner.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local near = root and (root.Position - drop.position).Magnitude <= Config.LootPickupRange
			if near or now >= drop.expire then
				table.remove(drops, i)
				drop.model:Destroy()
				PlayerService.addItem(drop.owner, drop.item)
			end
		end
	end
end)

return LootService
