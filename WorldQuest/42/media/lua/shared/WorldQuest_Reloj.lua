-- WorldQuest - Reloj del mod: mide el ritmo en minutos de partida (reales)
-- Convierte el tiempo del juego con la duracion del dia del sandbox, asi el ritmo
-- de la estrategia no depende de cuanto dure un dia.

WorldQuest = WorldQuest or {}
WorldQuest.Reloj = WorldQuest.Reloj or {}

local Reloj = WorldQuest.Reloj
local CLAVE_DATOS = "WorldQuest_Reloj"
local MINUTOS_CICLO = { 2, 4, 8 }   -- segun la opcion Duracion: rapida, normal, larga
local MAX_CICLOS_POR_TICK = 5        -- tope por si el tiempo salta (dormir)

local suscriptores = {}

-- Minutos reales que dura un dia, segun la opcion DayLength del sandbox
function Reloj.minutosPorDia()
    local d = (SandboxVars and SandboxVars.DayLength) or 3
    if d == 1 then return 15 end
    if d == 2 then return 30 end
    if d == 3 then return 60 end
    if d == 4 then return 90 end
    if d >= 27 then return 1440 end
    return (d - 3) * 60
end

function Reloj.minutosCiclo()
    return MINUTOS_CICLO[WorldQuest.Opciones.duracion()] or MINUTOS_CICLO[2]
end

-- Conversiones entre minutos de partida y horas de juego
function Reloj.horasDeJuego(minutos)
    return minutos * 24 / Reloj.minutosPorDia()
end

function Reloj.minutosDePartida(horas)
    return horas * Reloj.minutosPorDia() / 24
end

-- Minutos de partida que faltan para una hora del juego
function Reloj.minutosHasta(hora)
    return math.max(0, math.ceil(Reloj.minutosDePartida(hora - getGameTime():getWorldAgeHours())))
end

-- Registra una funcion que se llama una vez por ciclo (recibe el numero de ciclo)
function Reloj.alCiclo(funcion)
    table.insert(suscriptores, funcion)
end

function Reloj.getDatos()
    local datos = ModData.getOrCreate(CLAVE_DATOS)
    datos.acumulado = datos.acumulado or 0
    datos.ciclos = datos.ciclos or 0
    datos.ultimaHora = datos.ultimaHora or getGameTime():getWorldAgeHours()
    return datos
end

local function alPasarMinuto()
    if isClient() then
        return -- en multijugador el reloj corre solo en el servidor
    end
    local datos = Reloj.getDatos()
    local ahora = getGameTime():getWorldAgeHours()
    local delta = ahora - datos.ultimaHora
    datos.ultimaHora = ahora
    if delta <= 0 then
        return
    end

    datos.acumulado = datos.acumulado + Reloj.minutosDePartida(delta)
    local largo = Reloj.minutosCiclo()
    local vueltas = 0
    while datos.acumulado >= largo and vueltas < MAX_CICLOS_POR_TICK do
        datos.acumulado = datos.acumulado - largo
        datos.ciclos = datos.ciclos + 1
        vueltas = vueltas + 1
        for _, funcion in ipairs(suscriptores) do
            local ok, err = pcall(funcion, datos.ciclos)
            if not ok then
                print("[WorldQuest] Error en un ciclo: " .. tostring(err))
            end
        end
        if WorldQuest.Red then
            WorldQuest.Red.cambio()
        end
    end
    if datos.acumulado >= largo then
        datos.acumulado = 0
    end
end

local function alEmpezar()
    Reloj.getDatos().ultimaHora = getGameTime():getWorldAgeHours()
    print("[WorldQuest] Reloj: dia de " .. Reloj.minutosPorDia() .. " min reales, ciclo de " .. Reloj.minutosCiclo() .. " min")
end

Events.OnGameStart.Add(alEmpezar)
if Events.OnServerStarted then
    Events.OnServerStarted.Add(alEmpezar)
end
Events.EveryOneMinute.Add(alPasarMinuto)
