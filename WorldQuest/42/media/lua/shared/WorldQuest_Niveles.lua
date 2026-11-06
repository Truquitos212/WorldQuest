-- WorldQuest - Niveles de asentamiento

require "WorldQuest_Territorios"
require "WorldQuest_Almacen"
require "WorldQuest_Colonos"

WorldQuest = WorldQuest or {}
WorldQuest.Niveles = WorldQuest.Niveles or {}

local Niveles = WorldQuest.Niveles

Niveles.LISTA = {
    { id = "refugio",      radio = 20, cupoMax = 3 },
    { id = "campamento",   radio = 30, cupoMax = 5,  colonos = 2, costo = { tablas = 20,  clavos = 40 } },
    { id = "asentamiento", radio = 40, cupoMax = 8,  colonos = 4, costo = { tablas = 50,  clavos = 100, troncos = 20 } },
    { id = "fortaleza",    radio = 50, cupoMax = 12, colonos = 7, costo = { tablas = 100, clavos = 200, troncos = 40 } },
}

local ORDEN_RECURSOS = { "tablas", "clavos", "troncos" }

function Niveles.datos(t)
    return Niveles.LISTA[t.nivel or 1]
end

function Niveles.siguiente(t)
    return Niveles.LISTA[(t.nivel or 1) + 1]
end

function Niveles.nombre(datos)
    return getText("IGUI_WQ_Nivel_" .. datos.id)
end

-- "base (Campamento)"
function Niveles.titulo(t)
    return t.nombre .. " (" .. Niveles.nombre(Niveles.datos(t)) .. ")"
end

-- "20 tablas, 40 clavos, 2 colonos"
function Niveles.textoCosto(costo, colonos)
    local partes = {}
    for _, recurso in ipairs(ORDEN_RECURSOS) do
        if costo[recurso] then
            table.insert(partes, costo[recurso] .. " " .. getText("IGUI_WQ_Recurso_" .. recurso))
        end
    end
    if colonos then
        table.insert(partes, colonos .. " " .. getText("IGUI_WQ_Recurso_colonos"))
    end
    return table.concat(partes, ", ")
end

-- true, o false y el motivo
function Niveles.puedeMejorar(t)
    local siguiente = Niveles.siguiente(t)
    if not siguiente then
        return false, getText("IGUI_WQ_NivelMaximo")
    end

    if #WorldQuest.Colonos.delTerritorio(t) < siguiente.colonos then
        return false, getText("IGUI_WQ_FaltanColonos", tostring(siguiente.colonos))
    end

    local recursos = WorldQuest.Almacen.contar(t)
    for recurso, cantidad in pairs(siguiente.costo) do
        if (recursos[recurso] or 0) < cantidad then
            return false, getText("IGUI_WQ_FaltanRecursos")
        end
    end

    -- El circulo mas grande no puede chocar con otro territorio
    for _, otro in ipairs(WorldQuest.Territorios.getDatos().lista) do
        if otro ~= t then
            local dx = otro.x - t.x
            local dy = otro.y - t.y
            local minimo = siguiente.radio + otro.radio
            if dx * dx + dy * dy < minimo * minimo then
                return false, getText("IGUI_WQ_SinEspacio", otro.nombre)
            end
        end
    end

    return true
end

function Niveles.mejorar(t)
    if not Niveles.puedeMejorar(t) then
        return false
    end
    local siguiente = Niveles.siguiente(t)
    WorldQuest.Almacen.gastar(t, siguiente.costo)
    t.nivel = (t.nivel or 1) + 1
    t.radio = siguiente.radio
    return true
end
