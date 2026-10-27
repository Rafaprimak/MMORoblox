-- Fusão de equipamentos (janela): escolha a raridade, marque 9 itens dela (não equipados) e funda.
-- As chances de subir 1, 2 ou 3 raridades (Config.Fusion) aparecem antes de fundir.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Rarities = require(Shared.Rarities)

local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Window = require(script.Parent.Window)
local Sounds = require(script.Parent.Sounds)
local ItemIcon = require(script.Parent.ItemIcon)

local FusionWindow = {}

local win, rarityBar, grid, slots, oddsLabel, fuseButton, autoButton
local selectedRarity = "Comum"
local selected = {} -- lista de uids, na ordem em que foram marcados
local lastKey = nil

local function eligible()
	local list = {}
	for _, item in State.data and State.data.inventory or {} do
		local rarity = Rarities.ById[item.rarity]
		if rarity and not item.equipped and not item.unique and item.rarity == selectedRarity then
			table.insert(list, item)
		end
	end
	table.sort(list, function(a, b)
		if a.power ~= b.power then
			return a.power < b.power
		end
		return a.uid < b.uid
	end)
	return list
end

local function isSelected(uid)
	return table.find(selected, uid) ~= nil
end

local function renderSlots()
	UI.clear(slots)
	local inventory = {}
	for _, item in State.data and State.data.inventory or {} do
		inventory[item.uid] = item
	end
	for i = 1, Config.Fusion.count do
		local cell = UI.new("Frame", { LayoutOrder = i, BackgroundColor3 = UI.Colors.PanelLight, BackgroundTransparency = 0.2, Parent = slots }, { UI.corner(8), UI.stroke(UI.Colors.Stroke, 1) })
		local item = selected[i] and inventory[selected[i]]
		if item then
			ItemIcon.new(cell, item.base, item.rarity, { Size = UDim2.fromScale(0.9, 0.9), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) })
		end
	end
	local rarity = Rarities.ById[selectedRarity]
	local lines = {}
	for _, entry in Config.Fusion.jumps do
		local target = Rarities.ByOrder[math.min(rarity.order + entry.jump, Rarities.ById.Secreto.order)]
		table.insert(lines, ("%s: %g%%"):format(target.name, entry.chance * 100))
	end
	oddsLabel.Text = "Resultado: " .. table.concat(lines, "   •   ")
	local ready = #selected == Config.Fusion.count
	fuseButton.Text = if ready then "FUNDIR" else ("Escolha %d itens (%d/%d)"):format(Config.Fusion.count, #selected, Config.Fusion.count)
	fuseButton.BackgroundColor3 = if ready then Color3.fromRGB(150, 80, 200) else UI.Colors.Dark
end

local function render(force)
	local data = State.data
	if not data then
		return
	end
	-- some da seleção o que não existe mais
	local present = {}
	for _, item in data.inventory do
		present[item.uid] = item
	end
	for i = #selected, 1, -1 do
		local item = present[selected[i]]
		if not item or item.equipped or item.rarity ~= selectedRarity then
			table.remove(selected, i)
		end
	end
	local keyParts = { selectedRarity, table.concat(selected, ",") }
	for _, item in data.inventory do
		table.insert(keyParts, item.uid .. item.rarity .. tostring(item.equipped))
	end
	local key = table.concat(keyParts, "|")
	if key == lastKey and not force then
		return
	end
	lastKey = key
	-- botões de raridade (com quantos itens você tem de cada)
	UI.clear(rarityBar)
	for _, rarity in Rarities.List do
		if rarity.order < Rarities.ById.Secreto.order then
			local count = 0
			for _, item in data.inventory do
				if item.rarity == rarity.id and not item.equipped and not item.unique then
					count += 1
				end
			end
			local button = UI.button({ Text = ("%s (%d)"):format(rarity.name, count), Size = UDim2.fromOffset(104, 30), LayoutOrder = rarity.order, BackgroundColor3 = if rarity.id == selectedRarity then rarity.color:Lerp(Color3.new(0, 0, 0), 0.35) else UI.Colors.PanelLight, TextColor3 = rarity.color, Parent = rarityBar })
			button.MouseButton1Click:Connect(function()
				selectedRarity = rarity.id
				selected = {}
				render(true)
			end)
		end
	end
	-- itens da raridade escolhida (clique marca/desmarca)
	UI.clear(grid)
	for index, item in eligible() do
		local rarity = Rarities.ById[item.rarity]
		local chosen = isSelected(item.uid)
		local cell = UI.new("TextButton", { Text = "", LayoutOrder = index, AutoButtonColor = true, BackgroundColor3 = rarity.color:Lerp(Color3.new(0, 0, 0), if chosen then 0.3 else 0.7), Parent = grid }, { UI.corner(8), UI.stroke(if chosen then Color3.new(1, 1, 1) else rarity.color, if chosen then 3 else 1.5) })
		ItemIcon.new(cell, item.base, item.rarity, { Size = UDim2.fromScale(0.8, 0.62), Position = UDim2.fromScale(0.5, 0.02), AnchorPoint = Vector2.new(0.5, 0), glow = false })
		UI.label({ Text = item.name, Size = UDim2.new(1, -4, 0.3, 0), Position = UDim2.new(0, 2, 0.66, 0), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = rarity.color, Parent = cell }, { UI.textStroke(1) })
		if chosen then
			UI.label({ Text = "✔", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -3, 0, 2), Size = UDim2.fromOffset(18, 18), TextColor3 = UI.Colors.Green, Font = Enum.Font.GothamBlack, Parent = cell }, { UI.textStroke(1) })
		end
		cell.MouseButton1Click:Connect(function()
			local at = table.find(selected, item.uid)
			if at then
				table.remove(selected, at)
			elseif #selected < Config.Fusion.count then
				table.insert(selected, item.uid)
			end
			Sounds.play("ping", 2, 0.1)
			render(true)
		end)
	end
	renderSlots()
end

function FusionWindow.init(screen)
	win = Window.create(screen, { icon = "round-bottom-flask", name = "Fusao", title = "FUSÃO DE EQUIPAMENTOS", width = 780, height = 560, accent = Color3.fromRGB(190, 120, 255) })
	UI.label({ Text = ("Junte %d itens da mesma raridade (não equipados) e eles viram 1 item de raridade maior, de uma das bases que você colocou, no maior nível entre eles. Únicos não entram."):format(Config.Fusion.count), Size = UDim2.new(1, 0, 0, 34), TextScaled = false, TextSize = 13, TextWrapped = true, TextColor3 = UI.Colors.SubText, Parent = win.content })
	rarityBar = UI.new("Frame", { Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, Parent = win.content }, { UI.list(6, true) })
	grid = UI.new("ScrollingFrame", { Position = UDim2.fromOffset(0, 76), Size = UDim2.new(1, -270, 1, -76), BackgroundColor3 = UI.Colors.PanelLight, BackgroundTransparency = 0.3, BorderSizePixel = 0, ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = win.content }, {
		UI.corner(10),
		UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(78, 78), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		UI.padding(6),
	})
	local side = UI.new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 76), Size = UDim2.new(0, 258, 1, -76), BackgroundColor3 = UI.Colors.PanelLight, BackgroundTransparency = 0.3, Parent = win.content }, { UI.corner(10), UI.padding(10) })
	UI.label({ Text = "CUBO DE FUSÃO", Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Center, FontFace = UI.TitleFont, TextColor3 = Color3.fromRGB(220, 180, 255), Parent = side }, { UI.textStroke(1) })
	slots = UI.new("Frame", { Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 222), BackgroundTransparency = 1, Parent = side }, {
		UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(72, 70), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }),
	})
	oddsLabel = UI.label({ Text = "", Position = UDim2.fromOffset(0, 254), Size = UDim2.new(1, 0, 0, 48), TextScaled = false, TextSize = 13, TextWrapped = true, TextColor3 = UI.Colors.Gold, Parent = side })
	autoButton = UI.button({ Text = "Escolher os 9 mais fracos", Position = UDim2.new(0, 0, 1, -94), Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = UI.Colors.PanelLight, Parent = side })
	autoButton.MouseButton1Click:Connect(function()
		selected = {}
		for _, item in eligible() do
			if #selected >= Config.Fusion.count then
				break
			end
			table.insert(selected, item.uid)
		end
		render(true)
	end)
	fuseButton = UI.button({ Text = "FUNDIR", Position = UDim2.new(0, 0, 1, -50), Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = UI.Colors.Dark, Parent = side })
	fuseButton.MouseButton1Click:Connect(function()
		if #selected ~= Config.Fusion.count then
			return
		end
		local result = State.request("fuse", selected)
		if result and result.ok then
			selected = {}
			Sounds.play(if result.jump and result.jump >= 2 then "lootRare" else "loot", 1, 0.7)
		end
	end)
	win.onOpen = function()
		render(true)
	end
	State.Changed:Connect(function()
		if win:isOpen() then
			render(false)
		end
	end)
end

function FusionWindow.open()
	win:open()
end

function FusionWindow.toggle()
	win:toggle()
end

return FusionWindow
