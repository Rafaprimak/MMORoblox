-- Janela de inventário: ver, equipar, aprimorar (forja) e vender itens.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rarities = require(Shared.Rarities)
local Remotes = require(Shared.Remotes)

local UI = require(script.Parent.UI)
local Fx = require(script.Parent.Fx)
local Sounds = require(script.Parent.Sounds)
local Popups = require(script.Parent.Popups)

local Inventory = {}
Inventory.onOpen = nil

local WIDTH, HEIGHT = 680, 440
local window, windowScale, grid, details, titleLabel, statsLabel, junkButton
local state = nil
local selectedUid = nil
local junkConfirm = false

local function request(action, arg)
	local ok, result = pcall(function()
		return Remotes.Request:InvokeServer(action, arg)
	end)
	if not ok or type(result) ~= "table" then
		Popups.message("Erro de conexão, tente de novo.")
		return nil
	end
	if not result.ok and result.msg then
		Popups.message(result.msg)
	end
	return result
end

local function findItem(uid)
	if not state then
		return nil
	end
	for _, item in state.inventory do
		if item.uid == uid then
			return item
		end
	end
	return nil
end

local function equippedIn(slot)
	for _, item in state.inventory do
		if item.equipped and item.slot == slot then
			return item
		end
	end
	return nil
end

local function clear(container)
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function specialText(item)
	if item.cleave then
		return ("Golpe em área: até %d alvos"):format(item.cleave)
	elseif item.crit then
		return ("+%d%% de chance de crítico"):format(math.floor(item.crit * 100))
	elseif item.range then
		return ("+%d de alcance"):format(item.range)
	elseif item.slot == "armor" then
		return "Aumenta sua vida máxima"
	end
	return "Arma equilibrada"
end

local renderDetails

local function renderGrid()
	clear(grid)
	if not state then
		return
	end
	local items = table.clone(state.inventory)
	table.sort(items, function(a, b)
		if a.equipped ~= b.equipped then
			return a.equipped
		end
		if a.power ~= b.power then
			return a.power > b.power
		end
		return a.uid < b.uid
	end)

	for index, item in items do
		local rarity = Rarities.ById[item.rarity] or Rarities.List[1]
		local selected = item.uid == selectedUid
		local stroke = UI.stroke(if selected then Color3.new(1, 1, 1) else rarity.color, if selected then 3 else 1.5)
		local cell = UI.new("TextButton", {
			Text = "",
			LayoutOrder = index,
			AutoButtonColor = true,
			BackgroundColor3 = rarity.color:Lerp(Color3.new(0, 0, 0), 0.65),
			Parent = grid,
		}, { UI.corner(8), stroke })
		if rarity.rainbow and not selected then
			Fx.registerRainbow(stroke, "Color")
		end
		UI.label({ Text = UI.itemIcon(item), Size = UDim2.fromScale(1, 0.45), Position = UDim2.fromScale(0, 0.1), TextXAlignment = Enum.TextXAlignment.Center, Parent = cell })
		UI.label({
			Text = item.name,
			Size = UDim2.new(1, -6, 0.18, 0),
			Position = UDim2.new(0, 3, 0.58, 0),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = rarity.color,
			Parent = cell,
		}, { UI.textStroke(1) })
		UI.label({
			Text = UI.statIcon(item) .. " " .. item.power,
			Size = UDim2.new(1, -6, 0.16, 0),
			Position = UDim2.new(0, 3, 0.79, 0),
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = cell,
		}, { UI.textStroke(1) })
		if item.upgrade > 0 then
			UI.label({ Text = "+" .. item.upgrade, Size = UDim2.fromOffset(30, 16), Position = UDim2.fromOffset(5, 4), TextColor3 = UI.Colors.Gold, Parent = cell }, { UI.textStroke(1) })
		end
		if item.equipped then
			UI.label({
				Text = "E",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -4, 0, 4),
				Size = UDim2.fromOffset(18, 18),
				BackgroundTransparency = 0,
				BackgroundColor3 = UI.Colors.Green,
				TextXAlignment = Enum.TextXAlignment.Center,
				Font = Enum.Font.GothamBlack,
				Parent = cell,
			}, { UI.corner(9) })
		end
		cell.MouseButton1Click:Connect(function()
			selectedUid = item.uid
			Sounds.play("ping", 2.2, 0.12)
			renderGrid()
			renderDetails()
		end)
	end
end

function renderDetails()
	clear(details)
	local item = selectedUid and findItem(selectedUid)
	if not item then
		UI.label({
			Text = "Clique em um item para ver detalhes",
			Size = UDim2.new(1, 0, 0, 40),
			Position = UDim2.fromOffset(0, 130),
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = UI.Colors.SubText,
			Parent = details,
		})
		return
	end

	local rarity = Rarities.ById[item.rarity] or Rarities.List[1]
	local name = UI.label({ Text = item.name, TextColor3 = rarity.color, Font = Enum.Font.GothamBlack, TextWrapped = true, Size = UDim2.new(1, 0, 0, 44), Parent = details }, { UI.textStroke(1) })
	if rarity.rainbow then
		Fx.registerRainbow(name, "TextColor3")
	end
	UI.label({
		Text = ("%s • %s • Nv. %d"):format(rarity.name, if item.slot == "armor" then "Armadura" else "Arma", item.level),
		Position = UDim2.fromOffset(0, 46),
		Size = UDim2.new(1, 0, 0, 18),
		TextColor3 = UI.Colors.SubText,
		Parent = details,
	})
	UI.label({ Text = UI.statIcon(item) .. " " .. UI.formatNumber(item.power), Position = UDim2.fromOffset(0, 68), Size = UDim2.new(1, 0, 0, 40), Font = Enum.Font.GothamBlack, Parent = details }, { UI.textStroke(1.5) })

	if not item.equipped then
		local current = equippedIn(item.slot)
		local diff = item.power - (if current then current.power else 0)
		UI.label({
			Text = (if diff >= 0 then "▲ +" else "▼ ") .. diff .. " comparado ao equipado",
			Position = UDim2.fromOffset(0, 110),
			Size = UDim2.new(1, 0, 0, 18),
			TextColor3 = if diff >= 0 then UI.Colors.Green else UI.Colors.Red,
			Parent = details,
		})
	else
		UI.label({ Text = "✔ Equipado", Position = UDim2.fromOffset(0, 110), Size = UDim2.new(1, 0, 0, 18), TextColor3 = UI.Colors.Green, Parent = details })
	end
	UI.label({ Text = specialText(item), Position = UDim2.fromOffset(0, 132), Size = UDim2.new(1, 0, 0, 16), TextColor3 = UI.Colors.Xp, Font = Enum.Font.Gotham, Parent = details })
	UI.label({ Text = ("Aprimoramento: +%d / %d"):format(item.upgrade, item.maxUpgrade), Position = UDim2.fromOffset(0, 152), Size = UDim2.new(1, 0, 0, 16), TextColor3 = UI.Colors.Gold, Font = Enum.Font.Gotham, Parent = details })

	-- Equipar
	local equipButton = UI.button({
		Text = if item.equipped then "EQUIPADO" else "EQUIPAR",
		Position = UDim2.fromOffset(0, 184),
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundColor3 = if item.equipped then Color3.fromRGB(60, 60, 70) else UI.Colors.Green,
		AutoButtonColor = not item.equipped,
		Parent = details,
	})
	equipButton.MouseButton1Click:Connect(function()
		if item.equipped then
			return
		end
		local result = request("equip", item.uid)
		if result and result.ok then
			Sounds.play("equip", 1, 0.6)
		end
	end)

	-- Aprimorar
	local maxed = item.upgrade >= item.maxUpgrade
	local affordable = state.gold >= item.upgradeCost
	local upgradeButton = UI.button({
		Text = if maxed then "MÁXIMO" else ("⬆ APRIMORAR  💰%s"):format(UI.formatNumber(item.upgradeCost)),
		Position = UDim2.fromOffset(0, 228),
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundColor3 = if maxed then Color3.fromRGB(60, 60, 70) elseif affordable then Color3.fromRGB(220, 150, 30) else Color3.fromRGB(110, 85, 45),
		AutoButtonColor = not maxed,
		Parent = details,
	})
	upgradeButton.MouseButton1Click:Connect(function()
		if maxed then
			return
		end
		local result = request("upgrade", item.uid)
		if result and result.ok then
			Sounds.play("ping", 1.2 + result.upgrade * 0.08, 0.6)
			Popups.burst(("APRIMORADO +%d!"):format(result.upgrade), UI.Colors.Gold)
			Fx.shake(0.15, 0.3)
		end
	end)

	-- Vender
	local sellButton = UI.button({
		Text = if item.equipped then "—" else ("VENDER  💰%s"):format(UI.formatNumber(item.sell)),
		Position = UDim2.fromOffset(0, 272),
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = if item.equipped then Color3.fromRGB(60, 60, 70) else Color3.fromRGB(150, 60, 60),
		AutoButtonColor = not item.equipped,
		Parent = details,
	})
	sellButton.MouseButton1Click:Connect(function()
		if item.equipped then
			return
		end
		local result = request("sell", item.uid)
		if result and result.ok then
			Sounds.play("ping", 0.8, 0.4)
			Popups.message(("Vendido por %d de ouro"):format(result.gold))
		end
	end)
end

local function render()
	if not state then
		return
	end
	titleLabel.Text = ("🎒 INVENTÁRIO  (%d/%d)"):format(#state.inventory, state.maxInventory)
	statsLabel.Text = ("⚔ Ataque %s    ❤ Vida %s"):format(UI.formatNumber(state.attack), UI.formatNumber(state.maxHealth))
	renderGrid()
	renderDetails()
end

local function fitScale()
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	return math.min(1, (viewport.X - 24) / WIDTH, (viewport.Y - 60) / HEIGHT)
end

function Inventory.init(screen)
	window = UI.new("Frame", {
		Name = "Inventario",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.05,
		Visible = false,
		ZIndex = 5,
		Parent = screen,
	}, { UI.corner(14), UI.stroke(UI.Colors.Stroke, 2) })
	windowScale = UI.new("UIScale", { Parent = window })

	titleLabel = UI.label({ Text = "🎒 INVENTÁRIO", Position = UDim2.fromOffset(16, 10), Size = UDim2.fromOffset(300, 30), Font = Enum.Font.GothamBlack, Parent = window }, { UI.textStroke(1) })
	statsLabel = UI.label({
		Text = "",
		Position = UDim2.fromOffset(320, 15),
		Size = UDim2.fromOffset(290, 20),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = UI.Colors.SubText,
		Parent = window,
	})
	local closeButton = UI.button({ Text = "X", Position = UDim2.new(1, -46, 0, 8), Size = UDim2.fromOffset(36, 34), BackgroundColor3 = UI.Colors.Red, Parent = window })
	closeButton.MouseButton1Click:Connect(function()
		Inventory.close()
	end)

	grid = UI.new("ScrollingFrame", {
		Position = UDim2.fromOffset(14, 52),
		Size = UDim2.fromOffset(410, 330),
		BackgroundColor3 = UI.Colors.PanelLight,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = window,
	}, {
		UI.corner(10),
		UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(88, 88), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		UI.new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }),
	})

	details = UI.new("Frame", {
		Position = UDim2.fromOffset(436, 52),
		Size = UDim2.fromOffset(230, 330),
		BackgroundColor3 = UI.Colors.PanelLight,
		BackgroundTransparency = 0.3,
		Parent = window,
	}, {
		UI.corner(10),
		UI.new("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10) }),
	})

	junkButton = UI.button({
		Text = "🗑 Vender Comuns e Incomuns",
		Position = UDim2.fromOffset(14, 392),
		Size = UDim2.fromOffset(260, 36),
		BackgroundColor3 = Color3.fromRGB(110, 60, 60),
		Parent = window,
	})
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
		local result = request("sellJunk")
		if result and result.ok then
			Sounds.play("ping", 0.8, 0.4)
			Popups.message(("%d itens vendidos por %d de ouro"):format(result.count, result.gold))
		end
	end)
	UI.label({
		Text = "Dica: segure o clique para atacar sem parar",
		Position = UDim2.fromOffset(290, 400),
		Size = UDim2.fromOffset(376, 20),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = UI.Colors.SubText,
		Font = Enum.Font.Gotham,
		Parent = window,
	})
end

function Inventory.update(data)
	state = data
	if window.Visible then
		render()
	end
end

function Inventory.open()
	if Inventory.onOpen then
		Inventory.onOpen()
	end
	window.Visible = true
	local target = fitScale()
	windowScale.Scale = target * 0.85
	UI.tween(windowScale, 0.2, { Scale = target }, Enum.EasingStyle.Back)
	render()
end

function Inventory.close()
	window.Visible = false
end

function Inventory.toggle()
	if window.Visible then
		Inventory.close()
	else
		Inventory.open()
	end
end

return Inventory
