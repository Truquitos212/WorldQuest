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

local ANCHO, ALTO = 940, 540
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

-- Lo que usan las pestanas que viven en otros archivos
Panel.Vista = Vista
Panel.MARGEN = MARGEN
Panel.ALTO_LINEA = ALTO_LINEA
Panel.FUENTE = FUENTE
Panel.FUENTE_TITULO = FUENTE_TITULO
Panel.E = E
Panel.ayuda = ayuda
Panel.extra = Panel.extra or {}   -- { orden, clase, clave }

-- Agrega una pestana al Centro de mando. orden: donde va (Resumen 10 ... Ayuda 110)
-- si: funcion opcional; la pestana solo aparece si devuelve true al abrir la ventana
function Panel.registrar(orden, clase, clave, si)
    for _, p in ipairs(Panel.extra) do
        if p.clave == clave then
            p.orden, p.clase, p.si = orden, clase, si
            return
        end
    end
    table.insert(Panel.extra, { orden = orden, clase = clase, clave = clave, si = si })
end

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
    -- Los cinco recursos en una fila, cada uno con su ayuda
    local R = WorldQuest.Recursos
    local x = MARGEN
    for _, id in ipairs(R.LISTA) do
        local valor = r[id] or 0
        local texto = getText("IGUI_WQ_Panel_RecursoValor", R.nombre(id), R.corto(valor))
        if id == "comida" then
            texto = getText("IGUI_WQ_Panel_RecursoKcal", R.nombre(id), R.corto(valor))
        end
        self:texto(texto, x, y, valor > 0 and e.texto or e.gris, nil, ayuda("Recurso_" .. id))
        x = x + getTextManager():MeasureStringX(FUENTE, texto) + 18
    end
    if (r.cigarros or 0) > 0 then
        self:texto(getText("IGUI_WQ_Panel_RecursoValor", R.nombre("cigarros"), R.corto(r.cigarros)), x, y, e.gris, nil, ayuda("Recurso_cigarros"))
    end
    y = y + ALTO_LINEA
    self:texto(getText("IGUI_WQ_Panel_Riqueza", R.corto(v.riqueza or 0)), MARGEN, y, nil, nil, ayuda("Riqueza"))
    local esp = WorldQuest.Economia.especialidad(t)
    local textoEsp = esp and getText("IGUI_WQ_Panel_Especialidad", getText("IGUI_WQ_Esp_" .. esp.id)) or getText("IGUI_WQ_Panel_SinEspecialidad")
    self:texto(textoEsp, MARGEN + 200, y, esp and e.bien or e.gris, nil, esp and ayuda("Esp_" .. esp.id) or ayuda("Especialidad"))
    y = y + ALTO_LINEA
    if t.entregas and next(t.entregas) then
        self:texto(getText("IGUI_WQ_Panel_Entregas", R.texto(t.entregas)), MARGEN, y, e.acento, nil, ayuda("Entregas"))
        y = y + ALTO_LINEA
    end
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

    -- Segunda columna: quien es, sus rasgos y que esta haciendo
    local x2 = X_FICHA + 280
    local y2 = Y_ROL
    if colono.oficio then
        self:texto(getText("IGUI_WQ_Ficha_Antes", getText("IGUI_WQ_Oficio_" .. colono.oficio), tostring(colono.edad or "?")), x2, y2, e.gris)
        y2 = y2 + ALTO_LINEA
    end
    if colono.desde then
        local minutos = math.floor(WorldQuest.Reloj.minutosDePartida(getGameTime():getWorldAgeHours() - colono.desde))
        self:texto(getText("IGUI_WQ_Ficha_Desde", tostring(minutos), tostring(colono.trabajos or 0)), x2, y2, e.gris, nil, ayuda("Ficha_Desde"))
        y2 = y2 + ALTO_LINEA
    end
    y2 = y2 + 6
    self:texto(getText("IGUI_WQ_Ficha_Rasgos"), x2, y2, e.gris, nil, ayuda("Rasgos"))
    y2 = y2 + ALTO_LINEA
    for _, r in ipairs(colono.rasgos or {}) do
        self:texto("- " .. getText("IGUI_WQ_RasgoColono_" .. r), x2 + 8, y2, e.acento, nil, getText("IGUI_WQ_Ayuda_RasgoColono_" .. r))
        y2 = y2 + ALTO_LINEA
    end
    y2 = y2 + 6
    local estado = getText("IGUI_WQ_Ficha_EnBase")
    local viaje = WorldQuest.Economia and WorldQuest.Economia.expedicionDe(colono)
    if viaje then
        estado = getText("IGUI_WQ_Ficha_DeViaje", getText("IGUI_WQ_Viaje_" .. tostring(viaje.tipo)))
    elseif colono.orden then
        estado = getText("IGUI_WQ_Ficha_Orden", getText("IGUI_WQ_Orden_" .. tostring(colono.orden.tipo)))
    end
    self:texto(estado, x2, y2, viaje and e.acento or e.texto, nil, ayuda("Ficha_Estado"))
end

-- PESTANA OBRAS ------------------------------------------------------------
local VistaObras = Vista:derive("WorldQuestVistaObras")

function VistaObras:createChildren()
    self.botonUbicar = ISButton:new(self.width - 160 - MARGEN, MARGEN - 2, 160, 22, getText("IGUI_WQ_Panel_ElegirLugar"), self, VistaObras.alUbicar)
    self.botonUbicar:initialise()
    self.botonUbicar:setTooltip(ayuda("ElegirLugar"))
    self:addChild(self.botonUbicar)
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

function VistaObras:alUbicar()
    local t = self.ventana.territorio
    if t and t.proyecto and self.ventana.propio then
        WorldQuest.CursorObra.empezar(t)
        self.ventana:close()
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
        self.botonUbicar:setVisible(false)
        return
    end

    local y = MARGEN
    self.botonUbicar:setVisible(t.proyecto ~= nil and v.propio)
    if t.proyecto and t.proyecto.sinUbicar then
        self.botonUbicar:setTitle(getText("IGUI_WQ_Panel_ElegirLugar"))
        self:texto(getText("IGUI_WQ_Panel_ObraSinLugar", Proyectos.nombre(t.proyecto.id)), MARGEN, y, e.alerta, nil, ayuda("ElegirLugar"))
        y = y + ALTO_LINEA * 2 + 8
    elseif t.proyecto then
        self.botonUbicar:setTitle(getText("IGUI_WQ_Panel_CambiarLugar"))
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

    -- Solo para facciones sin rasgo de lider (creadas antes de la Fase 3B)
    self.comboRasgo = ISComboBox:new(MARGEN, 0, 200, 22, self, nil)
    self.comboRasgo:initialise()
    self:addChild(self.comboRasgo)
    self.botonRasgo = ISButton:new(MARGEN + 210, 0, 140, 22, getText("IGUI_WQ_Panel_ElegirRasgo"), self, VistaFaccion.alElegirRasgo)
    self.botonRasgo:initialise()
    self:addChild(self.botonRasgo)
    self.tipoRasgos = nil
end

function VistaFaccion:alElegirRasgo()
    local rasgo = self.comboRasgo:getSelectedData()
    if rasgo then
        WorldQuest.Red.pedir("elegirRasgo", { rasgo = rasgo })
    end
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
        self.comboRasgo:setVisible(false)
        self.botonRasgo:setVisible(false)
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
    if WorldQuest.Diplomacia then
        local D = WorldQuest.Diplomacia
        self:texto(getText("IGUI_WQ_Dipl_TuReputacion", tostring(D.reputacion(f))), MARGEN, y,
            D.malaFama(f) and e.alerta or nil, nil, ayuda("Reputacion"))
        y = y + ALTO_LINEA
    end

    -- Rasgo del lider
    local B = WorldQuest.Balance
    local esLider = f.lider == jugador:getUsername()
    if f.rasgo then
        local efectosRasgo = {}
        for _, item in ipairs(B.lista(B.RASGOS[f.rasgo] or {})) do
            table.insert(efectosRasgo, item.texto)
        end
        self:texto(getText("IGUI_WQ_Panel_Rasgo", getText("IGUI_WQ_Rasgo_" .. f.rasgo)), MARGEN, y, nil, nil,
            table.concat(efectosRasgo, ", "))
        self.comboRasgo:setVisible(false)
        self.botonRasgo:setVisible(false)
        y = y + ALTO_LINEA
    elseif esLider then
        if self.tipoRasgos ~= f.tipo then
            self.comboRasgo:clear()
            for _, rasgo in ipairs(B.RASGOS_DE[f.tipo] or {}) do
                self.comboRasgo:addOptionWithData(getText("IGUI_WQ_Rasgo_" .. rasgo), rasgo)
            end
            self.tipoRasgos = f.tipo
        end
        self:texto(getText("IGUI_WQ_Panel_SinRasgo"), MARGEN, y, e.alerta)
        y = y + ALTO_LINEA
        self.comboRasgo:setY(y)
        self.botonRasgo:setY(y)
        self.comboRasgo:setVisible(true)
        self.botonRasgo:setVisible(true)
        y = y + 28
    else
        self.comboRasgo:setVisible(false)
        self.botonRasgo:setVisible(false)
    end

    -- Efectos activos de la faccion y su lider
    y = y + 4
    self:texto(getText("IGUI_WQ_Panel_Efectos"), MARGEN, y, e.gris, nil, ayuda("Efectos"))
    y = y + ALTO_LINEA
    local x = MARGEN + 8
    for _, item in ipairs(B.lista(B.efectos(f.tipo, f.rasgo))) do
        local w = getTextManager():MeasureStringX(FUENTE, item.texto) + 14
        if x + w > self.width - MARGEN then
            x = MARGEN + 8
            y = y + ALTO_LINEA
        end
        self:texto(item.texto, x, y, item.bueno and e.bien or e.alerta)
        x = x + w
    end
    y = y + ALTO_LINEA

    local territorios = 0
    for _, t in ipairs(WorldQuest.Territorios.getDatos().lista) do
        if t.faccion == f.id then
            territorios = territorios + 1
        end
    end
    self:texto(getText("IGUI_WQ_Panel_TerritoriosFaccion", tostring(territorios)), MARGEN, y)
    y = y + ALTO_LINEA
    local puesto = f.puesto and WorldQuest.Territorios.buscarPorId(f.puesto.territorio)
    if puesto then
        self:texto(getText("IGUI_WQ_Panel_Puesto", puesto.nombre), MARGEN, y, nil, nil, ayuda("Puesto"))
    else
        self:texto(getText("IGUI_WQ_Panel_SinPuesto"), MARGEN, y, e.gris, nil, ayuda("Puesto"))
    end
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
    for _, fila in ipairs(self.filas or {}) do
        if y >= fila.y and y < fila.y + ALTO_LINEA then
            fila.accion()
            return true
        end
    end
    return true
end

-- Territorios que el jugador conoce (con la niebla de guerra, solo los vistos)
function Panel.territoriosConocidos()
    if WorldQuest.Niebla then
        return WorldQuest.Niebla.territoriosConocidos()
    end
    return WorldQuest.Territorios.getDatos().lista
end

function VistaMapa:dibujar()
    local e = E()
    local jugador = getPlayer()
    local lista = Panel.territoriosConocidos()
    self.filas = {}
    local y = Y_LISTA_MAPA
    if #lista == 0 then
        self:texto(getText("IGUI_WQ_Panel_SinTerritorio"), MARGEN, y, e.gris)
        y = y + ALTO_LINEA
    end
    for _, t in ipairs(lista) do
        local propio = WorldQuest.Territorios.esDueno(t, jugador)
        local color = propio and e.acento or e.texto
        local linea = getText("IGUI_WQ_Mapa_Fila", WorldQuest.Niveles.titulo(t), WorldQuest.Facciones.nombreDueno(t),
            tostring(t.colonosVistos or #WorldQuest.Colonos.delTerritorio(t)))
        if t.vistoHace then
            linea = linea .. "  " .. getText("IGUI_WQ_Niebla_Hace", tostring(t.vistoHace))
            color = e.gris
        end
        self:texto(linea, MARGEN, y, color, nil, ayuda("FilaMapa"))
        local destino = t
        table.insert(self.filas, { y = y, accion = function() abrirMapa(destino) end })
        y = y + ALTO_LINEA
        if y > self.height / 2 then
            break
        end
    end

    -- Viajes de la faccion: clic para llamarlos de vuelta
    local f = WorldQuest.Facciones.deJugador(jugador)
    if not f then
        return
    end
    y = y + ALTO_LINEA
    self:texto(getText("IGUI_WQ_Panel_Viajes"), MARGEN, y, e.acento, nil, ayuda("Viajes"))
    y = y + ALTO_LINEA
    local hay = false
    local ahora = getGameTime():getWorldAgeHours()
    for _, v in ipairs(WorldQuest.Economia.getExpediciones().lista) do
        if v.faccion == f.id then
            hay = true
            local _, _, estado = WorldQuest.Economia.posicionViaje(v, ahora)
            local minutos = WorldQuest.Reloj.minutosHasta(v.vuelta or v.llegada)
            local linea = getText("IGUI_WQ_Panel_Viaje", getText("IGUI_WQ_Viaje_" .. tostring(v.tipo)),
                table.concat(v.nombres or {}, ", "), getText("IGUI_WQ_ViajeEstado_" .. estado), tostring(minutos))
            local puedeLlamar = not v.vuelta and v.tipo == "exploracion"
            if puedeLlamar then
                linea = linea .. "  " .. getText("IGUI_WQ_Panel_ClicVolver")
            end
            self:texto(linea, MARGEN + 8, y, puedeLlamar and e.texto or e.gris)
            if puedeLlamar then
                local id = v.id
                table.insert(self.filas, { y = y, accion = function() WorldQuest.Red.pedir("llamarExpedicion", { id = id }) end })
            end
            y = y + ALTO_LINEA
            if y > self.height - ALTO_LINEA then
                break
            end
        end
    end
    if not hay then
        self:texto(getText("IGUI_WQ_Panel_SinViajes"), MARGEN + 8, y, e.gris, nil, ayuda("Expedicion"))
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
    local mia = WorldQuest.Facciones.deJugador(getPlayer())
    local todo = WorldQuest.Conflicto and WorldQuest.Conflicto.esObservador(mia)
    for i = #lista, 1, -1 do
        local entrada = lista[i]
        if entrada.faccion and not todo and not (mia and mia.id == entrada.faccion) then
            entrada = nil
        end
        if entrada then
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
    o.recursos = WorldQuest.Recursos.vacio()
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
    local lista = {
        { orden = 10, clase = VistaColonia, clave = "IGUI_WQ_Tab_Resumen" },
        { orden = 20, clase = VistaColonos, clave = "IGUI_WQ_Tab_Colonos" },
        { orden = 30, clase = VistaObras, clave = "IGUI_WQ_Tab_Construccion" },
        { orden = 40, clase = VistaCrisis, clave = "IGUI_WQ_Tab_Crisis" },
        { orden = 50, clase = VistaFaccion, clave = "IGUI_WQ_Tab_Faccion" },
        { orden = 80, clase = VistaMapa, clave = "IGUI_WQ_Tab_Mapa" },
        { orden = 100, clase = VistaRegistro, clave = "IGUI_WQ_Tab_Registro" },
        { orden = 110, clase = VistaAyuda, clave = "IGUI_WQ_Tab_Ayuda" },
    }
    for _, p in ipairs(Panel.extra) do
        if not p.si or p.si() then
            table.insert(lista, p)
        end
    end
    table.sort(lista, function(a, b) return a.orden < b.orden end)
    self.vistas = {}
    for _, p in ipairs(lista) do
        local vista = p.clase:new(0, 0, self.width, altoVista, self)
        vista:initialise()
        self.pestanas:addView(getText(p.clave), vista)
        self.vistas[p.clave] = vista
    end
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
    self.riqueza = WorldQuest.Economia.riquezaTerritorio(t)
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
