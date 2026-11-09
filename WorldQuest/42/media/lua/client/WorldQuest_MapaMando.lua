-- WorldQuest - Mapa de mando (cliente)
-- En el mapa del mundo: los colonos de tu faccion como iconos (color segun su
-- estado, letra segun su rol), seleccion con clic o Shift + arrastrar, ordenes con
-- clic derecho y un panel chico con las escuadras.
-- Las ordenes las valida y guarda el servidor (server/WorldQuest_MandoServidor.lua).

require "ISUI/Maps/ISWorldMap"
require "ISUI/ISPanel"
require "ISUI/ISButton"

WorldQuest = WorldQuest or {}
WorldQuest.MapaMando = WorldQuest.MapaMando or {}

local Mando = WorldQuest.MapaMando
local Red = WorldQuest.Red

local TAMANO = 14          -- lado del icono en pixeles
local RADIO_CLIC = 9       -- distancia para tomar un clic como sobre un icono
local LETRAS = { agricultor = "A", explorador = "E", constructor = "C", guardia = "G", medico = "M", ninguno = "-" }

Mando.seleccion = {}       -- id de colono -> true
local iconos = {}          -- ultimo dibujo: { id, x, y } en pantalla

function Mando.cantidadSeleccion()
    local n = 0
    for _, _ in pairs(Mando.seleccion) do
        n = n + 1
    end
    return n
end

function Mando.idsSeleccion()
    local ids = {}
    for id, _ in pairs(Mando.seleccion) do
        table.insert(ids, id)
    end
    return ids
end

function Mando.limpiar()
    Mando.seleccion = {}
end

-- Colonos de la faccion del jugador, con su territorio
local function colonosPropios()
    local jugador = getPlayer()
    local f = jugador and WorldQuest.Facciones.deJugador(jugador)
    local lista = {}
    if not f then
        return lista, nil
    end
    for _, t in ipairs(WorldQuest.Territorios.getDatos().lista) do
        if t.faccion == f.id then
            for _, colono in ipairs(WorldQuest.Colonos.delTerritorio(t)) do
                table.insert(lista, { colono = colono, territorio = t })
            end
        end
    end
    return lista, f
end

local function colorEstado(colono)
    if colono.animo < 30 then
        return 0.85, 0.25, 0.2
    end
    if WorldQuest.Colonos.ciclosSinComer(colono) > 0 then
        return 0.95, 0.8, 0.2
    end
    if colono.rol == "ninguno" then
        return 0.6, 0.6, 0.6
    end
    return 0.3, 0.8, 0.35
end

-- Posicion en el mundo: el cuerpo si esta cargado, el punto de defensa, o un
-- anillo alrededor del centro del territorio
local function posicion(colono, territorio, indice, total)
    local cuerpo = WorldQuest.Cuerpos and WorldQuest.Cuerpos.cercanos()[colono.nombre]
    if cuerpo then
        return cuerpo:getX(), cuerpo:getY()
    end
    local orden = colono.orden
    if orden and orden.x and (orden.tipo == "defender" or orden.tipo == "ir" or orden.tipo == "mantener") then
        return orden.x + 0.5, orden.y + 0.5
    end
    local angulo = (indice / math.max(1, total)) * 2 * math.pi
    local radio = math.min(6, territorio.radio / 3)
    return territorio.x + math.cos(angulo) * radio, territorio.y + math.sin(angulo) * radio
end

-- Obras de la faccion: la que esta en curso (contorno naranjo) y las terminadas (gris)
local function dibujarObras(mapa)
    local jugador = getPlayer()
    local f = jugador and WorldQuest.Facciones.deJugador(jugador)
    if not f then
        return
    end
    local api = mapa.mapAPI
    local function cuadro(x, y, tamano, relleno, r, g, b)
        local x1, y1 = api:worldToUIX(x, y), api:worldToUIY(x, y)
        local x2, y2 = api:worldToUIX(x + tamano, y + tamano), api:worldToUIY(x + tamano, y + tamano)
        local w, h = math.max(4, x2 - x1), math.max(4, y2 - y1)
        if relleno then
            mapa:drawRect(x1, y1, w, h, 0.8, r, g, b)
        end
        mapa:drawRectBorder(x1, y1, w, h, 1, r, g, b)
    end
    for _, t in ipairs(WorldQuest.Territorios.getDatos().lista) do
        if t.faccion == f.id then
            for _, obra in pairs(t.obras or {}) do
                cuadro(obra.x, obra.y, obra.tamano or 1, true, 0.55, 0.55, 0.55)
            end
            if t.proyecto and t.proyecto.x then
                local definicion = WorldQuest.Proyectos.buscar(t.proyecto.id)
                cuadro(t.proyecto.x, t.proyecto.y, definicion and definicion.tamano or 1, false, 1, 0.6, 0.15)
            end
        end
    end
end

local function dibujar(mapa)
    iconos = {}
    dibujarObras(mapa)
    local lista = colonosPropios()
    if #lista == 0 then
        return
    end
    local api = mapa.mapAPI
    local porTerritorio = {}
    for _, item in ipairs(lista) do
        local id = item.territorio.id
        porTerritorio[id] = (porTerritorio[id] or 0) + 1
        item.indice = porTerritorio[id]
    end
    for _, item in ipairs(lista) do
        local colono = item.colono
        local wx, wy = posicion(colono, item.territorio, item.indice, porTerritorio[item.territorio.id])
        local sx, sy = api:worldToUIX(wx, wy), api:worldToUIY(wx, wy)
        local r, g, b = colorEstado(colono)
        local m = TAMANO / 2
        if Mando.seleccion[colono.id] then
            mapa:drawRect(sx - m - 3, sy - m - 3, TAMANO + 6, TAMANO + 6, 1, 1, 1, 1)
        end
        mapa:drawRect(sx - m, sy - m, TAMANO, TAMANO, 1, r, g, b)
        mapa:drawRectBorder(sx - m, sy - m, TAMANO, TAMANO, 1, 0, 0, 0)
        mapa:drawTextCentre(LETRAS[colono.rol] or "?", sx, sy - 7, 0, 0, 0, 1, UIFont.Small)
        if colono.orden and colono.orden.tipo == "defender" then
            mapa:drawRectBorder(sx - m - 5, sy - m - 5, TAMANO + 10, TAMANO + 10, 1, 0.85, 0.25, 0.2)
        elseif colono.orden and (colono.orden.tipo == "ir" or colono.orden.tipo == "mantener") then
            mapa:drawRectBorder(sx - m - 5, sy - m - 5, TAMANO + 10, TAMANO + 10, 1, 0.3, 0.6, 1)
        end
        table.insert(iconos, { id = colono.id, x = sx, y = sy })
    end

    -- Rectangulo de seleccion
    local rect = mapa.wqRect
    if rect then
        local x1, y1 = math.min(rect.x0, rect.x1), math.min(rect.y0, rect.y1)
        local w, h = math.abs(rect.x1 - rect.x0), math.abs(rect.y1 - rect.y0)
        mapa:drawRect(x1, y1, w, h, 0.15, 1, 1, 1)
        mapa:drawRectBorder(x1, y1, w, h, 0.9, 1, 1, 1)
    end
end

local function iconoEn(x, y)
    local mejor, mejorDistancia = nil, nil
    for _, icono in ipairs(iconos) do
        local dx, dy = icono.x - x, icono.y - y
        local d = dx * dx + dy * dy
        if d <= RADIO_CLIC * RADIO_CLIC and (not mejorDistancia or d < mejorDistancia) then
            mejor, mejorDistancia = icono, d
        end
    end
    return mejor
end

-- ORDENES -----------------------------------------------------------------

local function ordenar(tipo, wx, wy)
    local ids = Mando.idsSeleccion()
    if #ids == 0 then
        return
    end
    local args = { colonos = ids, tipo = tipo, x = wx, y = wy }
    local lista = colonosPropios()

    -- Mantener: cada uno donde esta ahora (su cuerpo, o su icono si no esta cargado)
    if tipo == "mantener" then
        args.posiciones = {}
        local porTerritorio = {}
        for _, item in ipairs(lista) do
            porTerritorio[item.territorio.id] = (porTerritorio[item.territorio.id] or 0) + 1
            if Mando.seleccion[item.colono.id] then
                local px, py = posicion(item.colono, item.territorio, porTerritorio[item.territorio.id], #WorldQuest.Colonos.delTerritorio(item.territorio))
                args.posiciones[tostring(item.colono.id)] = { x = math.floor(px), y = math.floor(py) }
            end
        end
    end
    Red.pedir("ordenColonos", args)

    -- Cuerpos de Bandits: ir y mantener los llevan a un puesto de guardia en ese punto
    if WorldQuest.Cuerpos and WorldQuest.Cuerpos.activo() and (tipo == "ir" or tipo == "mantener") then
        for _, item in ipairs(lista) do
            if Mando.seleccion[item.colono.id] then
                local destino = args.posiciones and args.posiciones[tostring(item.colono.id)] or { x = math.floor(wx), y = math.floor(wy) }
                Mando.mover(item.colono.nombre, destino.x, destino.y, 0)
            end
        end
    end
    if tipo == "volver" or tipo == "llamar" then
        for _, item in ipairs(lista) do
            if Mando.seleccion[item.colono.id] then
                Mando.soltarDestino(item.colono.nombre)
            end
        end
    end
    -- Cuerpos de Bandits cercanos: llamar los hace seguirte, volver los deja en la base
    if WorldQuest.Cuerpos and WorldQuest.Cuerpos.activo() and (tipo == "llamar" or tipo == "volver") then
        local programa = (tipo == "llamar") and "Companion" or "Camper"
        local lista = colonosPropios()
        for _, item in ipairs(lista) do
            if Mando.seleccion[item.colono.id] then
                WorldQuest.Cuerpos.cambiarPrograma(item.colono.nombre, programa)
            end
        end
    end
end

local function alNombrarEscuadra(target, boton, ids)
    if boton.internal ~= "OK" then
        return
    end
    local nombre = WorldQuest.Territorios.limpiarNombre(boton.parent.entry:getText())
    if nombre then
        Red.pedir("crearEscuadra", { nombre = nombre, colonos = ids })
    end
end

function Mando.guardarEscuadra()
    local ids = Mando.idsSeleccion()
    if #ids == 0 then
        return
    end
    local ancho, alto = 280, 180
    local x = (getCore():getScreenWidth() - ancho) / 2
    local y = (getCore():getScreenHeight() - alto) / 2
    local ventana = ISTextBox:new(x, y, ancho, alto, getText("IGUI_WQ_Mando_NombreEscuadra"), "",
        nil, alNombrarEscuadra, getPlayer():getPlayerNum(), ids)
    ventana:initialise()
    ventana:addToUIManager()
end

function Mando.seleccionarEscuadra(escuadra)
    Mando.seleccion = {}
    for _, id in ipairs(escuadra.colonos or {}) do
        Mando.seleccion[id] = true
    end
    Mando.escuadraActual = escuadra.nombre
end

-- CUERPOS DE BANDITS: ir a un punto y quedarse de guardia --------------------
-- El cuerpo camina con una tarea "Move" de Bandits. Al llegar se crea un puesto de
-- guardia en esa casilla y el cuerpo pasa al programa CompanionGuard, que se queda
-- quieto vigilando mientras este sobre el puesto.

local destinos = {}          -- nombre -> { x, y, z, pedidoPuesto }
local creados = {}           -- "x,y,z" -> true (puestos que creo WorldQuest)
local ultimoSeguimiento = 0
local INTERVALO_MS = 1000

function Mando.ubicarObra(idTerritorio, x, y)
    Red.pedir("ubicarObra", { id = idTerritorio, x = x, y = y })
end

function Mando.mover(nombre, x, y, z)
    destinos[nombre] = { x = x, y = y, z = z or 0 }
end

local function llave(x, y, z)
    return x .. "," .. y .. "," .. z
end

local function hayPuesto(x, y, z)
    local ok, puestos = pcall(BanditPost.GetAll)
    if not ok or type(puestos) ~= "table" then
        return false
    end
    for _, p in pairs(puestos) do
        if p.x == x and p.y == y and p.z == z and p.type == "guard" then
            return true
        end
    end
    return false
end

-- Quita el destino y, si el puesto lo creo WorldQuest, lo saca
function Mando.soltarDestino(nombre)
    local d = destinos[nombre]
    destinos[nombre] = nil
    if d and creados[llave(d.x, d.y, d.z)] and hayPuesto(d.x, d.y, d.z) then
        creados[llave(d.x, d.y, d.z)] = nil
        pcall(BanditPost.GuardToggle, getPlayer(), d.x, d.y, d.z)
    end
end

local function seguir()
    if isServer() or not next(destinos) then
        return
    end
    local ahora = getTimestampMs()
    if ahora - ultimoSeguimiento < INTERVALO_MS then
        return
    end
    ultimoSeguimiento = ahora
    if not (WorldQuest.Cuerpos and WorldQuest.Cuerpos.activo() and BanditPost) then
        return
    end
    local cuerpos = WorldQuest.Cuerpos.cercanos()
    for nombre, d in pairs(destinos) do
        local zombie = cuerpos[nombre]
        if zombie then
            local dx, dy = zombie:getX() - (d.x + 0.5), zombie:getY() - (d.y + 0.5)
            if dx * dx + dy * dy <= 1.5 then
                -- Llego: puesto de guardia y programa de guardia
                if hayPuesto(d.x, d.y, d.z) then
                    WorldQuest.Cuerpos.cambiarPrograma(nombre, "CompanionGuard")
                    destinos[nombre] = nil
                elseif not d.pedidoPuesto then
                    d.pedidoPuesto = true
                    creados[llave(d.x, d.y, d.z)] = true
                    pcall(BanditPost.GuardToggle, getPlayer(), d.x, d.y, d.z)
                end
            else
                local ok, enCamino = pcall(Bandit.HasMoveTask, zombie)
                if ok and not enCamino then
                    pcall(function()
                        Bandit.ClearTasks(zombie)
                        Bandit.AddTask(zombie, { action = "Move", time = 200, endurance = 0,
                            x = d.x + 0.5, y = d.y + 0.5, z = d.z, walkType = "Walk" })
                    end)
                end
            end
        end
    end
end

Events.OnTick.Add(seguir)

-- PANEL DE MANDO (dentro del mapa) ----------------------------------------

local PanelMando = ISPanel:derive("WorldQuestPanelMando")

function PanelMando:new(x, y)
    local o = ISPanel:new(x, y, 220, 110)
    setmetatable(o, self)
    self.__index = self
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.7 }
    o.borderColor = { r = 1, g = 1, b = 1, a = 0.3 }
    o.botonesEscuadra = {}
    o.firma = nil
    return o
end

function PanelMando:createChildren()
    self.botonGuardar = ISButton:new(8, 44, 100, 20, getText("IGUI_WQ_Mando_Guardar"), self, Mando.guardarEscuadra)
    self.botonGuardar:initialise()
    self.botonGuardar:setTooltip(getText("IGUI_WQ_Ayuda_GuardarEscuadra"))
    self:addChild(self.botonGuardar)
    self.botonLimpiar = ISButton:new(112, 44, 100, 20, getText("IGUI_WQ_Mando_Limpiar"), self, PanelMando.alLimpiar)
    self.botonLimpiar:initialise()
    self:addChild(self.botonLimpiar)
    self.botonBorrar = ISButton:new(8, 0, 204, 20, getText("IGUI_WQ_Mando_Borrar"), self, PanelMando.alBorrar)
    self.botonBorrar:initialise()
    self:addChild(self.botonBorrar)
end

function PanelMando:alLimpiar()
    Mando.limpiar()
    Mando.escuadraActual = nil
end

function PanelMando:alBorrar()
    if Mando.escuadraActual then
        Red.pedir("borrarEscuadra", { nombre = Mando.escuadraActual })
        Mando.escuadraActual = nil
    end
end

function PanelMando:alEscuadra(boton)
    Mando.seleccionarEscuadra(boton.escuadra)
end

-- Rehace los botones de escuadras cuando cambian
function PanelMando:actualizarEscuadras(f)
    local escuadras = (f and f.escuadras) or {}
    local partes = {}
    for _, e in ipairs(escuadras) do
        table.insert(partes, e.nombre .. ":" .. #(e.colonos or {}))
    end
    local firma = table.concat(partes, "|")
    if firma == self.firma then
        return
    end
    self.firma = firma
    for _, boton in ipairs(self.botonesEscuadra) do
        self:removeChild(boton)
    end
    self.botonesEscuadra = {}
    local y = 72
    for _, e in ipairs(escuadras) do
        local boton = ISButton:new(8, y, 204, 20, getText("IGUI_WQ_Mando_BotonEscuadra", e.nombre, tostring(#(e.colonos or {}))), self, PanelMando.alEscuadra)
        boton:initialise()
        boton.escuadra = e
        self:addChild(boton)
        table.insert(self.botonesEscuadra, boton)
        y = y + 24
    end
    self.botonBorrar:setY(y + 4)
    self:setHeight(y + 30)
end

function PanelMando:prerender()
    local jugador = getPlayer()
    local f = jugador and WorldQuest.Facciones.deJugador(jugador)
    self:actualizarEscuadras(f)
    self.botonBorrar:setEnable(Mando.escuadraActual ~= nil)
    self.botonGuardar:setEnable(Mando.cantidadSeleccion() > 0)
    ISPanel.prerender(self)
end

function PanelMando:render()
    ISPanel.render(self)
    self:drawText(getText("IGUI_WQ_Mando_Titulo", tostring(Mando.cantidadSeleccion())), 8, 4, 1, 0.85, 0.5, 1, UIFont.Small)
    self:drawText(getText("IGUI_WQ_Mando_Ayuda"), 8, 22, 0.7, 0.7, 0.7, 1, UIFont.Small)
end

-- GANCHOS EN EL MAPA DEL JUEGO --------------------------------------------
-- Se instalan al empezar la partida, despues de los demas archivos, para quedar
-- por encima del dibujo de los territorios.

local function instalar()
    if Mando.instalado then
        return
    end
    Mando.instalado = true

    local renderOriginal = ISWorldMap.render
    function ISWorldMap:render()
        renderOriginal(self)
        if not self.wqPanelMando then
            self.wqPanelMando = PanelMando:new(10, 60)
            self.wqPanelMando:initialise()
            self:addChild(self.wqPanelMando)
        end
        self.wqPanelMando:setVisible(WorldQuest.Facciones.deJugador(getPlayer()) ~= nil)
        local ok, err = pcall(dibujar, self)
        if not ok and not Mando.errorAvisado then
            Mando.errorAvisado = true
            print("[WorldQuest] Error al dibujar el mapa de mando: " .. tostring(err))
        end
    end

    -- Shift + arrastrar: rectangulo de seleccion (no mueve el mapa)
    local downOriginal = ISWorldMap.onMouseDown
    function ISWorldMap:onMouseDown(x, y)
        if isShiftKeyDown() and WorldQuest.Facciones.deJugador(getPlayer()) then
            self.wqRect = { x0 = x, y0 = y, x1 = x, y1 = y }
            return true
        end
        return downOriginal(self, x, y)
    end

    local moveOriginal = ISWorldMap.onMouseMove
    function ISWorldMap:onMouseMove(dx, dy)
        if self.wqRect then
            self.wqRect.x1 = self:getMouseX()
            self.wqRect.y1 = self:getMouseY()
            return true
        end
        return moveOriginal(self, dx, dy)
    end

    local function terminarRect(mapa)
        local rect = mapa.wqRect
        mapa.wqRect = nil
        local x1, x2 = math.min(rect.x0, rect.x1), math.max(rect.x0, rect.x1)
        local y1, y2 = math.min(rect.y0, rect.y1), math.max(rect.y0, rect.y1)
        Mando.escuadraActual = nil
        for _, icono in ipairs(iconos) do
            if icono.x >= x1 and icono.x <= x2 and icono.y >= y1 and icono.y <= y2 then
                Mando.seleccion[icono.id] = true
            end
        end
    end

    local upOriginal = ISWorldMap.onMouseUp
    function ISWorldMap:onMouseUp(x, y)
        if self.wqRect then
            terminarRect(self)
            return true
        end
        local seMovio = self.dragMoved
        local resultado = upOriginal(self, x, y)
        if not seMovio then
            -- Clic simple: sobre un icono lo selecciona (con Shift lo suma); afuera limpia
            local icono = iconoEn(x, y)
            if icono then
                if not isShiftKeyDown() then
                    Mando.seleccion = {}
                end
                Mando.seleccion[icono.id] = true
                Mando.escuadraActual = nil
            elseif not isShiftKeyDown() then
                Mando.limpiar()
                Mando.escuadraActual = nil
            end
        end
        return resultado
    end

    local upFueraOriginal = ISWorldMap.onMouseUpOutside
    function ISWorldMap:onMouseUpOutside(x, y)
        if self.wqRect then
            terminarRect(self)
            return true
        end
        return upFueraOriginal(self, x, y)
    end

    -- Clic derecho con colonos seleccionados: menu de ordenes
    local derechoOriginal = ISWorldMap.onRightMouseUp
    function ISWorldMap:onRightMouseUp(x, y)
        local wx = self.mapAPI:uiToWorldX(x, y)
        local wy = self.mapAPI:uiToWorldY(x, y)

        -- Obra en curso de un territorio propio bajo el clic: se puede ubicar aqui
        local jugador = getPlayer()
        local t = WorldQuest.Territorios.buscarEn(math.floor(wx), math.floor(wy))
        local obra = t and t.proyecto and WorldQuest.Territorios.esDueno(t, jugador) and t.faccion ~= nil
        local n = Mando.cantidadSeleccion()
        if n == 0 and not obra then
            return derechoOriginal(self, x, y)
        end

        local context = ISContextMenu.get(self.playerNum, x + self:getAbsoluteX(), y + self:getAbsoluteY())
        if obra then
            context:addOption(getText("IGUI_WQ_Mando_UbicarObra", WorldQuest.Proyectos.nombre(t.proyecto.id)), t.id, Mando.ubicarObra, math.floor(wx), math.floor(wy))
        end
        if n > 0 then
            local titulo = context:addOption(getText("IGUI_WQ_Mando_Menu", tostring(n)), nil, nil)
            titulo.notAvailable = true
            context:addOption(getText("IGUI_WQ_Mando_IrAqui"), "ir", ordenar, wx, wy)
            context:addOption(getText("IGUI_WQ_Mando_Mantener"), "mantener", ordenar, wx, wy)
            context:addOption(getText("IGUI_WQ_Mando_Defender"), "defender", ordenar, wx, wy)
            context:addOption(getText("IGUI_WQ_Mando_Llamar"), "llamar", ordenar, wx, wy)
            context:addOption(getText("IGUI_WQ_Mando_Volver"), "volver", ordenar, wx, wy)
        end
        return true
    end

    print("[WorldQuest] Mapa de mando listo")
end

Events.OnGameStart.Add(instalar)
