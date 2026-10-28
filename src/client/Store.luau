-- Compras com Robux no cliente (Config.Products): abre a tela de compra do Roblox e mostra o preço.
-- Produto ainda sem ID: no Studio entrega de graça para testar; no jogo avisa que ainda não está à venda.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local State = require(script.Parent.State)
local Popups = require(script.Parent.Popups)
local UI = require(script.Parent.UI)

local Store = {}

local prices = {} -- [chave] = preço real (lido do Roblox quando o produto existe)

-- ícone oficial do Robux: caractere especial que as fontes do Roblox desenham como o símbolo do Robux
Store.RobuxIcon = utf8.char(0xE002)

-- texto do preço com o ícone do Robux na frente (ícone + "159")
function Store.priceText(key)
	local product = Config.Products[key]
	if not product then
		return ""
	end
	if product.id > 0 and prices[key] == nil then
		prices[key] = false
		task.spawn(function()
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(product.id, Enum.InfoType.Product)
			end)
			if ok and info and info.PriceInRobux then
				prices[key] = info.PriceInRobux
			end
		end)
	end
	return ("%s %d"):format(Store.RobuxIcon, prices[key] or product.robux)
end

function Store.buy(key)
	local product = Config.Products[key]
	if not product then
		return
	end
	if product.id > 0 then
		MarketplaceService:PromptProductPurchase(Players.LocalPlayer, product.id)
	elseif RunService:IsStudio() then
		State.request("devPremium", key)
	else
		Popups.message("Esse produto ainda não está à venda.", UI.Colors.Gold)
	end
end

return Store
