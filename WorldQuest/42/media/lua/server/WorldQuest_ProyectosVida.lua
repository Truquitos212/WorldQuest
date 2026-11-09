-- WorldQuest - Proyectos y estructuras: avance por ciclo

require "WorldQuest_Crisis"

local Territorios = WorldQuest.Territorios
local Proyectos = WorldQuest.Proyectos
local Estructuras = WorldQuest.Estructuras
local Crisis = WorldQuest.Crisis

local function alPasarCiclo()
    for _, t in ipairs(Territorios.getDatos().lista) do
        Estructuras.actualizar(t)

        if t.proyecto then
            t.proyecto.restante = t.proyecto.restante - Proyectos.trabajoDiario(t)
            if t.proyecto.restante <= 0 then
                local id = t.proyecto.id
                t.mejoras = t.mejoras or {}
                t.mejoras[id] = true
                t.proyecto = nil
                WorldQuest.Red.avisar("IGUI_WQ_ProyectoTerminado", { { clave = "IGUI_WQ_Proyecto_" .. id }, t.nombre }, "aviso")
            end
        end
    end
end

WorldQuest.Reloj.alCiclo(alPasarCiclo)
