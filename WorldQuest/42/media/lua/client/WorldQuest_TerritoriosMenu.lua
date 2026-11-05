-- WorldQuest - Territorios: opciones en el menu de clic derecho (cliente)

WorldQuest = WorldQuest or {}

local Territorios = WorldQuest.Territorios
local RADIO_INICIAL = 20
local LARGO_MAXIMO_NOMBRE = 30

local function reclamarTerritorio(jugador)
    local x = math.floor(jugador:getX())
    local y = math.floor(jugador:getY())
    local territorio = Territorios.crear(Territorios.siguienteNombre(), x, y, RADIO_INICIAL)

    jugador:Say("Territorio reclamado: " .. territorio.nombre)
    print("[WorldQuest] Territorio reclamado: " .. territorio.nombre .. " en " .. x .. ", " .. y)
end

local function abandonarTerritorio(jugador, territorio)
    Territorios.eliminar(territorio)

    jugador:Say("Territorio abandonado: " .. territorio.nombre)
    print("[WorldQuest] Territorio abandonado: " .. territorio.nombre)
end

-- Se llama cuando el jugador aprieta OK o Cancelar en la ventana
local function alConfirmarNombre(target, boton, jugador, territorio)
    if boton.internal ~= "OK" then
        return
    end

    local texto = boton.parent.entry:getText()
    texto = texto:match("^%s*(.-)%s*$")
    if texto == "" then
        return
    end
    texto = string.sub(texto, 1, LARGO_MAXIMO_NOMBRE)

    local anterior = territorio.nombre
    Territorios.renombrar(territorio, texto)

    jugador:Say("Territorio renombrado: " .. texto)
    print("[WorldQuest] Territorio renombrado: " .. anterior .. " -> " .. texto)
end

local function renombrarTerritorio(jugador, territorio)
    local ancho, alto = 280, 180
    local x = (getCore():getScreenWidth() - ancho) / 2
    local y = (getCore():getScreenHeight() - alto) / 2

    local ventana = ISTextBox:new(x, y, ancho, alto, "Nombre del territorio:", territorio.nombre,
        nil, alConfirmarNombre, jugador:getPlayerNum(), jugador, territorio)
    ventana:initialise()
    ventana:addToUIManager()
end

local function onFillWorldObjectContextMenu(numJugador, context, worldobjects, test)
    local jugador = getSpecificPlayer(numJugador)
    local x = math.floor(jugador:getX())
    local y = math.floor(jugador:getY())

    -- Dentro de un territorio: mostrar cual es, renombrar o abandonar
    local actual = Territorios.buscarEn(x, y)
    if actual then
        local info = context:addOption("Territorio actual: " .. actual.nombre, nil, nil)
        info.notAvailable = true
        context:addOption("Renombrar territorio", jugador, renombrarTerritorio, actual)
        context:addOption("Abandonar territorio", jugador, abandonarTerritorio, actual)
        return
    end

    -- Fuera, pero el territorio nuevo chocaria con otro
    local cercano = Territorios.buscarSuperpuesto(x, y, RADIO_INICIAL)
    if cercano then
        local opcion = context:addOption("Reclamar territorio (cerca de " .. cercano.nombre .. ")", nil, nil)
        opcion.notAvailable = true
        return
    end

    context:addOption("Reclamar territorio", jugador, reclamarTerritorio)
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
