-- Perks dos equipamentos (estilo Destiny): cada item dropado ou forjado sorteia perks próprios.
-- Quantidade pela raridade (Perks.CountByOrder). "pool" = weapon (armas) ou gear (armaduras e acessórios).
-- Perks com "stats" são bônus fixos (somados como as passivas); os outros têm gatilho no combate
-- (PerkService no servidor). "major" = perk forte, garantido a partir do Lendário.
local Perks = {}

-- índice = ordem da raridade (1 Comum ... 7 Secreto)
Perks.CountByOrder = { 0, 1, 1, 2, 2, 3, 3 }
Perks.MajorFromOrder = 5

Perks.List = {
	-- ===== ARMAS =====
	furia_crescente = { pool = "weapon", major = true, name = "Fúria Crescente", icon = "🔥", text = "Cada abate: +8% de dano por 6s (acumula 3x)." },
	golpe_final = { pool = "weapon", name = "Golpe Final", icon = "🎯", text = "Depois de um abate, os 3 próximos golpes causam +25%." },
	explosao_fatal = { pool = "weapon", major = true, name = "Explosão Fatal", icon = "💥", text = "Inimigos derrotados explodem e ferem quem está perto." },
	sanguessuga = { pool = "weapon", name = "Sanguessuga", icon = "🩸", text = "Cada abate cura 6% da vida." },
	ritmo_perfeito = { pool = "weapon", name = "Ritmo Perfeito", icon = "🥁", text = "Golpes no ritmo causam +20% a mais." },
	contragolpe = { pool = "weapon", name = "Contragolpe", icon = "✋", text = "Depois de aparar: +40% de dano por 4s." },
	abertura = { pool = "weapon", name = "Golpe de Abertura", icon = "⚡", text = "+50% de dano em inimigos com a vida cheia." },
	carrasco = { pool = "weapon", name = "Carrasco", icon = "💀", text = "+30% de dano em inimigos com menos de 30% de vida." },
	eco = { pool = "weapon", major = true, name = "Eco", icon = "🔁", text = "15% de chance de um segundo golpe (50% do dano)." },
	quebra_escudo = { pool = "weapon", name = "Quebra-Escudo", icon = "🔨", text = "+35% de dano na postura." },
	frenesi_combate = { pool = "weapon", name = "Frenesi", icon = "💢", text = "Depois de 8s lutando: +15% de dano." },
	tempestade = { pool = "weapon", major = true, name = "Tempestade", icon = "🌩", text = "Críticos soltam um raio em até 2 inimigos próximos." },
	lamina_toxica = { pool = "weapon", name = "Lâmina Tóxica", icon = "🧪", text = "25% de chance de envenenar." },
	brasa_viva = { pool = "weapon", name = "Brasa Viva", icon = "🔥", text = "25% de chance de queimar." },
	impeto = { pool = "weapon", name = "Ímpeto", icon = "💨", text = "Esquiva perfeita: +30% de dano por 3s." },
	impacto_brutal = { pool = "weapon", major = true, name = "Impacto Brutal", icon = "🌋", text = "Golpe pesado carregado ao máximo solta uma onda de choque." },
	sede_sangue = { pool = "weapon", name = "Sede de Sangue", icon = "❤️", text = "+1% de dano para cada 5% de vida que falta." },
	vampiro = { pool = "weapon", name = "Vampiro", icon = "🦇", text = "3% de roubo de vida.", stats = { lifesteal = 0.03 } },
	afiacao = { pool = "weapon", name = "Afiação", icon = "🗡️", text = "+4% de crítico.", stats = { crit = 0.04 } },
	pesado = { pool = "weapon", name = "Peso Extra", icon = "⚖️", text = "+20% de dano do golpe pesado.", stats = { heavyDamage = 0.2 } },

	-- ===== PERKS DE ASSINATURA (só nos itens exclusivos das masmorras; nunca sorteados) =====
	saqueador = { pool = "weapon", exclusive = "toca", name = "Saqueador da Toca", icon = "💰", text = "+5% de crítico, +15% de ouro e +10% de dano em masmorras.", stats = { crit = 0.05, goldFind = 0.15, dungeonDamage = 0.1 } },
	pele_tunel = { pool = "gear", exclusive = "toca", name = "Pele de Túnel", icon = "🕳", text = "+12% de estamina, +5% de vida e +5% de dano em masmorras.", stats = { stamina = 0.12, health = 0.05, dungeonDamage = 0.05 } },
	ceifa_alma = { pool = "weapon", exclusive = "cripta", name = "Ceifa Espectral", icon = "👻", text = "+4% de roubo de vida, +10% de dano crítico e +15% de dano em masmorras.", stats = { lifesteal = 0.04, critDamage = 0.1, dungeonDamage = 0.15 } },
	mortalha = { pool = "gear", exclusive = "cripta", name = "Mortalha", icon = "⚰", text = "+8% de vida, regenera 0,3% da vida/s e +8% de dano em masmorras.", stats = { health = 0.08, regen = 0.003, dungeonDamage = 0.08 } },
	coracao_magma = { pool = "weapon", exclusive = "abismo", name = "Coração de Magma", icon = "🌋", text = "+25% de dano do golpe pesado, +6% de dano e +20% de dano em masmorras.", stats = { heavyDamage = 0.25, damage = 0.06, dungeonDamage = 0.2 } },
	casca_abissal = { pool = "gear", exclusive = "abismo", name = "Casca Abissal", icon = "🛡", text = "+5% de redução de dano, +10% de vida e +10% de dano em masmorras.", stats = { defense = 0.05, health = 0.1, dungeonDamage = 0.1 } },

	-- ===== ARMADURAS E ACESSÓRIOS =====
	espinhos = { pool = "gear", name = "Espinhos", icon = "🌵", text = "Devolve 25% do dano corpo a corpo recebido." },
	segunda_chance = { pool = "gear", major = true, name = "Segunda Chance", icon = "😇", text = "Um golpe fatal deixa você com 1 de vida (a cada 90s)." },
	adrenalina = { pool = "gear", name = "Adrenalina", icon = "💉", text = "Abaixo de 30% de vida: +20% de dano." },
	muralha = { pool = "gear", name = "Muralha", icon = "🧱", text = "Bloquear gasta 25% menos estamina." },
	recuperacao = { pool = "gear", name = "Recuperação", icon = "💚", text = "Cada abate cura 3% da vida." },
	regeneracao = { pool = "gear", name = "Regeneração", icon = "🌿", text = "Regenera 0,4% da vida por segundo.", stats = { regen = 0.004 } },
	reflexos = { pool = "gear", name = "Reflexos", icon = "👁", text = "+0,04s na janela de aparar.", stats = { parryWindow = 0.04 } },
	folego = { pool = "gear", name = "Fôlego", icon = "💨", text = "+12% de estamina.", stats = { stamina = 0.12 } },
	sorte = { pool = "gear", name = "Sorte do Caçador", icon = "🍀", text = "+8% de ouro e +5% de XP.", stats = { goldFind = 0.08, xpGain = 0.05 } },
	pele_pedra = { pool = "gear", name = "Pele de Pedra", icon = "🗿", text = "-6% de dano recebido.", stats = { defense = 0.06 } },
	fluxo_arcano = { pool = "gear", name = "Fluxo Arcano", icon = "🔮", text = "+15% de mana por segundo.", stats = { manaRegen = 0.15 } },
	provocador = { pool = "gear", name = "Provocador", icon = "😤", text = "+30% de ameaça (bom para tanques).", stats = { threat = 0.3 } },
	maos_sagradas = { pool = "gear", name = "Mãos Sagradas", icon = "🙏", text = "+12% de cura.", stats = { healPower = 0.12 } },
	agilidade = { pool = "gear", name = "Agilidade", icon = "🐆", text = "+6% de velocidade de ataque.", stats = { attackSpeed = 0.06 } },
	vigor = { pool = "gear", name = "Vigor", icon = "❤️", text = "+6% de vida.", stats = { health = 0.06 } },
	foco = { pool = "gear", name = "Foco", icon = "🧠", text = "-6% de recarga das habilidades.", stats = { cooldown = 0.06 } },
}

Perks.ByPool = { weapon = {}, gear = {} }
Perks.MajorByPool = { weapon = {}, gear = {} }
for id, perk in Perks.List do
	perk.id = id
	if perk.exclusive then
		continue -- perk de assinatura: vem fixo no item exclusivo, não entra no sorteio
	end
	table.insert(Perks.ByPool[perk.pool], id)
	if perk.major then
		table.insert(Perks.MajorByPool[perk.pool], id)
	end
end
table.sort(Perks.ByPool.weapon)
table.sort(Perks.ByPool.gear)
table.sort(Perks.MajorByPool.weapon)
table.sort(Perks.MajorByPool.gear)

function Perks.poolForSlot(slot)
	return if slot == "weapon" then "weapon" else "gear"
end

-- Sorteia perks sem repetir. Lendário ou melhor garante um perk forte ("major").
function Perks.roll(slot, rarityOrder, rng)
	rng = rng or Random.new()
	local pool = Perks.poolForSlot(slot)
	local count = Perks.CountByOrder[rarityOrder] or 0
	local result = {}
	if count <= 0 then
		return result
	end
	if rarityOrder >= Perks.MajorFromOrder then
		local majors = Perks.MajorByPool[pool]
		table.insert(result, majors[rng:NextInteger(1, #majors)])
	end
	local options = Perks.ByPool[pool]
	local guard = 0
	while #result < count and guard < 50 do
		guard += 1
		local id = options[rng:NextInteger(1, #options)]
		if not table.find(result, id) then
			table.insert(result, id)
		end
	end
	return result
end

return Perks
