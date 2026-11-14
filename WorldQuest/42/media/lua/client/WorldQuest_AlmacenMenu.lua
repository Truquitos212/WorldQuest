-- WorldQuest - Almacen de la colonia: opciones en el clic derecho (cliente)
-- El cliente solo pregunta; el servidor marca, quita o renombra el mueble.
-- El nombre y el resaltado los aplica WorldQuest_Resaltado.lua en cada cliente.

WorldQuest = WorldQuest or {}

local Almacen = WorldQuest.Almacen
local Territorios = WorldQuest.Territorios
local Red = WorldQuest.Red

local function buscarMueble(worldobjects)
    for _, objeto in ipairs(worldobjects) do
        if Almacen.tieneContenedor(objeto) then
            return objeto
        end
    end
    return nil
end

-- Datos para que el servidor encuentre el mismo mueble
local function ubicacion(objeto, territorio)
    local casilla = objeto:getSquare()
    local sprite = objeto:getSprite()
    return {
        id = territorio and territorio.id or nil,
        x = casilla:getX(),
        y = casilla:getY(),
        z = casilla:getZ(),
        i = objeto:getObjectIndex(),
        sprite = sprite and sprite:getName() or nil,
    }
end

local function refrescar()
    if WorldQuest.Resaltado then
        WorldQuest.Resaltado.actualizar()
    end
end

local function marcarAlmacen(objeto, territorio)
    Red.pedir("marcarAlmacen", ubicacion(objeto, territorio))
    refrescar()
end

local function quitarAlmacen(objeto, territorio)
    Red.pedir("quitarAlmacen", ubicacion(objeto, territorio))
    if WorldQuest.Resaltado then
        WorldQuest.Resaltado.limpiar(objeto)
    end
end

local function alRenombrar(target, boton, objeto)
    if boton.internal ~= "OK" then
        return
    end
    local nombre = Territorios.limpiarNombre(boton.parent.entry:getText())
    if nombre then
        local args = ubicacion(objeto, nil)
        args.nombre = nombre
        Red.pedir("renombrarAlmacen", args)
        refrescar()
    end
end

local function renombrarAlmacen(objeto)
    local ancho, alto = 280, 180
    local x = (getCore():getScreenWidth() - ancho) / 2
    local y = (getCore():getScreenHeight() - alto) / 2
    local actual = objeto:getModData()[Almacen.CLAVE_NOMBRE] or ""
    local ventana = ISTextBox:new(x, y, ancho, alto, getText("IGUI_WQ_NombreAlmacen"), actual,
        nil, alRenombrar, getPlayer():getPlayerNum(), objeto)
    ventana:initialise()
    ventana:addToUIManager()
end

local function onFillWorldObjectContextMenu(numJugador, context, worldobjects, test)
    local mueble = buscarMueble(worldobjects)
    if not mueble then
        return
    end

    local casilla = mueble:getSquare()
    local territorio = Territorios.buscarEn(casilla:getX(), casilla:getY())
    if not territorio or not Territorios.esDueno(territorio, getSpecificPlayer(numJugador)) then
        return
    end

    if Almacen.territorioDe(mueble) == territorio.id then
        local r = Almacen.contar(territorio)
        local info1 = context:addOption(getText("ContextMenu_WQ_AlmacenComida", tostring(r.comidas), tostring(r.calorias)), nil, nil)
        info1.notAvailable = true
        local info2 = context:addOption(getText("ContextMenu_WQ_AlmacenRecursos", WorldQuest.Recursos.texto(r)), nil, nil)
        info2.notAvailable = true
        context:addOption(getText("ContextMenu_WQ_RenombrarAlmacen"), mueble, renombrarAlmacen)
        context:addOption(getText("ContextMenu_WQ_QuitarAlmacen"), mueble, quitarAlmacen, territorio)
    else
        context:addOption(getText("ContextMenu_WQ_MarcarAlmacen"), mueble, marcarAlmacen, territorio)
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
