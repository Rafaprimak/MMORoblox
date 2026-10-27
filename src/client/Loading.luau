-- Tela de carregamento enquanto o servidor gera o mundo.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local UI = require(script.Parent.UI)

local Loading = {}

function Loading.init()
	local player = Players.LocalPlayer
	local gui = UI.new("ScreenGui", { Name = "Carregando", DisplayOrder = 30, IgnoreGuiInset = true, ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })
	local back = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(10, 12, 20), Parent = gui })
	UI.label({ Text = "HUNTER RPG ", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.fromOffset(600, 70), TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamBlack, TextColor3 = UI.Colors.Gold, Parent = back }, { UI.textStroke(3) })
	local status = UI.label({ Text = "Conectando...", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromOffset(500, 24), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = UI.Colors.SubText, Parent = back })
	local barBack, fill = UI.bar(back, { Position = UDim2.new(0.5, -200, 0.57, 0), Size = UDim2.fromOffset(400, 14), color = UI.Colors.Gold, text = false })
	local _ = barBack
	UI.label({ Text = "Dica: clique no ritmo para combos • F bloqueia (na hora certa, apara!) • Q esquiva • segure R para o golpe pesado", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -30), Size = UDim2.fromOffset(700, 20), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = UI.Colors.SubText, Parent = back })

	local connection
	connection = RunService.RenderStepped:Connect(function()
		local ready = workspace:GetAttribute("WorldReady") == true
		status.Text = if ready then "Entrando no mundo..." else (workspace:GetAttribute("WorldStatus") or "Gerando o mundo") .. "..."
		UI.setBar(fill, workspace:GetAttribute("WorldProgress") or 0)
		local character = player.Character
		if ready and character and character:FindFirstChild("HumanoidRootPart") then
			connection:Disconnect()
			UI.tween(back, 0.8, { BackgroundTransparency = 1 })
			UI.fadeOut(back, 0.8)
			task.delay(0.9, function()
				gui:Destroy()
			end)
		end
	end)
end

return Loading
