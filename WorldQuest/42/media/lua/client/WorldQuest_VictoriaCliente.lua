-- WorldQuest - Victoria (cliente): tabla de puntos siempre visible, pestana Objetivos
-- y resumen final con linea de tiempo.

require "WorldQuest_Panel"
require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISCollapsableWindow"

local V = WorldQuest.Victoria
local Panel = WorldQuest.Panel
local Red = WorldQuest.Red
local Facciones = WorldQuest.Facciones
local MARGEN, ALTO_LINEA = Panel.MARGEN, Panel.ALTO_LINEA
local FUENTE = UIFont.Small
local ALTO_FILA_TABLA = getTextManager():getFontHeight(FUENTE) + 2

local function miFaccion()
    local j = getPlayer()
    return j and Facciones.deJugador(j)
end

local function color(f)
    return Facciones.color(f.color) or { r = 1, g = 1, b = 1 }
end

-- Lineas: usa DrawLine del elemento; si no existe, puntos chicos
local function linea(el, x1, y1, x2, y2, r, g, b, a)
    local ok = pcall(function()
        el.javaObject:DrawLine(nil, x1 + el:getAbsoluteX(), y1 + el:getAbsoluteY(), x2 + el:getAbsoluteX(), y2 + el:getAbsoluteY(), 2, r, g, b, a)
    end)
    if not ok then
        local pasos = math.max(1, math.floor(math.max(math.abs(x2 - x1), math.abs(y2 - y1)) / 3))
        for i = 0, pasos do
            el:drawRect(x1 + (x2 - x1) * i / pasos - 1, y1 + (y2 - y1) * i / pasos - 1, 2, 2, a, r, g, b)
        end
    end
end

-- Texto de las cuentas regresivas y la evacuacion de una faccion
local function estadoCorto(f)
    local partes = {}
    for _, via in ipairs(V.VIAS) do
        local falta = V.cuenta(f, via)
        if falta then
            table.insert(partes, getText("IGUI_WQ_Vic_CuentaCorta", getText("IGUI_WQ_Vic_Via_" .. via), tostring(falta)))
        end
    end
    local e = V.exodo(f)
    if e and (e.avance or 0) < 100 then
        table.insert(partes, getText("IGUI_WQ_Vic_EvacCorta", tostring(math.floor(e.avance or 0))))
    end
    return table.concat(partes, " ")
end

-- TABLA SIEMPRE VISIBLE ---------------------------------------------------------------
local Tabla = ISPanel:derive("WorldQuestTabla")

function Tabla:new()
    local ancho = 300
    local o = ISPanel:new(getCore():getScreenWidth() - ancho - 70, 12, ancho, 40)
    setmetatable(o, self)
    self.__index = self
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.55 }
    o.borderColor = { r = 1, g = 1, b = 1, a = 0.15 }
    o.plegada = false
    o.moveWithMouse = true
    return o
end

function Tabla:onMouseUp(x, y)
    if y < ALTO_FILA_TABLA + 6 and not self.moviendo then
        self.plegada = not self.plegada
    end
    return ISPanel.onMouseUp(self, x, y)
end

function Tabla:prerender()
    local lista = V.tabla()
    local filas = self.plegada and 0 or #lista
    self:setHeight(ALTO_FILA_TABLA + 10 + filas * ALTO_FILA_TABLA + ((not self.plegada and V.terminada()) and ALTO_FILA_TABLA or 0))
    ISPanel.prerender(self)
end

function Tabla:render()
    local d = V.getDatos()
    local titulo = getText("IGUI_WQ_Vic_TablaTitulo", V.reloj(d.minutos), V.reloj(V.limiteMinutos()))
    local r, g, b = 1, 0.85, 0.5
    if d.presion then
        r, g, b = 1, 0.45, 0.35
    end
    self:drawText((self.plegada and "+ " or "- ") .. titulo, 6, 4, r, g, b, 1, FUENTE)
    if self.plegada then
        return
    end
    local mia = miFaccion()
    local y = ALTO_FILA_TABLA + 8
    for i, f in ipairs(V.tabla()) do
        local c = color(f)
        local observador = WorldQuest.Conflicto and WorldQuest.Conflicto.esObservador(f)
        local alfa = observador and 0.45 or 1
        self:drawRect(6, y + 3, 9, 9, alfa, c.r, c.g, c.b)
        local nombre = i .. ". " .. f.nombre
        if mia and mia.id == f.id then
            nombre = nombre .. " *"
        end
        if f.proteccion then
            nombre = nombre .. " " .. getText("IGUI_WQ_Vic_Pausa")
        end
        self:drawText(nombre, 20, y, 1, 1, 1, alfa, FUENTE)
        self:drawTextRight(tostring(f.puntos or 0), self.width - 8, y, 1, 0.85, 0.5, alfa, FUENTE)
        local estado = estadoCorto(f)
        if estado ~= "" then
            self:drawTextRight(estado, self.width - 50, y, 1, 0.45, 0.35, 1, FUENTE)
        end
        y = y + ALTO_FILA_TABLA
    end
    if V.terminada() then
        local ganador = d.ganador.faccion and Facciones.porId(d.ganador.faccion)
        self:drawText(getText("IGUI_WQ_Vic_Fin", ganador and ganador.nombre or getText("IGUI_WQ_Vic_Nadie")), 6, y, 0.5, 0.9, 0.5, 1, FUENTE)
    end
end

local tabla = nil
local function mostrarTabla()
    if isServer() or tabla then
        return
    end
    if not getPlayer() then
        return
    end
    tabla = Tabla:new()
    tabla:initialise()
    tabla:addToUIManager()
end

-- RESUMEN FINAL ------------------------------------------------------------------------
local Resumen = ISCollapsableWindow:derive("WorldQuestResumen")

function Resumen:new()
    local ancho, alto = 760, 520
    local o = ISCollapsableWindow:new((getCore():getScreenWidth() - ancho) / 2, (getCore():getScreenHeight() - alto) / 2, ancho, alto)
    setmetatable(o, self)
    self.__index = self
    o.title = getText("IGUI_WQ_Vic_TituloResumen")
    o.resizable = false
    return o
end

function Resumen:render()
    ISCollapsableWindow.render(self)
    local d = V.getDatos()
    local y = 30
    if d.ganador then
        local ganador = d.ganador.faccion and Facciones.porId(d.ganador.faccion)
        local texto = ganador and getText("IGUI_WQ_Vic_Gano", ganador.nombre, getText("IGUI_WQ_Vic_Via_" .. d.ganador.via))
            or getText("IGUI_WQ_Vic_NadieGano", getText("IGUI_WQ_Vic_Via_" .. d.ganador.via))
        self:drawText(texto, MARGEN, y, 1, 0.85, 0.5, 1, UIFont.Medium)
        y = y + 26
    end
    -- Tabla por faccion
    local columnas = { 0, 200, 290, 380, 470, 560 }
    local titulos = { "IGUI_WQ_Vic_ColFaccion", "IGUI_WQ_Vic_ColPuntos", "IGUI_WQ_Vic_ColTerritorios",
        "IGUI_WQ_Vic_ColColonos", "IGUI_WQ_Vic_ColRiqueza", "IGUI_WQ_Vic_ColBatallas" }
    for i, clave in ipairs(titulos) do
        self:drawText(getText(clave), MARGEN + columnas[i], y, 0.7, 0.7, 0.7, 1, FUENTE)
    end
    y = y + ALTO_LINEA
    for _, f in ipairs(V.tabla()) do
        local c = color(f)
        self:drawRect(MARGEN, y + 3, 9, 9, 1, c.r, c.g, c.b)
        local valores = { f.nombre, f.puntos or 0, #V.territoriosDe(f), V.colonosDe(f), math.floor(f.riqueza or 0), f.batallasGanadas or 0 }
        for i, valor in ipairs(valores) do
            self:drawText(tostring(valor), MARGEN + columnas[i] + (i == 1 and 14 or 0), y, 1, 1, 1, 1, FUENTE)
        end
        y = y + ALTO_LINEA
    end
    -- Linea de tiempo de los puntos
    y = y + 10
    self:drawText(getText("IGUI_WQ_Vic_LineaTiempo"), MARGEN, y, 1, 0.85, 0.5, 1, FUENTE)
    y = y + ALTO_LINEA
    local x0, y0, ancho, alto = MARGEN + 30, y, self.width - MARGEN * 2 - 40, self.height - y - 50
    self:drawRectBorder(x0, y0, ancho, alto, 0.4, 1, 1, 1)
    local historia = d.historia or {}
    local maxM, maxP = 1, 1
    for _, h in ipairs(historia) do
        maxM = math.max(maxM, h.m)
        for _, v in pairs(h.f) do
            maxP = math.max(maxP, v.p or 0)
        end
    end
    self:drawText(tostring(maxP), MARGEN, y0, 0.6, 0.6, 0.6, 1, FUENTE)
    self:drawText(V.reloj(maxM), x0 + ancho - 30, y0 + alto + 2, 0.6, 0.6, 0.6, 1, FUENTE)
    for _, f in ipairs(Facciones.getDatos().lista) do
        local c = color(f)
        local anterior = nil
        for _, h in ipairs(historia) do
            local v = h.f[tostring(f.id)]
            if v then
                local px = x0 + h.m / maxM * ancho
                local py = y0 + alto - (v.p or 0) / maxP * alto
                if anterior then
                    linea(self, anterior[1], anterior[2], px, py, c.r, c.g, c.b, 1)
                end
                anterior = { px, py }
            end
        end
    end
    -- Batallas y eliminaciones como marcas abajo
    for _, b in ipairs(d.batallas or {}) do
        local f = Facciones.porId(b.g)
        local c = f and color(f) or { r = 1, g = 1, b = 1 }
        self:drawRect(x0 + b.m / maxM * ancho - 1, y0 + alto - 6, 3, 6, 1, c.r, c.g, c.b)
    end
    for _, e in ipairs(d.eliminadas or {}) do
        self:drawRect(x0 + e.m / maxM * ancho - 1, y0, 2, alto, 0.6, 1, 0.3, 0.3)
    end
    self:drawText(getText("IGUI_WQ_Vic_Leyenda"), MARGEN, self.height - 22, 0.6, 0.6, 0.6, 1, FUENTE)
end

function Resumen:close()
    ISCollapsableWindow.close(self)
    self:removeFromUIManager()
    V.ventanaResumen = nil
end

function V.abrirResumen()
    if V.ventanaResumen then
        return
    end
    local w = Resumen:new()
    w:initialise()
    w:addToUIManager()
    V.ventanaResumen = w
end

Red.mensaje("finPartida", function(args)
    V.abrirResumen()
end)

-- PESTANA OBJETIVOS -------------------------------------------------------------------
local Vista = Panel.Vista:derive("WorldQuestVistaObjetivos")

function Vista:createChildren()
    self.botonExodo = ISButton:new(self.width - MARGEN - 200, 0, 200, 24, getText("IGUI_WQ_Vic_IniciarExodo"), self, Vista.alExodo)
    self.botonExodo:initialise()
    self.botonExodo:setTooltip(getText("IGUI_WQ_Ayuda_Vic_IniciarExodo"))
    self:addChild(self.botonExodo)
    self.botonResumen = ISButton:new(self.width - MARGEN - 200, MARGEN, 200, 24, getText("IGUI_WQ_Vic_VerResumen"), self, Vista.alResumen)
    self.botonResumen:initialise()
    self:addChild(self.botonResumen)
end

function Vista:alExodo()
    Red.pedir("iniciarExodo", {})
end

function Vista:alResumen()
    V.abrirResumen()
end

function Vista:dibujar()
    local e = Panel.E()
    local d = V.getDatos()
    local f = miFaccion()
    local y = MARGEN
    self.botonResumen:setVisible(V.terminada() or #(d.historia or {}) > 0)
    self:texto(getText("IGUI_WQ_Vic_Tiempo", V.reloj(d.minutos), V.reloj(V.limiteMinutos())), MARGEN, y,
        d.presion and e.alerta or e.acento, Panel.FUENTE_TITULO, Panel.ayuda("Vic_Tiempo"))
    y = y + ALTO_LINEA * 2
    if not f then
        self:texto(getText("IGUI_WQ_Panel_SinFaccion"), MARGEN, y, e.gris)
        self.botonExodo:setVisible(false)
        return
    end
    self:texto(getText("IGUI_WQ_Vic_TusPuntos", tostring(f.puntos or 0)), MARGEN, y, nil, nil, Panel.ayuda("Vic_Puntos"))
    y = y + ALTO_LINEA * 2

    -- Exodo
    self:texto(getText("IGUI_WQ_Vic_Via_exodo"), MARGEN, y, e.acento, nil, Panel.ayuda("Vic_exodo"))
    y = y + ALTO_LINEA
    local ex = V.exodo(f)
    local puedeIniciar = not ex and not V.terminada() and f.lider == getPlayer():getUsername()
    for _, r in ipairs(V.requisitosExodo(f)) do
        local texto = (r.ok and "[x] " or "[ ] ") .. getText("IGUI_WQ_Vic_Req_" .. r.id)
        if r.id == "recursos" then
            texto = texto .. ": " .. WorldQuest.Recursos.texto(V.EXODO_COSTO)
        elseif r.id == "colonos" then
            texto = texto .. ": " .. V.colonosDe(f) .. "/" .. V.EXODO_COLONOS
        end
        self:texto(texto, MARGEN + 8, y, r.ok and e.bien or e.gris, nil, Panel.ayuda("Vic_Req_" .. r.id))
        puedeIniciar = puedeIniciar and r.ok
        y = y + ALTO_LINEA
    end
    if ex then
        self:texto(getText("IGUI_WQ_Vic_Evacuacion", tostring(math.floor(ex.avance or 0))), MARGEN + 8, y, e.acento)
        self:barra(MARGEN + 200, y + 3, 300, ex.avance or 0, 100, 0.85, 0.6, 0.15)
        y = y + ALTO_LINEA
    end
    self.botonExodo:setY(y - ALTO_LINEA * 3)
    self.botonExodo:setVisible(not ex)
    self.botonExodo:setEnable(puedeIniciar)
    y = y + 8

    -- Dominacion
    local necesarios, total = V.lugaresParaDominar()
    local propios = WorldQuest.Mundo and #WorldQuest.Mundo.deFaccion(f) or 0
    self:texto(getText("IGUI_WQ_Vic_Via_dominacion"), MARGEN, y, e.acento, nil, Panel.ayuda("Vic_dominacion"))
    y = y + ALTO_LINEA
    self:texto(getText("IGUI_WQ_Vic_Lugares", tostring(propios), tostring(necesarios), tostring(total)), MARGEN + 8, y)
    self:barra(MARGEN + 320, y + 3, 180, propios, necesarios, 0.35, 0.55, 0.85)
    y = y + ALTO_LINEA + 8

    -- Economia
    self:texto(getText("IGUI_WQ_Vic_Via_economia"), MARGEN, y, e.acento, nil, Panel.ayuda("Vic_economia"))
    y = y + ALTO_LINEA
    self:texto(getText("IGUI_WQ_Vic_Riqueza", WorldQuest.Recursos.corto(f.riqueza or 0), WorldQuest.Recursos.corto(V.metaRiqueza())), MARGEN + 8, y)
    self:barra(MARGEN + 320, y + 3, 180, f.riqueza or 0, V.metaRiqueza(), 0.3, 0.75, 0.35)
    y = y + ALTO_LINEA * 2

    -- Cuentas regresivas de todos
    self:texto(getText("IGUI_WQ_Vic_Cuentas"), MARGEN, y, e.acento, nil, Panel.ayuda("Vic_Cuentas"))
    y = y + ALTO_LINEA
    local hay = false
    for _, otra in ipairs(Facciones.getDatos().lista) do
        for _, via in ipairs(V.VIAS) do
            local falta = V.cuenta(otra, via)
            if falta then
                hay = true
                self:texto(getText("IGUI_WQ_Vic_CuentaLinea", otra.nombre, getText("IGUI_WQ_Vic_Via_" .. via), tostring(falta)),
                    MARGEN + 8, y, otra.id == f.id and e.bien or e.alerta)
                y = y + ALTO_LINEA
            end
        end
    end
    if not hay then
        self:texto(getText("IGUI_WQ_Vic_SinCuentas"), MARGEN + 8, y, e.gris)
    end
end

Panel.registrar(90, Vista, "IGUI_WQ_Tab_Objetivos")

Events.OnPlayerUpdate.Add(mostrarTabla)
