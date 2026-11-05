-- WorldQuest - Territorios: opcion en el menu de clic derecho (cliente)

WorldQuest = WorldQuest or {}

local Territorios = WorldQuest.Territorios
local RADIO_INICIAL = 20

local function reclamarTerritorio(jugador)
    local x = math.floor(jugador:getX())
    local y = math.floor(jugador:getY())
    local numero = #Territorios.getDatos().lista + 1
    local territorio = Territorios.crear("Territorio " .. numero, x, y, RADIO_INICIAL)

    jugador:Say("Territorio reclamado: " .. territorio.nombre)
    print("[WorldQuest] Territorio reclamado: " .. territorio.nombre .. " en " .. x .. ", " .. y)
end

local function onFillWorldObjectContextMenu(numJugador, context, worldobjects, test)
    local jugador = getSpecificPlayer(numJugador)
    local x = math.floor(jugador:getX())
    local y = math.floor(jugador:getY())
    local actual = Territorios.buscarEn(x, y)

    if actual then
        local opcion = context:addOption("Territorio actual: " .. actual.nombre, nil, nil)
        opcion.notAvailable = true
    else
        context:addOption("Reclamar territorio", jugador, reclamarTerritorio)
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
