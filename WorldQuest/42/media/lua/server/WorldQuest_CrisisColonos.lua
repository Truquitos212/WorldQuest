-- WorldQuest - Crisis de colonos: locura y asaltantes

require "WorldQuest_Crisis"

local Crisis = WorldQuest.Crisis
local Colonos = WorldQuest.Colonos
local Almacen = WorldQuest.Almacen
local M = WorldQuest.Modificadores

local UMBRAL_LOCURA = 30
local COMIDA_ROBADA_LOCURA = 3
local PORCENTAJE_SAQUEO = 40
local DIFERENCIA_MORTAL = 15

local function quitarColono(colono)
    local lista = Colonos.getDatos().lista
    for i = #lista, 1, -1 do
        if lista[i] == colono then
            table.remove(lista, i)
            return
        end
    end
end

-- LOCURA: de sorpresa. El colono mas triste huye con comida
Crisis.registrar({
    id = "locura",
    minutosAviso = 0,
    ejecutar = function(territorio)
        local peor = nil
        local umbral = M.umbralLocura(territorio, UMBRAL_LOCURA)
        for _, colono in ipairs(Colonos.delTerritorio(territorio)) do
            if colono.animo < umbral and (not peor or colono.animo < peor.animo) then
                peor = colono
            end
        end
        if not peor then
            return false
        end

        local robadas = 0
        Almacen.recorrerItems(territorio, function(item, contenedor)
            if robadas < COMIDA_ROBADA_LOCURA and item:IsFood() then
                Almacen.quitar(contenedor, item)
                robadas = robadas + 1
            end
        end)

        quitarColono(peor)
        WorldQuest.Red.avisar("IGUI_WQ_Locura", { peor.nombre, territorio.nombre }, "crisis")
        return true
    end,
})

-- ASALTANTES: con aviso. Ataque contra defensa
Crisis.registrar({
    id = "asaltantes",
    minutosAviso = 10,
    origen = 60,
    textoAviso = "IGUI_WQ_AvisoAsaltantes",
    ejecutar = function(territorio)
        local ataque = 10 + 10 * (territorio.nivel or 1) + ZombRand(20)
        local defensa = M.defensa(territorio)
        print("[WorldQuest] Asalto: ataque " .. ataque .. " contra defensa " .. defensa)

        if defensa >= ataque then
            WorldQuest.Red.avisar("IGUI_WQ_AsaltoRechazado", { territorio.nombre }, "aviso")
            return true
        end

        -- Saqueo de comida y materiales
        Almacen.recorrerItems(territorio, function(item, contenedor)
            local valioso = item:IsFood() or Almacen.MATERIALES[item:getFullType()] ~= nil
            if valioso and ZombRand(100) < M.saqueo(territorio, PORCENTAJE_SAQUEO) then
                Almacen.quitar(contenedor, item)
            end
        end)

        -- Derrota grande: muere un colono
        local colonos = Colonos.delTerritorio(territorio)
        if ataque - defensa > DIFERENCIA_MORTAL and #colonos > 0 then
            local victima = colonos[ZombRand(#colonos) + 1]
            quitarColono(victima)
            Colonos.registrarBaja(victima, "muerto")
            WorldQuest.Red.avisar("IGUI_WQ_AsaltoMuerte", { victima.nombre, territorio.nombre }, "crisis")
        else
            WorldQuest.Red.avisar("IGUI_WQ_AsaltoRobo", { territorio.nombre }, "crisis")
        end
        return true
    end,
})
