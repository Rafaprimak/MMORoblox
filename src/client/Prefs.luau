-- Configurações do jogador no cliente (volume, sensibilidade, números de dano...).
-- Só guarda valores: não exige nenhum outro módulo do cliente, então qualquer um pode ler.
-- Os valores vêm do servidor (data.settings) e são salvos pela janela de Configurações.
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local Prefs = {}

local values = table.clone(Config.DefaultSettings)
local loaded = false

function Prefs.get(key)
	return values[key]
end

function Prefs.all()
	return values
end

local function apply()
	UserInputService.MouseDeltaSensitivity = values.sensitivity
end

function Prefs.set(key, value)
	values[key] = value
	apply()
end

-- chamado a cada DataUpdate; só aplica a primeira vez (depois o cliente é a fonte da verdade)
function Prefs.load(settings)
	if loaded or type(settings) ~= "table" then
		return
	end
	loaded = true
	for key, value in settings do
		if values[key] ~= nil and type(value) == type(values[key]) then
			values[key] = value
		end
	end
	apply()
end

return Prefs
