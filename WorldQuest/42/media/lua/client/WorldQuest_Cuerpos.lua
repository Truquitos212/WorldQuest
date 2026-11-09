-- WorldQuest - Cuerpos de colonos con Bandits (capa opcional, cliente)
-- Si el mod Bandits (id Bandits2) esta cargado, cada colono aparece como un NPC
-- amigable en su territorio. Si no esta, este archivo no hace nada.

WorldQuest = WorldQuest or {}
WorldQuest.Cuerpos = WorldQuest.Cuerpos or {}

local Cuerpos = WorldQuest.Cuerpos

-- Clanes por defecto de Bandits (los mismos de sus grupos errantes)
local CLANES = {
    "2681ecf5-d0d9-481d-b769-7c4fb626eb81",
    "a2dec2f0-c76d-4640-8a71-733a547a1ebc",
    "bf5985eb-7cb0-44ba-8392-f656ffe421f4",
}

local PROGRAMA = "Camper"     -- se queda fijo, duerme y descansa en la base
local PROGRAMA_SALIDA = "Looter"
local ESPERA_TICKS = 2        -- 20 min de juego cargado antes de pedir cuerpos
local DISPERSION = 4

local ticksCargado = {}       -- id territorio -> ticks seguidos cargado
local pedidos = {}            -- id colono -> true (cuerpo pedido en esta carga)
local nombrePorZombie = {}    -- zombie -> nombre (respaldo para detectar muertes)

function Cuerpos.activo()
    return Bandit ~= nil and BanditBrain ~= nil
end

-- Nombres de los cuerpos que creo WorldQuest (guardado en la partida)
local function registro()
    local datos = WorldQuest.Colonos.getDatos()
    datos.cuerpos = datos.cuerpos or {}
    return datos.cuerpos
end

local function cerebroAmigable(zombie)
    if not zombie:getVariableBoolean("Bandit") then
        return nil
    end
    local brain = BanditBrain.Get(zombie)
    if brain and not brain.hostile and brain.fullname then
        return brain
    end
    return nil
end

-- NPCs amigables cargados, por nombre
local function cuerposCercanos()
    local porNombre = {}
    local zombies = getCell():getZombieList()
    for i = 0, zombies:size() - 1 do
        local zombie = zombies:get(i)
        local brain = cerebroAmigable(zombie)
        if brain then
            porNombre[brain.fullname] = zombie
            nombrePorZombie[zombie] = brain.fullname
        end
    end
    return porNombre
end

local function desvio(n)
    return ZombRand(n * 2 + 1) - n
end

local function pedirCuerpo(jugador, colono, territorio)
    colono.clan = colono.clan or CLANES[ZombRand(#CLANES) + 1]
    sendClientCommand(jugador, "Spawner", "Clan", {
        cid = colono.clan,
        x = territorio.x + desvio(DISPERSION),
        y = territorio.y + desvio(DISPERSION),
        z = 0,
        size = 1,
        program = PROGRAMA,
        hostile = false,
        hostileP = false,
        permanent = true,
        fullname = colono.nombre,
    })
    pedidos[colono.id] = true
    registro()[colono.nombre] = true
    print("[WorldQuest] Cuerpo pedido para " .. colono.nombre)
end

-- El cuerpo de un ex colono deja la base y sigue por su cuenta
local function soltar(zombie, nombre)
    local brain = BanditBrain.Get(zombie)
    Bandit.SetSleeping(zombie, false)
    Bandit.ClearTasks(zombie)
    Bandit.SetProgram(zombie, PROGRAMA_SALIDA, {})
    Bandit.ForceSyncPart(zombie, { id = brain.id, sleeping = false, program = brain.program })
    registro()[nombre] = nil
    print("[WorldQuest] " .. nombre .. " deja la base")
end

local function alPasarDiezMinutos()
    if not Cuerpos.activo() then
        return
    end
    local jugador = getPlayer()
    if not jugador then
        return
    end

    local Colonos = WorldQuest.Colonos
    local cuerpos = cuerposCercanos()
    local nombresActuales = {}

    for _, territorio in ipairs(WorldQuest.Territorios.getDatos().lista) do
        local colonos = Colonos.delTerritorio(territorio)
        for _, colono in ipairs(colonos) do
            nombresActuales[colono.nombre] = true
        end

        if getCell():getGridSquare(territorio.x, territorio.y, 0) then
            ticksCargado[territorio.id] = (ticksCargado[territorio.id] or 0) + 1
            if ticksCargado[territorio.id] >= ESPERA_TICKS then
                for _, colono in ipairs(colonos) do
                    if not cuerpos[colono.nombre] and not pedidos[colono.id] then
                        pedirCuerpo(jugador, colono, territorio)
                    end
                end
            end
        else
            -- Al descargarse, se puede volver a pedir cuando regreses
            ticksCargado[territorio.id] = 0
            for _, colono in ipairs(colonos) do
                pedidos[colono.id] = nil
            end
        end
    end

    -- Cuerpos creados por WorldQuest cuyo colono ya no esta: se van
    local creados = registro()
    for nombre, zombie in pairs(cuerpos) do
        if creados[nombre] and not nombresActuales[nombre] then
            soltar(zombie, nombre)
        end
    end
end

-- Si muere el cuerpo, muere el colono
local function onZombieDead(zombie)
    if not Cuerpos.activo() then
        return
    end

    local nombre = nombrePorZombie[zombie]
    local brain = zombie:getVariableBoolean("Bandit") and BanditBrain.Get(zombie) or nil
    if brain and brain.fullname then
        nombre = brain.fullname
    end
    nombrePorZombie[zombie] = nil
    if not nombre or not registro()[nombre] then
        return
    end

    local lista = WorldQuest.Colonos.getDatos().lista
    for i = #lista, 1, -1 do
        local colono = lista[i]
        if colono.nombre == nombre then
            table.remove(lista, i)
            -- Diagnostico: quien lo ataco por ultima vez
            local ok, atacante = pcall(function() return zombie:getAttackedBy() end)
            local quien = "desconocido"
            if ok and atacante then
                if instanceof(atacante, "IsoPlayer") then
                    quien = "el jugador"
                elseif atacante:getVariableBoolean("Bandit") and BanditBrain.Get(atacante) then
                    quien = "el NPC " .. tostring(BanditBrain.Get(atacante).fullname)
                else
                    quien = "un zombie"
                end
            end
            print("[WorldQuest] " .. nombre .. " fue atacado por " .. quien)
            registro()[nombre] = nil
            local territorio = WorldQuest.Territorios.buscarPorId(colono.territorio)
            local texto = getText("IGUI_WQ_ColonoMuerto", colono.nombre, territorio and territorio.nombre or "?")
            if WorldQuest.Banner then
                WorldQuest.Banner.mostrar(texto, "crisis")
            end
            print("[WorldQuest] " .. texto)
            return
        end
    end
end

Events.EveryTenMinutes.Add(alPasarDiezMinutos)
Events.OnZombieDead.Add(onZombieDead)
