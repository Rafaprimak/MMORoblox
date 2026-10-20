-- Diário de missões: ativas, detalhes, rastrear, abandonar e contratos do dia.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Quests = require(Shared.Quests)
local NPCs = require(Shared.NPCs)

local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Window = require(script.Parent.Window)

local QuestLog = {}

local win, listFrame, detail
local selected = nil
local abandonConfirm = false

local function npcName(id)
	local npc = id and NPCs.ById[id]
	return if npc then npc.name else "—"
end

local function renderDetail(data)
	UI.clear(detail)
	local entry = nil
	for _, e in data.quests.active do
		if e.id == selected then
			entry = e
		end
	end
	local def = selected and Quests.ById[selected]
	if not entry or not def then
		UI.label({ Text = "Selecione uma missão.\n\nNPCs com ❗ têm missões novas. ❓ significa que você pode entregar.", Size = UDim2.new(1, 0, 0, 120), TextScaled = false, TextSize = 16, TextWrapped = true, TextColor3 = UI.Colors.SubText, Parent = detail })
		return
	end
	local lines = { def.text, "" }
	for i, objective in def.objectives do
		local progress = entry.objectives[i]
		local done = progress.progress >= progress.amount
		table.insert(lines, (if done then "✅ " else "⬜ ") .. objective.text .. (if progress.amount > 1 then ("  (%d/%d)"):format(progress.progress, progress.amount) else ""))
	end
	table.insert(lines, "")
	table.insert(lines, "Entregar para: " .. (if def.turnIn then npcName(def.turnIn) else "automático"))
	table.insert(lines, "Recompensa: " .. Quests.rewardText(def.reward))
	if entry.ready then
		table.insert(lines, "")
		table.insert(lines, "❗ Tudo pronto! Fale com " .. npcName(def.turnIn) .. ".")
	end
	UI.label({ Text = def.name, Size = UDim2.new(1, 0, 0, 26), Font = Enum.Font.GothamBlack, TextColor3 = UI.Colors.Gold, Parent = detail }, { UI.textStroke(1) })
	UI.label({ Text = table.concat(lines, "\n"), Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 1, -80), TextScaled = false, TextSize = 16, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Font = Enum.Font.Gotham, Parent = detail })
	local track = UI.button({ Text = if data.quests.tracked == selected then "📍 RASTREANDO" else "📍 RASTREAR", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(0.5, -4, 0, 38), BackgroundColor3 = UI.Colors.Accent, Parent = detail })
	track.MouseButton1Click:Connect(function()
		State.request("trackQuest", selected)
	end)
	local abandon = UI.button({ Text = "Abandonar", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 1, 0), Size = UDim2.new(0.5, -4, 0, 38), BackgroundColor3 = Color3.fromRGB(120, 55, 55), Parent = detail })
	abandon.MouseButton1Click:Connect(function()
		if not abandonConfirm then
			abandonConfirm = true
			abandon.Text = "Confirmar?"
			task.delay(3, function()
				abandonConfirm = false
			end)
			return
		end
		abandonConfirm = false
		State.request("abandonQuest", selected)
		selected = nil
	end)
end

local function render()
	local data = State.data
	if not data or not data.quests then
		return
	end
	UI.clear(listFrame)
	local order = 0
	local function header(text, color)
		order += 1
		UI.label({ Text = text, Size = UDim2.new(1, -8, 0, 22), TextColor3 = color, Font = Enum.Font.GothamBlack, LayoutOrder = order, Parent = listFrame })
	end
	header("ATIVAS", UI.Colors.Gold)
	if not selected and data.quests.active[1] then
		selected = data.quests.tracked or data.quests.active[1].id
	end
	for _, entry in data.quests.active do
		local def = Quests.ById[entry.id]
		if def then
			order += 1
			local isSelected = entry.id == selected
			local button = UI.button({
				Text = (if entry.ready then "❗ " elseif entry.id == data.quests.tracked then "📍 " else "") .. def.name,
				Size = UDim2.new(1, -8, 0, 32),
				LayoutOrder = order,
				TextXAlignment = Enum.TextXAlignment.Left,
				BackgroundColor3 = if isSelected then UI.Colors.Accent else UI.Colors.PanelLight,
				Parent = listFrame,
			})
			button.MouseButton1Click:Connect(function()
				selected = entry.id
				render()
			end)
		end
	end
	if #data.quests.active == 0 then
		order += 1
		UI.label({ Text = "Nenhuma. Procure NPCs com ❗", Size = UDim2.new(1, -8, 0, 18), TextColor3 = UI.Colors.SubText, LayoutOrder = order, Parent = listFrame })
	end
	local daily = data.quests.daily
	header(("CONTRATOS DO DIA  (renovam em %s)"):format(UI.formatTime(daily.resetIn)), UI.Colors.Xp)
	for _, qid in daily.offered do
		local def = Quests.ById[qid]
		if def then
			order += 1
			local status = if daily.done[qid] then "✅ " else "◦ "
			UI.label({ Text = status .. def.name, Size = UDim2.new(1, -8, 0, 18), TextColor3 = if daily.done[qid] then UI.Colors.Green else UI.Colors.SubText, LayoutOrder = order, Parent = listFrame })
		end
	end
	order += 1
	UI.label({ Text = if daily.bonusClaimed then "✅ Bônus do dia recebido" else "Pegue no Quadro de Recompensas da vila", Size = UDim2.new(1, -8, 0, 16), TextColor3 = UI.Colors.SubText, Font = Enum.Font.Gotham, LayoutOrder = order, Parent = listFrame })
	renderDetail(data)
end

function QuestLog.init(screen)
	win = Window.create(screen, { name = "Missoes", title = "📜 DIÁRIO DE MISSÕES", width = 720, height = 480, accent = UI.Colors.Gold })
	listFrame = UI.new("ScrollingFrame", { Size = UDim2.new(0, 270, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 5, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = win.content }, { UI.list(5) })
	detail = UI.new("Frame", { Position = UDim2.fromOffset(282, 0), Size = UDim2.new(1, -282, 1, 0), BackgroundColor3 = UI.Colors.PanelLight, BackgroundTransparency = 0.3, Parent = win.content }, { UI.corner(10), UI.padding(12) })
	win.onOpen = render
	State.Changed:Connect(function()
		if win:isOpen() then
			render()
		end
	end)
end

function QuestLog.toggle()
	win:toggle()
end

return QuestLog
