-- Proteções contra trapaça (o cliente nunca é confiável):
--   * Limite de pedidos: cada canal de rede (Action/Request) tem um "balde" de fichas por jogador.
--     Passou do limite, o pedido é ignorado; abusar sem parar desconecta.
--   * Movimento: o servidor compara a posição do personagem a cada meio segundo com a velocidade
--     máxima possível (corrida, cavalo, esquiva). Rápido demais (speed hack/teleporte) volta para o
--     último lugar válido. Teleportes do próprio servidor (viagem, masmorra, Piscar...) chamam
--     AntiCheat.allowTeleport antes, para não serem confundidos com trapaça.
-- Não exige nenhum outro serviço (qualquer um pode exigir este).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local AntiCheat = {}

-- ===================== LIMITE DE PEDIDOS =====================
-- rate = fichas por segundo, burst = máximo guardado
local LIMITS = {
	action = { rate = 25, burst = 45 }, -- golpes, esquiva, bloqueio, habilidades...
	request = { rate = 12, burst = 30 }, -- janelas (equipar, comprar, forjar, trocar...)
}
local KICK_DROPS = 400 -- pedidos ignorados em KICK_WINDOW segundos = desconecta
local KICK_WINDOW = 30

local buckets = {} -- [player] = { [nome] = { tokens, last } , drops, dropsSince }

-- true se o pedido pode passar
function AntiCheat.allow(player, kind)
	local limit = LIMITS[kind]
	if not limit then
		return true
	end
	local entry = buckets[player]
	if not entry then
		entry = { drops = 0, dropsSince = os.clock() }
		buckets[player] = entry
	end
	local now = os.clock()
	local bucket = entry[kind]
	if not bucket then
		bucket = { tokens = limit.burst, last = now }
		entry[kind] = bucket
	end
	bucket.tokens = math.min(limit.burst, bucket.tokens + (now - bucket.last) * limit.rate)
	bucket.last = now
	if bucket.tokens >= 1 then
		bucket.tokens -= 1
		return true
	end
	-- excesso: conta e, se for abuso contínuo, desconecta
	if now - entry.dropsSince > KICK_WINDOW then
		entry.drops, entry.dropsSince = 0, now
	end
	entry.drops += 1
	if entry.drops >= KICK_DROPS and not RunService:IsStudio() then
		warn(("[AntiCheat] %s excedeu o limite de pedidos (%s)"):format(player.Name, kind))
		player:Kick("Atividade suspeita detectada.")
	end
	return false
end

-- ===================== MOVIMENTO =====================
local CHECK_EVERY = 0.5
local BURST = 32 -- folga para esquiva + investida (~25 studs) e para o atraso da rede
local TOLERANCE = 1.45 -- folga sobre a velocidade máxima
local RISE_SPEED = 90 -- subida máxima (studs/s) fora de pulo normal
local VIOLATIONS_TO_LOG = 6

local tracks = {} -- [player] = { lastValid, lastTime, allowUntil, violations }

-- O servidor vai mover o personagem (viagem, masmorra, Piscar...): não conta como trapaça
function AntiCheat.allowTeleport(player, seconds)
	local track = tracks[player]
	if not track then
		track = { violations = 0 }
		tracks[player] = track
	end
	track.allowUntil = os.clock() + (seconds or 2)
	track.lastValid = nil
end

local function maxSpeed(player)
	if player:GetAttribute("Mounted") then
		return Config.MountSpeed
	end
	return Config.SprintSpeed
end

local function check(player, now)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	local track = tracks[player]
	if not track then
		track = { violations = 0 }
		tracks[player] = track
	end
	local position = root.Position
	if (track.allowUntil and now < track.allowUntil) or not track.lastValid then
		track.lastValid, track.lastTime = position, now
		return
	end
	local dt = math.max(now - track.lastTime, 0.05)
	local offset = position - track.lastValid
	local horizontal = Vector3.new(offset.X, 0, offset.Z).Magnitude
	local allowed = maxSpeed(player) * TOLERANCE * dt + BURST
	local rising = offset.Y / dt
	if horizontal > allowed or rising > RISE_SPEED then
		-- volta para o último lugar válido
		track.violations += 1
		root.AssemblyLinearVelocity = Vector3.zero
		character:PivotTo(CFrame.new(track.lastValid) * (root.CFrame - root.CFrame.Position))
		track.lastTime = now
		if track.violations % VIOLATIONS_TO_LOG == 0 then
			warn(("[AntiCheat] %s se moveu rápido demais %d vezes"):format(player.Name, track.violations))
		end
		return
	end
	track.lastValid, track.lastTime = position, now
end

function AntiCheat.onCharacterAdded(player)
	AntiCheat.allowTeleport(player, 3) -- nascer/renascer
end

function AntiCheat.start()
	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
		tracks[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(CHECK_EVERY)
			local now = os.clock()
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(check, player, now)
				if not ok then
					warn("[AntiCheat] " .. tostring(err))
				end
			end
		end
	end)
end

return AntiCheat
