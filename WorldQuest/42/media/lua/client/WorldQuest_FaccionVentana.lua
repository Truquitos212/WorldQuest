-- WorldQuest - Ventana para crear una faccion o unirse a una (cliente)
-- Se abre sola al entrar si el jugador todavia no tiene faccion, y desde la
-- pestana Faccion del Centro de mando.

require "ISUI/ISCollapsableWindow"
require "ISUI/ISButton"
require "ISUI/ISComboBox"
require "ISUI/ISTextEntryBox"

WorldQuest = WorldQuest or {}
WorldQuest.FaccionVentana = WorldQuest.FaccionVentana or {}

local FV = WorldQuest.FaccionVentana
local Facciones = WorldQuest.Facciones
local Red = WorldQuest.Red

local ANCHO, ALTO = 560, 600
local MARGEN = 14
local FUENTE = UIFont.Small
local ALTO_LINEA = getTextManager():getFontHeight(FUENTE) + 4
local X_CAMPO = 110
local ESPERA_AUTO_MS = 6000      -- espera a que lleguen los datos antes de abrirse sola

local Ventana = ISCollapsableWindow:derive("WorldQuestVentanaFaccion")

function Ventana:new(x, y)
    local o = ISCollapsableWindow:new(x, y, ANCHO, ALTO)
    setmetatable(o, self)
    self.__index = self
    o.title = getText("IGUI_WQ_FV_Titulo")
    o.resizable = false
    return o
end

local function etiqueta(self, clave, y)
    local texto = getText(clave)
    self.etiquetas = self.etiquetas or {}
    table.insert(self.etiquetas, { texto = texto, y = y })
end

function Ventana:createChildren()
    ISCollapsableWindow.createChildren(self)
    local y = (self.titleBarHeight and self:titleBarHeight() or 16) + MARGEN + ALTO_LINEA + 4
    self.yCrear = y - ALTO_LINEA - 4

    -- Tipo
    etiqueta(self, "IGUI_WQ_FV_Tipo", y)
    self.comboTipo = ISComboBox:new(X_CAMPO, y - 2, 220, 22, self, Ventana.alCambiarTipo)
    self.comboTipo:initialise()
    for _, tipo in ipairs(Facciones.TIPOS) do
        self.comboTipo:addOptionWithData(Facciones.nombreTipo(tipo), tipo)
    end
    self:addChild(self.comboTipo)
    y = y + 30
    self.yDescripcion = y
    y = y + ALTO_LINEA * 9 + 6

    -- Rasgo del lider (depende del tipo)
    etiqueta(self, "IGUI_WQ_FV_Rasgo", y)
    self.comboRasgo = ISComboBox:new(X_CAMPO, y - 2, 220, 22, self, nil)
    self.comboRasgo:initialise()
    self:addChild(self.comboRasgo)
    self:llenarRasgos(Facciones.TIPOS[1])
    y = y + 26
    self.yRasgo = y
    y = y + ALTO_LINEA + 6

    -- Nombre
    etiqueta(self, "IGUI_WQ_FV_Nombre", y)
    self.entradaNombre = ISTextEntryBox:new(Facciones.nombreTipo(Facciones.TIPOS[1]), X_CAMPO, y - 2, 220, 22)
    self.entradaNombre:initialise()
    self.entradaNombre:instantiate()
    self:addChild(self.entradaNombre)
    y = y + 30

    -- Color
    etiqueta(self, "IGUI_WQ_FV_Color", y)
    self.comboColor = ISComboBox:new(X_CAMPO, y - 2, 220, 22, self, nil)
    self.comboColor:initialise()
    for _, c in ipairs(Facciones.COLORES) do
        self.comboColor:addOptionWithData(getText("IGUI_WQ_Color_" .. c.id), c.id)
    end
    self:addChild(self.comboColor)
    y = y + 30

    -- Emblema
    etiqueta(self, "IGUI_WQ_FV_Emblema", y)
    self.comboEmblema = ISComboBox:new(X_CAMPO, y - 2, 220, 22, self, nil)
    self.comboEmblema:initialise()
    for _, e in ipairs(Facciones.EMBLEMAS) do
        self.comboEmblema:addOptionWithData(getText("IGUI_WQ_Emblema_" .. e), e)
    end
    self:addChild(self.comboEmblema)
    y = y + 34

    self.botonCrear = ISButton:new(X_CAMPO, y, 220, 26, getText("IGUI_WQ_FV_Crear"), self, Ventana.alCrear)
    self.botonCrear:initialise()
    self.botonCrear:setTooltip(getText("IGUI_WQ_Ayuda_CrearFaccion"))
    self:addChild(self.botonCrear)
    y = y + 44

    -- Unirse
    self.yUnirse = y
    y = y + ALTO_LINEA + 6
    self.comboUnirse = ISComboBox:new(MARGEN, y, 300, 22, self, nil)
    self.comboUnirse:initialise()
    self:addChild(self.comboUnirse)
    self.botonUnirse = ISButton:new(MARGEN + 310, y, 160, 24, getText("IGUI_WQ_FV_Unirse"), self, Ventana.alUnirse)
    self.botonUnirse:initialise()
    self.botonUnirse:setTooltip(getText("IGUI_WQ_Ayuda_Unirse"))
    self:addChild(self.botonUnirse)
    self:llenarUnirse()
end

function Ventana:llenarRasgos(tipo)
    self.comboRasgo:clear()
    for _, rasgo in ipairs(WorldQuest.Balance.RASGOS_DE[tipo] or {}) do
        self.comboRasgo:addOptionWithData(getText("IGUI_WQ_Rasgo_" .. rasgo), rasgo)
    end
end

function Ventana:alCambiarTipo(combo)
    self:llenarRasgos(combo:getSelectedData())
    -- Si el jugador no cambio el nombre, sigue al tipo elegido
    local actual = self.entradaNombre:getText()
    for _, tipo in ipairs(Facciones.TIPOS) do
        if actual == Facciones.nombreTipo(tipo) then
            self.entradaNombre:setText(Facciones.nombreTipo(combo:getSelectedData()))
            return
        end
    end
end

function Ventana:llenarUnirse()
    self.comboUnirse:clear()
    self.cantidadFacciones = 0
    for _, f in ipairs(Facciones.getDatos().lista) do
        self.comboUnirse:addOptionWithData(getText("IGUI_WQ_FV_OpcionUnirse", f.nombre, f.lider), f.id)
        self.cantidadFacciones = self.cantidadFacciones + 1
    end
end

function Ventana:alCrear()
    local nombre = WorldQuest.Territorios.limpiarNombre(self.entradaNombre:getText())
        or Facciones.nombreTipo(self.comboTipo:getSelectedData())
    Red.pedir("crearFaccion", {
        tipo = self.comboTipo:getSelectedData(),
        nombre = nombre,
        color = self.comboColor:getSelectedData(),
        emblema = self.comboEmblema:getSelectedData(),
        rasgo = self.comboRasgo:getSelectedData(),
    })
end

function Ventana:alUnirse()
    local id = self.comboUnirse:getSelectedData()
    if id then
        Red.pedir("pedirUnion", { faccion = id })
    end
end

function Ventana:prerender()
    ISCollapsableWindow.prerender(self)
    -- Si ya tiene faccion (o la recien creada llego desde el servidor), se cierra
    if Facciones.deJugador(getPlayer()) then
        self:close()
        return
    end
    if #Facciones.getDatos().lista ~= self.cantidadFacciones then
        self:llenarUnirse()
    end
    self.botonUnirse:setEnable(self.cantidadFacciones > 0)
    self.comboUnirse:setVisible(self.cantidadFacciones > 0)
end

function Ventana:render()
    ISCollapsableWindow.render(self)
    local e = WorldQuest.Estilo.actual()
    self:drawText(getText("IGUI_WQ_FV_SeccionCrear"), MARGEN, self.yCrear, e.acento[1], e.acento[2], e.acento[3], 1, UIFont.Medium)
    for _, et in ipairs(self.etiquetas or {}) do
        self:drawText(et.texto, MARGEN, et.y, e.gris[1], e.gris[2], e.gris[3], 1, FUENTE)
    end

    -- Descripcion del tipo elegido, sus efectos y lo que llega mas adelante
    local B = WorldQuest.Balance
    local tipo = self.comboTipo:getSelectedData()
    local ancho = self.width - X_CAMPO - MARGEN
    local y = self.yDescripcion
    for _, linea in ipairs(WorldQuest.Ayuda.envolver(getText("IGUI_WQ_FaccionDesc_" .. tostring(tipo)), ancho)) do
        self:drawText(linea, X_CAMPO, y, 1, 1, 1, 1, FUENTE)
        y = y + ALTO_LINEA
    end
    y = y + 2
    local efectos = {}
    for _, item in ipairs(B.lista(B.FACCIONES[tipo] or {})) do
        table.insert(efectos, item)
    end
    local x = X_CAMPO
    for _, item in ipairs(efectos) do
        local c = item.bueno and e.bien or e.alerta
        local w = getTextManager():MeasureStringX(FUENTE, item.texto) + 12
        if x + w > self.width - MARGEN then
            x = X_CAMPO
            y = y + ALTO_LINEA
        end
        self:drawText(item.texto, x, y, c[1], c[2], c[3], 1, FUENTE)
        x = x + w
    end
    y = y + ALTO_LINEA
    local pendientes = B.PENDIENTES[tipo]
    if pendientes then
        local nombres = {}
        for _, id in ipairs(pendientes) do
            table.insert(nombres, getText("IGUI_WQ_Pendiente_" .. id))
        end
        for _, linea in ipairs(WorldQuest.Ayuda.envolver(getText("IGUI_WQ_FV_Pendientes", table.concat(nombres, ", ")), ancho)) do
            self:drawText(linea, X_CAMPO, y, e.gris[1], e.gris[2], e.gris[3], 1, FUENTE)
            y = y + ALTO_LINEA
        end
    end

    -- Efecto del rasgo elegido
    local rasgo = self.comboRasgo:getSelectedData()
    local textoRasgo = {}
    for _, item in ipairs(B.lista(B.RASGOS[rasgo] or {})) do
        table.insert(textoRasgo, item.texto)
    end
    if #textoRasgo > 0 then
        self:drawText(table.concat(textoRasgo, "  "), X_CAMPO, self.yRasgo, e.bien[1], e.bien[2], e.bien[3], 1, FUENTE)
    end

    self:drawText(getText("IGUI_WQ_FV_SeccionUnirse"), MARGEN, self.yUnirse, e.acento[1], e.acento[2], e.acento[3], 1, UIFont.Medium)
    if self.cantidadFacciones == 0 then
        self:drawText(getText("IGUI_WQ_FV_SinFacciones"), MARGEN, self.yUnirse + ALTO_LINEA + 8, e.gris[1], e.gris[2], e.gris[3], 1, FUENTE)
    end
end

function Ventana:close()
    ISCollapsableWindow.close(self)
    self:removeFromUIManager()
    FV.instancia = nil
end

function FV.abrir()
    if FV.instancia then
        return
    end
    local x = (getCore():getScreenWidth() - ANCHO) / 2
    local y = (getCore():getScreenHeight() - ALTO) / 2
    local ventana = Ventana:new(x, y)
    ventana:initialise()
    ventana:addToUIManager()
    FV.instancia = ventana
end

-- El lider recibe la solicitud de alguien que quiere unirse
local function alResponderSolicitud(target, boton, usuario)
    Red.pedir("responderUnion", { usuario = usuario, acepta = boton.internal == "YES" })
end

Red.mensaje("pedirUnion", function(args)
    local ancho, alto = 420, 150
    local x = (getCore():getScreenWidth() - ancho) / 2
    local y = (getCore():getScreenHeight() - alto) / 2
    local ventana = ISModalDialog:new(x, y, ancho, alto, getText("IGUI_WQ_SolicitudRecibida", args.usuario), true,
        nil, alResponderSolicitud, 0, args.usuario)
    ventana:initialise()
    ventana:addToUIManager()
end)

-- Se abre sola una vez por sesion, si el jugador no tiene faccion
local inicio = nil
local abiertaSola = false

local function revisar()
    if isServer() or abiertaSola then
        return
    end
    local jugador = getPlayer()
    if not jugador then
        return
    end
    local ahora = getTimestampMs()
    inicio = inicio or ahora
    if ahora - inicio < ESPERA_AUTO_MS then
        return
    end
    abiertaSola = true
    if not Facciones.deJugador(jugador) then
        FV.abrir()
    end
end

Events.EveryOneMinute.Add(revisar)
