-- Perícias: maestrias de arma (sobem usando a arma) e profissões (coleta e fabricação).
local Skills = {}

Skills.List = {
	-- maestrias
	espadas = { name = "Espadas", icon = "🗡️", kind = "mastery", weaponType = "sword" },
	machados = { name = "Machados", icon = "🪓", kind = "mastery", weaponType = "axe" },
	martelos = { name = "Martelos", icon = "🔨", kind = "mastery", weaponType = "hammer" },
	lancas = { name = "Lanças", icon = "🔱", kind = "mastery", weaponType = "spear" },
	katanas = { name = "Katanas", icon = "⚔️", kind = "mastery", weaponType = "katana" },
	adagas = { name = "Adagas", icon = "🔪", kind = "mastery", weaponType = "dagger" },
	arcos = { name = "Arcos", icon = "🏹", kind = "mastery", weaponType = "bow" },
	cajados = { name = "Cajados", icon = "🔮", kind = "mastery", weaponType = "staff" },
	-- profissões
	mineracao = { name = "Mineração", icon = "⛏️", kind = "profession", description = "Minere rochas. Níveis liberam ferro (5) e mitril (15)." },
	herbalismo = { name = "Herbalismo", icon = "🌿", kind = "profession", description = "Colha plantas. Níveis liberam cogumelos (4) e flor lunar (12)." },
	lenhador = { name = "Lenhador", icon = "🪓", kind = "profession", description = "Corte árvores. Nível 8 libera madeira antiga." },
	ferraria = { name = "Ferraria", icon = "⚒️", kind = "profession", description = "Forje equipamentos. Níveis altos aumentam a chance de raridade." },
	alquimia = { name = "Alquimia", icon = "⚗️", kind = "profession", description = "Prepare poções. Níveis altos podem render poções extras." },
	encantamento = { name = "Encantamento", icon = "✨", kind = "profession", description = "Encante itens. Níveis altos dão tiers maiores." },
}

Skills.MasteryOrder = { "espadas", "machados", "martelos", "lancas", "katanas", "adagas", "arcos", "cajados" }
Skills.ProfessionOrder = { "mineracao", "herbalismo", "lenhador", "ferraria", "alquimia", "encantamento" }

Skills.ByWeaponType = {}
for id, skill in Skills.List do
	if skill.weaponType then
		Skills.ByWeaponType[skill.weaponType] = id
	end
end

-- O que cada nível de maestria libera
Skills.MasteryPerks = {
	{ level = 3, text = "Finalizador do combo" },
	{ level = 5, text = "Ataque pesado (botão direito)" },
	{ level = 10, text = "+5% de crítico" },
	{ level = 20, text = "+10% de velocidade de ataque" },
	{ level = 30, text = "+10% de dano crítico" },
}

function Skills.masteryCrit(level)
	return if level >= 10 then 0.05 else 0
end

function Skills.masterySpeed(level)
	return if level >= 20 then 0.1 else 0
end

function Skills.masteryCritDamage(level)
	return if level >= 30 then 0.1 else 0
end

return Skills
