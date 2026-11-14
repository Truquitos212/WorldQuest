-- WorldQuest - Opciones de partida (sandbox)
-- Lee SandboxVars.WorldQuest con valores por defecto si la opcion no existe

WorldQuest = WorldQuest or {}
WorldQuest.Opciones = WorldQuest.Opciones or {}

local Opciones = WorldQuest.Opciones

local function valor(nombre, defecto)
    local vars = SandboxVars and SandboxVars.WorldQuest
    if not vars or vars[nombre] == nil then
        return defecto
    end
    return vars[nombre]
end

function Opciones.pruebas()
    return valor("HerramientasPrueba", false) == true
end

function Opciones.frecuenciaCrisis()
    return valor("FrecuenciaCrisis", 1.0)
end

function Opciones.produccion()
    return valor("Produccion", 1.0)
end

-- 1 libre, 2 justo, 3 pueblo chico, 4 aleatorio (STERAK)
function Opciones.modoInicio()
    return valor("ModoInicio", 1)
end

-- 1 rapida, 2 normal, 3 larga
function Opciones.duracion()
    return valor("Duracion", 2)
end

-- Niebla de guerra (solo ves lo que tienes cerca)
function Opciones.niebla()
    return valor("NieblaDeGuerra", true) == true
end

-- 1 estandar, 2 caos
function Opciones.modoJuego()
    return valor("ModoJuego", 1)
end

-- Horas de partida antes del final por tiempo (0 = segun la duracion)
function Opciones.limiteHoras()
    return valor("LimiteHoras", 0)
end

function Opciones.costos()
    return valor("Costos", 1.0)
end

-- Cantidad entera escalada por un factor (redondeada, nunca negativa)
function Opciones.escalar(cantidad, factor)
    return math.max(0, math.floor(cantidad * factor + 0.5))
end

-- Escala los costos desde su valor base (se puede llamar varias veces)
local function escalarCostos(lista, factor)
    for _, fila in ipairs(lista or {}) do
        if fila.costo then
            fila.costoBase = fila.costoBase or fila.costo
            local costo = {}
            for recurso, cantidad in pairs(fila.costoBase) do
                costo[recurso] = math.max(1, Opciones.escalar(cantidad, factor))
            end
            fila.costo = costo
        end
    end
end

function Opciones.aplicar()
    local factor = Opciones.costos()
    escalarCostos(WorldQuest.Niveles and WorldQuest.Niveles.LISTA, factor)
    escalarCostos(WorldQuest.Proyectos and WorldQuest.Proyectos.LISTA, factor)
    print("[WorldQuest] Opciones: pruebas=" .. tostring(Opciones.pruebas())
        .. ", crisis x" .. tostring(Opciones.frecuenciaCrisis())
        .. ", produccion x" .. tostring(Opciones.produccion())
        .. ", costos x" .. tostring(factor))
end

Events.OnGameStart.Add(Opciones.aplicar)
if Events.OnServerStarted then
    Events.OnServerStarted.Add(Opciones.aplicar)
end
