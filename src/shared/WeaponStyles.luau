-- Estilo de luta de cada tipo de arma: sequência de combo + ataque pesado.
-- hit:
--   "cone"   = golpe corpo a corpo em leque (range, arc em graus)
--   "circle" = área em volta de um ponto à frente (offset, radius)
--   "nova"   = área em volta do próprio jogador (radius), pode ter ticks
--   "dash"   = avança dashSpeed por dashTime acertando tudo no caminho
--   "projectile" = dispara projétil (speed, range, radius, aoe, pierce, style)
-- windup: tempo até o golpe acertar; duration: tempo até poder atacar de novo
-- lunge: velocidade do passo para frente durante o golpe
-- masteryReq: nível de maestria necessário (finalizador do combo / ataque pesado)
local WeaponStyles = {}

WeaponStyles.sword = {
	mastery = "espadas",
	combo = {
		{ name = "Corte", hit = "cone", dmg = 1.0, range = 8, arc = 120, windup = 0.1, duration = 0.38, lunge = 10, pose = "slashA" },
		{ name = "Contra-corte", hit = "cone", dmg = 1.1, range = 8, arc = 120, windup = 0.1, duration = 0.38, lunge = 10, pose = "slashB" },
		{ name = "Estocada Final", hit = "cone", dmg = 1.8, range = 10, arc = 50, windup = 0.16, duration = 0.55, lunge = 22, knockback = 12, pose = "thrust", masteryReq = 3 },
	},
	heavy = { name = "Golpe Giratório", hit = "nova", dmg = 2.2, radius = 10, windup = 0.25, duration = 0.7, stamina = 25, knockback = 14, pose = "spin", masteryReq = 5 },
}

WeaponStyles.axe = {
	mastery = "machados",
	combo = {
		{ name = "Talho Largo", hit = "cone", dmg = 1.25, range = 9, arc = 170, windup = 0.18, duration = 0.55, lunge = 8, pose = "slashA" },
		{ name = "Talho Reverso", hit = "cone", dmg = 1.35, range = 9, arc = 170, windup = 0.18, duration = 0.55, lunge = 8, pose = "slashB" },
		{ name = "Machadada", hit = "cone", dmg = 2.0, range = 10, arc = 70, windup = 0.3, duration = 0.75, knockback = 14, pose = "overhead", masteryReq = 3 },
	},
	heavy = { name = "Fenda", hit = "circle", dmg = 3.0, offset = 7, radius = 8, windup = 0.45, duration = 0.95, stamina = 30, knockback = 18, pose = "overhead", masteryReq = 5 },
}

WeaponStyles.hammer = {
	mastery = "martelos",
	combo = {
		{ name = "Esmagar", hit = "circle", dmg = 1.6, offset = 6, radius = 7, windup = 0.32, duration = 0.8, knockback = 14, pose = "overhead" },
		{ name = "Esmagar Duplo", hit = "circle", dmg = 1.9, offset = 6, radius = 8, windup = 0.32, duration = 0.85, knockback = 16, pose = "overhead", masteryReq = 3 },
	},
	heavy = { name = "Terremoto", hit = "nova", dmg = 2.6, radius = 15, windup = 0.55, duration = 1.05, stamina = 35, stun = 1.2, knockback = 10, pose = "slam", masteryReq = 5 },
}

WeaponStyles.spear = {
	mastery = "lancas",
	combo = {
		{ name = "Estocada", hit = "cone", dmg = 0.9, range = 13, arc = 30, windup = 0.08, duration = 0.32, lunge = 10, pose = "thrust" },
		{ name = "Estocada Dupla", hit = "cone", dmg = 1.0, range = 13, arc = 30, windup = 0.08, duration = 0.32, lunge = 10, pose = "thrust" },
		{ name = "Varredura", hit = "cone", dmg = 1.3, range = 11, arc = 200, windup = 0.14, duration = 0.5, knockback = 10, pose = "spin", masteryReq = 3 },
	},
	heavy = { name = "Investida da Lança", hit = "dash", dmg = 2.0, dashSpeed = 70, dashTime = 0.35, radius = 5, windup = 0.05, duration = 0.6, stamina = 25, pose = "thrust", masteryReq = 5 },
}

WeaponStyles.katana = {
	mastery = "katanas",
	crit = 0.1,
	combo = {
		{ name = "Iaijutsu", hit = "cone", dmg = 0.8, range = 8, arc = 100, windup = 0.06, duration = 0.26, lunge = 12, pose = "slashA" },
		{ name = "Corte Duplo", hit = "cone", dmg = 0.85, range = 8, arc = 100, windup = 0.06, duration = 0.26, lunge = 12, pose = "slashB" },
		{ name = "Corte Ascendente", hit = "cone", dmg = 0.9, range = 8, arc = 100, windup = 0.06, duration = 0.28, lunge = 12, pose = "overhead" },
		{ name = "Lua Crescente", hit = "cone", dmg = 1.6, range = 10, arc = 140, windup = 0.12, duration = 0.45, lunge = 24, knockback = 10, pose = "spin", masteryReq = 3 },
	},
	heavy = { name = "Corte Relâmpago", hit = "dash", dmg = 2.4, dashSpeed = 95, dashTime = 0.25, radius = 6, windup = 0.05, duration = 0.55, stamina = 25, pose = "thrust", masteryReq = 5 },
}

WeaponStyles.dagger = {
	mastery = "adagas",
	backstab = 0.6, -- +60% de dano pelas costas
	crit = 0.05,
	combo = {
		{ name = "Punhalada", hit = "cone", dmg = 0.6, range = 6, arc = 90, windup = 0.04, duration = 0.2, lunge = 10, pose = "stab" },
		{ name = "Punhalada", hit = "cone", dmg = 0.6, range = 6, arc = 90, windup = 0.04, duration = 0.2, lunge = 10, pose = "slashB" },
		{ name = "Talho", hit = "cone", dmg = 0.7, range = 6, arc = 110, windup = 0.04, duration = 0.22, lunge = 10, pose = "stab" },
		{ name = "Golpe Mortal", hit = "cone", dmg = 1.4, range = 7, arc = 90, windup = 0.1, duration = 0.4, lunge = 20, pose = "thrust", masteryReq = 3 },
	},
	heavy = { name = "Dança das Lâminas", hit = "nova", dmg = 0.8, radius = 9, ticks = 4, interval = 0.15, windup = 0.05, duration = 0.75, stamina = 25, pose = "spin", masteryReq = 5 },
}

WeaponStyles.bow = {
	mastery = "arcos",
	ranged = true,
	combo = {
		{ name = "Disparo", hit = "projectile", dmg = 1.0, speed = 150, range = 110, radius = 1.2, style = "arrow", windup = 0.12, duration = 0.5, pose = "bow" },
	},
	heavy = { name = "Tiro Perfurante", hit = "projectile", dmg = 2.6, speed = 220, range = 140, radius = 1.6, pierce = 5, style = "arrowBig", windup = 0.45, duration = 0.85, stamina = 25, pose = "bow", masteryReq = 5 },
}

WeaponStyles.staff = {
	mastery = "cajados",
	ranged = true,
	combo = {
		{ name = "Míssil Arcano", hit = "projectile", dmg = 1.05, speed = 95, range = 85, radius = 1.4, aoe = 5, style = "arcane", windup = 0.14, duration = 0.55, pose = "cast" },
		{ name = "Míssil Arcano", hit = "projectile", dmg = 1.05, speed = 95, range = 85, radius = 1.4, aoe = 5, style = "arcane", windup = 0.14, duration = 0.55, pose = "castB" },
	},
	heavy = { name = "Explosão Arcana", hit = "nova", dmg = 2.3, radius = 13, windup = 0.4, duration = 0.9, stamina = 25, knockback = 12, style = "arcane", pose = "castBig", masteryReq = 5 },
}

function WeaponStyles.get(weaponType)
	return WeaponStyles[weaponType] or WeaponStyles.sword
end

return WeaponStyles
