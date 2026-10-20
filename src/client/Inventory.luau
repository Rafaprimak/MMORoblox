-- Inventário: equipamentos, materiais e consumíveis.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Items)
local Rarities = require(Shared.Rarities)
local Classes = require(Shared.Classes)

local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Window = require(script.Parent.Window)
local ItemGrid = require(script.Parent.ItemGrid)
local Sounds = require(script.Parent.Sounds)
local Popups = require(script.Parent.Popups)

local Inventory = {}

local win, grid, details, list, junkButton, statsLabel
local selectedUid = nil
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
		table.insert(lines, { "Tipo: Armadura", UI.Colors.SubText })
		if item.bonus and item.bonus.mana then
			table.insert(lines, { ("+%d de mana"):format(item.bonus.mana), UI.Colors.Mana })
		end
		if item.bonus and item.bonus.stamina then
			table.insert(lines, { ("+%d de estamina"):format(item.bonus.stamina), UI.Colors.Stamina })
		end
	end
	if item.enchantText then
		table.insert(lines, { "✨ " .. item.enchantText, Color3.fromRGB(200, 150, 255) })
	end
	return lines
end

local function renderDetails()
	UI.clear(details)
	local data = State.data
	local item = data and selectedUid and ItemGrid.find(data.inventory, selectedUid)
	if not item then
		line(details, 120, "Clique em um item para ver detalhes", UI.Colors.SubText, 40).TextXAlignment = Enum.TextXAlignment.Center
		return
	end
	local rarity = Rarities.ById[item.rarity] or Rarities.List[1]
	line(details, 0, item.name, rarity.color, 40, Enum.Font.GothamBlack).TextScaled = true
	line(details, 42, ("%s • Nv. %d • +%d/%d"):format(rarity.name, item.level, item.upgrade, item.maxUpgrade), UI.Colors.SubText)
	line(details, 62, UI.statIcon(item) .. " " .. UI.formatNumber(item.power), UI.Colors.Text, 34, Enum.Font.GothamBlack).TextScaled = true
	local y = 100
	if not item.equipped then
		local current = equippedIn(item.slot)
		local diff = item.power - (if current then current.power else 0)
		line(details, y, (if diff >= 0 then "▲ +" else "▼ ") .. diff .. " comparado ao equipado", if diff >= 0 then UI.Colors.Green else UI.Colors.Red)
	else
		line(details, y, "✔ Equipado", UI.Colors.Green)
	end
	y += 20
	for _, entry in Inventory.describeLines(item) do
		line(details, y, entry[1], entry[2], 30).TextScaled = false
		y += 22
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
	if equipment then
		ItemGrid.render(grid, data.inventory, selectedUid, function(uid)
			selectedUid = uid
			render()
		end)
		renderDetails()
	else
		renderMaterials(if win.tab == "Materiais" then "materials" else "consumables")
	end
end

function Inventory.init(screen)
	win = Window.create(screen, { name = "Inventario", title = "🎒 INVENTÁRIO", width = 700, height = 500, tabs = { "Equipamentos", "Materiais", "Consumíveis" } })
	statsLabel = UI.label({ Text = "", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -56, 0, 16), Size = UDim2.fromOffset(320, 20), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = UI.Colors.SubText, Parent = win.frame })
	grid = ItemGrid.create(win.content, { Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, -250, 1, -46) })
	details = UI.new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 238, 1, -2), BackgroundColor3 = UI.Colors.PanelLight, BackgroundTransparency = 0.3, Parent = win.content }, { UI.corner(10), UI.padding(10) })
	list = UI.new("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false, Parent = win.content }, { UI.list(6) })
	junkButton = UI.button({ Text = "🗑 Vender Comuns e Incomuns", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.fromOffset(260, 36), BackgroundColor3 = Color3.fromRGB(110, 60, 60), Parent = win.content })
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
