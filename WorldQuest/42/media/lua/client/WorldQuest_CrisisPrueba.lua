-- WorldQuest - Crisis: opciones de prueba en el clic derecho (cliente)
-- Sirve para probar sin esperar dias. Desactivar con MODO_PRUEBA = false

local MODO_PRUEBA = true
local TIPOS = { "horda", "incendio", "comida", "tormenta" }

local function forzarCrisis(territorio, idTipo)
    WorldQuest.Crisis.programar(idTipo, territorio, true)
    WorldQuest.Crisis.procesarPendientes()
end

local function onFillWorldObjectContextMenu(numJugador, context, worldobjects, test)
    if not MODO_PRUEBA or not WorldQuest.Crisis then
        return
    end

    local jugador = getSpecificPlayer(numJugador)
    local territorio = WorldQuest.Territorios.buscarEn(math.floor(jugador:getX()), math.floor(jugador:getY()))
    if not territorio then
        return
    end

    local opcion = context:addOption(getText("ContextMenu_WQ_ProbarCrisis"))
    local submenu = ISContextMenu:getNew(context)
    context:addSubMenu(opcion, submenu)

    for _, idTipo in ipairs(TIPOS) do
        submenu:addOption(getText("IGUI_WQ_Crisis_" .. idTipo), territorio, forzarCrisis, idTipo)
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
