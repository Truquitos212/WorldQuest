-- WorldQuest - Proyectos: obras que construyen los colonos

require "WorldQuest_Almacen"
require "WorldQuest_Niveles"
require "WorldQuest_Colonos"

WorldQuest = WorldQuest or {}
WorldQuest.Proyectos = WorldQuest.Proyectos or {}

local Proyectos = WorldQuest.Proyectos

Proyectos.LISTA = {
    -- tamano: lado en casillas de la silueta que se coloca en el mapa o en el mundo
    { id = "torre",   costo = { madera = 30, metal = 3 },               trabajo = 3, tamano = 2 },
    { id = "taller",  costo = { madera = 20, metal = 4 },               trabajo = 2, tamano = 3 },
    { id = "muralla", costo = { madera = 120, metal = 10 },             trabajo = 6, tamano = 1, nivel = 2 },
    { id = "radio",   costo = { madera = 15, metal = 8 },               trabajo = 2, tamano = 1, nivel = 2 },
    -- Para la victoria por Exodo
    { id = "helipuerto", costo = { madera = 150, metal = 60 },          trabajo = 8, tamano = 4, nivel = 3 },
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
    if not WorldQuest.Almacen.alcanza(WorldQuest.Almacen.contar(t), proyecto.costo) then
        return false, getText("IGUI_WQ_FaltanRecursos")
    end
    return true
end

function Proyectos.iniciar(t, proyecto)
    if not Proyectos.puedeIniciar(t, proyecto) then
        return false
    end
    WorldQuest.Almacen.gastar(t, proyecto.costo)
    -- La obra no avanza hasta que se elige su lugar (ordenes ubicarObra)
    t.proyecto = { id = proyecto.id, restante = proyecto.trabajo, sinUbicar = true }
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
    return WorldQuest.Modificadores.obras(t, trabajo)
end
