-- Equipamentos dropados no chão com feixe de luz na cor da raridade. Só o dono pode pegar.
-- Materiais vão direto para a bolsa (com aviso na tela).
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local World = require(Shared.World)
local Items = require(Shared.Items)
local Rarities = require(Shared.Rarities)
local Remotes = require(Shared.Remotes)
local ItemModels = require(Shared.ItemModels)

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
	local x, z = position.X + math.cos(angle) * distance, position.Z + math.sin(angle) * distance
	-- fora do mapa (masmorras) o chão é o da sala, não o do relevo
	local outside = math.abs(position.X) > World.Half or math.abs(position.Z) > World.Half
	local groundY = if outside then position.Y else math.max(World.height(x, z), World.SeaLevel)
	local target = Vector3.new(x, groundY + 1, z)

	local model = Instance.new("Model")
	model.Name = "Drop_" .. player.Name
	model:SetAttribute("Owner", player.UserId) -- o cliente esconde os drops dos outros (loot pessoal)
	local gem = effectPart(model, {
		Name = "Gema",
		Size = Vector3.new(0.6, 0.6, 0.6),
		Color = rarity.color,
		Transparency = 1,
		CFrame = CFrame.new(position + Vector3.new(0, 3, 0)),
	})
	-- o próprio item (mesmo modelo da mão e do ícone), deitado de lado e um pouco acima do chão
	local itemModel = ItemModels.build(item.base, item.rarity, { anchored = true })
	itemModel.Name = "ItemNoChao"
	local itemSize = itemModel:GetExtentsSize()
	local fit = math.clamp(2.6 / math.max(itemSize.X, itemSize.Y, itemSize.Z), 0.25, 1)
	itemModel:ScaleTo(fit)
	-- posição do pivô em relação ao centro do item (medida uma vez, antes de girar)
	local tilt = ItemModels.displayRotation(item.base)
	local center = itemModel:GetBoundingBox()
	local relative = CFrame.new(center.Position):ToObjectSpace(itemModel:GetPivot())
	local lift = math.max(itemSize.X, itemSize.Y, itemSize.Z) * fit * 0.5 + 0.3
	local function placeItem(at)
		itemModel:PivotTo(CFrame.new(at + Vector3.new(0, lift, 0)) * tilt * relative)
	end
	itemModel.Parent = model
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
	gui.Size = UDim2.fromOffset(220, 30)
	gui.StudsOffset = Vector3.new(0, 2, 0)
	gui.MaxDistance = 70
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
		CFrame = CFrame.new(target),
	}):Play()
	-- o item faz um arco do inimigo até o chão
	placeItem(position + Vector3.new(0, 2, 0))
	task.spawn(function()
		local from = position + Vector3.new(0, 2, 0)
		for step = 1, 9 do
			task.wait(0.05)
			local t = step / 9
			placeItem(from:Lerp(target - Vector3.new(0, 1, 0), t) + Vector3.new(0, math.sin(t * math.pi) * 2.5, 0))
		end
	end)

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

-- materiais de um inimigo: { {id, chance, min, max} }
function LootService.rollMaterials(player, dropTable, bonus)
	for _, entry in dropTable or {} do
		if math.random() <= entry.chance * (bonus or 1) then
			PlayerService.addMaterial(player, entry.id, math.random(entry.min, entry.max))
		end
	end
end

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
			-- VIP: o loot vem sozinho assim que cai no chão (dá tempo de ver o feixe)
			local vip = drop.owner:GetAttribute("Vip") == true and now >= drop.ready + 0.6
			if near or vip or now >= drop.expire then
				table.remove(drops, i)
				drop.model:Destroy()
				-- protegido: um erro ao entregar um item não pode parar a coleta de todos os outros
				local ok, err = pcall(PlayerService.addItem, drop.owner, drop.item)
				if not ok then
					warn("[Loot] Falha ao entregar item:", err)
				end
			end
		end
	end
end)

return LootService
