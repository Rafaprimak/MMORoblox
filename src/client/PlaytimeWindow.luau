-- Presentes por tempo no servidor (tecla U): lista os presentes de Config.PlaytimeRewards com o tempo
-- que falta, e o botão Resgatar quando liberam. O tempo vem do servidor (data.playtime.elapsed) e o
-- cliente só conta os segundos entre uma sincronização e outra.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Chests = require(Shared.Chests)

local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Window = require(script.Parent.Window)
local Sounds = require(script.Parent.Sounds)

local PlaytimeWindow = {}

local win, list
local syncedElapsed, syncedAt = 0, os.clock()
local rows = {}
local lastKey = nil

-- segundos neste servidor agora
function PlaytimeWindow.elapsed()
	return syncedElapsed + (os.clock() - syncedAt)
end

local function rewardText(reward)
	local parts = {}
	if reward.gold then
		table.insert(parts, ("%s ouro"):format(UI.formatNumber(reward.gold)))
	end
	for id, count in reward.consumables or {} do
		local def = Items.Consumables[id]
		table.insert(parts, ("%s %s x%d"):format(def and def.icon or "", def and def.name or id, count))
	end
	for id, count in reward.materials or {} do
		local def = Items.Materials[id]
		table.insert(parts, ("%s %s x%d"):format(def and def.icon or "", def and def.name or id, count))
	end
	if reward.chest then
		local chest = Chests.List[reward.chest]
		table.insert(parts, chest and chest.name or "Baú")
	end
	return table.concat(parts, "  •  ")
end

local function formatTime(seconds)
	seconds = math.max(0, math.floor(seconds))
	return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

-- quantos presentes estão prontos para resgatar
function PlaytimeWindow.readyCount()
	local data = State.data
	local claimed = data and data.playtime and data.playtime.claimed or {}
	local count = 0
	for index, reward in Config.PlaytimeRewards do
		if not claimed[index] and PlaytimeWindow.elapsed() >= reward.minutes * 60 then
			count += 1
		end
	end
	return count
end

local function build()
	local data = State.data
	local claimed = data and data.playtime and data.playtime.claimed or {}
	-- só recria a lista quando muda o que foi resgatado
	local keyParts = {}
	for index in Config.PlaytimeRewards do
		table.insert(keyParts, tostring(claimed[index] == true))
	end
	local key = table.concat(keyParts, ",")
	if key == lastKey then
		return
	end
	lastKey = key
	UI.clear(list)
	rows = {}
	UI.label({ Text = "Fique no mesmo servidor e ganhe presentes. Trocar de servidor recomeça o tempo.", Size = UDim2.new(1, -8, 0, 20), TextScaled = false, TextSize = 14, TextColor3 = UI.Colors.SubText, LayoutOrder = 0, Parent = list })
	for index, reward in Config.PlaytimeRewards do
		local row = UI.new("Frame", { Size = UDim2.new(1, -8, 0, 54), BackgroundColor3 = UI.Colors.PanelLight, BackgroundTransparency = 0.3, LayoutOrder = index, Parent = list }, { UI.corner(10) })
		UI.label({ Text = ("%d min"):format(reward.minutes), Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(70, 38), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = UI.Colors.Gold, Font = Enum.Font.GothamBlack, Parent = row }, { UI.textStroke(1) })
		UI.label({ Text = rewardText(reward), Position = UDim2.fromOffset(88, 8), Size = UDim2.new(1, -240, 0, 38), TextScaled = false, TextSize = 14, TextWrapped = true, Parent = row })
		local button = UI.button({ Text = "", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(130, 36), Parent = row })
		button.MouseButton1Click:Connect(function()
			local result = State.request("claimPlaytime", index)
			if result and result.ok then
				Sounds.play("coin", 1, 0.6)
			end
		end)
		rows[index] = { button = button, reward = reward, claimed = claimed[index] == true }
	end
end

-- atualiza só os botões (tempo restante / resgatar / pego)
local function refresh()
	for _, row in rows do
		local left = row.reward.minutes * 60 - PlaytimeWindow.elapsed()
		if row.claimed then
			row.button.Text = "Pego"
			row.button.BackgroundColor3 = UI.Colors.Dark
			row.button.Active = false
		elseif left <= 0 then
			row.button.Text = "RESGATAR"
			row.button.BackgroundColor3 = UI.Colors.Green
			row.button.Active = true
		else
			row.button.Text = formatTime(left)
			row.button.BackgroundColor3 = UI.Colors.PanelLight
			row.button.Active = false
		end
	end
	win.title.Text = ("PRESENTES  •  neste servidor há %s"):format(formatTime(PlaytimeWindow.elapsed()))
end

function PlaytimeWindow.init(screen)
	win = Window.create(screen, { icon = "sands-of-time", name = "Presentes", title = "PRESENTES", width = 560, height = 560, accent = UI.Colors.Gold })
	list = UI.new("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 5, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = win.content }, { UI.list(8) })
	win.onOpen = function()
		lastKey = nil
		build()
		refresh()
	end
	State.Changed:Connect(function()
		local playtime = State.data and State.data.playtime
		if playtime then
			syncedElapsed, syncedAt = playtime.elapsed, os.clock()
		end
		if win:isOpen() then
			build()
			refresh()
		end
	end)
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= 1 and win:isOpen() then
			accumulator = 0
			refresh()
		end
	end)
end

function PlaytimeWindow.toggle()
	win:toggle()
end

return PlaytimeWindow
