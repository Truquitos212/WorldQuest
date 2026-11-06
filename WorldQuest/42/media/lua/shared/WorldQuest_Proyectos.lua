-- WorldQuest - Proyectos: obras que construyen los colonos

require "WorldQuest_Almacen"
require "WorldQuest_Niveles"
require "WorldQuest_Colonos"

WorldQuest = WorldQuest or {}
WorldQuest.Proyectos = WorldQuest.Proyectos or {}

local Proyectos = WorldQuest.Proyectos

Proyectos.LISTA = {
    { id = "torre",   costo = { tablas = 30, clavos = 30 },                trabajo = 3 },
    { id = "taller",  costo = { tablas = 20, clavos = 20 },                trabajo = 2 },
    { id = "muralla", costo = { tablas = 60, clavos = 80, troncos = 20 },  trabajo = 6, nivel = 2 },
    { id = "radio",   costo = { tablas = 15, clavos = 15 },                trabajo = 2, nivel = 2 },
}

function Proyectos.buscar(id)
    for _, proyecto in ipairs(Proyectos.LISTA) do
        if proyecto.id == id then
            return proyecto
        end
    end
    return nil
end

function Proyectos.nombre(id)
    return getText("IGUI_WQ_Proyecto_" .. id)
end

function Proyectos.construido(t, id)
    return t.mejoras ~= nil and t.mejoras[id] == true
end

-- true, o false y el motivo
function Proyectos.puedeIniciar(t, proyecto)
    if t.proyecto then
        return false, getText("IGUI_WQ_ProyectoOcupado")
    end
    if proyecto.nivel and (t.nivel or 1) < proyecto.nivel then
        local nivel = WorldQuest.Niveles.LISTA[proyecto.nivel]
        return false, getText("IGUI_WQ_ProyectoRequiereNivel", WorldQuest.Niveles.nombre(nivel))
    end
    local recursos = WorldQuest.Almacen.contar(t)
    for recurso, cantidad in pairs(proyecto.costo) do
        if (recursos[recurso] or 0) < cantidad then
            return false, getText("IGUI_WQ_FaltanRecursos")
        end
    end
    return true
end

function Proyectos.iniciar(t, proyecto)
    if not Proyectos.puedeIniciar(t, proyecto) then
        return false
    end
    WorldQuest.Almacen.gastar(t, proyecto.costo)
    t.proyecto = { id = proyecto.id, restante = proyecto.trabajo }
    return true
end

-- Trabajo que aportan los constructores del territorio en un dia
function Proyectos.trabajoDiario(t)
    local trabajo = 0
    for _, colono in ipairs(WorldQuest.Colonos.delTerritorio(t)) do
        if colono.rol == "constructor" then
            trabajo = trabajo + 1 + math.floor(colono.habilidades.construccion / 5)
        end
    end
    return trabajo
end
