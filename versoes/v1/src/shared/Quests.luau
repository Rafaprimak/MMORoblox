-- Missões da história (em sequência) e diárias (3 sorteadas por dia).
-- type: "kill" (target = id do inimigo ou "any"), "level", "chest", "equip", "upgrade", "rarity" (amount = ordem da raridade)
local Quests = {}

Quests.Story = {
	{ id = "s1", text = "Derrote 5 Slimes", type = "kill", target = "slime", amount = 5, reward = { xp = 60, gold = 60 } },
	{ id = "s2", text = "Abra um Baú do Hunter (tecla B)", type = "chest", amount = 1, reward = { xp = 80, gold = 40 } },
	{ id = "s3", text = "Equipe um item novo (tecla I)", type = "equip", amount = 1, reward = { xp = 80, gold = 60 } },
	{ id = "s4", text = "Alcance o Nível 3", type = "level", amount = 3, reward = { gold = 120 } },
	{ id = "s5", text = "Derrote 25 Slimes", type = "kill", target = "slime", amount = 25, reward = { xp = 250, gold = 150 } },
	{ id = "s6", text = "Alcance o Rank D (Nível 5)", type = "level", amount = 5, reward = { gold = 200, chest = true } },
	{ id = "s7", text = "Derrote 10 Goblins na Floresta", type = "kill", target = "goblin", amount = 10, reward = { xp = 500, gold = 250 } },
	{ id = "s8", text = "Aprimore um item na Forja", type = "upgrade", amount = 1, reward = { xp = 300, gold = 150 } },
	{ id = "s9", text = "Alcance o Nível 8 (libera o Portal)", type = "level", amount = 8, reward = { gold = 300 } },
	{ id = "s10", text = "Derrote o Rei Goblin", type = "kill", target = "rei_goblin", amount = 1, reward = { xp = 2500, gold = 800, chest = true } },
	{ id = "s11", text = "Alcance o Rank C (Nível 10)", type = "level", amount = 10, reward = { gold = 500, chest = true } },
	{ id = "s12", text = "Derrote 20 Esqueletos nas Ruínas", type = "kill", target = "esqueleto", amount = 20, reward = { xp = 3000, gold = 1000 } },
	{ id = "s13", text = "Consiga um item Lendário", type = "rarity", amount = 5, reward = { xp = 2000, gold = 1500 } },
	{ id = "s14", text = "Alcance o Rank B (Nível 18)", type = "level", amount = 18, reward = { gold = 2500, chest = true } },
}

Quests.DailyPool = {
	{ id = "d_slime", text = "Derrote 40 Slimes", type = "kill", target = "slime", amount = 40, reward = { xp = 200, gold = 150 } },
	{ id = "d_any", text = "Derrote 80 inimigos", type = "kill", target = "any", amount = 80, reward = { xp = 500, gold = 400 } },
	{ id = "d_chest", text = "Abra 3 Baús", type = "chest", amount = 3, reward = { gold = 250 } },
	{ id = "d_upgrade", text = "Aprimore itens 3 vezes", type = "upgrade", amount = 3, reward = { xp = 400, gold = 200 } },
	{ id = "d_goblin", text = "Derrote 25 Goblins", type = "kill", target = "goblin", amount = 25, reward = { xp = 600, gold = 300 }, minLevel = 5 },
	{ id = "d_boss", text = "Derrote o Rei Goblin", type = "kill", target = "rei_goblin", amount = 1, reward = { xp = 1000, gold = 500, chest = true }, minLevel = 8 },
	{ id = "d_skeleton", text = "Derrote 20 Esqueletos", type = "kill", target = "esqueleto", amount = 20, reward = { xp = 1500, gold = 600 }, minLevel = 10 },
}

Quests.DailyCount = 3
Quests.DailyBonus = { gold = 500, chest = true }

Quests.DailyById = {}
for _, quest in Quests.DailyPool do
	Quests.DailyById[quest.id] = quest
end

return Quests
