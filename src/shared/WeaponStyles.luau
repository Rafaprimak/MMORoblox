-- Estilo de luta de cada tipo de arma: sequência de combo + ataque pesado (carregável com R).
-- hit:
--   "cone"   = golpe corpo a corpo em leque (range, arc em graus)
--   "circle" = área em volta de um ponto à frente (offset, radius)
--   "nova"   = área em volta do próprio jogador (radius), pode ter ticks
--   "dash"   = avança dashSpeed por dashTime acertando tudo no caminho (só ataques pesados)
--   "projectile" = dispara projétil (speed, range, radius, aoe, pierce, style)
-- windup: tempo até o golpe acertar; duration: tempo até poder atacar de novo
-- stamina: custo do golpe (o pesado escala com a carga)
-- masteryReq: nível de maestria necessário (finalizador do combo / ataque pesado)
-- posture (na arma): quanto a arma quebra a guarda dos inimigos (1 = normal)
--
-- Golpes leves NÃO movem o personagem. Só os pesados do tipo "dash" avançam.
local WeaponStyles = {}

WeaponStyles.sword = {
	mastery = "espadas",
	posture = 1.0,
	combo = {
		{ name = "Corte", hit = "cone", dmg = 1.0, range = 8, arc = 120, windup = 0.12, duration = 0.42, stamina = 5, pose = "slashA" },
		{ name = "Contra-corte", hit = "cone", dmg = 1.1, range = 8, arc = 120, windup = 0.12, duration = 0.42, stamina = 5, pose = "slashB" },
		{ name = "Estocada Final", hit = "cone", dmg = 1.8, range = 10, arc = 50, windup = 0.18, duration = 0.6, stamina = 8, knockback = 12, pose = "thrust", masteryReq = 3 },
	},
	heavy = { name = "Golpe Giratório", hit = "nova", dmg = 2.0, radius = 10, windup = 0.25, duration = 0.7, stamina = 22, knockback = 14, pose = "spin", masteryReq = 5 },
}

WeaponStyles.axe = {
	mastery = "machados",
	posture = 1.3,
	combo = {
		{ name = "Talho Largo", hit = "cone", dmg = 1.25, range = 9, arc = 170, windup = 0.2, duration = 0.58, stamina = 7, pose = "slashA" },
		{ name = "Talho Reverso", hit = "cone", dmg = 1.35, range = 9, arc = 170, windup = 0.2, duration = 0.58, stamina = 7, pose = "slashB" },
		{ name = "Machadada", hit = "cone", dmg = 2.0, range = 10, arc = 70, windup = 0.32, duration = 0.8, stamina = 10, knockback = 14, pose = "overhead", masteryReq = 3 },
	},
	heavy = { name = "Fenda", hit = "circle", dmg = 2.8, offset = 7, radius = 8, windup = 0.4, duration = 0.95, stamina = 26, knockback = 18, pose = "overhead", masteryReq = 5 },
}

WeaponStyles.hammer = {
	mastery = "martelos",
	posture = 1.8,
	combo = {
		{ name = "Esmagar", hit = "circle", dmg = 1.6, offset = 6, radius = 7, windup = 0.34, duration = 0.85, stamina = 10, knockback = 14, pose = "overhead" },
		{ name = "Esmagar Duplo", hit = "circle", dmg = 1.9, offset = 6, radius = 8, windup = 0.34, duration = 0.9, stamina = 12, knockback = 16, pose = "overhead", masteryReq = 3 },
	},
	heavy = { name = "Terremoto", hit = "nova", dmg = 2.4, radius = 15, windup = 0.5, duration = 1.05, stamina = 30, stun = 1.2, knockback = 10, pose = "slam", masteryReq = 5 },
}

WeaponStyles.spear = {
	mastery = "lancas",
	posture = 0.9,
	combo = {
		{ name = "Estocada", hit = "cone", dmg = 0.9, range = 13, arc = 30, windup = 0.1, duration = 0.36, stamina = 4, pose = "thrust" },
		{ name = "Estocada Dupla", hit = "cone", dmg = 1.0, range = 13, arc = 30, windup = 0.1, duration = 0.36, stamina = 4, pose = "thrust" },
		{ name = "Varredura", hit = "cone", dmg = 1.3, range = 11, arc = 200, windup = 0.16, duration = 0.55, stamina = 8, knockback = 10, pose = "spin", masteryReq = 3 },
	},
	heavy = { name = "Investida da Lança", hit = "dash", dmg = 1.9, dashSpeed = 70, dashTime = 0.35, radius = 5, windup = 0.05, duration = 0.6, stamina = 22, pose = "thrust", masteryReq = 5 },
}

WeaponStyles.katana = {
	mastery = "katanas",
	posture = 0.8,
	crit = 0.1,
	combo = {
		{ name = "Iaijutsu", hit = "cone", dmg = 0.8, range = 8, arc = 100, windup = 0.07, duration = 0.3, stamina = 4, pose = "slashA" },
		{ name = "Corte Duplo", hit = "cone", dmg = 0.85, range = 8, arc = 100, windup = 0.07, duration = 0.3, stamina = 4, pose = "slashB" },
		{ name = "Corte Ascendente", hit = "cone", dmg = 0.9, range = 8, arc = 100, windup = 0.07, duration = 0.32, stamina = 4, pose = "overhead" },
		{ name = "Lua Crescente", hit = "cone", dmg = 1.6, range = 10, arc = 140, windup = 0.13, duration = 0.5, stamina = 8, knockback = 10, pose = "spin", masteryReq = 3 },
	},
	heavy = { name = "Corte Relâmpago", hit = "dash", dmg = 2.2, dashSpeed = 95, dashTime = 0.25, radius = 6, windup = 0.05, duration = 0.55, stamina = 22, pose = "thrust", masteryReq = 5 },
}

WeaponStyles.dagger = {
	mastery = "adagas",
	posture = 0.6,
	backstab = 0.6, -- +60% de dano pelas costas
	crit = 0.05,
	combo = {
		{ name = "Punhalada", hit = "cone", dmg = 0.6, range = 6, arc = 90, windup = 0.05, duration = 0.24, stamina = 3, pose = "stab" },
		{ name = "Punhalada", hit = "cone", dmg = 0.6, range = 6, arc = 90, windup = 0.05, duration = 0.24, stamina = 3, pose = "slashB" },
		{ name = "Talho", hit = "cone", dmg = 0.7, range = 6, arc = 110, windup = 0.05, duration = 0.26, stamina = 3, pose = "stab" },
		{ name = "Golpe Mortal", hit = "cone", dmg = 1.4, range = 7, arc = 90, windup = 0.11, duration = 0.45, stamina = 6, pose = "thrust", masteryReq = 3 },
	},
	heavy = { name = "Dança das Lâminas", hit = "nova", dmg = 0.75, radius = 9, ticks = 4, interval = 0.15, windup = 0.05, duration = 0.75, stamina = 22, pose = "spin", masteryReq = 5 },
}

WeaponStyles.bow = {
	mastery = "arcos",
	posture = 0.5,
	ranged = true,
	combo = {
		{ name = "Disparo", hit = "projectile", dmg = 1.0, speed = 150, range = 110, radius = 1.2, style = "arrow", windup = 0.14, duration = 0.55, stamina = 4, pose = "bow" },
	},
	heavy = { name = "Tiro Perfurante", hit = "projectile", dmg = 2.4, speed = 220, range = 140, radius = 1.6, pierce = 5, style = "arrowBig", windup = 0.15, duration = 0.7, stamina = 22, pose = "bow", masteryReq = 5 },
}

WeaponStyles.staff = {
	mastery = "cajados",
	posture = 0.6,
	ranged = true,
	combo = {
		{ name = "Míssil Arcano", hit = "projectile", dmg = 1.05, speed = 95, range = 85, radius = 1.4, aoe = 5, style = "arcane", windup = 0.15, duration = 0.58, stamina = 4, pose = "cast" },
		{ name = "Míssil Arcano", hit = "projectile", dmg = 1.05, speed = 95, range = 85, radius = 1.4, aoe = 5, style = "arcane", windup = 0.15, duration = 0.58, stamina = 4, pose = "castB" },
	},
	heavy = { name = "Explosão Arcana", hit = "nova", dmg = 2.1, radius = 13, windup = 0.3, duration = 0.85, stamina = 22, knockback = 12, style = "arcane", pose = "castBig", masteryReq = 5 },
}

function WeaponStyles.get(weaponType)
	return WeaponStyles[weaponType] or WeaponStyles.sword
end

return WeaponStyles
