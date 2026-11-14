-- WorldQuest - Herramientas de prueba (cliente): submenu [Prueba] en el clic derecho
-- Solo aparece con la opcion de partida Herramientas de prueba.

local Red = WorldQuest.Red

local OPCIONES = {
    { "IGUI_WQ_Prueba_Mercenarios", "probarMercenarios", {} },
    { "IGUI_WQ_Prueba_MercenariosHostiles", "probarMercenarios", { simpatia = 5 } },
    { "IGUI_WQ_Prueba_Evacuacion", "probarEvacuacion", {} },
    { "IGUI_WQ_Prueba_Tiempo", "probarTiempo", {} },
    { "IGUI_WQ_Prueba_Amenaza", "probarAmenaza", {} },
}

local function onFillWorldObjectContextMenu(numJugador, context, worldobjects, test)
    if not WorldQuest.Opciones.pruebas() then
        return
    end
    local opcion = context:addOption(getText("IGUI_WQ_Prueba_Menu"))
    local sub = ISContextMenu:getNew(context)
    context:addSubMenu(opcion, sub)
    for _, o in ipairs(OPCIONES) do
        sub:addOption(getText(o[1]), o[2], function(orden) Red.pedir(orden, o[3]) end)
    end
    local lugar = sub:addOption(getText("IGUI_WQ_Prueba_Lugar"))
    local subLugar = ISContextMenu:getNew(sub)
    sub:addSubMenu(lugar, subLugar)
    for _, tipo in ipairs(WorldQuest.Mundo.TIPOS) do
        subLugar:addOption(WorldQuest.Mundo.nombreTipo(tipo.id), tipo.id, function(id) Red.pedir("probarLugar", { tipo = id }) end)
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
