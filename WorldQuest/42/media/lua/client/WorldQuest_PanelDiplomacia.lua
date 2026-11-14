-- WorldQuest - Pestana Diplomacia del Centro de mando (cliente)
-- Cada faccion con su estado (guerra, neutral, pacto, alianza), su reputacion y
-- las acciones posibles. Abajo, las propuestas que llegaron. Solo el lider actua.

require "WorldQuest_Panel"
require "WorldQuest_Dialogos"
require "ISUI/ISButton"
require "ISUI/ISComboBox"
require "ISUI/ISTextEntryBox"
require "ISUI/ISCollapsableWindow"

local Panel = WorldQuest.Panel
local D = WorldQuest.Diplomacia
local Red = WorldQuest.Red
local Facciones = WorldQuest.Facciones
local MARGEN, ALTO_LINEA = Panel.MARGEN, Panel.ALTO_LINEA
local ALTO_FILA = 28
local Y_TABLA = MARGEN + ALTO_LINEA * 2 + 8

local function E()
    return Panel.E()
end

-- VENTANA DE TRIBUTO ----------------------------------------------------------------
local VentanaTributo = ISCollapsableWindow:derive("WorldQuestVentanaTributo")

function VentanaTributo:new(f)
    local ancho, alto = 360, 190
    local o = ISCollapsableWindow:new((getCore():getScreenWidth() - ancho) / 2, (getCore():getScreenHeight() - alto) / 2, ancho, alto)
    setmetatable(o, self)
    self.__index = self
    o.faccion = f
    o.title = getText("IGUI_WQ_Dipl_TituloTributo", f.nombre)
    o.resizable = false
    return o
end

function VentanaTributo:createChildren()
    ISCollapsableWindow.createChildren(self)
    local y = 30
    self.comboDireccion = ISComboBox:new(MARGEN, y, 330, 22, self, nil)
    self.comboDireccion:initialise()
    self.comboDireccion:addOptionWithData(getText("IGUI_WQ_Dipl_Ofrecer"), "ofrece")
    self.comboDireccion:addOptionWithData(getText("IGUI_WQ_Dipl_Pedir"), "pide")
    self:addChild(self.comboDireccion)
    y = y + 32
    self.comboRecurso = ISComboBox:new(MARGEN, y, 200, 22, self, nil)
    self.comboRecurso:initialise()
    for _, id in ipairs(WorldQuest.Recursos.LISTA) do
        self.comboRecurso:addOptionWithData(WorldQuest.Recursos.nombre(id), id)
    end
    self.comboRecurso:addOptionWithData(WorldQuest.Recursos.nombre("cigarros"), "cigarros")
    self:addChild(self.comboRecurso)
    self.entrada = ISTextEntryBox:new("20", MARGEN + 210, y, 120, 22)
    self.entrada:initialise()
    self.entrada:instantiate()
    self.entrada:setOnlyNumbers(true)
    self:addChild(self.entrada)
    y = y + 40
    self.botonEnviar = ISButton:new(MARGEN, y, 330, 26, getText("IGUI_WQ_Dipl_EnviarTributo"), self, VentanaTributo.alEnviar)
    self.botonEnviar:initialise()
    self.botonEnviar:setTooltip(getText("IGUI_WQ_Ayuda_Tributo"))
    self:addChild(self.botonEnviar)
end

function VentanaTributo:alEnviar()
    local cantidad = tonumber(self.entrada:getText())
    if cantidad and cantidad > 0 then
        Red.pedir("proponer", { faccion = self.faccion.id, tipo = "tributo", direccion = self.comboDireccion:getSelectedData(),
            recurso = self.comboRecurso:getSelectedData(), cantidad = math.floor(cantidad) })
    end
    self:close()
end

function VentanaTributo:render()
    ISCollapsableWindow.render(self)
    if self.comboRecurso:getSelectedData() == "comida" then
        self:drawText(getText("IGUI_WQ_Dipl_EnKcal"), MARGEN + 210, 84, 0.7, 0.7, 0.7, 1, UIFont.Small)
    end
end

function VentanaTributo:close()
    ISCollapsableWindow.close(self)
    self:removeFromUIManager()
end

local function abrirTributo(f)
    local v = VentanaTributo:new(f)
    v:initialise()
    v:addToUIManager()
end

-- ACCIONES -------------------------------------------------------------------------

local function guerra(f)
    WorldQuest.Dialogos.confirmar(getText("IGUI_WQ_Dipl_ConfirmarGuerra", f.nombre), function(si)
        if si then
            Red.pedir("declararGuerra", { faccion = f.id })
        end
    end)
end

local function romper(f)
    WorldQuest.Dialogos.confirmar(getText("IGUI_WQ_Dipl_ConfirmarRomper", f.nombre), function(si)
        if si then
            Red.pedir("romperTrato", { faccion = f.id })
        end
    end)
end

local function proponer(f, tipo)
    Red.pedir("proponer", { faccion = f.id, tipo = tipo })
end

-- Botones segun el estado: { clave del texto, funcion, ayuda }
local function accionesPara(estado, f)
    local lista = {}
    if estado == "guerra" then
        table.insert(lista, { "IGUI_WQ_Dipl_BotonPaz", function() proponer(f, "paz") end, "Paz" })
    end
    if estado == "neutral" then
        table.insert(lista, { "IGUI_WQ_Dipl_BotonPacto", function() proponer(f, "pacto") end, "Pacto" })
    end
    if estado == "neutral" or estado == "pacto" then
        table.insert(lista, { "IGUI_WQ_Dipl_BotonAlianza", function() proponer(f, "alianza") end, "Alianza" })
    end
    if estado == "pacto" or estado == "alianza" then
        table.insert(lista, { "IGUI_WQ_Dipl_BotonRomper", function() romper(f) end, "Romper" })
    end
    table.insert(lista, { "IGUI_WQ_Dipl_BotonTributo", function() abrirTributo(f) end, "Tributo" })
    if estado ~= "guerra" then
        table.insert(lista, { "IGUI_WQ_Dipl_BotonGuerra", function() guerra(f) end, "Guerra" })
    end
    return lista
end

-- PESTANA ------------------------------------------------------------------------------
local Vista = Panel.Vista:derive("WorldQuestVistaDiplomacia")

function Vista:createChildren()
    self.botones = {}
    self.firma = nil
end

function Vista:alBoton(boton)
    if boton.accion then
        boton.accion()
    end
end

-- Firma de lo que hay en pantalla: si cambia, se rehacen los botones
local function firma(mia, esLider)
    local partes = { tostring(mia and mia.id), tostring(esLider) }
    for _, f in ipairs(Facciones.getDatos().lista) do
        table.insert(partes, f.id .. ":" .. (mia and D.estado(mia.id, f.id) or "-"))
    end
    for _, p in ipairs(mia and D.propuestasPara(mia.id) or {}) do
        table.insert(partes, "p" .. p.id)
    end
    return table.concat(partes, "|")
end

function Vista:boton(x, y, ancho, clave, accion, textoAyuda)
    local b = ISButton:new(x, y, ancho, 22, getText(clave), self, Vista.alBoton)
    b:initialise()
    b.accion = accion
    if textoAyuda then
        b:setTooltip(textoAyuda)
    end
    self:addChild(b)
    table.insert(self.botones, b)
    return b
end

function Vista:rehacer(mia, esLider)
    for _, b in ipairs(self.botones) do
        self:removeChild(b)
    end
    self.botones = {}
    self.filas = {}
    self.filasPropuesta = {}
    if not mia then
        return
    end
    local y = Y_TABLA
    for _, f in ipairs(Facciones.getDatos().lista) do
        if f.id ~= mia.id then
            local estado = D.estado(mia.id, f.id)
            table.insert(self.filas, { f = f, y = y, estado = estado })
            local x = self.width - MARGEN
            local acciones = accionesPara(estado, f)
            for i = #acciones, 1, -1 do
                local a = acciones[i]
                local ancho = getTextManager():MeasureStringX(UIFont.Small, getText(a[1])) + 16
                x = x - ancho - 4
                local b = self:boton(x, y + 2, ancho, a[1], a[2], getText("IGUI_WQ_Ayuda_Dipl_" .. a[3]))
                b:setEnable(esLider)
            end
            y = y + ALTO_FILA
        end
    end
    self.yPropuestas = y + ALTO_LINEA
    y = self.yPropuestas + ALTO_LINEA + 4
    for _, p in ipairs(D.propuestasPara(mia.id)) do
        table.insert(self.filasPropuesta, { p = p, y = y })
        local id = p.id
        local si = self:boton(self.width - MARGEN - 200, y, 96, "IGUI_WQ_Dipl_Aceptar",
            function() Red.pedir("responderPropuesta", { id = id, acepta = true }) end)
        local no = self:boton(self.width - MARGEN - 100, y, 96, "IGUI_WQ_Dipl_Rechazar",
            function() Red.pedir("responderPropuesta", { id = id, acepta = false }) end)
        si:setEnable(esLider)
        no:setEnable(esLider)
        y = y + ALTO_FILA
    end
end

function Vista:prerender()
    Panel.Vista.prerender(self)
    local jugador = getPlayer()
    local mia = jugador and Facciones.deJugador(jugador)
    local esLider = mia ~= nil and mia.lider == jugador:getUsername()
    local f = firma(mia, esLider)
    if f ~= self.firma then
        self.firma = f
        self:rehacer(mia, esLider)
    end
end

-- Texto de una propuesta recibida
function Panel.textoPropuesta(p, nombreDe)
    if p.tipo == "tributo" then
        local texto = WorldQuest.Recursos.texto({ [p.recurso] = p.cantidad })
        local clave = p.direccion == "pide" and "IGUI_WQ_Dipl_PideTributo" or "IGUI_WQ_Dipl_OfreceTributo"
        return getText(clave, nombreDe, texto)
    end
    return getText("IGUI_WQ_Dipl_Propone", nombreDe, getText("IGUI_WQ_Propuesta_" .. tostring(p.tipo)))
end

function Vista:dibujar()
    local e = E()
    local jugador = getPlayer()
    local mia = jugador and Facciones.deJugador(jugador)
    if not mia then
        self:texto(getText("IGUI_WQ_Panel_SinFaccion"), MARGEN, MARGEN, e.gris, nil, Panel.ayuda("SinFaccion"))
        return
    end
    local rep = D.reputacion(mia)
    local colorRep = D.malaFama(mia) and e.alerta or e.texto
    self:texto(getText("IGUI_WQ_Dipl_TuReputacion", tostring(rep)), MARGEN, MARGEN, colorRep, Panel.FUENTE_TITULO, Panel.ayuda("Reputacion"))
    if mia.lider ~= jugador:getUsername() then
        self:texto(getText("IGUI_WQ_Dipl_SoloLider"), MARGEN + 260, MARGEN + 4, e.gris)
    end

    if #(self.filas or {}) == 0 then
        self:texto(getText("IGUI_WQ_Dipl_SinOtras"), MARGEN, Y_TABLA, e.gris)
    end
    for _, fila in ipairs(self.filas or {}) do
        local f = fila.f
        local c = Facciones.color(f.color) or { r = 1, g = 1, b = 1 }
        self:drawRect(MARGEN, fila.y + 4, 12, 12, 1, c.r, c.g, c.b)
        self:texto(f.nombre, MARGEN + 18, fila.y + 4, e.texto, nil, getText("IGUI_WQ_FaccionDesc_" .. tostring(f.tipo)))
        self:texto(Facciones.nombreTipo(f.tipo), MARGEN + 190, fila.y + 4, e.gris)
        local ce = D.COLORES[fila.estado] or e.texto
        self:texto(D.nombreEstado(fila.estado), MARGEN + 330, fila.y + 4, ce, nil, Panel.ayuda("Estado_" .. fila.estado))
        local r = D.reputacion(f)
        self:texto(getText("IGUI_WQ_Dipl_Rep", tostring(r)), MARGEN + 430, fila.y + 4, D.malaFama(f) and e.alerta or e.gris, nil, Panel.ayuda("Reputacion"))
    end

    self:texto(getText("IGUI_WQ_Dipl_Propuestas"), MARGEN, self.yPropuestas or Y_TABLA, e.acento, nil, Panel.ayuda("Propuestas"))
    if #(self.filasPropuesta or {}) == 0 then
        self:texto(getText("IGUI_WQ_Dipl_SinPropuestas"), MARGEN, (self.yPropuestas or Y_TABLA) + ALTO_LINEA + 4, e.gris)
    end
    for _, fila in ipairs(self.filasPropuesta or {}) do
        local de = Facciones.porId(fila.p.de)
        local minutos = WorldQuest.Reloj.minutosHasta(fila.p.expira)
        self:texto(Panel.textoPropuesta(fila.p, de and de.nombre or "?") .. "  " .. getText("IGUI_WQ_Dipl_Expira", tostring(minutos)),
            MARGEN, fila.y + 4, e.texto)
    end
end

Panel.registrar(60, Vista, "IGUI_WQ_Tab_Diplomacia")

-- Propuesta nueva: ventana para responder al tiro (tambien queda en la pestana)
Red.mensaje("propuesta", function(args)
    local p = { tipo = args.tipo, recurso = args.recurso, cantidad = tonumber(args.cantidad), direccion = args.direccion }
    local texto = Panel.textoPropuesta(p, args.de or "?") .. ". " .. getText("IGUI_WQ_Dipl_PreguntaAceptar")
    local id = args.id
    WorldQuest.Dialogos.confirmar(texto, function(si)
        Red.pedir("responderPropuesta", { id = id, acepta = si })
    end)
end)
