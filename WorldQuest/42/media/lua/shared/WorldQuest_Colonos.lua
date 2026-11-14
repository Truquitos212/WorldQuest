-- WorldQuest - Colonos: datos (capa de simulacion)

WorldQuest = WorldQuest or {}
WorldQuest.Colonos = WorldQuest.Colonos or {}

local Colonos = WorldQuest.Colonos
local CLAVE_DATOS = "WorldQuest_Colonos"

Colonos.CUPO_BASE = 3
Colonos.RACION = 250              -- calorias que come cada colono por ciclo
Colonos.HABILIDADES = { "agricultura", "exploracion", "construccion", "combate", "medicina" }

-- Rasgos de personalidad: cada colono tiene uno o dos. Efectos:
--   produccion, racion, riesgo (multiplicadores); animo (por ciclo), defensa (suma)
Colonos.RASGOS = {
    trabajador = { produccion = 1.25 },
    perezoso   = { produccion = 0.75, animo = 1 },
    valiente   = { defensa = 4, riesgo = 0.8 },
    cobarde    = { defensa = -3, riesgo = 1.3 },
    gloton     = { racion = 1.3, animo = 1 },
    frugal     = { racion = 0.8 },
    optimista  = { animo = 2 },
    pesimista  = { animo = -2, produccion = 1.1 },
    sociable   = { animoGrupo = 2 },          -- con 4 o mas colonos en la base
    solitario  = { animoGrupo = -2, produccion = 1.15 },
}
-- Pares que no pueden ir juntos
Colonos.OPUESTOS = { trabajador = "perezoso", perezoso = "trabajador", valiente = "cobarde", cobarde = "valiente",
    gloton = "frugal", frugal = "gloton", optimista = "pesimista", pesimista = "optimista",
    sociable = "solitario", solitario = "sociable" }
Colonos.OFICIOS = { "mecanico", "enfermera", "camionero", "profesor", "policia", "cocinero", "granjero",
    "estudiante", "soldado", "carpintero", "cajero", "bombero" }

local MULT_RASGO = { produccion = true, racion = true, riesgo = true }

-- Efecto combinado de los rasgos del colono
function Colonos.efecto(colono, clave)
    local mult = MULT_RASGO[clave]
    local valor = mult and 1 or 0
    for _, r in ipairs(colono and colono.rasgos or {}) do
        local e = Colonos.RASGOS[r]
        if e and e[clave] then
            if mult then
                valor = valor * e[clave]
            else
                valor = valor + e[clave]
            end
        end
    end
    return valor
end

local function rasgosAlAzar()
    local lista = {}
    for id, _ in pairs(Colonos.RASGOS) do
        table.insert(lista, id)
    end
    table.sort(lista)
    local primero = lista[ZombRand(#lista) + 1]
    local rasgos = { primero }
    if ZombRand(100) < 35 then
        local segundo = lista[ZombRand(#lista) + 1]
        if segundo ~= primero and Colonos.OPUESTOS[primero] ~= segundo then
            table.insert(rasgos, segundo)
        end
    end
    return rasgos
end

-- Completa los datos de colonos viejos (de antes de los rasgos)
function Colonos.completar(colono)
    if not colono.rasgos then
        colono.rasgos = rasgosAlAzar()
    end
    colono.edad = colono.edad or (18 + ZombRand(48))
    colono.oficio = colono.oficio or Colonos.OFICIOS[ZombRand(#Colonos.OFICIOS) + 1]
    colono.desde = colono.desde or getGameTime():getWorldAgeHours()
    colono.trabajos = colono.trabajos or 0
end

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

    local colono = {
        nombre = alAzar(NOMBRES) .. " " .. alAzar(APELLIDOS),
        territorio = territorio.id,
        rol = "ninguno",
        habilidades = habilidades,
        especialidad = especialidad,
        animo = 60,
        deuda = 0, -- calorias que debe comer
    }
    Colonos.completar(colono)
    return colono
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
