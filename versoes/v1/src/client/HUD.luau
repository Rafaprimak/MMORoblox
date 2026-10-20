-- HUD fixo: rank, nível, XP, ouro, missões e botões.
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local UI = require(script.Parent.UI)

local HUD = {}

local refs = {}
local goldValue = Instance.new("NumberValue")
local lastLevel, lastGold, lastRank = nil, nil, nil
local resetAt = 0

local function bar(parent, position, size, color)
	local back = UI.new("Frame", {
		Position = position,
		Size = size,
		BackgroundColor3 = Color3.fromRGB(10, 10, 16),
		BackgroundTransparency = 0.2,
		Parent = parent,
	}, { UI.corner(6) })
	local fill = UI.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = color, Parent = back }, { UI.corner(6) })
	return back, fill
end

local function questRow(parent, y, withReward)
	local row = {}
	row.frame = UI.new("Frame", {
		Position = UDim2.fromOffset(12, y),
		Size = UDim2.new(1, -24, 0, if withReward then 50 else 32),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	row.text = UI.label({ Size = UDim2.new(1, -70, 0, 17), Font = Enum.Font.GothamBold, Parent = row.frame }, { UI.textStroke(1) })
	row.progress = UI.label({
		Position = UDim2.new(1, -66, 0, 0),
		Size = UDim2.fromOffset(66, 17),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = UI.Colors.Gold,
		Parent = row.frame,
	}, { UI.textStroke(1) })
	local _, fill = bar(row.frame, UDim2.fromOffset(0, 21), UDim2.new(1, 0, 0, 8), UI.Colors.Gold)
	row.fill = fill
	if withReward then
		row.reward = UI.label({
			Position = UDim2.fromOffset(0, 33),
			Size = UDim2.new(1, 0, 0, 14),
			Font = Enum.Font.Gotham,
			TextColor3 = UI.Colors.SubText,
			Parent = row.frame,
		})
	end
	return row
end

local function setQuestRow(row, quest)
	if not quest then
		row.frame.Visible = false
		return
	end
	row.frame.Visible = true
	row.text.Text = (if quest.done then "✅ " else "") .. quest.text
	row.text.TextColor3 = if quest.done then UI.Colors.Green else UI.Colors.Text
	row.progress.Text = if quest.done then "Feito!" else ("%s/%s"):format(UI.formatNumber(quest.progress), UI.formatNumber(quest.amount))
	row.fill.BackgroundColor3 = if quest.done then UI.Colors.Green else UI.Colors.Gold
	local ratio = math.clamp(quest.progress / math.max(quest.amount, 1), 0, 1)
	TweenService:Create(row.fill, TweenInfo.new(0.3), { Size = UDim2.fromScale(ratio, 1) }):Play()
	if row.reward then
		row.reward.Text = "Recompensa: " .. quest.reward
	end
end

function HUD.init(screen, callbacks)
	-- Painel do jogador (canto superior esquerdo)
	local panel = UI.new("Frame", {
		Name = "Jogador",
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(310, 92),
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.2,
		Parent = screen,
	}, { UI.corner(12), UI.stroke(UI.Colors.Stroke, 1.5, 0.3) })

	refs.rankBadge = UI.new("Frame", {
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.fromOffset(72, 72),
		BackgroundColor3 = Config.Ranks[1].color,
		Parent = panel,
	}, { UI.corner(12), UI.stroke(Color3.new(1, 1, 1), 2, 0.5) })
	refs.rankScale = UI.new("UIScale", { Parent = refs.rankBadge })
	refs.rankLetter = UI.label({
		Text = "E",
		Size = UDim2.fromScale(1, 0.75),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Enum.Font.GothamBlack,
		Parent = refs.rankBadge,
	}, { UI.textStroke(2) })
	UI.label({
		Text = "RANK",
		Position = UDim2.fromScale(0, 0.72),
		Size = UDim2.fromScale(1, 0.22),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = refs.rankBadge,
	}, { UI.textStroke(1) })

	refs.level = UI.label({ Text = "Nível 1", Position = UDim2.fromOffset(94, 8), Size = UDim2.fromOffset(206, 22), Font = Enum.Font.GothamBlack, Parent = panel }, { UI.textStroke(1) })
	local xpBack, xpFill = bar(panel, UDim2.fromOffset(94, 34), UDim2.fromOffset(206, 16), UI.Colors.Xp)
	refs.xpFill = xpFill
	refs.xpText = UI.label({
		Text = "",
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 2,
		Parent = xpBack,
	}, { UI.textStroke(1) })

	refs.gold = UI.label({ Text = "💰 0", Position = UDim2.fromOffset(94, 56), Size = UDim2.fromOffset(110, 24), TextColor3 = UI.Colors.Gold, Font = Enum.Font.GothamBlack, Parent = panel }, { UI.textStroke(1) })
	refs.goldScale = UI.new("UIScale", { Parent = refs.gold })
	refs.stats = UI.label({
		Text = "",
		Position = UDim2.fromOffset(206, 59),
		Size = UDim2.fromOffset(94, 18),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = UI.Colors.SubText,
		Parent = panel,
	})
	refs.nextRank = UI.label({
		Text = "",
		Position = UDim2.fromOffset(16, 108),
		Size = UDim2.fromOffset(300, 16),
		TextColor3 = UI.Colors.SubText,
		Parent = screen,
	}, { UI.textStroke(1) })

	goldValue.Changed:Connect(function(value)
		refs.gold.Text = "💰 " .. UI.formatNumber(value)
	end)

	-- Missões (canto superior direito)
	local quests = UI.new("Frame", {
		Name = "Missoes",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(290, 254),
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.25,
		Parent = screen,
	}, { UI.corner(12), UI.stroke(UI.Colors.Stroke, 1.5, 0.3) })
	UI.label({ Text = "📜 MISSÃO", Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(200, 20), TextColor3 = UI.Colors.Gold, Font = Enum.Font.GothamBlack, Parent = quests }, { UI.textStroke(1) })
	refs.story = questRow(quests, 32, true)
	UI.new("Frame", { Position = UDim2.fromOffset(12, 88), Size = UDim2.new(1, -24, 0, 1), BackgroundColor3 = UI.Colors.Stroke, BorderSizePixel = 0, Parent = quests })
	UI.label({ Text = "📅 DIÁRIAS", Position = UDim2.fromOffset(12, 94), Size = UDim2.fromOffset(120, 18), TextColor3 = UI.Colors.Xp, Font = Enum.Font.GothamBlack, Parent = quests }, { UI.textStroke(1) })
	refs.dailyReset = UI.label({
		Text = "",
		Position = UDim2.new(1, -152, 0, 96),
		Size = UDim2.fromOffset(140, 14),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = UI.Colors.SubText,
		Font = Enum.Font.Gotham,
		Parent = quests,
	})
	refs.daily = {}
	for i = 1, 3 do
		refs.daily[i] = questRow(quests, 118 + (i - 1) * 36, false)
	end
	refs.dailyBonus = UI.label({
		Text = "",
		Position = UDim2.fromOffset(12, 228),
		Size = UDim2.new(1, -24, 0, 16),
		TextColor3 = UI.Colors.SubText,
		Font = Enum.Font.GothamBold,
		Parent = quests,
	})

	-- Botões (meio da esquerda, longe dos controles do celular)
	local buttons = UI.new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(170, 240),
		BackgroundTransparency = 1,
		Parent = screen,
	}, { UI.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local inventoryButton = UI.button({ Text = "🎒 Inventário [I]", Size = UDim2.fromOffset(170, 44), BackgroundColor3 = Color3.fromRGB(60, 90, 200), LayoutOrder = 1, Parent = buttons })
	inventoryButton.MouseButton1Click:Connect(callbacks.onInventory)
	local chestButton = UI.button({ Text = "🎁 Baú [B]", Size = UDim2.fromOffset(170, 44), BackgroundColor3 = Color3.fromRGB(210, 140, 30), LayoutOrder = 2, Parent = buttons })
	chestButton.MouseButton1Click:Connect(callbacks.onChest)

	refs.devPanel = UI.new("Frame", {
		Size = UDim2.fromOffset(170, 100),
		BackgroundTransparency = 1,
		LayoutOrder = 3,
		Visible = false,
		Parent = buttons,
	}, { UI.new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })
	UI.label({ Text = "🧪 MODO TESTE (só no Studio)", Size = UDim2.fromOffset(170, 16), TextColor3 = UI.Colors.SubText, LayoutOrder = 1, Parent = refs.devPanel }, { UI.textStroke(1) })
	local devXp = UI.button({ Text = "+5.000 XP", Size = UDim2.fromOffset(170, 34), BackgroundColor3 = Color3.fromRGB(60, 60, 75), LayoutOrder = 2, Parent = refs.devPanel })
	devXp.MouseButton1Click:Connect(function()
		callbacks.onDev("xp")
	end)
	local devGold = UI.button({ Text = "+5.000 Ouro", Size = UDim2.fromOffset(170, 34), BackgroundColor3 = Color3.fromRGB(60, 60, 75), LayoutOrder = 3, Parent = refs.devPanel })
	devGold.MouseButton1Click:Connect(function()
		callbacks.onDev("gold")
	end)

	-- contador regressivo das diárias
	task.spawn(function()
		while true do
			if resetAt > 0 then
				refs.dailyReset.Text = "reinicia em " .. UI.formatTime(resetAt - os.clock())
			end
			task.wait(1)
		end
	end)
end

function HUD.update(data)
	local rank = Config.getRank(data.level)
	refs.rankLetter.Text = rank.name
	refs.rankBadge.BackgroundColor3 = rank.color
	if lastRank and lastRank ~= rank.name then
		UI.pulse(refs.rankScale, 1.5)
	end
	lastRank = rank.name

	refs.level.Text = "Nível " .. data.level
	local nextRank = Config.getNextRank(data.level)
	refs.nextRank.Text = if nextRank then ("Próximo: Rank %s no Nível %d"):format(nextRank.name, nextRank.minLevel) else "Rank máximo alcançado!"

	if lastLevel and data.level > lastLevel then
		refs.xpFill.Size = UDim2.fromScale(0, 1)
	end
	local ratio = math.clamp(data.xp / math.max(data.xpNext, 1), 0, 1)
	TweenService:Create(refs.xpFill, TweenInfo.new(0.35), { Size = UDim2.fromScale(ratio, 1) }):Play()
	refs.xpText.Text = ("%s / %s XP"):format(UI.formatNumber(data.xp), UI.formatNumber(data.xpNext))
	lastLevel = data.level

	-- ouro "contando" até o valor novo
	if lastGold == nil then
		goldValue.Value = data.gold
		refs.gold.Text = "💰 " .. UI.formatNumber(data.gold)
	elseif data.gold ~= lastGold then
		TweenService:Create(goldValue, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { Value = data.gold }):Play()
		if data.gold > lastGold then
			UI.pulse(refs.goldScale, 1.25)
		end
	end
	lastGold = data.gold

	refs.stats.Text = ("⚔ %s  ❤ %s"):format(UI.formatNumber(data.attack), UI.formatNumber(data.maxHealth))

	local quests = data.quests
	if quests then
		if quests.story then
			setQuestRow(refs.story, quests.story)
		else
			setQuestRow(refs.story, { text = "História concluída! Novidades em breve.", progress = 1, amount = 1, done = true, reward = "—" })
		end
		for i = 1, 3 do
			setQuestRow(refs.daily[i], quests.daily[i])
		end
		resetAt = os.clock() + quests.dailyResetIn
		refs.dailyBonus.Text = if quests.dailyBonusClaimed then "✅ Bônus diário recebido!" else "Complete as 3: " .. quests.dailyBonus
	end

	refs.devPanel.Visible = data.isStudio == true
end

return HUD
