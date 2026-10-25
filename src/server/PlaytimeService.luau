-- Presentes por tempo seguido no mesmo servidor (Config.PlaytimeRewards). O relógio começa quando o
-- jogador entra neste servidor; sair (ou trocar de servidor) recomeça do zero. Cada presente é resgatado
-- uma vez por sessão, pela janela de Presentes no cliente.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local PlayerService = require(script.Parent.PlayerService)
local ShopService = require(script.Parent.ShopService)

local PlaytimeService = {}

local sessions = {} -- [player] = { joined, claimed = { [index] = true }, announced = { [index] = true } }

local function session(player)
	local s = sessions[player]
	if not s then
		s = { joined = os.clock(), claimed = {}, announced = {} }
		sessions[player] = s
	end
	return s
end

function PlaytimeService.onPlayerAdded(player)
	session(player)
end

function PlaytimeService.onPlayerRemoving(player)
	sessions[player] = nil
end

-- para o cliente: segundos neste servidor e quais presentes já saíram
function PlaytimeService.summary(player)
	local s = session(player)
	local claimed = {}
	for index in Config.PlaytimeRewards do
		claimed[index] = s.claimed[index] == true
	end
	return { elapsed = math.floor(os.clock() - s.joined), claimed = claimed }
end

function PlaytimeService.claim(player, index)
	local reward = Config.PlaytimeRewards[tonumber(index) or 0]
	local s = session(player)
	if not reward or not DataService.get(player) then
		return { ok = false, msg = "Presente inválido." }
	end
	if s.claimed[index] then
		return { ok = false, msg = "Você já pegou esse presente nesta sessão." }
	end
	if os.clock() - s.joined < reward.minutes * 60 then
		return { ok = false, msg = ("Fique %d minutos neste servidor para liberar."):format(reward.minutes) }
	end
	s.claimed[index] = true
	if reward.gold then
		PlayerService.addGold(player, reward.gold)
	end
	for id, count in reward.consumables or {} do
		PlayerService.addConsumable(player, id, count)
	end
	for id, count in reward.materials or {} do
		PlayerService.addMaterial(player, id, count)
	end
	if reward.chest then
		ShopService.grant(player, reward.chest)
	end
	PlayerService.markDirty(player)
	return { ok = true }
end

-- avisa quando um presente fica pronto
task.spawn(function()
	while true do
		task.wait(5)
		for _, player in Players:GetPlayers() do
			local s = sessions[player]
			if s then
				local elapsed = os.clock() - s.joined
				for index, reward in Config.PlaytimeRewards do
					if not s.announced[index] and not s.claimed[index] and elapsed >= reward.minutes * 60 then
						s.announced[index] = true
						Remotes.Notify:FireClient(player, { kind = "message", text = ("🎁 Presente de %d minutos liberado! Abra a janela Presentes (tecla U)."):format(reward.minutes) })
						PlayerService.markDirty(player)
					end
				end
			end
		end
	end
end)

return PlaytimeService
