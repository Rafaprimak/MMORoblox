-- Baixa os modelos 3D da natureza (IDs em ExternalModels.Catalog) para ServerStorage.Natureza, no Studio.
-- Uso: no Studio, Exibir → Barra de comandos, cole a LINHA ÚNICA abaixo e aperte Enter.
-- Depois: no Explorer, ServerStorage → Natureza → botão direito → "Salvar em arquivo..." e salve como
-- MMOTESTE/assets/modelos/Natureza.rbxm. Gere o jogo de novo (Rojo) e os modelos aparecem no Play.
--
-- LINHA ÚNICA (copie tudo, da palavra "local" até o fim):
--
-- local c=require(game.ServerScriptService.Server.WorldGen.ExternalModels).Catalog local root=Instance.new("Folder") root.Name="Natureza" for kind,e in c do local f=Instance.new("Folder") f.Name=kind f.Parent=root for _,id in e.ids do local ok,objs=pcall(function() return game:GetObjects("rbxassetid://"..id) end) if ok then for _,o in objs do for _,d in o:GetDescendants() do if d:IsA("LuaSourceContainer") then d:Destroy() end end o.Parent=f end else warn("Falhou o modelo",id,objs) end end end local old=game.ServerStorage:FindFirstChild("Natureza") if old then old:Destroy() end root.Parent=game.ServerStorage game.Selection:Set({root}) print("Pronto! ServerStorage > Natureza > botao direito > Salvar em arquivo... > MMOTESTE/assets/modelos/Natureza.rbxm")
--
-- Versão legível do mesmo comando:
local catalog = require(game.ServerScriptService.Server.WorldGen.ExternalModels).Catalog
local root = Instance.new("Folder")
root.Name = "Natureza"
for kind, entry in catalog do
	local folder = Instance.new("Folder")
	folder.Name = kind
	folder.Parent = root
	for _, id in entry.ids do
		local ok, objects = pcall(function()
			return game:GetObjects("rbxassetid://" .. id)
		end)
		if ok then
			for _, object in objects do
				-- modelos gratuitos podem trazer scripts: fora com eles
				for _, item in object:GetDescendants() do
					if item:IsA("LuaSourceContainer") then
						item:Destroy()
					end
				end
				object.Parent = folder
			end
		else
			warn("Falhou o modelo", id, objects)
		end
	end
end
local old = game.ServerStorage:FindFirstChild("Natureza")
if old then
	old:Destroy()
end
root.Parent = game.ServerStorage
game.Selection:Set({ root })
print("Pronto! ServerStorage > Natureza > botao direito > Salvar em arquivo... > MMOTESTE/assets/modelos/Natureza.rbxm")
