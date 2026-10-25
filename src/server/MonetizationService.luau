-- Compras com Robux (developer products de Config.Products): Baú Celestial e Ovo Celestial.
-- ProcessReceipt entrega uma única vez por compra (data.purchases guarda o PurchaseId) e salva na hora.
-- Itens aleatórios pagos: as chances ficam sempre visíveis antes da compra (janelas do Baú e dos Ovos).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local DataService = require(script.Parent.DataService)
local ShopService = require(script.Parent.ShopService)
local PetService = require(script.Parent.PetService)

local MonetizationService = {}

local function productKeyById(productId)
	for key, product in Config.Products do
		if product.id > 0 and product.id == productId then
			return key
		end
	end
	return nil
end

local function grant(player, key)
	local product = Config.Products[key]
	if product.kind == "chest" then
		ShopService.grant(player, product.target)
	elseif product.kind == "egg" then
		PetService.grantEgg(player, product.target)
	end
end

-- Botão "Testar" no Studio (produto sem ID ainda): entrega de graça para ver a animação e o sorteio
function MonetizationService.devGrant(player, key)
	if not RunService:IsStudio() or type(key) ~= "string" or not Config.Products[key] then
		return { ok = false, msg = "Isso só funciona no Studio." }
	end
	grant(player, key)
	return { ok = true }
end

function MonetizationService.init()
	MarketplaceService.ProcessReceipt = function(receipt)
		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		local data = player and DataService.get(player)
		if not data then
			return Enum.ProductPurchaseDecision.NotProcessedYet -- o Roblox tenta de novo quando ele voltar
		end
		data.purchases = data.purchases or {}
		if data.purchases[receipt.PurchaseId] then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		local key = productKeyById(receipt.ProductId)
		if not key then
			warn(("[Robux] Produto desconhecido: %s"):format(tostring(receipt.ProductId)))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local ok, err = pcall(grant, player, key)
		if not ok then
			warn("[Robux] Falha ao entregar: " .. tostring(err))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		data.purchases[receipt.PurchaseId] = true
		pcall(DataService.save, player)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
end

return MonetizationService
