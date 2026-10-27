-- Inventário: equipamentos, materiais e consumíveis.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Items)
local Rarities = require(Shared.Rarities)
local Classes = require(Shared.Classes)
local Perks = require(Shared.Perks)

local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Window = require(script.Parent.Window)
local ItemGrid = require(script.Parent.ItemGrid)
local Sounds = require(script.Parent.Sounds)
local Popups = require(script.Parent.Popups)
local ItemIcon = require(script.Parent.ItemIcon)

local Inventory = {}

-- preenchido pelo init: abre a janela de Fusão
Inventory.onFusion = function() end

local win, grid, details, list, junkButton, statsLabel, slotBar
local selectedUid = nil
local detailIcon, detailIconKey = nil, nil -- ícone 3D do item selecionado (fora de "details", que é redesenhado sempre)

local function setDetailIcon(item)
	local key = if item then item.base .. "|" .. item.rarity else nil
	if key == detailIconKey then
		return
	end
	detailIconKey = key
	if detailIcon then
		detailIcon:Destroy()
		detailIcon = nil
	end
	if item and win then
		detailIcon = ItemIcon.new(win.content, item.base, item.rarity, { Size = UDim2.fromOffset(104, 104), Position = UDim2.new(1, -119, 0, 2), AnchorPoint = Vector2.new(0.5, 0), spin = true, ZIndex = 5 })
	end
end
local junkConfirm = false

local function equippedIn(slot)
	for _, item in State.data.inventory do
		if item.equipped and item.slot == slot then
			return item
		end
	end
	return nil
end

local function line(parent, y, text, color, height, font)
	return UI.label({ Text = text, Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, height or 17), TextColor3 = color or UI.Colors.Text, Font = font or Enum.Font.GothamBold, TextWrapped = true, Parent = parent })
end

function Inventory.describeLines(item)
	local lines = {}
	if item.slot == "weapon" then
		local weaponType = Items.WeaponTypes[item.weaponType]
		table.insert(lines, { ("Tipo: %s"):format(if weaponType then weaponType.name else "Arma"), UI.Colors.SubText })
		local data = State.data
		local class = data and Classes.List[data.class]
		if class and class.weapons[item.weaponType] then
			table.insert(lines, { "★ Arma da sua classe (+15% de dano)", UI.Colors.Green })
		end
	else
		local slotInfo = Items.Slots[item.slot]
		table.insert(lines, { "Tipo: " .. (if slotInfo then slotInfo.name else "Equipamento"), UI.Colors.SubText })
		if item.bonus and item.bonus.mana then
			table.insert(lines, { ("+%d de mana"):format(item.bonus.mana), UI.Colors.Mana })
		end
		if item.bonus and item.bonus.stamina then
			table.insert(lines, { ("+%d de estamina"):format(item.bonus.stamina), UI.Colors.Stamina })
		end
	end
	for _, text in Items.statLines(item.stats) do
		table.insert(lines, { text, Color3.fromRGB(255, 220, 140) })
	end
	if item.enchantText then
		table.insert(lines, { "✨ " .. item.enchantText, Color3.fromRGB(200, 150, 255), 34 })
	end
	-- perks (estilo Destiny): os fortes em dourado, o efeito Único em verde-água
	for _, perkId in item.perks or {} do
		local perk = Perks.List[perkId]
		if perk then
			local color = if perk.exclusive == "unique" then Color3.fromRGB(60, 255, 215) elseif perk.exclusive then Color3.fromRGB(200, 170, 255) elseif perk.major then UI.Colors.Gold else Color3.fromRGB(150, 220, 255)
			table.insert(lines, { ("%s %s: %s"):format(perk.icon, perk.name, perk.text), color, 36 })
		end
	end
	if item.unique then
		table.insert(lines, { "✦ ÚNICO: só cai de chefes, muito raro.", Color3.fromRGB(60, 255, 215), 18 })
	end
	-- conjunto: peças equipadas e bônus (ativos em verde)
	local set = item.set and Items.Sets[item.set]
	if set then
		local equipped = 0
		for _, other in State.data and State.data.inventory or {} do
			if other.equipped and other.set == item.set then
				equipped += 1
			end
		end
		table.insert(lines, { ("◆ Conjunto %s (%d/%d)"):format(set.name, equipped, #set.pieces), Color3.fromRGB(120, 255, 170), 18 })
		for _, pieces in { 2, 4 } do
			local bonus = set.bonuses[pieces]
			if bonus then
				table.insert(lines, { ("  %d peças: %s"):format(pieces, bonus.text), if equipped >= pieces then Color3.fromRGB(120, 255, 170) else UI.Colors.SubText, 34 })
			end
		end
	end
	return lines
end

local function renderDetails()
	UI.clear(details)
	local data = State.data
	local item = data and selectedUid and ItemGrid.find(data.inventory, selectedUid)
	if not item then
		setDetailIcon(nil)
		line(details, 120, "Clique em um item para ver detalhes", UI.Colors.SubText, 40).TextXAlignment = Enum.TextXAlignment.Center
		return
	end
	local rarity = Rarities.ById[item.rarity] or Rarities.List[1]
	-- modelo 3D girando no topo
	setDetailIcon(item)
	local top = 100
	line(details, top, item.name, rarity.color, 30, Enum.Font.GothamBlack).TextScaled = true
	line(details, top + 32, ("%s • Nv. %d • +%d/%d"):format(rarity.name, item.level, item.upgrade, item.maxUpgrade), UI.Colors.SubText)
	line(details, top + 52, UI.statIcon(item) .. " " .. UI.formatNumber(item.power), UI.Colors.Text, 26, Enum.Font.GothamBlack).TextScaled = true
	local y = top + 82
	if not item.equipped then
		local current = equippedIn(item.slot)
		local diff = item.power - (if current then current.power else 0)
		line(details, y, (if diff >= 0 then "▲ +" else "▼ ") .. diff .. " comparado ao equipado", if diff >= 0 then UI.Colors.Green else UI.Colors.Red)
	else
		line(details, y, "✔ Equipado", UI.Colors.Green)
	end
	y += 20
	-- lista rolável para caber perks e stats sem cobrir os botões
	local scroll = UI.new("ScrollingFrame", { Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 1, -y - 88), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = details }, { UI.list(4) })
	for index, entry in Inventory.describeLines(item) do
		local label = UI.label({ Text = entry[1], Size = UDim2.new(1, -6, 0, entry[3] or 18), TextColor3 = entry[2], Font = Enum.Font.GothamBold, TextScaled = false, TextSize = 13, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = index, Parent = scroll })
		local _ = label
	end

	local equipButton = UI.button({ Text = if item.equipped then "EQUIPADO" else "EQUIPAR", Position = UDim2.new(0, 0, 1, -80), Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = if item.equipped then UI.Colors.Dark else UI.Colors.Green, Parent = details })
	equipButton.MouseButton1Click:Connect(function()
		if not item.equipped then
			local result = State.request("equip", item.uid)
			if result and result.ok then
				Sounds.play("equip", 1, 0.6)
			end
		end
	end)
	local sellButton = UI.button({ Text = if item.equipped then "—" else ("VENDER 💰%s"):format(UI.formatNumber(item.sell)), Position = UDim2.new(0, 0, 1, -38), Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = if item.equipped then UI.Colors.Dark else Color3.fromRGB(150, 60, 60), Parent = details })
	sellButton.MouseButton1Click:Connect(function()
		if not item.equipped then
			local result = State.request("sell", item.uid)
			if result and result.ok then
				Sounds.play("ping", 0.8, 0.4)
				Popups.message(("Vendido por %d de ouro"):format(result.gold), UI.Colors.Gold)
			end
		end
	end)
end

local function renderMaterials(kind)
	UI.clear(list)
	local data = State.data
	if not data then
		return
	end
	local entries = {}
	if kind == "materials" then
		for id, count in data.materials or {} do
			local def = Items.Materials[id]
			if def and count > 0 then
				table.insert(entries, { id = id, def = def, count = count })
			end
		end
	else
		for _, id in Items.ConsumableOrder do
			local count = data.consumables and data.consumables[id] or 0
			table.insert(entries, { id = id, def = Items.Consumables[id], count = count })
		end
	end
	table.sort(entries, function(a, b)
		return a.def.name < b.def.name
	end)
	if #entries == 0 then
		line(list, 0, "Nada aqui ainda. Colete minérios, plantas e derrote monstros!", UI.Colors.SubText, 40)
		return
	end
	for i, entry in entries do
		local row = UI.new("Frame", { Size = UDim2.new(1, -8, 0, 40), BackgroundColor3 = UI.Colors.PanelLight, BackgroundTransparency = 0.3, LayoutOrder = i, Parent = list }, { UI.corner(8) })
		UI.label({ Text = entry.def.icon, Position = UDim2.fromOffset(8, 5), Size = UDim2.fromOffset(30, 30), TextXAlignment = Enum.TextXAlignment.Center, Parent = row })
		UI.label({ Text = entry.def.name, Position = UDim2.fromOffset(46, 4), Size = UDim2.new(0.5, 0, 0, 20), Parent = row })
		local info = if kind == "materials" then ("Vende por %d no Otto"):format(entry.def.sell) else (entry.def.key and ("Tecla %s"):format(entry.def.key) or "Pela mochila")
		UI.label({ Text = info, Position = UDim2.fromOffset(46, 23), Size = UDim2.new(0.5, 0, 0, 14), TextColor3 = UI.Colors.SubText, Font = Enum.Font.Gotham, Parent = row })
		UI.label({ Text = "x" .. UI.formatNumber(entry.count), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -110, 0, 8), Size = UDim2.fromOffset(80, 24), TextXAlignment = Enum.TextXAlignment.Right, Font = Enum.Font.GothamBlack, Parent = row })
		if kind == "consumables" and entry.count > 0 then
			local use = UI.button({ Text = "USAR", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(90, 30), BackgroundColor3 = UI.Colors.Green, Parent = row })
			use.MouseButton1Click:Connect(function()
				State.action("potion", entry.id)
			end)
		end
	end
end

local function render()
	local data = State.data
	if not data then
		return
	end
	win.title.Text = ("🎒 INVENTÁRIO  (%d/%d)"):format(#data.inventory, data.maxInventory)
	statsLabel.Text = ("⚔ %s   ❤ %s   🛡 %s   🎯 %d%%"):format(UI.formatNumber(data.stats.attack), UI.formatNumber(data.stats.maxHealth), UI.formatNumber(data.stats.defense), math.floor(data.stats.crit * 100))
	local equipment = win.tab == "Equipamentos"
	grid.Visible = equipment
	details.Visible = equipment
	junkButton.Visible = equipment
	list.Visible = not equipment
	slotBar.Visible = equipment
	if equipment then
		UI.clear(slotBar)
		for index, slot in Items.SlotOrder do
			local info = Items.Slots[slot]
			local item = equippedIn(slot)
			local rarity = item and Rarities.ById[item.rarity]
			local cell = UI.new("TextButton", { Text = "", LayoutOrder = index, Size = UDim2.fromOffset(62, 44), BackgroundColor3 = if rarity then rarity.color:Lerp(Color3.new(0, 0, 0), 0.6) else UI.Colors.Panel, Parent = slotBar }, { UI.corner(8), UI.stroke(if rarity then rarity.color else UI.Colors.Stroke, 1.5) })
			if item then
				ItemIcon.new(cell, item.base, item.rarity, { Size = UDim2.new(1, 0, 0, 28), glow = false })
			else
				UI.label({ Text = info.name, Size = UDim2.new(1, 0, 0, 26), TextXAlignment = Enum.TextXAlignment.Center, TextTransparency = 0.6, TextColor3 = UI.Colors.SubText, Parent = cell })
			end
			UI.label({ Text = if item then ("+%d"):format(item.upgrade) else "vazio", Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 0, 14), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = UI.Colors.SubText, Font = Enum.Font.Gotham, Parent = cell })
			cell.MouseButton1Click:Connect(function()
				if item then
					selectedUid = item.uid
					render()
				end
			end)
		end
		ItemGrid.render(grid, data.inventory, selectedUid, function(uid)
			selectedUid = uid
			render()
		end)
		renderDetails()
	else
		setDetailIcon(nil)
		renderMaterials(if win.tab == "Materiais" then "materials" else "consumables")
	end
end

function Inventory.init(screen)
	win = Window.create(screen, { name = "Inventario", title = "🎒 INVENTÁRIO", width = 760, height = 560, tabs = { "Equipamentos", "Materiais", "Consumíveis" } })
	statsLabel = UI.label({ Text = "", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -56, 0, 16), Size = UDim2.fromOffset(320, 20), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = UI.Colors.SubText, Parent = win.frame })
	slotBar = UI.new("Frame", { Size = UDim2.new(1, -250, 0, 44), BackgroundTransparency = 1, Parent = win.content }, { UI.list(6, true) })
	grid = ItemGrid.create(win.content, { Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, -250, 1, -96) })
	details = UI.new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 238, 1, -2), BackgroundColor3 = UI.Colors.PanelLight, BackgroundTransparency = 0.3, Parent = win.content }, { UI.corner(10), UI.padding(10) })
	list = UI.new("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false, Parent = win.content }, { UI.list(6) })
	junkButton = UI.button({ Text = "🗑 Vender Comuns e Incomuns", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.fromOffset(260, 36), BackgroundColor3 = Color3.fromRGB(110, 60, 60), Parent = win.content })
	-- fusão: 9 itens da mesma raridade viram 1 de raridade maior
	local fusionButton = UI.button({ Text = "⚗ Fundir itens (9 → 1)", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 268, 1, 0), Size = UDim2.fromOffset(220, 36), BackgroundColor3 = Color3.fromRGB(120, 70, 170), Parent = win.content })
	fusionButton.MouseButton1Click:Connect(function()
		if Inventory.onFusion then
			Inventory.onFusion()
		end
	end)
	junkButton.MouseButton1Click:Connect(function()
		if not junkConfirm then
			junkConfirm = true
			junkButton.Text = "Clique de novo para confirmar"
			task.delay(3, function()
				junkConfirm = false
				junkButton.Text = "🗑 Vender Comuns e Incomuns"
			end)
			return
		end
		junkConfirm = false
		junkButton.Text = "🗑 Vender Comuns e Incomuns"
		local result = State.request("sellJunk")
		if result and result.ok then
			Sounds.play("ping", 0.8, 0.4)
			Popups.message(("%d itens vendidos por %d de ouro"):format(result.count, result.gold), UI.Colors.Gold)
		end
	end)
	win.onTab = render
	win.onOpen = render
	State.Changed:Connect(function()
		if win:isOpen() then
			render()
		end
	end)
end

function Inventory.toggle()
	win:toggle()
end

function Inventory.open()
	win:open()
end

return Inventory
