-- WorldQuest - Almacen de la colonia: opciones en el clic derecho (cliente)

WorldQuest = WorldQuest or {}

local Almacen = WorldQuest.Almacen
local Territorios = WorldQuest.Territorios
local LARGO_MAXIMO = 30
local CLAVE_NOMBRE = "WQ_AlmacenNombre"

local function buscarMueble(worldobjects)
    for _, objeto in ipairs(worldobjects) do
        if Almacen.tieneContenedor(objeto) then
            return objeto
        end
    end
    return nil
end

-- El nombre se guarda en el mueble y en sus contenedores (sale en la ventana de botin)
local function ponerNombre(objeto, nombre)
    objeto:getModData()[CLAVE_NOMBRE] = nombre
    for c = 0, objeto:getContainerCount() - 1 do
        objeto:getContainerByIndex(c):setCustomName(nombre)
    end
end

local function quitarNombre(objeto)
    objeto:getModData()[CLAVE_NOMBRE] = nil
    for c = 0, objeto:getContainerCount() - 1 do
        local contenedor = objeto:getContainerByIndex(c)
        pcall(function() contenedor:setCustomName(nil) end)
    end
end

local function resaltar(objeto, activo)
    if WorldQuest.Resaltado then
        WorldQuest.Resaltado.aplicar(objeto, getPlayer():getPlayerNum(), activo)
    end
end

local function marcarAlmacen(objeto, territorio)
    Almacen.marcar(objeto, territorio)
    ponerNombre(objeto, getText("IGUI_WQ_AlmacenNombreDefecto", territorio.nombre))
    resaltar(objeto, true)
    print("[WorldQuest] Almacen marcado en " .. territorio.nombre)
end

local function quitarAlmacen(objeto, territorio)
    Almacen.desmarcar(objeto, territorio)
    quitarNombre(objeto)
    resaltar(objeto, false)
    print("[WorldQuest] Almacen quitado de " .. territorio.nombre)
end

local function alRenombrar(target, boton, objeto)
    if boton.internal ~= "OK" then
        return
    end
    local texto = boton.parent.entry:getText():match("^%s*(.-)%s*$")
    if texto == "" then
        return
    end
    ponerNombre(objeto, string.sub(texto, 1, LARGO_MAXIMO))
end

local function renombrarAlmacen(objeto)
    local ancho, alto = 280, 180
    local x = (getCore():getScreenWidth() - ancho) / 2
    local y = (getCore():getScreenHeight() - alto) / 2
    local actual = objeto:getModData()[CLAVE_NOMBRE] or ""
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
    if not territorio then
        return
    end

    if Almacen.territorioDe(mueble) == territorio.id then
        local r = Almacen.contar(territorio)
        local info1 = context:addOption(getText("ContextMenu_WQ_AlmacenComida", tostring(r.comidas), tostring(r.calorias)), nil, nil)
        info1.notAvailable = true
        local info2 = context:addOption(getText("ContextMenu_WQ_AlmacenMateriales", tostring(r.tablas), tostring(r.clavos), tostring(r.troncos)), nil, nil)
        info2.notAvailable = true
        context:addOption(getText("ContextMenu_WQ_RenombrarAlmacen"), mueble, renombrarAlmacen)
        context:addOption(getText("ContextMenu_WQ_QuitarAlmacen"), mueble, quitarAlmacen, territorio)
    else
        context:addOption(getText("ContextMenu_WQ_MarcarAlmacen"), mueble, marcarAlmacen, territorio)
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
