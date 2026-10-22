-- Janela de Pets (tecla G ou no Otto): seus pets (equipar, soltar) e ovos (chances visíveis antes da compra).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Pets = require(Shared.Pets)
local Rarities = require(Shared.Rarities)
local Items = require(Shared.Items)

local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Window = require(script.Parent.Window)
local Sounds = require(script.Parent.Sounds)
local Popups = require(script.Parent.Popups)

local PetsWindow = {}

local win, body
local confirmRelease = nil

local function statText(stats)
	local parts = {}
	for key, value in stats do
		local shown = if key == "regen" then ("%.1f%%/s"):format(value * 100) else ("%d%%"):format(math.floor(value * 100 + 0.5))
		table.insert(parts, ("+%s %s"):format(shown, Items.StatNames[key] or key))
	end
	table.sort(parts)
	return table.concat(parts, "  •  ")
end

local function renderOwned(data)
	local list = data.pets or {}
	table.sort(list, function(a, b)
		if a.equipped ~= b.equipped then
			return a.equipped
		end
		local ra = Rarities.ById[Pets.List[a.id].rarity].order
		local rb = Rarities.ById[Pets.List[b.id].rarity].order
		if ra ~= rb then
			return ra > rb
		end
		return a.level > b.level
	end)
	UI.label({ Text = ("🐾 %d/%d pets  •  O pet equipado segue você, ganha XP com os abates e dá bônus."):format(#list, Pets.MaxOwned), Size = UDim2.new(1, -10, 0, 20), TextColor3 = UI.Colors.SubText, LayoutOrder = 0, Parent = body })
	if #list == 0 then
		UI.label({ Text = "Você ainda não tem pets. Compre um ovo na aba Ovos (no Otto, na vila).", Size = UDim2.new(1, -10, 0, 40), TextColor3 = UI.Colors.Gold, LayoutOrder = 1, Parent = body })
		return
	end
	for index, entry in list do
		local def = Pets.List[entry.id]
		local rarity = Rarities.ById[def.rarity]
		local row = UI.new("Frame", { Size = UDim2.new(1, -10, 0, 70), BackgroundColor3 = rarity.color:Lerp(Color3.new(0, 0, 0), 0.7), LayoutOrder = index, Parent = body }, { UI.corner(10), UI.stroke(if entry.equipped then UI.Colors.Gold else rarity.color, if entry.equipped then 2.5 else 1.2) })
		UI.label({ Text = def.icon, Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(54, 54), TextXAlignment = Enum.TextXAlignment.Center, Parent = row })
		UI.label({ Text = ("%s  •  Nv. %d"):format(def.name, entry.level), Position = UDim2.fromOffset(70, 6), Size = UDim2.new(1, -320, 0, 20), Font = Enum.Font.GothamBlack, TextColor3 = rarity.color, Parent = row }, { UI.textStroke(1) })
		UI.label({ Text = statText(Pets.stats(entry.id, entry.level)), Position = UDim2.fromOffset(70, 28), Size = UDim2.new(1, -320, 0, 16), TextColor3 = Color3.fromRGB(180, 255, 200), Parent = row })
		local _, fill, label = UI.bar(row, { Position = UDim2.new(0, 70, 0, 48), Size = UDim2.new(1, -330, 0, 12), color = UI.Colors.Xp })
		UI.setBar(fill, if entry.level >= Pets.MaxLevel then 1 else entry.xp / math.max(entry.xpNext, 1))
		label.Text = if entry.level >= Pets.MaxLevel then "MÁX" else ("%d / %d"):format(entry.xp, entry.xpNext)
		local equip = UI.button({ Text = if entry.equipped then "GUARDAR" else "EQUIPAR", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -130, 0.5, 0), Size = UDim2.fromOffset(110, 34), BackgroundColor3 = if entry.equipped then UI.Colors.Dark else UI.Colors.Green, Parent = row })
		equip.MouseButton1Click:Connect(function()
			local result = State.request("equipPet", if entry.equipped then "" else entry.uid)
			if result and result.ok then
				Sounds.play("equip", 1.3, 0.5)
			end
		end)
		local release = UI.button({ Text = "SOLTAR", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(110, 34), BackgroundColor3 = Color3.fromRGB(130, 60, 60), Parent = row })
		release.MouseButton1Click:Connect(function()
			if confirmRelease ~= entry.uid then
				confirmRelease = entry.uid
				release.Text = "CONFIRMAR?"
				return
			end
			confirmRelease = nil
			local result = State.request("releasePet", entry.uid)
			if result and result.ok then
				Popups.message(("Pet solto. +%d de ouro"):format(result.gold), UI.Colors.Gold)
			end
		end)
	end
end

local function renderEggs(data)
	UI.label({ Text = "Ovos são vendidos pelo Otto (na vila) e pagos só com ouro do jogo. As chances de cada pet aparecem abaixo.", Size = UDim2.new(1, -10, 0, 34), TextWrapped = true, TextColor3 = UI.Colors.SubText, LayoutOrder = 0, Parent = body })
	local row = UI.new("Frame", { Size = UDim2.new(1, -10, 0, 380), BackgroundTransparency = 1, LayoutOrder = 1, Parent = body }, { UI.list(10, true) })
	for index, eggId in Pets.EggOrder do
		local egg = Pets.Eggs[eggId]
		local card = UI.new("Frame", { Size = UDim2.new(1 / 3, -7, 1, 0), BackgroundColor3 = UI.Colors.PanelLight, BackgroundTransparency = 0.15, LayoutOrder = index, Parent = row }, { UI.corner(12), UI.stroke(egg.color, 2) })
		UI.label({ Text = egg.icon, Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 50), TextXAlignment = Enum.TextXAlignment.Center, Parent = card })
		UI.label({ Text = egg.name, Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 0, 22), TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamBlack, TextColor3 = egg.color, Parent = card }, { UI.textStroke(1) })
		-- chances, da mais rara para a mais comum
		local entries = {}
		for petId, chance in egg.odds do
			table.insert(entries, { id = petId, chance = chance })
		end
		table.sort(entries, function(a, b)
			return a.chance > b.chance
		end)
		for i, entry in entries do
			local def = Pets.List[entry.id]
			local rarity = Rarities.ById[def.rarity]
			UI.label({ Text = ("%s %s"):format(def.icon, def.name), Position = UDim2.fromOffset(10, 82 + (i - 1) * 22), Size = UDim2.new(1, -70, 0, 20), TextColor3 = rarity.color, Parent = card })
			UI.label({ Text = ("%g%%"):format(entry.chance), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 82 + (i - 1) * 22), Size = UDim2.fromOffset(56, 20), TextXAlignment = Enum.TextXAlignment.Right, Parent = card })
		end
		local canBuy = data.gold >= egg.price
		local buy = UI.button({ Text = ("CHOCAR  💰%s"):format(UI.formatNumber(egg.price)), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.new(1, -20, 0, 40), BackgroundColor3 = if canBuy then egg.color:Lerp(Color3.new(0, 0, 0), 0.25) else UI.Colors.Dark, Parent = card })
		buy.MouseButton1Click:Connect(function()
			local result = State.request("buyEgg", eggId)
			if result and result.ok then
				win:setTab("Meus Pets")
			end
		end)
	end
end

local function render()
	local data = State.data
	if not data then
		return
	end
	UI.clear(body)
	if win.tab == "Ovos" then
		renderEggs(data)
	else
		renderOwned(data)
	end
end

function PetsWindow.init(screen)
	win = Window.create(screen, { name = "Pets", title = "🐾 PETS", width = 760, height = 540, tabs = { "Meus Pets", "Ovos" }, accent = Color3.fromRGB(150, 255, 200) })
	body = UI.new("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = win.content }, { UI.list(7) })
	win.onTab = render
	win.onOpen = render
	State.Changed:Connect(function()
		if win:isOpen() then
			render()
		end
	end)
end

function PetsWindow.toggle()
	win:toggle()
end

function PetsWindow.openEggs()
	win:open()
	win:setTab("Ovos")
end

-- aviso de pet novo (ovo chocado ou drop)
function PetsWindow.announce(notification)
	local def = Pets.List[notification.pet]
	if not def then
		return
	end
	local rarity = Rarities.ById[def.rarity]
	Popups.burst(("%s %s!"):format(def.icon, string.upper(def.name)), rarity.color, if notification.source == "drop" then "Um ovo caiu do inimigo e chocou!" else "Saiu do ovo! Ele já está seguindo você (tecla G).")
	Sounds.play("ping", 0.8 + rarity.order * 0.15, 0.8)
end

return PetsWindow
