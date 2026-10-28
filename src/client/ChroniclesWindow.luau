-- Crônicas (tecla Y): reputação com as facções (degrau atual, barra até o próximo e a recompensa) e o
-- diário de lore (páginas liberadas para ler; as trancadas mostram uma dica de como achar).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Factions = require(Shared.Factions)
local Lore = require(Shared.Lore)
local Progression = require(Shared.Progression)

local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Window = require(script.Parent.Window)

local ChroniclesWindow = {}

local win
local pages = {}
local selectedPage = nil
local lastKey = nil

local function text(parent, props)
	local merged = { TextScaled = false, TextSize = 14, TextWrapped = true, Font = Enum.Font.GothamBold }
	for k, v in props do
		merged[k] = v
	end
	merged.Parent = parent
	return UI.label(merged)
end

local function renderFactions(page, chronicle)
	local reps = chronicle and chronicle.factions or {}
	for i, faction in Factions.List do
		local rep = reps[faction.id] or 0
		local tierIndex = Factions.tier(rep)
		local tier = Factions.Tiers[tierIndex]
		local nextTier = Factions.Tiers[tierIndex + 1]
		local card = UI.new("Frame", { Position = UDim2.fromOffset(0, (i - 1) * 140), Size = UDim2.new(1, 0, 0, 130), BackgroundColor3 = UI.Colors.PanelLight, Parent = page }, { UI.corner(10), UI.stroke(faction.color, 1.5, 0.4) })
		UI.icon(faction.icon, { Position = UDim2.fromOffset(12, 14), Size = UDim2.fromOffset(64, 64), Color = faction.color, Parent = card })
		text(card, { Text = faction.name, Position = UDim2.fromOffset(88, 8), Size = UDim2.new(1, -100, 0, 24), TextSize = 18, FontFace = UI.TitleFont, TextColor3 = faction.color })
		text(card, { Text = ("%s  •  %s de reputação"):format(tier.name, UI.formatNumber(rep)), Position = UDim2.fromOffset(88, 34), Size = UDim2.new(1, -100, 0, 18), TextColor3 = UI.Colors.Gold })
		local _, fill, label = UI.bar(card, { Position = UDim2.fromOffset(88, 56), Size = UDim2.new(1, -100, 0, 14), color = faction.color })
		if nextTier then
			UI.setBar(fill, (rep - tier.rep) / math.max(nextTier.rep - tier.rep, 1))
			if label then
				label.Text = ("%s / %s"):format(UI.formatNumber(rep), UI.formatNumber(nextTier.rep))
			end
			local reward = nextTier.reward or {}
			local titleName = reward.title and Progression.Titles[Factions.titleId(faction.id, reward.title)]
			text(card, { Text = ("Próximo: %s  •  %d de ouro + baú%s"):format(nextTier.name, reward.gold or 0, if titleName then (" + título \"%s\""):format(titleName.name) else ""), Position = UDim2.fromOffset(88, 74), Size = UDim2.new(1, -100, 0, 16), TextSize = 12, TextColor3 = UI.Colors.SubText })
		else
			UI.setBar(fill, 1)
			if label then
				label.Text = "Máximo!"
			end
		end
		text(card, { Text = faction.text, Position = UDim2.fromOffset(88, 92), Size = UDim2.new(1, -100, 0, 34), TextSize = 12, TextColor3 = UI.Colors.SubText })
	end
end

local function renderLore(page, chronicle)
	local unlocked = chronicle and chronicle.lore or {}
	local list = UI.new("ScrollingFrame", { Size = UDim2.new(0.38, -8, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = page }, { UI.list(4) })
	local reader = UI.new("Frame", { Position = UDim2.new(0.38, 8, 0, 0), Size = UDim2.new(0.62, -8, 1, 0), BackgroundColor3 = Color3.fromRGB(46, 40, 32), Parent = page }, { UI.corner(10), UI.padding(14) })
	local count = 0
	for i, entry in Lore.Pages do
		local open = unlocked[entry.id] == true
		if open then
			count += 1
		end
		local button = UI.button({ Text = if open then ("%d. %s"):format(i, entry.title) else ("%d. ???"):format(i), Size = UDim2.new(1, -8, 0, 32), LayoutOrder = i, BackgroundColor3 = if selectedPage == entry.id then Color3.fromRGB(120, 95, 40) elseif open then UI.Colors.PanelLight else UI.Colors.Dark, TextXAlignment = Enum.TextXAlignment.Left, Parent = list })
		button.MouseButton1Click:Connect(function()
			selectedPage = entry.id
			lastKey = nil
			ChroniclesWindow.render()
		end)
	end
	local current = selectedPage and Lore.ById[selectedPage]
	if not current then
		text(reader, { Text = ("Páginas encontradas: %d de %d.\n\nEscolha uma página à esquerda. As páginas aparecem quando você descobre segredos, derrota chefes e explora o mundo."):format(count, #Lore.Pages), Size = UDim2.fromScale(1, 1), TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = Color3.fromRGB(235, 220, 190), Font = Enum.Font.Gotham, TextSize = 16 })
		return
	end
	if unlocked[current.id] then
		text(reader, { Text = current.title, Size = UDim2.new(1, 0, 0, 30), TextSize = 22, FontFace = UI.TitleFont, TextColor3 = UI.Colors.Gold })
		text(reader, { Text = current.text, Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 1, -40), TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = Color3.fromRGB(235, 220, 190), Font = Enum.Font.Gotham, TextSize = 16 })
	else
		text(reader, { Text = "Página perdida", Size = UDim2.new(1, 0, 0, 30), TextSize = 22, FontFace = UI.TitleFont, TextColor3 = UI.Colors.SubText })
		text(reader, { Text = "Dica: " .. current.hint, Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 60), TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = UI.Colors.SubText, TextSize = 15 })
	end
end

function ChroniclesWindow.render()
	if not win or not win:isOpen() then
		return
	end
	local chronicle = State.data and State.data.chronicle
	local parts = { win.tab, tostring(selectedPage) }
	if chronicle then
		for id, rep in chronicle.factions or {} do
			table.insert(parts, id .. rep)
		end
		for id in chronicle.lore or {} do
			table.insert(parts, id)
		end
	end
	table.sort(parts)
	local key = table.concat(parts, ";")
	if key == lastKey then
		return
	end
	lastKey = key
	local page = pages[win.tab]
	UI.clear(page)
	if win.tab == "Facções" then
		renderFactions(page, chronicle)
	else
		renderLore(page, chronicle)
	end
end

function ChroniclesWindow.toggle()
	win:toggle()
end

function ChroniclesWindow.init(screen)
	win = Window.create(screen, { icon = "book-cover", name = "Cronicas", title = "CRÔNICAS", width = 780, height = 540, tabs = { "Facções", "Diário" }, accent = Color3.fromRGB(200, 170, 110) })
	for _, name in { "Facções", "Diário" } do
		pages[name] = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = win.content })
	end
	win.onTab = function(name)
		for tabName, page in pages do
			page.Visible = tabName == name
		end
		lastKey = nil
		ChroniclesWindow.render()
	end
	win.onOpen = function()
		win.onTab(win.tab)
	end
	State.Changed:Connect(ChroniclesWindow.render)
end

return ChroniclesWindow
