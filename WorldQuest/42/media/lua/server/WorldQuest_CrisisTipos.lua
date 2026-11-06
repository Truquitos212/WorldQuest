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

-- Punto al azar alrededor del territorio, a cierta distancia del borde
local function puntoAlrededor(territorio, distanciaExtra)
    local angulo = ZombRand(360) * math.pi / 180
    local distancia = territorio.radio + distanciaExtra
    return math.floor(territorio.x + math.cos(angulo) * distancia),
           math.floor(territorio.y + math.sin(angulo) * distancia)
end

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
    horasAviso = 6,
    textoAviso = "IGUI_WQ_AvisoHorda",
    textoInicio = "IGUI_WQ_InicioHorda",
    ejecutar = function(territorio)
        local origenX, origenY = puntoAlrededor(territorio, DISTANCIA_HORDA)

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
        addSound(getPlayer(), territorio.x, territorio.y, 0, territorio.radio + DISTANCIA_HORDA + 10, 100)

        print("[WorldQuest] Horda de " .. TAMANO_HORDA .. " desde " .. origenX .. ", " .. origenY)
        return true
    end,
})

-- INCENDIO: de sorpresa. Fuego dentro de una casa del territorio ------------
local FOCOS_INCENDIO = 3

Crisis.registrar({
    id = "incendio",
    horasAviso = 0,
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
    horasAviso = 0,
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
                        if item:IsFood() and ZombRand(100) < PORCENTAJE_PERDIDA then
                            contenedor:DoRemoveItem(item)
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
local HORAS_TORMENTA = 12
local TEMPERATURA_FRIO = -15
local CLIMA_TEMPERATURA = 4 -- numero interno de la temperatura en el clima

Crisis.registrar({
    id = "tormenta",
    horasAviso = 4,
    textoAviso = "IGUI_WQ_AvisoTormenta",
    textoInicio = "IGUI_WQ_InicioTormenta",
    ejecutar = function(territorio)
        getClimateManager():triggerCustomWeatherStage(3, HORAS_TORMENTA)
        Crisis.getDatos().frio = {
            territorio = territorio.id,
            hasta = getGameTime():getWorldAgeHours() + HORAS_TORMENTA,
        }
        return true
    end,
})

-- Cada minuto de juego: frio extremo solo si el jugador esta en el territorio
local function actualizarFrio()
    local datos = Crisis.getDatos()
    local frio = datos.frio
    if not frio then
        return
    end

    local temperatura = getClimateManager():getClimateFloat(CLIMA_TEMPERATURA)
    local territorio = Territorios.buscarPorId(frio.territorio)

    -- Termino la tormenta o se abandono el territorio: todo vuelve a la normalidad
    if not territorio or getGameTime():getWorldAgeHours() >= frio.hasta then
        temperatura:setEnableAdmin(false)
        datos.frio = nil
        print("[WorldQuest] Fin del frio extremo")
        return
    end

    local jugador = getPlayer()
    local dentro = jugador ~= nil and Territorios.contiene(territorio, jugador:getX(), jugador:getY())

    if dentro then
        temperatura:setEnableAdmin(true)
        temperatura:setAdminValue(TEMPERATURA_FRIO)
    else
        temperatura:setEnableAdmin(false)
    end
end

Events.EveryOneMinute.Add(actualizarFrio)
