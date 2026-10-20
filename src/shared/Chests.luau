-- Baús vendidos pelo Mercador (pagos com ouro do jogo, nunca com Robux).
-- Se um dia puderem ser comprados com Robux, o Roblox exige mostrar as chances antes da compra
-- (a janela do baú já mostra).
local Chests = {}

Chests.Order = { "bronze", "prata", "real" }

Chests.List = {
	bronze = { name = "Baú de Bronze", icon = "🎁", price = 150, minRarity = 1, color = Color3.fromRGB(205, 130, 70) },
	prata = { name = "Baú de Prata", icon = "🎁", price = 600, minRarity = 2, color = Color3.fromRGB(200, 205, 220) },
	real = { name = "Baú Real", icon = "👑", price = 2000, minRarity = 3, color = Color3.fromRGB(255, 200, 50) },
}

Chests.WeightKey = "chestWeight"

return Chests
