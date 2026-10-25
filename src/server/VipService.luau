-- VIP (game pass Config.VipGamePassId) e o Auto Caçar, que só VIP pode ligar.
-- O servidor confere a compra e marca o atributo "Vip"; o Auto Caçar é o atributo "AutoFarm" (o cliente
-- anda e ataca sozinho enquanto ele está ligado; os golpes passam pelas mesmas regras de sempre).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local PlayerService = require(script.Parent.PlayerService)

local VipService = {}

function VipService.isVip(player)
	return player:GetAttribute("Vip") == true
end

function VipService.onPlayerAdded(player)
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
		end
	end)
end

-- Liga/desliga o Auto Caçar
function VipService.setAutoFarm(player, on)
	if on ~= true then
		player:SetAttribute("AutoFarm", false)
		return { ok = true }
	end
	if not VipService.isVip(player) then
		return { ok = false, msg = "O Auto Caçar é exclusivo para VIP." }
	end
	if player:GetAttribute("Dungeon") then
		return { ok = false, msg = "O Auto Caçar não funciona dentro das masmorras." }
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return { ok = false, msg = "Espere seu personagem voltar." }
	end
	player:SetAttribute("AutoFarm", true)
	return { ok = true }
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
			if player:GetAttribute("AutoFarm") and player:GetAttribute("Dungeon") then
				player:SetAttribute("AutoFarm", false)
			end
		end
	end
end)

return VipService
