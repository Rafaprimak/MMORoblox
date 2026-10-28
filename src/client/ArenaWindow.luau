-- Arena PvP (botão "Arena" no menu): fila dos modos, divisão e pontos da temporada, ranking e histórico.
-- Durante a luta: placar no topo (vida de cada caçador dos dois times, rodada, tempo) e "Desistir".
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Arena = require(Shared.Arena)
local Seasons = require(Shared.Seasons)

local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Window = require(script.Parent.Window)
local Sounds = require(script.Parent.Sounds)

local ArenaWindow = {}

local win
local pages = {}
local lastKey = nil
local rankingList = nil
local board, boardScore, boardInfo, boardTeams

local GOLD = Color3.fromRGB(255, 205, 90)
local TEAM_COLORS = { Color3.fromRGB(70, 140, 255), Color3.fromRGB(255, 80, 70) }

local function text(parent, props)
	local merged = { TextScaled = false, TextSize = 14, TextWrapped = true, Font = Enum.Font.GothamBold }
	for k, v in props do
		merged[k] = v
	end
	merged.Parent = parent
	return UI.label(merged)
end

local function renderFight(page, arena)
	local season = Seasons.info(os.time())
	local division, index = Arena.division(arena.rating)
	local nextDivision = Arena.Divisions[index + 1]
	-- cartão da divisão
	local card = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 120), BackgroundColor3 = UI.Colors.PanelLight, Parent = page }, { UI.corner(10), UI.stroke(division.color, 2, 0.3) })
	UI.icon("laurel-crown", { Position = UDim2.fromOffset(14, 14), Size = UDim2.fromOffset(84, 84), Color = division.color, Parent = card })
	text(card, { Text = division.name, Position = UDim2.fromOffset(110, 8), Size = UDim2.new(0.5, -110, 0, 32), TextSize = 26, FontFace = UI.TitleFont, TextColor3 = division.color })
	text(card, { Text = ("%d pontos  •  melhor %d  •  %d V / %d D"):format(arena.rating, arena.best, arena.wins, arena.losses), Position = UDim2.fromOffset(110, 42), Size = UDim2.new(1, -120, 0, 18) })
	if nextDivision then
		local _, fill, label = UI.bar(card, { Position = UDim2.fromOffset(110, 66), Size = UDim2.new(1, -124, 0, 16), color = nextDivision.color })
		UI.setBar(fill, (arena.rating - division.rating) / math.max(nextDivision.rating - division.rating, 1))
		label.Text = ("%d / %d para %s"):format(arena.rating, nextDivision.rating, nextDivision.name)
	end
	text(card, { Text = ("%s  •  termina em %s  •  a pontuação recomeça a cada temporada"):format(season.name, UI.formatTime(season.endsIn)), Position = UDim2.fromOffset(110, 90), Size = UDim2.new(1, -120, 0, 18), TextSize = 12, TextColor3 = season.color })
	-- modos
	for i, modeId in Arena.ModeOrder do
		local mode = Arena.Modes[modeId]
		local queued = arena.queued == modeId
		local box = UI.new("Frame", { Position = UDim2.new((i - 1) * 0.5, if i == 1 then 0 else 6, 0, 132), Size = UDim2.new(0.5, -6, 0, 150), BackgroundColor3 = UI.Colors.PanelLight, Parent = page }, { UI.corner(10), UI.stroke(if queued then GOLD else UI.Colors.Stroke, if queued then 2 else 1, 0.3) })
		UI.icon(mode.icon, { Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(40, 40), Color = GOLD, Parent = box })
		text(box, { Text = mode.name, Position = UDim2.fromOffset(60, 10), Size = UDim2.new(1, -70, 0, 22), TextSize = 18, FontFace = UI.TitleFont, TextColor3 = GOLD })
		text(box, { Text = ("%d na fila"):format((arena.queues or {})[modeId] or 0), Position = UDim2.fromOffset(60, 32), Size = UDim2.new(1, -70, 0, 16), TextSize = 12, TextColor3 = UI.Colors.SubText })
		text(box, { Text = mode.text, Position = UDim2.fromOffset(12, 58), Size = UDim2.new(1, -24, 0, 36), TextSize = 12, TextColor3 = UI.Colors.SubText })
		local button = UI.button({ Text = if queued then ("Sair da fila (%s)"):format(UI.formatTime(arena.waiting or 0)) else "Entrar na fila", Position = UDim2.new(0, 12, 1, -46), Size = UDim2.new(1, -24, 0, 36), BackgroundColor3 = if queued then Color3.fromRGB(150, 60, 60) else Color3.fromRGB(200, 140, 40), Parent = box })
		button.MouseButton1Click:Connect(function()
			if queued then
				State.request("arenaLeave")
			else
				State.request("arenaJoin", modeId)
				Sounds.play("ping", 1.2, 0.5)
			end
		end)
	end
	-- divisões e títulos
	text(page, { Text = "DIVISÕES (cada uma dá um título para sempre)", Position = UDim2.fromOffset(0, 294), Size = UDim2.new(1, 0, 0, 18), TextColor3 = GOLD, Font = Enum.Font.GothamBlack })
	local row = UI.new("Frame", { Position = UDim2.fromOffset(0, 316), Size = UDim2.new(1, 0, 0, 56), BackgroundTransparency = 1, Parent = page }, { UI.list(6, true) })
	for i, entry in Arena.Divisions do
		local reached = arena.best >= entry.rating
		local chip = UI.new("Frame", { Size = UDim2.new(1 / #Arena.Divisions, -6, 1, 0), BackgroundColor3 = UI.Colors.PanelLight, LayoutOrder = i, Parent = row }, { UI.corner(8), UI.stroke(entry.color, 1.5, if reached then 0.1 else 0.7) })
		text(chip, { Text = entry.name, Position = UDim2.fromOffset(4, 6), Size = UDim2.new(1, -8, 0, 18), TextSize = 14, TextColor3 = if reached then entry.color else UI.Colors.SubText, TextXAlignment = Enum.TextXAlignment.Center })
		text(chip, { Text = ("%d+"):format(entry.rating), Position = UDim2.fromOffset(4, 28), Size = UDim2.new(1, -8, 0, 16), TextSize = 12, TextColor3 = UI.Colors.SubText, TextXAlignment = Enum.TextXAlignment.Center })
	end
	text(page, { Text = ("Regras: dano entre jogadores reduzido, sem poções, curas valem metade. Vitória: +%d ouro. Derrota: +%d ouro. Nível mínimo %d."):format(Arena.Rewards.win.gold, Arena.Rewards.loss.gold, Arena.MinLevel), Position = UDim2.fromOffset(0, 382), Size = UDim2.new(1, 0, 0, 34), TextSize = 12, TextColor3 = UI.Colors.SubText })
end

local function renderRanking(page)
	if rankingList == nil then
		text(page, { Text = "Carregando...", Size = UDim2.new(1, 0, 0, 20), TextColor3 = UI.Colors.SubText })
		task.spawn(function()
			local result = State.request("arenaRanking")
			rankingList = if result and result.ok then result.list else { error = if result then result.msg else "Ranking indisponível." }
			lastKey = nil
			ArenaWindow.render()
		end)
		return
	end
	if rankingList.error then
		text(page, { Text = rankingList.error, Size = UDim2.new(1, 0, 0, 20), TextColor3 = UI.Colors.SubText })
		return
	end
	text(page, { Text = ("TOP 20  •  %s"):format(Seasons.info(os.time()).name), Size = UDim2.new(1, 0, 0, 20), TextColor3 = GOLD, Font = Enum.Font.GothamBlack })
	local scroll = UI.new("ScrollingFrame", { Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 1, -26), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = page }, { UI.list(4) })
	if #rankingList == 0 then
		text(scroll, { Text = "Ninguém lutou nesta temporada ainda. Seja o primeiro!", Size = UDim2.new(1, 0, 0, 20), TextColor3 = UI.Colors.SubText })
	end
	for _, entry in rankingList do
		local division = Arena.division(entry.rating)
		local line = UI.new("Frame", { Size = UDim2.new(1, -8, 0, 30), BackgroundColor3 = UI.Colors.PanelLight, LayoutOrder = entry.position, Parent = scroll }, { UI.corner(6) })
		text(line, { Text = ("%d."):format(entry.position), Position = UDim2.fromOffset(10, 0), Size = UDim2.new(0, 40, 1, 0), TextColor3 = if entry.position <= 3 then GOLD else UI.Colors.Text })
		text(line, { Text = entry.name, Position = UDim2.fromOffset(50, 0), Size = UDim2.new(0.5, -50, 1, 0) })
		text(line, { Text = division.name, Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0.25, 0, 1, 0), TextColor3 = division.color })
		text(line, { Text = ("%d pts"):format(entry.rating), Position = UDim2.new(0.75, 0, 0, 0), Size = UDim2.new(0.25, -10, 1, 0), TextXAlignment = Enum.TextXAlignment.Right })
	end
end

local function renderHistory(page, arena)
	if #arena.history == 0 then
		text(page, { Text = "Nenhuma luta nesta temporada ainda.", Size = UDim2.new(1, 0, 0, 20), TextColor3 = UI.Colors.SubText })
		return
	end
	for i, entry in arena.history do
		local line = UI.new("Frame", { Position = UDim2.fromOffset(0, (i - 1) * 36), Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = UI.Colors.PanelLight, Parent = page }, { UI.corner(6), UI.stroke(if entry.won then Color3.fromRGB(90, 200, 110) else Color3.fromRGB(200, 90, 90), 1, 0.5) })
		text(line, { Text = if entry.won then "VITÓRIA" else "DERROTA", Position = UDim2.fromOffset(10, 0), Size = UDim2.new(0, 90, 1, 0), TextColor3 = if entry.won then Color3.fromRGB(110, 230, 130) else Color3.fromRGB(230, 110, 110) })
		text(line, { Text = (Arena.Modes[entry.mode] or { name = "?" }).name, Position = UDim2.fromOffset(110, 0), Size = UDim2.new(0.3, 0, 1, 0) })
		text(line, { Text = entry.score or "", Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0.2, 0, 1, 0), TextColor3 = UI.Colors.SubText })
		text(line, { Text = ("%s%d"):format(if entry.delta >= 0 then "+" else "", entry.delta), Position = UDim2.new(0.75, 0, 0, 0), Size = UDim2.new(0.25, -10, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = if entry.delta >= 0 then Color3.fromRGB(110, 230, 130) else Color3.fromRGB(230, 110, 110) })
	end
end

function ArenaWindow.render()
	if not win or not win:isOpen() then
		return
	end
	local arena = State.data and State.data.arena
	if not arena then
		return
	end
	local key = table.concat({ win.tab, arena.rating, arena.wins, arena.losses, tostring(arena.queued), tostring(arena.waiting), (arena.queues or {}).duelo or 0, (arena.queues or {}).equipes or 0, tostring(rankingList ~= nil) }, "|")
	if key == lastKey then
		return
	end
	lastKey = key
	local page = pages[win.tab]
	UI.clear(page)
	if win.tab == "Lutar" then
		renderFight(page, arena)
	elseif win.tab == "Ranking" then
		renderRanking(page)
	else
		renderHistory(page, arena)
	end
end

-- placar durante a luta
local function updateBoard()
	local arena = State.data and State.data.arena
	local match = arena and arena.match
	board.Visible = match ~= nil
	if not match then
		return
	end
	if win:isOpen() then
		win:close()
	end
	boardScore.Text = ("%d  x  %d"):format(match.score[1], match.score[2])
	local info
	if match.state == "countdown" then
		info = ("Rodada %d  •  começa em %d"):format(match.round, match.startsIn or 0)
	elseif match.state == "live" then
		info = ("Rodada %d  •  %s"):format(match.round, UI.formatTime(match.endsIn or 0))
	else
		info = ("Rodada %d  •  fim"):format(match.round)
	end
	boardInfo.Text = info
	for index, holder in boardTeams do
		local members = match.teams[index] or {}
		local signature = {}
		for _, member in members do
			table.insert(signature, member.name)
		end
		local key = table.concat(signature, ",")
		if holder:GetAttribute("Chave") ~= key then
			holder:SetAttribute("Chave", key)
			UI.clear(holder)
			for i, member in members do
				local row = UI.new("Frame", { Name = "M" .. i, Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, LayoutOrder = i, Parent = holder })
				UI.label({ Name = "Nome", Text = member.name, Size = UDim2.new(0.45, 0, 1, 0), TextSize = 12, TextScaled = false, TextColor3 = TEAM_COLORS[index], TextXAlignment = if index == 1 then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right, Position = UDim2.fromScale(if index == 1 then 0 else 0.55, 0), Parent = row }, { UI.textStroke(1) })
				local _, fill = UI.bar(row, { Position = UDim2.new(if index == 1 then 0.47 else 0, 0, 0, 3), Size = UDim2.new(0.53, 0, 0, 12), color = TEAM_COLORS[index], text = false })
				fill.Name = "Fill"
			end
		end
		for i, member in members do
			local row = holder:FindFirstChild("M" .. i)
			local fill = row and row:FindFirstChild("Fill", true)
			if fill then
				UI.setBar(fill, member.hp / 100, true)
			end
			local name = row and row:FindFirstChild("Nome")
			if name then
				name.TextTransparency = if member.down then 0.6 else 0
			end
		end
	end
end

function ArenaWindow.toggle()
	if win:isOpen() then
		win:close()
	else
		rankingList = nil
		lastKey = nil
		win:open()
	end
end

function ArenaWindow.init(screen)
	win = Window.create(screen, { icon = "crossed-swords", name = "Arena", title = "ARENA: " .. string.upper(Arena.Name), width = 780, height = 520, tabs = { "Lutar", "Ranking", "Histórico" }, accent = GOLD })
	for _, name in { "Lutar", "Ranking", "Histórico" } do
		pages[name] = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = win.content })
	end
	win.onTab = function(name)
		for tabName, page in pages do
			page.Visible = tabName == name
		end
		lastKey = nil
		ArenaWindow.render()
	end
	win.onOpen = function()
		win.onTab(win.tab)
	end
	-- placar no topo
	board = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 96), Size = UDim2.fromOffset(560, 96), BackgroundColor3 = Color3.fromRGB(20, 18, 30), BackgroundTransparency = 0.15, Visible = false, Parent = screen }, { UI.corner(10), UI.stroke(GOLD, 2, 0.3) })
	boardScore = UI.label({ Text = "0 x 0", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4), Size = UDim2.fromOffset(120, 34), TextXAlignment = Enum.TextXAlignment.Center, FontFace = UI.TitleFont, TextColor3 = GOLD, Parent = board }, { UI.textStroke(2) })
	boardInfo = UI.label({ Text = "", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 40), Size = UDim2.fromOffset(150, 16), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = UI.Colors.SubText, Parent = board })
	boardTeams = {}
	for index = 1, 2 do
		boardTeams[index] = UI.new("Frame", { Position = UDim2.new(if index == 1 then 0 else 0.5, if index == 1 then 10 else 70, 0, 8), Size = UDim2.new(0.5, -80, 1, -16), BackgroundTransparency = 1, Parent = board }, { UI.list(4) })
	end
	local forfeit = UI.button({ Text = "Desistir", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.fromOffset(100, 24), BackgroundColor3 = Color3.fromRGB(150, 50, 50), Parent = board })
	forfeit.MouseButton1Click:Connect(function()
		State.request("arenaForfeit")
	end)
	State.Changed:Connect(function()
		ArenaWindow.render()
		updateBoard()
	end)
end

return ArenaWindow
