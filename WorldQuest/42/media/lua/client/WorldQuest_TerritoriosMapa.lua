-- WorldQuest - Territorios: dibujo en el mapa del mundo (cliente)

require "ISUI/Maps/ISWorldMap"

WorldQuest = WorldQuest or {}

local Territorios = WorldQuest.Territorios

local SEGMENTOS = 48

-- Colores (0 a 1) y opacidades
local COLOR = { r = 0.16, g = 0.42, b = 0.55 }
local ALFA_RELLENO = 0.18
local ALFA_BORDE = 0.9
local ALFA_CONTORNO = 0.35
local GROSOR_BORDE = 2
local GROSOR_CONTORNO = 5

-- Etiqueta con el nombre
local FUENTE = UIFont.Medium
local FONDO = { r = 0.1, g = 0.1, b = 0.1, a = 0.75 }
local MARGEN_X, MARGEN_Y = 6, 2
local RADIO_MINIMO_ETIQUETA = 30 -- en pixeles

-- Convierte los puntos del borde del territorio a coordenadas de pantalla
local function puntosEnPantalla(api, territorio)
    local puntos = {}
    for i = 0, SEGMENTOS do
        local angulo = (i / SEGMENTOS) * 2 * math.pi
        local mundoX = territorio.x + math.cos(angulo) * territorio.radio
        local mundoY = territorio.y + math.sin(angulo) * territorio.radio
        puntos[#puntos + 1] = {
            x = api:worldToUIX(mundoX, mundoY),
            y = api:worldToUIY(mundoX, mundoY),
        }
    end
    return puntos
end

-- Relleno: triangulos desde el centro hacia cada tramo del borde
local function dibujarRelleno(mapa, centroX, centroY, puntos)
    for i = 1, #puntos - 1 do
        local a, b = puntos[i], puntos[i + 1]
        mapa:drawTextureAllPoint(nil, centroX, centroY, a.x, a.y, b.x, b.y, b.x, b.y,
            COLOR.r, COLOR.g, COLOR.b, ALFA_RELLENO)
    end
end

-- Borde: primero un contorno oscuro grueso y encima la linea de color
local function dibujarBorde(mapa, puntos)
    for i = 1, #puntos - 1 do
        local a, b = puntos[i], puntos[i + 1]
        mapa.javaObject:DrawLine(nil, a.x, a.y, b.x, b.y, GROSOR_CONTORNO, 0, 0, 0, ALFA_CONTORNO)
    end
    for i = 1, #puntos - 1 do
        local a, b = puntos[i], puntos[i + 1]
        mapa.javaObject:DrawLine(nil, a.x, a.y, b.x, b.y, GROSOR_BORDE, COLOR.r, COLOR.g, COLOR.b, ALFA_BORDE)
    end
end

-- Nombre: texto blanco sobre un recuadro oscuro, centrado
local function dibujarEtiqueta(mapa, nombre, centroX, centroY)
    local ancho = getTextManager():MeasureStringX(FUENTE, nombre)
    local alto = getTextManager():MeasureStringY(FUENTE, nombre)

    mapa:drawRect(centroX - ancho / 2 - MARGEN_X, centroY - alto / 2 - MARGEN_Y,
        ancho + MARGEN_X * 2, alto + MARGEN_Y * 2,
        FONDO.a, FONDO.r, FONDO.g, FONDO.b)
    mapa:drawTextCentre(nombre, centroX, centroY - alto / 2, 0.95, 0.95, 0.9, 1, FUENTE)
end

local function dibujarTerritorio(mapa, territorio)
    local api = mapa.mapAPI
    local centroX = api:worldToUIX(territorio.x, territorio.y)
    local centroY = api:worldToUIY(territorio.x, territorio.y)
    local puntos = puntosEnPantalla(api, territorio)

    dibujarRelleno(mapa, centroX, centroY, puntos)
    dibujarBorde(mapa, puntos)

    -- Tamano en pantalla: distancia del centro a un punto del borde
    local dx = puntos[1].x - centroX
    local dy = puntos[1].y - centroY
    if (dx * dx + dy * dy) >= RADIO_MINIMO_ETIQUETA * RADIO_MINIMO_ETIQUETA then
        dibujarEtiqueta(mapa, territorio.nombre, centroX, centroY)
    end
end

-- Hook: guardamos el render original y lo envolvemos
local renderOriginal = ISWorldMap.render

function ISWorldMap:render()
    renderOriginal(self)

    for _, territorio in ipairs(Territorios.getDatos().lista) do
        dibujarTerritorio(self, territorio)
    end
end
