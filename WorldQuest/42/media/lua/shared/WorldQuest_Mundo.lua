-- WorldQuest - Mundo: puntos de interes de cada ciudad (datos)
-- Los descubren los jugadores al pasar cerca (el cliente reconoce el tipo de edificio
-- por el nombre de sus habitaciones). El primero de cada tipo en cada ciudad queda
-- fijo para toda la partida. Los controla la faccion que tenga un territorio encima.

WorldQuest = WorldQuest or {}
WorldQuest.Mundo = WorldQuest.Mundo or {}

local Mundo = WorldQuest.Mundo
local CLAVE_DATOS = "WorldQuest_Mundo"

-- Tipos de lugar: partes del nombre de habitacion que los delatan, lo que dan por
-- ciclo al que los controla y sus puntos
Mundo.TIPOS = {
    { id = "comisaria",    nombres = { "police" },                                   da = { municion = 8 },               puntos = 3 },
    { id = "hospital",     nombres = { "hospital", "medical", "clinic", "pharmac" },  da = { medicina = 3 },                puntos = 3 },
    { id = "supermercado", nombres = { "grocer", "gigamart", "supermarket", "conveniencestore" }, da = { comida = 1200 }, puntos = 2 },
    { id = "ferreteria",   nombres = { "toolstore", "hardware", "lumber", "sawmill" }, da = { madera = 4, metal = 3 },     puntos = 2 },
    { id = "escuela",      nombres = { "classroom", "school", "church", "chapel" },  da = {},                             puntos = 2, colonos = true },
    { id = "radio",        nombres = { "radio" },                                     da = {},                             puntos = 4, revela = true, exodo = true },
    { id = "militar",      nombres = { "army", "military" },                          da = { municion = 20 },              puntos = 6, exodo = true },
}

Mundo.BONO_CIUDAD = 1.5        -- lo que producen los lugares si controlas todos los de la ciudad
Mundo.MINIMO_CIUDAD = 2        -- lugares que necesita una ciudad para tener bono

function Mundo.tipo(id)
    for _, t in ipairs(Mundo.TIPOS) do
        if t.id == id then
            return t
        end
    end
    return nil
end

-- Tipo de lugar segun el nombre de una habitacion (o nil)
function Mundo.tipoDeHabitacion(nombre)
    if type(nombre) ~= "string" then
        return nil
    end
    nombre = string.lower(nombre)
    for _, t in ipairs(Mundo.TIPOS) do
        for _, parte in ipairs(t.nombres) do
            if string.find(nombre, parte, 1, true) then
                return t
            end
        end
    end
    return nil
end

function Mundo.getDatos()
    local datos = ModData.getOrCreate(CLAVE_DATOS)
    datos.lugares = datos.lugares or {}
    datos.siguienteId = datos.siguienteId or 1
    return datos
end

-- Faccion que controla un lugar: la duena del territorio que lo cubre (o nil)
function Mundo.controlador(lugar)
    local t = WorldQuest.Territorios.buscarEn(lugar.x, lugar.y)
    if t then
        return WorldQuest.Facciones.deTerritorio(t), t
    end
    return nil, nil
end

-- Lugares de una ciudad
function Mundo.deCiudad(pueblo)
    local lista = {}
    for _, l in ipairs(Mundo.getDatos().lugares) do
        if l.pueblo == pueblo then
            table.insert(lista, l)
        end
    end
    return lista
end

-- true si la faccion controla todos los lugares de la ciudad (y son suficientes)
function Mundo.tieneCiudad(f, pueblo)
    if not f then
        return false
    end
    local lugares = Mundo.deCiudad(pueblo)
    if #lugares < Mundo.MINIMO_CIUDAD then
        return false
    end
    for _, l in ipairs(lugares) do
        local duena = Mundo.controlador(l)
        if not duena or duena.id ~= f.id then
            return false
        end
    end
    return true
end

-- Lugares que controla una faccion
function Mundo.deFaccion(f)
    local lista = {}
    if not f then
        return lista
    end
    for _, l in ipairs(Mundo.getDatos().lugares) do
        local duena = Mundo.controlador(l)
        if duena and duena.id == f.id then
            table.insert(lista, l)
        end
    end
    return lista
end

-- true si la faccion controla algun lugar de ese tipo
function Mundo.controlaTipo(f, idTipo)
    for _, l in ipairs(Mundo.deFaccion(f)) do
        if l.tipo == idTipo then
            return true
        end
    end
    return false
end

-- Lugar ya conocido de ese tipo cerca de un punto (o nil)
function Mundo.cercano(idTipo, x, y, radio)
    for _, l in ipairs(Mundo.getDatos().lugares) do
        if l.tipo == idTipo and (l.x - x) ^ 2 + (l.y - y) ^ 2 <= radio * radio then
            return l
        end
    end
    return nil
end

function Mundo.nombreTipo(id)
    return getText("IGUI_WQ_Lugar_" .. tostring(id))
end
