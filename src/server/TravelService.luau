-- Viagem: pedras de teletransporte, montaria e o portão selado do norte.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local World = require(Shared.World)
local NPCs = require(Shared.NPCs)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local PlayerService = require(script.Parent.PlayerService)
local AntiCheat = require(script.Parent.AntiCheat)

local TravelService = {}

TravelService.QuestHook = function(_player, _kind, _target, _amount) end

local PASS_LEVEL = 10
local buildHorse = nil
local mounts = {}

local function characterParts(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and humanoid and humanoid.Health > 0 then
		return character, root, humanoid
	end
	return nil
end

-- ===================== MONTARIA =====================

function TravelService.dismount(player)
	local mount = mounts[player]
	if not mount then
		return
	end
	mounts[player] = nil
	if mount.model then
		mount.model:Destroy()
	end
	local _, _, humanoid = characterParts(player)
	if humanoid then
		humanoid.HipHeight = mount.hipHeight
	end
	local s = PlayerService.getState(player)
	if s then
		s.mounted = false
	end
	player:SetAttribute("Mounted", false)
end

function TravelService.mount(player)
	local data = DataService.get(player)
	local character, root, humanoid = characterParts(player)
	if not data or not character then
		return
	end
	if not data.mount then
		Remotes.Notify:FireClient(player, { kind = "message", text = "Você ainda não tem montaria. Fale com Pedro, o cavalariço." })
		return
	end
	if PlayerService.inCombat(player) then
		Remotes.Notify:FireClient(player, { kind = "message", text = "Não dá para montar em combate!" })
		return
	end
	local raise = 2.6
	local hipHeight = humanoid.HipHeight
	humanoid.HipHeight = hipHeight + raise
	local model = Instance.new("Model")
	model.Name = "Montaria"
	local horseModel = buildHorse(model, CFrame.new(), Color3.fromRGB(120, 80, 50), true)
	local rootHeight = hipHeight + raise + root.Size.Y / 2
	local offset = CFrame.new(0, -rootHeight, 0.4)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Massless = true
			p.CFrame = root.CFrame * offset * p.CFrame
		end
	end
	-- juntas: grupos (pernas, cabeça, cauda) presos ao corpo com Motor6D para o cliente animar o galope
	local body = horseModel:FindFirstChild("Corpo")
	local JOINT_MAIN = { Cabeca = "Pescoco", Cauda = "Cauda" }
	for _, g in horseModel:GetChildren() do
		if g:IsA("Model") then
			local mainName = JOINT_MAIN[g.Name] or "Perna"
			local main = g:FindFirstChild(mainName)
			if main and body then
				-- ponto de giro: topo da perna/cauda, base do pescoço
				local pivot = if g.Name == "Cabeca" then main.CFrame * CFrame.new(0, -main.Size.Y / 2, 0) else main.CFrame * CFrame.new(0, main.Size.Y / 2, 0)
				local motor = Instance.new("Motor6D")
				motor.Name = "Junta" .. g.Name
				motor.Part0 = body
				motor.Part1 = main
				motor.C0 = body.CFrame:ToObjectSpace(pivot)
				motor.C1 = main.CFrame:ToObjectSpace(pivot)
				motor.Parent = body
				for _, other in g:GetDescendants() do
					if other:IsA("BasePart") and other ~= main then
						local weld = Instance.new("WeldConstraint")
						weld.Part0 = main
						weld.Part1 = other
						weld.Parent = other
					end
				end
			end
		end
	end
	-- o resto (tronco, sela) fica soldado na raiz do jogador
	for _, p in horseModel:GetChildren() do
		if p:IsA("BasePart") then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = p
			weld.Parent = p
		end
	end
	model.Parent = character
	mounts[player] = { model = model, hipHeight = hipHeight }
	local s = PlayerService.getState(player)
	if s then
		s.mounted = true
		s.sprinting = false
	end
	player:SetAttribute("Mounted", true)
	TravelService.QuestHook(player, "mount", nil, 1)
end

function TravelService.toggleMount(player)
	if mounts[player] then
		TravelService.dismount(player)
	else
		TravelService.mount(player)
	end
end

function TravelService.buyMount(player)
	local data = DataService.get(player)
	if not data then
		return { ok = false }
	end
	if data.mount then
		return { ok = false, msg = "Você já tem uma montaria! Aperte H." }
	end
	local pedro = NPCs.ById.pedro
	local _, root = characterParts(player)
	if not root or (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(pedro.x, 0, pedro.z)).Magnitude > 45 then
		return { ok = false, msg = "Fale com Pedro no estábulo." }
	end
	local ok, msg = PlayerService.payCost(player, { gold = Config.MountPrice })
	if not ok then
		return { ok = false, msg = msg }
	end
	data.mount = true
	PlayerService.markDirty(player)
	return { ok = true }
end

-- ===================== PEDRAS DE VIAGEM =====================

function TravelService.travel(player, stoneId)
	local data = DataService.get(player)
	local stone = typeof(stoneId) == "string" and World.WaystoneById[stoneId]
	local character = characterParts(player)
	if not data or not stone or not character then
		return { ok = false, msg = "Destino inválido." }
	end
	if not data.discovered[stoneId] then
		return { ok = false, msg = "Você ainda não ativou essa pedra." }
	end
	if PlayerService.inCombat(player) then
		return { ok = false, msg = "Não dá para viajar em combate!" }
	end
	TravelService.dismount(player)
	local x, z = stone.x + 6, stone.z + 6
	local y = World.height(x, z)
	AntiCheat.allowTeleport(player, 3)
	character:PivotTo(CFrame.new(x, math.max(y, World.SeaLevel) + 4, z))
	Remotes.Fx:FireAllClients("blink", Vector3.new(stone.x, y, stone.z), Vector3.new(x, y + 3, z), "travel")
	TravelService.QuestHook(player, "travel", stoneId, 1)
	return { ok = true }
end

local function discoveryLoop()
	while true do
		task.wait(0.5)
		for _, player in Players:GetPlayers() do
			local data = DataService.get(player)
			local _, root = characterParts(player)
			if data and root then
				for _, stone in World.Waystones do
					if not data.discovered[stone.id] then
						local dx, dz = root.Position.X - stone.x, root.Position.Z - stone.z
						if dx * dx + dz * dz < 26 * 26 then
							data.discovered[stone.id] = true
							Remotes.Notify:FireClient(player, { kind = "discover", name = stone.name })
							TravelService.QuestHook(player, "discover", stone.id, 1)
							PlayerService.markDirty(player)
						end
					end
				end
				-- portão selado: só Rank C (nível 10) passa
				local gateZ = World.PassGateZ
				if root.Position.Z < gateZ - 1 and root.Position.Z > gateZ - 60 * World.Scale and math.abs(root.Position.X) < 60 * World.Scale and data.level < PASS_LEVEL then
					local x, z = root.Position.X, gateZ + 14
					AntiCheat.allowTeleport(player, 3)
					player.Character:PivotTo(CFrame.new(x, World.height(x, z) + 4, z))
					Remotes.Notify:FireClient(player, { kind = "message", text = ("A barreira te repele! Precisa de Nível %d (Rank C)."):format(PASS_LEVEL) })
				end
			end
		end
	end
end

function TravelService.onDamaged(player)
	if mounts[player] then
		TravelService.dismount(player)
	end
end

function TravelService.init(horseBuilder)
	buildHorse = horseBuilder
	task.spawn(discoveryLoop)
	Players.PlayerRemoving:Connect(function(player)
		mounts[player] = nil
	end)
end

return TravelService
