-- WorldQuest - Puesto de mando (cliente)
-- El lider lo marca con clic derecho dentro de un territorio de su faccion.
-- Mientras este cerca y tenga hambre, pide comida y los colonos se la llevan.

WorldQuest = WorldQuest or {}
WorldQuest.Puesto = WorldQuest.Puesto or {}

local Puesto = WorldQuest.Puesto
local Red = WorldQuest.Red
local Facciones = WorldQuest.Facciones

local RADIO = 4                  -- igual que en el servidor
local UMBRAL_HAMBRE = 0.15       -- desde aqui le llevan comida
local CALORIAS_POR_BARRA = 1500  -- cuanto baja el hambre por caloria (aproximado)
local ESPERA_MS = 20000

local ultimo = 0

function Puesto.cerca(jugador, p)
    local dx, dy = jugador:getX() - (p.x + 0.5), jugador:getY() - (p.y + 0.5)
    return math.floor(jugador:getZ()) == p.z and (dx * dx + dy * dy) <= RADIO * RADIO
end

local function marcar(jugador)
    Red.pedir("marcarPuesto", { x = math.floor(jugador:getX()), y = math.floor(jugador:getY()), z = math.floor(jugador:getZ()) })
end

local function onFillWorldObjectContextMenu(numJugador, context, worldobjects, test)
    local jugador = getSpecificPlayer(numJugador)
    local f = Facciones.deJugador(jugador)
    if not f or f.lider ~= jugador:getUsername() then
        return
    end
    local t = WorldQuest.Territorios.buscarEn(math.floor(jugador:getX()), math.floor(jugador:getY()))
    if not t or t.faccion ~= f.id then
        return
    end
    local clave = f.puesto and "ContextMenu_WQ_MoverPuesto" or "ContextMenu_WQ_MarcarPuesto"
    context:addOption(getText(clave), jugador, marcar)
end

local function revisar()
    if isServer() then
        return
    end
    local jugador = getPlayer()
    if not jugador then
        return
    end
    local f = Facciones.deJugador(jugador)
    if not f or f.lider ~= jugador:getUsername() or not f.puesto or not Puesto.cerca(jugador, f.puesto) then
        return
    end
    local ok, hambre = pcall(function() return jugador:getStats():get(CharacterStat.HUNGER) end)
    if not ok or type(hambre) ~= "number" or hambre < UMBRAL_HAMBRE then
        return
    end
    local ahora = getTimestampMs()
    if ahora - ultimo < ESPERA_MS then
        return
    end
    ultimo = ahora
    Red.pedir("alimentarLider", {})
end

Red.mensaje("alimentado", function(args)
    local jugador = getPlayer()
    if not jugador then
        return
    end
    local baja = (tonumber(args.calorias) or 0) / CALORIAS_POR_BARRA
    local ok = pcall(function()
        local stats = jugador:getStats()
        stats:set(CharacterStat.HUNGER, math.max(0, stats:get(CharacterStat.HUNGER) - baja))
    end)
    if ok then
        jugador:Say(getText("IGUI_WQ_Alimentado", tostring(args.calorias)))
    end
    print("[WorldQuest] Puesto de mando: comida de " .. tostring(args.calorias) .. " kcal" .. (ok and "" or " (no se pudo cambiar el hambre)"))
end)

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
Events.EveryOneMinute.Add(revisar)
