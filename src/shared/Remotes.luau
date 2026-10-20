-- Cria (no servidor) ou encontra (no cliente) os canais de comunicação.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DEFINITIONS = {
	DataUpdate = "RemoteEvent", -- servidor -> cliente: estado completo do jogador
	Notify = "RemoteEvent", -- servidor -> cliente: popups (loot, level up, missões...)
	Fx = "RemoteEvent", -- servidor -> cliente: efeitos visuais, golpes, projéteis
	Action = "RemoteEvent", -- cliente -> servidor: ações de combate e movimento (rápidas)
	Request = "RemoteFunction", -- cliente -> servidor: ações de interface (equipar, forjar, missões...)
}

local Remotes = {}

if RunService:IsServer() then
	local folder = Instance.new("Folder")
	folder.Name = "Remotes"
	for name, className in DEFINITIONS do
		local remote = Instance.new(className)
		remote.Name = name
		remote.Parent = folder
		Remotes[name] = remote
	end
	folder.Parent = ReplicatedStorage
else
	local folder = ReplicatedStorage:WaitForChild("Remotes")
	for name in DEFINITIONS do
		Remotes[name] = folder:WaitForChild(name)
	end
end

return Remotes
