-- Grupos (party) no mundo aberto: até MAX jogadores, convite pelo botão "Grupo" em cima de outro jogador.
--   * Recompensa compartilhada: colegas vivos perto do abate também ganham XP, ouro e o próprio loot,
--     e cada colega por perto dá +10% de XP (init.server → EnemyService.OnKilled).
--   * Chat do grupo: um TextChannel por grupo ("Grupo<id>"); o cliente manda com /g ou /grupo.
--   * O cliente recebe { leader, members = { { id, name, level, class } } } no payload (`party`); vida e
--     posição dos colegas ele lê direto dos personagens (já replicados).
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local PlayerService = require(script.Parent.PlayerService)

local PartyService = {}

PartyService.MAX = 5
PartyService.SHARE_RANGE = 100 -- studs: colega mais longe que isso não divide o abate
PartyService.XP_PER_MATE = 0.1

local INVITE_TIME = 30
local parties = {} -- [id] = { id, leader, members = { player... }, channel }
local partyOf = {} -- [player] = party
local invites = {} -- [convidado] = { from, time }
local lastInvite = {} -- [player] = os.clock() (evita spam de convite)
local nextId = 0
local looking = {} -- [player] = { note, since }: "procurando grupo"

local function markAll(party)
	for _, member in party.members do
		PlayerService.markDirty(member)
	end
end

local function notifyAll(party, text)
	for _, member in party.members do
		Remotes.Notify:FireClient(member, { kind = "message", text = text })
	end
end

-- canal de chat do grupo (TextChatService); falha em silêncio se o chat novo estiver desligado
local function channelAdd(party, player)
	pcall(function()
		if not party.channel then
			local folder = TextChatService:FindFirstChild("TextChannels") or TextChatService
			local channel = Instance.new("TextChannel")
			channel.Name = "Grupo" .. party.id
			channel.Parent = folder
			party.channel = channel
		end
		party.channel:AddUserAsync(player.UserId)
	end)
end

local function channelRemove(party, player)
	pcall(function()
		if party.channel then
			for _, source in party.channel:GetChildren() do
				if source:IsA("TextSource") and source.UserId == player.UserId then
					source:Destroy()
				end
			end
		end
	end)
end

local function disband(party)
	for _, member in party.members do
		partyOf[member] = nil
		PlayerService.markDirty(member)
	end
	if party.channel then
		party.channel:Destroy()
	end
	parties[party.id] = nil
end

local function removeMember(party, player, reason)
	local index = table.find(party.members, player)
	if not index then
		return
	end
	table.remove(party.members, index)
	partyOf[player] = nil
	channelRemove(party, player)
	PlayerService.markDirty(player)
	if #party.members < 2 then
		if party.members[1] and reason then
			Remotes.Notify:FireClient(party.members[1], { kind = "message", text = "O grupo foi desfeito." })
		end
		disband(party)
		return
	end
	if party.leader == player then
		party.leader = party.members[1]
		notifyAll(party, ("%s agora é o líder do grupo."):format(party.leader.DisplayName))
	end
	if reason then
		notifyAll(party, reason)
	end
	markAll(party)
end

local function addMember(party, player)
	looking[player] = nil
	table.insert(party.members, player)
	partyOf[player] = party
	channelAdd(party, player)
	markAll(party)
end

-- ===================== CONSULTAS =====================

function PartyService.get(player)
	return partyOf[player]
end

-- membros do grupo (ou só o próprio jogador)
function PartyService.members(player)
	local party = partyOf[player]
	return if party then party.members else { player }
end

local function rootOf(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and humanoid and humanoid.Health > 0 then
		return root
	end
	return nil
end

-- colegas vivos perto de uma posição (inclui o próprio jogador se estiver perto)
function PartyService.nearbyMembers(player, position)
	local list = {}
	for _, member in PartyService.members(player) do
		local root = rootOf(member)
		if root and (root.Position - position).Magnitude <= PartyService.SHARE_RANGE then
			table.insert(list, member)
		end
	end
	return list
end

-- multiplicador de XP por jogar junto (cada colega por perto +10%)
function PartyService.xpBonus(player, position)
	local count = #PartyService.nearbyMembers(player, position)
	return 1 + math.max(0, count - 1) * PartyService.XP_PER_MATE
end

-- payload para a interface
function PartyService.payload(player)
	local party = partyOf[player]
	if not party then
		return nil
	end
	local members = {}
	for _, member in party.members do
		local data = DataService.get(member)
		table.insert(members, {
			id = member.UserId,
			name = member.DisplayName,
			level = data and data.level or 1,
			class = data and data.class or "",
		})
	end
	return { leader = party.leader.UserId, id = party.id, members = members }
end

-- ===================== PEDIDOS =====================

function PartyService.invite(player, targetId)
	local target = typeof(targetId) == "number" and Players:GetPlayerByUserId(targetId)
	if not target or target == player then
		return { ok = false, msg = "Jogador não encontrado." }
	end
	local party = partyOf[player]
	if party and party.leader ~= player then
		return { ok = false, msg = "Só o líder pode convidar." }
	end
	if party and #party.members >= PartyService.MAX then
		return { ok = false, msg = ("O grupo está cheio (%d)."):format(PartyService.MAX) }
	end
	if partyOf[target] and partyOf[target] == party then
		return { ok = false, msg = "Esse jogador já está no seu grupo." }
	end
	if os.clock() - (lastInvite[player] or 0) < 3 then
		return { ok = false, msg = "Espere um pouco antes de convidar de novo." }
	end
	lastInvite[player] = os.clock()
	invites[target] = { from = player, time = os.clock() }
	Remotes.Notify:FireClient(target, { kind = "partyInvite", from = player.DisplayName, fromId = player.UserId })
	return { ok = true, msg = ("Convite enviado para %s."):format(target.DisplayName) }
end

function PartyService.respond(player, fromId, accept)
	local invite = invites[player]
	invites[player] = nil
	if not invite or invite.from.UserId ~= fromId or os.clock() - invite.time > INVITE_TIME or invite.from.Parent ~= Players then
		return { ok = false, msg = "O convite expirou." }
	end
	if accept ~= true then
		Remotes.Notify:FireClient(invite.from, { kind = "message", text = ("%s recusou o convite."):format(player.DisplayName) })
		return { ok = true }
	end
	local inviter = invite.from
	local party = partyOf[inviter]
	if party and #party.members >= PartyService.MAX then
		return { ok = false, msg = "O grupo já está cheio." }
	end
	-- sai do grupo antigo, se tiver
	if partyOf[player] then
		removeMember(partyOf[player], player, ("%s saiu do grupo."):format(player.DisplayName))
	end
	if not party then
		nextId += 1
		party = { id = nextId, leader = inviter, members = {} }
		parties[party.id] = party
		addMember(party, inviter)
	end
	addMember(party, player)
	notifyAll(party, ("%s entrou no grupo. Use /g para falar com o grupo."):format(player.DisplayName))
	return { ok = true }
end

function PartyService.leave(player)
	local party = partyOf[player]
	if not party then
		return { ok = false, msg = "Você não está num grupo." }
	end
	removeMember(party, player, ("%s saiu do grupo."):format(player.DisplayName))
	return { ok = true }
end

function PartyService.kick(player, targetId)
	local party = partyOf[player]
	local target = typeof(targetId) == "number" and Players:GetPlayerByUserId(targetId)
	if not party or party.leader ~= player then
		return { ok = false, msg = "Só o líder pode tirar alguém do grupo." }
	end
	if not target or partyOf[target] ~= party or target == player then
		return { ok = false, msg = "Jogador não está no grupo." }
	end
	Remotes.Notify:FireClient(target, { kind = "message", text = "Você foi removido do grupo." })
	removeMember(party, target, ("%s foi removido do grupo."):format(target.DisplayName))
	return { ok = true }
end

-- ===================== PROCURAR GRUPO =====================

-- liga/desliga "procurando grupo" (com um recado curto: "masmorra", "chefe de mundo"...)
function PartyService.setLooking(player, on, note)
	if on == true then
		local text = if typeof(note) == "string" then string.sub(note, 1, 40) else ""
		looking[player] = { note = text, since = os.time() }
		return { ok = true, msg = "Você aparece na lista de quem procura grupo." }
	end
	looking[player] = nil
	return { ok = true }
end

-- lista de quem procura grupo (sem quem já está num grupo cheio)
function PartyService.lookingList(player)
	local list = {}
	for other, info in looking do
		if other.Parent == Players and other ~= player then
			local party = partyOf[other]
			if not party or #party.members < PartyService.MAX then
				local data = DataService.get(other)
				table.insert(list, { id = other.UserId, name = other.DisplayName, level = data and data.level or 1, class = data and data.class or "", note = info.note, grouped = party ~= nil })
			end
		end
	end
	table.sort(list, function(a, b)
		return a.level > b.level
	end)
	return { ok = true, list = list, mine = looking[player] ~= nil }
end

function PartyService.onPlayerRemoving(player)
	looking[player] = nil
	invites[player] = nil
	lastInvite[player] = nil
	local party = partyOf[player]
	if party then
		removeMember(party, player, ("%s saiu do jogo."):format(player.DisplayName))
	end
end

return PartyService
