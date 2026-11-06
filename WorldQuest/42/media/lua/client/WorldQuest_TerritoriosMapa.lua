-- WorldQuest - Territorios: dibujo en el mapa del mundo (cliente)

require "ISUI/Maps/ISWorldMap"

WorldQuest = WorldQuest or {}

local Territorios = WorldQuest.Territorios

local SEGMENTOS = 48

-- Colores (0 a 1) y opacidades
local COLOR = { r = 0.16, g = 0.42, b = 0.55 }
local COLOR_ALERTA = { r = 0.75, g = 0.25, b = 0.15 }
local ALFA_RELLENO = 0.18
local ALFA_BORDE = 0.9
local ALFA_CONTORNO = 0.35
local GROSOR_BORDE = 2
local GROSOR_CONTORNO = 5

-- Etiqueta con el nombre y las alertas
local FUENTE = UIFont.Medium
local FUENTE_ALERTA = UIFont.Small
local COLOR_TEXTO_ALERTA = { r = 1.0, g = 0.7, b = 0.4 }
local FONDO = { r = 0.1, g = 0.1, b = 0.1, a = 0.75 }
local MARGEN_X, MARGEN_Y = 6, 2
local RADIO_MINIMO_ETIQUETA = 30 -- en pixeles

-- Arma, por id de territorio, la lista de alertas (crisis avisadas y frio)
local function juntarAlertas()
    local alertas = {}
    local Crisis = WorldQuest.Crisis
    if not Crisis then
        return alertas
    end

    local datos = Crisis.getDatos()
    local ahora = getGameTime():getWorldAgeHours()

    for _, pendiente in ipairs(datos.pendientes) do
        local ficha = Crisis.tipos[pendiente.tipo]
        -- Solo las crisis con aviso: las de sorpresa no se muestran
        if ficha and ficha.textoAviso then
            local nombre = getText("IGUI_WQ_Crisis_" .. pendiente.tipo)
            local horas = math.ceil(pendiente.hora - ahora)
            local texto
            if horas > 0 then
                texto = getText("IGUI_WQ_MapaPendiente", nombre, tostring(horas))
            else
                texto = getText("IGUI_WQ_MapaEsperando", nombre)
            end
            alertas[pendiente.territorio] = alertas[pendiente.territorio] or {}
            table.insert(alertas[pendiente.territorio], texto)
        end
    end

    if datos.frio then
        alertas[datos.frio.territorio] = alertas[datos.frio.territorio] or {}
        table.insert(alertas[datos.frio.territorio], getText("IGUI_WQ_MapaFrio"))
    end

    return alertas
end

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
local function dibujarRelleno(mapa, centroX, centroY, puntos, color)
    for i = 1, #puntos - 1 do
        local a, b = puntos[i], puntos[i + 1]
        mapa:drawTextureAllPoint(nil, centroX, centroY, a.x, a.y, b.x, b.y, b.x, b.y,
            color.r, color.g, color.b, ALFA_RELLENO)
    end
end

-- Borde: primero un contorno oscuro grueso y encima la linea de color
local function dibujarBorde(mapa, puntos, color)
    for i = 1, #puntos - 1 do
        local a, b = puntos[i], puntos[i + 1]
        mapa.javaObject:DrawLine(nil, a.x, a.y, b.x, b.y, GROSOR_CONTORNO, 0, 0, 0, ALFA_CONTORNO)
    end
    for i = 1, #puntos - 1 do
        local a, b = puntos[i], puntos[i + 1]
        mapa.javaObject:DrawLine(nil, a.x, a.y, b.x, b.y, GROSOR_BORDE, color.r, color.g, color.b, ALFA_BORDE)
    end
end

-- Nombre y alertas: textos centrados sobre un recuadro oscuro
local function dibujarEtiqueta(mapa, nombre, lineas, centroX, centroY)
    local tm = getTextManager()
    local ancho = tm:MeasureStringX(FUENTE, nombre)
    local altoNombre = tm:MeasureStringY(FUENTE, nombre)
    local alto = altoNombre

    for _, linea in ipairs(lineas) do
        ancho = math.max(ancho, tm:MeasureStringX(FUENTE_ALERTA, linea))
        alto = alto + tm:MeasureStringY(FUENTE_ALERTA, linea)
    end

    local arriba = centroY - alto / 2
    mapa:drawRect(centroX - ancho / 2 - MARGEN_X, arriba - MARGEN_Y,
        ancho + MARGEN_X * 2, alto + MARGEN_Y * 2,
        FONDO.a, FONDO.r, FONDO.g, FONDO.b)
    mapa:drawTextCentre(nombre, centroX, arriba, 0.95, 0.95, 0.9, 1, FUENTE)

    local y = arriba + altoNombre
    for _, linea in ipairs(lineas) do
        mapa:drawTextCentre(linea, centroX, y,
            COLOR_TEXTO_ALERTA.r, COLOR_TEXTO_ALERTA.g, COLOR_TEXTO_ALERTA.b, 1, FUENTE_ALERTA)
        y = y + tm:MeasureStringY(FUENTE_ALERTA, linea)
    end
end

local function dibujarTerritorio(mapa, territorio, lineas)
    local api = mapa.mapAPI
    local centroX = api:worldToUIX(territorio.x, territorio.y)
    local centroY = api:worldToUIY(territorio.x, territorio.y)
    local puntos = puntosEnPantalla(api, territorio)
    local color = COLOR
    if #lineas > 0 then
        color = COLOR_ALERTA
    end

    dibujarRelleno(mapa, centroX, centroY, puntos, color)
    dibujarBorde(mapa, puntos, color)

    -- Tamano en pantalla: distancia del centro a un punto del borde
    local dx = puntos[1].x - centroX
    local dy = puntos[1].y - centroY
    if (dx * dx + dy * dy) >= RADIO_MINIMO_ETIQUETA * RADIO_MINIMO_ETIQUETA then
        dibujarEtiqueta(mapa, territorio.nombre, lineas, centroX, centroY)
    end
end

-- Hook: guardamos el render original y lo envolvemos
local renderOriginal = ISWorldMap.render

function ISWorldMap:render()
    renderOriginal(self)

    local alertas = juntarAlertas()
    for _, territorio in ipairs(Territorios.getDatos().lista) do
        dibujarTerritorio(self, territorio, alertas[territorio.id] or {})
    end
end
