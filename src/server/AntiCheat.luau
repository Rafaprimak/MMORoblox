-- Proteções contra trapaça (o cliente nunca é confiável). Cobre os hacks mais comuns do Roblox:
--   * Spam de rede / auto-clicker: cada canal (Action/Request) tem um "balde" de fichas por jogador.
--     Passou do limite, o pedido é ignorado; abusar sem parar desconecta.
--   * Argumentos forjados: AntiCheat.validArgs recusa tipos estranhos, NaN/infinito, textos e tabelas
--     enormes ou fundas demais (evita erros e travamentos provocados de propósito).
--   * Speed hack / teleporte: a cada meio segundo compara a distância andada com a velocidade máxima
--     possível (corrida, cavalo, esquiva). Rápido demais volta para o último lugar válido.
--   * Atravessar paredes (noclip): 20x por segundo um raio liga a posição anterior à atual; se cruzar
--     uma parede sólida (peça grande, de pé), volta para antes da parede.
--   * Voo, pulo infinito e super pulo: o servidor mede a altura até o chão. No ar, não pode subir mais
--     que um pulo acima de onde decolou, nem ficar flutuando (cair devagar demais).
--   * Arremesso (fling): jogadores não colidem entre si e giro absurdo da raiz é zerado.
--   * Personagem desmontado (god mode por apagar o Humanoid/raiz): o personagem é recriado.
--   * Serviços de longe: forja, loja, encantador, alquimista e Mercador de Masmorras só respondem
--     perto do NPC (AntiCheat.ServiceActions + AntiCheat.nearService); conversa idem.
-- Teleportes e saltos do próprio servidor (viagem, masmorra, Piscar, pancada...) chamam
-- AntiCheat.allowTeleport / AntiCheat.allowAir antes, para não serem confundidos com trapaça.
-- Não exige nenhum serviço do servidor (qualquer um pode exigir este).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local NPCs = require(Shared.NPCs)

local AntiCheat = {}

local IS_STUDIO = RunService:IsStudio()

-- ===================== LIMITE DE PEDIDOS =====================
-- rate = fichas por segundo, burst = máximo guardado
local LIMITS = {
	action = { rate = 25, burst = 45 }, -- golpes, esquiva, bloqueio, habilidades...
	request = { rate = 12, burst = 30 }, -- janelas (equipar, comprar, forjar, trocar...)
}
local KICK_DROPS = 400 -- pedidos ignorados em KICK_WINDOW segundos = desconecta
local KICK_WINDOW = 30

local buckets = {} -- [player] = { [nome] = { tokens, last } , drops, dropsSince }

local function kick(player, reason)
	warn(("[AntiCheat] %s: %s"):format(player.Name, reason))
	if not IS_STUDIO then
		player:Kick("Atividade suspeita detectada.")
	end
end

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
	if entry.drops >= KICK_DROPS then
		entry.drops = 0
		kick(player, "excedeu o limite de pedidos (" .. kind .. ")")
	end
	return false
end

-- ===================== ARGUMENTOS =====================
local MAX_STRING = 200
local MAX_TABLE_KEYS = 64
local MAX_DEPTH = 3

local function finite(n)
	return n == n and n ~= math.huge and n ~= -math.huge
end

local function validValue(value, depth)
	local kind = typeof(value)
	if kind == "nil" or kind == "boolean" then
		return true
	elseif kind == "number" then
		return finite(value)
	elseif kind == "string" then
		return #value <= MAX_STRING
	elseif kind == "Vector3" then
		return finite(value.X) and finite(value.Y) and finite(value.Z) and value.Magnitude < 1e6
	elseif kind == "table" then
		if depth >= MAX_DEPTH or getmetatable(value) ~= nil then
			return false
		end
		local count = 0
		for key, inner in value do
			count += 1
			local keyKind = typeof(key)
			if count > MAX_TABLE_KEYS or (keyKind ~= "string" and keyKind ~= "number") or not validValue(key, depth + 1) or not validValue(inner, depth + 1) then
				return false
			end
		end
		return true
	end
	return false -- Instance, CFrame, função... nenhum pedido nosso usa
end

-- true se todos os argumentos vindos do cliente têm formato aceitável
function AntiCheat.validArgs(...)
	for i = 1, select("#", ...) do
		if not validValue((select(i, ...)), 0) then
			return false
		end
	end
	return true
end

-- ===================== SERVIÇOS DOS NPCs =====================
-- pedido → serviço do NPC que precisa estar perto (as janelas abrem conversando com ele)
AntiCheat.ServiceActions = {
	forge = "forge",
	upgrade = "forge",
	reforge = "forge",
	enchant = "enchant",
	disassemble = "enchant",
	alchemy = "alchemy",
	buy = "shop",
	sellMaterial = "shop",
	dungeonBuy = "dungeon",
	dungeonBuyLoot = "dungeon",
	marketSell = "market",
	marketBuy = "market",
	marketCancel = "market",
	marketBrowse = "market",
	marketMine = "market",
	guildCreate = "guild",
}
local SERVICE_RANGE = 40 -- studs (folga para quem anda um pouco com a janela aberta)

local function horizontalDistance(root, x, z)
	local dx, dz = root.Position.X - x, root.Position.Z - z
	return math.sqrt(dx * dx + dz * dz)
end

local function rootOf(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

-- true se o jogador está perto de algum NPC que oferece o serviço
function AntiCheat.nearService(player, service)
	local root = rootOf(player)
	if not root then
		return false
	end
	for _, npc in NPCs.List do
		if npc.services and npc.x and table.find(npc.services, service) and horizontalDistance(root, npc.x, npc.z) <= SERVICE_RANGE then
			return true
		end
	end
	return false
end

-- true se o jogador está perto do NPC (quadros de aviso sem posição fixa sempre passam)
function AntiCheat.nearNpc(player, npcId)
	local npc = NPCs.ById[npcId]
	local root = rootOf(player)
	if not npc or not root then
		return false
	end
	if not npc.x then
		return true
	end
	return horizontalDistance(root, npc.x, npc.z) <= SERVICE_RANGE
end

-- ===================== MOVIMENTO =====================
local SAMPLE_EVERY = 0.05 -- voo, paredes, arremesso
local SPEED_EVERY = 0.5 -- velocidade
local BURST = 32 -- folga para esquiva + investida (~25 studs) e para o atraso da rede
local TOLERANCE = 1.45 -- folga sobre a velocidade máxima
local RISE_SPEED = 90 -- subida máxima (studs/s) fora de pulo normal
local AIR_HEIGHT = 8.5 -- raiz mais alta que isso acima do chão = no ar (montado: + MOUNT_RAISE)
local MOUNT_RAISE = 3
local JUMP_ALLOWANCE = 11 -- quanto pode subir acima do ponto de decolagem (pulo ~6,4 + folga)
local HOVER_TIME = 2.2 -- segundos no ar...
local HOVER_DROP = 8 -- ...caindo menos que isso = flutuando
local WALL_MIN_SIZE = 6 -- só paredes de verdade (árvores, postes e barris dá para contornar)
local MAX_SPIN = 50 -- rad/s na raiz: acima disso é arremesso
local VIOLATION_WINDOW = 60
local VIOLATIONS_TO_KICK = 45
local MISSING_PARTS_TIME = 1.5 -- personagem sem Humanoid/raiz por mais que isso = recria

local tracks = {} -- [player] = estado do movimento

local function trackOf(player)
	local track = tracks[player]
	if not track then
		track = { violations = 0, violationsSince = os.clock() }
		tracks[player] = track
	end
	return track
end

local function resetTrack(track)
	track.lastValid = nil
	track.prevPos = nil
	track.groundPos = nil
	track.airSince = nil
	track.takeoffY = nil
end

-- O servidor vai mover o personagem (viagem, masmorra, Piscar...): não conta como trapaça
function AntiCheat.allowTeleport(player, seconds)
	local track = trackOf(player)
	track.allowUntil = os.clock() + (seconds or 2)
	resetTrack(track)
end

-- O servidor vai lançar o jogador para o alto (pancada no chão...): só a checagem de voo descansa
function AntiCheat.allowAir(player, seconds)
	local track = trackOf(player)
	track.airUntil = os.clock() + (seconds or 1.5)
end

local function maxSpeed(player)
	if player:GetAttribute("Mounted") then
		return Config.MountSpeed
	end
	return Config.SprintSpeed
end

-- raios ignoram personagens, inimigos e itens no chão
local function rayParams(includeTerrain)
	local ignore = {}
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	for _, name in { "Inimigos", "Drops" } do
		local folder = workspace:FindFirstChild(name)
		if folder then
			table.insert(ignore, folder)
		end
	end
	if not includeTerrain then
		table.insert(ignore, workspace.Terrain)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	params.IgnoreWater = false
	return params
end

-- volta o personagem para um lugar seguro
local function snapBack(player, character, root, position, reason)
	local track = trackOf(player)
	local now = os.clock()
	if now - track.violationsSince > VIOLATION_WINDOW then
		track.violations, track.violationsSince = 0, now
	end
	track.violations += 1
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	character:PivotTo(CFrame.new(position) * (root.CFrame - root.CFrame.Position))
	resetTrack(track)
	track.lastValid, track.lastTime = position, now
	track.prevPos, track.groundPos = position, position
	if track.violations % 6 == 0 then
		warn(("[AntiCheat] %s: %s (%d vezes no último minuto)"):format(player.Name, reason, track.violations))
	end
	if track.violations >= VIOLATIONS_TO_KICK then
		track.violations = 0
		kick(player, "movimento impossível repetido (" .. reason .. ")")
	end
end

-- atravessou uma parede entre a amostra anterior e a atual?
local function crossedWall(from, to, params)
	local offset = to - from
	if offset.Magnitude < 0.3 then
		return false
	end
	local hit = workspace:Raycast(from, offset, params)
	if not hit or not hit.Instance:IsA("BasePart") then
		return false
	end
	local part = hit.Instance
	if math.abs(hit.Normal.Y) > 0.5 or not part.Anchored or math.max(part.Size.X, part.Size.Z) < WALL_MIN_SIZE then
		return false -- piso/telhado, peça solta ou peça pequena
	end
	-- a posição nova ficou atrás da face atingida (dentro ou do outro lado da parede)
	return (to - hit.Position):Dot(hit.Normal) < -0.2
end

local function sample(player, now, wallParams, groundParams)
	local character = player.Character
	if not character or not character.Parent then
		return
	end
	local track = trackOf(player)
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	-- personagem sem peças essenciais (apagadas pelo cliente): recria
	if not root or not humanoid then
		track.missingSince = track.missingSince or now
		if now - track.missingSince > MISSING_PARTS_TIME then
			track.missingSince = nil
			warn(("[AntiCheat] %s ficou sem Humanoid/raiz; recriando o personagem"):format(player.Name))
			pcall(player.LoadCharacter, player)
		end
		return
	end
	track.missingSince = nil
	if humanoid.Health <= 0 then
		return
	end

	-- arremesso: giro absurdo
	if root.AssemblyAngularVelocity.Magnitude > MAX_SPIN then
		root.AssemblyAngularVelocity = Vector3.zero
	end

	local position = root.Position
	if (track.allowUntil and now < track.allowUntil) or not track.prevPos then
		track.prevPos, track.lastValid, track.lastTime = position, position, now
		track.groundPos, track.airSince, track.takeoffY = position, nil, nil
		return
	end

	-- 1) paredes
	if crossedWall(track.prevPos, position, wallParams) then
		snapBack(player, character, root, track.prevPos, "atravessou parede")
		return
	end

	-- 2) voo / pulo infinito / super pulo
	local mounted = player:GetAttribute("Mounted") == true
	local airLimit = AIR_HEIGHT + (if mounted then MOUNT_RAISE else 0)
	-- o raio sai um pouco acima da raiz para achar a superfície da água (nadando = no chão)
	local below = workspace:Raycast(position + Vector3.new(0, 4, 0), Vector3.new(0, -64, 0), groundParams)
	local height = if below then position.Y - below.Position.Y else math.huge
	if below and below.Material == Enum.Material.Water then
		height = 0
	end
	local airFree = track.airUntil and now < track.airUntil
	if height <= airLimit or airFree then
		track.airSince, track.takeoffY = nil, nil
		if height <= airLimit then
			track.groundPos = position
		end
	else
		if not track.airSince then
			track.airSince = now
			track.takeoffY = if track.groundPos then track.groundPos.Y else position.Y
		end
		local airTime = now - track.airSince
		local tooHigh = position.Y > track.takeoffY + JUMP_ALLOWANCE
		local hovering = airTime > HOVER_TIME and position.Y > track.takeoffY - HOVER_DROP
		if (tooHigh or hovering) and track.groundPos then
			snapBack(player, character, root, track.groundPos, if tooHigh then "subiu no ar" else "flutuando")
			return
		end
	end
	track.prevPos = position

	-- 3) velocidade (janela de meio segundo)
	local dt = now - (track.lastTime or now)
	if dt < SPEED_EVERY then
		return
	end
	local offset = position - track.lastValid
	local horizontal = Vector3.new(offset.X, 0, offset.Z).Magnitude
	local allowed = maxSpeed(player) * TOLERANCE * dt + BURST
	if horizontal > allowed or (offset.Y / dt > RISE_SPEED and not airFree) then
		snapBack(player, character, root, track.lastValid, "rápido demais")
		return
	end
	track.lastValid, track.lastTime = position, now
end

-- ===================== PERSONAGEM =====================
local GROUP = "Jogadores"

local function setGroup(part)
	if part:IsA("BasePart") then
		part.CollisionGroup = GROUP
	end
end

function AntiCheat.onCharacterAdded(player)
	AntiCheat.allowTeleport(player, 3) -- nascer/renascer
	local character = player.Character
	if character then
		-- jogadores não se empurram (impede arremessar os outros)
		for _, part in character:GetDescendants() do
			setGroup(part)
		end
		character.DescendantAdded:Connect(setGroup)
	end
end

function AntiCheat.start()
	pcall(function()
		PhysicsService:RegisterCollisionGroup(GROUP)
		PhysicsService:CollisionGroupSetCollidable(GROUP, GROUP, false)
	end)
	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
		tracks[player] = nil
	end)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < SAMPLE_EVERY then
			return
		end
		elapsed = 0
		local now = os.clock()
		local wallParams, groundParams = rayParams(false), rayParams(true)
		for _, player in Players:GetPlayers() do
			local ok, err = pcall(sample, player, now, wallParams, groundParams)
			if not ok then
				warn("[AntiCheat] " .. tostring(err))
			end
		end
	end)
end

return AntiCheat
