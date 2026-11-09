-- WorldQuest - Nombre y resaltado de los almacenes (cliente)
-- El nombre se ve en la ventana de botin para todos; el resaltado solo lo ve el dueno.
-- El resaltado de Zomboid es por jugador: solo lo ve quien lo activa.

WorldQuest = WorldQuest or {}
WorldQuest.Resaltado = WorldQuest.Resaltado or {}

local Resaltado = WorldQuest.Resaltado
local Almacen = WorldQuest.Almacen

local function color()
    if not Resaltado.color then
        local ok, c = pcall(function() return ColorInfo.new(0.85, 0.55, 0.2, 1) end)
        if ok and c then
            Resaltado.color = c
        else
            Resaltado.color = getCore():getWorldItemHighlightColor()
        end
    end
    return Resaltado.color
end

function Resaltado.esDueno(territorio, jugador)
    return WorldQuest.Territorios.esDueno(territorio, jugador)
end

function Resaltado.aplicar(objeto, numJugador, activo)
    objeto:setHighlighted(numJugador, activo, false)
    objeto:setOutlineHighlight(numJugador, activo)
    if activo then
        objeto:setHighlightColor(numJugador, color())
        objeto:setOutlineHighlightCol(numJugador, color())
    end
end

local function ponerNombre(objeto, nombre)
    for c = 0, objeto:getContainerCount() - 1 do
        objeto:getContainerByIndex(c):setCustomName(nombre)
    end
end

-- Al dejar de ser almacen: sin resaltado y sin nombre
function Resaltado.limpiar(objeto)
    local jugador = getPlayer()
    if jugador then
        Resaltado.aplicar(objeto, jugador:getPlayerNum(), false)
    end
    for c = 0, objeto:getContainerCount() - 1 do
        local contenedor = objeto:getContainerByIndex(c)
        pcall(function() contenedor:setCustomName(nil) end)
    end
end

-- Cada minuto de juego: se vuelve a aplicar (los muebles se recargan al alejarse)
function Resaltado.actualizar()
    if isServer() then
        return
    end
    local jugador = getPlayer()
    if not jugador then
        return
    end
    local numJugador = jugador:getPlayerNum()
    for _, territorio in ipairs(WorldQuest.Territorios.getDatos().lista) do
        local dueno = Resaltado.esDueno(territorio, jugador)
        for _, objeto in ipairs(Almacen.objetos(territorio)) do
            local nombre = objeto:getModData()[Almacen.CLAVE_NOMBRE]
                or getText("IGUI_WQ_AlmacenNombreDefecto", territorio.nombre)
            ponerNombre(objeto, nombre)
            if dueno then
                Resaltado.aplicar(objeto, numJugador, true)
            end
        end
    end
end

Events.EveryOneMinute.Add(Resaltado.actualizar)
