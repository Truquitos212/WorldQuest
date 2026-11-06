-- WorldQuest - Territorios: datos y logica base

WorldQuest = WorldQuest or {}
WorldQuest.Territorios = WorldQuest.Territorios or {}

local Territorios = WorldQuest.Territorios
local CLAVE_DATOS = "WorldQuest_Territorios"

local migrado = false

-- Devuelve los datos guardados en la partida (los crea si no existen)
function Territorios.getDatos()
    local datos = ModData.getOrCreate(CLAVE_DATOS)
    datos.lista = datos.lista or {}
    datos.contador = datos.contador or #datos.lista
    datos.siguienteId = datos.siguienteId or 1

    -- Una vez por carga: da id a los territorios creados antes de que existieran
    if not migrado then
        for _, territorio in ipairs(datos.lista) do
            if not territorio.id then
                territorio.id = datos.siguienteId
                datos.siguienteId = datos.siguienteId + 1
            end
        end
        migrado = true
    end

    return datos
end

-- Crea un territorio circular, lo guarda y avanza el contador
function Territorios.crear(nombre, x, y, radio)
    local datos = Territorios.getDatos()
    local territorio = {
        id = datos.siguienteId,
        nombre = nombre,
        x = x,
        y = y,
        radio = radio,
    }
    datos.siguienteId = datos.siguienteId + 1
    datos.contador = datos.contador + 1
    table.insert(datos.lista, territorio)
    return territorio
end

-- Nombre sugerido para el proximo territorio (no avanza el contador)
function Territorios.nombreSugerido()
    return getText("IGUI_WQ_NombreSugerido", tostring(Territorios.getDatos().contador + 1))
end

-- Cambia el nombre de un territorio
function Territorios.renombrar(territorio, nombre)
    territorio.nombre = nombre
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

-- true si el territorio sigue guardado (no fue abandonado)
function Territorios.existe(territorio)
    for _, t in ipairs(Territorios.getDatos().lista) do
        if t == territorio then
            return true
        end
    end
    return false
end

-- Busca un territorio por su id, o nil si ya no existe
function Territorios.buscarPorId(id)
    for _, territorio in ipairs(Territorios.getDatos().lista) do
        if territorio.id == id then
            return territorio
        end
    end
    return nil
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
