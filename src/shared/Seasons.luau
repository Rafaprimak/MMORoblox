-- Temporadas e eventos sazonais (dados puros, iguais no servidor e no cliente).
--   * Temporada: 8 semanas a partir de Seasons.Epoch. Recomeça o Passe do Hunter e a pontuação da Arena.
--   * Eventos por data (UTC): enfeites na vila, bônus e um título do evento (EventService).
local Seasons = {}

Seasons.Epoch = 1767225600 -- 2026-01-01 00:00 UTC
Seasons.Length = 8 * 7 * 86400

-- nome e cor de cada temporada (repete em ciclo)
Seasons.Themes = {
	{ name = "Brasas", color = Color3.fromRGB(255, 130, 60) },
	{ name = "Marés", color = Color3.fromRGB(80, 170, 255) },
	{ name = "Raízes", color = Color3.fromRGB(110, 210, 110) },
	{ name = "Geada", color = Color3.fromRGB(170, 225, 255) },
	{ name = "Tempestade", color = Color3.fromRGB(190, 150, 255) },
	{ name = "Eclipse", color = Color3.fromRGB(255, 90, 120) },
}

function Seasons.index(time)
	return math.max(1, math.floor(((time or os.time()) - Seasons.Epoch) / Seasons.Length) + 1)
end

function Seasons.info(time)
	time = time or os.time()
	local index = Seasons.index(time)
	local theme = Seasons.Themes[(index - 1) % #Seasons.Themes + 1]
	local ends = Seasons.Epoch + index * Seasons.Length
	return { index = index, name = ("Temporada %d: %s"):format(index, theme.name), short = theme.name, color = theme.color, endsIn = ends - time }
end

-- ===================== EVENTOS SAZONAIS =====================
-- from/to = { mês, dia } (inclusive; pode atravessar o ano). bonus soma em XP/ouro/drop.
-- goal: abates durante o evento para ganhar o título do evento.
-- ícones: "pumpkin", "pine-tree", "party-flags", "campfire"
Seasons.Events = {
	{
		id = "halloween",
		name = "Noite das Abóboras",
		icon = "pumpkin",
		color = Color3.fromRGB(255, 140, 40),
		from = { 10, 15 },
		to = { 11, 5 },
		text = "Abóboras acesas pela vila, noites mais longas e +25% de XP à noite. Derrote 150 inimigos para ganhar o título do evento.",
		bonus = { nightXp = 0.25 },
		goal = 150,
		title = "cacador_aboboras",
		reward = { gold = 1500, chest = "prata" },
	},
	{
		id = "natal",
		name = "Festival de Inverno",
		icon = "pine-tree",
		color = Color3.fromRGB(120, 220, 255),
		from = { 12, 10 },
		to = { 1, 6 },
		text = "Neve na vila, a grande árvore na praça e +20% de ouro. Derrote 150 inimigos para ganhar o título do evento.",
		bonus = { gold = 0.2 },
		goal = 150,
		title = "espirito_inverno",
		reward = { gold = 1500, chest = "prata" },
	},
	{
		id = "carnaval",
		name = "Carnaval de Aurora",
		icon = "party-flags",
		color = Color3.fromRGB(255, 90, 200),
		from = { 2, 5 },
		to = { 2, 25 },
		text = "Confete e fitas coloridas na vila e +15% de XP. Derrote 150 inimigos para ganhar o título do evento.",
		bonus = { xp = 0.15 },
		goal = 150,
		title = "folia",
		reward = { gold = 1500, chest = "prata" },
	},
	{
		id = "junina",
		name = "Festa Junina",
		icon = "campfire",
		color = Color3.fromRGB(255, 200, 60),
		from = { 6, 1 },
		to = { 6, 30 },
		text = "Bandeirinhas, fogueira na praça e +15% de chance de drop. Derrote 150 inimigos para ganhar o título do evento.",
		bonus = { drop = 0.15 },
		goal = 150,
		title = "arraia",
		reward = { gold = 1500, chest = "prata" },
	},
}
Seasons.EventsById = {}
for _, event in Seasons.Events do
	Seasons.EventsById[event.id] = event
end

local function dayOfYear(month, day)
	return month * 100 + day
end

-- evento ativo agora (ou nil). "forced" vem do teste no Studio (workspace "EventoForcado").
function Seasons.activeEvent(time, forced)
	if forced and Seasons.EventsById[forced] then
		return Seasons.EventsById[forced]
	end
	local date = os.date("!*t", time or os.time())
	local today = dayOfYear(date.month, date.day)
	for _, event in Seasons.Events do
		local from, to = dayOfYear(event.from[1], event.from[2]), dayOfYear(event.to[1], event.to[2])
		local inside = if from <= to then today >= from and today <= to else today >= from or today <= to
		if inside then
			return event
		end
	end
	return nil
end

-- ano do evento (eventos que atravessam o ano contam como o ano em que começaram)
function Seasons.eventKey(event, time)
	local date = os.date("!*t", time or os.time())
	local year = date.year
	if event.from[1] > event.to[1] and date.month <= event.to[1] then
		year -= 1
	end
	return event.id .. "_" .. year
end

return Seasons
