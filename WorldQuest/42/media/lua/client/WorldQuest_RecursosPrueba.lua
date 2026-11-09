-- WorldQuest - Opcion de prueba: llenar el almacen con materiales (cliente)
-- Se activa con la opcion de partida Herramientas de prueba

local CANTIDADES = {
    ["Base.Plank"] = 100,
    ["Base.Nails"] = 200,
    ["Base.Log"] = 40,
    ["Base.TinnedBeans"] = 20,
}

local function llenar(territorio)
    local mueble = WorldQuest.Almacen.objetos(territorio)[1]
    if not mueble then
        getPlayer():Say(getText("IGUI_WQ_SinAlmacen", territorio.nombre))
        return
    end
    local contenedor = mueble:getContainerByIndex(0)
    for tipo, cantidad in pairs(CANTIDADES) do
        for i = 1, cantidad do
            contenedor:AddItem(tipo)
        end
    end
    print("[WorldQuest] Almacen de prueba lleno en " .. territorio.nombre)
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
