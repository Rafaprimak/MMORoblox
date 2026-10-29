-- Interação com outros jogadores: um aviso pequeno em cima da cabeça ("E  Grupo / Troca") no lugar
-- dos dois avisos grandes do Roblox, que cobriam o personagem inteiro. Apertar E (ou tocar no aviso)
-- abre um menu curto com Convidar para o grupo e Trocar. O menu fecha sozinho ao se afastar.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local UI = require(script.Parent.UI)
local PartyUI = require(script.Parent.PartyUI)
local TradeWindow = require(script.Parent.TradeWindow)

local PlayerPrompt = {}

local player = Players.LocalPlayer
local MENU_RANGE = 20 -- studs: mais longe que isso o menu fecha

local menu, menuTitle, partyButton = nil, nil, nil
local menuTarget = nil
local menuOpenedAt = 0

local function rootOf(other)
	local character = other and other.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function closeMenu()
	menuTarget = nil
	if menu then
		menu.Visible = false
	end
end

local function openMenu(other)
	if not menu or not other.Parent then
		return
	end
	menuTarget = other
	menuOpenedAt = os.clock()
	menuTitle.Text = other.DisplayName
	partyButton.Visible = not PartyUI.isMember(other)
	menu.Visible = true
end

-- aviso pequeno sobre a cabeça (BillboardGui na PlayerGui para aceitar toque)
local function showTag(other)
	local character = other.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return nil
	end
	local touch = UI.touchOnly()
	local gui = UI.new("BillboardGui", { Name = "AvisoJogador", Size = UDim2.fromOffset(if touch then 120 else 132, 26), StudsOffset = Vector3.new(0, 4.4, 0), AlwaysOnTop = true, LightInfluence = 0, Active = true, ResetOnSpawn = false, Adornee = head, Parent = player:WaitForChild("PlayerGui") })
	local pill = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = UI.Colors.Panel, BackgroundTransparency = 0.2, Parent = gui }, { UI.corner(13), UI.stroke(UI.Colors.Trim, 1.5, 0.3) })
	local textLeft = 8
	if not touch then
		local key = UI.new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 4, 0.5, 0), Size = UDim2.fromOffset(20, 20), BackgroundColor3 = UI.Colors.Gold, Parent = pill }, { UI.corner(6) })
		UI.label({ Text = "E", Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Color3.fromRGB(30, 24, 10), Font = Enum.Font.GothamBlack, TextSize = 13, Parent = key })
		textLeft = 28
	end
	UI.label({ Text = "Grupo / Troca", Position = UDim2.fromOffset(textLeft, 0), Size = UDim2.new(1, -textLeft - 6, 1, 0), TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamBold, TextSize = 13, Parent = pill }, { UI.textStroke(1) })
	local hit = UI.new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = gui })
	hit.Activated:Connect(function()
		openMenu(other)
	end)
	return gui
end

local function addPlayer(other)
	local function onCharacter(character)
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if not root then
			return
		end
		local prompt = UI.new("ProximityPrompt", {
			Name = "JogadorPrompt",
			Style = Enum.ProximityPromptStyle.Custom,
			ActionText = "Grupo / Troca",
			ObjectText = other.DisplayName,
			KeyboardKeyCode = Enum.KeyCode.E,
			GamepadKeyCode = Enum.KeyCode.ButtonX,
			HoldDuration = 0,
			MaxActivationDistance = 14,
			RequiresLineOfSight = false,
			Parent = root,
		})
		local tag = nil
		prompt.PromptShown:Connect(function()
			if tag then
				tag:Destroy()
			end
			tag = showTag(other)
		end)
		prompt.PromptHidden:Connect(function()
			if tag then
				tag:Destroy()
				tag = nil
			end
		end)
		prompt.Triggered:Connect(function()
			openMenu(other)
		end)
		prompt.Destroying:Connect(function()
			if tag then
				tag:Destroy()
				tag = nil
			end
		end)
	end
	if other.Character then
		task.spawn(onCharacter, other.Character)
	end
	other.CharacterAdded:Connect(onCharacter)
end

function PlayerPrompt.init(screen)
	-- menu curto, um pouco abaixo do centro (não cobre o personagem de ninguém)
	menu = UI.new("Frame", { Name = "MenuJogador", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.6, 0), Size = UDim2.fromOffset(230, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = UI.Colors.Panel, BackgroundTransparency = 0.1, Visible = false, Parent = screen }, { UI.corner(10), UI.stroke(UI.Colors.Trim, 1.5, 0.3), UI.padding(8), UI.list(6) })
	menuTitle = UI.label({ Text = "", Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Center, FontFace = UI.TitleFont, TextColor3 = UI.Colors.Gold, LayoutOrder = 0, Parent = menu }, { UI.textStroke(1) })
	partyButton = UI.button({ Text = "Convidar para o grupo", Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = UI.Colors.Green, LayoutOrder = 1, Parent = menu })
	local tradeButton = UI.button({ Text = "Trocar itens", Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = UI.Colors.Accent, LayoutOrder = 2, Parent = menu })
	local closeButton = UI.button({ Text = "Fechar", Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = UI.Colors.Dark, LayoutOrder = 3, Parent = menu })
	partyButton.MouseButton1Click:Connect(function()
		local target = menuTarget
		closeMenu()
		if target then
			PartyUI.inviteTo(target)
		end
	end)
	tradeButton.MouseButton1Click:Connect(function()
		local target = menuTarget
		closeMenu()
		if target then
			TradeWindow.inviteTo(target)
		end
	end)
	closeButton.MouseButton1Click:Connect(closeMenu)

	-- fecha ao se afastar ou depois de um tempo parado aberto
	RunService.Heartbeat:Connect(function()
		if not menuTarget then
			return
		end
		local mine, theirs = rootOf(player), rootOf(menuTarget)
		if not mine or not theirs or (mine.Position - theirs.Position).Magnitude > MENU_RANGE or os.clock() - menuOpenedAt > 15 then
			closeMenu()
		end
	end)

	for _, other in Players:GetPlayers() do
		if other ~= player then
			addPlayer(other)
		end
	end
	Players.PlayerAdded:Connect(addPlayer)
	Players.PlayerRemoving:Connect(function(other)
		if menuTarget == other then
			closeMenu()
		end
	end)
end

return PlayerPrompt
