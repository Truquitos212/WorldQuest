-- WorldQuest - Territorios: datos y logica base

WorldQuest = WorldQuest or {}
WorldQuest.Territorios = WorldQuest.Territorios or {}

local Territorios = WorldQuest.Territorios
local CLAVE_DATOS = "WorldQuest_Territorios"

-- Devuelve los datos guardados en la partida (los crea si no existen)
function Territorios.getDatos()
    local datos = ModData.getOrCreate(CLAVE_DATOS)
    datos.lista = datos.lista or {}
    datos.contador = datos.contador or #datos.lista
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

-- Siguiente nombre automatico, sin repetir aunque se borren territorios
function Territorios.siguienteNombre()
    local datos = Territorios.getDatos()
    datos.contador = datos.contador + 1
    return "Territorio " .. datos.contador
end

-- Quita un territorio de la lista
function Territorios.eliminar(territorio)
    local lista = Territorios.getDatos().lista
    for i = #lista, 1, -1 do
        if lista[i] == territorio then
            table.remove(lista, i)
            return true
        end
    end
    return false
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

-- Devuelve el primer territorio que chocaria con un circulo nuevo, o nil
function Territorios.buscarSuperpuesto(x, y, radio)
    for _, territorio in ipairs(Territorios.getDatos().lista) do
        local dx = x - territorio.x
        local dy = y - territorio.y
        local distanciaMinima = radio + territorio.radio
        if (dx * dx + dy * dy) < (distanciaMinima * distanciaMinima) then
            return territorio
        end
    end
    return nil
end

-- Cambia el nombre de un territorio
function Territorios.renombrar(territorio, nombre)
    territorio.nombre = nombre
end
