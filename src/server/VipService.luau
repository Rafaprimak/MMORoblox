-- VIP (game pass Config.VipGamePassId) e o Auto Caçar, que só VIP pode ligar.
-- O servidor confere a compra e marca o atributo "Vip"; o Auto Caçar é o atributo "AutoFarm" (o cliente
-- anda e ataca sozinho enquanto ele está ligado; os golpes passam pelas mesmas regras de sempre).
-- 100% AFK: o ponto de caça fica no atributo "AutoAnchor"; quem morre volta para lá; e antes de o Roblox
-- desconectar por inatividade (20 min), o cliente pede um "reconectar" para o MESMO servidor, que volta
-- com o Auto Caçar ligado no mesmo ponto (TeleportData).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local PlayerService = require(script.Parent.PlayerService)
local DataService = require(script.Parent.DataService)
local AntiCheat = require(script.Parent.AntiCheat)
local World = require(Shared.World)

local VipService = {}

function VipService.isVip(player)
	return player:GetAttribute("Vip") == true
end

-- ponto de caça válido (dentro do mapa)
local function validAnchor(position)
	return typeof(position) == "Vector3" and math.abs(position.X) < World.Half and math.abs(position.Z) < World.Half and position.Y > -50 and position.Y < 600
end

function VipService.onPlayerAdded(player)
	-- voltou de um "reconectar" do modo AFK? liga o Auto Caçar de novo no mesmo ponto
	local joinData = player:GetJoinData()
	local teleportData = joinData and joinData.TeleportData
	if type(teleportData) == "table" and teleportData.autoFarm and type(teleportData.anchor) == "table" then
		local anchor = Vector3.new(tonumber(teleportData.anchor[1]) or 0, tonumber(teleportData.anchor[2]) or 0, tonumber(teleportData.anchor[3]) or 0)
		if validAnchor(anchor) then
			player:SetAttribute("AutoAnchor", anchor)
			player:SetAttribute("ResumeAutoFarm", true)
		end
	end
	task.spawn(function()
		local vip = false
		if RunService:IsStudio() then
			vip = true -- no Studio todo mundo é VIP, para testar
		elseif Config.VipGamePassId > 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, Config.VipGamePassId)
			end)
			vip = ok and owns == true
		end
		if player.Parent == Players then
			player:SetAttribute("Vip", vip)
			PlayerService.markDirty(player)
			if vip and player:GetAttribute("ResumeAutoFarm") then
				player:SetAttribute("ResumeAutoFarm", nil)
				player:SetAttribute("AutoFarm", true)
			end
		end
	end)
end

-- quem morre com o Auto Caçar ligado nasce de volta no ponto de caça
function VipService.onCharacterAdded(player, character)
	local anchor = player:GetAttribute("AutoAnchor")
	if (player:GetAttribute("AutoFarm") or player:GetAttribute("ResumeAutoFarm")) and validAnchor(anchor) and not VipService.inInstance(player) then
		task.delay(0.6, function()
			if character.Parent and character:FindFirstChild("HumanoidRootPart") then
				AntiCheat.allowTeleport(player, 3)
				character:PivotTo(CFrame.new(anchor + Vector3.new(0, 4, 0)))
			end
		end)
	end
end

-- Reconecta no mesmo servidor (zera o contador de inatividade do Roblox) e volta caçando
function VipService.afkRejoin(player)
	if not player:GetAttribute("AutoFarm") or not VipService.isVip(player) then
		return { ok = false }
	end
	if RunService:IsStudio() then
		return { ok = false, msg = "O reconectar automático só funciona no jogo publicado." }
	end
	local anchor = player:GetAttribute("AutoAnchor")
	if not validAnchor(anchor) then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		anchor = root and root.Position
	end
	pcall(DataService.save, player)
	local options = Instance.new("TeleportOptions")
	options.ServerInstanceId = game.JobId
	options:SetTeleportData({ autoFarm = true, anchor = if anchor then { anchor.X, anchor.Y, anchor.Z } else nil })
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, { player }, options)
	end)
	if not ok then
		warn("[AFK] Falha ao reconectar: " .. tostring(err))
		return { ok = false }
	end
	return { ok = true }
end

-- dentro de masmorra, raide ou luta da arena (o Auto nunca roda lá)
function VipService.inInstance(player)
	return player:GetAttribute("Dungeon") ~= nil or player:GetAttribute("Raid") ~= nil or player:GetAttribute("Arena") ~= nil
end

-- Liga/desliga o Auto Caçar (anchor = ponto de caça, mandado pelo cliente ao ligar)
function VipService.setAutoFarm(player, on, anchor)
	if on ~= true then
		player:SetAttribute("AutoFarm", false)
		player:SetAttribute("AutoAnchor", nil)
		return { ok = true }
	end
	if not VipService.isVip(player) then
		return { ok = false, msg = "O Auto Caçar é exclusivo para VIP." }
	end
	if VipService.inInstance(player) then
		return { ok = false, msg = "O Auto não funciona em masmorras, raide e arena." }
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return { ok = false, msg = "Espere seu personagem voltar." }
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	-- o ponto de caça precisa estar perto do personagem (não confia no cliente)
	if not validAnchor(anchor) or not root or (anchor - root.Position).Magnitude > 30 then
		anchor = root and root.Position
	end
	player:SetAttribute("AutoAnchor", anchor)
	player:SetAttribute("AutoFarm", true)
	return { ok = true }
end

-- Auto preso (obstáculo que o caminho não resolveu): o servidor leva o personagem alguns studs na direção
-- do destino, para um lugar livre com chão. Só com o Auto ligado, fora de masmorra/raide/arena, a cada 6 s.
local lastUnstuck = {}
function VipService.autoUnstuck(player, goal)
	if not player:GetAttribute("AutoFarm") or VipService.inInstance(player) or typeof(goal) ~= "Vector3" then
		return { ok = false }
	end
	if os.clock() - (lastUnstuck[player] or 0) < 6 then
		return { ok = false }
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return { ok = false }
	end
	lastUnstuck[player] = os.clock()
	local toward = Vector3.new(goal.X - root.Position.X, 0, goal.Z - root.Position.Z)
	local forward = if toward.Magnitude > 0.1 then toward.Unit else root.CFrame.LookVector
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { character }
	for _, distance in { 10, 7, 14, 4 } do
		for _, angle in { 0, 40, -40, 80, -80, 140, -140 } do
			local direction = CFrame.Angles(0, math.rad(angle), 0):VectorToWorldSpace(forward)
			local spot = root.Position + direction * distance
			local hit = workspace:Raycast(spot + Vector3.new(0, 30, 0), Vector3.new(0, -70, 0), rayParams)
			if hit and hit.Material ~= Enum.Material.Water then
				local stand = hit.Position + Vector3.new(0, 3.2, 0)
				local blocking = false
				for _, part in workspace:GetPartBoundsInBox(CFrame.new(stand), Vector3.new(3, 5, 3)) do
					if part.CanCollide and part.Transparency < 1 and not part:IsDescendantOf(character) then
						blocking = true
						break
					end
				end
				if not blocking then
					AntiCheat.allowTeleport(player, 2)
					character:PivotTo(CFrame.lookAt(stand, stand + direction))
					return { ok = true }
				end
			end
		end
	end
	return { ok = false }
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, purchased)
	if purchased and gamePassId == Config.VipGamePassId and Config.VipGamePassId > 0 then
		player:SetAttribute("Vip", true)
		PlayerService.markDirty(player)
	end
end)

-- entrar numa masmorra desliga o Auto Caçar
task.spawn(function()
	while true do
		task.wait(1)
		for _, player in Players:GetPlayers() do
			if player:GetAttribute("AutoFarm") and VipService.inInstance(player) then
				player:SetAttribute("AutoFarm", false)
			end
		end
	end
end)

return VipService
