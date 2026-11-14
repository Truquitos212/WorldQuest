-- WorldQuest - Crisis: tipos de crisis (fichas)

require "WorldQuest_Crisis"

local Crisis = WorldQuest.Crisis
local Territorios = WorldQuest.Territorios

-- Llama a funcion(casilla) para cada casilla cargada dentro del territorio
local function recorrerCasillas(territorio, funcion)
    local celda = getCell()
    local r = territorio.radio
    for x = territorio.x - r, territorio.x + r do
        for y = territorio.y - r, territorio.y + r do
            if Territorios.contiene(territorio, x, y) then
                local casilla = celda:getGridSquare(x, y, 0)
                if casilla then
                    funcion(casilla)
                end
            end
        end
    end
end

local puntoAlrededor = Crisis.puntoAlrededor

-- Numero al azar entre -n y n
local function desvio(n)
    return ZombRand(n * 2 + 1) - n
end

-- HORDA: con aviso. Todos salen del mismo lado y caminan al centro ----------
local TAMANO_HORDA = 20
local DISTANCIA_HORDA = 25 -- casillas fuera del borde
local DISPERSION_HORDA = 4

Crisis.registrar({
    id = "horda",
    minutosAviso = 8,
    origen = DISTANCIA_HORDA,
    textoAviso = "IGUI_WQ_AvisoHorda",
    textoInicio = "IGUI_WQ_InicioHorda",
    ejecutar = function(territorio, pendiente)
        local origenX, origenY = puntoAlrededor(territorio, DISTANCIA_HORDA)
        if pendiente and pendiente.ox then
            origenX, origenY = pendiente.ox, pendiente.oy
        end

        for i = 1, WorldQuest.Modificadores.tamanoHorda(territorio, TAMANO_HORDA) do
            local x = origenX + desvio(DISPERSION_HORDA)
            local y = origenY + desvio(DISPERSION_HORDA)
            local zombies = addZombiesInOutfit(x, y, 0, 1, nil, 50)
            if zombies then
                for k = 0, zombies:size() - 1 do
                    zombies:get(k):pathToLocation(territorio.x + desvio(3), territorio.y + desvio(3), 0)
                end
            end
        end

        -- Ruido en el centro para que la horda no se distraiga en el camino
        pcall(addSound, nil, territorio.x, territorio.y, 0, territorio.radio + DISTANCIA_HORDA + 10, 100)

        print("[WorldQuest] Horda de " .. TAMANO_HORDA .. " desde " .. origenX .. ", " .. origenY)
        return true
    end,
})

-- INCENDIO: de sorpresa. Fuego dentro de una casa del territorio ------------
local FOCOS_INCENDIO = 3

Crisis.registrar({
    id = "incendio",
    minutosAviso = 0,
    textoInicio = "IGUI_WQ_InicioIncendio",
    ejecutar = function(territorio)
        -- Casillas interiores (las que pertenecen a una habitacion)
        local interiores = {}
        recorrerCasillas(territorio, function(casilla)
            if casilla:getRoom() then
                table.insert(interiores, casilla)
            end
        end)

        if #interiores == 0 then
            print("[WorldQuest] Incendio cancelado: no hay casas en " .. territorio.nombre)
            return false
        end

        -- Elegir una casa y quedarse solo con sus casillas
        local casa = interiores[ZombRand(#interiores) + 1]:getBuilding()
        local casillasCasa = {}
        for _, casilla in ipairs(interiores) do
            if casilla:getBuilding() == casa then
                table.insert(casillasCasa, casilla)
            end
        end

        for foco = 1, FOCOS_INCENDIO do
            local casilla = casillasCasa[ZombRand(#casillasCasa) + 1]
            IsoFireManager.StartFire(getCell(), casilla, true, 100)
        end
        return true
    end,
})

-- PERDIDA DE COMIDA: de sorpresa. Desaparece parte de la comida guardada -----
local PORCENTAJE_PERDIDA = 30

Crisis.registrar({
    id = "comida",
    minutosAviso = 0,
    textoInicio = "IGUI_WQ_InicioComida",
    ejecutar = function(territorio)
        local perdidas = 0
        recorrerCasillas(territorio, function(casilla)
            local objetos = casilla:getObjects()
            for i = 0, objetos:size() - 1 do
                local objeto = objetos:get(i)
                for c = 0, objeto:getContainerCount() - 1 do
                    local contenedor = objeto:getContainerByIndex(c)
                    local items = contenedor:getItems()
                    for k = items:size() - 1, 0, -1 do
                        local item = items:get(k)
                        if item:IsFood() and ZombRand(100) < WorldQuest.Modificadores.perdidaComida(territorio, PORCENTAJE_PERDIDA) then
                            WorldQuest.Almacen.quitar(contenedor, item)
                            perdidas = perdidas + 1
                        end
                    end
                end
            end
        end)
        print("[WorldQuest] Comida perdida: " .. perdidas)
        return true
    end,
})

-- TORMENTA: con aviso. Tormenta global y frio extremo dentro del territorio --
local MINUTOS_TORMENTA = 10

Crisis.registrar({
    id = "tormenta",
    minutosAviso = 6,
    textoAviso = "IGUI_WQ_AvisoTormenta",
    textoInicio = "IGUI_WQ_InicioTormenta",
    ejecutar = function(territorio)
        local horas = WorldQuest.Reloj.horasDeJuego(MINUTOS_TORMENTA)
        getClimateManager():triggerCustomWeatherStage(3, horas)
        Crisis.getDatos().frio = {
            territorio = territorio.id,
            hasta = getGameTime():getWorldAgeHours() + horas,
        }
        WorldQuest.Red.cambio()
        return true
    end,
})

-- Cada minuto de juego: el servidor da por terminado el frio cuando se acaba la tormenta
-- (el efecto sobre cada jugador lo aplica el cliente en client/WorldQuest_Frio.lua)
local function terminarFrio()
    if isClient() then
        return
    end
    local datos = Crisis.getDatos()
    local frio = datos.frio
    if not frio then
        return
    end
    if not Territorios.buscarPorId(frio.territorio) or getGameTime():getWorldAgeHours() >= frio.hasta then
        datos.frio = nil
        WorldQuest.Red.cambio()
        print("[WorldQuest] Fin del frio extremo")
    end
end

Events.EveryOneMinute.Add(terminarFrio)
