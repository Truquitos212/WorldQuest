-- WorldQuest - Opcion de prueba: llenar el almacen con materiales (cliente)
-- Se activa con la opcion de partida Herramientas de prueba. Lo hace el servidor.

local function llenar(territorio)
    WorldQuest.Red.pedir("llenarAlmacen", { id = territorio.id })
end

local function onFillWorldObjectContextMenu(numJugador, context, worldobjects, test)
    if not WorldQuest.Opciones.pruebas() then
        return
    end
    local jugador = getSpecificPlayer(numJugador)
    local territorio = WorldQuest.Territorios.buscarEn(math.floor(jugador:getX()), math.floor(jugador:getY()))
    if territorio then
        context:addOption(getText("ContextMenu_WQ_ProbarLlenar"), territorio, llenar)
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
