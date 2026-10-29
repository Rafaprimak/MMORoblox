-- Notificações: loot, materiais, level up, rank, perícias, missões, descobertas e anúncios.
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Rarities = require(Shared.Rarities)
local Items = require(Shared.Items)
local Skills = require(Shared.Skills)
local Classes = require(Shared.Classes)

local UI = require(script.Parent.UI)
local Fx = require(script.Parent.Fx)
local ItemIcon = require(script.Parent.ItemIcon)
local Sounds = require(script.Parent.Sounds)

local Popups = {}

local screen, toastList, bannerList, messageLabel, pickupList
local toastCounter, bannerCounter, messageToken = 0, 0, 0
local pickupRows = {}

function Popups.init(parent)
	screen = parent
	toastList = UI.new("Frame", {
		Name = "Loot",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -150),
		Size = UDim2.fromOffset(300, 420),
		BackgroundTransparency = 1,
		Parent = parent,
	}, {
		UI.new("UIListLayout", { VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	pickupList = UI.new("Frame", {
		Name = "Coletas",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -150),
		Size = UDim2.fromOffset(260, 300),
		BackgroundTransparency = 1,
		Parent = parent,
	}, {
		UI.new("UIListLayout", { VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	bannerList = UI.new("Frame", {
		Name = "Banners",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 70),
		Size = UDim2.fromOffset(560, 300),
		BackgroundTransparency = 1,
		Parent = parent,
	}, {
		UI.new("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	messageLabel = UI.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -170),
		Size = UDim2.fromOffset(600, 28),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Color3.fromRGB(255, 130, 130),
		TextTransparency = 1,
		ZIndex = 50,
		Parent = parent,
	})
	local stroke = UI.textStroke(2)
	stroke.Transparency = 1
	stroke.Parent = messageLabel
end

function Popups.message(text, color)
	messageToken += 1
	local token = messageToken
	local stroke = messageLabel:FindFirstChildOfClass("UIStroke")
	messageLabel.Text = text
	messageLabel.TextColor3 = color or Color3.fromRGB(255, 130, 130)
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

function Popups.burst(text, color, subText)
	local frame = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.34), Size = UDim2.fromOffset(640, 110), BackgroundTransparency = 1, ZIndex = 40, Parent = screen })
	local scale = UI.new("UIScale", { Scale = 0.3, Parent = frame })
	local title = UI.label({ Text = text, TextColor3 = color, FontFace = UI.TitleFont, Size = UDim2.fromScale(1, 0.65), TextXAlignment = Enum.TextXAlignment.Center, Parent = frame }, { UI.textStroke(3) })
	if color == Color3.new(1, 1, 1) then
		Fx.registerRainbow(title, "TextColor3")
	end
	if subText then
		UI.label({ Text = subText, Size = UDim2.fromScale(1, 0.3), Position = UDim2.fromScale(0, 0.68), TextXAlignment = Enum.TextXAlignment.Center, Parent = frame }, { UI.textStroke(2) })
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

function Popups.banner(title, subText, color, duration)
	bannerCounter += 1
	local frame = UI.new("Frame", {
		Size = UDim2.fromOffset(560, if subText then 64 else 44),
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.15,
		LayoutOrder = bannerCounter,
		Parent = bannerList,
	}, { UI.corner(10), UI.stroke(color, 2), UI.new("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 175)), Rotation = 90 }) })
	UI.ornate(frame, color, 4)
	local scale = UI.new("UIScale", { Scale = 0.6, Parent = frame })
	UI.label({ Text = title, TextColor3 = color, FontFace = UI.TitleFont, Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 28), TextXAlignment = Enum.TextXAlignment.Center, Parent = frame }, { UI.textStroke(1.5) })
	if subText then
		UI.label({ Text = subText, Position = UDim2.fromOffset(12, 36), Size = UDim2.new(1, -24, 0, 20), TextXAlignment = Enum.TextXAlignment.Center, Parent = frame })
	end
	UI.tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(duration or 3.5, function()
		UI.fadeOut(frame, 0.4)
		task.wait(0.45)
		frame:Destroy()
	end)
	local banners = {}
	for _, child in bannerList:GetChildren() do
		if child:IsA("Frame") then
			table.insert(banners, child)
		end
	end
	if #banners > 4 then
		table.sort(banners, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		banners[1]:Destroy()
	end
end

-- Cartão de equipamento que desliza da direita
function Popups.loot(item)
	local rarity = Rarities.ById[item.rarity] or Rarities.List[1]
	toastCounter += 1
	local holder = UI.new("Frame", { Size = UDim2.fromOffset(300, 58), BackgroundTransparency = 1, LayoutOrder = toastCounter, Parent = toastList })
	local cardStroke = UI.stroke(rarity.color, 2)
	local card = UI.new("Frame", { Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(340, 0), BackgroundColor3 = UI.Colors.Panel, BackgroundTransparency = 0.1, Parent = holder }, { UI.corner(10), cardStroke })
	UI.new("Frame", { Size = UDim2.new(0, 6, 1, -12), Position = UDim2.fromOffset(6, 6), BackgroundColor3 = rarity.color, Parent = card }, { UI.corner(3) })
	ItemIcon.new(card, item.base, item.rarity, { Size = UDim2.fromOffset(48, 48), Position = UDim2.fromOffset(14, 5) })
	local name = UI.label({ Text = item.name, TextColor3 = rarity.color, Size = UDim2.new(1, -72, 0, 24), Position = UDim2.fromOffset(64, 6), Parent = card }, { UI.textStroke(1) })
	UI.label({ Text = ("%s  •  %s %d"):format(rarity.name, UI.statWord(item), item.power), TextColor3 = UI.Colors.SubText, Font = Enum.Font.Gotham, Size = UDim2.new(1, -72, 0, 18), Position = UDim2.fromOffset(64, 32), Parent = card })
	if rarity.rainbow then
		Fx.registerRainbow(name, "TextColor3")
		Fx.registerRainbow(cardStroke, "Color")
	end
	UI.tween(card, 0.35, { Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Back)
	Sounds.play(if rarity.order >= 4 then "lootRare" else "loot", 0.75 + rarity.order * 0.12, 0.35 + rarity.order * 0.05)
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

-- Coletas de material/poção: linhas pequenas que somam se repetirem
function Popups.pickup(id, count)
	local def = Items.Materials[id] or Items.Consumables[id]
	if not def then
		return
	end
	local row = pickupRows[id]
	if row and row.frame.Parent then
		row.count += count
		row.label.Text = ("+%d  %s"):format(row.count, def.name)
		row.expire = os.clock() + 3
		UI.pulse(row.scale, 1.15)
	else
		toastCounter += 1
		local frame = UI.new("Frame", { Size = UDim2.fromOffset(260, 26), BackgroundColor3 = UI.Colors.Panel, BackgroundTransparency = 0.3, LayoutOrder = toastCounter, Parent = pickupList }, { UI.corner(6) })
		local label = UI.label({ Text = ("+%d  %s"):format(count, def.name), Position = UDim2.fromOffset(8, 3), Size = UDim2.new(1, -16, 1, -6), TextColor3 = UI.Colors.Green, Parent = frame }, { UI.textStroke(1) })
		row = { frame = frame, label = label, count = count, expire = os.clock() + 3, scale = UI.new("UIScale", { Parent = frame }) }
		pickupRows[id] = row
		task.spawn(function()
			while os.clock() < row.expire do
				task.wait(0.25)
			end
			UI.fadeOut(frame, 0.3)
			task.wait(0.35)
			frame:Destroy()
			if pickupRows[id] == row then
				pickupRows[id] = nil
			end
		end)
	end
	Sounds.play("ping", 2.4, 0.12)
end

local QUEST_LABELS = { daily = "CONTRATO", guild = "CONTRATO DA GUILDA", bonus = "BÔNUS DIÁRIO", main = "MISSÃO", side = "MISSÃO", lenda = "LENDA" }

function Popups.handle(notification)
	local kind = notification.kind
	if kind == "loot" then
		Popups.loot(notification.item)
	elseif kind == "material" or kind == "consumable" then
		Popups.pickup(notification.id, notification.count)
	elseif kind == "levelup" then
		Popups.burst("NÍVEL " .. notification.level .. "!", UI.Colors.Gold, "+1 ponto de habilidade (tecla C)")
		Sounds.play("levelup", 1, 0.7)
		task.delay(0.12, Sounds.play, "ping", 2, 0.4)
		Fx.levelUp()
	elseif kind == "rankup" then
		local rank = Config.getRankByName(notification.rank)
		Popups.banner("RANK " .. notification.rank .. " ALCANÇADO!", "Novas áreas e inimigos esperam por você", rank.color, 5)
		Fx.shake(0.4, 0.5)
	elseif kind == "skillup" then
		local skill = Skills.List[notification.skill]
		if skill then
			Popups.banner(("%s: nível %d!"):format(skill.name, notification.level), notification.perk and ("Novo: " .. notification.perk) or nil, UI.Colors.Xp, 3)
			Sounds.play("ping", 1.7, 0.35)
		end
	elseif kind == "ability" then
		local ability = Classes.Abilities[notification.ability]
		if ability then
			if notification.learn then
				Popups.banner("Habilidade avançada disponível: " .. ability.name, "Aprenda com 1 ponto de talento (tecla C, aba Habilidades)", Color3.fromRGB(255, 220, 140), 5)
			else
				Popups.burst("NOVA HABILIDADE!", Color3.fromRGB(150, 220, 255), ability.name)
			end
		end
	elseif kind == "quest" then
		Popups.banner((QUEST_LABELS[notification.category] or "MISSÃO") .. " COMPLETA: " .. notification.title, notification.reward, UI.Colors.Green, 4.5)
		Sounds.play("quest", 1, 0.6)
		task.delay(0.15, Sounds.play, "ping", 1.6, 0.4)
	elseif kind == "questAccepted" then
		Popups.banner("Nova missão: " .. notification.title, "Acompanhe no canto da tela (J para o diário)", UI.Colors.Gold, 3)
	elseif kind == "questReady" then
		Popups.banner("! Objetivos concluídos: " .. notification.title, "Volte para falar com " .. notification.npc, UI.Colors.Gold, 4)
		Sounds.play("ping", 1.9, 0.4)
	elseif kind == "discover" then
		Popups.banner("Pedra de viagem ativada: " .. notification.name, "Use o mapa (M) para viajar até aqui", Color3.fromRGB(140, 210, 255), 4)
		Sounds.play("ping", 1.1, 0.5)
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
