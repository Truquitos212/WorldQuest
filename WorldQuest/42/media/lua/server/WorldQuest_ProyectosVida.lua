-- WorldQuest - Proyectos y estructuras: avance por ciclo

require "WorldQuest_Crisis"

local Territorios = WorldQuest.Territorios
local Proyectos = WorldQuest.Proyectos
local Estructuras = WorldQuest.Estructuras
local Crisis = WorldQuest.Crisis

local function alPasarCiclo()
    for _, t in ipairs(Territorios.getDatos().lista) do
        Estructuras.actualizar(t)

        if t.proyecto and not t.proyecto.sinUbicar then
            t.proyecto.restante = t.proyecto.restante - Proyectos.trabajoDiario(t)
            if t.proyecto.restante <= 0 then
                local id = t.proyecto.id
                t.mejoras = t.mejoras or {}
                t.mejoras[id] = true
                -- Donde quedo la obra (para dibujarla en el mapa)
                if t.proyecto.x then
                    local definicion = Proyectos.buscar(id)
                    t.obras = t.obras or {}
                    t.obras[id] = { x = t.proyecto.x, y = t.proyecto.y, tamano = definicion and definicion.tamano or 1 }
                end
                t.proyecto = nil
                WorldQuest.Red.avisar("IGUI_WQ_ProyectoTerminado", { { clave = "IGUI_WQ_Proyecto_" .. id }, t.nombre }, "aviso")
            end
        end
    end
end

WorldQuest.Reloj.alCiclo(alPasarCiclo)
