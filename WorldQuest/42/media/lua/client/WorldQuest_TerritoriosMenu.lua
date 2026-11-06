-- WorldQuest - Territorios: opciones en el menu de clic derecho (cliente)

WorldQuest = WorldQuest or {}

local Territorios = WorldQuest.Territorios
local RADIO_INICIAL = 20
local LARGO_MAXIMO_NOMBRE = 30

-- Limpia el texto escrito por el jugador; devuelve nil si queda vacio
local function limpiarNombre(texto)
    texto = texto:match("^%s*(.-)%s*$")
    if texto == "" then
        return nil
    end
    return string.sub(texto, 1, LARGO_MAXIMO_NOMBRE)
end

-- Ventana para escribir un nombre, centrada en pantalla
local function pedirNombre(jugador, titulo, textoInicial, alConfirmar, param1, param2)
    local ancho, alto = 280, 180
    local x = (getCore():getScreenWidth() - ancho) / 2
    local y = (getCore():getScreenHeight() - alto) / 2
    local ventana = ISTextBox:new(x, y, ancho, alto, titulo, textoInicial,
        nil, alConfirmar, jugador:getPlayerNum(), param1, param2)
    ventana:initialise()
    ventana:addToUIManager()
end

-- Ventana de Si/No, centrada en pantalla
local function pedirConfirmacion(jugador, texto, alResponder, param1, param2)
    local ancho, alto = 300, 150
    local x = (getCore():getScreenWidth() - ancho) / 2
    local y = (getCore():getScreenHeight() - alto) / 2
    local ventana = ISModalDialog:new(x, y, ancho, alto, texto, true,
        nil, alResponder, jugador:getPlayerNum(), param1, param2)
    ventana:initialise()
    ventana:addToUIManager()
end

-- RECLAMAR ------------------------------------------------------------

local function alNombrarNuevo(target, boton, jugador, posicion)
    if boton.internal ~= "OK" then
        return
    end

    -- Revalidar: mientras la ventana estaba abierta pudo cambiar algo
    if Territorios.buscarSuperpuesto(posicion.x, posicion.y, RADIO_INICIAL) then
        jugador:Say(getText("IGUI_WQ_NoReclamable"))
        return
    end

    local nombre = limpiarNombre(boton.parent.entry:getText()) or Territorios.nombreSugerido()
    local territorio = Territorios.crear(nombre, posicion.x, posicion.y, RADIO_INICIAL)

    jugador:Say(getText("IGUI_WQ_Reclamado", territorio.nombre))
    print("[WorldQuest] Territorio reclamado: " .. territorio.nombre .. " en " .. posicion.x .. ", " .. posicion.y)
end

local function reclamarTerritorio(jugador)
    local posicion = {
        x = math.floor(jugador:getX()),
        y = math.floor(jugador:getY()),
    }
    pedirNombre(jugador, getText("IGUI_WQ_NombreNuevo"), Territorios.nombreSugerido(),
        alNombrarNuevo, jugador, posicion)
end

-- RENOMBRAR -----------------------------------------------------------

local function alRenombrar(target, boton, jugador, territorio)
    if boton.internal ~= "OK" then
        return
    end

    local nombre = limpiarNombre(boton.parent.entry:getText())
    if not nombre then
        return
    end

    local anterior = territorio.nombre
    Territorios.renombrar(territorio, nombre)

    jugador:Say(getText("IGUI_WQ_Renombrado", nombre))
    print("[WorldQuest] Territorio renombrado: " .. anterior .. " -> " .. nombre)
end

local function renombrarTerritorio(jugador, territorio)
    pedirNombre(jugador, getText("IGUI_WQ_Nombre"), territorio.nombre,
        alRenombrar, jugador, territorio)
end

-- ABANDONAR -----------------------------------------------------------

local function alConfirmarAbandono(target, boton, jugador, territorio)
    if boton.internal ~= "YES" then
        return
    end

    Territorios.eliminar(territorio)

    jugador:Say(getText("IGUI_WQ_Abandonado", territorio.nombre))
    print("[WorldQuest] Territorio abandonado: " .. territorio.nombre)
end

local function abandonarTerritorio(jugador, territorio)
    pedirConfirmacion(jugador, getText("IGUI_WQ_ConfirmarAbandono", territorio.nombre),
        alConfirmarAbandono, jugador, territorio)
end

-- MENU ----------------------------------------------------------------

local function onFillWorldObjectContextMenu(numJugador, context, worldobjects, test)
    local jugador = getSpecificPlayer(numJugador)
    local x = math.floor(jugador:getX())
    local y = math.floor(jugador:getY())

    -- Dentro de un territorio: mostrar cual es, renombrar o abandonar
    local actual = Territorios.buscarEn(x, y)
    if actual then
        local info = context:addOption(getText("ContextMenu_WQ_TerritorioActual", actual.nombre), nil, nil)
        info.notAvailable = true
        context:addOption(getText("ContextMenu_WQ_Renombrar"), jugador, renombrarTerritorio, actual)
        context:addOption(getText("ContextMenu_WQ_Abandonar"), jugador, abandonarTerritorio, actual)
        return
    end

    -- Fuera, pero el territorio nuevo chocaria con otro
    local cercano = Territorios.buscarSuperpuesto(x, y, RADIO_INICIAL)
    if cercano then
        local opcion = context:addOption(getText("ContextMenu_WQ_ReclamarCerca", cercano.nombre), nil, nil)
        opcion.notAvailable = true
        return
    end

    context:addOption(getText("ContextMenu_WQ_Reclamar"), jugador, reclamarTerritorio)
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
