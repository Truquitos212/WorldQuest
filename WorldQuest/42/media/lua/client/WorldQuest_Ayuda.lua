-- WorldQuest - Tooltips reutilizables (cliente)
-- Cualquier panel puede registrar zonas con un texto de ayuda y dibujar el
-- tooltip de la zona que esta bajo el mouse.

WorldQuest = WorldQuest or {}
WorldQuest.Ayuda = WorldQuest.Ayuda or {}

local Ayuda = WorldQuest.Ayuda
local FUENTE = UIFont.Small
local ANCHO_MAXIMO = 300
local MARGEN = 6

-- Parte un texto en lineas que caben en el ancho dado
function Ayuda.envolver(texto, ancho, fuente)
    fuente = fuente or FUENTE
    local tm = getTextManager()
    local lineas, linea = {}, ""
    for palabra in string.gmatch(texto, "%S+") do
        local prueba = (linea == "") and palabra or (linea .. " " .. palabra)
        if linea ~= "" and tm:MeasureStringX(fuente, prueba) > ancho then
            table.insert(lineas, linea)
            linea = palabra
        else
            linea = prueba
        end
    end
    if linea ~= "" then
        table.insert(lineas, linea)
    end
    return lineas
end

-- Dibuja un tooltip en el elemento, cerca de la posicion (mx, my)
function Ayuda.dibujar(elemento, texto, mx, my)
    local estilo = WorldQuest.Estilo.actual()
    local tm = getTextManager()
    local lineas = Ayuda.envolver(texto, ANCHO_MAXIMO)
    local altoLinea = tm:getFontHeight(FUENTE)
    local ancho = 0
    for _, linea in ipairs(lineas) do
        ancho = math.max(ancho, tm:MeasureStringX(FUENTE, linea))
    end
    ancho = ancho + MARGEN * 2
    local alto = #lineas * altoLinea + MARGEN * 2

    local x = math.min(mx + 14, elemento.width - ancho - 4)
    local y = my + 18
    if y + alto > elemento.height then
        y = my - alto - 6
    end
    x = math.max(2, x)
    y = math.max(2, y)

    local f, b = estilo.fondoAyuda, estilo.bordeAyuda
    elemento:drawRect(x, y, ancho, alto, 0.92, f[1], f[2], f[3])
    elemento:drawRectBorder(x, y, ancho, alto, 0.8, b[1], b[2], b[3])
    for i, linea in ipairs(lineas) do
        elemento:drawText(linea, x + MARGEN, y + MARGEN + (i - 1) * altoLinea, 1, 1, 1, 1, FUENTE)
    end
end

-- Zonas: { x, y, w, h, texto }. Dibuja el tooltip de la que esta bajo el mouse.
function Ayuda.dibujarZonas(elemento, zonas)
    if not zonas or not elemento:isMouseOver() then
        return
    end
    local mx, my = elemento:getMouseX(), elemento:getMouseY()
    for i = #zonas, 1, -1 do
        local z = zonas[i]
        if mx >= z.x and mx <= z.x + z.w and my >= z.y and my <= z.y + z.h then
            Ayuda.dibujar(elemento, z.texto, mx, my)
            return
        end
    end
end
