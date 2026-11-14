-- WorldQuest - Niebla de guerra con desfase (datos y consultas del cliente)
-- Cada faccion ve lo que tiene cerca (sus bases, sus jugadores y sus viajes). Lo que
-- vio antes queda tal como estaba la ultima vez que lo vio. Los aliados comparten lo
-- que ven, la torre de radio revela todo y los observadores ven todo.
-- El servidor calcula la vision cada minuto (server/WorldQuest_NieblaServidor.lua).

WorldQuest = WorldQuest or {}
WorldQuest.Niebla = WorldQuest.Niebla or {}

local Niebla = WorldQuest.Niebla
local CLAVE_DATOS = "WorldQuest_Niebla"

Niebla.VISION_JUGADOR = 120
Niebla.VISION_BASE = 80        -- se suma al radio de cada territorio propio
Niebla.VISION_VIAJE = 70

function Niebla.activa()
    return WorldQuest.Opciones.niebla()
end

function Niebla.getDatos()
    local datos = ModData.getOrCreate(CLAVE_DATOS)
    datos.vision = datos.vision or {}     -- id faccion -> lista de { x, y, r }
    datos.vistos = datos.vistos or {}     -- id faccion -> { id territorio -> foto }
    datos.todo = datos.todo or {}         -- id faccion -> true si lo ve todo (radio)
    return datos
end

local function clave(f)
    return tostring(f.id)
end

-- true si la faccion ve todo el mapa ahora
function Niebla.veTodo(f)
    if not Niebla.activa() or not f then
        return not Niebla.activa()
    end
    if WorldQuest.Conflicto and WorldQuest.Conflicto.esObservador(f) then
        return true
    end
    return Niebla.getDatos().todo[clave(f)] == true
end

-- true si la faccion ve ese punto ahora
function Niebla.vePunto(f, x, y)
    if not Niebla.activa() then
        return true
    end
    if not f then
        return false
    end
    if Niebla.veTodo(f) then
        return true
    end
    for _, z in ipairs(Niebla.getDatos().vision[clave(f)] or {}) do
        if (z.x - x) ^ 2 + (z.y - y) ^ 2 <= z.r * z.r then
            return true
        end
    end
    return false
end

-- true si ve el viaje de otra faccion (las caravanas siempre se ven)
function Niebla.veViaje(f, v)
    if v.tipo == "caravana" then
        return true
    end
    if f and WorldQuest.Diplomacia and WorldQuest.Diplomacia.aliados(f.id, v.faccion) then
        return true
    end
    local x, y = WorldQuest.Economia.posicionViaje(v)
    return Niebla.vePunto(f, x, y)
end

-- true si ve el territorio en vivo (propio, aliado o a la vista)
function Niebla.veTerritorio(f, t)
    if not Niebla.activa() then
        return true
    end
    if not f then
        return false
    end
    if t.faccion == f.id or (t.faccion and WorldQuest.Diplomacia and WorldQuest.Diplomacia.aliados(f.id, t.faccion)) then
        return true
    end
    return Niebla.vePunto(f, t.x, t.y)
end

-- Foto guardada del territorio (o nil)
function Niebla.foto(f, idTerritorio)
    if not f then
        return nil
    end
    local vistos = Niebla.getDatos().vistos[clave(f)]
    return vistos and vistos[tostring(idTerritorio)] or nil
end

-- CLIENTE: territorios para mostrar: los vistos en vivo y las fotos de los demas.
-- Las fotos traen vistoHace (minutos) y colonosVistos.
local cacheLista, cacheMs = nil, 0
function Niebla.territoriosConocidos()
    -- Se usa en cada cuadro del mapa: se recalcula como mucho dos veces por segundo
    local ms = getTimestampMs()
    if cacheLista and ms - cacheMs < 500 then
        return cacheLista
    end
    cacheMs = ms
    cacheLista = Niebla.calcularConocidos()
    return cacheLista
end

function Niebla.calcularConocidos()
    local jugador = getPlayer()
    local f = jugador and WorldQuest.Facciones.deJugador(jugador)
    local lista = {}
    local enVivo = {}
    for _, t in ipairs(WorldQuest.Territorios.getDatos().lista) do
        if Niebla.veTerritorio(f, t) then
            table.insert(lista, t)
            enVivo[tostring(t.id)] = true
        end
    end
    if f then
        local ahora = getGameTime():getWorldAgeHours()
        for id, foto in pairs(Niebla.getDatos().vistos[clave(f)] or {}) do
            if not enVivo[id] then
                local copia = {}
                for k, v in pairs(foto) do
                    copia[k] = v
                end
                copia.vistoHace = math.floor(WorldQuest.Reloj.minutosDePartida(ahora - (foto.h or ahora)))
                copia.foto = true
                table.insert(lista, copia)
            end
        end
    end
    return lista
end
