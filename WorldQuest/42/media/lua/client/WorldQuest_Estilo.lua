-- WorldQuest - Estilo visual del Centro de mando (cliente)
-- Por ahora hay un solo estilo. En la Fase 3 cada faccion tendra el suyo
-- (Estilo.actual elegira segun la faccion del jugador).

WorldQuest = WorldQuest or {}
WorldQuest.Estilo = WorldQuest.Estilo or {}

local Estilo = WorldQuest.Estilo

local ESTILOS = {
    neutral = {
        texto = { 1, 1, 1 },
        gris = { 0.7, 0.7, 0.7 },
        acento = { 1, 0.85, 0.5 },
        alerta = { 1, 0.5, 0.4 },
        bien = { 0.5, 0.9, 0.5 },
        frio = { 0.6, 0.8, 1 },
        seleccion = { 0.3, 0.5, 0.7 },
        fondoAyuda = { 0.08, 0.08, 0.08 },
        bordeAyuda = { 1, 0.85, 0.5 },
    },
}

-- Mezcla un color con blanco para que se lea bien como texto
local function aclarar(c, cuanto)
    return { c.r + (1 - c.r) * cuanto, c.g + (1 - c.g) * cuanto, c.b + (1 - c.b) * cuanto }
end

local cache = {}

-- Por ahora la faccion solo cambia el color de acento (titulos, seleccion, bordes)
function Estilo.actual()
    local base = ESTILOS.neutral
    local jugador = getPlayer()
    local f = jugador and WorldQuest.Facciones and WorldQuest.Facciones.deJugador(jugador)
    local color = f and WorldQuest.Facciones.color(f.color)
    if not color then
        return base
    end
    if not cache[color.id] then
        local estilo = {}
        for k, v in pairs(base) do
            estilo[k] = v
        end
        estilo.acento = aclarar(color, 0.35)
        estilo.bordeAyuda = aclarar(color, 0.35)
        estilo.seleccion = { color.r * 0.6, color.g * 0.6, color.b * 0.6 }
        cache[color.id] = estilo
    end
    return cache[color.id]
end
