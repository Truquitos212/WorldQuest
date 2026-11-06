-- WorldQuest - Proyectos y estructuras: avance diario

require "WorldQuest_Crisis"

local Territorios = WorldQuest.Territorios
local Proyectos = WorldQuest.Proyectos
local Estructuras = WorldQuest.Estructuras
local Crisis = WorldQuest.Crisis

local function alPasarDia()
    for _, t in ipairs(Territorios.getDatos().lista) do
        Estructuras.actualizar(t)

        if t.proyecto then
            t.proyecto.restante = t.proyecto.restante - Proyectos.trabajoDiario(t)
            if t.proyecto.restante <= 0 then
                local id = t.proyecto.id
                t.mejoras = t.mejoras or {}
                t.mejoras[id] = true
                t.proyecto = nil
                Crisis.avisar(getText("IGUI_WQ_ProyectoTerminado", Proyectos.nombre(id), t.nombre), "aviso")
            end
        end
    end
end

Events.EveryDays.Add(alPasarDia)
