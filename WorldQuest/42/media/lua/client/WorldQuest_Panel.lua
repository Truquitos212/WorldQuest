-- WorldQuest - Panel de la colonia (cliente)

require "ISUI/ISCollapsableWindow"
require "ISUI/ISTabPanel"
require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISComboBox"

WorldQuest = WorldQuest or {}
WorldQuest.Panel = WorldQuest.Panel or {}

local Panel = WorldQuest.Panel

local ANCHO, ALTO = 560, 460
local MARGEN = 12
local FUENTE = UIFont.Small
local FUENTE_TITULO = UIFont.Medium
local ALTO_LINEA = getTextManager():getFontHeight(UIFont.Small) + 4
local REFRESCO_MS = 1000
local ROLES = { "ninguno", "agricultor", "explorador", "constructor", "guardia", "medico" }

-- Posiciones de la pestana Colonos
local ANCHO_LISTA = 220
local ALTO_FILA = ALTO_LINEA * 2 + 6
local X_FICHA = ANCHO_LISTA + MARGEN * 2
local Y_ROL = MARGEN + 28
local Y_COMBO = Y_ROL + ALTO_LINEA
local Y_ANIMO = Y_COMBO + 32
local Y_HAMBRE = Y_ANIMO + ALTO_LINEA
local Y_HABILIDADES = Y_HAMBRE + ALTO_LINEA + 8

local BLANCO = { 1, 1, 1 }
local GRIS = { 0.7, 0.7, 0.7 }
local DORADO = { 1, 0.85, 0.5 }
local ROJO = { 1, 0.5, 0.4 }
local VERDE = { 0.5, 0.9, 0.5 }

-- Territorio a mostrar: el mas cercano al jugador
function Panel.territorioActual()
    local jugador = getPlayer()
    local lista = WorldQuest.Territorios.getDatos().lista
    if not jugador or #lista == 0 then
        return nil
    end
    local mejor, mejorDistancia = nil, nil
    for _, t in ipairs(lista) do
        local dx = t.x - jugador:getX()
        local dy = t.y - jugador:getY()
        local distancia = dx * dx + dy * dy
        if not mejorDistancia or distancia < mejorDistancia then
            mejor, mejorDistancia = t, distancia
        end
    end
    return mejor
end

-- VISTA BASE: panel transparente con ayudas para texto y barras --------
local Vista = ISPanel:derive("WorldQuestVista")

function Vista:new(x, y, ancho, alto, ventana)
    local o = ISPanel:new(x, y, ancho, alto)
    setmetatable(o, self)
    self.__index = self
    o.ventana = ventana
    o.background = false
    o.border = false
    return o
end

function Vista:texto(str, x, y, color, fuente)
    color = color or BLANCO
    self:drawText(str, x, y, color[1], color[2], color[3], 1, fuente or FUENTE)
end

function Vista:barra(x, y, ancho, valor, maximo, r, g, b)
    local fraccion = math.max(0, math.min(1, valor / maximo))
    self:drawRect(x, y, ancho, 10, 0.6, 0.15, 0.15, 0.15)
    self:drawRect(x, y, math.floor(ancho * fraccion), 10, 0.9, r, g, b)
    self:drawRectBorder(x, y, ancho, 10, 0.4, 1, 1, 1)
end

-- PESTANA RESUMEN ------------------------------------------------------
local VistaResumen = Vista:derive("WorldQuestVistaResumen")

function VistaResumen:createChildren()
    self.botonMejorar = ISButton:new(MARGEN, 0, 140, 24, getText("IGUI_WQ_Panel_Mejorar"), self, VistaResumen.alMejorar)
    self.botonMejorar:initialise()
    self:addChild(self.botonMejorar)
end

function VistaResumen:alMejorar()
    local t = self.ventana.territorio
    local Niveles = WorldQuest.Niveles
    if t and Niveles.mejorar(t) then
        local texto = getText("IGUI_WQ_NivelSubido", t.nombre, Niveles.nombre(Niveles.datos(t)))
        if WorldQuest.Banner then
            WorldQuest.Banner.mostrar(texto, "aviso")
        end
        print("[WorldQuest] " .. texto)
        self.ventana:refrescar(true)
    end
end

function VistaResumen:render()
    local v = self.ventana
    local t = v.territorio
    if not t then
        self:texto(getText("IGUI_WQ_Panel_SinTerritorio"), MARGEN, MARGEN, GRIS)
        self.botonMejorar:setVisible(false)
        return
    end

    local Niveles = WorldQuest.Niveles
    local r = v.recursos
    local e = t.estructuras or { camas = 0, huertos = 0, cocinas = 0, generadores = 0 }
    local y = MARGEN

    self:texto(getText("IGUI_WQ_Panel_Nivel", Niveles.nombre(Niveles.datos(t))), MARGEN, y, DORADO, FUENTE_TITULO)
    y = y + ALTO_LINEA * 2
    self:texto(getText("IGUI_WQ_Panel_Colonos", tostring(#v.colonos), tostring(v.cupo)), MARGEN, y)
    y = y + ALTO_LINEA
    self:texto(getText("IGUI_WQ_Panel_Comida", tostring(r.comidas), tostring(r.calorias)), MARGEN, y)
    y = y + ALTO_LINEA
    self:texto(getText("IGUI_WQ_Panel_Materiales", tostring(r.tablas), tostring(r.clavos), tostring(r.troncos)), MARGEN, y)
    y = y + ALTO_LINEA
    self:texto(getText("IGUI_WQ_Panel_Estructuras", tostring(e.camas), tostring(e.huertos), tostring(e.cocinas), tostring(e.generadores)), MARGEN, y)
    y = y + ALTO_LINEA * 2

    local siguiente = Niveles.siguiente(t)
    if not siguiente then
        self:texto(getText("IGUI_WQ_NivelMaximo"), MARGEN, y, VERDE)
        self.botonMejorar:setVisible(false)
        return
    end

    self:texto(getText("IGUI_WQ_Panel_Siguiente", Niveles.nombre(siguiente)), MARGEN, y, DORADO)
    y = y + ALTO_LINEA
    self:texto(getText("IGUI_WQ_Panel_Costo", Niveles.textoCosto(siguiente.costo, siguiente.colonos)), MARGEN, y)
    y = y + ALTO_LINEA
    if not v.puedeMejorar and v.motivoMejorar then
        self:texto(v.motivoMejorar, MARGEN, y, ROJO)
        y = y + ALTO_LINEA
    end
    self.botonMejorar:setY(y + 4)
    self.botonMejorar:setVisible(true)
    self.botonMejorar:setEnable(v.puedeMejorar == true)
end

-- PESTANA COLONOS: lista a la izquierda, ficha a la derecha -------------
local VistaColonos = Vista:derive("WorldQuestVistaColonos")

function VistaColonos:createChildren()
    self.comboRol = ISComboBox:new(X_FICHA, Y_COMBO, 170, 22, self, VistaColonos.alCambiarRol)
    self.comboRol:initialise()
    for _, rol in ipairs(ROLES) do
        self.comboRol:addOptionWithData(getText("IGUI_WQ_Rol_" .. rol), rol)
    end
    self:addChild(self.comboRol)
    self.comboRol:setVisible(false)
end

function VistaColonos:seleccionado()
    for _, colono in ipairs(self.ventana.colonos) do
        if colono.id == self.idSeleccionado then
            return colono
        end
    end
    return nil
end

function VistaColonos:alCambiarRol(combo)
    local colono = self:seleccionado()
    if colono then
        colono.rol = combo:getSelectedData()
        print("[WorldQuest] " .. colono.nombre .. " ahora es " .. colono.rol)
    end
end

function VistaColonos:onMouseDown(x, y)
    if x < ANCHO_LISTA + MARGEN then
        local i = math.floor((y - MARGEN) / ALTO_FILA) + 1
        local colono = self.ventana.colonos[i]
        if colono then
            self.idSeleccionado = colono.id
            self.comboRol:selectData(colono.rol)
        end
    end
    return true
end

function VistaColonos:render()
    local colonos = self.ventana.colonos
    if not self.ventana.territorio or #colonos == 0 then
        self:texto(getText("IGUI_WQ_Panel_SinColonos"), MARGEN, MARGEN, GRIS)
        self.comboRol:setVisible(false)
        return
    end

    -- Lista
    for i, colono in ipairs(colonos) do
        local y = MARGEN + (i - 1) * ALTO_FILA
        if colono.id == self.idSeleccionado then
            self:drawRect(MARGEN - 4, y - 2, ANCHO_LISTA, ALTO_FILA - 2, 0.3, 0.3, 0.5, 0.7)
        end
        self:texto(colono.nombre, MARGEN, y)
        local dias = WorldQuest.Colonos.minutosSinComer(colono)
        if dias > 0 then
            self:texto(getText("IGUI_WQ_Panel_HambreMin", tostring(dias)), MARGEN, y + ALTO_LINEA, ROJO)
        else
            self:texto(getText("IGUI_WQ_Rol_" .. colono.rol), MARGEN, y + ALTO_LINEA, GRIS)
        end
        self:barra(MARGEN + 120, y + ALTO_LINEA + 3, 80, colono.animo, 100, 0.3, 0.75, 0.35)
    end
    self:drawRect(ANCHO_LISTA + MARGEN, MARGEN, 1, self.height - MARGEN * 2, 0.3, 1, 1, 1)

    -- Ficha
    local colono = self:seleccionado()
    if not colono then
        self:texto(getText("IGUI_WQ_Panel_Selecciona"), X_FICHA, MARGEN, GRIS)
        self.comboRol:setVisible(false)
        return
    end
    self.comboRol:setVisible(true)

    self:texto(colono.nombre, X_FICHA, MARGEN, DORADO, FUENTE_TITULO)
    self:texto(getText("IGUI_WQ_Panel_Rol"), X_FICHA, Y_ROL, GRIS)
    self:texto(getText("IGUI_WQ_Panel_Animo"), X_FICHA, Y_ANIMO, GRIS)
    self:barra(X_FICHA + 70, Y_ANIMO + 3, 150, colono.animo, 100, 0.3, 0.75, 0.35)
    self:texto(tostring(colono.animo), X_FICHA + 228, Y_ANIMO)

    local dias = WorldQuest.Colonos.minutosSinComer(colono)
    if dias > 0 then
        self:texto(getText("IGUI_WQ_Panel_HambreMin", tostring(dias)), X_FICHA, Y_HAMBRE, ROJO)
    end

    self:texto(getText("IGUI_WQ_Panel_Habilidades"), X_FICHA, Y_HABILIDADES, GRIS)
    for i, id in ipairs(WorldQuest.Colonos.HABILIDADES) do
        local y = Y_HABILIDADES + i * (ALTO_LINEA + 2)
        local valor = colono.habilidades[id] or 0
        local color = BLANCO
        if id == colono.especialidad then
            color = DORADO
        end
        self:texto(getText("IGUI_WQ_Hab_" .. id), X_FICHA, y, color)
        self:barra(X_FICHA + 110, y + 3, 110, valor, 10, 0.35, 0.55, 0.85)
        self:texto(tostring(valor), X_FICHA + 228, y)
    end
end

-- PESTANA CONSTRUCCION -------------------------------------------------
local VistaConstruccion = Vista:derive("WorldQuestVistaConstruccion")

function VistaConstruccion:createChildren()
    self.botones = {}
    for i, proyecto in ipairs(WorldQuest.Proyectos.LISTA) do
        local boton = ISButton:new(self.width - 120 - MARGEN, 0, 120, 22, getText("IGUI_WQ_Panel_Construir"), self, VistaConstruccion.alConstruir)
        boton:initialise()
        boton.proyecto = proyecto
        self:addChild(boton)
        self.botones[i] = boton
    end
end

function VistaConstruccion:alConstruir(boton)
    local t = self.ventana.territorio
    local Proyectos = WorldQuest.Proyectos
    if t and Proyectos.iniciar(t, boton.proyecto) then
        local texto = getText("IGUI_WQ_ProyectoIniciado", Proyectos.nombre(boton.proyecto.id), t.nombre)
        if WorldQuest.Banner then
            WorldQuest.Banner.mostrar(texto, "aviso")
        end
        print("[WorldQuest] " .. texto)
        self.ventana:refrescar(true)
    end
end

function VistaConstruccion:render()
    local v = self.ventana
    local t = v.territorio
    local Proyectos = WorldQuest.Proyectos
    if not t then
        self:texto(getText("IGUI_WQ_Panel_SinTerritorio"), MARGEN, MARGEN, GRIS)
        for _, boton in ipairs(self.botones) do
            boton:setVisible(false)
        end
        return
    end

    local y = MARGEN
    if t.proyecto then
        local definicion = Proyectos.buscar(t.proyecto.id)
        local porCiclo = Proyectos.trabajoDiario(t)
        local estado = getText("IGUI_WQ_Panel_ObraDetenida", Proyectos.nombre(t.proyecto.id))
        if porCiclo > 0 then
            local minutos = math.ceil(t.proyecto.restante / porCiclo) * WorldQuest.Reloj.minutosCiclo()
            estado = getText("IGUI_WQ_Panel_ObraMin", Proyectos.nombre(t.proyecto.id), tostring(minutos))
        end
        self:texto(estado, MARGEN, y, DORADO)
        y = y + ALTO_LINEA
        if definicion then
            self:barra(MARGEN, y + 2, self.width - MARGEN * 2, definicion.trabajo - t.proyecto.restante, definicion.trabajo, 0.85, 0.6, 0.15)
        end
        y = y + ALTO_LINEA + 8
    end

    for i, proyecto in ipairs(Proyectos.LISTA) do
        local boton = self.botones[i]
        boton:setY(y + 2)
        if Proyectos.construido(t, proyecto.id) then
            boton:setVisible(false)
            self:texto(Proyectos.nombre(proyecto.id), MARGEN, y, VERDE)
            self:texto(getText("IGUI_WQ_Panel_Construido"), MARGEN, y + ALTO_LINEA, VERDE)
        else
            local estado = v.puedeProyecto[proyecto.id] or {}
            boton:setVisible(true)
            boton:setEnable(estado.ok == true)
            self:texto(getText("IGUI_WQ_Panel_Proyecto", Proyectos.nombre(proyecto.id),
                WorldQuest.Niveles.textoCosto(proyecto.costo), tostring(proyecto.trabajo * WorldQuest.Reloj.minutosCiclo())), MARGEN, y)
            if not estado.ok and estado.motivo then
                self:texto(estado.motivo, MARGEN, y + ALTO_LINEA, ROJO)
            end
        end
        y = y + ALTO_LINEA * 2 + 10
    end
end

-- PESTANA CRISIS -------------------------------------------------------
local VistaCrisis = Vista:derive("WorldQuestVistaCrisis")

function VistaCrisis:render()
    local Crisis = WorldQuest.Crisis
    if not Crisis then
        return
    end
    local datos = Crisis.getDatos()
    local factor = 1
    if WorldQuest.Modificadores then
        factor = WorldQuest.Modificadores.factorNarrador() * WorldQuest.Opciones.frecuenciaCrisis()
    end
    local probabilidad = math.floor(math.min(datos.tension * 10 * factor, 80))

    local y = MARGEN
    self:texto(getText("IGUI_WQ_Panel_Tirada", tostring(datos.tension), tostring(probabilidad), tostring(Crisis.CICLOS_NARRADOR * WorldQuest.Reloj.minutosCiclo())), MARGEN, y, DORADO)
    y = y + ALTO_LINEA * 2

    local ahora = getGameTime():getWorldAgeHours()
    local hayAlgo = false
    for _, pendiente in ipairs(datos.pendientes) do
        local ficha = Crisis.tipos[pendiente.tipo]
        if ficha and ficha.textoAviso then
            local nombre = getText("IGUI_WQ_Crisis_" .. pendiente.tipo)
            local horas = WorldQuest.Reloj.minutosHasta(pendiente.hora)
            local linea
            if horas > 0 then
                linea = getText("IGUI_WQ_PendienteMin", nombre, tostring(horas))
            else
                linea = getText("IGUI_WQ_MapaEsperando", nombre)
            end
            local territorio = WorldQuest.Territorios.buscarPorId(pendiente.territorio)
            if territorio then
                linea = territorio.nombre .. ": " .. linea
            end
            self:texto(linea, MARGEN, y, ROJO)
            y = y + ALTO_LINEA
            hayAlgo = true
        end
    end

    if datos.frio then
        self:texto(getText("IGUI_WQ_Panel_Frio"), MARGEN, y, { 0.6, 0.8, 1 })
        y = y + ALTO_LINEA
        hayAlgo = true
    end

    if not hayAlgo then
        self:texto(getText("IGUI_WQ_Panel_SinCrisis"), MARGEN, y, GRIS)
    end
end

-- VENTANA ---------------------------------------------------------------
local Ventana = ISCollapsableWindow:derive("WorldQuestPanelColonia")

function Ventana:new(x, y)
    local o = ISCollapsableWindow:new(x, y, ANCHO, ALTO)
    setmetatable(o, self)
    self.__index = self
    o.title = getText("IGUI_WQ_Panel_Boton")
    o.resizable = false
    o.ultimoRefresco = 0
    o.colonos = {}
    o.cupo = 0
    o.recursos = { comidas = 0, calorias = 0, tablas = 0, clavos = 0, troncos = 0 }
    o.puedeProyecto = {}
    return o
end

function Ventana:createChildren()
    ISCollapsableWindow.createChildren(self)
    local alturaTitulo = 16
    if self.titleBarHeight then
        alturaTitulo = self:titleBarHeight()
    end

    self.pestanas = ISTabPanel:new(0, alturaTitulo, self.width, self.height - alturaTitulo)
    self.pestanas:initialise()
    self:addChild(self.pestanas)

    local altoVista = self.pestanas.height - (self.pestanas.tabHeight or 24)
    local function agregar(clase, clave)
        local vista = clase:new(0, 0, self.width, altoVista, self)
        vista:initialise()
        self.pestanas:addView(getText(clave), vista)
    end
    agregar(VistaResumen, "IGUI_WQ_Tab_Resumen")
    agregar(VistaColonos, "IGUI_WQ_Tab_Colonos")
    agregar(VistaConstruccion, "IGUI_WQ_Tab_Construccion")
    agregar(VistaCrisis, "IGUI_WQ_Tab_Crisis")
end

-- Recalcula los datos como mucho una vez por segundo (contar el almacen cuesta)
function Ventana:refrescar(forzar)
    local ahora = getTimestampMs()
    if not forzar and ahora - self.ultimoRefresco < REFRESCO_MS then
        return
    end
    self.ultimoRefresco = ahora

    local t = Panel.territorioActual()
    self.territorio = t
    if not t then
        self.colonos = {}
        return
    end

    self.title = getText("IGUI_WQ_Panel_Titulo", WorldQuest.Niveles.titulo(t))
    self.recursos = WorldQuest.Almacen.contar(t)
    self.colonos = WorldQuest.Colonos.delTerritorio(t)
    self.cupo = WorldQuest.Colonos.cupo(t)
    self.puedeMejorar, self.motivoMejorar = WorldQuest.Niveles.puedeMejorar(t)
    self.puedeProyecto = {}
    for _, proyecto in ipairs(WorldQuest.Proyectos.LISTA) do
        local ok, motivo = WorldQuest.Proyectos.puedeIniciar(t, proyecto)
        self.puedeProyecto[proyecto.id] = { ok = ok, motivo = motivo }
    end
end

function Ventana:prerender()
    self:refrescar(false)
    ISCollapsableWindow.prerender(self)
end

function Ventana:close()
    ISCollapsableWindow.close(self)
    self:removeFromUIManager()
    Panel.instancia = nil
end

-- Abre o cierra el panel
function Panel.alternar()
    if Panel.instancia then
        Panel.instancia:close()
        return
    end
    local ventana = Ventana:new(120, 120)
    ventana:initialise()
    ventana:addToUIManager()
    Panel.instancia = ventana
end

-- Mientras no este el boton de la barra: se abre con clic derecho
local function onFillWorldObjectContextMenu(numJugador, context, worldobjects, test)
    context:addOption(getText("ContextMenu_WQ_AbrirPanel"), nil, Panel.alternar)
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
