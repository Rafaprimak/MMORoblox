-- Evento do mundo em andamento (WorldEventService): painel no topo da tela com nome, lugar, distância e
-- tempo restante, e um marcador no mundo (visível de longe) no ponto do evento. Lê os atributos do
-- workspace: EventKind, EventName, EventPlace, EventX, EventZ, EventEnds, EventWave, EventWaves.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared.World)

local UI = require(script.Parent.UI)

local EventTracker = {}

local player = Players.LocalPlayer
local panel, title, sub, icon
local beacon -- peça local com o marcador no mundo
-- ícones: "crown", "crossed-swords"

local function kindInfo(kind)
	if kind == "boss" then
		return "crown", Color3.fromRGB(255, 130, 80), "CHEFE DE MUNDO"
	end
	return "crossed-swords", Color3.fromRGB(255, 90, 90), "INVASÃO"
end

-- posição do evento (x, z) ou nil
function EventTracker.position()
	local kind = workspace:GetAttribute("EventKind")
	local x, z = workspace:GetAttribute("EventX"), workspace:GetAttribute("EventZ")
	if kind and x and z then
		return x, z, kind
	end
	return nil
end

local function ensureBeacon(x, z, kind)
	local iconName, color = kindInfo(kind)
	if not beacon then
		beacon = Instance.new("Part")
		beacon.Name = "MarcadorEvento"
		beacon.Anchored = true
		beacon.CanCollide = false
		beacon.CanQuery = false
		beacon.CanTouch = false
		beacon.Transparency = 1
		beacon.Size = Vector3.one
		beacon.Parent = workspace
		local gui = UI.new("BillboardGui", { Name = "Marcador", Size = UDim2.fromOffset(60, 76), AlwaysOnTop = true, LightInfluence = 0, MaxDistance = 100000, Parent = beacon })
		UI.icon(iconName, { Name = "Simbolo", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(48, 48), Color = color, Parent = gui })
		UI.label({ Name = "Distancia", Text = "", Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = color, Font = Enum.Font.GothamBlack, Parent = gui }, { UI.textStroke(1.5) })
	end
	local gui = beacon:FindFirstChild("Marcador")
	UI.setIcon(gui and gui:FindFirstChild("Simbolo"), iconName, color)
	beacon.Position = Vector3.new(x, World.height(x, z) + 24, z)
	return beacon
end

local function update()
	local x, z, kind = EventTracker.position()
	if not x then
		panel.Visible = false
		if beacon then
			beacon:Destroy()
			beacon = nil
		end
		return
	end
	local iconName, color, label = kindInfo(kind)
	panel.Visible = true
	UI.setIcon(icon, iconName, color)
	title.TextColor3 = color
	title.Text = ("%s: %s"):format(label, workspace:GetAttribute("EventName") or "")
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local distance = if root then math.floor((Vector3.new(x, root.Position.Y, z) - root.Position).Magnitude) else 0
	local left = math.max(0, (workspace:GetAttribute("EventEnds") or 0) - workspace:GetServerTimeNow())
	local parts = { workspace:GetAttribute("EventPlace") or "", ("%dm"):format(distance), UI.formatTime(left) }
	local wave, waves = workspace:GetAttribute("EventWave"), workspace:GetAttribute("EventWaves")
	if wave and waves then
		table.insert(parts, 2, ("onda %d/%d"):format(wave, waves))
	end
	sub.Text = table.concat(parts, "  •  ")
	local mark = ensureBeacon(x, z, kind)
	local gui = mark:FindFirstChild("Marcador")
	local distanceLabel = gui and gui:FindFirstChild("Distancia")
	if distanceLabel then
		distanceLabel.Text = ("%dm"):format(distance)
	end
end

function EventTracker.init(screen)
	panel = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 52), Size = UDim2.fromOffset(440, 50), BackgroundColor3 = UI.Colors.Panel, BackgroundTransparency = 0.15, Visible = false, Parent = screen }, { UI.corner(10) })
	UI.ornate(panel, UI.Colors.Trim, 3)
	icon = UI.icon("crown", { Position = UDim2.fromOffset(8, 7), Size = UDim2.fromOffset(36, 36), Parent = panel })
	title = UI.label({ Text = "", Position = UDim2.fromOffset(52, 5), Size = UDim2.new(1, -60, 0, 20), Font = Enum.Font.GothamBlack, Parent = panel }, { UI.textStroke(1) })
	sub = UI.label({ Text = "", Position = UDim2.fromOffset(52, 27), Size = UDim2.new(1, -60, 0, 16), TextColor3 = UI.Colors.SubText, Parent = panel })
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= 0.25 then
			elapsed = 0
			update()
		end
	end)
end

return EventTracker
