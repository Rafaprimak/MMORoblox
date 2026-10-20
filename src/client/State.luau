-- Estado do jogador recebido do servidor + atalho para pedidos.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local State = {}

State.data = nil
local changed = Instance.new("BindableEvent")
State.Changed = changed.Event

-- Mensagem de erro (preenchido pelo init com Popups.message)
State.onError = function(_text) end

function State.set(data)
	State.data = data
	changed:Fire(data)
end

-- Faz um pedido ao servidor; mostra a mensagem de erro se falhar
function State.request(action, a, b)
	local ok, result = pcall(function()
		return Remotes.Request:InvokeServer(action, a, b)
	end)
	if not ok or type(result) ~= "table" then
		State.onError("Erro de conexão, tente de novo.")
		return nil
	end
	if not result.ok and result.msg then
		State.onError(result.msg)
	end
	return result
end

function State.action(name, a, b, c)
	Remotes.Action:FireServer(name, a, b, c)
end

function State.materialCount(id)
	local data = State.data
	return if data and data.materials then data.materials[id] or 0 else 0
end

function State.skillLevel(id)
	local data = State.data
	local skill = data and data.skills and data.skills[id]
	return if skill then skill.level else 1
end

return State
