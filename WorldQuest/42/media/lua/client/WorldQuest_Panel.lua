-- WorldQuest - Centro de mando (cliente)
-- Un solo boton abre el Centro de mando; todo el mod vive aqui en pestanas.
-- Cada dato tiene un tooltip corto (pasa el mouse encima). Las acciones son
-- ordenes al servidor (WorldQuest.Red.pedir).

require "ISUI/ISCollapsableWindow"
require "ISUI/ISTabPanel"
require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISComboBox"

WorldQuest = WorldQuest or {}
WorldQuest.Panel = WorldQuest.Panel or {}

local Panel = WorldQuest.Panel

local ANCHO, ALTO = 700, 480
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

local function E()
    return WorldQuest.Estilo.actual()
end

local function ayuda(id)
    return getText("IGUI_WQ_Ayuda_" .. id)
end

-- Territorio a mostrar: el propio mas cercano; si no tienes, el mas cercano de otro
function Panel.territorioActual()
    local jugador = getPlayer()
    local lista = WorldQuest.Territorios.getDatos().lista
    if not jugador or #lista == 0 then
        return nil
    end
    local mejor, mejorDistancia, mejorPropio = nil, nil, false
    for _, t in ipairs(lista) do
        local propio = WorldQuest.Territorios.esDueno(t, jugador)
        local dx = t.x - jugador:getX()
        local dy = t.y - jugador:getY()
        local distancia = dx * dx + dy * dy
        local gana = false
        if not mejor then
            gana = true
        elseif propio ~= mejorPropio then
            gana = propio
        else
            gana = distancia < mejorDistancia
        end
        if gana then
            mejor, mejorDistancia, mejorPropio = t, distancia, propio
        end
    end
    return mejor
end

-- VISTA BASE: panel transparente con texto, barras y tooltips -------------
local Vista = ISPanel:derive("WorldQuestVista")

function Vista:new(x, y, ancho, alto, ventana)
    local o = ISPanel:new(x, y, ancho, alto)
    setmetatable(o, self)
    self.__index = self
    o.ventana = ventana
    o.background = false
    o.border = false
    o.zonas = {}
    return o
end

function Vista:prerender()
    self.zonas = {}
    ISPanel.prerender(self)
end

-- Las vistas dibujan en dibujar(); despues se pinta el tooltip bajo el mouse
function Vista:render()
    self:dibujar()
    WorldQuest.Ayuda.dibujarZonas(self, self.zonas)
end

function Vista:dibujar()
end

-- Zona con tooltip
function Vista:zona(x, y, ancho, alto, texto)
    if texto then
        table.insert(self.zonas, { x = x, y = y, w = ancho, h = alto, texto = texto })
    end
end

function Vista:texto(str, x, y, color, fuente, textoAyuda)
    color = color or E().texto
    fuente = fuente or FUENTE
    self:drawText(str, x, y, color[1], color[2], color[3], 1, fuente)
    if textoAyuda then
        local tm = getTextManager()
        self:zona(x, y, tm:MeasureStringX(fuente, str), tm:getFontHeight(fuente), textoAyuda)
    end
end

function Vista:barra(x, y, ancho, valor, maximo, r, g, b)
    local fraccion = math.max(0, math.min(1, valor / maximo))
    self:drawRect(x, y, ancho, 10, 0.6, 0.15, 0.15, 0.15)
    self:drawRect(x, y, math.floor(ancho * fraccion), 10, 0.9, r, g, b)
    self:drawRectBorder(x, y, ancho, 10, 0.4, 1, 1, 1)
end

-- Texto largo en varias lineas; devuelve la y siguiente
function Vista:parrafo(str, x, y, ancho, color)
    for _, linea in ipairs(WorldQuest.Ayuda.envolver(str, ancho, FUENTE)) do
        self:texto(linea, x, y, color)
        y = y + ALTO_LINEA
    end
    return y
end

-- PESTANA COLONIA ---------------------------------------------------------
local VistaColonia = Vista:derive("WorldQuestVistaColonia")

function VistaColonia:createChildren()
    self.botonMejorar = ISButton:new(MARGEN, 0, 140, 24, getText("IGUI_WQ_Panel_Mejorar"), self, VistaColonia.alMejorar)
    self.botonMejorar:initialise()
    self.botonMejorar:setTooltip(ayuda("Mejorar"))
    self:addChild(self.botonMejorar)
end

function VistaColonia:alMejorar()
    local t = self.ventana.territorio
    if t then
        WorldQuest.Red.pedir("mejorar", { id = t.id })
        self.ventana:refrescar(true)
    end
end

function VistaColonia:dibujar()
    local v = self.ventana
    local t = v.territorio
    local e = E()
    if not t then
        self:texto(getText("IGUI_WQ_Panel_SinTerritorio"), MARGEN, MARGEN, e.gris)
        self.botonMejorar:setVisible(false)
        return
    end

    local Niveles = WorldQuest.Niveles
    local r = v.recursos
    local est = t.estructuras or { camas = 0, huertos = 0, cocinas = 0, generadores = 0 }
    local y = MARGEN

    self:texto(getText("IGUI_WQ_Panel_Nivel", Niveles.nombre(Niveles.datos(t))), MARGEN, y, e.acento, FUENTE_TITULO, ayuda("Nivel"))
    y = y + ALTO_LINEA * 2
    if not v.propio then
        self:texto(getText("IGUI_WQ_Panel_DeOtro", WorldQuest.Facciones.nombreDueno(t)), MARGEN, y, e.gris, nil, ayuda("DeOtro"))
        y = y + ALTO_LINEA
    end
    self:texto(getText("IGUI_WQ_Panel_Colonos", tostring(#v.colonos), tostring(v.cupo)), MARGEN, y, nil, nil, ayuda("Cupo"))
    y = y + ALTO_LINEA
    self:texto(getText("IGUI_WQ_Panel_Comida", tostring(r.comidas), tostring(r.calorias)), MARGEN, y, nil, nil, ayuda("Comida"))
    y = y + ALTO_LINEA
    self:texto(getText("IGUI_WQ_Panel_Materiales", tostring(r.tablas), tostring(r.clavos), tostring(r.troncos)), MARGEN, y, nil, nil, ayuda("Materiales"))
    y = y + ALTO_LINEA
    self:texto(getText("IGUI_WQ_Panel_Estructuras", tostring(est.camas), tostring(est.huertos), tostring(est.cocinas), tostring(est.generadores)), MARGEN, y, nil, nil, ayuda("Estructuras"))
    y = y + ALTO_LINEA
    self:texto(getText("IGUI_WQ_Panel_Defensa", tostring(v.defensa)), MARGEN, y, nil, nil, ayuda("Defensa"))
    y = y + ALTO_LINEA * 2

    local siguiente = Niveles.siguiente(t)
    if not siguiente then
        self:texto(getText("IGUI_WQ_NivelMaximo"), MARGEN, y, e.bien)
        self.botonMejorar:setVisible(false)
        return
    end

    self:texto(getText("IGUI_WQ_Panel_Siguiente", Niveles.nombre(siguiente)), MARGEN, y, e.acento, nil, ayuda("Siguiente"))
    y = y + ALTO_LINEA
    self:texto(getText("IGUI_WQ_Panel_Costo", Niveles.textoCosto(siguiente.costo, siguiente.colonos)), MARGEN, y)
    y = y + ALTO_LINEA
    if not v.puedeMejorar and v.motivoMejorar then
        self:texto(v.motivoMejorar, MARGEN, y, e.alerta)
        y = y + ALTO_LINEA
    end
    self.botonMejorar:setY(y + 4)
    self.botonMejorar:setVisible(true)
    self.botonMejorar:setEnable(v.propio and v.puedeMejorar == true)
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
    if colono and self.ventana.propio then
        WorldQuest.Red.pedir("rol", { colono = colono.id, rol = combo:getSelectedData() })
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

function VistaColonos:dibujar()
    local colonos = self.ventana.colonos
    local e = E()
    if not self.ventana.territorio or #colonos == 0 then
        self:texto(getText("IGUI_WQ_Panel_SinColonos"), MARGEN, MARGEN, e.gris, nil, ayuda("SinColonos"))
        self.comboRol:setVisible(false)
        return
    end

    -- Lista
    for i, colono in ipairs(colonos) do
        local y = MARGEN + (i - 1) * ALTO_FILA
        if colono.id == self.idSeleccionado then
            local s = e.seleccion
            self:drawRect(MARGEN - 4, y - 2, ANCHO_LISTA, ALTO_FILA - 2, 0.3, s[1], s[2], s[3])
        end
        self:texto(colono.nombre, MARGEN, y)
        local minutos = WorldQuest.Colonos.minutosSinComer(colono)
        if minutos > 0 then
            self:texto(getText("IGUI_WQ_Panel_HambreMin", tostring(minutos)), MARGEN, y + ALTO_LINEA, e.alerta)
        else
            self:texto(getText("IGUI_WQ_Rol_" .. colono.rol), MARGEN, y + ALTO_LINEA, e.gris)
        end
        self:barra(MARGEN + 120, y + ALTO_LINEA + 3, 80, colono.animo, 100, 0.3, 0.75, 0.35)
        self:zona(MARGEN + 120, y + ALTO_LINEA, 80, 14, ayuda("Animo"))
    end
    self:drawRect(ANCHO_LISTA + MARGEN, MARGEN, 1, self.height - MARGEN * 2, 0.3, 1, 1, 1)

    -- Ficha
    local colono = self:seleccionado()
    if not colono then
        self:texto(getText("IGUI_WQ_Panel_Selecciona"), X_FICHA, MARGEN, e.gris)
        self.comboRol:setVisible(false)
        return
    end
    self.comboRol:setVisible(true)
    self.comboRol.disabled = not self.ventana.propio

    self:texto(colono.nombre, X_FICHA, MARGEN, e.acento, FUENTE_TITULO)
    self:texto(getText("IGUI_WQ_Panel_Rol"), X_FICHA, Y_ROL, e.gris, nil, ayuda("Rol"))
    self:texto(getText("IGUI_WQ_Panel_Animo"), X_FICHA, Y_ANIMO, e.gris, nil, ayuda("Animo"))
    self:barra(X_FICHA + 70, Y_ANIMO + 3, 150, colono.animo, 100, 0.3, 0.75, 0.35)
    self:texto(tostring(colono.animo), X_FICHA + 228, Y_ANIMO)

    local minutos = WorldQuest.Colonos.minutosSinComer(colono)
    if minutos > 0 then
        self:texto(getText("IGUI_WQ_Panel_HambreMin", tostring(minutos)), X_FICHA, Y_HAMBRE, e.alerta, nil, ayuda("Hambre"))
    end

    self:texto(getText("IGUI_WQ_Panel_Habilidades"), X_FICHA, Y_HABILIDADES, e.gris, nil, ayuda("Habilidades"))
    for i, id in ipairs(WorldQuest.Colonos.HABILIDADES) do
        local y = Y_HABILIDADES + i * (ALTO_LINEA + 2)
        local valor = colono.habilidades[id] or 0
        local color = e.texto
        if id == colono.especialidad then
            color = e.acento
        end
        self:texto(getText("IGUI_WQ_Hab_" .. id), X_FICHA, y, color)
        self:barra(X_FICHA + 110, y + 3, 110, valor, 10, 0.35, 0.55, 0.85)
        self:texto(tostring(valor), X_FICHA + 228, y)
    end
end

-- PESTANA OBRAS ------------------------------------------------------------
local VistaObras = Vista:derive("WorldQuestVistaObras")

function VistaObras:createChildren()
    self.botones = {}
    for i, proyecto in ipairs(WorldQuest.Proyectos.LISTA) do
        local boton = ISButton:new(self.width - 120 - MARGEN, 0, 120, 22, getText("IGUI_WQ_Panel_Construir"), self, VistaObras.alConstruir)
        boton:initialise()
        boton:setTooltip(ayuda("Construir"))
        boton.proyecto = proyecto
        self:addChild(boton)
        self.botones[i] = boton
    end
end

function VistaObras:alConstruir(boton)
    local t = self.ventana.territorio
    if t then
        WorldQuest.Red.pedir("construir", { id = t.id, proyecto = boton.proyecto.id })
        self.ventana:refrescar(true)
    end
end

function VistaObras:dibujar()
    local v = self.ventana
    local t = v.territorio
    local e = E()
    local Proyectos = WorldQuest.Proyectos
    if not t then
        self:texto(getText("IGUI_WQ_Panel_SinTerritorio"), MARGEN, MARGEN, e.gris)
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
        self:texto(estado, MARGEN, y, e.acento, nil, ayuda("EnObra"))
        y = y + ALTO_LINEA
        if definicion then
            self:barra(MARGEN, y + 2, self.width - MARGEN * 2, definicion.trabajo - t.proyecto.restante, definicion.trabajo, 0.85, 0.6, 0.15)
        end
        y = y + ALTO_LINEA + 8
    end

    for i, proyecto in ipairs(Proyectos.LISTA) do
        local boton = self.botones[i]
        boton:setY(y + 2)
        local textoAyuda = ayuda("Proyecto_" .. proyecto.id)
        if Proyectos.construido(t, proyecto.id) then
            boton:setVisible(false)
            self:texto(Proyectos.nombre(proyecto.id), MARGEN, y, e.bien, nil, textoAyuda)
            self:texto(getText("IGUI_WQ_Panel_Construido"), MARGEN, y + ALTO_LINEA, e.bien)
        else
            local estado = v.puedeProyecto[proyecto.id] or {}
            boton:setVisible(true)
            boton:setEnable(v.propio and estado.ok == true)
            self:texto(getText("IGUI_WQ_Panel_Proyecto", Proyectos.nombre(proyecto.id),
                WorldQuest.Niveles.textoCosto(proyecto.costo), tostring(proyecto.trabajo * WorldQuest.Reloj.minutosCiclo())), MARGEN, y, nil, nil, textoAyuda)
            if not estado.ok and estado.motivo then
                self:texto(estado.motivo, MARGEN, y + ALTO_LINEA, e.alerta)
            end
        end
        y = y + ALTO_LINEA * 2 + 10
    end
end

-- PESTANA CRISIS -------------------------------------------------------
local VistaCrisis = Vista:derive("WorldQuestVistaCrisis")

function VistaCrisis:dibujar()
    local Crisis = WorldQuest.Crisis
    local e = E()
    local datos = Crisis.getDatos()
    local factor = WorldQuest.Modificadores.factorNarrador() * WorldQuest.Opciones.frecuenciaCrisis()
    local probabilidad = math.floor(math.min(datos.tension * 10 * factor, 80))

    local y = MARGEN
    self:texto(getText("IGUI_WQ_Panel_Tirada", tostring(datos.tension), tostring(probabilidad),
        tostring(Crisis.CICLOS_NARRADOR * WorldQuest.Reloj.minutosCiclo())), MARGEN, y, e.acento, nil, ayuda("Tension"))
    y = y + ALTO_LINEA * 2

    local hayAlgo = false
    for _, pendiente in ipairs(datos.pendientes) do
        if pendiente.conAviso then
            local nombre = getText("IGUI_WQ_Crisis_" .. pendiente.tipo)
            local minutos = WorldQuest.Reloj.minutosHasta(pendiente.hora)
            local linea
            if minutos > 0 then
                linea = getText("IGUI_WQ_PendienteMin", nombre, tostring(minutos))
            else
                linea = getText("IGUI_WQ_MapaEsperando", nombre)
            end
            local territorio = WorldQuest.Territorios.buscarPorId(pendiente.territorio)
            if territorio then
                linea = territorio.nombre .. ": " .. linea
            end
            self:texto(linea, MARGEN, y, e.alerta, nil, ayuda("Pendiente"))
            y = y + ALTO_LINEA
            hayAlgo = true
        end
    end

    if datos.frio then
        self:texto(getText("IGUI_WQ_Panel_Frio"), MARGEN, y, e.frio, nil, ayuda("Frio"))
        y = y + ALTO_LINEA
        hayAlgo = true
    end

    if not hayAlgo then
        self:texto(getText("IGUI_WQ_Panel_SinCrisis"), MARGEN, y, e.gris)
    end
end

-- PESTANA FACCION: tu faccion, sus miembros y territorios ---------------------
local VistaFaccion = Vista:derive("WorldQuestVistaFaccion")

function VistaFaccion:createChildren()
    self.botonCrear = ISButton:new(MARGEN, MARGEN + ALTO_LINEA * 2, 180, 24, getText("IGUI_WQ_Panel_CrearOUnirse"), self, VistaFaccion.alCrear)
    self.botonCrear:initialise()
    self:addChild(self.botonCrear)
    self.botonSalir = ISButton:new(MARGEN, 0, 180, 24, getText("IGUI_WQ_Panel_SalirFaccion"), self, VistaFaccion.alSalir)
    self.botonSalir:initialise()
    self.botonSalir:setTooltip(ayuda("SalirFaccion"))
    self:addChild(self.botonSalir)
end

function VistaFaccion:alCrear()
    WorldQuest.FaccionVentana.abrir()
end

local function alConfirmarSalida(target, boton)
    if boton.internal == "YES" then
        WorldQuest.Red.pedir("salirFaccion", {})
    end
end

function VistaFaccion:alSalir()
    local f = WorldQuest.Facciones.deJugador(getPlayer())
    if not f then
        return
    end
    local ancho, alto = 360, 150
    local x = (getCore():getScreenWidth() - ancho) / 2
    local y = (getCore():getScreenHeight() - alto) / 2
    local ventana = ISModalDialog:new(x, y, ancho, alto, getText("IGUI_WQ_ConfirmarSalida", f.nombre), true,
        nil, alConfirmarSalida, getPlayer():getPlayerNum())
    ventana:initialise()
    ventana:addToUIManager()
end

function VistaFaccion:dibujar()
    local e = E()
    local Facciones = WorldQuest.Facciones
    local jugador = getPlayer()
    local f = Facciones.deJugador(jugador)
    if not f then
        self:texto(getText("IGUI_WQ_Panel_SinFaccion"), MARGEN, MARGEN, e.gris, nil, ayuda("SinFaccion"))
        self.botonCrear:setVisible(true)
        self.botonSalir:setVisible(false)
        return
    end
    self.botonCrear:setVisible(false)

    local y = MARGEN
    self:texto(f.nombre, MARGEN, y, e.acento, FUENTE_TITULO)
    y = y + ALTO_LINEA * 2
    self:texto(getText("IGUI_WQ_Panel_TipoFaccion", Facciones.nombreTipo(f.tipo)), MARGEN, y, nil, nil,
        getText("IGUI_WQ_FaccionDesc_" .. f.tipo))
    y = y + ALTO_LINEA
    local color = Facciones.color(f.color)
    self:texto(getText("IGUI_WQ_Panel_ColorFaccion", getText("IGUI_WQ_Color_" .. f.color)), MARGEN, y)
    if color then
        self:drawRect(MARGEN + 160, y + 2, 40, ALTO_LINEA - 6, 1, color.r, color.g, color.b)
    end
    y = y + ALTO_LINEA
    self:texto(getText("IGUI_WQ_Panel_EmblemaFaccion", getText("IGUI_WQ_Emblema_" .. f.emblema)), MARGEN, y)
    y = y + ALTO_LINEA
    self:texto(getText("IGUI_WQ_Panel_Lider", f.lider), MARGEN, y, nil, nil, ayuda("Lider"))
    y = y + ALTO_LINEA

    local territorios = 0
    for _, t in ipairs(WorldQuest.Territorios.getDatos().lista) do
        if t.faccion == f.id then
            territorios = territorios + 1
        end
    end
    self:texto(getText("IGUI_WQ_Panel_TerritoriosFaccion", tostring(territorios)), MARGEN, y)
    y = y + ALTO_LINEA * 2

    self:texto(getText("IGUI_WQ_Panel_Miembros"), MARGEN, y, e.gris)
    y = y + ALTO_LINEA
    for _, usuario in ipairs(Facciones.miembros(f)) do
        self:texto("- " .. usuario, MARGEN + 8, y)
        y = y + ALTO_LINEA
    end

    self.botonSalir:setY(y + 10)
    self.botonSalir:setVisible(true)
end

-- PESTANA MAPA: todos los territorios conocidos; clic para verlo en el mapa --
local VistaMapa = Vista:derive("WorldQuestVistaMapa")

local Y_LISTA_MAPA = MARGEN + 36

local function abrirMapa(t)
    local jugador = getPlayer()
    if not jugador then
        return
    end
    if not ISWorldMap_instance or not ISWorldMap_instance:isVisible() then
        pcall(ISWorldMap.ShowWorldMap, jugador:getPlayerNum())
    end
    if t then
        pcall(function()
            ISWorldMap_instance.mapAPI:centerOn(t.x, t.y)
        end)
    end
end

function VistaMapa:createChildren()
    self.botonMapa = ISButton:new(MARGEN, MARGEN, 140, 24, getText("IGUI_WQ_Panel_AbrirMapa"), self, VistaMapa.alAbrir)
    self.botonMapa:initialise()
    self.botonMapa:setTooltip(ayuda("AbrirMapa"))
    self:addChild(self.botonMapa)
end

function VistaMapa:alAbrir()
    abrirMapa(self.ventana.territorio)
end

function VistaMapa:onMouseDown(x, y)
    if y >= Y_LISTA_MAPA then
        local i = math.floor((y - Y_LISTA_MAPA) / ALTO_LINEA) + 1
        local t = WorldQuest.Territorios.getDatos().lista[i]
        if t then
            abrirMapa(t)
        end
    end
    return true
end

function VistaMapa:dibujar()
    local e = E()
    local jugador = getPlayer()
    local lista = WorldQuest.Territorios.getDatos().lista
    if #lista == 0 then
        self:texto(getText("IGUI_WQ_Panel_SinTerritorio"), MARGEN, Y_LISTA_MAPA, e.gris)
        return
    end
    for i, t in ipairs(lista) do
        local y = Y_LISTA_MAPA + (i - 1) * ALTO_LINEA
        local propio = WorldQuest.Territorios.esDueno(t, jugador)
        local color = propio and e.acento or e.texto
        local linea = getText("IGUI_WQ_Mapa_Fila", WorldQuest.Niveles.titulo(t), WorldQuest.Facciones.nombreDueno(t),
            tostring(#WorldQuest.Colonos.delTerritorio(t)))
        self:texto(linea, MARGEN, y, color, nil, ayuda("FilaMapa"))
    end
end

-- PESTANA REGISTRO: lo que ha pasado en la partida, lo mas nuevo arriba ----
local VistaRegistro = Vista:derive("WorldQuestVistaRegistro")

function VistaRegistro:dibujar()
    local e = E()
    local lista = WorldQuest.Red.getRegistro().lista
    if #lista == 0 then
        self:texto(getText("IGUI_WQ_Registro_Vacio"), MARGEN, MARGEN, e.gris)
        return
    end
    local ahora = getGameTime():getWorldAgeHours()
    local y = MARGEN
    local anchoTexto = self.width - MARGEN * 2 - 90
    for i = #lista, 1, -1 do
        local entrada = lista[i]
        local minutos = math.floor(WorldQuest.Reloj.minutosDePartida(ahora - (entrada.h or ahora)))
        local hace = minutos < 1 and getText("IGUI_WQ_Registro_Recien") or getText("IGUI_WQ_Registro_Hace", tostring(minutos))
        local color = e.texto
        if entrada.tipo == "crisis" then
            color = e.alerta
        elseif entrada.tipo == "aviso" then
            color = e.acento
        end
        self:texto(hace, MARGEN, y, e.gris)
        y = self:parrafo(WorldQuest.Red.traducir(entrada.clave, entrada.p), MARGEN + 90, y, anchoTexto, color)
        if y > self.height - ALTO_LINEA then
            return
        end
    end
end

-- PESTANA AYUDA: las pistas que ya aparecieron ------------------------------
local VistaAyuda = Vista:derive("WorldQuestVistaAyuda")

function VistaAyuda:dibujar()
    local e = E()
    local y = MARGEN
    local hay = false
    for _, pista in ipairs(WorldQuest.Pistas.LISTA) do
        if WorldQuest.Pistas.vista(pista.id) then
            y = self:parrafo("- " .. WorldQuest.Pistas.texto(pista.id), MARGEN, y, self.width - MARGEN * 2, e.texto)
            y = y + 4
            hay = true
        end
    end
    if not hay then
        self:parrafo(getText("IGUI_WQ_Ayuda_SinPistas"), MARGEN, y, self.width - MARGEN * 2, e.gris)
    end
end

-- VENTANA ---------------------------------------------------------------
local Ventana = ISCollapsableWindow:derive("WorldQuestCentroDeMando")

function Ventana:new(x, y)
    local o = ISCollapsableWindow:new(x, y, ANCHO, ALTO)
    setmetatable(o, self)
    self.__index = self
    o.title = getText("IGUI_WQ_Panel_Boton")
    o.resizable = false
    o.ultimoRefresco = 0
    o.colonos = {}
    o.cupo = 0
    o.defensa = 0
    o.propio = false
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
    agregar(VistaColonia, "IGUI_WQ_Tab_Resumen")
    agregar(VistaColonos, "IGUI_WQ_Tab_Colonos")
    agregar(VistaObras, "IGUI_WQ_Tab_Construccion")
    agregar(VistaCrisis, "IGUI_WQ_Tab_Crisis")
    agregar(VistaFaccion, "IGUI_WQ_Tab_Faccion")
    agregar(VistaMapa, "IGUI_WQ_Tab_Mapa")
    agregar(VistaRegistro, "IGUI_WQ_Tab_Registro")
    agregar(VistaAyuda, "IGUI_WQ_Tab_Ayuda")
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
        self.propio = false
        self.title = getText("IGUI_WQ_Panel_Boton")
        return
    end

    self.propio = WorldQuest.Territorios.esDueno(t, getPlayer())
    self.title = getText("IGUI_WQ_Panel_Titulo", WorldQuest.Niveles.titulo(t))
    self.recursos = WorldQuest.Almacen.contar(t)
    self.colonos = WorldQuest.Colonos.delTerritorio(t)
    self.cupo = WorldQuest.Colonos.cupo(t)
    self.defensa = WorldQuest.Modificadores.defensa(t)
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

-- Abre o cierra el Centro de mando
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

-- Tambien se abre con clic derecho
local function onFillWorldObjectContextMenu(numJugador, context, worldobjects, test)
    context:addOption(getText("ContextMenu_WQ_AbrirPanel"), nil, Panel.alternar)
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
