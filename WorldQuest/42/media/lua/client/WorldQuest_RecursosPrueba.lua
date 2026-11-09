-- WorldQuest - Opcion de prueba: llenar el almacen con materiales (cliente)
-- Desactivar con MODO_PRUEBA = false

local MODO_PRUEBA = true

local CANTIDADES = {
    ["Base.Plank"] = 100,
    ["Base.Nails"] = 200,
    ["Base.Log"] = 40,
    ["Base.TinnedBeans"] = 20,
}

local function llenar(territorio)
    local mueble = WorldQuest.Almacen.objetos(territorio)[1]
    if not mueble then
        getPlayer():Say("No hay almacen cargado en " .. territorio.nombre)
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
    if not MODO_PRUEBA then
        return
    end
    local jugador = getSpecificPlayer(numJugador)
    local territorio = WorldQuest.Territorios.buscarEn(math.floor(jugador:getX()), math.floor(jugador:getY()))
    if territorio then
        context:addOption("[Prueba] Llenar almacen", territorio, llenar)
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
