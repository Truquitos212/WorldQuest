-- WorldQuest - Niveles de asentamiento

require "WorldQuest_Territorios"
require "WorldQuest_Almacen"
require "WorldQuest_Colonos"
require "WorldQuest_Recursos"

WorldQuest = WorldQuest or {}
WorldQuest.Niveles = WorldQuest.Niveles or {}

local Niveles = WorldQuest.Niveles

Niveles.LISTA = {
    { id = "refugio",      radio = 20, cupoMax = 3 },
    { id = "campamento",   radio = 30, cupoMax = 5,  colonos = 2, costo = { madera = 20,  metal = 4 } },
    { id = "asentamiento", radio = 40, cupoMax = 8,  colonos = 4, costo = { madera = 110, metal = 12, comida = 3000 } },
    { id = "fortaleza",    radio = 50, cupoMax = 12, colonos = 7, costo = { madera = 220, metal = 30, medicina = 10, municion = 40 } },
}


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

-- "20 madera, 4 metal, 2 colonos"
function Niveles.textoCosto(costo, colonos)
    local texto = WorldQuest.Recursos.texto(costo or {})
    if colonos then
        local extra = colonos .. " " .. getText("IGUI_WQ_Recurso_colonos")
        texto = (texto ~= "" and (texto .. ", ") or "") .. extra
    end
    return texto
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

    if not WorldQuest.Almacen.alcanza(WorldQuest.Almacen.contar(t), siguiente.costo) then
        return false, getText("IGUI_WQ_FaltanRecursos")
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
