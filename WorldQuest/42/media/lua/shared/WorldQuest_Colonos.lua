-- WorldQuest - Colonos: datos (capa de simulacion)

WorldQuest = WorldQuest or {}
WorldQuest.Colonos = WorldQuest.Colonos or {}

local Colonos = WorldQuest.Colonos
local CLAVE_DATOS = "WorldQuest_Colonos"

Colonos.CUPO_BASE = 3
Colonos.CALORIAS_DIARIAS = 2000
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
    return Colonos.CUPO_BASE
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

-- Dias completos sin comer, sin contar la racion de hoy
function Colonos.diasSinComer(colono)
    return math.max(0, math.ceil(colono.deuda / Colonos.CALORIAS_DIARIAS) - 1)
end
