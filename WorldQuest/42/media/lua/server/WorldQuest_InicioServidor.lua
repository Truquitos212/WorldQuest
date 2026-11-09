-- WorldQuest - Modos de inicio: el servidor asigna el punto de cada jugador nuevo

local Red = WorldQuest.Red
local Inicio = WorldQuest.Inicio
local CLAVE_DATOS = "WorldQuest_Inicio"   -- solo vive en el servidor

local function getDatos()
    local datos = ModData.getOrCreate(CLAVE_DATOS)
    datos.asignaciones = datos.asignaciones or {}
    datos.estado = datos.estado or {}
    return datos
end

-- Revisa y copia la lista de candidatos que manda el cliente
local function limpiar(lista)
    local resultado = {}
    if type(lista) ~= "table" then
        return resultado
    end
    for _, p in ipairs(lista) do
        local x, y, z = tonumber(p.x), tonumber(p.y), tonumber(p.z) or 0
        if x and y then
            table.insert(resultado, { x = math.floor(x), y = math.floor(y), z = math.floor(z), pueblo = tostring(p.pueblo or "?") })
        end
    end
    return resultado
end

Red.orden("pedirInicio", function(jugador, args)
    local modo = Inicio.modo()
    local usuario = jugador and jugador:getUsername()
    if modo == "libre" or not usuario then
        return
    end
    local datos = getDatos()
    if datos.asignaciones[usuario] then
        return -- ya tuvo su inicio en esta partida
    end

    -- La primera lista que llega queda como la de toda la partida
    if not datos.candidatos or #datos.candidatos == 0 then
        datos.candidatos = limpiar(args.puntos)
    end
    if #datos.candidatos == 0 then
        print("[WorldQuest] Inicio: no hay puntos de aparicion")
        return
    end

    -- Aleatorio: el escenario se elige una vez para toda la partida
    if not datos.escenario then
        if modo == "aleatorio" then
            datos.escenario = Inicio.ESCENARIOS[ZombRand(#Inicio.ESCENARIOS) + 1]
        else
            datos.escenario = modo
        end
    end

    local ocupados = {}
    for _, p in pairs(datos.asignaciones) do
        table.insert(ocupados, p)
    end
    local punto = Inicio.elegir(datos.escenario, datos.candidatos, ocupados, datos.estado)
    if not punto then
        return
    end
    datos.asignaciones[usuario] = { x = punto.x, y = punto.y, z = punto.z, pueblo = punto.pueblo }
    print("[WorldQuest] Inicio de " .. usuario .. ": " .. punto.pueblo .. " (" .. punto.x .. ", " .. punto.y .. ") escenario " .. datos.escenario)
    Red.enviar("inicio", {
        x = punto.x, y = punto.y, z = punto.z, pueblo = punto.pueblo,
        escenario = datos.escenario, aleatorio = (modo == "aleatorio"),
    }, jugador)
end)
