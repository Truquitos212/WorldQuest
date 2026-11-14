-- WorldQuest - Mundo y conflicto (cliente)
-- Reconoce lugares importantes alrededor del jugador, los dibuja en el mapa, y agrega
-- las acciones contra bases ajenas: asaltar, espiar, sabotear y capturar en vivo.

require "WorldQuest_MapaMando"

local Mundo = WorldQuest.Mundo
local Conflicto = WorldQuest.Conflicto
local Red = WorldQuest.Red
local Facciones = WorldQuest.Facciones
local Territorios = WorldQuest.Territorios
local Mando = WorldQuest.MapaMando

local RADIO_BUSQUEDA = 50
local PASO = 4
local DISTANCIA_PUEBLO = 900
local LETRAS = { comisaria = "P", hospital = "H", supermercado = "S", ferreteria = "F", escuela = "E", radio = "R", militar = "B" }

local enviados = {}       -- "tipo:x:y" -> true (en esta sesion)
local puntosPueblo = nil

local function miFaccion()
    local j = getPlayer()
    return j and Facciones.deJugador(j)
end

-- Nombre del pueblo mas cercano segun los puntos de aparicion del juego
local function pueblo(x, y)
    if not puntosPueblo then
        puntosPueblo = WorldQuest.Inicio and WorldQuest.Inicio.candidatos() or {}
    end
    local mejor, distancia = nil, nil
    for _, p in ipairs(puntosPueblo) do
        local d = (p.x - x) ^ 2 + (p.y - y) ^ 2
        if not distancia or d < distancia then
            mejor, distancia = p, d
        end
    end
    if mejor and distancia <= DISTANCIA_PUEBLO * DISTANCIA_PUEBLO then
        return mejor.pueblo
    end
    return "Knox"
end

-- Centro del edificio de una habitacion (o la casilla si no se puede saber)
local function centro(room, casilla)
    local ok, x, y = pcall(function()
        local def = room:getBuilding():getDef()
        return def:getX() + math.floor(def:getW() / 2), def:getY() + math.floor(def:getH() / 2)
    end)
    if ok and x and y then
        return x, y
    end
    return casilla:getX(), casilla:getY()
end

local function buscarLugares()
    if isServer() then
        return
    end
    local j = getPlayer()
    if not j or not miFaccion() then
        return
    end
    local celda = getCell()
    local px, py = math.floor(j:getX()), math.floor(j:getY())
    for x = px - RADIO_BUSQUEDA, px + RADIO_BUSQUEDA, PASO do
        for y = py - RADIO_BUSQUEDA, py + RADIO_BUSQUEDA, PASO do
            local casilla = celda:getGridSquare(x, y, 0)
            local room = casilla and casilla:getRoom()
            if room then
                local ok, nombre = pcall(function() return room:getName() end)
                local tipo = ok and Mundo.tipoDeHabitacion(nombre) or nil
                if tipo then
                    local cx, cy = centro(room, casilla)
                    local llave = tipo.id .. ":" .. math.floor(cx / 50) .. ":" .. math.floor(cy / 50)
                    if not enviados[llave] and not Mundo.cercano(tipo.id, cx, cy, 150) then
                        enviados[llave] = true
                        Red.pedir("lugarVisto", { tipo = tipo.id, x = cx, y = cy, pueblo = pueblo(cx, cy) })
                    end
                end
            end
        end
    end
end

-- MAPA: lugares ------------------------------------------------------------------

Mando.agregarDibujo(function(mapa)
    local api = mapa.mapAPI
    for _, l in ipairs(Mundo.getDatos().lugares) do
        local duena = Mundo.controlador(l)
        local c = duena and Facciones.color(duena.color) or { r = 0.9, g = 0.9, b = 0.9 }
        local sx, sy = api:worldToUIX(l.x, l.y), api:worldToUIY(l.x, l.y)
        mapa:drawRect(sx - 9, sy - 9, 18, 18, 0.95, 0.12, 0.12, 0.12)
        mapa:drawRectBorder(sx - 9, sy - 9, 18, 18, 1, c.r, c.g, c.b)
        mapa:drawRectBorder(sx - 7, sy - 7, 14, 14, 0.6, c.r, c.g, c.b)
        mapa:drawTextCentre(LETRAS[l.tipo] or "?", sx, sy - 7, c.r, c.g, c.b, 1, UIFont.Small)
    end
end)

-- MAPA: acciones contra una base ajena con colonos elegidos -------------------------

local function pedir(orden, args)
    args.colonos = Mando.idsSeleccion()
    Red.pedir(orden, args)
    Mando.limpiar()
end

Mando.agregarOpcion(function(context, wx, wy, t, n, mapa)
    local f = miFaccion()
    if not f or not t or n == 0 or t.faccion == f.id then
        return
    end
    local acciones = Conflicto.acciones(f, t)
    if acciones.protegido then
        local titulo = context:addOption(getText("IGUI_WQ_Conf_EstaProtegida"), nil, nil)
        titulo.notAvailable = true
        return
    end
    if acciones.asaltar then
        local opcion = context:addOption(getText("IGUI_WQ_Conf_Asaltar", t.nombre))
        local sub = ISContextMenu:getNew(context)
        context:addSubMenu(opcion, sub)
        for _, modo in ipairs({ "saquear", "capturar", "eliminar" }) do
            local o = sub:addOption(getText("IGUI_WQ_Conf_Modo_" .. modo), t, function(objetivo)
                pedir("asaltar", { territorio = objetivo.id, modo = modo })
            end)
            o.toolTip = Mando.tooltip(getText("IGUI_WQ_Ayuda_Conf_" .. modo))
        end
    elseif WorldQuest.Diplomacia and not WorldQuest.Diplomacia.enGuerra(f.id, t.faccion) then
        local titulo = context:addOption(getText("IGUI_WQ_Conf_SoloGuerra"), nil, nil)
        titulo.notAvailable = true
    end
    if acciones.espiar then
        local o = context:addOption(getText("IGUI_WQ_Conf_Espiar", t.nombre), t, function(objetivo)
            local ids = Mando.idsSeleccion()
            Red.pedir("espiar", { territorio = objetivo.id, colonos = { ids[1] } })
            Mando.limpiar()
        end)
        o.toolTip = Mando.tooltip(getText("IGUI_WQ_Ayuda_Conf_Espiar"))
        local opcion = context:addOption(getText("IGUI_WQ_Conf_Sabotear", t.nombre))
        local sub = ISContextMenu:getNew(context)
        context:addSubMenu(opcion, sub)
        for _, blanco in ipairs({ "comida", "almacen", "obra", "exodo" }) do
            sub:addOption(getText("IGUI_WQ_Conf_Blanco_" .. blanco), t, function(objetivo)
                pedir("sabotear", { territorio = objetivo.id, blanco = blanco })
            end)
        end
    end
end)

-- MUNDO: captura en vivo con clic derecho dentro de una base enemiga --------------------

local function capturar(t)
    Red.pedir("capturar", { territorio = t.id })
end

local function onFillWorldObjectContextMenu(numJugador, context, worldobjects, test)
    local j = getSpecificPlayer(numJugador)
    local f = j and Facciones.deJugador(j)
    if not f then
        return
    end
    local t = Territorios.buscarEn(math.floor(j:getX()), math.floor(j:getY()))
    if not t or t.faccion == nil or t.faccion == f.id then
        return
    end
    local c = Conflicto.captura(t)
    if c and c.faccion == f.id then
        local titulo = context:addOption(getText("IGUI_WQ_Conf_CapturaAvance", tostring(math.floor(c.avance)), tostring(c.necesario)), nil, nil)
        titulo.notAvailable = true
        return
    end
    local acciones = Conflicto.acciones(f, t)
    if acciones.asaltar then
        local o = context:addOption(getText("IGUI_WQ_Conf_Capturar", t.nombre), t, capturar)
        o.toolTip = Mando.tooltip(getText("IGUI_WQ_Ayuda_Conf_Capturar"))
    end
end

-- Aviso del avance de una captura propia mientras estas adentro
local function avisarCaptura()
    if isServer() then
        return
    end
    local j = getPlayer()
    local f = j and Facciones.deJugador(j)
    if not f then
        return
    end
    for id, c in pairs(Conflicto.getDatos().capturas) do
        local t = Territorios.buscarPorId(tonumber(id))
        if t and c.faccion == f.id and Territorios.contiene(t, math.floor(j:getX()), math.floor(j:getY())) then
            local clave = c.disputa and "IGUI_WQ_Conf_CapturaDisputa" or "IGUI_WQ_Conf_CapturaAvance"
            j:Say(getText(clave, tostring(math.floor(c.avance)), tostring(c.necesario)))
        end
    end
end

Events.EveryTenMinutes.Add(buscarLugares)
Events.EveryTenMinutes.Add(avisarCaptura)
Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
