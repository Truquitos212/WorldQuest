-- WorldQuest - Diplomacia: estados entre facciones, propuestas y reputacion (datos)
-- Estados: guerra, neutral, pacto (comercial) y alianza. Neutral es lo normal.
-- Los cambios los hace el servidor (server/WorldQuest_DiplomaciaServidor.lua).

WorldQuest = WorldQuest or {}
WorldQuest.Diplomacia = WorldQuest.Diplomacia or {}

local D = WorldQuest.Diplomacia
local CLAVE_DATOS = "WorldQuest_Diplomacia"

D.ESTADOS = { "guerra", "neutral", "pacto", "alianza" }
D.TIPOS_PROPUESTA = { "paz", "pacto", "alianza", "tributo" }
D.REPUTACION_INICIAL = 50
D.REPUTACION_MALA = 30          -- bajo esto, la faccion tiene mala fama
D.REPUTACION_INICIAL_DE = { carroneros = 35, devotos = 60 }

D.COLORES = {
    guerra = { 0.95, 0.35, 0.3 },
    neutral = { 0.8, 0.8, 0.8 },
    pacto = { 0.95, 0.8, 0.35 },
    alianza = { 0.45, 0.85, 0.45 },
}

function D.getDatos()
    local datos = ModData.getOrCreate(CLAVE_DATOS)
    datos.relaciones = datos.relaciones or {}
    datos.propuestas = datos.propuestas or {}
    datos.siguienteId = datos.siguienteId or 1
    return datos
end

local function llave(a, b)
    a, b = tonumber(a), tonumber(b)
    if a > b then
        a, b = b, a
    end
    return a .. "-" .. b
end
D.llave = llave

-- Relacion entre dos facciones (por id). Nunca nil.
function D.relacion(a, b)
    if a == nil or b == nil or a == b then
        return { estado = "alianza" }
    end
    return D.getDatos().relaciones[llave(a, b)] or { estado = "neutral" }
end

function D.estado(a, b)
    return D.relacion(a, b).estado
end

function D.enGuerra(a, b)
    return a ~= nil and b ~= nil and a ~= b and D.estado(a, b) == "guerra"
end

function D.aliados(a, b)
    return a ~= nil and b ~= nil and (a == b or D.estado(a, b) == "alianza")
end

-- Pacto comercial o alianza: pueden comerciar y sus caravanas no se atacan
function D.comercian(a, b)
    local e = D.estado(a, b)
    return e == "pacto" or e == "alianza"
end

-- Facciones en guerra con la dada
function D.enemigos(a)
    local lista = {}
    for _, f in ipairs(WorldQuest.Facciones.getDatos().lista) do
        if D.enGuerra(a, f.id) then
            table.insert(lista, f)
        end
    end
    return lista
end

function D.reputacion(f)
    if not f then
        return D.REPUTACION_INICIAL
    end
    if f.reputacion == nil then
        return D.REPUTACION_INICIAL_DE[f.tipo] or D.REPUTACION_INICIAL
    end
    return f.reputacion
end

function D.malaFama(f)
    return D.reputacion(f) < D.REPUTACION_MALA
end

-- Propuestas pendientes para una faccion
function D.propuestasPara(id)
    local lista = {}
    for _, p in ipairs(D.getDatos().propuestas) do
        if p.para == id then
            table.insert(lista, p)
        end
    end
    return lista
end

function D.nombreEstado(estado)
    return getText("IGUI_WQ_Estado_" .. tostring(estado))
end
