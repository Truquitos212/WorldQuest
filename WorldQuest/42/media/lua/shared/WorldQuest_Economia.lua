-- WorldQuest - Economia: especializacion de bases, riqueza y expediciones (datos)
-- La logica que cambia cosas corre en el servidor (server/WorldQuest_EconomiaServidor.lua)

require "WorldQuest_Recursos"

WorldQuest = WorldQuest or {}
WorldQuest.Economia = WorldQuest.Economia or {}

local E = WorldQuest.Economia
local CLAVE_EXPEDICIONES = "WorldQuest_Expediciones"

-- ESPECIALIZACION -------------------------------------------------------------
-- Una base se especializa sola segun lo que tiene. Gana la primera que se cumpla.

local function cuantos(t, rol)
    local n = 0
    for _, c in ipairs(WorldQuest.Colonos.delTerritorio(t)) do
        if c.rol == rol and not c.expedicion then
            n = n + 1
        end
    end
    return n
end

local function estructura(t, id)
    return (t.estructuras and t.estructuras[id]) or 0
end

local function mejora(t, id)
    return t.mejoras ~= nil and t.mejoras[id] == true
end

E.ESPECIALIDADES = {
    { id = "fortin",   efectos = { defensa = 1.15 },
      cumple = function(t) return (mejora(t, "torre") or mejora(t, "muralla")) and cuantos(t, "guardia") >= 2 end },
    { id = "taller",   efectos = { troncos = 1.2, metal = 1.25 },
      cumple = function(t) return mejora(t, "taller") and cuantos(t, "constructor") >= 1 end },
    { id = "granja",   efectos = { agricultor = 1.2 },
      cumple = function(t) return estructura(t, "huertos") >= 8 or cuantos(t, "agricultor") >= 2 end },
    { id = "hospital", efectos = { animo = 2, medicina = 1.3 },
      cumple = function(t) return cuantos(t, "medico") >= 1 and estructura(t, "camas") >= 4 end },
    { id = "exploracion", efectos = { botin = 1.15 },
      cumple = function(t) return cuantos(t, "explorador") >= 2 end },
}

-- Especialidad actual del territorio (o nil)
function E.especialidad(t)
    if not t or not WorldQuest.Colonos then
        return nil
    end
    for _, esp in ipairs(E.ESPECIALIDADES) do
        local ok, cumple = pcall(esp.cumple, t)
        if ok and cumple then
            return esp
        end
    end
    return nil
end

-- Efecto de la especialidad: multiplicador (1) o suma (0) segun la clave
function E.efectoEspecialidad(t, clave, neutro)
    local esp = E.especialidad(t)
    if esp and esp.efectos[clave] then
        return esp.efectos[clave]
    end
    return neutro
end

-- RIQUEZA ---------------------------------------------------------------------
-- Valor de trueque de lo guardado (ultimo conteo del servidor), mas lo construido
-- y la gente. Sirve para la victoria economica y para el modo Caos.

E.VALOR_NIVEL = 60
E.VALOR_MEJORA = 30
E.VALOR_COLONO = 20

function E.riquezaTerritorio(t)
    local total = WorldQuest.Recursos.valor(t.recursos or {})
    total = total + ((t.nivel or 1) - 1) * E.VALOR_NIVEL
    for _, hecho in pairs(t.mejoras or {}) do
        if hecho then
            total = total + E.VALOR_MEJORA
        end
    end
    total = total + #WorldQuest.Colonos.delTerritorio(t) * E.VALOR_COLONO
    return math.floor(total)
end

function E.riquezaFaccion(f)
    if not f then
        return 0
    end
    local total = 0
    for _, t in ipairs(WorldQuest.Territorios.getDatos().lista) do
        if t.faccion == f.id then
            total = total + E.riquezaTerritorio(t)
        end
    end
    return total + math.floor(f.riquezaExtra or 0)
end

-- Recursos sumados de todos los territorios de la faccion (ultimo conteo)
function E.recursosFaccion(f)
    local total = WorldQuest.Recursos.vacio()
    for _, t in ipairs(WorldQuest.Territorios.getDatos().lista) do
        if f and t.faccion == f.id then
            for clave, valor in pairs(t.recursos or {}) do
                if total[clave] then
                    total[clave] = total[clave] + valor
                end
            end
        end
    end
    return total
end

-- EXPEDICIONES ------------------------------------------------------------------
-- Colonos que salen a una zona lejana, exploran y vuelven con botin. Mientras estan
-- afuera no trabajan, no defienden y no comen del almacen (llevan lo suyo).

E.TILES_POR_MINUTO = 40       -- velocidad con la duracion Normal
E.MINUTOS_EXPLORANDO = 6
E.DISTANCIA_MAXIMA = 3000
E.MAX_COLONOS = 5

function E.getExpediciones()
    local datos = ModData.getOrCreate(CLAVE_EXPEDICIONES)
    datos.lista = datos.lista or {}
    datos.siguienteId = datos.siguienteId or 1
    return datos
end

-- Velocidad en casillas por minuto de partida (las partidas largas van mas lento)
function E.velocidad(t)
    local base = E.TILES_POR_MINUTO * 4 / WorldQuest.Reloj.minutosCiclo()
    local efecto = WorldQuest.Modificadores and WorldQuest.Modificadores.efecto(t, "velocidad") or 1
    return base * (efecto or 1)
end

local function mezclar(a, b, f)
    return a + (b - a) * math.max(0, math.min(1, f))
end

-- Posicion en el mundo de algo que va y vuelve: { ox, oy, dx, dy, salida, llegada, finExplorar, vuelta }
function E.posicionViaje(v, ahora)
    ahora = ahora or getGameTime():getWorldAgeHours()
    if ahora < v.llegada then
        local f = (ahora - v.salida) / math.max(0.0001, v.llegada - v.salida)
        return mezclar(v.ox, v.dx, f), mezclar(v.oy, v.dy, f), "ida"
    elseif not v.vuelta then
        return v.dx, v.dy, "llego"
    elseif ahora < (v.finExplorar or v.llegada) then
        return v.dx, v.dy, "explorando"
    end
    local f = (ahora - v.finExplorar) / math.max(0.0001, v.vuelta - v.finExplorar)
    return mezclar(v.dx, v.ox, f), mezclar(v.dy, v.oy, f), "vuelta"
end

function E.expedicionDe(colono)
    if not colono or not colono.expedicion then
        return nil
    end
    for _, e in ipairs(E.getExpediciones().lista) do
        if e.id == colono.expedicion then
            return e
        end
    end
    return nil
end
