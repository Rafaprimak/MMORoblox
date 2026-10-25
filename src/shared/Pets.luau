-- Pets: seguem o jogador e dão bônus (somados como as passivas). Sobem de nível com os abates.
-- Saem de ovos comprados com OURO do jogo no Otto (chances sempre visíveis) ou, raramente, de Elites e chefes.
local Pets = {}

Pets.MaxLevel = 20
Pets.MaxOwned = 30

-- shape decide o modelo blocado no cliente (PetRenderer); fly = flutua
Pets.List = {
	slime = { name = "Slime", icon = "🟢", rarity = "Comum", shape = "slime", color = Color3.fromRGB(110, 220, 110), accent = Color3.fromRGB(60, 150, 60), stats = { xpGain = 0.03 } },
	gato = { name = "Gato", icon = "🐱", rarity = "Comum", shape = "quadruped", color = Color3.fromRGB(240, 170, 90), accent = Color3.fromRGB(255, 240, 220), ears = "pointy", stats = { crit = 0.01 } },
	cachorro = { name = "Cachorro", icon = "🐶", rarity = "Comum", shape = "quadruped", color = Color3.fromRGB(170, 120, 80), accent = Color3.fromRGB(240, 230, 210), ears = "floppy", stats = { health = 0.03 } },
	coelho = { name = "Coelho", icon = "🐰", rarity = "Incomum", shape = "bunny", color = Color3.fromRGB(245, 245, 250), accent = Color3.fromRGB(255, 170, 190), stats = { stamina = 0.05 } },
	coruja = { name = "Coruja", icon = "🦉", rarity = "Incomum", shape = "bird", fly = true, color = Color3.fromRGB(150, 110, 70), accent = Color3.fromRGB(255, 220, 120), stats = { xpGain = 0.06 } },
	raposa = { name = "Raposa", icon = "🦊", rarity = "Raro", shape = "quadruped", color = Color3.fromRGB(240, 120, 40), accent = Color3.fromRGB(255, 250, 245), ears = "pointy", tail = "big", stats = { goldFind = 0.08 } },
	tartaruga = { name = "Tartaruga", icon = "🐢", rarity = "Raro", shape = "turtle", color = Color3.fromRGB(110, 170, 90), accent = Color3.fromRGB(120, 90, 60), stats = { defense = 0.03 } },
	lobo_espiritual = { name = "Lobo Espiritual", icon = "🐺", rarity = "Epico", shape = "quadruped", color = Color3.fromRGB(150, 200, 255), accent = Color3.fromRGB(230, 245, 255), ears = "pointy", glow = true, stats = { damage = 0.05 } },
	golem_mini = { name = "Mini Golem", icon = "🗿", rarity = "Epico", shape = "golem", color = Color3.fromRGB(140, 135, 125), accent = Color3.fromRGB(255, 160, 60), stats = { health = 0.08, threat = 0.1 } },
	fada = { name = "Fada da Luz", icon = "💫", rarity = "Epico", shape = "wisp", fly = true, color = Color3.fromRGB(255, 240, 170), accent = Color3.fromRGB(200, 255, 230), glow = true, stats = { healPower = 0.1, manaRegen = 0.1 } },
	dragao_bebe = { name = "Dragão Bebê", icon = "🐉", rarity = "Lendario", shape = "dragon", fly = true, color = Color3.fromRGB(200, 60, 60), accent = Color3.fromRGB(255, 200, 80), stats = { damage = 0.08, crit = 0.02 } },
	unicornio = { name = "Unicórnio", icon = "🦄", rarity = "Lendario", shape = "quadruped", color = Color3.fromRGB(250, 245, 255), accent = Color3.fromRGB(255, 160, 230), ears = "pointy", tail = "big", glow = true, stats = { health = 0.1, regen = 0.003 } },
	tigre_celeste = { name = "Tigre Celeste", icon = "🐯", rarity = "Lendario", shape = "quadruped", color = Color3.fromRGB(120, 200, 255), accent = Color3.fromRGB(30, 40, 80), ears = "pointy", tail = "big", glow = true, stats = { damage = 0.08, attackSpeed = 0.04 } },
	dragao_sombrio = { name = "Dragão Sombrio", icon = "🐲", rarity = "Mitico", shape = "dragon", fly = true, color = Color3.fromRGB(60, 30, 90), accent = Color3.fromRGB(190, 110, 255), glow = true, stats = { damage = 0.12, critDamage = 0.15 } },
	dragao_estelar = { name = "Dragão Estelar", icon = "🌌", rarity = "Secreto", shape = "dragon", fly = true, color = Color3.fromRGB(40, 50, 110), accent = Color3.fromRGB(200, 230, 255), glow = true, stats = { damage = 0.14, xpGain = 0.15, goldFind = 0.15 } },
	fenix = { name = "Fênix", icon = "🔥", rarity = "Mitico", shape = "bird", fly = true, color = Color3.fromRGB(255, 120, 30), accent = Color3.fromRGB(255, 230, 90), glow = true, stats = { damage = 0.1, regen = 0.003, xpGain = 0.1 } },
}

-- Ovos: pagos só com ouro do jogo. "odds" em %, somando 100 (mostradas antes da compra).
Pets.EggOrder = { "comum", "raro", "lendario", "celestial" }
Pets.Eggs = {
	comum = { name = "Ovo Comum", icon = "🥚", price = 500, color = Color3.fromRGB(230, 220, 200), odds = { slime = 30, gato = 25, cachorro = 25, coelho = 12, coruja = 8 } },
	raro = { name = "Ovo Raro", icon = "🥚", price = 3000, color = Color3.fromRGB(110, 170, 255), odds = { coelho = 20, coruja = 20, raposa = 25, tartaruga = 25, lobo_espiritual = 6, golem_mini = 4 } },
	lendario = { name = "Ovo Lendário", icon = "🥚", price = 15000, color = Color3.fromRGB(255, 190, 50), odds = { raposa = 20, tartaruga = 20, lobo_espiritual = 25, golem_mini = 15, fada = 13, dragao_bebe = 6, fenix = 1 } },
	-- pago com Robux (Config.Products.egg_celestial): só pets Lendários para cima
	celestial = { name = "Ovo Celestial", icon = "🌟", robux = true, product = "egg_celestial", color = Color3.fromRGB(120, 225, 255), odds = { dragao_bebe = 30, unicornio = 25, tigre_celeste = 25, fenix = 12, dragao_sombrio = 7, dragao_estelar = 1 } },
}

-- bônus cresce 10% por nível do pet
function Pets.stats(petId, level)
	local def = Pets.List[petId]
	if not def then
		return {}
	end
	local scale = 1 + 0.1 * ((level or 1) - 1)
	local result = {}
	for key, value in def.stats do
		result[key] = value * scale
	end
	return result
end

function Pets.xpToNext(level)
	return math.floor(60 * level ^ 1.5)
end

-- sorteia pelas chances do ovo
function Pets.rollEgg(eggId, rng)
	local egg = Pets.Eggs[eggId]
	if not egg then
		return nil
	end
	rng = rng or Random.new()
	local roll = rng:NextNumber() * 100
	local keys = {}
	for petId in egg.odds do
		table.insert(keys, petId)
	end
	table.sort(keys)
	local acc = 0
	for _, petId in keys do
		acc += egg.odds[petId]
		if roll <= acc then
			return petId
		end
	end
	return keys[#keys]
end

return Pets
