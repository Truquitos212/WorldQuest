-- WorldQuest - Ventanas chicas reutilizables (cliente): confirmar y escribir un texto

require "ISUI/ISModalDialog"
require "ISUI/ISTextBox"

WorldQuest = WorldQuest or {}
WorldQuest.Dialogos = WorldQuest.Dialogos or {}

local Dialogos = WorldQuest.Dialogos

local function centro(ancho, alto)
    return (getCore():getScreenWidth() - ancho) / 2, (getCore():getScreenHeight() - alto) / 2
end

-- Si / No. alResponder(si) se llama con true o false.
function Dialogos.confirmar(texto, alResponder)
    local ancho, alto = 420, 160
    local x, y = centro(ancho, alto)
    local jugador = getPlayer()
    local ventana = ISModalDialog:new(x, y, ancho, alto, texto, true, nil,
        function(_, boton) alResponder(boton.internal == "YES") end, jugador and jugador:getPlayerNum() or 0)
    ventana:initialise()
    ventana:addToUIManager()
    return ventana
end

-- Pide un texto. alConfirmar(texto) solo se llama si el jugador acepta.
function Dialogos.pedirTexto(titulo, inicial, alConfirmar)
    local ancho, alto = 300, 180
    local x, y = centro(ancho, alto)
    local jugador = getPlayer()
    local ventana = ISTextBox:new(x, y, ancho, alto, titulo, inicial or "", nil,
        function(_, boton)
            if boton.internal == "OK" then
                alConfirmar(boton.parent.entry:getText())
            end
        end, jugador and jugador:getPlayerNum() or 0)
    ventana:initialise()
    ventana:addToUIManager()
    return ventana
end
