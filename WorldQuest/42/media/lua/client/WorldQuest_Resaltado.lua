-- WorldQuest - Resaltado de almacenes, solo para el dueno del territorio (cliente)
-- El resaltado de Zomboid es por jugador: solo lo ve quien lo activa

WorldQuest = WorldQuest or {}
WorldQuest.Resaltado = WorldQuest.Resaltado or {}

local Resaltado = WorldQuest.Resaltado

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

-- Los territorios antiguos (sin dueno) pasan a ser del primer jugador que los revise
function Resaltado.esDueno(territorio, jugador)
    local usuario = jugador:getUsername()
    if territorio.dueno == nil then
        territorio.dueno = usuario
    end
    return territorio.dueno == usuario
end

function Resaltado.aplicar(objeto, numJugador, activo)
    objeto:setHighlighted(numJugador, activo, false)
    objeto:setOutlineHighlight(numJugador, activo)
    if activo then
        objeto:setHighlightColor(numJugador, color())
        objeto:setOutlineHighlightCol(numJugador, color())
    end
end

-- Cada minuto de juego: se vuelve a aplicar (los muebles se recargan al alejarse)
local function actualizar()
    local jugador = getPlayer()
    if not jugador then
        return
    end
    local numJugador = jugador:getPlayerNum()
    for _, territorio in ipairs(WorldQuest.Territorios.getDatos().lista) do
        if Resaltado.esDueno(territorio, jugador) then
            for _, objeto in ipairs(WorldQuest.Almacen.objetos(territorio)) do
                Resaltado.aplicar(objeto, numJugador, true)
            end
        end
    end
end

Events.EveryOneMinute.Add(actualizar)
