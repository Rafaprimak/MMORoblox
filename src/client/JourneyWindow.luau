-- Jornada (tecla K): temporada (Passe Premium e evento sazonal), recompensa diária em sequência,
-- Passe do Hunter (trilha grátis + Premium), conquistas e títulos.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Progression = require(Shared.Progression)
local Items = require(Shared.Items)
local Pets = require(Shared.Pets)
local Chests = require(Shared.Chests)
local Seasons = require(Shared.Seasons)

local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Window = require(script.Parent.Window)
local Sounds = require(script.Parent.Sounds)
local Popups = require(script.Parent.Popups)
local Fx = require(script.Parent.Fx)
local Store = require(script.Parent.Store)

local JourneyWindow = {}

local win, body
local shownLoginPrompt = false

local function rewardText(reward)
	return Progression.rewardText(reward, Items, Pets, Chests)
end

-- ===================== DIÁRIO =====================
local function renderDaily(progress)
	local login = progress.login
	UI.label({ Text = ("Sequência: %d dia(s). Entre todo dia: se faltar um, a sequência recomeça."):format(login.streak), Size = UDim2.new(1, -10, 0, 22), TextColor3 = UI.Colors.Gold, Font = Enum.Font.GothamBlack, LayoutOrder = 0, Parent = body }, { UI.textStroke(1) })
	local row = UI.new("Frame", { Size = UDim2.new(1, -10, 0, 200), BackgroundTransparency = 1, LayoutOrder = 1, Parent = body }, { UI.list(8, true) })
	for day, reward in Progression.Login do
		local done = day <= login.streak and not (login.canClaim and day >= login.nextDay)
		local isNext = login.canClaim and day == login.nextDay
		local card = UI.new("Frame", { Size = UDim2.new(1 / 7, -7, 1, 0), BackgroundColor3 = if isNext then Color3.fromRGB(70, 60, 20) elseif done then Color3.fromRGB(30, 60, 40) else UI.Colors.PanelLight, BackgroundTransparency = 0.1, LayoutOrder = day, Parent = row }, { UI.corner(10), UI.stroke(if isNext then UI.Colors.Gold elseif day == 7 then Color3.fromRGB(200, 150, 255) else UI.Colors.Stroke, if isNext then 3 else 1.5) })
		UI.label({ Text = "DIA " .. day, Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamBlack, TextColor3 = if isNext then UI.Colors.Gold else UI.Colors.Text, Parent = card })
		UI.icon(if done then "check-mark" elseif day == 7 then "crown" else "present", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 28), Size = UDim2.fromOffset(40, 40), Color = if done then UI.Colors.Green elseif day == 7 then Color3.fromRGB(220, 170, 255) else UI.Colors.Gold, Parent = card })
		UI.label({ Text = rewardText(reward), Position = UDim2.fromOffset(4, 74), Size = UDim2.new(1, -8, 1, -80), TextScaled = false, TextSize = 13, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamBold, Parent = card })
	end
	local claim = UI.button({ Text = if login.canClaim then "RESGATAR A RECOMPENSA DE HOJE" else "Já resgatado. Volte amanhã!", Size = UDim2.new(1, -10, 0, 46), BackgroundColor3 = if login.canClaim then UI.Colors.Green else UI.Colors.Dark, LayoutOrder = 2, Parent = body })
	claim.MouseButton1Click:Connect(function()
		if login.canClaim then
			local result = State.request("claimLogin")
			if result and result.ok then
				Fx.shake(0.15, 0.3)
			end
		end
	end)
end

-- ===================== TEMPORADA =====================
local PREMIUM = Color3.fromRGB(255, 200, 90)

local function renderSeason(progress)
	local season = Seasons.info(os.time())
	local pass = progress.pass
	-- cabeçalho da temporada
	local header = UI.new("Frame", { Size = UDim2.new(1, -10, 0, 96), BackgroundColor3 = UI.Colors.PanelLight, LayoutOrder = 0, Parent = body }, { UI.corner(10), UI.stroke(season.color, 2, 0.3) })
	UI.icon("star-formation", { Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(72, 72), Color = season.color, Parent = header })
	UI.label({ Text = string.upper(season.name), Position = UDim2.fromOffset(96, 10), Size = UDim2.new(1, -110, 0, 28), FontFace = UI.TitleFont, TextColor3 = season.color, Parent = header }, { UI.textStroke(1) })
	UI.label({ Text = ("Termina em %s. Na virada, o Passe do Hunter e a pontuação da Arena recomeçam (títulos e itens ficam com você)."):format(UI.formatTime(season.endsIn)), Position = UDim2.fromOffset(96, 42), Size = UDim2.new(1, -110, 0, 40), TextScaled = false, TextSize = 13, TextWrapped = true, Font = Enum.Font.GothamBold, TextColor3 = UI.Colors.SubText, Parent = header })
	-- Passe Premium
	local premium = UI.new("Frame", { Size = UDim2.new(1, -10, 0, 120), BackgroundColor3 = Color3.fromRGB(50, 40, 20), BackgroundTransparency = 0.1, LayoutOrder = 1, Parent = body }, { UI.corner(10), UI.stroke(PREMIUM, 2, 0.2) })
	UI.icon("crown", { Position = UDim2.fromOffset(12, 14), Size = UDim2.fromOffset(60, 60), Color = PREMIUM, Parent = premium })
	UI.label({ Text = "PASSE PREMIUM DA TEMPORADA", Position = UDim2.fromOffset(84, 8), Size = UDim2.new(1, -96, 0, 24), FontFace = UI.TitleFont, TextColor3 = PREMIUM, Parent = premium }, { UI.textStroke(1) })
	UI.label({ Text = "Uma recompensa a mais em cada um dos 50 tiers: muito ouro, baús Prata e Real, ovos Raros e Lendários e o título arco-íris \"Lenda da Temporada\". Todas as recompensas aparecem na aba Passe antes de comprar. Tiers que você já subiu são liberados na hora.", Position = UDim2.fromOffset(84, 34), Size = UDim2.new(1, -260, 0, 76), TextScaled = false, TextSize = 13, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Font = Enum.Font.GothamBold, Parent = premium })
	if pass.premium then
		UI.label({ Text = "ATIVO", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), Size = UDim2.fromOffset(150, 40), TextXAlignment = Enum.TextXAlignment.Center, FontFace = UI.TitleFont, TextColor3 = UI.Colors.Green, Parent = premium }, { UI.textStroke(1.5) })
	else
		local buy = UI.button({ Text = "Comprar  •  " .. Store.priceText("pass_premium"), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(160, 44), BackgroundColor3 = Color3.fromRGB(220, 160, 40), Parent = premium })
		buy.MouseButton1Click:Connect(function()
			Store.buy("pass_premium")
		end)
	end
	-- evento sazonal
	local eventId = workspace:GetAttribute("Evento")
	local event = eventId and Seasons.EventsById[eventId]
	local eventState = State.data and State.data.event
	if event then
		local card = UI.new("Frame", { Size = UDim2.new(1, -10, 0, 130), BackgroundColor3 = UI.Colors.PanelLight, LayoutOrder = 2, Parent = body }, { UI.corner(10), UI.stroke(event.color, 2, 0.2) })
		UI.icon(event.icon, { Position = UDim2.fromOffset(12, 14), Size = UDim2.fromOffset(64, 64), Color = event.color, Parent = card })
		UI.label({ Text = "EVENTO: " .. string.upper(event.name), Position = UDim2.fromOffset(88, 8), Size = UDim2.new(1, -100, 0, 24), FontFace = UI.TitleFont, TextColor3 = event.color, Parent = card }, { UI.textStroke(1) })
		UI.label({ Text = event.text, Position = UDim2.fromOffset(88, 34), Size = UDim2.new(1, -100, 0, 40), TextScaled = false, TextSize = 13, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Font = Enum.Font.GothamBold, TextColor3 = UI.Colors.SubText, Parent = card })
		local title = Progression.Titles[event.title]
		local kills = if eventState then eventState.kills else 0
		local done = eventState ~= nil and eventState.done
		local _, fill, label = UI.bar(card, { Position = UDim2.fromOffset(88, 82), Size = UDim2.new(1, -100, 0, 18), color = event.color })
		UI.setBar(fill, if done then 1 else kills / event.goal)
		label.Text = if done then "META COMPLETA" else ("%d / %d abates"):format(kills, event.goal)
		UI.label({ Text = ("Prêmio: título \"%s\" + %s"):format(if title then title.name else "?", rewardText(event.reward or {})), Position = UDim2.fromOffset(88, 104), Size = UDim2.new(1, -100, 0, 18), TextScaled = false, TextSize = 13, Font = Enum.Font.GothamBold, TextColor3 = UI.Colors.Gold, Parent = card })
	else
		local nextText = {}
		for _, entry in Seasons.Events do
			table.insert(nextText, ("%s (%02d/%02d)"):format(entry.name, entry.from[2], entry.from[1]))
		end
		UI.label({ Text = "Nenhum evento agora. Próximos: " .. table.concat(nextText, ", "), Size = UDim2.new(1, -10, 0, 40), TextScaled = false, TextSize = 13, TextWrapped = true, Font = Enum.Font.GothamBold, TextColor3 = UI.Colors.SubText, LayoutOrder = 2, Parent = body })
	end
end

-- ===================== PASSE =====================
local function renderPass(progress)
	local pass = progress.pass
	UI.label({ Text = ("PASSE DO HUNTER  •  Tier %d/%d%s"):format(pass.tier, Progression.PassMaxTier, if pass.premium then "  •  PREMIUM" else ""), Size = UDim2.new(1, -10, 0, 24), TextColor3 = Color3.fromRGB(150, 210, 255), Font = Enum.Font.GothamBlack, LayoutOrder = 0, Parent = body }, { UI.textStroke(1) })
	local barHolder = UI.new("Frame", { Size = UDim2.new(1, -10, 0, 20), BackgroundTransparency = 1, LayoutOrder = 1, Parent = body })
	local _, fill, label = UI.bar(barHolder, { Size = UDim2.fromScale(1, 1), color = Color3.fromRGB(120, 190, 255) })
	UI.setBar(fill, pass.xp / math.max(pass.need, 1))
	label.Text = ("%s / %s XP  (ganhe XP derrotando inimigos, completando missões, fabricando e coletando)"):format(UI.formatNumber(pass.xp), UI.formatNumber(pass.need))
	local pending = pass.tier - pass.claimed + (if pass.premium then pass.tier - (pass.claimedPremium or 0) else 0)
	local claim = UI.button({ Text = if pending > 0 then ("RESGATAR %d RECOMPENSA(S)"):format(pending) else "Suba de tier para ganhar recompensas", Size = UDim2.new(1, -10, 0, 40), BackgroundColor3 = if pending > 0 then UI.Colors.Green else UI.Colors.Dark, LayoutOrder = 2, Parent = body })
	claim.MouseButton1Click:Connect(function()
		if pending > 0 then
			local result = State.request("claimPass")
			if result and result.ok then
				Fx.shake(0.2, 0.35)
				Sounds.play("ping", 1.4, 0.6)
			end
		end
	end)
	local grid = UI.new("Frame", { Size = UDim2.new(1, -10, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 3, Parent = body }, { UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(136, 132), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	-- mostra a partir de alguns tiers antes do atual
	local first = math.max(1, pass.claimed - 2)
	for tier = first, math.min(Progression.PassMaxTier, first + 23) do
		local reward = Progression.passReward(tier)
		local reached = tier <= pass.tier
		local claimed = tier <= pass.claimed
		local special = tier % 5 == 0
		local cell = UI.new("Frame", { LayoutOrder = tier, BackgroundColor3 = if claimed then Color3.fromRGB(30, 55, 40) elseif reached then Color3.fromRGB(70, 60, 20) else UI.Colors.PanelLight, BackgroundTransparency = 0.1, Parent = grid }, { UI.corner(8), UI.stroke(if special then Color3.fromRGB(200, 150, 255) elseif reached then UI.Colors.Gold else UI.Colors.Stroke, if special then 2 else 1) })
		UI.label({ Text = "Tier " .. tier .. (if claimed then "  (pego)" elseif reached then "  »" else ""), Position = UDim2.fromOffset(6, 4), Size = UDim2.new(1, -12, 0, 18), Font = Enum.Font.GothamBlack, Parent = cell })
		UI.label({ Text = rewardText(reward), Position = UDim2.fromOffset(6, 24), Size = UDim2.new(1, -12, 0, 48), TextScaled = false, TextSize = 13, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Font = Enum.Font.GothamBold, TextColor3 = if reached then UI.Colors.Text else UI.Colors.SubText, Parent = cell })
		-- trilha Premium (sempre visível, para saber o que se ganha antes de comprar)
		local premiumClaimed = pass.premium and tier <= (pass.claimedPremium or 0)
		local strip = UI.new("Frame", { Position = UDim2.new(0, 4, 1, -58), Size = UDim2.new(1, -8, 0, 54), BackgroundColor3 = Color3.fromRGB(60, 45, 15), BackgroundTransparency = if pass.premium then 0.1 else 0.45, Parent = cell }, { UI.corner(6), UI.stroke(PREMIUM, 1, if pass.premium then 0.3 else 0.7) })
		UI.label({ Text = "PREMIUM" .. (if premiumClaimed then "  (pego)" elseif not pass.premium then "  (bloqueado)" else ""), Position = UDim2.fromOffset(4, 2), Size = UDim2.new(1, -8, 0, 14), TextScaled = false, TextSize = 11, Font = Enum.Font.GothamBlack, TextColor3 = PREMIUM, Parent = strip })
		UI.label({ Text = rewardText(Progression.passPremiumReward(tier)), Position = UDim2.fromOffset(4, 16), Size = UDim2.new(1, -8, 1, -18), TextScaled = false, TextSize = 12, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Font = Enum.Font.GothamBold, TextColor3 = if pass.premium and reached then UI.Colors.Text else UI.Colors.SubText, Parent = strip })
	end
end

-- ===================== CONQUISTAS =====================
local ROMAN = { "I", "II", "III" }

local function renderAchievements(progress)
	local byId = {}
	for _, entry in progress.achievements do
		byId[entry.id] = entry
	end
	for index, achievement in Progression.Achievements do
		local entry = byId[achievement.id] or { value = 0, tier = 0 }
		local maxed = entry.tier >= #achievement.tiers
		local goal = achievement.tiers[math.min(entry.tier + 1, #achievement.tiers)]
		local row = UI.new("Frame", { Size = UDim2.new(1, -10, 0, 58), BackgroundColor3 = if maxed then Color3.fromRGB(60, 50, 20) else UI.Colors.PanelLight, BackgroundTransparency = 0.25, LayoutOrder = index, Parent = body }, { UI.corner(8), UI.stroke(if maxed then UI.Colors.Gold else UI.Colors.Stroke, 1.2) })
		UI.icon(achievement.icon, { Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(46, 46), Parent = row })
		UI.label({ Text = ("%s %s"):format(achievement.name, if entry.tier > 0 then ROMAN[entry.tier] else ""), Position = UDim2.fromOffset(58, 4), Size = UDim2.new(0.5, 0, 0, 20), Font = Enum.Font.GothamBlack, TextColor3 = if maxed then UI.Colors.Gold else UI.Colors.Text, Parent = row })
		local title = Progression.Titles[achievement.title]
		UI.label({ Text = achievement.text .. (if title then ("  •  título: %s"):format(title.name) else ""), Position = UDim2.fromOffset(58, 24), Size = UDim2.new(1, -260, 0, 14), TextColor3 = UI.Colors.SubText, Font = Enum.Font.Gotham, Parent = row })
		local _, fill, label = UI.bar(row, { Position = UDim2.new(1, -196, 0, 18), Size = UDim2.fromOffset(186, 20), color = if maxed then UI.Colors.Gold else UI.Colors.Xp })
		UI.setBar(fill, if maxed then 1 else entry.value / goal)
		label.Text = if maxed then "COMPLETA" else ("%s / %s"):format(UI.formatNumber(entry.value), UI.formatNumber(goal))
		for tier = 1, #achievement.tiers do
			UI.new("Frame", { Position = UDim2.new(1, -196 + (tier - 1) * 14, 0, 42), Size = UDim2.fromOffset(10, 10), BackgroundColor3 = if tier <= entry.tier then UI.Colors.Gold else UI.Colors.Dark, Parent = row }, { UI.corner(5) })
		end
	end
end

-- ===================== TÍTULOS =====================
local function renderTitles(progress)
	UI.label({ Text = "O título aparece em cima da sua cabeça para todos. Ganhe títulos com conquistas, passe e marcos de nível.", Size = UDim2.new(1, -10, 0, 34), TextWrapped = true, TextColor3 = UI.Colors.SubText, LayoutOrder = 0, Parent = body })
	local none = UI.button({ Text = if progress.title == "" then "Sem título (em uso)" else "Sem título", Size = UDim2.new(1, -10, 0, 34), BackgroundColor3 = UI.Colors.Dark, LayoutOrder = 1, Parent = body })
	none.MouseButton1Click:Connect(function()
		State.request("setTitle", "")
	end)
	local owned = {}
	for _, id in progress.titles do
		owned[id] = true
	end
	local ids = {}
	for id in Progression.Titles do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		if (owned[a] == true) ~= (owned[b] == true) then
			return owned[a] == true
		end
		return Progression.Titles[a].name < Progression.Titles[b].name
	end)
	for index, id in ids do
		local title = Progression.Titles[id]
		local has = owned[id] == true
		local active = progress.title == id
		local button = UI.button({ Text = title.name .. (if active then "  (em uso)" else ""), Size = UDim2.new(1, -10, 0, 34), BackgroundColor3 = if active then Color3.fromRGB(70, 60, 20) elseif has then UI.Colors.PanelLight else UI.Colors.Panel, TextColor3 = if has then title.color else UI.Colors.SubText, LayoutOrder = 10 + index, Parent = body })
		button.MouseButton1Click:Connect(function()
			if has then
				local result = State.request("setTitle", id)
				if result and result.ok then
					Sounds.play("equip", 1.4, 0.5)
				end
			end
		end)
	end
end

local function render()
	local data = State.data
	local progress = data and data.progress
	if not progress then
		return
	end
	UI.clear(body)
	if win.tab == "Temporada" then
		renderSeason(progress)
	elseif win.tab == "Passe" then
		renderPass(progress)
	elseif win.tab == "Conquistas" then
		renderAchievements(progress)
	elseif win.tab == "Títulos" then
		renderTitles(progress)
	else
		renderDaily(progress)
	end
end

function JourneyWindow.init(screen)
	win = Window.create(screen, { icon = "star-formation", name = "Jornada", title = "JORNADA DO HUNTER", width = 820, height = 560, tabs = { "Temporada", "Diário", "Passe", "Conquistas", "Títulos" }, accent = UI.Colors.Gold })
	body = UI.new("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = win.content }, { UI.list(8) })
	win.onTab = render
	win.onOpen = render
	State.Changed:Connect(function(data)
		if win:isOpen() then
			render()
		end
		-- abre sozinho a recompensa diária na primeira vez que der para resgatar
		if not shownLoginPrompt and data.class and data.progress and data.progress.login.canClaim then
			shownLoginPrompt = true
			task.delay(3, function()
				if not Window.anyOpen() then
					win:open()
					win:setTab("Diário")
				end
			end)
		end
	end)
end

function JourneyWindow.toggle()
	win:toggle()
end

-- há algo para resgatar? (para o aviso no botão do HUD)
function JourneyWindow.hasClaim(data)
	local progress = data and data.progress
	return progress ~= nil and (progress.login.canClaim or progress.pass.tier > progress.pass.claimed or (progress.pass.premium and progress.pass.tier > (progress.pass.claimedPremium or 0)))
end

-- avisos vindos do servidor
function JourneyWindow.notify(notification)
	if notification.kind == "passTier" then
		Popups.banner(("PASSE DO HUNTER: TIER %d!"):format(notification.tier), "Resgate a recompensa na Jornada (tecla K)", Color3.fromRGB(130, 200, 255), 3.5)
		Sounds.play("ping", 1.6, 0.5)
	elseif notification.kind == "achievement" then
		local achievement = Progression.AchievementById[notification.id]
		if achievement then
			Popups.burst(("%s %s"):format(achievement.name, ROMAN[notification.tier] or ""), UI.Colors.Gold, "Conquista desbloqueada!")
			Fx.shake(0.15, 0.3)
		end
	elseif notification.kind == "reward" then
		Popups.banner(notification.title, notification.text, UI.Colors.Green, 4)
		Sounds.play("ping", 1.3, 0.5)
	end
end

return JourneyWindow
