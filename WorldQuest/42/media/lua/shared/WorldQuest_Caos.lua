-- WorldQuest - Modo Caos: tres enemigos controlados por el juego (datos)
--   Los Militares: redadas contra quien va primero y controles que confiscan lo que pasa.
--   Los Fugados (rama dura): una base propia que crece saqueando a todos.
--   La Horda que piensa: llega dividida, flanquea y aparece en los momentos criticos.
-- La amenaza sube con el tiempo y con cada golpe que dan. Si llega a 100, pierden todos.
-- La logica corre en el servidor (server/WorldQuest_CaosServidor.lua).

WorldQuest = WorldQuest or {}
WorldQuest.Caos = WorldQuest.Caos or {}

local Caos = WorldQuest.Caos
local CLAVE_DATOS = "WorldQuest_Caos"

Caos.RADIO_CONTROL = 150
Caos.RADIO_BASE = 35
Caos.TRIBUTO = { recurso = "municion", cantidad = 80 }
Caos.COSTO_DESVIO = { recurso = "municion", cantidad = 60 }

function Caos.activo()
    return WorldQuest.Opciones.modoJuego() == 2
end

function Caos.getDatos()
    local datos = ModData.getOrCreate(CLAVE_DATOS)
    datos.amenaza = datos.amenaza or 0
    datos.controles = datos.controles or {}     -- { x, y }
    datos.demandas = datos.demandas or {}       -- id faccion -> { expira }
    datos.tranquilos = datos.tranquilos or {}   -- id faccion -> ciclos sin ataques de los Fugados
    datos.prioridad = datos.prioridad or {}     -- id faccion -> true (negaron el tributo)
    return datos
end

-- Base de los Fugados (o nil si todavia no aparece o fue destruida)
function Caos.base()
    local b = Caos.getDatos().base
    if b and (b.fuerza or 0) > 0 then
        return b
    end
    return nil
end

function Caos.demanda(f)
    return f and Caos.getDatos().demandas[tostring(f.id)] or nil
end

-- true si la faccion es de Los Fugados (comparte origen con la rama dura)
function Caos.esFugado(f)
    return f ~= nil and f.tipo == "fugados"
end

-- true si un punto esta dentro de un control militar
function Caos.enControl(x, y)
    for _, c in ipairs(Caos.getDatos().controles) do
        if (c.x - x) ^ 2 + (c.y - y) ^ 2 <= Caos.RADIO_CONTROL * Caos.RADIO_CONTROL then
            return c
        end
    end
    return nil
end
