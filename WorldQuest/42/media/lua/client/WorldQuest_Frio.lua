-- WorldQuest - Frio extremo de la tormenta (cliente)
-- Solo lo siente quien esta dentro del territorio afectado

WorldQuest = WorldQuest or {}

local TEMPERATURA_FRIO = -15
local CLIMA_TEMPERATURA = 4 -- numero interno de la temperatura en el clima

local activo = false

local function actualizar()
    if isServer() then
        return
    end
    local jugador = getPlayer()
    if not jugador then
        return
    end

    local dentro = false
    local frio = WorldQuest.Crisis.getDatos().frio
    if frio and getGameTime():getWorldAgeHours() < frio.hasta then
        local territorio = WorldQuest.Territorios.buscarPorId(frio.territorio)
        dentro = territorio ~= nil and WorldQuest.Territorios.contiene(territorio, jugador:getX(), jugador:getY())
    end

    local temperatura = getClimateManager():getClimateFloat(CLIMA_TEMPERATURA)
    if dentro then
        temperatura:setEnableAdmin(true)
        temperatura:setAdminValue(TEMPERATURA_FRIO)
        activo = true
    elseif activo then
        temperatura:setEnableAdmin(false)
        activo = false
    end
end

Events.EveryOneMinute.Add(actualizar)
