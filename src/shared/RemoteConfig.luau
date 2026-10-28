-- Configuração remota (balanceamento ao vivo): valores que os administradores mudam pelo painel de Admin,
-- guardados num DataStore e aplicados em todos os servidores na hora (MessagingService), sem publicar
-- o jogo de novo. Cada campo tem padrão, mínimo, máximo e passo; o servidor recusa o que sair disso.
local RemoteConfig = {}

-- kind "number" (padrão) ou "text"
RemoteConfig.Fields = {
	{ key = "xpMult", name = "XP dos inimigos", text = "Multiplica o XP de abates (2 = fim de semana de XP em dobro).", default = 1, min = 0.5, max = 5, step = 0.25 },
	{ key = "goldMult", name = "Ouro dos inimigos", text = "Multiplica o ouro que os inimigos deixam.", default = 1, min = 0.5, max = 5, step = 0.25 },
	{ key = "dropMult", name = "Chance de drop", text = "Multiplica a chance de equipamento cair.", default = 1, min = 0.5, max = 5, step = 0.25 },
	{ key = "enemyHpMult", name = "Vida dos inimigos", text = "Vida de todos os inimigos que nascerem daqui em diante.", default = 1, min = 0.5, max = 3, step = 0.1 },
	{ key = "enemyDamageMult", name = "Dano dos inimigos", text = "Dano de todos os inimigos (vale na hora).", default = 1, min = 0.5, max = 3, step = 0.1 },
	{ key = "arenaDamage", name = "Dano na Arena", text = "Fração do dano normal entre jogadores na Arena.", default = 0.3, min = 0.05, max = 1, step = 0.05 },
	{ key = "arenaHeal", name = "Cura na Arena", text = "Fração das curas dentro da Arena.", default = 0.5, min = 0, max = 1, step = 0.1 },
	{ key = "worldBossMinutes", name = "Chefe de mundo (min)", text = "Intervalo entre chefes de mundo.", default = 25, min = 5, max = 120, step = 5 },
	{ key = "motd", name = "Mensagem do dia", text = "Aparece para quem entra no jogo (vazio = nenhuma).", kind = "text", default = "", maxLength = 140 },
}
RemoteConfig.ByKey = {}
for _, field in RemoteConfig.Fields do
	RemoteConfig.ByKey[field.key] = field
end

function RemoteConfig.defaults()
	local values = {}
	for _, field in RemoteConfig.Fields do
		values[field.key] = field.default
	end
	return values
end

-- valor válido para o campo (ou nil)
function RemoteConfig.validate(key, value)
	local field = RemoteConfig.ByKey[key]
	if not field then
		return nil
	end
	if field.kind == "text" then
		if type(value) ~= "string" then
			return nil
		end
		return string.sub(value, 1, field.maxLength or 140)
	end
	value = tonumber(value)
	if not value or value ~= value then
		return nil
	end
	value = math.clamp(value, field.min, field.max)
	-- arredonda para o passo
	return math.floor(value / field.step + 0.5) * field.step
end

return RemoteConfig
