-- Projéteis (flechas, magias) simulados no servidor. O cliente desenha o mesmo trajeto.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local EnemyService = require(script.Parent.EnemyService)
local PlayerService = require(script.Parent.PlayerService)

local ProjectileService = {}

local projectiles = {}
local nextId = 0

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.IgnoreWater = true

local function refreshRayFilter()
	local list = { workspace.Terrain }
	local world = workspace:FindFirstChild("Mundo")
	if world then
		table.insert(list, world)
	end
	rayParams.FilterDescendantsInstances = list
end

-- spec: team ("player"|"enemy"), origin, direction, speed, range, radius, style,
--       pierce, aoe, damage (inimigos), onHitEnemy(rec, position), onExplode(position)
function ProjectileService.fire(spec)
	nextId += 1
	local projectile = {
		id = nextId,
		team = spec.team,
		position = spec.origin,
		direction = spec.direction.Unit,
		speed = spec.speed,
		range = spec.range,
		radius = spec.radius or 1,
		style = spec.style or "arrow",
		pierceLeft = spec.pierce or 0,
		aoe = spec.aoe,
		damage = spec.damage,
		onHitEnemy = spec.onHitEnemy,
		onExplode = spec.onExplode,
		owner = spec.owner,
		traveled = 0,
		hit = {},
	}
	table.insert(projectiles, projectile)
	Remotes.Fx:FireAllClients("projectile", projectile.id, spec.origin, projectile.direction, projectile.speed, projectile.range, projectile.style)
	return projectile
end

local function finish(projectile, position, exploded)
	projectile.done = true
	if exploded and projectile.aoe then
		if projectile.team == "player" and projectile.onExplode then
			projectile.onExplode(position)
		elseif projectile.team == "enemy" then
			for _, player in Players:GetPlayers() do
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if root and (root.Position - position).Magnitude <= projectile.aoe + 1.5 then
					PlayerService.damagePlayer(player, projectile.damage, position)
				end
			end
		end
	end
	Remotes.Fx:FireAllClients("projectileEnd", projectile.id, position, if exploded and projectile.aoe then projectile.aoe else 0, projectile.style)
end

local function step(projectile, dt)
	local distance = projectile.speed * dt
	local from = projectile.position
	local to = from + projectile.direction * distance

	-- alvos
	if projectile.team == "player" then
		for _, rec in EnemyService.alongSegment(from, to, projectile.radius, projectile.owner) do
			if not projectile.hit[rec] then
				projectile.hit[rec] = true
				local center = EnemyService.centerOf(rec)
				if projectile.aoe then
					finish(projectile, center, true)
					return
				end
				if projectile.onHitEnemy then
					projectile.onHitEnemy(rec, center)
				end
				if projectile.pierceLeft <= 0 then
					finish(projectile, center, false)
					return
				end
				projectile.pierceLeft -= 1
			end
		end
	else
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if root and humanoid and humanoid.Health > 0 then
				local ab = to - from
				local t = math.clamp((root.Position - from):Dot(ab) / math.max(ab:Dot(ab), 0.001), 0, 1)
				local closest = from + ab * t
				if (root.Position - closest).Magnitude <= projectile.radius + 2 then
					if projectile.aoe then
						finish(projectile, closest, true)
					else
						PlayerService.damagePlayer(player, projectile.damage, from)
						finish(projectile, closest, false)
					end
					return
				end
			end
		end
	end

	-- terreno e construções
	local result = workspace:Raycast(from, to - from, rayParams)
	if result then
		finish(projectile, result.Position, true)
		return
	end

	projectile.position = to
	projectile.traveled += distance
	if projectile.traveled >= projectile.range then
		finish(projectile, to, projectile.style == "fire" or projectile.style == "arcane")
	end
end

function ProjectileService.start()
	refreshRayFilter()
	RunService.Heartbeat:Connect(function(dt)
		for i = #projectiles, 1, -1 do
			local projectile = projectiles[i]
			if not projectile.done then
				local ok, err = pcall(step, projectile, dt)
				if not ok then
					warn("[ProjectileService] " .. tostring(err))
					projectile.done = true
				end
			end
			if projectile.done then
				table.remove(projectiles, i)
			end
		end
	end)
end

return ProjectileService
