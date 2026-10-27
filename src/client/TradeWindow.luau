-- Troca entre jogadores (cliente): botão "Trocar" em cima dos outros jogadores, convite com Aceitar/Recusar
-- e a janela da troca (sua oferta à esquerda, a do outro à direita, Pronto → Confirmar). O servidor
-- (TradeService) valida tudo; aqui só se monta a oferta e se mostra o estado (data.trade).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Rarities = require(Shared.Rarities)

local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Window = require(script.Parent.Window)
local Sounds = require(script.Parent.Sounds)
local ItemIcon = require(script.Parent.ItemIcon)

local TradeWindow = {}

local player = Players.LocalPlayer
local win, mineFrame, theirsFrame, inventoryGrid, goldBox, readyButton, confirmButton, statusLabel, theirGold, theirStatus
local invitePanel, inviteText
local pendingInvite = nil
local lastKey = nil

local function offerItems(frame, items, onClick)
	UI.clear(frame)
	for i = 1, Config.TradeMaxItems do
		local item = items[i]
		local rarity = item and Rarities.ById[item.rarity]
		local cell = UI.new("TextButton", { Text = "", LayoutOrder = i, AutoButtonColor = onClick ~= nil, BackgroundColor3 = if rarity then rarity.color:Lerp(Color3.new(0, 0, 0), 0.6) else UI.Colors.PanelLight, BackgroundTransparency = if item then 0 else 0.4, Parent = frame }, { UI.corner(8), UI.stroke(if rarity then rarity.color else UI.Colors.Stroke, 1.5) })
		if item then
			ItemIcon.new(cell, item.base, item.rarity, { Size = UDim2.fromScale(0.85, 0.85), Position = UDim2.fromScale(0.5, 0.45), AnchorPoint = Vector2.new(0.5, 0.5), glow = false })
			UI.label({ Text = ("+%d • %d"):format(item.upgrade, item.power), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -1), Size = UDim2.new(1, -4, 0, 12), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = rarity.color, Parent = cell }, { UI.textStroke(1) })
			if onClick then
				cell.MouseButton1Click:Connect(function()
					onClick(item)
				end)
			end
		end
	end
end

local function sendOffer(uids)
	local gold = tonumber(goldBox.Text) or 0
	State.request("tradeOffer", { items = uids, gold = gold })
end

local function render(force)
	local trade = State.data and State.data.trade
	if not trade then
		if win:isOpen() then
			win:close()
		end
		return
	end
	-- só redesenha quando algo muda (tem ícones 3D)
	local keyParts = { tostring(trade.myReady), tostring(trade.theirReady), tostring(trade.myConfirm), tostring(trade.theirConfirm), table.concat(trade.mine.uids, ","), tostring(trade.mine.gold), tostring(trade.theirs.gold) }
	for _, item in trade.theirs.items do
		table.insert(keyParts, item.uid)
	end
	for _, item in State.data.inventory do
		table.insert(keyParts, item.uid .. tostring(item.equipped))
	end
	local key = table.concat(keyParts, "|")
	if key == lastKey and not force then
		return
	end
	lastKey = key
	win.title.Text = "TROCA COM " .. string.upper(trade.partner)
	local mineUids = table.clone(trade.mine.uids)
	offerItems(mineFrame, trade.mine.items, function(item)
		-- clicar num item da sua oferta tira ele
		local at = table.find(mineUids, item.uid)
		if at then
			table.remove(mineUids, at)
			sendOffer(mineUids)
		end
	end)
	offerItems(theirsFrame, trade.theirs.items, nil)
	if not goldBox:IsFocused() then
		goldBox.Text = tostring(trade.mine.gold)
	end
	theirGold.Text = ("%s ouro"):format(UI.formatNumber(trade.theirs.gold))
	theirStatus.Text = if trade.theirConfirm then "Confirmou" elseif trade.theirReady then "Pronto" else "… montando a oferta"
	theirStatus.TextColor3 = if trade.theirReady then UI.Colors.Green else UI.Colors.SubText
	-- seu inventário (clique para colocar na oferta)
	UI.clear(inventoryGrid)
	local index = 0
	for _, item in State.data.inventory do
		if not item.equipped and not table.find(mineUids, item.uid) then
			index += 1
			local rarity = Rarities.ById[item.rarity] or Rarities.List[1]
			local cell = UI.new("TextButton", { Text = "", LayoutOrder = -rarity.order * 1000 + index, BackgroundColor3 = rarity.color:Lerp(Color3.new(0, 0, 0), 0.65), Parent = inventoryGrid }, { UI.corner(8), UI.stroke(rarity.color, 1.2) })
			ItemIcon.new(cell, item.base, item.rarity, { Size = UDim2.fromScale(0.85, 0.85), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), glow = false })
			cell.MouseButton1Click:Connect(function()
				if #mineUids >= Config.TradeMaxItems then
					return
				end
				table.insert(mineUids, item.uid)
				Sounds.play("ping", 1.8, 0.15)
				sendOffer(mineUids)
			end)
		end
	end
	readyButton.Text = if trade.myReady then "Cancelar pronto" else "PRONTO"
	readyButton.BackgroundColor3 = if trade.myReady then Color3.fromRGB(150, 120, 60) else UI.Colors.Green
	local bothReady = trade.myReady and trade.theirReady
	confirmButton.Text = if trade.myConfirm then "Esperando o outro..." else "CONFIRMAR TROCA"
	confirmButton.BackgroundColor3 = if bothReady and not trade.myConfirm then Color3.fromRGB(230, 160, 40) else UI.Colors.Dark
	statusLabel.Text = if not bothReady then "1) Montem as ofertas  2) Os dois dão PRONTO  3) Os dois CONFIRMAM. Mudar a oferta tira o Pronto." else "Confira o que o outro está oferecendo e confirme."
end

-- botão "Trocar" em cima dos outros jogadores
local function addPrompt(other)
	local function onCharacter(character)
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if not root then
			return
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "TrocarPrompt"
		prompt.ActionText = "Trocar"
		prompt.ObjectText = other.DisplayName
		prompt.HoldDuration = 0.5
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = root
		prompt.Triggered:Connect(function()
			State.request("tradeInvite", other.UserId)
		end)
	end
	if other.Character then
		task.spawn(onCharacter, other.Character)
	end
	other.CharacterAdded:Connect(onCharacter)
end

-- convite recebido
function TradeWindow.invite(notification)
	pendingInvite = notification.fromId
	inviteText.Text = ("%s quer trocar com você"):format(notification.from or "Alguém")
	invitePanel.Visible = true
	Sounds.play("ping", 1.2, 0.6)
	local mine = pendingInvite
	task.delay(25, function()
		if pendingInvite == mine then
			pendingInvite = nil
			invitePanel.Visible = false
		end
	end)
end

function TradeWindow.open()
	lastKey = nil
	win:open()
	render(true)
end

function TradeWindow.init(screen)
	win = Window.create(screen, { icon = "shaking-hands", name = "Troca", title = "TROCA", width = 820, height = 580, accent = Color3.fromRGB(240, 200, 90) })
	local left = UI.new("Frame", { Size = UDim2.new(0.5, -6, 1, -54), BackgroundTransparency = 1, Parent = win.content })
	local right = UI.new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.5, -6, 1, -54), BackgroundTransparency = 1, Parent = win.content })
	UI.label({ Text = "VOCÊ OFERECE (clique para tirar)", Size = UDim2.new(1, 0, 0, 18), TextColor3 = UI.Colors.Gold, Parent = left })
	local function slotGrid(parent, y)
		return UI.new("Frame", { Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 156), BackgroundColor3 = UI.Colors.PanelLight, BackgroundTransparency = 0.3, Parent = parent }, {
			UI.corner(10),
			UI.padding(6),
			UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(70, 68), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
	end
	mineFrame = slotGrid(left, 22)
	UI.label({ Text = "Ouro:", Position = UDim2.fromOffset(0, 186), Size = UDim2.fromOffset(70, 26), TextColor3 = UI.Colors.Gold, Parent = left })
	goldBox = UI.new("TextBox", { Text = "0", PlaceholderText = "0", ClearTextOnFocus = false, Position = UDim2.fromOffset(72, 184), Size = UDim2.fromOffset(150, 30), BackgroundColor3 = UI.Colors.Dark, TextColor3 = UI.Colors.Text, Font = Enum.Font.GothamBold, TextSize = 16, Parent = left }, { UI.corner(6) })
	goldBox.FocusLost:Connect(function()
		local trade = State.data and State.data.trade
		if trade then
			goldBox.Text = tostring(math.max(0, math.floor(tonumber(goldBox.Text) or 0)))
			sendOffer(table.clone(trade.mine.uids))
		end
	end)
	UI.label({ Text = "SEU INVENTÁRIO (clique para oferecer)", Position = UDim2.fromOffset(0, 220), Size = UDim2.new(1, 0, 0, 18), TextColor3 = UI.Colors.SubText, Parent = left })
	inventoryGrid = UI.new("ScrollingFrame", { Position = UDim2.fromOffset(0, 240), Size = UDim2.new(1, 0, 1, -240), BackgroundColor3 = UI.Colors.PanelLight, BackgroundTransparency = 0.3, BorderSizePixel = 0, ScrollBarThickness = 5, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = left }, {
		UI.corner(10),
		UI.padding(6),
		UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(58, 58), CellPadding = UDim2.fromOffset(5, 5), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	UI.label({ Text = "O OUTRO OFERECE", Size = UDim2.new(1, 0, 0, 18), TextColor3 = UI.Colors.Gold, Parent = right })
	theirsFrame = slotGrid(right, 22)
	theirGold = UI.label({ Text = "0", Position = UDim2.fromOffset(0, 186), Size = UDim2.new(1, 0, 0, 26), TextColor3 = UI.Colors.Gold, Parent = right })
	theirStatus = UI.label({ Text = "", Position = UDim2.fromOffset(0, 220), Size = UDim2.new(1, 0, 0, 24), Font = Enum.Font.GothamBlack, Parent = right })
	statusLabel = UI.label({ Text = "", Position = UDim2.fromOffset(0, 252), Size = UDim2.new(1, 0, 0, 60), TextScaled = false, TextSize = 14, TextWrapped = true, TextColor3 = UI.Colors.SubText, TextYAlignment = Enum.TextYAlignment.Top, Parent = right })
	readyButton = UI.button({ Text = "PRONTO", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(0.32, 0, 0, 44), BackgroundColor3 = UI.Colors.Green, Parent = win.content })
	readyButton.MouseButton1Click:Connect(function()
		local trade = State.data and State.data.trade
		if trade then
			State.request("tradeReady", not trade.myReady)
		end
	end)
	confirmButton = UI.button({ Text = "CONFIRMAR TROCA", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.new(0.32, 0, 0, 44), BackgroundColor3 = UI.Colors.Dark, Parent = win.content })
	confirmButton.MouseButton1Click:Connect(function()
		State.request("tradeConfirm")
	end)
	local cancel = UI.button({ Text = "CANCELAR", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 1, 0), Size = UDim2.new(0.32, 0, 0, 44), BackgroundColor3 = Color3.fromRGB(150, 50, 50), Parent = win.content })
	cancel.MouseButton1Click:Connect(function()
		State.request("tradeCancel")
	end)
	win.onClose = function()
		if State.data and State.data.trade then
			State.request("tradeCancel")
		end
	end

	-- aviso de convite (canto da tela)
	invitePanel = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 150), Size = UDim2.fromOffset(380, 96), BackgroundColor3 = UI.Colors.Panel, Visible = false, Parent = screen }, { UI.corner(12) })
	UI.ornate(invitePanel, UI.Colors.Trim, 4)
	inviteText = UI.label({ Text = "", Position = UDim2.fromOffset(12, 10), Size = UDim2.new(1, -24, 0, 26), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = UI.Colors.Gold, Parent = invitePanel }, { UI.textStroke(1) })
	local accept = UI.button({ Text = "Aceitar", Position = UDim2.new(0, 14, 1, -46), Size = UDim2.new(0.5, -20, 0, 36), BackgroundColor3 = UI.Colors.Green, Parent = invitePanel })
	accept.MouseButton1Click:Connect(function()
		invitePanel.Visible = false
		if pendingInvite then
			State.request("tradeRespond", pendingInvite, true)
			pendingInvite = nil
		end
	end)
	local decline = UI.button({ Text = "Recusar", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 1, -46), Size = UDim2.new(0.5, -20, 0, 36), BackgroundColor3 = Color3.fromRGB(150, 50, 50), Parent = invitePanel })
	decline.MouseButton1Click:Connect(function()
		invitePanel.Visible = false
		if pendingInvite then
			State.request("tradeRespond", pendingInvite, false)
			pendingInvite = nil
		end
	end)

	for _, other in Players:GetPlayers() do
		if other ~= player then
			addPrompt(other)
		end
	end
	Players.PlayerAdded:Connect(addPrompt)

	State.Changed:Connect(function()
		local trade = State.data and State.data.trade
		if trade and not win:isOpen() then
			TradeWindow.open()
		elseif win:isOpen() then
			render(false)
		end
	end)
end

return TradeWindow
