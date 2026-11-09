-- WorldQuest - Pistas de primera vez (cliente)
-- Una pista corta la primera vez que aparece algo nuevo; despues se puede releer
-- en la pestana Ayuda del Centro de mando. Nunca cuentan lo que viene despues.

WorldQuest = WorldQuest or {}
WorldQuest.Pistas = WorldQuest.Pistas or {}

local Pistas = WorldQuest.Pistas
local CLAVE = "WQ_Pistas"            -- en el ModData del jugador
local ESPERA_INICIAL_MS = 20000      -- no molestar apenas carga la partida
local ESPERA_ENTRE_MS = 25000        -- una pista a la vez

local inicio = nil
local ultima = 0

-- Territorio propio mas cercano (o nil)
local function propio(jugador)
    local mejor, mejorDistancia = nil, nil
    for _, t in ipairs(WorldQuest.Territorios.getDatos().lista) do
        if WorldQuest.Territorios.esDueno(t, jugador) then
            local dx, dy = t.x - jugador:getX(), t.y - jugador:getY()
            local d = dx * dx + dy * dy
            if not mejorDistancia or d < mejorDistancia then
                mejor, mejorDistancia = t, d
            end
        end
    end
    return mejor
end

local function colonos(t)
    return t and WorldQuest.Colonos.delTerritorio(t) or {}
end

-- En orden: la primera que se cumpla y no se haya visto es la que sale
Pistas.LISTA = {
    { id = "faccion", cumple = function(j, t) return WorldQuest.Facciones.deJugador(j) == nil end },
    { id = "reclamar", cumple = function(j, t) return t == nil and WorldQuest.Facciones.deJugador(j) ~= nil end },
    { id = "almacen", cumple = function(j, t) return t ~= nil and #(t.almacenes or {}) == 0 end },
    { id = "puesto", cumple = function(j, t)
        local f = WorldQuest.Facciones.deJugador(j)
        return t ~= nil and f ~= nil and f.lider == j:getUsername() and f.puesto == nil
    end },
    { id = "colonos", cumple = function(j, t) return t ~= nil and #(t.almacenes or {}) > 0 and #colonos(t) == 0 end },
    { id = "roles", cumple = function(j, t)
        for _, c in ipairs(colonos(t)) do
            if c.rol == "ninguno" then return true end
        end
        return false
    end },
    { id = "mando", cumple = function(j, t) return #colonos(t) >= 2 end },
    { id = "hambre", cumple = function(j, t)
        for _, c in ipairs(colonos(t)) do
            if WorldQuest.Colonos.ciclosSinComer(c) > 0 then return true end
        end
        return false
    end },
    { id = "obras", cumple = function(j, t)
        for _, c in ipairs(colonos(t)) do
            if c.rol == "constructor" then return true end
        end
        return false
    end },
    { id = "mejorar", cumple = function(j, t)
        return t ~= nil and WorldQuest.Niveles.siguiente(t) ~= nil and WorldQuest.Niveles.puedeMejorar(t) == true
    end },
    { id = "crisis", cumple = function(j, t)
        if not t then return false end
        for _, p in ipairs(WorldQuest.Crisis.getDatos().pendientes) do
            if p.conAviso and p.territorio == t.id then return true end
        end
        return false
    end },
}

local function vistas()
    local jugador = getPlayer()
    if not jugador then
        return {}
    end
    local datos = jugador:getModData()
    datos[CLAVE] = datos[CLAVE] or {}
    return datos[CLAVE]
end

function Pistas.vista(id)
    return vistas()[id] == true
end

function Pistas.texto(id)
    return getText("IGUI_WQ_Pista_" .. id)
end

function Pistas.mostrar(id)
    vistas()[id] = true
    local texto = Pistas.texto(id)
    if WorldQuest.Banner and WorldQuest.Banner.mostrarPista then
        WorldQuest.Banner.mostrarPista(getText("IGUI_WQ_PistaTitulo", texto))
    end
    print("[WorldQuest] Pista: " .. id)
end

local function revisar()
    if isServer() then
        return
    end
    local jugador = getPlayer()
    if not jugador then
        return
    end
    local ahora = getTimestampMs()
    inicio = inicio or ahora
    if ahora - inicio < ESPERA_INICIAL_MS or ahora - ultima < ESPERA_ENTRE_MS then
        return
    end

    local t = propio(jugador)
    for _, pista in ipairs(Pistas.LISTA) do
        if not Pistas.vista(pista.id) then
            local ok, cumple = pcall(pista.cumple, jugador, t)
            if ok and cumple then
                Pistas.mostrar(pista.id)
                ultima = ahora
                return
            end
        end
    end
end

Events.EveryOneMinute.Add(revisar)
