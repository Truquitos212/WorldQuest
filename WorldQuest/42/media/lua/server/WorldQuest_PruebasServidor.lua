-- WorldQuest - Herramientas de prueba (servidor)
-- Solo funcionan con la opcion de partida Herramientas de prueba. Sirven para ver
-- en una sola sesion cosas que en una partida real tardan horas.

require "WorldQuest_MercenariosServidor"
require "WorldQuest_VictoriaServidor"

local Red = WorldQuest.Red
local Facciones = WorldQuest.Facciones

local function permitido(jugador)
    return WorldQuest.Opciones.pruebas() and jugador ~= nil
end

Red.orden("probarMercenarios", function(jugador, args)
    if not permitido(jugador) then
        return
    end
    local f = Facciones.deJugador(jugador)
    local g = WorldQuest.Mercenarios.crearGrupo(math.floor(jugador:getX()) + 40, math.floor(jugador:getY()) + 40)
    if f then
        g.simpatia[tostring(f.id)] = tonumber(args.simpatia) or 80
    end
    Red.decir(jugador, "IGUI_WQ_Prueba_Hecho")
end)

Red.orden("probarLugar", function(jugador, args)
    if not permitido(jugador) or not WorldQuest.Mundo.tipo(args.tipo) then
        return
    end
    local datos = WorldQuest.Mundo.getDatos()
    table.insert(datos.lugares, { id = datos.siguienteId, tipo = args.tipo, x = math.floor(jugador:getX()),
        y = math.floor(jugador:getY()), pueblo = "Prueba " .. datos.siguienteId, descubierto = getGameTime():getWorldAgeHours() })
    datos.siguienteId = datos.siguienteId + 1
    Red.cambio()
    Red.decir(jugador, "IGUI_WQ_Prueba_Hecho")
end)

Red.orden("probarAmenaza", function(jugador, args)
    if not permitido(jugador) or not WorldQuest.Caos.subirAmenaza then
        return
    end
    WorldQuest.Caos.subirAmenaza(30)
    Red.decir(jugador, "IGUI_WQ_Prueba_Hecho")
end)

Red.orden("probarEvacuacion", function(jugador, args)
    if not permitido(jugador) then
        return
    end
    local e = WorldQuest.Victoria.exodo(Facciones.deJugador(jugador))
    if e then
        e.avance = 95
        Red.cambio()
        Red.decir(jugador, "IGUI_WQ_Prueba_Hecho")
    end
end)

Red.orden("probarTiempo", function(jugador, args)
    if not permitido(jugador) then
        return
    end
    local d = WorldQuest.Victoria.getDatos()
    d.minutos = d.minutos + 30
    Red.cambio()
    Red.decir(jugador, "IGUI_WQ_Prueba_Hecho")
end)
