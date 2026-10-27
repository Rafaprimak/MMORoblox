-- Ícones do jogo (nada de emoji): desenhos do game-icons.net (CC BY 3.0, créditos no README e nas
-- Configurações), brancos com fundo transparente, tingidos na hora pela cor de cada tela.
-- Ficam em "folhas" de 1024x1024 com células de 128 px (assets/icones/folhaN.png), montadas por
-- scripts/icones/montar.py a partir dos nomes usados no código (icon = "crossed-swords", UI.icon("key")...).
-- Cada folha é enviada uma vez ao Roblox (Studio: Janela → Gerenciador de Ativos → Importar) e o ID vai
-- em Icons.Sheets na mesma ordem. Folha sem ID: o ícone aparece como um losango de reserva.
local Atlas = require(script.Parent.IconAtlas)

local Icons = {}

-- "rbxassetid://..." de cada folha (folha1.png, folha2.png, ...)
Icons.Sheets = {
	"rbxassetid://128765421939314", -- folha1.png
	"rbxassetid://95019878449171", -- folha2.png
	"rbxassetid://87916820599702", -- folha3.png
}

-- true se o nome é um ícone do atlas (os dados guardam o nome do ícone em `icon`)
function Icons.has(name)
	return type(name) == "string" and Atlas.icons[name] ~= nil
end

-- imagem, recorte (ImageRectOffset) e tamanho do recorte; nil se não existe ou a folha não foi enviada
function Icons.get(name)
	local entry = type(name) == "string" and Atlas.icons[name]
	if not entry then
		return nil
	end
	local image = Icons.Sheets[entry[1]]
	if not image or image == "" then
		return nil
	end
	local index = entry[2]
	local cell = Atlas.cell
	local offset = Vector2.new((index % Atlas.columns) * cell, math.floor(index / Atlas.columns) * cell)
	return image, offset, Vector2.new(cell, cell)
end

return Icons
