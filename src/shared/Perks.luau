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
	furia_crescente = { pool = "weapon", major = true, name = "Fúria Crescente", icon = "flame", text = "Cada abate: +8% de dano por 6s (acumula 3x)." },
	golpe_final = { pool = "weapon", name = "Golpe Final", icon = "archery-target", text = "Depois de um abate, os 3 próximos golpes causam +25%." },
	explosao_fatal = { pool = "weapon", major = true, name = "Explosão Fatal", icon = "explosion-rays", text = "Inimigos derrotados explodem e ferem quem está perto." },
	sanguessuga = { pool = "weapon", name = "Sanguessuga", icon = "bleeding-wound", text = "Cada abate cura 6% da vida." },
	ritmo_perfeito = { pool = "weapon", name = "Ritmo Perfeito", icon = "drum", text = "Golpes no ritmo causam +20% a mais." },
	contragolpe = { pool = "weapon", name = "Contragolpe", icon = "hand", text = "Depois de aparar: +40% de dano por 4s." },
	abertura = { pool = "weapon", name = "Golpe de Abertura", icon = "lightning-helix", text = "+50% de dano em inimigos com a vida cheia." },
	carrasco = { pool = "weapon", name = "Carrasco", icon = "skull-crack", text = "+30% de dano em inimigos com menos de 30% de vida." },
	eco = { pool = "weapon", major = true, name = "Eco", icon = "cycle", text = "15% de chance de um segundo golpe (50% do dano)." },
	quebra_escudo = { pool = "weapon", name = "Quebra-Escudo", icon = "hammer-drop", text = "+35% de dano na postura." },
	frenesi_combate = { pool = "weapon", name = "Frenesi", icon = "enrage", text = "Depois de 8s lutando: +15% de dano." },
	tempestade = { pool = "weapon", major = true, name = "Tempestade", icon = "lightning-storm", text = "Críticos soltam um raio em até 2 inimigos próximos." },
	lamina_toxica = { pool = "weapon", name = "Lâmina Tóxica", icon = "bubbling-flask", text = "25% de chance de envenenar." },
	brasa_viva = { pool = "weapon", name = "Brasa Viva", icon = "flame", text = "25% de chance de queimar." },
	impeto = { pool = "weapon", name = "Ímpeto", icon = "wind-slap", text = "Esquiva perfeita: +30% de dano por 3s." },
	impacto_brutal = { pool = "weapon", major = true, name = "Impacto Brutal", icon = "volcano", text = "Golpe pesado carregado ao máximo solta uma onda de choque." },
	sede_sangue = { pool = "weapon", name = "Sede de Sangue", icon = "heart-plus", text = "+1% de dano para cada 5% de vida que falta." },
	vampiro = { pool = "weapon", name = "Vampiro", icon = "bat", text = "3% de roubo de vida.", stats = { lifesteal = 0.03 } },
	afiacao = { pool = "weapon", name = "Afiação", icon = "broadsword", text = "+4% de crítico.", stats = { crit = 0.04 } },
	pesado = { pool = "weapon", name = "Peso Extra", icon = "scales", text = "+20% de dano do golpe pesado.", stats = { heavyDamage = 0.2 } },

	-- ===== PERKS DE ASSINATURA (só nos itens exclusivos das masmorras; nunca sorteados) =====
	saqueador = { pool = "weapon", exclusive = "toca", name = "Saqueador da Toca", icon = "two-coins", text = "+5% de crítico, +15% de ouro e +10% de dano em masmorras.", stats = { crit = 0.05, goldFind = 0.15, dungeonDamage = 0.1 } },
	pele_tunel = { pool = "gear", exclusive = "toca", name = "Pele de Túnel", icon = "portal", text = "+12% de estamina, +5% de vida e +5% de dano em masmorras.", stats = { stamina = 0.12, health = 0.05, dungeonDamage = 0.05 } },
	ceifa_alma = { pool = "weapon", exclusive = "cripta", name = "Ceifa Espectral", icon = "spectre", text = "+4% de roubo de vida, +10% de dano crítico e +15% de dano em masmorras.", stats = { lifesteal = 0.04, critDamage = 0.1, dungeonDamage = 0.15 } },
	mortalha = { pool = "gear", exclusive = "cripta", name = "Mortalha", icon = "coffin", text = "+8% de vida, regenera 0,3% da vida/s e +8% de dano em masmorras.", stats = { health = 0.08, regen = 0.003, dungeonDamage = 0.08 } },
	coracao_magma = { pool = "weapon", exclusive = "abismo", name = "Coração de Magma", icon = "volcano", text = "+25% de dano do golpe pesado, +6% de dano e +20% de dano em masmorras.", stats = { heavyDamage = 0.25, damage = 0.06, dungeonDamage = 0.2 } },
	casca_abissal = { pool = "gear", exclusive = "abismo", name = "Casca Abissal", icon = "checked-shield", text = "+5% de redução de dano, +10% de vida e +10% de dano em masmorras.", stats = { defense = 0.05, health = 0.1, dungeonDamage = 0.1 } },

	-- ===== PERKS ÚNICOS (só nos itens Únicos; efeito no PerkService/PlayerService) =====
	eclipse = { pool = "weapon", exclusive = "unique", name = "Eclipse", icon = "moon-orbit", text = "A cada 5 golpes, uma onda de sombra fere tudo em volta (150% do ataque)." },
	sangria = { pool = "weapon", exclusive = "unique", name = "Sangria do Capitão", icon = "bleeding-wound", text = "Todo golpe faz sangrar (30% do golpe em 3 s) e +40% de dano pelas costas.", stats = { backstab = 0.4 } },
	terremoto = { pool = "weapon", exclusive = "unique", name = "Terremoto", icon = "volcano", text = "A cada 4 golpes, o chão treme: 110% do ataque em volta e quebra a guarda." },
	teia_viuva = { pool = "weapon", exclusive = "unique", name = "Beijo da Viúva", icon = "spider-alt", text = "Todo golpe envenena e os críticos saltam para até 3 inimigos." },
	abismo_arcano = { pool = "weapon", exclusive = "unique", name = "Abismo Arcano", icon = "vortex", text = "Cada abate devolve 15% da mana e abre um vórtice que fere quem está perto (120%)." },
	bastiao = { pool = "gear", exclusive = "unique", name = "Bastião", icon = "checked-shield", text = "Bloquear não gasta estamina e devolve 40% do dano bloqueado ao atacante." },
	tirania = { pool = "gear", exclusive = "unique", name = "Tirania", icon = "crown", text = "Recebe 15% menos dano e ganha +25% de ouro.", stats = { goldFind = 0.25 } },
	filacterio = { pool = "gear", exclusive = "unique", name = "Filactério", icon = "skull-crack", text = "Um golpe fatal faz você voltar com 50% da vida (a cada 120 s)." },
	-- ===== EXÓTICOS (missões depois do nível 20; só um item exótico equipado por vez) =====
	ciclo_eterno = { pool = "weapon", exclusive = "exotic", major = true, name = "Ciclo Eterno", icon = "cycle", text = "A cada 6 golpes o tempo volta e o golpe se repete com 100% do dano. +10% de dano crítico.", stats = { critDamage = 0.1 } },
	egide = { pool = "gear", exclusive = "exotic", major = true, name = "Égide de Aurora", icon = "barrier", text = "Ao levar um golpe: 25% menos dano por 4 s e cura 5% da vida (a cada 12 s)." },
	arquimagos = { pool = "gear", exclusive = "exotic", major = true, name = "Saber dos Arquimagos", icon = "wizard-staff", text = "+30% de dano das habilidades e +25% de dano contra chefes.", stats = { abilityDamage = 0.3 } },
	passos_tempo = { pool = "gear", exclusive = "exotic", major = true, name = "Passos do Tempo", icon = "hourglass", text = "Esquiva perfeita para o tempo: os 3 golpes seguintes são críticos garantidos." },
	coracao_partido = { pool = "gear", exclusive = "exotic", major = true, name = "Coração Partido", icon = "broken-heart", text = "Abates explodem em luz estelar (80% do ataque em volta) e curam 5% da vida." },
	caca_infinita = { pool = "gear", exclusive = "exotic", major = true, name = "Caçada Infinita", icon = "wolf-howl", text = "Cada abate dá +2% de dano por 20 s (acumula até +40%)." },
	colecionador = { pool = "gear", exclusive = "exotic", major = true, name = "Colecionador", icon = "open-treasure-chest", text = "+35% de ouro, +25% de chance de drop e +20% de XP.", stats = { goldFind = 0.35, dropFind = 0.25, xpGain = 0.2 } },
	horizonte = { pool = "gear", exclusive = "exotic", major = true, name = "Horizonte", icon = "horizon-road", text = "+25% de dano em alvos a mais de 15 studs e +15% de XP.", stats = { xpGain = 0.15 } },
	-- ===== BÔNUS DE CONJUNTO (4 peças; ver Items.Sets) =====
	chuva_estelar = { pool = "weapon", exclusive = "raide", major = true, name = "Chuva Estelar", icon = "falling-star", text = "12% de chance por golpe de uma estrela cair no alvo: 120% de dano em área. +8% de dano crítico.", stats = { critDamage = 0.08 } },
	manto_estelar = { pool = "gear", exclusive = "raide", name = "Manto Estelar", icon = "galaxy", text = "+8% de vida, +5% de defesa e +8% de dano das habilidades.", stats = { health = 0.08, defense = 0.05, abilityDamage = 0.08 } },
	nucleo_estelar = { pool = "gear", exclusive = "set", name = "Núcleo Estelar", icon = "star-swirl", text = "Golpe fatal: uma explosão estelar cura 30% da vida e empurra os inimigos (a cada 60 s)." },
	pilhagem = { pool = "gear", exclusive = "set", name = "Pilhagem", icon = "two-coins", text = "Inimigos em masmorras deixam o dobro de material." },
	pacto_espectral = { pool = "gear", exclusive = "set", name = "Pacto Espectral", icon = "spectre", text = "Cada abate cura 5% da vida." },
	erupcao = { pool = "gear", exclusive = "set", name = "Erupção", icon = "flame", text = "Inimigos derrotados explodem em lava (80% do ataque em volta)." },

	-- ===== ARMADURAS E ACESSÓRIOS =====
	espinhos = { pool = "gear", name = "Espinhos", icon = "cactus", text = "Devolve 25% do dano corpo a corpo recebido." },
	segunda_chance = { pool = "gear", major = true, name = "Segunda Chance", icon = "angel-wings", text = "Um golpe fatal deixa você com 1 de vida (a cada 90s)." },
	adrenalina = { pool = "gear", name = "Adrenalina", icon = "syringe", text = "Abaixo de 30% de vida: +20% de dano." },
	muralha = { pool = "gear", name = "Muralha", icon = "brick-wall", text = "Bloquear gasta 25% menos estamina." },
	recuperacao = { pool = "gear", name = "Recuperação", icon = "health-normal", text = "Cada abate cura 3% da vida." },
	regeneracao = { pool = "gear", name = "Regeneração", icon = "herbs-bundle", text = "Regenera 0,4% da vida por segundo.", stats = { regen = 0.004 } },
	reflexos = { pool = "gear", name = "Reflexos", icon = "eyeball", text = "+0,04s na janela de aparar.", stats = { parryWindow = 0.04 } },
	folego = { pool = "gear", name = "Fôlego", icon = "wind-slap", text = "+12% de estamina.", stats = { stamina = 0.12 } },
	sorte = { pool = "gear", name = "Sorte do Caçador", icon = "clover", text = "+8% de ouro e +5% de XP.", stats = { goldFind = 0.08, xpGain = 0.05 } },
	pele_pedra = { pool = "gear", name = "Pele de Pedra", icon = "moai", text = "-6% de dano recebido.", stats = { defense = 0.06 } },
	fluxo_arcano = { pool = "gear", name = "Fluxo Arcano", icon = "crystal-ball", text = "+15% de mana por segundo.", stats = { manaRegen = 0.15 } },
	provocador = { pool = "gear", name = "Provocador", icon = "enrage", text = "+30% de ameaça (bom para tanques).", stats = { threat = 0.3 } },
	maos_sagradas = { pool = "gear", name = "Mãos Sagradas", icon = "prayer", text = "+12% de cura.", stats = { healPower = 0.12 } },
	agilidade = { pool = "gear", name = "Agilidade", icon = "feline", text = "+6% de velocidade de ataque.", stats = { attackSpeed = 0.06 } },
	vigor = { pool = "gear", name = "Vigor", icon = "heart-plus", text = "+6% de vida.", stats = { health = 0.06 } },
	foco = { pool = "gear", name = "Foco", icon = "brain", text = "-6% de recarga das habilidades.", stats = { cooldown = 0.06 } },
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
