-- WorldQuest - Colonos: vida por ciclo (comer, animo, llegadas)

require "WorldQuest_Crisis"

local Colonos = WorldQuest.Colonos
local Territorios = WorldQuest.Territorios
local Almacen = WorldQuest.Almacen
local Crisis = WorldQuest.Crisis
local M = WorldQuest.Modificadores

local PROBABILIDAD_LLEGADA = 20      -- % por ciclo (la radio la duplica)
local ANIMO_SI_COMEN = 5
local ANIMO_POR_CICLO_DE_HAMBRE = 8
local MAX_CICLOS_HAMBRE = 5
local MAX_CICLOS_DEUDA = 7           -- tope de comida atrasada

-- Los colonos del territorio comen del almacen hasta pagar lo que deben
local function comer(territorio)
    local colonos = Colonos.delTerritorio(territorio)
    local deudaTotal = 0
    for _, colono in ipairs(colonos) do
        deudaTotal = deudaTotal + colono.deuda
    end
    if deudaTotal <= 0 then
        return
    end

    local comido = 0
    Almacen.recorrerItems(territorio, function(item, contenedor)
        if comido < deudaTotal and item:IsFood() and not item:isRotten() then
            local calorias = item:getCalories()
            if calorias > 0 then
                Almacen.quitar(contenedor, item)
                comido = comido + calorias
            end
        end
    end)

    -- Repartir lo comido entre los colonos
    for _, colono in ipairs(colonos) do
        local pago = math.min(colono.deuda, comido)
        colono.deuda = colono.deuda - pago
        comido = comido - pago
    end
end

-- LLEGADAS ------------------------------------------------------------

function Colonos.aceptar(propuesta, territorio)
    if #Colonos.delTerritorio(territorio) >= Colonos.cupo(territorio) then
        return
    end
    propuesta.pid = nil
    Colonos.agregar(propuesta)
    WorldQuest.Red.cambio()
    WorldQuest.Red.avisar("IGUI_WQ_ColonoUnido", { propuesta.nombre, territorio.nombre }, "aviso")
end

-- Genera un sobreviviente y le pregunta al dueno del territorio si lo acepta.
-- La propuesta queda guardada en el servidor hasta que el dueno responda.
function Colonos.ofrecerLlegada(territorio)
    local jugador = WorldQuest.Red.jugador(territorio.dueno)
    if not jugador then
        return -- el dueno no esta conectado: nadie puede responder
    end

    local datos = Colonos.getDatos()
    datos.propuestas = datos.propuestas or {}
    datos.siguientePropuesta = (datos.siguientePropuesta or 0) + 1
    local propuesta = Colonos.generar(territorio)
    propuesta.pid = datos.siguientePropuesta
    datos.propuestas[tostring(propuesta.pid)] = propuesta

    WorldQuest.Red.enviar("ofrecerColono", {
        pid = propuesta.pid,
        nombre = propuesta.nombre,
        especialidad = propuesta.especialidad,
        nivel = propuesta.habilidades[propuesta.especialidad],
        territorio = territorio.nombre,
    }, jugador)
end

-- Saca una propuesta guardada (nil si ya no existe)
function Colonos.tomarPropuesta(pid)
    local datos = Colonos.getDatos()
    if not datos.propuestas then
        return nil
    end
    local propuesta = datos.propuestas[tostring(pid)]
    datos.propuestas[tostring(pid)] = nil
    return propuesta
end

local function intentarLlegada()
    if ZombRand(100) >= M.probabilidadLlegada(PROBABILIDAD_LLEGADA) then
        return
    end

    -- Solo territorios con almacen y cupo libre
    local candidatos = {}
    for _, territorio in ipairs(Territorios.getDatos().lista) do
        local tieneAlmacen = territorio.almacenes and #territorio.almacenes > 0
        if tieneAlmacen and #Colonos.delTerritorio(territorio) < Colonos.cupo(territorio) then
            table.insert(candidatos, territorio)
        end
    end

    if #candidatos > 0 then
        Colonos.ofrecerLlegada(candidatos[ZombRand(#candidatos) + 1])
    end
end

-- EVENTOS -------------------------------------------------------------

-- Cada 10 minutos de juego: en los territorios cargados, comen lo que deben
local function alPasarDiezMinutos()
    if isClient() then
        return
    end
    WorldQuest.Red.cambio()
    for _, territorio in ipairs(Territorios.getDatos().lista) do
        if Crisis.estaCargado(territorio) then
            comer(territorio)
        end
    end
end

-- Cada ciclo: hambre, animo, partidas y llegadas
local function alPasarCiclo()
    local lista = Colonos.getDatos().lista

    for i = #lista, 1, -1 do
        local colono = lista[i]
        local territorio = Territorios.buscarPorId(colono.territorio)

        if not territorio then
            -- Territorio abandonado: el colono se va sin aviso
            table.remove(lista, i)
        else
            local seFue = false

            -- Solo se evalua el hambre si el almacen esta al alcance
            if Crisis.estaCargado(territorio) then
                comer(territorio)
                local ciclosHambre = math.floor(colono.deuda / Colonos.RACION)
                if ciclosHambre == 0 then
                    colono.animo = math.min(100, colono.animo + ANIMO_SI_COMEN + M.animoDiario(territorio))
                else
                    colono.animo = math.max(0, colono.animo - ANIMO_POR_CICLO_DE_HAMBRE * ciclosHambre)
                end

                if ciclosHambre >= MAX_CICLOS_HAMBRE or colono.animo <= 0 then
                    table.remove(lista, i)
                    seFue = true
                    WorldQuest.Red.avisar("IGUI_WQ_ColonoSeVa", { colono.nombre, territorio.nombre }, "crisis")
                end
            end

            -- La racion de este ciclo queda pendiente
            if not seFue then
                local tope = Colonos.RACION * MAX_CICLOS_DEUDA
                colono.deuda = math.min(colono.deuda + Colonos.RACION, tope)
            end
        end
    end

    intentarLlegada()
end

Events.EveryTenMinutes.Add(alPasarDiezMinutos)
WorldQuest.Reloj.alCiclo(alPasarCiclo)
