-- WorldQuest - Territorios: avisos al entrar y salir (cliente)

WorldQuest = WorldQuest or {}

local Territorios = WorldQuest.Territorios

local ultimaX = nil
local ultimaY = nil
local territorioActual = nil

local function onPlayerUpdate(jugador)
    -- Casilla actual (las coordenadas vienen con decimales)
    local x = math.floor(jugador:getX())
    local y = math.floor(jugador:getY())

    -- Si sigue en la misma casilla, no hay nada que revisar
    if x == ultimaX and y == ultimaY then
        return
    end
    ultimaX = x
    ultimaY = y

    local nuevo = Territorios.buscarEn(x, y)

    if nuevo ~= territorioActual then
        if territorioActual then
            jugador:Say("Saliendo de " .. territorioActual.nombre)
            print("[WorldQuest] Saliendo de " .. territorioActual.nombre)
        end
        if nuevo then
            jugador:Say("Entrando a " .. nuevo.nombre)
            print("[WorldQuest] Entrando a " .. nuevo.nombre)
        end
        territorioActual = nuevo
    end
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)
