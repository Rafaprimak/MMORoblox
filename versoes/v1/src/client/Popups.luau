-- Notificações na tela: loot, level up, rank up, missões, anúncios do servidor.
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Rarities = require(Shared.Rarities)

local UI = require(script.Parent.UI)
local Fx = require(script.Parent.Fx)
local Sounds = require(script.Parent.Sounds)

local Popups = {}

local screen, toastList, bannerList, messageLabel
local toastCounter, bannerCounter, messageToken = 0, 0, 0

function Popups.init(parent)
	screen = parent
	toastList = UI.new("Frame", {
		Name = "Loot",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -110),
		Size = UDim2.fromOffset(300, 420),
		BackgroundTransparency = 1,
		Parent = parent,
	}, {
		UI.new("UIListLayout", {
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	bannerList = UI.new("Frame", {
		Name = "Banners",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 16),
		Size = UDim2.fromOffset(540, 300),
		BackgroundTransparency = 1,
		Parent = parent,
	}, {
		UI.new("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	messageLabel = UI.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -140),
		Size = UDim2.fromOffset(560, 30),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Color3.fromRGB(255, 120, 120),
		TextTransparency = 1,
		Parent = parent,
	})
	local stroke = UI.textStroke(2)
	stroke.Transparency = 1
	stroke.Parent = messageLabel
end

-- Texto curto no centro-baixo da tela (erros, avisos)
function Popups.message(text)
	messageToken += 1
	local token = messageToken
	local stroke = messageLabel:FindFirstChildOfClass("UIStroke")
	messageLabel.Text = text
	messageLabel.TextTransparency = 0
	if stroke then
		stroke.Transparency = 0.2
	end
	task.delay(2.5, function()
		if token ~= messageToken then
			return
		end
		UI.tween(messageLabel, 0.4, { TextTransparency = 1 })
		if stroke then
			UI.tween(stroke, 0.4, { Transparency = 1 })
		end
	end)
end

-- Texto GRANDE no meio da tela que "explode"
function Popups.burst(text, color, subText)
	local frame = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.36),
		Size = UDim2.fromOffset(620, 110),
		BackgroundTransparency = 1,
		Parent = screen,
	})
	local scale = UI.new("UIScale", { Scale = 0.3, Parent = frame })
	local title = UI.label({
		Text = text,
		TextColor3 = color,
		Font = Enum.Font.GothamBlack,
		Size = UDim2.fromScale(1, 0.65),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = frame,
	}, { UI.textStroke(3) })
	if typeof(color) == "Color3" and color == Color3.new(1, 1, 1) then
		Fx.registerRainbow(title, "TextColor3")
	end
	if subText then
		UI.label({
			Text = subText,
			Size = UDim2.fromScale(1, 0.3),
			Position = UDim2.fromScale(0, 0.68),
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = frame,
		}, { UI.textStroke(2) })
	end
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(1.6, function()
		UI.tween(scale, 0.4, { Scale = 1.15 })
		UI.fadeOut(frame, 0.4)
		task.wait(0.45)
		Fx.unregisterRainbow(title)
		frame:Destroy()
	end)
end

-- Faixa no topo da tela
function Popups.banner(title, subText, color, duration)
	bannerCounter += 1
	local frame = UI.new("Frame", {
		Size = UDim2.fromOffset(540, if subText then 64 else 44),
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.15,
		LayoutOrder = bannerCounter,
		Parent = bannerList,
	}, { UI.corner(10), UI.stroke(color, 2) })
	local scale = UI.new("UIScale", { Scale = 0.6, Parent = frame })
	UI.label({
		Text = title,
		TextColor3 = color,
		Font = Enum.Font.GothamBlack,
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -24, 0, 28),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = frame,
	}, { UI.textStroke(1.5) })
	if subText then
		UI.label({
			Text = subText,
			TextColor3 = UI.Colors.Text,
			Font = Enum.Font.GothamBold,
			Position = UDim2.fromOffset(12, 36),
			Size = UDim2.new(1, -24, 0, 20),
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = frame,
		})
	end
	UI.tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(duration or 3.5, function()
		UI.fadeOut(frame, 0.4)
		task.wait(0.45)
		frame:Destroy()
	end)
end

-- Cartão de item que desliza da direita
function Popups.loot(item)
	local rarity = Rarities.ById[item.rarity] or Rarities.List[1]
	toastCounter += 1
	local holder = UI.new("Frame", {
		Size = UDim2.fromOffset(300, 58),
		BackgroundTransparency = 1,
		LayoutOrder = toastCounter,
		Parent = toastList,
	})
	local cardStroke = UI.stroke(rarity.color, 2)
	local card = UI.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(340, 0),
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.1,
		Parent = holder,
	}, { UI.corner(10), cardStroke })
	UI.new("Frame", { Size = UDim2.new(0, 6, 1, -12), Position = UDim2.fromOffset(6, 6), BackgroundColor3 = rarity.color, Parent = card }, { UI.corner(3) })
	UI.label({ Text = UI.itemIcon(item), Size = UDim2.fromOffset(40, 40), Position = UDim2.fromOffset(18, 9), TextXAlignment = Enum.TextXAlignment.Center, Parent = card })
	local name = UI.label({
		Text = item.name,
		TextColor3 = rarity.color,
		Size = UDim2.new(1, -72, 0, 24),
		Position = UDim2.fromOffset(64, 6),
		Parent = card,
	}, { UI.textStroke(1) })
	UI.label({
		Text = ("%s  •  %s %d"):format(rarity.name, UI.statIcon(item), item.power),
		TextColor3 = UI.Colors.SubText,
		Font = Enum.Font.Gotham,
		Size = UDim2.new(1, -72, 0, 18),
		Position = UDim2.fromOffset(64, 32),
		Parent = card,
	})
	if rarity.rainbow then
		Fx.registerRainbow(name, "TextColor3")
		Fx.registerRainbow(cardStroke, "Color")
	end

	UI.tween(card, 0.35, { Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Back)
	Sounds.play("ping", 0.75 + rarity.order * 0.12, 0.35 + rarity.order * 0.05)
	if rarity.order >= 4 then
		Popups.burst(rarity.upper .. "!", rarity.color, item.name)
	end
	if rarity.order >= 5 then
		Fx.shake(0.35, 0.6)
	end

	task.delay(4 + rarity.order * 0.5, function()
		if not holder.Parent then
			return
		end
		UI.tween(card, 0.3, { Position = UDim2.fromOffset(340, 0) }).Completed:Wait()
		holder:Destroy()
	end)

	-- no máximo 6 cartões ao mesmo tempo
	local cards = {}
	for _, child in toastList:GetChildren() do
		if child:IsA("Frame") then
			table.insert(cards, child)
		end
	end
	if #cards > 6 then
		table.sort(cards, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		cards[1]:Destroy()
	end
end

function Popups.handle(notification)
	local kind = notification.kind
	if kind == "loot" then
		Popups.loot(notification.item)
	elseif kind == "levelup" then
		Popups.burst("NÍVEL " .. notification.level .. "!", UI.Colors.Gold, "Vida e dano aumentaram")
		Sounds.play("ping", 1.5, 0.6)
		task.delay(0.12, Sounds.play, "ping", 2, 0.6)
		Fx.levelUp()
	elseif kind == "rankup" then
		local rank = Config.getRankByName(notification.rank)
		Popups.banner("⭐ RANK " .. notification.rank .. " ALCANÇADO! ⭐", "Novas áreas e inimigos esperam por você", rank.color, 5)
		Fx.shake(0.4, 0.5)
	elseif kind == "quest" then
		local label = if notification.category == "daily" then "DIÁRIA" elseif notification.category == "bonus" then "BÔNUS" else "MISSÃO"
		Popups.banner("✅ " .. label .. " COMPLETA", notification.title .. "   " .. notification.reward, UI.Colors.Green, 4)
		Sounds.play("ping", 1.3, 0.5)
	elseif kind == "announce" then
		local color = notification.color or UI.Colors.Gold
		if notification.rarity and Rarities.ById[notification.rarity] then
			color = Rarities.ById[notification.rarity].color
		end
		Popups.banner(notification.text, notification.sub, color, 5)
	elseif kind == "banner" then
		Popups.banner(notification.text, notification.sub, notification.color or UI.Colors.Accent, notification.duration or 4)
	elseif kind == "message" then
		Popups.message(notification.text)
	end
end

return Popups
