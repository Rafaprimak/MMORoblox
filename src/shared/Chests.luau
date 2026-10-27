-- Baús. Bronze, Prata e Real são pagos com ouro do jogo; o Celestial é pago com Robux (produto em
-- Config.Products) e só tem Lendário, Mítico e Secreto. Regra do Roblox: todo item aleatório pago com Robux
-- mostra as chances em % antes da compra (a janela do baú mostra; ver Rarities.odds).
local Chests = {}

Chests.Order = { "bronze", "prata", "real", "celestial" }

Chests.List = {
	bronze = { name = "Baú de Bronze", icon = "present", price = 150, minRarity = 1, color = Color3.fromRGB(205, 130, 70) },
	prata = { name = "Baú de Prata", icon = "present", price = 600, minRarity = 2, color = Color3.fromRGB(200, 205, 220) },
	real = { name = "Baú Real", icon = "crown", price = 2000, minRarity = 3, color = Color3.fromRGB(255, 200, 50) },
	celestial = {
		name = "Baú Celestial", icon = "star-swirl", robux = true, product = "chest_celestial", minRarity = 5,
		weightKey = "premiumWeight", pool = "premium", color = Color3.fromRGB(120, 225, 255),
	},
}

Chests.WeightKey = "chestWeight"

-- coluna de peso das raridades usada por um baú
function Chests.weightKey(chest)
	return chest.weightKey or Chests.WeightKey
end

return Chests
