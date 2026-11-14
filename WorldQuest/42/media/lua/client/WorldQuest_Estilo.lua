-- WorldQuest - Estilo visual del Centro de mando (cliente)
-- Cada tipo de faccion tiene su propio fondo y su linea de borde (militar, tierra,
-- oxido, cuero...). El color elegido por la faccion tine titulos, seleccion y bordes.
-- Tambien entrega los iconos (emblemas y recursos).

WorldQuest = WorldQuest or {}
WorldQuest.Estilo = WorldQuest.Estilo or {}

local Estilo = WorldQuest.Estilo

local BASE = {
    texto = { 1, 1, 1 },
    gris = { 0.7, 0.7, 0.7 },
    acento = { 1, 0.85, 0.5 },
    alerta = { 1, 0.5, 0.4 },
    bien = { 0.5, 0.9, 0.5 },
    frio = { 0.6, 0.8, 1 },
    seleccion = { 0.3, 0.5, 0.7 },
    fondoAyuda = { 0.08, 0.08, 0.08 },
    bordeAyuda = { 1, 0.85, 0.5 },
    fondo = { 0.08, 0.08, 0.08 },
    linea = { 0.4, 0.4, 0.4 },
}

-- Fondo y linea de cada tipo de faccion
local TIPOS = {
    leales      = { fondo = { 0.09, 0.11, 0.08 }, linea = { 0.45, 0.52, 0.30 } },  -- radio militar
    comuna      = { fondo = { 0.13, 0.10, 0.07 }, linea = { 0.62, 0.48, 0.30 } },  -- cuaderno, tierra
    chatarreros = { fondo = { 0.12, 0.09, 0.07 }, linea = { 0.66, 0.36, 0.18 } },  -- oxido
    caravana    = { fondo = { 0.13, 0.11, 0.08 }, linea = { 0.78, 0.68, 0.45 } },  -- mapas de rutas
    carroneros  = { fondo = { 0.09, 0.07, 0.10 }, linea = { 0.85, 0.30, 0.65 } },  -- grafiti
    devotos     = { fondo = { 0.08, 0.07, 0.12 }, linea = { 0.78, 0.66, 0.30 } },  -- vitrales y velas
    moteros     = { fondo = { 0.07, 0.07, 0.08 }, linea = { 0.75, 0.78, 0.82 } },  -- cromo y cuero
    preppers    = { fondo = { 0.08, 0.10, 0.08 }, linea = { 0.55, 0.60, 0.50 } },  -- latas, manuales
    fugados     = { fondo = { 0.12, 0.08, 0.05 }, linea = { 0.95, 0.50, 0.15 } },  -- overol naranjo
}

-- Mezcla un color con blanco para que se lea bien como texto
local function aclarar(c, cuanto)
    return { c.r + (1 - c.r) * cuanto, c.g + (1 - c.g) * cuanto, c.b + (1 - c.b) * cuanto }
end

local cache = {}

function Estilo.de(f)
    if not f then
        return BASE
    end
    local llave = tostring(f.tipo) .. "/" .. tostring(f.color)
    if cache[llave] then
        return cache[llave]
    end
    local estilo = {}
    for k, v in pairs(BASE) do
        estilo[k] = v
    end
    local tipo = TIPOS[f.tipo]
    if tipo then
        estilo.fondo = tipo.fondo
        estilo.linea = tipo.linea
        estilo.fondoAyuda = { tipo.fondo[1] * 0.8, tipo.fondo[2] * 0.8, tipo.fondo[3] * 0.8 }
    end
    local color = WorldQuest.Facciones and WorldQuest.Facciones.color(f.color)
    if color then
        estilo.acento = aclarar(color, 0.35)
        estilo.bordeAyuda = aclarar(color, 0.35)
        estilo.seleccion = { color.r * 0.6, color.g * 0.6, color.b * 0.6 }
    end
    cache[llave] = estilo
    return estilo
end

function Estilo.actual()
    local jugador = getPlayer()
    local f = jugador and WorldQuest.Facciones and WorldQuest.Facciones.deJugador(jugador)
    return Estilo.de(f)
end

-- Pinta el fondo y el borde de una ventana con el estilo de la faccion del jugador
function Estilo.aplicarVentana(ventana)
    local e = Estilo.actual()
    ventana.backgroundColor = { r = e.fondo[1], g = e.fondo[2], b = e.fondo[3], a = 0.92 }
    ventana.borderColor = { r = e.linea[1], g = e.linea[2], b = e.linea[3], a = 0.8 }
end

-- ICONOS -------------------------------------------------------------------------------
local texturas = {}

function Estilo.textura(ruta)
    if texturas[ruta] == nil then
        texturas[ruta] = getTexture(ruta) or false
    end
    return texturas[ruta] or nil
end

function Estilo.emblema(f)
    return f and Estilo.textura("media/ui/WorldQuest/Emblema_" .. tostring(f.emblema) .. ".png") or nil
end

function Estilo.recurso(id)
    return Estilo.textura("media/ui/WorldQuest/Recurso_" .. tostring(id) .. ".png")
end

-- Dibuja el emblema de la faccion con su color (o un cuadrado si no hay textura)
function Estilo.dibujarEmblema(el, f, x, y, tamano)
    local c = WorldQuest.Facciones.color(f.color) or { r = 1, g = 1, b = 1 }
    local tex = Estilo.emblema(f)
    if tex then
        el:drawTextureScaled(tex, x, y, tamano, tamano, 1, c.r, c.g, c.b)
    else
        el:drawRect(x, y, tamano, tamano, 1, c.r, c.g, c.b)
    end
end
