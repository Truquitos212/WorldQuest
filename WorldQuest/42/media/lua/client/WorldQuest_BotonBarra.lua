-- WorldQuest - Boton del panel de la colonia en la barra de la izquierda (cliente)

require "ISUI/ISButton"

WorldQuest = WorldQuest or {}

-- Botones del juego en la barra, para saber donde termina
local BOTONES_BARRA = { "invBtn", "healthBtn", "craftingBtn", "buildBtn", "movableBtn",
    "searchBtn", "zoneBtn", "mapBtn", "debugBtn", "arfBtn" }
local SEPARACION = 4

local texturaOn, texturaOff = nil, nil
local barraConBoton = nil

local function cargarTexturas()
    if not texturaOn then
        texturaOn = getTexture("media/ui/WorldQuest/Colonia_On.png")
        texturaOff = getTexture("media/ui/WorldQuest/Colonia_Off.png")
    end
end

local function alHacerClic()
    if WorldQuest.Panel then
        WorldQuest.Panel.alternar()
    end
end

-- Parte de abajo del ultimo boton visible de la barra
local function fondoDeLaBarra(barra)
    local fondo = 0
    for _, nombre in ipairs(BOTONES_BARRA) do
        local b = barra[nombre]
        if b and b:isVisible() then
            fondo = math.max(fondo, b:getY() + b:getHeight())
        end
    end
    return fondo
end

local BotonColonia = ISButton:derive("WorldQuestBotonColonia")

-- En cada frame se acomoda debajo del ultimo boton (la barra cambia de tamano)
function BotonColonia:prerender()
    local barra = self.parent
    local referencia = barra and barra.invBtn
    if referencia then
        self:setX(referencia:getX())
        self:setWidth(referencia:getWidth())
        self:setHeight(referencia:getHeight())
        local y = fondoDeLaBarra(barra) + SEPARACION
        self:setY(y)
        if barra:getHeight() < y + self:getHeight() then
            barra:setHeight(y + self:getHeight())
        end
    end

    if WorldQuest.Panel and WorldQuest.Panel.instancia then
        self:setImage(texturaOn)
    else
        self:setImage(texturaOff)
    end
    ISButton.prerender(self)
end

-- La barra se crea junto con el jugador: se revisa hasta que exista
local function intentarAgregar()
    local datos = getPlayerData(0)
    local barra = datos and datos.equipped
    if not barra or not barra.invBtn or barraConBoton == barra then
        return
    end

    cargarTexturas()
    local referencia = barra.invBtn
    local boton = BotonColonia:new(referencia:getX(), 0, referencia:getWidth(), referencia:getHeight(),
        "", nil, alHacerClic)
    boton:initialise()
    boton:setDisplayBackground(false)
    boton.borderColor = { r = 1, g = 1, b = 1, a = 0 }
    boton:setTooltip(getText("IGUI_WQ_Panel_Boton"))
    barra:addChild(boton)
    barraConBoton = barra
    print("[WorldQuest] Boton de la colonia agregado a la barra")
end

Events.OnPlayerUpdate.Add(intentarAgregar)
