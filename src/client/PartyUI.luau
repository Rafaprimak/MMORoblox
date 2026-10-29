-- Grupo (party) no cliente:
--   * botão "Convidar para o grupo" (tecla T) em cima dos outros jogadores (o E é da troca);
--   * painel de convite recebido (Entrar / Recusar);
--   * quadros dos colegas à esquerda: ícone da classe, nome, nível, vida ao vivo, distância e coroa do
--     líder; o líder tira alguém pelo X; botão "Sair do grupo";
--   * nome verde em cima dos colegas no mundo e pontos verdes no mapa (MapWindow usa PartyUI.members);
--   * chat do grupo: /g mensagem (ou /grupo), com a marca [Grupo] nas mensagens;
--   * "Procurar grupo": janela com a lista de quem está procurando (convidar com um clique) e o botão
--     para entrar na lista com um recado curto.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Classes = require(Shared.Classes)

local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Sounds = require(script.Parent.Sounds)
local Popups = require(script.Parent.Popups)
local Window = require(script.Parent.Window)

local PartyUI = {}

local player = Players.LocalPlayer

local list, leaveButton, invitePanel, inviteText
local pendingInvite = nil
local current = nil -- payload `party` atual
local frames = {} -- [userId] = { frame, fill, distance }
local tags = {} -- [userId] = BillboardGui em cima do colega
local signature = ""
local lfg = {} -- janela "Procurar grupo"

-- colegas atuais (sem o próprio jogador), para o mapa
function PartyUI.members()
	local result = {}
	if current then
		for _, member in current.members do
			if member.id ~= player.UserId then
				local other = Players:GetPlayerByUserId(member.id)
				if other then
					table.insert(result, { player = other, name = member.name, leader = member.id == current.leader })
				end
			end
		end
	end
	return result
end

local function rootOf(other)
	local character = other and other.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

-- nome verde em cima do colega
local function setTag(other, enabled)
	local existing = tags[other.UserId]
	if not enabled then
		if existing then
			existing:Destroy()
			tags[other.UserId] = nil
		end
		return
	end
	local character = other.Character
	local head = character and character:FindFirstChild("Head")
	if not head or (existing and existing.Parent == head) then
		return
	end
	if existing then
		existing:Destroy()
	end
	local gui = UI.new("BillboardGui", { Name = "TagGrupo", Size = UDim2.fromOffset(160, 22), StudsOffset = Vector3.new(0, 3.2, 0), AlwaysOnTop = true, MaxDistance = 400, LightInfluence = 0, Adornee = head, Parent = head })
	UI.label({ Text = "• " .. other.DisplayName, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Color3.fromRGB(120, 235, 140), Font = Enum.Font.GothamBlack, Parent = gui }, { UI.textStroke(1.5) })
	tags[other.UserId] = gui
end

local function render()
	local party = current
	local key = ""
	if party then
		key = tostring(party.leader)
		for _, member in party.members do
			key ..= ("|%d:%d:%s"):format(member.id, member.level, member.class)
		end
	end
	if key == signature then
		return
	end
	signature = key
	for _, info in frames do
		info.frame:Destroy()
	end
	frames = {}
	local keep = {}
	leaveButton.Visible = party ~= nil
	if not party then
		for userId, gui in tags do
			gui:Destroy()
			tags[userId] = nil
		end
		return
	end
	local amLeader = party.leader == player.UserId
	for order, member in party.members do
		if member.id ~= player.UserId then
			local class = Classes.List[member.class]
			local frame = UI.new("Frame", { Size = UDim2.fromOffset(200, 40), BackgroundColor3 = UI.Colors.Panel, BackgroundTransparency = 0.15, LayoutOrder = order, Parent = list }, { UI.corner(8), UI.stroke(Color3.fromRGB(90, 160, 100), 1.5) })
			UI.icon(class and class.icon or "person", { Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(32, 32), Color = class and class.color or UI.Colors.Icon, Parent = frame })
			UI.label({ Text = ("%s  •  Nv. %d"):format(member.name, member.level), Position = UDim2.fromOffset(40, 3), Size = UDim2.new(1, -78, 0, 15), Font = Enum.Font.GothamBlack, Parent = frame }, { UI.textStroke(1) })
			local _, fill = UI.bar(frame, { Position = UDim2.fromOffset(40, 21), Size = UDim2.new(1, -78, 0, 12), color = UI.Colors.Health, text = false })
			local distance = UI.label({ Text = "", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 3), Size = UDim2.fromOffset(34, 14), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = UI.Colors.SubText, Parent = frame })
			if member.id == party.leader then
				UI.icon("crown", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 19), Size = UDim2.fromOffset(16, 16), Color = UI.Colors.Gold, Parent = frame })
			elseif amLeader then
				local kick = UI.button({ Text = "X", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 18), Size = UDim2.fromOffset(20, 18), BackgroundColor3 = Color3.fromRGB(150, 40, 45), Parent = frame })
				kick.MouseButton1Click:Connect(function()
					State.request("partyKick", member.id)
				end)
			end
			frames[member.id] = { frame = frame, fill = fill, distance = distance }
			keep[member.id] = true
			local other = Players:GetPlayerByUserId(member.id)
			if other then
				setTag(other, true)
			end
		end
	end
	for userId, gui in tags do
		if not keep[userId] then
			gui:Destroy()
			tags[userId] = nil
		end
	end
end

-- vida e distância ao vivo
local function refreshLive()
	local myRoot = rootOf(player)
	for userId, info in frames do
		local other = Players:GetPlayerByUserId(userId)
		local character = other and other.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = rootOf(other)
		if humanoid then
			UI.setBar(info.fill, humanoid.Health / math.max(humanoid.MaxHealth, 1))
		end
		info.distance.Text = if root and myRoot then ("%dm"):format(math.floor((root.Position - myRoot.Position).Magnitude)) else ""
		if other and not tags[userId] then
			setTag(other, true)
		end
	end
end

-- convite para o grupo (chamado pelo menu do PlayerPrompt, em cima dos outros jogadores)
function PartyUI.inviteTo(other)
	local result = State.request("partyInvite", other.UserId)
	if result and result.ok and result.msg then
		Popups.message(result.msg, UI.Colors.Green)
	end
end

-- true se o jogador já está no meu grupo
function PartyUI.isMember(other)
	return current ~= nil and frames[other.UserId] ~= nil
end

-- nome verde de volta no colega que renasceu
local function addPrompt(other)
	local function onCharacter(character)
		if not character:WaitForChild("Head", 10) then
			return
		end
		if current and frames[other.UserId] then
			setTag(other, true)
		end
	end
	if other.Character then
		task.spawn(onCharacter, other.Character)
	end
	other.CharacterAdded:Connect(onCharacter)
end

-- convite recebido
function PartyUI.invite(notification)
	pendingInvite = notification.fromId
	inviteText.Text = ("%s chamou você para o grupo"):format(notification.from or "Alguém")
	invitePanel.Visible = true
	Sounds.play("ping", 1.3, 0.6)
	local mine = pendingInvite
	task.delay(28, function()
		if pendingInvite == mine then
			pendingInvite = nil
			invitePanel.Visible = false
		end
	end)
end

-- chat do grupo: /g mensagem
local function setupChat()
	local ok = pcall(function()
		local command = Instance.new("TextChatCommand")
		command.Name = "ComandoGrupo"
		command.PrimaryAlias = "/g"
		command.SecondaryAlias = "/grupo"
		command.Parent = TextChatService
		command.Triggered:Connect(function(_source, text)
			local message = string.gsub(text, "^%S+%s*", "")
			local channels = TextChatService:FindFirstChild("TextChannels")
			local channel = current and channels and channels:FindFirstChild("Grupo" .. tostring(current.id))
			if not channel then
				Popups.message("Você não está num grupo. Chegue perto de alguém e aperte T para convidar.", UI.Colors.SubText)
				return
			end
			if message ~= "" then
				channel:SendAsync(message)
			end
		end)
		TextChatService.OnIncomingMessage = function(message)
			local channel = message.TextChannel
			if channel and string.match(channel.Name, "^Grupo%d+$") then
				local properties = Instance.new("TextChatMessageProperties")
				properties.PrefixText = '<font color="#7CE38B">[Grupo]</font> ' .. message.PrefixText
				return properties
			end
			return nil
		end
	end)
	if not ok then
		warn("[Grupo] Chat do grupo indisponível (TextChatService desligado?)")
	end
end

-- ===================== PROCURAR GRUPO =====================

local function renderLooking()
	local result = State.request("partyList")
	if not result or not result.ok then
		return
	end
	UI.clear(lfg.list)
	lfg.mine = result.mine == true
	lfg.toggle.Text = if lfg.mine then "Sair da lista" else "Entrar na lista"
	lfg.toggle.BackgroundColor3 = if lfg.mine then UI.Colors.Dark else UI.Colors.Green
	if #result.list == 0 then
		UI.label({ Text = "Ninguém procurando grupo agora. Entre na lista para aparecer para os outros!", Size = UDim2.new(1, -8, 0, 40), TextWrapped = true, TextScaled = false, TextSize = 15, TextColor3 = UI.Colors.SubText, Parent = lfg.list })
		return
	end
	for order, entry in result.list do
		local class = Classes.List[entry.class]
		local row = UI.new("Frame", { Size = UDim2.new(1, -8, 0, 46), BackgroundColor3 = UI.Colors.PanelLight, LayoutOrder = order, Parent = lfg.list }, { UI.corner(8) })
		UI.icon(class and class.icon or "person", { Position = UDim2.fromOffset(6, 7), Size = UDim2.fromOffset(32, 32), Color = class and class.color or UI.Colors.Icon, Parent = row })
		UI.label({ Text = ("%s  •  Nv. %d  •  %s"):format(entry.name, entry.level, class and class.name or "?"), Position = UDim2.fromOffset(46, 4), Size = UDim2.new(1, -170, 0, 18), Font = Enum.Font.GothamBlack, Parent = row })
		UI.label({ Text = if entry.note ~= "" then entry.note else (if entry.grouped then "já tem grupo, aceita mais gente" else "sem recado"), Position = UDim2.fromOffset(46, 24), Size = UDim2.new(1, -170, 0, 16), TextColor3 = UI.Colors.SubText, Parent = row })
		local invite = UI.button({ Text = "Convidar", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(110, 32), BackgroundColor3 = UI.Colors.Green, Parent = row })
		invite.MouseButton1Click:Connect(function()
			local reply = State.request("partyInvite", entry.id)
			if reply and reply.ok and reply.msg then
				Popups.message(reply.msg, UI.Colors.Green)
			end
		end)
	end
end

local function buildLooking(screen)
	lfg.win = Window.create(screen, { icon = "team-idea", name = "ProcurarGrupo", title = "PROCURAR GRUPO", width = 560, height = 470, accent = Color3.fromRGB(110, 200, 120) })
	local top = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Parent = lfg.win.content })
	lfg.note = UI.new("TextBox", { PlaceholderText = "Recado (ex.: masmorra, chefe de mundo, missões)", Text = "", ClearTextOnFocus = false, Size = UDim2.new(1, -290, 0, 34), BackgroundColor3 = UI.Colors.PanelLight, TextColor3 = UI.Colors.Text, PlaceholderColor3 = UI.Colors.SubText, Font = Enum.Font.Gotham, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Parent = top }, { UI.corner(8), UI.padding(8) })
	lfg.toggle = UI.button({ Text = "Entrar na lista", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -140, 0, 0), Size = UDim2.fromOffset(140, 34), BackgroundColor3 = UI.Colors.Green, Parent = top })
	lfg.toggle.MouseButton1Click:Connect(function()
		local reply = State.request("partyLooking", not lfg.mine, lfg.note.Text)
		if reply and reply.ok and reply.msg then
			Popups.message(reply.msg, UI.Colors.Green)
		end
		renderLooking()
	end)
	local refresh = UI.button({ Text = "Atualizar", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(130, 34), BackgroundColor3 = UI.Colors.Accent, Parent = top })
	refresh.MouseButton1Click:Connect(renderLooking)
	lfg.list = UI.new("ScrollingFrame", { Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 1, -50), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = lfg.win.content }, { UI.list(6) })
	lfg.win.onOpen = renderLooking
end

function PartyUI.openLooking()
	lfg.win:open()
end

function PartyUI.init(screen)
	list = UI.new("Frame", { Position = UDim2.fromOffset(12, 124), Size = UDim2.fromOffset(200, 260), BackgroundTransparency = 1, Parent = screen }, { UI.list(4) })
	buildLooking(screen)
	local finder = UI.button({ Text = "Procurar grupo", Size = UDim2.fromOffset(120, 24), LayoutOrder = 0, BackgroundColor3 = Color3.fromRGB(60, 110, 70), Parent = list })
	finder.MouseButton1Click:Connect(PartyUI.openLooking)
	leaveButton = UI.button({ Text = "Sair do grupo", Size = UDim2.fromOffset(120, 24), LayoutOrder = 99, BackgroundColor3 = UI.Colors.Dark, Visible = false, Parent = list })
	leaveButton.MouseButton1Click:Connect(function()
		State.request("partyLeave")
	end)

	invitePanel = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 260), Size = UDim2.fromOffset(380, 96), BackgroundColor3 = UI.Colors.Panel, Visible = false, Parent = screen }, { UI.corner(12) })
	UI.ornate(invitePanel, UI.Colors.Trim, 4)
	inviteText = UI.label({ Text = "", Position = UDim2.fromOffset(12, 10), Size = UDim2.new(1, -24, 0, 26), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Color3.fromRGB(140, 235, 150), Parent = invitePanel }, { UI.textStroke(1) })
	local accept = UI.button({ Text = "Entrar no grupo", Position = UDim2.new(0, 14, 1, -46), Size = UDim2.new(0.5, -20, 0, 36), BackgroundColor3 = UI.Colors.Green, Parent = invitePanel })
	accept.MouseButton1Click:Connect(function()
		invitePanel.Visible = false
		if pendingInvite then
			State.request("partyRespond", pendingInvite, true)
			pendingInvite = nil
		end
	end)
	local decline = UI.button({ Text = "Recusar", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 1, -46), Size = UDim2.new(0.5, -20, 0, 36), BackgroundColor3 = Color3.fromRGB(150, 50, 50), Parent = invitePanel })
	decline.MouseButton1Click:Connect(function()
		invitePanel.Visible = false
		if pendingInvite then
			State.request("partyRespond", pendingInvite, false)
			pendingInvite = nil
		end
	end)

	for _, other in Players:GetPlayers() do
		if other ~= player then
			addPrompt(other)
		end
	end
	Players.PlayerAdded:Connect(addPrompt)
	Players.PlayerRemoving:Connect(function(other)
		local gui = tags[other.UserId]
		if gui then
			gui:Destroy()
			tags[other.UserId] = nil
		end
	end)

	State.Changed:Connect(function(data)
		current = data and data.party or nil
		render()
	end)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= 0.2 then
			elapsed = 0
			refreshLive()
		end
	end)
	setupChat()
end

return PartyUI
