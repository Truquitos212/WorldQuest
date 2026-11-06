-- WorldQuest - Crisis: opciones de prueba en el clic derecho (cliente)
-- Sirve para probar sin esperar dias. Desactivar con MODO_PRUEBA = false

local MODO_PRUEBA = true
local TIPOS = { "horda", "incendio", "comida", "tormenta" }

local function probarAhora(territorio, idTipo)
    WorldQuest.Crisis.programar(idTipo, territorio, true)
    WorldQuest.Crisis.procesarPendientes()
end

local function probarConAviso(territorio, idTipo)
    WorldQuest.Crisis.programar(idTipo, territorio, false)
end

local function agregarSubmenu(context, menuPadre, titulo, territorio, funcion)
    local opcion = menuPadre:addOption(titulo)
    local submenu = ISContextMenu:getNew(context)
    menuPadre:addSubMenu(opcion, submenu)
    for _, idTipo in ipairs(TIPOS) do
        submenu:addOption(getText("IGUI_WQ_Crisis_" .. idTipo), territorio, funcion, idTipo)
    end
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
    local menuCrisis = ISContextMenu:getNew(context)
    context:addSubMenu(opcion, menuCrisis)

    agregarSubmenu(context, menuCrisis, getText("ContextMenu_WQ_ProbarAhora"), territorio, probarAhora)
    agregarSubmenu(context, menuCrisis, getText("ContextMenu_WQ_ProbarConAviso"), territorio, probarConAviso)
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
