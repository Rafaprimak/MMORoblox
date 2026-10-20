-- Receitas da Forja (Ferreiro) e da Alquimia (Alquimista).
local Recipes = {}

-- result = id da base do item; skill = nível de Ferraria necessário
Recipes.Forge = {
	{ result = "espada_cobre", skill = 1, gold = 20, materials = { minerio_cobre = 5, madeira = 2 } },
	{ result = "adaga_cobre", skill = 1, gold = 15, materials = { minerio_cobre = 3, madeira = 1 } },
	{ result = "arco_curto", skill = 1, gold = 20, materials = { madeira = 5, minerio_cobre = 1 } },
	{ result = "cajado_aprendiz", skill = 1, gold = 20, materials = { madeira = 4, minerio_cobre = 2 } },
	{ result = "lanca_cacador", skill = 2, gold = 25, materials = { madeira = 3, minerio_cobre = 3 } },
	{ result = "machado_lenhador", skill = 2, gold = 25, materials = { minerio_cobre = 5, madeira = 3 } },
	{ result = "colete_couro", skill = 2, gold = 25, materials = { couro = 5 } },
	{ result = "manto_aprendiz", skill = 2, gold = 25, materials = { pano = 4, erva_verde = 2 } },
	{ result = "martelo_pedra", skill = 4, gold = 40, materials = { minerio_cobre = 6, madeira = 2, gosma = 4 } },
	{ result = "katana_errante", skill = 5, gold = 50, materials = { minerio_ferro = 4, minerio_cobre = 2 } },
	{ result = "cota_malha", skill = 6, gold = 60, materials = { minerio_ferro = 8 } },
	{ result = "lamina_guardiao", skill = 10, gold = 120, materials = { minerio_ferro = 8, osso = 4 } },
	{ result = "machado_berserker", skill = 10, gold = 120, materials = { minerio_ferro = 8, presa = 6 } },
	{ result = "presas_gemeas", skill = 12, gold = 140, materials = { minerio_ferro = 6, presa = 8 } },
	{ result = "arco_longo", skill = 12, gold = 140, materials = { madeira_antiga = 6, seda = 4 } },
	{ result = "cajado_arcano", skill = 12, gold = 140, materials = { madeira_antiga = 4, essencia = 4 } },
	{ result = "manto_arcano", skill = 12, gold = 140, materials = { seda = 8, essencia = 5 } },
	{ result = "couraca_sombria", skill = 12, gold = 140, materials = { couro = 10, seda = 5 } },
	{ result = "martelo_gigante", skill = 14, gold = 180, materials = { minerio_ferro = 10, nucleo_golem = 2 } },
	{ result = "lanca_draconica", skill = 15, gold = 200, materials = { minerio_mitril = 4, madeira_antiga = 3 } },
	{ result = "armadura_placas", skill = 15, gold = 200, materials = { minerio_ferro = 12, minerio_mitril = 2 } },
	{ result = "katana_sombria", skill = 16, gold = 220, materials = { minerio_mitril = 5, seda = 4 } },
}

Recipes.Alchemy = {
	{ result = "pocao_vida", count = 2, skill = 1, gold = 5, materials = { erva_verde = 3, gosma = 1 } },
	{ result = "pocao_mana", count = 2, skill = 3, gold = 5, materials = { cogumelo_azul = 2, erva_verde = 1 } },
	{ result = "pocao_vigor", count = 2, skill = 5, gold = 10, materials = { erva_verde = 2, presa = 1 } },
	{ result = "elixir_forca", count = 1, skill = 10, gold = 25, materials = { flor_lunar = 2, essencia = 1 } },
}

-- Loja do Mercador
Recipes.Shop = { "pocao_vida", "pocao_mana", "pocao_vigor" }

-- XP de profissão ganho por fabricação
function Recipes.forgeXp(recipe)
	return 20 + recipe.skill * 8
end

function Recipes.alchemyXp(recipe)
	return 15 + recipe.skill * 6
end

return Recipes
