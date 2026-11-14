-- WorldQuest - Comercio y mercenarios (cliente)
-- Pestana Comercio del Centro de mando, ventana para comerciar con mercenarios,
-- y en el mapa: mercenarios, caravanas y las opciones de emboscar y contratar.

require "WorldQuest_Panel"
require "WorldQuest_Dialogos"
require "WorldQuest_MapaMando"
require "ISUI/ISButton"
require "ISUI/ISComboBox"
require "ISUI/ISTextEntryBox"
require "ISUI/ISCollapsableWindow"

local Panel = WorldQuest.Panel
local C = WorldQuest.Comercio
local Merc = WorldQuest.Mercenarios
local R = WorldQuest.Recursos
local Red = WorldQuest.Red
local Facciones = WorldQuest.Facciones
local MARGEN, ALTO_LINEA = Panel.MARGEN, Panel.ALTO_LINEA
local ALTO_FILA = 26
local X_MERC = 480

local COLOR_ACTITUD = {
    hostil = { 0.95, 0.35, 0.3 },
    neutral = { 0.75, 0.75, 0.75 },
    amigo = { 0.45, 0.85, 0.45 },
    contratado = { 0.4, 0.65, 1 },
}

local function miFaccion()
    local jugador = getPlayer()
    return jugador and Facciones.deJugador(jugador)
end

-- VENTANA: COMERCIAR CON MERCENARIOS ---------------------------------------------
local VentanaMerc = ISCollapsableWindow:derive("WorldQuestVentanaMercenarios")

function VentanaMerc:new(g)
    local ancho, alto = 460, 420
    local o = ISCollapsableWindow:new((getCore():getScreenWidth() - ancho) / 2, (getCore():getScreenHeight() - alto) / 2, ancho, alto)
    setmetatable(o, self)
    self.__index = self
    o.idGrupo = g.id
    o.title = getText("IGUI_WQ_Merc_TituloComercio", Merc.nombre(g))
    o.resizable = false
    o.botones = {}
    return o
end

function VentanaMerc:grupo()
    return Merc.porId(self.idGrupo)
end

function VentanaMerc:alBoton(boton)
    Red.pedir("comprarMercenario", { grupo = self.idGrupo, tipo = boton.tipo, cantidad = boton.cantidad })
end

function VentanaMerc:prerender()
    ISCollapsableWindow.prerender(self)
    local g = self:grupo()
    if not g then
        self:close()
        return
    end
    local partes = {}
    for tipo, n in pairs(g.inventario or {}) do
        table.insert(partes, tipo .. n)
    end
    table.sort(partes)
    local firma = table.concat(partes, ",")
    if firma == self.firma then
        return
    end
    self.firma = firma
    for _, b in ipairs(self.botones) do
        self:removeChild(b)
    end
    self.botones = {}
    self.filas = {}
    local tipos = {}
    for tipo, _ in pairs(g.inventario or {}) do
        table.insert(tipos, tipo)
    end
    table.sort(tipos)
    local y = 60
    for _, tipo in ipairs(tipos) do
        table.insert(self.filas, { tipo = tipo, y = y })
        for i, cantidad in ipairs({ 1, 5 }) do
            local b = ISButton:new(self.width - MARGEN - (3 - i) * 54, y, 50, 20, "x" .. cantidad, self, VentanaMerc.alBoton)
            b:initialise()
            b.tipo = tipo
            b.cantidad = cantidad
            self:addChild(b)
            table.insert(self.botones, b)
        end
        y = y + 24
        if y > self.height - 30 then
            break
        end
    end
end

function VentanaMerc:render()
    ISCollapsableWindow.render(self)
    local g = self:grupo()
    local f = miFaccion()
    if not g then
        return
    end
    local _, quiere = Merc.precio(g, 1, f)
    self:drawText(getText("IGUI_WQ_Merc_Quieren", R.nombre(quiere)), MARGEN, 30, 1, 0.85, 0.5, 1, UIFont.Small)
    for _, fila in ipairs(self.filas or {}) do
        local n = g.inventario[fila.tipo] or 0
        local precio = Merc.precio(g, Merc.valorItem(fila.tipo), f)
        self:drawText(Merc.nombreItem(fila.tipo) .. " x" .. n, MARGEN, fila.y + 2, 1, 1, 1, 1, UIFont.Small)
        self:drawText(getText("IGUI_WQ_Merc_PrecioUno", tostring(precio)), 260, fila.y + 2, 0.7, 0.7, 0.7, 1, UIFont.Small)
    end
end

function VentanaMerc:close()
    ISCollapsableWindow.close(self)
    self:removeFromUIManager()
end

function Merc.abrirComercio(g)
    local v = VentanaMerc:new(g)
    v:initialise()
    v:addToUIManager()
end

function Merc.contratar(g)
    local f = miFaccion()
    if not f then
        return
    end
    local motivo = Merc.motivoRechazo(g, f)
    if motivo then
        getPlayer():Say(getText(motivo, Merc.nombre(g)))
        return
    end
    local precio, quiere = Merc.costoContrato(g, f)
    WorldQuest.Dialogos.confirmar(getText("IGUI_WQ_Merc_ConfirmarContrato", Merc.nombre(g), R.texto({ [quiere] = precio }),
        tostring(Merc.MINUTOS_CONTRATO)), function(si)
        if si then
            Red.pedir("contratarMercenario", { grupo = g.id })
        end
    end)
end

-- PESTANA COMERCIO --------------------------------------------------------------------
local Vista = Panel.Vista:derive("WorldQuestVistaComercio")

local function combo(self, x, y, ancho)
    local c = ISComboBox:new(x, y, ancho, 22, self, nil)
    c:initialise()
    self:addChild(c)
    return c
end

local function llenarRecursos(c)
    for _, id in ipairs(C.RECURSOS) do
        c:addOptionWithData(R.nombre(id), id)
    end
end

local function entrada(self, x, y, texto)
    local e = ISTextEntryBox:new(texto, x, y, 70, 22)
    e:initialise()
    e:instantiate()
    e:setOnlyNumbers(true)
    self:addChild(e)
    return e
end

function Vista:createChildren()
    local y = MARGEN + ALTO_LINEA + 4
    self.comboFaccion = combo(self, MARGEN + 70, y, 220)
    y = y + 28
    self.comboDa = combo(self, MARGEN + 70, y, 140)
    llenarRecursos(self.comboDa)
    self.entradaDa = entrada(self, MARGEN + 220, y, "20")
    y = y + 28
    self.comboPide = combo(self, MARGEN + 70, y, 140)
    llenarRecursos(self.comboPide)
    self.comboPide.selected = 2
    self.entradaPide = entrada(self, MARGEN + 220, y, "20")
    self.botonEnviar = ISButton:new(MARGEN + 300, y, 140, 22, getText("IGUI_WQ_Com_Enviar"), self, Vista.alEnviar)
    self.botonEnviar:initialise()
    self.botonEnviar:setTooltip(getText("IGUI_WQ_Ayuda_Com_Enviar"))
    self:addChild(self.botonEnviar)
    self.yLista = y + 40
    self.botones = {}
    self.firmaFacciones = nil
end

function Vista:alEnviar()
    local faccion = self.comboFaccion:getSelectedData()
    local da, pide = tonumber(self.entradaDa:getText()), tonumber(self.entradaPide:getText())
    if not faccion or not da or not pide then
        return
    end
    Red.pedir("ofertaComercio", { faccion = faccion, daRecurso = self.comboDa:getSelectedData(), daCantidad = da,
        pideRecurso = self.comboPide:getSelectedData(), pideCantidad = pide })
end

function Vista:alBoton(boton)
    if boton.accion then
        boton.accion()
    end
end

function Vista:boton(x, y, ancho, texto, accion, tip)
    local b = ISButton:new(x, y, ancho, 20, texto, self, Vista.alBoton)
    b:initialise()
    b.accion = accion
    if tip then
        b:setTooltip(tip)
    end
    self:addChild(b)
    table.insert(self.botones, b)
    return b
end

local function firma(f)
    local partes = { tostring(f and f.id) }
    if f then
        for _, o in ipairs(C.getDatos().ofertas) do
            if o.de == f.id or o.para == f.id then
                table.insert(partes, "o" .. o.id)
            end
        end
        for _, g in ipairs(Merc.getDatos().grupos) do
            table.insert(partes, g.id .. Merc.actitud(g, f))
        end
    end
    return table.concat(partes, "|")
end

function Vista:rehacer(f)
    for _, b in ipairs(self.botones) do
        self:removeChild(b)
    end
    self.botones = {}
    self.filasRecibidas, self.filasMias, self.filasMerc = {}, {}, {}
    if not f then
        return
    end
    -- Ofertas recibidas y propias
    local y = self.yLista + ALTO_LINEA + 2
    for _, o in ipairs(C.ofertasPara(f.id)) do
        table.insert(self.filasRecibidas, { o = o, y = y })
        local id = o.id
        self:boton(X_MERC - 150, y, 64, getText("IGUI_WQ_Dipl_Aceptar"), function() Red.pedir("responderOferta", { id = id, acepta = true }) end)
        self:boton(X_MERC - 82, y, 64, getText("IGUI_WQ_Dipl_Rechazar"), function() Red.pedir("responderOferta", { id = id, acepta = false }) end)
        y = y + ALTO_FILA
    end
    self.yMias = y + ALTO_LINEA
    y = self.yMias + ALTO_LINEA + 2
    for _, o in ipairs(C.ofertasDe(f.id)) do
        table.insert(self.filasMias, { o = o, y = y })
        local id = o.id
        self:boton(X_MERC - 82, y, 64, getText("IGUI_WQ_Com_Cancelar"), function() Red.pedir("cancelarOferta", { id = id }) end)
        y = y + ALTO_FILA
    end
    -- Mercenarios
    y = MARGEN + ALTO_LINEA + 4
    for _, g in ipairs(Merc.getDatos().grupos) do
        table.insert(self.filasMerc, { g = g, y = y })
        local actitud = Merc.actitud(g, f)
        local grupo = g
        if actitud == "amigo" or actitud == "contratado" then
            self:boton(self.width - MARGEN - 200, y + ALTO_LINEA, 96, getText("IGUI_WQ_Merc_Comerciar"), function() Merc.abrirComercio(grupo) end,
                getText("IGUI_WQ_Ayuda_Merc_Comerciar"))
        end
        if actitud == "contratado" then
            self:boton(self.width - MARGEN - 100, y + ALTO_LINEA, 96, getText("IGUI_WQ_Merc_Extender"), function() Merc.contratar(grupo) end)
        elseif actitud ~= "hostil" then
            self:boton(self.width - MARGEN - 100, y + ALTO_LINEA, 96, getText("IGUI_WQ_Merc_Contratar"), function() Merc.contratar(grupo) end,
                getText("IGUI_WQ_Ayuda_Merc_Contratar"))
        end
        y = y + ALTO_FILA * 2
    end
end

function Vista:prerender()
    Panel.Vista.prerender(self)
    local f = miFaccion()
    -- Facciones con las que se puede comerciar
    local partes = {}
    for _, otra in ipairs(Facciones.getDatos().lista) do
        if f and C.puedenComerciar(f.id, otra.id) then
            table.insert(partes, otra.id .. otra.nombre)
        end
    end
    local ff = table.concat(partes, "|")
    if ff ~= self.firmaFacciones then
        self.firmaFacciones = ff
        self.comboFaccion:clear()
        for _, otra in ipairs(Facciones.getDatos().lista) do
            if f and C.puedenComerciar(f.id, otra.id) then
                self.comboFaccion:addOptionWithData(otra.nombre, otra.id)
            end
        end
    end
    self.botonEnviar:setEnable(f ~= nil and self.comboFaccion:getSelectedData() ~= nil)
    local fi = firma(f)
    if fi ~= self.firma then
        self.firma = fi
        self:rehacer(f)
    end
end

local function textoOferta(o, nombre)
    return getText("IGUI_WQ_Com_Fila", nombre, R.texto({ [o.daRecurso] = o.daCantidad }), R.texto({ [o.pideRecurso] = o.pideCantidad }))
end

function Vista:dibujar()
    local e = Panel.E()
    local f = miFaccion()
    if not f then
        self:texto(getText("IGUI_WQ_Panel_SinFaccion"), MARGEN, MARGEN, e.gris, nil, Panel.ayuda("SinFaccion"))
        return
    end
    -- Nueva oferta
    self:texto(getText("IGUI_WQ_Com_Nueva"), MARGEN, MARGEN, e.acento, nil, Panel.ayuda("Com_Nueva"))
    local y = MARGEN + ALTO_LINEA + 6
    self:texto(getText("IGUI_WQ_Com_Con"), MARGEN, y, e.gris)
    self:texto(getText("IGUI_WQ_Com_Doy"), MARGEN, y + 28, e.gris)
    self:texto(getText("IGUI_WQ_Com_Pido"), MARGEN, y + 56, e.gris)
    if self.comboFaccion:getSelectedData() == nil then
        self:texto(getText("IGUI_WQ_Com_SinSocios"), MARGEN + 300, y, e.gris)
    end

    -- Ofertas
    self:texto(getText("IGUI_WQ_Com_Recibidas"), MARGEN, self.yLista, e.acento)
    if #(self.filasRecibidas or {}) == 0 then
        self:texto(getText("IGUI_WQ_Dipl_SinPropuestas"), MARGEN + 8, self.yLista + ALTO_LINEA + 2, e.gris)
    end
    for _, fila in ipairs(self.filasRecibidas or {}) do
        local de = Facciones.porId(fila.o.de)
        self:texto(textoOferta(fila.o, de and de.nombre or "?"), MARGEN + 8, fila.y + 2, e.texto)
    end
    self:texto(getText("IGUI_WQ_Com_Mias"), MARGEN, self.yMias or self.yLista, e.acento)
    for _, fila in ipairs(self.filasMias or {}) do
        local para = Facciones.porId(fila.o.para)
        self:texto(textoOferta(fila.o, para and para.nombre or "?"), MARGEN + 8, fila.y + 2, e.gris)
    end

    -- Mercenarios
    self:drawRect(X_MERC - 10, MARGEN, 1, self.height - MARGEN * 2, 0.3, 1, 1, 1)
    self:texto(getText("IGUI_WQ_Merc_Titulo"), X_MERC, MARGEN, e.acento, nil, Panel.ayuda("Mercenarios"))
    if #(self.filasMerc or {}) == 0 then
        self:texto(getText("IGUI_WQ_Merc_Ninguno"), X_MERC, MARGEN + ALTO_LINEA + 4, e.gris)
    end
    for _, fila in ipairs(self.filasMerc or {}) do
        local g = fila.g
        local actitud = Merc.actitud(g, f)
        local c = COLOR_ACTITUD[actitud]
        self:texto(Merc.nombre(g), X_MERC, fila.y, c, nil, getText("IGUI_WQ_Ayuda_Merc_" .. g.personalidad))
        self:texto(getText("IGUI_WQ_Merc_Linea", getText("IGUI_WQ_Merc_" .. g.personalidad), tostring(g.fuerza),
            getText("IGUI_WQ_Merc_Actitud_" .. actitud), tostring(Merc.simpatia(g, f))), X_MERC + 150, fila.y, e.gris)
        if actitud == "contratado" then
            local t = WorldQuest.Territorios.buscarPorId(g.guarda)
            self:texto(getText("IGUI_WQ_Merc_Cuidan", t and t.nombre or "?", tostring(WorldQuest.Reloj.minutosHasta(g.contratoHasta or 0))),
                X_MERC + 8, fila.y + ALTO_LINEA + 2, c)
        elseif actitud ~= "hostil" then
            local precio, quiere = Merc.costoContrato(g, f)
            self:texto(getText("IGUI_WQ_Merc_Precio", R.texto({ [quiere] = precio })), X_MERC + 8, fila.y + ALTO_LINEA + 2, e.gris)
        end
    end
end

Panel.registrar(70, Vista, "IGUI_WQ_Tab_Comercio")

-- MAPA: mercenarios y opciones ------------------------------------------------------

local Mando = WorldQuest.MapaMando

Mando.agregarDibujo(function(mapa)
    local f = miFaccion()
    local api = mapa.mapAPI
    for _, g in ipairs(Merc.getDatos().grupos) do
        if not WorldQuest.Niebla or WorldQuest.Niebla.vePunto(f, g.x, g.y) then
            local actitud = Merc.actitud(g, f)
            local c = COLOR_ACTITUD[actitud]
            local sx, sy = api:worldToUIX(g.x, g.y), api:worldToUIY(g.x, g.y)
            mapa:drawRect(sx - 8, sy - 8, 16, 16, 0.9, 0.08, 0.08, 0.08)
            mapa:drawRectBorder(sx - 8, sy - 8, 16, 16, 1, c[1], c[2], c[3])
            mapa:drawTextCentre("M", sx, sy - 7, c[1], c[2], c[3], 1, UIFont.Small)
            mapa:drawText(g.nombre, sx + 11, sy - 7, c[1], c[2], c[3], 0.9, UIFont.Small)
        end
    end
end)

local RADIO_PIXELES = 14

local function grupoCerca(mapa, wx, wy)
    for _, g in ipairs(Merc.getDatos().grupos) do
        if Mando.distanciaPantalla(mapa, g.x, g.y, wx, wy) <= RADIO_PIXELES then
            return g
        end
    end
    return nil
end

local function caravanaCerca(mapa, wx, wy, f)
    for _, v in ipairs(WorldQuest.Economia.getExpediciones().lista) do
        if v.tipo == "caravana" and v.faccion ~= (f and f.id) then
            local x, y = WorldQuest.Economia.posicionViaje(v)
            if Mando.distanciaPantalla(mapa, x, y, wx, wy) <= RADIO_PIXELES then
                return v
            end
        end
    end
    return nil
end

table.insert(Mando.quiereMenu, function(wx, wy, t, mapa)
    return grupoCerca(mapa, wx, wy) ~= nil or caravanaCerca(mapa, wx, wy, miFaccion()) ~= nil
end)

Mando.agregarOpcion(function(context, wx, wy, t, n, mapa)
    local f = miFaccion()
    if not f then
        return
    end
    local g = grupoCerca(mapa, wx, wy)
    if g then
        local actitud = Merc.actitud(g, f)
        local titulo = context:addOption(getText("IGUI_WQ_Merc_MenuTitulo", Merc.nombre(g), getText("IGUI_WQ_Merc_Actitud_" .. actitud)), nil, nil)
        titulo.notAvailable = true
        if actitud == "amigo" or actitud == "contratado" then
            context:addOption(getText("IGUI_WQ_Merc_Comerciar"), g, Merc.abrirComercio)
        end
        if actitud ~= "hostil" then
            context:addOption(getText(actitud == "contratado" and "IGUI_WQ_Merc_Extender" or "IGUI_WQ_Merc_Contratar"), g, Merc.contratar)
        end
        if actitud == "contratado" then
            context:addOption(getText("IGUI_WQ_Merc_Despedir"), g, function(grupo) Red.pedir("despedirMercenario", { grupo = grupo.id }) end)
            if t and t.faccion == f.id then
                context:addOption(getText("IGUI_WQ_Merc_CuidarAqui", t.nombre), g, function(grupo)
                    Red.pedir("moverMercenario", { grupo = grupo.id, territorio = t.id })
                end)
            end
        end
    end
    local v = caravanaCerca(mapa, wx, wy, f)
    if v then
        local dueno = Facciones.porId(v.faccion)
        if n > 0 and C.puedeEmboscar(f, v) then
            local ids = Mando.idsSeleccion()
            local opcion = context:addOption(getText("IGUI_WQ_Com_Emboscar", dueno and dueno.nombre or "?"), v, function(caravana)
                Red.pedir("emboscar", { colonos = ids, caravana = caravana.id })
                Mando.limpiar()
            end)
            opcion.toolTip = Mando.tooltip(getText("IGUI_WQ_Ayuda_Emboscar"))
        else
            local titulo = context:addOption(getText("IGUI_WQ_Com_CaravanaDe", dueno and dueno.nombre or "?"), nil, nil)
            titulo.notAvailable = true
        end
    end
end)
