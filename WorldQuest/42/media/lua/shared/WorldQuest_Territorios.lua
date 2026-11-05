-- WorldQuest - Territorios: datos y logica base

WorldQuest = WorldQuest or {}
WorldQuest.Territorios = WorldQuest.Territorios or {}

local Territorios = WorldQuest.Territorios
local CLAVE_DATOS = "WorldQuest_Territorios"

-- Devuelve los datos guardados en la partida (los crea si no existen)
function Territorios.getDatos()
    local datos = ModData.getOrCreate(CLAVE_DATOS)
    datos.lista = datos.lista or {}
    return datos
end

-- Crea un territorio circular y lo guarda
function Territorios.crear(nombre, x, y, radio)
    local territorio = {
        nombre = nombre,
        x = x,
        y = y,
        radio = radio,
    }
    table.insert(Territorios.getDatos().lista, territorio)
    return territorio
end

-- true si la posicion (x, y) esta dentro del territorio
function Territorios.contiene(territorio, x, y)
    local dx = x - territorio.x
    local dy = y - territorio.y
    return (dx * dx + dy * dy) <= (territorio.radio * territorio.radio)
end

-- Devuelve el territorio que contiene (x, y), o nil si no hay ninguno
function Territorios.buscarEn(x, y)
    for _, territorio in ipairs(Territorios.getDatos().lista) do
        if Territorios.contiene(territorio, x, y) then
            return territorio
        end
    end
    return nil
end
