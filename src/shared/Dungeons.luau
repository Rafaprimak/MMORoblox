-- Masmorras instanciadas (o endgame): cada grupo de 1 a 4 jogadores ganha uma cópia só sua, longe do mapa.
-- Cada masmorra tem 20 andares; o andar é montado na hora (um por vez). Limpou o andar, a escada abre e o
-- grupo desce junto. A cada 5 andares há um chefe com baú de recompensa. É sempre uma corrida só (do
-- andar 1 ao 20, sem ponto de retorno) e o grupo só entra quando todos dão "Pronto".
-- Os inimigos ficam mais fortes a cada andar e a vida cresce com o tamanho do grupo (tanque, suporte e
-- dano fazem diferença; ver Classes: role).
-- Cada masmorra tem material próprio (cai de todo inimigo lá dentro), itens exclusivos com perk de
-- assinatura (Perks: exclusive) e a chave da masmorra seguinte, vendidos pelo Mercador de Masmorras.
local World = require(script.Parent.World)
local Points = require(script.Parent.Points)

local Dungeons = {}

local S = World.Scale

Dungeons.Floors = 20
Dungeons.BossEvery = 5
Dungeons.MaxPlayers = 4
Dungeons.HpPerExtraPlayer = 0.7 -- +70% de vida dos inimigos por jogador além do primeiro
Dungeons.PortalRange = 30 -- studs: perto do portal para entrar no grupo/começar
Dungeons.DescendDelay = 8 -- segundos entre limpar o andar e descer (ou "Descer agora")
Dungeons.CloseAfter = 90 -- segundos depois do chefe do andar 20 até a masmorra fechar sozinha

-- pools: inimigos por faixa de andares (1-5, 6-10, 11-15, 16-20); bosses: chefe de cada 5 andares
-- material: moeda da masmorra; key: chave exigida para entrar (gasta pelo líder ao começar)
-- loot: itens exclusivos (Items.Bases com dungeon = id)
local DESIGN = {
	{
		id = "toca",
		name = "Toca dos Goblins",
		icon = "portal",
		text = "Túneis cavados pelos goblins embaixo das colinas do leste. Lá no fundo, o próprio Rei Goblin guarda o saque roubado da vila.",
		minLevel = 5,
		level = 6,
		theme = "caverna",
		x = 180,
		z = -10,
		material = "saque_toca",
		pools = {
			{ "goblin", "goblin", "goblin_arqueiro" },
			{ "goblin", "goblin_arqueiro", "aranha" },
			{ "aranha", "goblin", "javali", "goblin_arqueiro" },
			{ "aranha", "goblin", "goblin_arqueiro", "javali" },
		},
		bosses = { [5] = "capitao_goblin", [10] = "rainha_aranha", [15] = "capitao_goblin", [20] = "rei_goblin" },
		loot = { "faca_saqueador", "machado_tunel", "arco_tunel", "cajado_cristal", "capuz_saqueador", "colete_tunel", "botas_tunel", "anel_saqueador" },
	},
	{
		id = "cripta",
		name = "Cripta Esquecida",
		icon = "coffin",
		text = "Embaixo do cemitério antigo, mortos que não descansam guardam o túmulo do Rei Lich.",
		minLevel = 10,
		level = 12,
		theme = "cripta",
		x = -245,
		z = -105,
		material = "fragmento_alma",
		key = "chave_cripta",
		pools = {
			{ "esqueleto", "esqueleto" },
			{ "esqueleto", "esqueleto_mago" },
			{ "esqueleto", "esqueleto_mago", "aranha" },
			{ "esqueleto_mago", "esqueleto", "golem" },
		},
		bosses = { [5] = "senhor_ossos", [10] = "guardiao_cripta", [15] = "senhor_ossos", [20] = "rei_lich" },
		loot = { "ceifa_espectral", "katana_espectral", "cetro_ossos", "arco_luto", "elmo_vigia", "mortalha_cripta", "grevas_vigia", "amuleto_alma" },
	},
	{
		id = "abismo",
		name = "Abismo de Pedra",
		icon = "volcano",
		text = "Uma fenda de lava no coração das montanhas. Golens despertos e o Colosso do Abismo esperam quem descer até o fim.",
		minLevel = 15,
		level = 16,
		theme = "abismo",
		x = -150,
		z = -215,
		material = "brasa_abissal",
		key = "chave_abismo",
		pools = {
			{ "golem", "aranha", "esqueleto" },
			{ "golem", "esqueleto_mago", "aranha" },
			{ "golem", "esqueleto", "esqueleto_mago", "aranha" },
			{ "golem", "golem", "esqueleto_mago", "esqueleto" },
		},
		bosses = { [5] = "rainha_aranha", [10] = "guardiao_cripta", [15] = "rei_lich", [20] = "colosso_abismo" },
		loot = { "martelo_magma", "lanca_magma", "adagas_brasa", "cajado_magma", "elmo_magma", "casca_abissal", "botas_brasa", "anel_magma" },
	},
}

-- Itens que o Mercador de Masmorras vende: { kind = "key" | "consumable" | "loot", id, gold, material = { id, qtd } }
Dungeons.Shop = {
	{ kind = "consumable", id = "pocao_grande", gold = 120, material = { "saque_toca", 2 } },
	{ kind = "consumable", id = "tonico_pedra", gold = 150, material = { "saque_toca", 3 } },
	{ kind = "consumable", id = "elixir_forca", gold = 200, material = { "fragmento_alma", 2 } },
	{ kind = "key", id = "chave_cripta", gold = 500, material = { "saque_toca", 25 } },
	{ kind = "key", id = "chave_abismo", gold = 1500, material = { "fragmento_alma", 30 } },
}
-- Preço de um item exclusivo (raridade Rara, nível do jogador) no mercador; o material é o da masmorra dele
Dungeons.LootPrice = { gold = 400, material = 40, rarity = "Raro" }

-- Faixa (1 a 4) de um andar
function Dungeons.tier(floor)
	return math.clamp(math.ceil(floor / Dungeons.BossEvery), 1, 4)
end

function Dungeons.isBossFloor(floor)
	return floor % Dungeons.BossEvery == 0
end

-- Força dos inimigos do andar (multiplicadores sobre os valores normais) e quantos aparecem
function Dungeons.floorInfo(dungeon, floor)
	local boss = dungeon.bosses[floor]
	return {
		boss = boss,
		count = if boss then 0 else math.min(9, 3 + math.floor(floor / 3)),
		hpMult = 1 + 0.12 * (floor - 1),
		damageMult = 1 + 0.05 * (floor - 1),
		rewardMult = 1 + 0.1 * (floor - 1),
		pool = dungeon.pools[Dungeons.tier(floor)],
		-- raridade mínima do item que o chefe deixa (andar 5 Incomum ... andar 20 Lendário)
		minRarity = Dungeons.tier(floor) + 1,
	}
end

Dungeons.List = {}
Dungeons.ById = {}
Dungeons.ByMaterial = {}
for _, def in DESIGN do
	local x, z = Points.resolve(def.x * S, def.z * S)
	def.position = Vector3.new(x, World.height(x, z), z)
	table.insert(Dungeons.List, def)
	Dungeons.ById[def.id] = def
	Dungeons.ByMaterial[def.material] = def
end

return Dungeons
