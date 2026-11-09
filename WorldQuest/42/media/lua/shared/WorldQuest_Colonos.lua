-- WorldQuest - Colonos: datos (capa de simulacion)

WorldQuest = WorldQuest or {}
WorldQuest.Colonos = WorldQuest.Colonos or {}

local Colonos = WorldQuest.Colonos
local CLAVE_DATOS = "WorldQuest_Colonos"

Colonos.CUPO_BASE = 3
Colonos.RACION = 250              -- calorias que come cada colono por ciclo
Colonos.HABILIDADES = { "agricultura", "exploracion", "construccion", "combate", "medicina" }

local NOMBRES = {
    "James", "John", "Robert", "Michael", "William", "David", "Richard", "Joseph",
    "Thomas", "Charles", "Dale", "Earl", "Bobby", "Mary", "Patricia", "Linda",
    "Barbara", "Elizabeth", "Jennifer", "Susan", "Margaret", "Dorothy", "Wanda", "Kate",
}

local APELLIDOS = {
    "Smith", "Johnson", "Williams", "Brown", "Jones", "Miller", "Davis", "Wilson",
    "Anderson", "Taylor", "Moore", "Jackson", "Martin", "Lee", "Thompson", "White",
    "Harris", "Clark", "Lewis", "Walker",
}

function Colonos.getDatos()
    local datos = ModData.getOrCreate(CLAVE_DATOS)
    datos.lista = datos.lista or {}
    datos.siguienteId = datos.siguienteId or 1
    return datos
end

-- Colonos que viven en el territorio
function Colonos.delTerritorio(territorio)
    local resultado = {}
    for _, colono in ipairs(Colonos.getDatos().lista) do
        if colono.territorio == territorio.id then
            table.insert(resultado, colono)
        end
    end
    return resultado
end

-- Cuantos colonos caben en el territorio (despues dependera de camas y nivel)
function Colonos.cupo(territorio)
    return WorldQuest.Modificadores.cupo(territorio)
end

local function alAzar(lista)
    return lista[ZombRand(#lista) + 1]
end

-- Crea un colono nuevo, todavia sin guardar
function Colonos.generar(territorio)
    local habilidades = {}
    for _, habilidad in ipairs(Colonos.HABILIDADES) do
        habilidades[habilidad] = ZombRand(5) -- 0 a 4
    end
    local especialidad = alAzar(Colonos.HABILIDADES)
    habilidades[especialidad] = 5 + ZombRand(5) -- 5 a 9

    return {
        nombre = alAzar(NOMBRES) .. " " .. alAzar(APELLIDOS),
        territorio = territorio.id,
        rol = "ninguno",
        habilidades = habilidades,
        especialidad = especialidad,
        animo = 60,
        deuda = 0, -- calorias que debe comer
    }
end

-- Guarda un colono y le asigna id
function Colonos.agregar(colono)
    local datos = Colonos.getDatos()
    colono.id = datos.siguienteId
    datos.siguienteId = datos.siguienteId + 1
    table.insert(datos.lista, colono)
    return colono
end

-- Minutos de partida sin comer (para el panel)
function Colonos.minutosSinComer(colono)
    return Colonos.ciclosSinComer(colono) * WorldQuest.Reloj.minutosCiclo()
end

-- Ciclos completos sin comer, sin contar la racion del ciclo actual
function Colonos.ciclosSinComer(colono)
    local racion = Colonos.RACION
    local territorio = WorldQuest.Territorios.buscarPorId(colono.territorio)
    if territorio and WorldQuest.Modificadores then
        racion = WorldQuest.Modificadores.racion(territorio)
    end
    return math.max(0, math.ceil(colono.deuda / racion) - 1)
end

-- Registra por que un colono dejo la colonia, para saber que hacer con su cuerpo:
-- "muerto", "desaparecido" o sin registro (se fue por su cuenta)
function Colonos.registrarBaja(colono, motivo)
    local datos = Colonos.getDatos()
    datos.bajas = datos.bajas or {}
    datos.bajas[colono.nombre] = motivo
end
