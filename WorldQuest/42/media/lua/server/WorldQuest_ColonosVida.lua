-- WorldQuest - Colonos: vida diaria (comer, animo, llegadas)

require "WorldQuest_Crisis"

local Colonos = WorldQuest.Colonos
local Territorios = WorldQuest.Territorios
local Almacen = WorldQuest.Almacen
local Crisis = WorldQuest.Crisis

local PROBABILIDAD_LLEGADA = 20   -- % por dia
local ANIMO_SI_COMEN = 5
local ANIMO_POR_DIA_DE_HAMBRE = 15
local MAX_DIAS_HAMBRE = 5
local MAX_DIAS_DEUDA = 7          -- tope de comida atrasada

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
                contenedor:DoRemoveItem(item)
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
    Colonos.agregar(propuesta)
    Crisis.avisar(getText("IGUI_WQ_ColonoUnido", propuesta.nombre, territorio.nombre), "aviso")
end

-- Genera un sobreviviente y le pregunta al jugador si lo acepta
function Colonos.ofrecerLlegada(territorio)
    local propuesta = Colonos.generar(territorio)
    if WorldQuest.ColonosUI then
        WorldQuest.ColonosUI.ofrecer(propuesta, territorio)
    else
        Colonos.aceptar(propuesta, territorio)
    end
end

local function intentarLlegada()
    if ZombRand(100) >= PROBABILIDAD_LLEGADA then
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

-- Cada 10 minutos: en los territorios cargados, comen lo que deben
local function alPasarDiezMinutos()
    for _, territorio in ipairs(Territorios.getDatos().lista) do
        if Crisis.estaCargado(territorio) then
            comer(territorio)
        end
    end
end

-- Cada dia: hambre, animo, partidas y llegadas
local function alPasarDia()
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
                local diasHambre = math.floor(colono.deuda / Colonos.CALORIAS_DIARIAS)
                if diasHambre == 0 then
                    colono.animo = math.min(100, colono.animo + ANIMO_SI_COMEN)
                else
                    colono.animo = math.max(0, colono.animo - ANIMO_POR_DIA_DE_HAMBRE * diasHambre)
                end

                if diasHambre >= MAX_DIAS_HAMBRE or colono.animo <= 0 then
                    table.remove(lista, i)
                    seFue = true
                    Crisis.avisar(getText("IGUI_WQ_ColonoSeVa", colono.nombre, territorio.nombre), "crisis")
                end
            end

            -- La racion de hoy queda pendiente
            if not seFue then
                local tope = Colonos.CALORIAS_DIARIAS * MAX_DIAS_DEUDA
                colono.deuda = math.min(colono.deuda + Colonos.CALORIAS_DIARIAS, tope)
            end
        end
    end

    intentarLlegada()
end

Events.EveryTenMinutes.Add(alPasarDiezMinutos)
Events.EveryDays.Add(alPasarDia)
