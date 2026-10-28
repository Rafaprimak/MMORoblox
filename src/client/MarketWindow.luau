-- Mercado dos Caçadores (casa de leilão entre servidores, no Otto). Abas:
--   Comprar: busca por nome, tipo e raridade; ícone 3D, perks, nível, vendedor; clique duas vezes para comprar.
--   Vender: inventário (sem os equipados) e materiais; preço com taxa e valor líquido calculados.
--   Meus anúncios: anúncios ativos com "Cancelar".
-- O servidor (MarketService) faz tudo; aqui só desenha e pede.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Items)
local Perks = require(Shared.Perks)
local Rarities = require(Shared.Rarities)

local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Window = require(script.Parent.Window)
local ItemIcon = require(script.Parent.ItemIcon)
local Popups = require(script.Parent.Popups)

local MarketWindow = {}

local TAX = 0.1
local FEE = 0.01

local win
local buyTab, sellTab, mineTab = {}, {}, {}
local filter = { kind = nil, rarity = nil }

local function text(parent, props)
	local merged = { TextScaled = false, TextSize = 14, TextWrapped = true, Font = Enum.Font.GothamBold }
	for key, value in props do
		merged[key] = value
	end
	merged.Parent = parent
	return UI.label(merged)
end

local function scrolling(parent, position, size)
	return UI.new("ScrollingFrame", { Position = position, Size = size, BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = parent }, { UI.list(6) })
end

local function rarityColor(rarityId)
	local rarity = rarityId and Rarities.ById[rarityId]
	return if rarity then rarity.color else UI.Colors.Text
end

-- ícone do que está à venda (equipamento em 3D, material pelo ícone do atlas)
local function thumb(row, entry)
	if entry.kind == "item" or entry.base then
		ItemIcon.new(row, entry.base, entry.rarity, { Size = UDim2.fromOffset(50, 50), Position = UDim2.fromOffset(4, 4) })
	else
		local def = Items.Materials[entry.material]
		UI.icon(def and def.icon or "help", { Position = UDim2.fromOffset(9, 9), Size = UDim2.fromOffset(40, 40), Parent = row })
	end
end

local function perkNames(perks)
	local names = {}
	for _, perkId in perks or {} do
		local perk = Perks.List[perkId]
		if perk then
			table.insert(names, perk.name)
		end
	end
	return table.concat(names, ", ")
end

-- ===================== COMPRAR =====================

local function search()
	local result = State.request("marketBrowse", { text = buyTab.search.Text, kind = filter.kind, rarity = filter.rarity })
	UI.clear(buyTab.list)
	if not result or not result.ok then
		text(buyTab.list, { Text = result and result.msg or "O mercado não respondeu.", Size = UDim2.new(1, -8, 0, 40), TextColor3 = UI.Colors.SubText })
		return
	end
	if #result.list == 0 then
		text(buyTab.list, { Text = "Nada à venda com esses filtros.", Size = UDim2.new(1, -8, 0, 30), TextColor3 = UI.Colors.SubText })
		return
	end
	for order, entry in result.list do
		local row = UI.new("Frame", { Size = UDim2.new(1, -8, 0, 58), BackgroundColor3 = UI.Colors.PanelLight, LayoutOrder = order, Parent = buyTab.list }, { UI.corner(8) })
		thumb(row, entry)
		local title = if entry.kind == "material" then ("%dx %s"):format(entry.count or 1, entry.name) else entry.name
		text(row, { Text = title, Position = UDim2.fromOffset(62, 4), Size = UDim2.new(1, -250, 0, 18), TextColor3 = rarityColor(entry.rarity), Font = Enum.Font.GothamBlack })
		local details = if entry.kind == "item" then ("Nv. %d  •  poder %s  •  %s"):format(entry.level or 1, UI.formatNumber(entry.power or 0), entry.seller or "?") else ("vendido por %s"):format(entry.seller or "?")
		text(row, { Text = details, Position = UDim2.fromOffset(62, 22), Size = UDim2.new(1, -250, 0, 16), TextSize = 12, TextColor3 = UI.Colors.SubText })
		local perks = perkNames(entry.perks)
		if perks ~= "" then
			text(row, { Text = perks, Position = UDim2.fromOffset(62, 38), Size = UDim2.new(1, -250, 0, 16), TextSize = 12, TextColor3 = Color3.fromRGB(200, 180, 255) })
		end
		local button = UI.button({ Text = ("%s ouro"):format(UI.formatNumber(entry.price)), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(170, 38), BackgroundColor3 = UI.Colors.Green, Parent = row })
		local armed = false
		button.MouseButton1Click:Connect(function()
			if not armed then
				armed = true
				button.Text = "Confirmar compra?"
				task.delay(3, function()
					if armed and button.Parent then
						armed = false
						button.Text = ("%s ouro"):format(UI.formatNumber(entry.price))
					end
				end)
				return
			end
			armed = false
			local reply = State.request("marketBuy", entry.id)
			if reply and reply.msg then
				Popups.message(reply.msg, if reply.ok then UI.Colors.Green else UI.Colors.Red)
			end
			search()
		end)
	end
end

local function buildBuy(page)
	local top = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, Parent = page })
	buyTab.search = UI.new("TextBox", { PlaceholderText = "Buscar pelo nome (ex.: katana, cobre)", Text = "", ClearTextOnFocus = false, Size = UDim2.new(1, -440, 0, 34), BackgroundColor3 = UI.Colors.PanelLight, TextColor3 = UI.Colors.Text, PlaceholderColor3 = UI.Colors.SubText, Font = Enum.Font.Gotham, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Parent = top }, { UI.corner(8), UI.padding(8) })
	local kinds = { { nil, "Tudo" }, { "item", "Equipamentos" }, { "material", "Materiais" } }
	local kindIndex = 1
	local kindButton = UI.button({ Text = "Tudo", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -300, 0, 0), Size = UDim2.fromOffset(130, 34), BackgroundColor3 = UI.Colors.Dark, Parent = top })
	kindButton.MouseButton1Click:Connect(function()
		kindIndex = kindIndex % #kinds + 1
		filter.kind = kinds[kindIndex][1]
		kindButton.Text = kinds[kindIndex][2]
	end)
	local rarityIndex = 0
	local rarityButton = UI.button({ Text = "Qualquer raridade", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -120, 0, 0), Size = UDim2.fromOffset(170, 34), BackgroundColor3 = UI.Colors.Dark, Parent = top })
	rarityButton.MouseButton1Click:Connect(function()
		rarityIndex = (rarityIndex + 1) % (#Rarities.List + 1)
		local rarity = Rarities.List[rarityIndex]
		filter.rarity = rarity and rarity.id or nil
		rarityButton.Text = rarity and rarity.name or "Qualquer raridade"
		rarityButton.TextColor3 = rarity and rarity.color or UI.Colors.Text
	end)
	local go = UI.button({ Text = "Buscar", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(110, 34), BackgroundColor3 = UI.Colors.Accent, Parent = top })
	go.MouseButton1Click:Connect(search)
	buyTab.search.FocusLost:Connect(function(enter)
		if enter then
			search()
		end
	end)
	buyTab.list = scrolling(page, UDim2.fromOffset(0, 46), UDim2.new(1, 0, 1, -46))
end

-- ===================== VENDER =====================

local selected = nil -- { uid } | { material, max }

local function updateSellDetail()
	local detail = sellTab.detail
	UI.clear(detail)
	if not selected then
		text(detail, { Text = "Escolha um item ou material à esquerda.", Size = UDim2.new(1, 0, 0, 40), TextColor3 = UI.Colors.SubText })
		return
	end
	text(detail, { Text = selected.name, Size = UDim2.new(1, 0, 0, 22), TextColor3 = rarityColor(selected.rarity), Font = Enum.Font.GothamBlack })
	local y = 30
	local count = nil
	if selected.material then
		text(detail, { Text = ("Quantidade (você tem %d):"):format(selected.max), Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 18) })
		count = UI.new("TextBox", { Text = tostring(selected.max), Position = UDim2.fromOffset(0, y + 22), Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = UI.Colors.PanelLight, TextColor3 = UI.Colors.Text, Font = Enum.Font.GothamBold, TextSize = 16, Parent = detail }, { UI.corner(8) })
		y += 62
	end
	text(detail, { Text = "Preço total (ouro):", Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 18) })
	local price = UI.new("TextBox", { Text = "", PlaceholderText = "ex.: 500", Position = UDim2.fromOffset(0, y + 22), Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = UI.Colors.PanelLight, TextColor3 = UI.Colors.Gold, PlaceholderColor3 = UI.Colors.SubText, Font = Enum.Font.GothamBold, TextSize = 16, Parent = detail }, { UI.corner(8) })
	local summaryLabel = text(detail, { Text = "", Position = UDim2.fromOffset(0, y + 60), Size = UDim2.new(1, 0, 0, 60), TextSize = 13, TextColor3 = UI.Colors.SubText })
	local function refresh()
		local value = tonumber(price.Text) or 0
		local fee = math.max(5, math.floor(value * FEE))
		summaryLabel.Text = ("Taxa para anunciar: %s ouro (agora)\nSe vender, você recebe %s ouro (o mercado fica com 10%%).\nO anúncio fica 48 h; se não vender, o item volta."):format(UI.formatNumber(fee), UI.formatNumber(math.floor(value * (1 - TAX))))
	end
	price:GetPropertyChangedSignal("Text"):Connect(refresh)
	refresh()
	local button = UI.button({ Text = "ANUNCIAR", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = UI.Colors.Green, Parent = detail })
	button.MouseButton1Click:Connect(function()
		local what = if selected.uid then { uid = selected.uid } else { material = selected.material, count = tonumber(count and count.Text) or 0 }
		local reply = State.request("marketSell", what, tonumber(price.Text) or 0)
		if reply and reply.msg then
			Popups.message(reply.msg, if reply.ok then UI.Colors.Green else UI.Colors.Red)
		end
		if reply and reply.ok then
			selected = nil
			MarketWindow.renderSell()
		end
	end)
end

function MarketWindow.renderSell()
	local data = State.data
	UI.clear(sellTab.list)
	if not data then
		return
	end
	local order = 0
	for _, item in data.inventory or {} do
		if not item.equipped then
			order += 1
			local row = UI.button({ Text = "", Size = UDim2.new(1, -8, 0, 44), BackgroundColor3 = UI.Colors.PanelLight, LayoutOrder = order, Parent = sellTab.list })
			ItemIcon.new(row, item.base, item.rarity, { Size = UDim2.fromOffset(38, 38), Position = UDim2.fromOffset(3, 3) })
			text(row, { Text = ("%s  •  Nv. %d"):format(item.name, item.level or 1), Position = UDim2.fromOffset(46, 4), Size = UDim2.new(1, -52, 0, 36), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = rarityColor(item.rarity) })
			row.MouseButton1Click:Connect(function()
				selected = { uid = item.uid, name = item.name, rarity = item.rarity }
				updateSellDetail()
			end)
		end
	end
	for id, amount in data.materials or {} do
		local def = Items.Materials[id]
		if def and amount > 0 then
			order += 1
			local row = UI.button({ Text = "", Size = UDim2.new(1, -8, 0, 40), BackgroundColor3 = UI.Colors.PanelLight, LayoutOrder = order, Parent = sellTab.list })
			UI.icon(def.icon, { Position = UDim2.fromOffset(6, 5), Size = UDim2.fromOffset(30, 30), Parent = row })
			text(row, { Text = ("%s  x%d"):format(def.name, amount), Position = UDim2.fromOffset(46, 4), Size = UDim2.new(1, -52, 0, 32), TextXAlignment = Enum.TextXAlignment.Left })
			row.MouseButton1Click:Connect(function()
				selected = { material = id, max = amount, name = def.name }
				updateSellDetail()
			end)
		end
	end
	updateSellDetail()
end

local function buildSell(page)
	sellTab.list = scrolling(page, UDim2.new(), UDim2.new(0.55, -8, 1, 0))
	sellTab.detail = UI.new("Frame", { Position = UDim2.new(0.55, 8, 0, 0), Size = UDim2.new(0.45, -8, 1, 0), BackgroundTransparency = 1, Parent = page })
end

-- ===================== MEUS ANÚNCIOS =====================

local function renderMine()
	local reply = State.request("marketMine")
	UI.clear(mineTab.list)
	if not reply or not reply.ok then
		return
	end
	if #reply.list == 0 then
		text(mineTab.list, { Text = "Você não tem anúncios. Anuncie na aba Vender.", Size = UDim2.new(1, -8, 0, 30), TextColor3 = UI.Colors.SubText })
		return
	end
	for order, entry in reply.list do
		local row = UI.new("Frame", { Size = UDim2.new(1, -8, 0, 58), BackgroundColor3 = UI.Colors.PanelLight, LayoutOrder = order, Parent = mineTab.list }, { UI.corner(8) })
		thumb(row, entry)
		text(row, { Text = entry.name or "?", Position = UDim2.fromOffset(62, 6), Size = UDim2.new(1, -250, 0, 20), TextColor3 = rarityColor(entry.rarity), Font = Enum.Font.GothamBlack })
		text(row, { Text = ("à venda por %s ouro"):format(UI.formatNumber(entry.price or 0)), Position = UDim2.fromOffset(62, 28), Size = UDim2.new(1, -250, 0, 18), TextColor3 = UI.Colors.Gold })
		local cancel = UI.button({ Text = "Cancelar", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(130, 36), BackgroundColor3 = Color3.fromRGB(150, 50, 50), Parent = row })
		cancel.MouseButton1Click:Connect(function()
			local result = State.request("marketCancel", entry.id)
			if result and result.ok then
				Popups.message("Anúncio cancelado: o item voltou.", UI.Colors.Green)
			end
			renderMine()
		end)
	end
end

function MarketWindow.open()
	win:open()
end

function MarketWindow.init(screen)
	win = Window.create(screen, { icon = "scales", name = "Mercado", title = "MERCADO DOS CAÇADORES", width = 820, height = 560, tabs = { "Comprar", "Vender", "Meus anúncios" }, accent = UI.Colors.Gold })
	local pages = {}
	for i = 1, 3 do
		pages[i] = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = i == 1, Parent = win.content })
	end
	buildBuy(pages[1])
	buildSell(pages[2])
	mineTab.list = scrolling(pages[3], UDim2.new(), UDim2.fromScale(1, 1))
	local names = { "Comprar", "Vender", "Meus anúncios" }
	local function show(name)
		local index = table.find(names, name) or 1
		for i, page in pages do
			page.Visible = i == index
		end
		if index == 1 then
			search()
		elseif index == 2 then
			MarketWindow.renderSell()
		else
			renderMine()
		end
	end
	win.onTab = show
	win.onOpen = function()
		show(win.tab)
	end
end

return MarketWindow
