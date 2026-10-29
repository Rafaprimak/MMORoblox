-- Conversa com NPCs: missões disponíveis, entregas e serviços (forja, loja...).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NPCs = require(Shared.NPCs)
local Quests = require(Shared.Quests)
local Items = require(Shared.Items)

local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Window = require(script.Parent.Window)
local Sounds = require(script.Parent.Sounds)

local Dialog = {}

-- preenchido pelo init: { forge = fn, enchant = fn, ... }
Dialog.services = {}

local win, text, options
local currentNpc = nil

local SERVICE_LABELS = {
	forge = "Forja (criar e aprimorar)",
	enchant = "Encantar e desmontar",
	alchemy = "Alquimia (poções)",
	shop = "Loja",
	chest = "Baús do Hunter",
	pets = "Ovos de Pet",
	classes = "Classes",
	stable = "Montaria",
	dungeon = "Mercado das Masmorras",
	fusion = "Fusão de equipamentos (9 em 1)",
	market = "Mercado dos Caçadores (leilão entre servidores)",
	guild = "Guildas (fundar e gerenciar)",
}
local SERVICE_ICONS = {
	forge = "anvil-impact",
	enchant = "sparkles",
	alchemy = "bubbling-flask",
	shop = "shopping-cart",
	chest = "present",
	pets = "egg-clutch",
	classes = "wizard-face",
	stable = "horse-head",
	dungeon = "castle",
	fusion = "round-bottom-flask",
	market = "scales",
	guild = "eagle-emblem",
}

local function objectiveText(objective)
	local extra = ""
	if objective.type == "deliver" then
		extra = (" (você tem %d)"):format(State.materialCount(objective.item))
	end
	return "• " .. objective.text .. (if objective.amount > 1 then (" x%d"):format(objective.amount) else "") .. extra
end

local function option(label, color, order, callback, icon)
	local button = UI.button({ Text = label, Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = color or UI.Colors.PanelLight, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = order, Parent = options })
	button.MouseButton1Click:Connect(callback)
	if icon then
		local pad = button:FindFirstChildOfClass("UIPadding") or UI.new("UIPadding", { Parent = button })
		pad.PaddingLeft = UDim.new(0, 36)
		UI.icon(icon, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -30, 0.5, 0), Size = UDim2.fromOffset(24, 24), ZIndex = button.ZIndex + 1, Parent = button })
	end
	return button
end

local showMain

local function showQuest(qid)
	local def = Quests.ById[qid]
	if not def then
		return
	end
	UI.clear(options)
	local lines = { def.text, "" }
	for _, objective in def.objectives do
		table.insert(lines, objectiveText(objective))
	end
	table.insert(lines, "")
	table.insert(lines, "Recompensa: " .. Quests.rewardText(def.reward))
	text.Text = def.name .. "\n\n" .. table.concat(lines, "\n")
	text:SetAttribute("LendoMissao", true)
	option("Aceitar missão", UI.Colors.Green, 1, function()
		local result = State.request("acceptQuest", qid)
		if result and result.ok then
			Sounds.play("ping", 1.4, 0.5)
			showMain()
		end
	end)
	option("Voltar", nil, 2, showMain)
end

function showMain()
	local npc = currentNpc and NPCs.ById[currentNpc]
	if not npc then
		return
	end
	UI.clear(options)
	text.Text = npc.greeting or "..."
	text:SetAttribute("LendoMissao", false)
	local data = State.data
	local order = 1
	if data and data.quests then
		-- entregas
		for _, entry in data.quests.active do
			local def = Quests.ById[entry.id]
			if def and entry.ready and def.turnIn == currentNpc then
				option("? Entregar: " .. def.name, Color3.fromRGB(60, 140, 70), order, function()
					local result = State.request("turnInQuest", entry.id)
					if result and result.ok then
						Sounds.play("ping", 1.6, 0.6)
						showMain()
					end
				end)
				order += 1
			end
		end
		-- novas missões
		for _, qid in (data.quests.available and data.quests.available[currentNpc] or {}) do
			local def = Quests.ById[qid]
			if def then
				option("! " .. def.name .. (if def.daily then " (contrato)" else ""), Color3.fromRGB(150, 120, 40), order, function()
					showQuest(qid)
				end)
				order += 1
			end
		end
	end
	for _, service in npc.services or {} do
		if SERVICE_LABELS[service] and Dialog.services[service] then
			option(SERVICE_LABELS[service], UI.Colors.Accent, order, function()
				Dialog.services[service](currentNpc)
			end, SERVICE_ICONS[service])
			order += 1
		end
	end
	-- Ulf (Contratos da Guilda): só com guilda
	if npc.guildBoard and data and data.quests then
		local daily = data.quests.daily
		local offered = daily.guildOffered or {}
		local doneCount = 0
		for _, qid in offered do
			if daily.done[qid] then
				doneCount += 1
			end
		end
		local inGuild = data.guild and data.guild.guild
		text.Text = if inGuild
			then ("%s\n\nContratos da guilda de hoje: %d/%d  •  Renovam em %s"):format(npc.greeting, doneCount, #offered, UI.formatTime(daily.resetIn))
			else npc.greeting .. "\n\nVocê ainda não tem guilda. Fale com a Helena aqui do lado para fundar uma, ou peça um convite a quem já tem."
	end
	if npc.board and data and data.quests then
		local daily = data.quests.daily
		local doneCount = 0
		for _ in daily.done do
			doneCount += 1
		end
		text.Text = ("%s\n\nContratos de hoje concluídos: %d/%d  •  Renovam em %s\nBônus por completar todos: %s"):format(npc.greeting, doneCount, #daily.offered, UI.formatTime(daily.resetIn), Quests.rewardText(Quests.DailyBonus))
	end
	option("Tchau", UI.Colors.Dark, 99, function()
		win:close()
	end)
end

function Dialog.init(screen)
	win = Window.create(screen, { name = "Dialogo", title = "", width = 560, height = 460, accent = UI.Colors.Gold })
	text = UI.label({
		Text = "",
		Size = UDim2.new(1, 0, 0, 200),
		TextScaled = false,
		TextSize = 17,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Font = Enum.Font.Gotham,
		Parent = win.content,
	})
	options = UI.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 206),
		Size = UDim2.new(1, 0, 1, -206),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = win.content,
	}, { UI.list(6) })
	State.Changed:Connect(function()
		if win:isOpen() and currentNpc then
			-- atualiza só a tela principal (não interrompe quem está lendo uma missão)
			if not text:GetAttribute("LendoMissao") then
				showMain()
			end
		end
	end)
end

function Dialog.open(npcId)
	local npc = NPCs.ById[npcId]
	if not npc then
		return
	end
	currentNpc = npcId
	win.title.Text = ("%s — %s"):format(npc.name, npc.title)
	win:open()
	showMain()
	State.action("talk", npcId)
end

-- usado por outras janelas
Dialog.materialName = function(id)
	local def = Items.Materials[id]
	return if def then def.name else id
end

return Dialog
