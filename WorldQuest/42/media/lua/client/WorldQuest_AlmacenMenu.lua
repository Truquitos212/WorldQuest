-- WorldQuest - Almacen de la colonia: opciones en el clic derecho (cliente)

WorldQuest = WorldQuest or {}

local Almacen = WorldQuest.Almacen
local Territorios = WorldQuest.Territorios

-- Primer objeto con contenedor entre los objetos del clic
local function buscarMueble(worldobjects)
    for _, objeto in ipairs(worldobjects) do
        if Almacen.tieneContenedor(objeto) then
            return objeto
        end
    end
    return nil
end

local function marcarAlmacen(objeto, territorio)
    Almacen.marcar(objeto, territorio)
    print("[WorldQuest] Almacen marcado en " .. territorio.nombre)
end

local function quitarAlmacen(objeto, territorio)
    Almacen.desmarcar(objeto, territorio)
    print("[WorldQuest] Almacen quitado de " .. territorio.nombre)
end

local function onFillWorldObjectContextMenu(numJugador, context, worldobjects, test)
    local mueble = buscarMueble(worldobjects)
    if not mueble then
        return
    end

    -- El territorio se busca por la posicion del mueble, no del jugador
    local casilla = mueble:getSquare()
    local territorio = Territorios.buscarEn(casilla:getX(), casilla:getY())
    if not territorio then
        return
    end

    if Almacen.territorioDe(mueble) == territorio.id then
        local r = Almacen.contar(territorio)
        local info1 = context:addOption(getText("ContextMenu_WQ_AlmacenComida", tostring(r.comidas), tostring(r.calorias)), nil, nil)
        info1.notAvailable = true
        local info2 = context:addOption(getText("ContextMenu_WQ_AlmacenMateriales", tostring(r.tablas), tostring(r.clavos), tostring(r.troncos)), nil, nil)
        info2.notAvailable = true
        context:addOption(getText("ContextMenu_WQ_QuitarAlmacen"), mueble, quitarAlmacen, territorio)
    else
        context:addOption(getText("ContextMenu_WQ_MarcarAlmacen"), mueble, marcarAlmacen, territorio)
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
