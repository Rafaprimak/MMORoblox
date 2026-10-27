-- Grade de equipamentos reutilizável (inventário, forja, encantador).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rarities = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Rarities"))

local UI = require(script.Parent.UI)
local Fx = require(script.Parent.Fx)
local ItemIcon = require(script.Parent.ItemIcon)
local Sounds = require(script.Parent.Sounds)

local ItemGrid = {}

function ItemGrid.create(parent, props)
	local frame = UI.new("ScrollingFrame", {
		Position = props.Position,
		Size = props.Size,
		BackgroundColor3 = UI.Colors.PanelLight,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = parent,
	}, {
		UI.corner(10),
		UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(props.cell or 84, props.cell or 84), CellPadding = UDim2.fromOffset(7, 7), SortOrder = Enum.SortOrder.LayoutOrder }),
		UI.padding(7),
	})
	return frame
end

function ItemGrid.sort(items)
	local list = table.clone(items or {})
	table.sort(list, function(a, b)
		if a.equipped ~= b.equipped then
			return a.equipped
		end
		if a.order ~= b.order then
			return a.order > b.order
		end
		if a.power ~= b.power then
			return a.power > b.power
		end
		return a.uid < b.uid
	end)
	return list
end

function ItemGrid.render(frame, items, selectedUid, onSelect, filter)
	-- os ícones 3D custam: só redesenha se algo mudou (itens, seleção ou filtro)
	local parts = { tostring(selectedUid), tostring(filter) }
	for _, item in items or {} do
		table.insert(parts, ("%s:%s:%d:%d:%s:%s"):format(item.uid, item.rarity, item.power, item.upgrade, tostring(item.equipped), item.enchant and item.enchant.id or ""))
	end
	local signature = table.concat(parts, "|")
	if frame:GetAttribute("Assinatura") == signature then
		return
	end
	frame:SetAttribute("Assinatura", signature)
	UI.clear(frame)
	for index, item in ItemGrid.sort(items) do
		if filter and not filter(item) then
			continue
		end
		local rarity = Rarities.ById[item.rarity] or Rarities.List[1]
		local selected = item.uid == selectedUid
		local stroke = UI.stroke(if selected then Color3.new(1, 1, 1) else rarity.color, if selected then 3 else 1.5)
		local cell = UI.new("TextButton", { Text = "", LayoutOrder = index, AutoButtonColor = true, BackgroundColor3 = rarity.color:Lerp(Color3.new(0, 0, 0), 0.66), Parent = frame }, { UI.corner(8), stroke })
		if rarity.rainbow and not selected then
			Fx.registerRainbow(stroke, "Color")
		end
		ItemIcon.new(cell, item.base, item.rarity, { Size = UDim2.fromScale(0.72, 0.56), Position = UDim2.fromScale(0.5, 0.02), AnchorPoint = Vector2.new(0.5, 0) })
		if item.unique then
			UI.label({ Text = "ÚNICO", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 2), Size = UDim2.fromOffset(46, 13), TextColor3 = rarity.color, TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamBlack, ZIndex = 4, Parent = cell }, { UI.textStroke(1) })
		elseif item.set then
			UI.iconImage("emerald", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -4, 0.58, 0), Size = UDim2.fromOffset(14, 14), Color = Color3.fromRGB(120, 255, 170), ZIndex = 4, Parent = cell }, { UI.textStroke(1) })
		end
		UI.label({ Text = item.name, Size = UDim2.new(1, -6, 0.18, 0), Position = UDim2.new(0, 3, 0.56, 0), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = rarity.color, Parent = cell }, { UI.textStroke(1) })
		local statRow = UI.new("Frame", { Size = UDim2.new(1, -6, 0.16, 0), Position = UDim2.new(0, 3, 0.78, 0), BackgroundTransparency = 1, Parent = cell })
		UI.icon(UI.statIcon(item), { SizeConstraint = Enum.SizeConstraint.RelativeYY, Size = UDim2.fromScale(1, 1), Position = UDim2.fromScale(0.1, 0), Parent = statRow })
		UI.label({ Text = tostring(item.power), Size = UDim2.fromScale(0.6, 1), Position = UDim2.fromScale(0.36, 0), Parent = statRow }, { UI.textStroke(1) })
		if item.upgrade > 0 then
			UI.label({ Text = "+" .. item.upgrade, Size = UDim2.fromOffset(28, 15), Position = UDim2.fromOffset(4, 3), TextColor3 = UI.Colors.Gold, Parent = cell }, { UI.textStroke(1) })
		end
		if item.enchant then
			UI.icon("sparkles", { Size = UDim2.fromOffset(16, 16), Position = UDim2.new(1, -20, 1, -20), Color = Color3.fromRGB(210, 170, 255), Parent = cell })
		end
		if item.equipped then
			UI.label({ Text = "E", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(18, 18), BackgroundTransparency = 0, BackgroundColor3 = UI.Colors.Green, TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamBlack, Parent = cell }, { UI.corner(9) })
		end
		cell.MouseButton1Click:Connect(function()
			Sounds.play("ping", 2.2, 0.1)
			onSelect(item.uid)
		end)
	end
end

function ItemGrid.find(items, uid)
	for _, item in items or {} do
		if item.uid == uid then
			return item
		end
	end
	return nil
end

return ItemGrid
