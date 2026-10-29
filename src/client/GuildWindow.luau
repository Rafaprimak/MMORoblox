-- Guilda (tecla L). Abas:
--   Guilda: sem guilda = fundar (nome, sigla, emblema; perto da Helena) e convites; com guilda = emblema,
--           nível e bônus, membros (cargo, online/visto) com ações conforme o cargo, convidar jogadores
--           deste servidor, histórico e "Sair".
--   Banco: saldo, depositar (todos) e sacar (líder e oficiais).
--   Metas: Guilds.WeeklyGoals metas da semana com progresso e "Resgatar" (cada membro uma vez).
--   Ranking: top 20 guildas da semana.
-- Chat da guilda (todos os servidores): /gu mensagem (ou /guilda). Convite recebido: painel Entrar/Recusar.
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Guilds = require(Shared.Guilds)

local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Window = require(script.Parent.Window)
local Popups = require(script.Parent.Popups)
local Sounds = require(script.Parent.Sounds)

local GuildWindow = {}

local player = Players.LocalPlayer
local win
local pages = {}
local invitePanel, inviteText
local emblemChoice = Guilds.Emblems[1]
local lastKey = nil

local function text(parent, props)
	local merged = { TextScaled = false, TextSize = 14, TextWrapped = true, Font = Enum.Font.GothamBold }
	for k, v in props do
		merged[k] = v
	end
	merged.Parent = parent
	return UI.label(merged)
end

local function textBox(parent, props)
	local merged = { Text = "", ClearTextOnFocus = false, BackgroundColor3 = UI.Colors.PanelLight, TextColor3 = UI.Colors.Text, PlaceholderColor3 = UI.Colors.SubText, Font = Enum.Font.Gotham, TextSize = 15, Parent = parent }
	for k, v in props do
		merged[k] = v
	end
	return UI.new("TextBox", merged, { UI.corner(8), UI.padding(8) })
end

local function reply(result, successText)
	if result and (result.msg or successText) then
		Popups.message(result.msg or successText, if result.ok then UI.Colors.Green else UI.Colors.Red)
	end
end

local function ago(seconds)
	if not seconds then
		return ""
	end
	local delta = math.max(0, os.time() - seconds)
	if delta < 3600 then
		return ("há %d min"):format(math.floor(delta / 60))
	elseif delta < 86400 then
		return ("há %d h"):format(math.floor(delta / 3600))
	end
	return ("há %d dias"):format(math.floor(delta / 86400))
end

-- ===================== ABA GUILDA =====================

local function renderCreate(page, info)
	text(page, { Text = ("Você não tem guilda. Fundar custa %d de ouro e o nível %d; fale com a Helena no Salão dos Clãs (a leste da vila)."):format(Guilds.CreateCost, Guilds.CreateLevel), Size = UDim2.new(1, 0, 0, 40), TextColor3 = UI.Colors.SubText })
	if info and info.invite then
		text(page, { Text = ("Convite pendente: %s (de %s)"):format(info.invite.name, info.invite.from), Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 0, 20), TextColor3 = UI.Colors.Green })
	end
	local name = textBox(page, { PlaceholderText = "Nome da guilda (3 a 20 letras)", Position = UDim2.fromOffset(0, 74), Size = UDim2.new(0.6, -6, 0, 36) })
	local tag = textBox(page, { PlaceholderText = "Sigla (2 a 4)", Position = UDim2.new(0.6, 6, 0, 74), Size = UDim2.new(0.4, -6, 0, 36) })
	text(page, { Text = "Emblema:", Position = UDim2.fromOffset(0, 120), Size = UDim2.new(1, 0, 0, 18) })
	local grid = UI.new("Frame", { Position = UDim2.fromOffset(0, 142), Size = UDim2.new(1, 0, 0, 110), BackgroundTransparency = 1, Parent = page }, { UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(50, 50), CellPadding = UDim2.fromOffset(6, 6) }) })
	for _, iconName in Guilds.Emblems do
		local cell = UI.button({ Text = "", BackgroundColor3 = if iconName == emblemChoice then Color3.fromRGB(120, 95, 40) else UI.Colors.PanelLight, Parent = grid })
		UI.icon(iconName, { Position = UDim2.fromOffset(7, 7), Size = UDim2.fromOffset(36, 36), Parent = cell })
		cell.MouseButton1Click:Connect(function()
			emblemChoice = iconName
			lastKey = nil
			GuildWindow.render()
		end)
	end
	local found = UI.button({ Text = ("FUNDAR GUILDA  (%d ouro)"):format(Guilds.CreateCost), Position = UDim2.fromOffset(0, 266), Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = UI.Colors.Green, Parent = page })
	found.MouseButton1Click:Connect(function()
		local result = State.request("guildCreate", { name = name.Text, tag = tag.Text, icon = emblemChoice })
		reply(result)
	end)
end

local function memberRow(list, guild, member, order)
	local row = UI.new("Frame", { Size = UDim2.new(1, -8, 0, 36), BackgroundColor3 = UI.Colors.PanelLight, LayoutOrder = order, Parent = list }, { UI.corner(6) })
	UI.new("Frame", { Position = UDim2.fromOffset(8, 13), Size = UDim2.fromOffset(10, 10), BackgroundColor3 = if member.online then UI.Colors.Green else UI.Colors.Dark, Parent = row }, { UI.corner(5) })
	text(row, { Text = member.name, Position = UDim2.fromOffset(26, 2), Size = UDim2.new(0.4, -26, 0, 18), Font = Enum.Font.GothamBlack })
	text(row, { Text = ("%s  •  %s"):format(Guilds.RankNames[member.rank] or member.rank, if member.online then "neste servidor" else "visto " .. ago(member.seen)), Position = UDim2.fromOffset(26, 18), Size = UDim2.new(0.5, 0, 0, 16), TextSize = 12, TextColor3 = UI.Colors.SubText })
	if member.id == player.UserId then
		return
	end
	local actions = {}
	if guild.rank == "lider" then
		if member.rank == "membro" then
			table.insert(actions, { "Promover", function()
				reply(State.request("guildRank", member.id, "oficial"))
			end })
		elseif member.rank == "oficial" then
			table.insert(actions, { "Rebaixar", function()
				reply(State.request("guildRank", member.id, "membro"))
			end })
		end
		table.insert(actions, { "Liderança", function()
			reply(State.request("guildRank", member.id, "lider"))
		end })
	end
	if guild.rank == "lider" or (guild.rank == "oficial" and member.rank == "membro") then
		table.insert(actions, { "Remover", function()
			reply(State.request("guildKick", member.id))
		end })
	end
	for i, action in actions do
		local button = UI.button({ Text = action[1], AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6 - (#actions - i) * 92, 0.5, 0), Size = UDim2.fromOffset(86, 26), BackgroundColor3 = if action[1] == "Remover" then Color3.fromRGB(150, 50, 50) else UI.Colors.Dark, Parent = row })
		button.MouseButton1Click:Connect(action[2])
	end
end

local function renderGuild(page, guild)
	UI.icon(guild.icon, { Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(56, 56), Color = UI.Colors.Gold, Parent = page })
	text(page, { Text = ("[%s] %s"):format(guild.tag, guild.name), Position = UDim2.fromOffset(66, 0), Size = UDim2.new(1, -200, 0, 26), TextSize = 20, FontFace = UI.TitleFont, TextColor3 = UI.Colors.Gold })
	text(page, { Text = ("Nível %d  •  +%d%% de XP e de ouro para todos  •  %d/%d membros"):format(guild.level, math.floor(guild.bonus * 100 + 0.5), #guild.members, guild.max), Position = UDim2.fromOffset(66, 28), Size = UDim2.new(1, -200, 0, 18), TextColor3 = UI.Colors.SubText })
	local _, fill, label = UI.bar(page, { Position = UDim2.fromOffset(66, 48), Size = UDim2.new(1, -200, 0, 12), color = UI.Colors.Xp })
	local span = math.max(guild.xpNext - guild.xpThis, 1)
	UI.setBar(fill, (guild.xp - guild.xpThis) / span)
	if label then
		label.Text = ""
	end
	local leave = UI.button({ Text = "Sair da guilda", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(120, 30), BackgroundColor3 = Color3.fromRGB(150, 50, 50), Parent = page })
	local armed = false
	leave.MouseButton1Click:Connect(function()
		if not armed then
			armed = true
			leave.Text = "Confirmar?"
			task.delay(3, function()
				armed = false
				if leave.Parent then
					leave.Text = "Sair da guilda"
				end
			end)
			return
		end
		reply(State.request("guildLeave"))
	end)
	-- membros
	local list = UI.new("ScrollingFrame", { Position = UDim2.fromOffset(0, 70), Size = UDim2.new(0.62, -8, 1, -70), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = page }, { UI.list(4) })
	for order, member in guild.members do
		memberRow(list, guild, member, order)
	end
	-- lado direito: convidar (líder/oficial) e histórico
	local side = UI.new("ScrollingFrame", { Position = UDim2.new(0.62, 8, 0, 70), Size = UDim2.new(0.38, -8, 1, -70), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = page }, { UI.list(4) })
	local order = 0
	if guild.rank == "lider" or guild.rank == "oficial" then
		order += 1
		text(side, { Text = "Convidar (neste servidor):", Size = UDim2.new(1, -8, 0, 18), LayoutOrder = order, TextColor3 = UI.Colors.Gold })
		local inGuild = {}
		for _, member in guild.members do
			inGuild[member.id] = true
		end
		for _, other in Players:GetPlayers() do
			if not inGuild[other.UserId] then
				order += 1
				local invite = UI.button({ Text = "Convidar " .. other.DisplayName, Size = UDim2.new(1, -8, 0, 28), LayoutOrder = order, BackgroundColor3 = UI.Colors.Accent, Parent = side })
				invite.MouseButton1Click:Connect(function()
					reply(State.request("guildInvite", other.UserId))
				end)
			end
		end
	end
	order += 1
	text(side, { Text = "Histórico:", Size = UDim2.new(1, -8, 0, 18), LayoutOrder = order, TextColor3 = UI.Colors.Gold })
	for _, entry in guild.log do
		order += 1
		text(side, { Text = ("%s  (%s)"):format(entry.text, ago(entry.t)), Size = UDim2.new(1, -8, 0, 30), LayoutOrder = order, TextSize = 12, TextColor3 = UI.Colors.SubText })
	end
end

-- ===================== BANCO / METAS / RANKING =====================

local function renderBank(page, guild)
	if not guild then
		text(page, { Text = "Entre numa guilda para usar o banco.", Size = UDim2.new(1, 0, 0, 30), TextColor3 = UI.Colors.SubText })
		return
	end
	UI.icon("two-coins", { Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(48, 48), Color = UI.Colors.Gold, Parent = page })
	text(page, { Text = ("%s de ouro no banco da guilda"):format(UI.formatNumber(guild.bank)), Position = UDim2.fromOffset(60, 8), Size = UDim2.new(1, -60, 0, 30), TextSize = 20, TextColor3 = UI.Colors.Gold, Font = Enum.Font.GothamBlack })
	local amount = textBox(page, { PlaceholderText = "Quantidade", Position = UDim2.fromOffset(0, 64), Size = UDim2.new(0.4, 0, 0, 38) })
	local deposit = UI.button({ Text = "Depositar", Position = UDim2.new(0.4, 10, 0, 64), Size = UDim2.new(0.3, -10, 0, 38), BackgroundColor3 = UI.Colors.Green, Parent = page })
	deposit.MouseButton1Click:Connect(function()
		reply(State.request("guildBank", tonumber(amount.Text) or 0, false), "Depositado!")
	end)
	if guild.rank == "lider" or guild.rank == "oficial" then
		local withdraw = UI.button({ Text = "Sacar", Position = UDim2.new(0.7, 10, 0, 64), Size = UDim2.new(0.3, -10, 0, 38), BackgroundColor3 = UI.Colors.Dark, Parent = page })
		withdraw.MouseButton1Click:Connect(function()
			reply(State.request("guildBank", tonumber(amount.Text) or 0, true), "Sacado!")
		end)
	end
	text(page, { Text = "Todos podem depositar; só o líder e os oficiais sacam. Tudo fica registrado no histórico.", Position = UDim2.fromOffset(0, 112), Size = UDim2.new(1, 0, 0, 36), TextColor3 = UI.Colors.SubText })
end

local function renderGoals(page, guild)
	if not guild then
		text(page, { Text = "Entre numa guilda para participar das metas da semana.", Size = UDim2.new(1, 0, 0, 30), TextColor3 = UI.Colors.SubText })
		return
	end
	text(page, { Text = "Metas da semana (renovam toda segunda-feira). Todo mundo da guilda ajuda; cada membro resgata o prêmio uma vez. Contratos do Clã (Ulf) e o brinde no Salão dos Clãs também dão pontos.", Size = UDim2.new(1, 0, 0, 36), TextColor3 = UI.Colors.SubText })
	for i, goal in guild.goals do
		local y = 44 + (i - 1) * 92
		local card = UI.new("Frame", { Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 84), BackgroundColor3 = UI.Colors.PanelLight, Parent = page }, { UI.corner(10) })
		UI.icon(goal.icon, { Position = UDim2.fromOffset(10, 16), Size = UDim2.fromOffset(52, 52), Parent = card })
		text(card, { Text = goal.text, Position = UDim2.fromOffset(74, 8), Size = UDim2.new(1, -230, 0, 20), Font = Enum.Font.GothamBlack })
		local _, fill, label = UI.bar(card, { Position = UDim2.fromOffset(74, 36), Size = UDim2.new(1, -230, 0, 18), color = UI.Colors.Green })
		UI.setBar(fill, goal.progress / math.max(goal.target, 1))
		if label then
			label.Text = ("%s / %s"):format(UI.formatNumber(math.min(goal.progress, goal.target)), UI.formatNumber(goal.target))
		end
		text(card, { Text = ("Prêmio: %d de ouro + baú"):format(goal.gold), Position = UDim2.fromOffset(74, 60), Size = UDim2.new(1, -230, 0, 18), TextSize = 12, TextColor3 = UI.Colors.Gold })
		local done = goal.progress >= goal.target
		local claim = UI.button({ Text = if goal.claimed then "Resgatado" elseif done then "RESGATAR" else "Em andamento", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(140, 40), BackgroundColor3 = if done and not goal.claimed then UI.Colors.Green else UI.Colors.Dark, Parent = card })
		claim.MouseButton1Click:Connect(function()
			if done and not goal.claimed then
				reply(State.request("guildClaim", goal.id))
			end
		end)
	end
end

local function renderRanking(page)
	local result = State.request("guildRanking")
	UI.clear(page)
	text(page, { Text = "Guildas que mais somaram pontos nesta semana (abates, chefes, masmorras, segredos...).", Size = UDim2.new(1, 0, 0, 30), TextColor3 = UI.Colors.SubText })
	if not result or not result.ok then
		text(page, { Text = result and result.msg or "Ranking indisponível.", Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 0, 30), TextColor3 = UI.Colors.SubText })
		return
	end
	for i, entry in result.list do
		local row = UI.new("Frame", { Position = UDim2.fromOffset(0, 36 + (i - 1) * 34), Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = if i <= 3 then Color3.fromRGB(70, 60, 25) else UI.Colors.PanelLight, Parent = page }, { UI.corner(6) })
		text(row, { Text = ("%d."):format(entry.position), Position = UDim2.fromOffset(8, 6), Size = UDim2.fromOffset(30, 18), Font = Enum.Font.GothamBlack, TextColor3 = UI.Colors.Gold })
		UI.icon(entry.icon or "crossed-swords", { Position = UDim2.fromOffset(40, 3), Size = UDim2.fromOffset(24, 24), Parent = row })
		text(row, { Text = ("[%s] %s"):format(entry.tag, entry.name), Position = UDim2.fromOffset(72, 6), Size = UDim2.new(1, -200, 0, 18) })
		text(row, { Text = ("%s pts"):format(UI.formatNumber(entry.points)), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 6), Size = UDim2.fromOffset(120, 18), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = UI.Colors.Gold })
	end
end

function GuildWindow.render()
	if not win or not win:isOpen() then
		return
	end
	local info = State.data and State.data.guild
	local guild = info and info.guild
	local tab = win.tab
	if tab == "Ranking" then
		return -- só recarrega ao abrir a aba
	end
	-- evita redesenhar à toa (assinatura do que aparece)
	local keyParts = { tab, emblemChoice, tostring(info and info.invite and info.invite.name) }
	if guild then
		table.insert(keyParts, ("%s|%d|%d|%s|%d"):format(guild.id, guild.xp, guild.bank, guild.rank or "", #guild.log))
		for _, member in guild.members do
			table.insert(keyParts, ("%d:%s:%s"):format(member.id, member.rank, tostring(member.online)))
		end
		for _, goal in guild.goals do
			table.insert(keyParts, ("%s:%d:%s"):format(goal.id, goal.progress, tostring(goal.claimed)))
		end
	end
	local key = table.concat(keyParts, ";")
	if key == lastKey then
		return
	end
	lastKey = key
	local page = pages[tab]
	UI.clear(page)
	if tab == "Guilda" then
		if guild then
			renderGuild(page, guild)
		else
			renderCreate(page, info)
		end
	elseif tab == "Banco" then
		renderBank(page, guild)
	elseif tab == "Metas" then
		renderGoals(page, guild)
	end
end

function GuildWindow.open()
	win:open()
end

function GuildWindow.toggle()
	win:toggle()
end

-- convite recebido
function GuildWindow.invite(notification)
	inviteText.Text = ("%s chamou você para a guilda [%s] %s"):format(notification.from or "Alguém", notification.tag or "?", notification.name or "")
	invitePanel.Visible = true
	Sounds.play("ping", 1.3, 0.6)
	task.delay(55, function()
		invitePanel.Visible = false
	end)
end

-- mensagem do chat da guilda (já filtrada pelo servidor)
function GuildWindow.chat(notification)
	local function escape(value)
		return (string.gsub(string.gsub(string.gsub(tostring(value or ""), "&", "&amp;"), "<", "&lt;"), ">", "&gt;"))
	end
	pcall(function()
		local channels = TextChatService:FindFirstChild("TextChannels")
		local general = channels and channels:FindFirstChild("RBXGeneral")
		if general then
			general:DisplaySystemMessage(('<font color="#FFCF5A">[Guilda] %s:</font> %s'):format(escape(notification.from), escape(notification.text)))
		end
	end)
end

local function setupChat()
	pcall(function()
		local command = Instance.new("TextChatCommand")
		command.Name = "ComandoGuilda"
		command.PrimaryAlias = "/gu"
		command.SecondaryAlias = "/guilda"
		command.Parent = TextChatService
		command.Triggered:Connect(function(_source, message)
			local body = string.gsub(message, "^%S+%s*", "")
			if body ~= "" then
				local result = State.request("guildChat", body)
				if result and not result.ok then
					Popups.message(result.msg or "Não deu para enviar.", UI.Colors.SubText)
				end
			end
		end)
	end)
end

function GuildWindow.init(screen)
	win = Window.create(screen, { icon = "eagle-emblem", name = "Guilda", title = "GUILDA", width = 820, height = 560, tabs = { "Guilda", "Banco", "Metas", "Ranking" }, accent = Color3.fromRGB(210, 170, 70) })
	for _, name in { "Guilda", "Banco", "Metas", "Ranking" } do
		pages[name] = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = win.content })
	end
	win.onTab = function(name)
		for tabName, page in pages do
			page.Visible = tabName == name
		end
		lastKey = nil
		if name == "Ranking" then
			renderRanking(pages.Ranking)
		else
			GuildWindow.render()
		end
	end
	win.onOpen = function()
		win.onTab(win.tab)
	end
	State.Changed:Connect(GuildWindow.render)

	invitePanel = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 370), Size = UDim2.fromOffset(420, 96), BackgroundColor3 = UI.Colors.Panel, Visible = false, Parent = screen }, { UI.corner(12) })
	UI.ornate(invitePanel, UI.Colors.Trim, 4)
	inviteText = UI.label({ Text = "", Position = UDim2.fromOffset(12, 10), Size = UDim2.new(1, -24, 0, 26), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = UI.Colors.Gold, Parent = invitePanel }, { UI.textStroke(1) })
	local accept = UI.button({ Text = "Entrar na guilda", Position = UDim2.new(0, 14, 1, -46), Size = UDim2.new(0.5, -20, 0, 36), BackgroundColor3 = UI.Colors.Green, Parent = invitePanel })
	accept.MouseButton1Click:Connect(function()
		invitePanel.Visible = false
		reply(State.request("guildRespond", true))
	end)
	local decline = UI.button({ Text = "Recusar", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 1, -46), Size = UDim2.new(0.5, -20, 0, 36), BackgroundColor3 = Color3.fromRGB(150, 50, 50), Parent = invitePanel })
	decline.MouseButton1Click:Connect(function()
		invitePanel.Visible = false
		State.request("guildRespond", false)
	end)
	setupChat()
end

return GuildWindow
