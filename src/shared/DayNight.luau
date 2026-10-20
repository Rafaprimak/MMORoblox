-- Ciclo de dia e noite determinístico: servidor e cliente calculam a mesma hora a partir do
-- relógio do servidor e do atributo "DayEpoch" do workspace (quando o ciclo começou).
local Config = require(script.Parent.Config)

local DayNight = {}

DayNight.DawnHour = 6.5 -- amanhecer
DayNight.DuskHour = 18.5 -- anoitecer

local DAY = Config.DayMinutes * 60
local NIGHT = Config.NightMinutes * 60
local CYCLE = DAY + NIGHT

-- segundos de ciclo até chegar em uma hora do dia (para começar o servidor de manhã)
function DayNight.offsetFor(clock)
	if clock >= DayNight.DawnHour and clock < DayNight.DuskHour then
		return (clock - DayNight.DawnHour) / 12 * DAY
	end
	local sinceDusk = (clock - DayNight.DuskHour) % 24
	return DAY + sinceDusk / 12 * NIGHT
end

-- segundos desde o começo do ciclo atual
function DayNight.phase(serverTime, epoch)
	return (serverTime - (epoch or 0)) % CYCLE
end

-- hora do dia (0 a 24). O dia dura Config.DayMinutes e a noite Config.NightMinutes.
function DayNight.clock(serverTime, epoch)
	local t = DayNight.phase(serverTime, epoch)
	if t < DAY then
		return DayNight.DawnHour + t / DAY * 12
	end
	return (DayNight.DuskHour + (t - DAY) / NIGHT * 12) % 24
end

function DayNight.isNight(clock)
	return clock >= DayNight.DuskHour or clock < DayNight.DawnHour
end

-- segundos reais até a próxima troca (amanhecer ou anoitecer)
function DayNight.secondsToChange(serverTime, epoch)
	local t = DayNight.phase(serverTime, epoch)
	if t < DAY then
		return DAY - t
	end
	return CYCLE - t
end

-- hora atual usando o atributo do workspace (funciona nos dois lados)
function DayNight.now()
	return DayNight.clock(workspace:GetServerTimeNow(), workspace:GetAttribute("DayEpoch") or 0)
end

function DayNight.format(clock)
	local hours = math.floor(clock)
	local minutes = math.floor((clock - hours) * 60)
	return ("%02d:%02d"):format(hours, minutes)
end

return DayNight
