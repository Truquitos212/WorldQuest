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
}

local PanelBanner = ISPanel:derive("WorldQuestBanner")

function PanelBanner:new(texto, color)
    local ancho = math.max(ANCHO_MINIMO, getTextManager():MeasureStringX(FUENTE, texto) + MARGEN * 2)
    local x = (getCore():getScreenWidth() - ancho) / 2
    local o = ISPanel:new(x, POSICION_Y, ancho, ALTO)
    setmetatable(o, self)
    self.__index = self
    o.texto = texto
    o.color = color
    o.inicio = getTimestampMs()
    return o
end

-- Opacidad actual: 1 casi todo el tiempo, baja a 0 en el ultimo segundo
function PanelBanner:alfa()
    local restante = DURACION_MS - (getTimestampMs() - self.inicio)
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
    local altoTexto = getTextManager():MeasureStringY(FUENTE, self.texto)
    self:drawTextCentre(self.texto, self.width / 2, (self.height - altoTexto) / 2, 1, 1, 1, a, FUENTE)
end

function PanelBanner:update()
    if self:alfa() <= 0 then
        self:removeFromUIManager()
        if Banner.actual == self then
            Banner.actual = nil
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
