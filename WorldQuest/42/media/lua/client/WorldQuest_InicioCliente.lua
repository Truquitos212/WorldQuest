-- WorldQuest - Modos de inicio (cliente): pide su punto al aparecer y se mueve ahi

WorldQuest = WorldQuest or {}

local Red = WorldQuest.Red
local ESPERA_TICKS = 60   -- un momento para que el mundo termine de cargar

local pendiente = nil
local ticks = 0

local function alAparecer(jugador, casilla)
    if isServer() or WorldQuest.Inicio.modo() == "libre" then
        return
    end
    local puntos = WorldQuest.Inicio.candidatos()
    print("[WorldQuest] Inicio: " .. #puntos .. " puntos de aparicion, modo " .. WorldQuest.Inicio.modo())
    Red.pedir("pedirInicio", { puntos = puntos })
end

local function alTick()
    if not pendiente then
        return
    end
    ticks = ticks + 1
    if ticks < ESPERA_TICKS then
        return
    end
    local destino = pendiente
    pendiente = nil
    local jugador = getPlayer()
    if not jugador then
        return
    end
    jugador:teleportTo(destino.x + 0.5, destino.y + 0.5, destino.z or 0)
    if destino.aleatorio then
        Red.recibir("decir", { clave = "IGUI_WQ_Escenario", p = Red.empacar({ { clave = "IGUI_WQ_Escenario_" .. destino.escenario } }) })
    end
    print("[WorldQuest] Inicio en " .. tostring(destino.pueblo))
end

Red.mensaje("inicio", function(args)
    pendiente = args
    ticks = 0
end)

Events.OnNewGame.Add(alAparecer)
Events.OnTick.Add(alTick)
