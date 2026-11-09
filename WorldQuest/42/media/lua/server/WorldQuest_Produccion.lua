-- WorldQuest - Colonos: produccion por ciclo segun el rol

require "WorldQuest_Crisis"

local Colonos = WorldQuest.Colonos
local Territorios = WorldQuest.Territorios
local Almacen = WorldQuest.Almacen
local Crisis = WorldQuest.Crisis
local M = WorldQuest.Modificadores

-- Cantidad producida con el multiplicador de la opcion de partida
local function producir(territorio, rol, base)
    return WorldQuest.Opciones.escalar(M.produccion(territorio, rol, base), WorldQuest.Opciones.produccion())
end

local HABILIDAD_DEL_ROL = {
    agricultor = "agricultura",
    explorador = "exploracion",
    constructor = "construccion",
    guardia = "combate",
    medico = "medicina",
}

local MAX_DIAS_PENDIENTES = 7
local PROBABILIDAD_MEJORA = 10      -- % por dia de trabajo
local RIESGO_EXPLORADOR = 8         -- % base de no volver

local COSECHA = { "Base.Potato", "Base.Carrots", "Base.Cabbage", "Base.Tomato" }
local BOTIN = { "Base.TinnedBeans", "Base.TinnedSoup", "Base.CannedCorn", "Base.Bandage", "Base.Nails", "Base.Plank" }

local function alAzar(lista)
    return lista[ZombRand(#lista) + 1]
end

-- Primer contenedor del primer almacen cargado
local function contenedorDeposito(territorio)
    for _, objeto in ipairs(Almacen.objetos(territorio)) do
        if objeto:getContainerCount() > 0 then
            return objeto:getContainerByIndex(0)
        end
    end
    return nil
end

local function depositar(contenedor, tipos, cantidad)
    for i = 1, cantidad do
        if type(tipos) == "table" then
            contenedor:AddItem(alAzar(tipos))
        else
            contenedor:AddItem(tipos)
        end
    end
end

-- Un dia de trabajo. Devuelve false si el colono murio
local function trabajar(colono, territorio, contenedor)
    local habilidadId = HABILIDAD_DEL_ROL[colono.rol]
    if not habilidadId then
        return true
    end
    local habilidad = colono.habilidades[habilidadId]

    if colono.rol == "agricultor" then
        depositar(contenedor, COSECHA, producir(territorio, "agricultor", 1 + math.floor(habilidad / 3)))

    elseif colono.rol == "constructor" then
        -- Si hay una obra, el constructor trabaja en ella en vez de cortar troncos
        if not territorio.proyecto then
            depositar(contenedor, "Base.Log", producir(territorio, "constructor", 1 + math.floor(habilidad / 4)))
        end

    elseif colono.rol == "explorador" then
        local riesgo = math.max(1, RIESGO_EXPLORADOR - math.floor(colono.habilidades.combate / 2))
        if ZombRand(100) < riesgo then
            return false
        end
        depositar(contenedor, BOTIN, producir(territorio, "explorador", 1 + ZombRand(1 + math.floor(habilidad / 2))))
    end

    if habilidad < 10 and ZombRand(100) < PROBABILIDAD_MEJORA then
        colono.habilidades[habilidadId] = habilidad + 1
    end
    return true
end

-- Cada ciclo: los colonos con rol suman un ciclo de trabajo pendiente
local function alPasarDia()
    for _, colono in ipairs(Colonos.getDatos().lista) do
        if colono.rol ~= "ninguno" then
            colono.trabajoPendiente = math.min((colono.trabajoPendiente or 0) + 1, MAX_DIAS_PENDIENTES)
        end
    end
end

-- Cada 10 minutos: en territorios cargados, se entrega lo producido
local function alPasarDiezMinutos()
    local lista = Colonos.getDatos().lista
    for i = #lista, 1, -1 do
        local colono = lista[i]
        if (colono.trabajoPendiente or 0) > 0 then
            local territorio = Territorios.buscarPorId(colono.territorio)
            if territorio and Crisis.estaCargado(territorio) then
                local contenedor = contenedorDeposito(territorio)
                if contenedor then
                    local vivo = true
                    while vivo and colono.trabajoPendiente > 0 do
                        colono.trabajoPendiente = colono.trabajoPendiente - 1
                        vivo = trabajar(colono, territorio, contenedor)
                    end
                    if not vivo then
                        table.remove(lista, i)
                        Colonos.registrarBaja(colono, "desaparecido")
                        Crisis.avisar(getText("IGUI_WQ_ExploradorMuerto", colono.nombre, territorio.nombre), "crisis")
                    end
                end
            end
        end
    end
end

WorldQuest.Reloj.alCiclo(alPasarDia)
Events.EveryTenMinutes.Add(alPasarDiezMinutos)
