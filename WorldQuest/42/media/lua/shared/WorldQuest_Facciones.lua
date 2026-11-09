-- WorldQuest - Facciones: datos compartidos
-- Cada jugador lidera o integra una faccion. Los territorios (y con ellos sus
-- colonos y almacenes) pertenecen a la faccion, no al jugador.
-- Los cambios los hace el servidor (server/WorldQuest_FaccionesServidor.lua).

WorldQuest = WorldQuest or {}
WorldQuest.Facciones = WorldQuest.Facciones or {}

local Facciones = WorldQuest.Facciones
local CLAVE_DATOS = "WorldQuest_Facciones"

-- Tipos de faccion (los efectos de cada uno llegan en la Fase 3B)
Facciones.TIPOS = { "leales", "comuna", "chatarreros", "caravana", "carroneros", "devotos", "moteros", "preppers", "fugados" }

Facciones.COLORES = {
    { id = "rojo",     r = 0.80, g = 0.22, b = 0.18 },
    { id = "azul",     r = 0.22, g = 0.45, b = 0.85 },
    { id = "verde",    r = 0.25, g = 0.68, b = 0.30 },
    { id = "amarillo", r = 0.92, g = 0.80, b = 0.20 },
    { id = "naranjo",  r = 0.92, g = 0.50, b = 0.15 },
    { id = "morado",   r = 0.58, g = 0.32, b = 0.75 },
    { id = "celeste",  r = 0.30, g = 0.78, b = 0.88 },
    { id = "gris",     r = 0.65, g = 0.65, b = 0.65 },
}

Facciones.EMBLEMAS = { "calavera", "lobo", "engranaje", "cruz", "llave", "estrella", "rosa", "ancla" }

local function contiene(lista, valor)
    for _, v in ipairs(lista) do
        if v == valor then
            return true
        end
    end
    return false
end

function Facciones.tipoValido(tipo)
    return contiene(Facciones.TIPOS, tipo)
end

function Facciones.emblemaValido(emblema)
    return contiene(Facciones.EMBLEMAS, emblema)
end

function Facciones.color(id)
    for _, c in ipairs(Facciones.COLORES) do
        if c.id == id then
            return c
        end
    end
    return nil
end

function Facciones.getDatos()
    local datos = ModData.getOrCreate(CLAVE_DATOS)
    datos.lista = datos.lista or {}
    datos.siguienteId = datos.siguienteId or 1
    return datos
end

function Facciones.porId(id)
    if id == nil then
        return nil
    end
    for _, f in ipairs(Facciones.getDatos().lista) do
        if f.id == id then
            return f
        end
    end
    return nil
end

-- Faccion de un usuario (o nil)
function Facciones.de(usuario)
    if not usuario then
        return nil
    end
    for _, f in ipairs(Facciones.getDatos().lista) do
        if f.miembros and f.miembros[usuario] then
            return f
        end
    end
    return nil
end

function Facciones.deJugador(jugador)
    return jugador and Facciones.de(jugador:getUsername()) or nil
end

function Facciones.porNombre(nombre)
    local buscado = string.lower(nombre or "")
    for _, f in ipairs(Facciones.getDatos().lista) do
        if string.lower(f.nombre) == buscado then
            return f
        end
    end
    return nil
end

-- Lista de miembros, el lider primero
function Facciones.miembros(f)
    local lista = { f.lider }
    local otros = {}
    for usuario, _ in pairs(f.miembros or {}) do
        if usuario ~= f.lider then
            table.insert(otros, usuario)
        end
    end
    table.sort(otros)
    for _, usuario in ipairs(otros) do
        table.insert(lista, usuario)
    end
    return lista
end

function Facciones.cantidadMiembros(f)
    local n = 0
    for _, _ in pairs(f.miembros or {}) do
        n = n + 1
    end
    return n
end

-- Faccion duena de un territorio (o nil si es un territorio antiguo sin faccion)
function Facciones.deTerritorio(t)
    return t and Facciones.porId(t.faccion) or nil
end

-- Nombre para mostrar del dueno de un territorio: la faccion, o el jugador que lo reclamo
function Facciones.nombreDueno(t)
    local f = Facciones.deTerritorio(t)
    if f then
        return f.nombre
    end
    return tostring(t.dueno or "?")
end

-- Color { r, g, b } de un territorio, o nil si no tiene faccion
function Facciones.colorTerritorio(t)
    local f = Facciones.deTerritorio(t)
    return f and Facciones.color(f.color) or nil
end

-- Jugador conectado que responde por el territorio: el lider, si no otro miembro
function Facciones.responsable(t)
    local Red = WorldQuest.Red
    local f = Facciones.deTerritorio(t)
    if not f then
        return Red.jugador(t.dueno)
    end
    for _, usuario in ipairs(Facciones.miembros(f)) do
        local jugador = Red.jugador(usuario)
        if jugador then
            return jugador
        end
    end
    return nil
end

function Facciones.nombreTipo(tipo)
    return getText("IGUI_WQ_Faccion_" .. tostring(tipo))
end
