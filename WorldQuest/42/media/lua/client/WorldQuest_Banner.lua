-- WorldQuest - Aviso grande en pantalla (cliente)

require "ISUI/ISPanel"

WorldQuest = WorldQuest or {}
WorldQuest.Banner = WorldQuest.Banner or {}

local Banner = WorldQuest.Banner

local DURACION_MS = 6000    -- tiempo visible, en milisegundos
local DESVANECER_MS = 1000  -- el ultimo segundo se va apagando
local FUENTE = UIFont.Large
local ALTO = 50
local ANCHO_MINIMO = 400
local MARGEN = 30
local POSICION_Y = 80

local COLORES = {
    aviso = { r = 0.85, g = 0.6, b = 0.15 },  -- naranja: viene algo
    crisis = { r = 0.75, g = 0.2, b = 0.15 }, -- rojo: esta pasando
    pista = { r = 0.3, g = 0.55, b = 0.85 },  -- azul: pista de primera vez
}
local POSICION_Y_PISTA = POSICION_Y + ALTO + 12
local DURACION_PISTA_MS = 10000

local PanelBanner = ISPanel:derive("WorldQuestBanner")

function PanelBanner:new(texto, color, y, duracion, fuente)
    fuente = fuente or FUENTE
    local ancho = math.max(ANCHO_MINIMO, getTextManager():MeasureStringX(fuente, texto) + MARGEN * 2)
    local x = (getCore():getScreenWidth() - ancho) / 2
    local o = ISPanel:new(x, y or POSICION_Y, ancho, ALTO)
    setmetatable(o, self)
    self.__index = self
    o.texto = texto
    o.color = color
    o.fuente = fuente
    o.duracion = duracion or DURACION_MS
    o.inicio = getTimestampMs()
    return o
end

-- Opacidad actual: 1 casi todo el tiempo, baja a 0 en el ultimo segundo
function PanelBanner:alfa()
    local restante = self.duracion - (getTimestampMs() - self.inicio)
    if restante <= 0 then
        return 0
    end
    return math.min(1, restante / DESVANECER_MS)
end

function PanelBanner:prerender()
    local a = self:alfa()
    self:drawRect(0, 0, self.width, self.height, 0.8 * a, 0.08, 0.08, 0.08)
    self:drawRect(0, 0, self.width, 4, a, self.color.r, self.color.g, self.color.b)
end

function PanelBanner:render()
    local a = self:alfa()
    local altoTexto = getTextManager():MeasureStringY(self.fuente, self.texto)
    self:drawTextCentre(self.texto, self.width / 2, (self.height - altoTexto) / 2, 1, 1, 1, a, self.fuente)
end

function PanelBanner:update()
    if self:alfa() <= 0 then
        self:removeFromUIManager()
        if Banner.actual == self then
            Banner.actual = nil
        end
        if Banner.pista == self then
            Banner.pista = nil
        end
    end
end

-- tipo: "aviso" o "crisis"
function Banner.mostrar(texto, tipo)
    if Banner.actual then
        Banner.actual:removeFromUIManager()
    end
    local panel = PanelBanner:new(texto, COLORES[tipo] or COLORES.crisis)
    panel:initialise()
    panel:addToUIManager()
    panel:setAlwaysOnTop(true)
    Banner.actual = panel
end

-- Pista de primera vez: mas abajo, en azul y con letra mas chica
function Banner.mostrarPista(texto)
    if Banner.pista then
        Banner.pista:removeFromUIManager()
    end
    local panel = PanelBanner:new(texto, COLORES.pista, POSICION_Y_PISTA, DURACION_PISTA_MS, UIFont.Medium)
    panel:initialise()
    panel:addToUIManager()
    panel:setAlwaysOnTop(true)
    Banner.pista = panel
end
