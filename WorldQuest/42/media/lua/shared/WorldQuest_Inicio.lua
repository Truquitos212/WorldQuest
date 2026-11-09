-- WorldQuest - Modos de inicio: donde aparece cada jugador al empezar
-- Usa los mismos puntos de aparicion del juego (casas validas en cada pueblo).
-- El cliente junta los puntos y el servidor decide, para que el reparto sea uno solo.
--   Justo:        todos lo mas lejos posible entre si
--   Pueblo chico: todos en el mismo pueblo, en casas distintas
--   Aleatorio (STERAK): elige uno de estos escenarios para toda la partida
--     Vecinos:      dos jugadores por pueblo
--     Triangulo:    dos juntos en un pueblo y el tercero en el pueblo mas cercano
--     Mal comienzo: todos en los pueblos chicos (pocos puntos), igual de mal

WorldQuest = WorldQuest or {}
WorldQuest.Inicio = WorldQuest.Inicio or {}

local Inicio = WorldQuest.Inicio

Inicio.MODOS = { "libre", "justo", "pueblo", "aleatorio" }   -- en el orden de la opcion de partida
Inicio.ESCENARIOS = { "vecinos", "triangulo", "malcomienzo" }
local MAXIMO_PUNTOS_PUEBLO_CHICO = 2

function Inicio.modo()
    return Inicio.MODOS[WorldQuest.Opciones.modoInicio()] or "libre"
end

-- CLIENTE: puntos de aparicion del juego, sin repetir ---------------------
function Inicio.candidatos()
    local ok, regiones = pcall(function() return SpawnRegionMgr.getSpawnRegions() end)
    if not ok or type(regiones) ~= "table" then
        return {}
    end
    local vistos, lista = {}, {}
    for _, region in ipairs(regiones) do
        local pueblo = tostring(region.name or "?")
        for _, puntos in pairs(region.points or {}) do
            if type(puntos) == "table" then
                for _, p in ipairs(puntos) do
                    local x, y, z = p.posX, p.posY, p.posZ or 0
                    if p.worldX and p.worldY then
                        -- Formato antiguo (por celdas de 300)
                        x = p.worldX * 300 + (p.posX or 0)
                        y = p.worldY * 300 + (p.posY or 0)
                    end
                    if x and y then
                        local llave = x .. "," .. y .. "," .. z
                        if not vistos[llave] then
                            vistos[llave] = true
                            table.insert(lista, { x = x, y = y, z = z, pueblo = pueblo })
                        end
                    end
                end
            end
        end
    end
    return lista
end

-- SERVIDOR: reparto ---------------------------------------------------------

local function distancia(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

local function distanciaMinima(p, ocupados)
    local minima = nil
    for _, o in ipairs(ocupados) do
        local d = distancia(p, o)
        if not minima or d < minima then
            minima = d
        end
    end
    return minima or 1000000
end

-- El candidato mas lejos de todos los ocupados (empates al azar)
local function masLejano(candidatos, ocupados)
    local mejores, mejorDistancia = {}, -1
    for _, p in ipairs(candidatos) do
        local d = distanciaMinima(p, ocupados)
        if d > mejorDistancia + 0.5 then
            mejores, mejorDistancia = { p }, d
        elseif math.abs(d - mejorDistancia) <= 0.5 then
            table.insert(mejores, p)
        end
    end
    if #mejores == 0 then
        return nil
    end
    return mejores[ZombRand(#mejores) + 1]
end

local function masCercano(candidatos, a)
    local mejor, mejorDistancia = nil, nil
    for _, p in ipairs(candidatos) do
        local d = distancia(p, a)
        if not mejorDistancia or d < mejorDistancia then
            mejor, mejorDistancia = p, d
        end
    end
    return mejor
end

local function porPueblo(candidatos)
    local pueblos = {}
    for _, p in ipairs(candidatos) do
        pueblos[p.pueblo] = pueblos[p.pueblo] or {}
        table.insert(pueblos[p.pueblo], p)
    end
    return pueblos
end

local function ocupado(p, ocupados)
    for _, o in ipairs(ocupados) do
        if o.x == p.x and o.y == p.y and o.z == p.z then
            return true
        end
    end
    return false
end

local function libres(candidatos, ocupados)
    local lista = {}
    for _, p in ipairs(candidatos) do
        if not ocupado(p, ocupados) then
            table.insert(lista, p)
        end
    end
    return lista
end

-- Un punto por pueblo (el primero), para comparar pueblos entre si
local function representantes(pueblos)
    local lista = {}
    for nombre, puntos in pairs(pueblos) do
        table.insert(lista, { x = puntos[1].x, y = puntos[1].y, z = puntos[1].z, pueblo = nombre })
    end
    return lista
end

-- Punto dentro de un pueblo: uno libre lejos de los demas; si no hay, uno cualquiera
local function puntoEnPueblo(puntos, ocupados)
    local disponibles = libres(puntos, ocupados)
    if #disponibles > 0 then
        return masLejano(disponibles, ocupados)
    end
    return puntos[ZombRand(#puntos) + 1]
end

local function justo(candidatos, ocupados)
    local disponibles = libres(candidatos, ocupados)
    if #disponibles == 0 then
        disponibles = candidatos
    end
    return masLejano(disponibles, ocupados)
end

local function puebloChico(candidatos, ocupados, estado)
    local pueblos = porPueblo(candidatos)
    if not estado.pueblo or not pueblos[estado.pueblo] then
        local mejor, cantidad = nil, -1
        for nombre, puntos in pairs(pueblos) do
            if #puntos > cantidad then
                mejor, cantidad = nombre, #puntos
            end
        end
        estado.pueblo = mejor
    end
    return puntoEnPueblo(pueblos[estado.pueblo], ocupados)
end

local function vecinos(candidatos, ocupados, estado)
    local pueblos = porPueblo(candidatos)
    estado.porPueblo = estado.porPueblo or {}
    -- Un pueblo con un solo jugador recibe al siguiente
    for nombre, n in pairs(estado.porPueblo) do
        if n == 1 and pueblos[nombre] then
            estado.porPueblo[nombre] = 2
            return puntoEnPueblo(pueblos[nombre], ocupados)
        end
    end
    -- Si no, un pueblo nuevo lo mas lejos de los ocupados, mejor si tiene dos casas o mas
    local vacios, vaciosGrandes = {}, {}
    for _, r in ipairs(representantes(pueblos)) do
        if not estado.porPueblo[r.pueblo] then
            table.insert(vacios, r)
            if #pueblos[r.pueblo] >= 2 then
                table.insert(vaciosGrandes, r)
            end
        end
    end
    if #vaciosGrandes > 0 then
        vacios = vaciosGrandes
    end
    local elegido = masLejano(#vacios > 0 and vacios or representantes(pueblos), ocupados)
    estado.porPueblo[elegido.pueblo] = (estado.porPueblo[elegido.pueblo] or 0) + 1
    return puntoEnPueblo(pueblos[elegido.pueblo], ocupados)
end

local function triangulo(candidatos, ocupados, estado)
    local pueblos = porPueblo(candidatos)
    estado.grupos = estado.grupos or {}
    for _, g in ipairs(estado.grupos) do
        if g.n == 1 and pueblos[g.pueblo] then
            -- El segundo, pegado al primero
            g.n = 2
            return masCercano(pueblos[g.pueblo], g.primero)
        elseif g.n == 2 then
            -- El tercero, en el pueblo mas cercano que no sea el del grupo
            g.n = 3
            local otros = {}
            for _, r in ipairs(representantes(pueblos)) do
                if r.pueblo ~= g.pueblo then
                    table.insert(otros, r)
                end
            end
            local cerca = masCercano(otros, g.primero)
            if cerca then
                return puntoEnPueblo(pueblos[cerca.pueblo], ocupados)
            end
            return puntoEnPueblo(pueblos[g.pueblo], ocupados)
        end
    end
    -- Grupo nuevo, lejos de los otros grupos
    local usados = {}
    for _, g in ipairs(estado.grupos) do
        usados[g.pueblo] = true
    end
    local vacios = {}
    for _, r in ipairs(representantes(pueblos)) do
        if not usados[r.pueblo] then
            table.insert(vacios, r)
        end
    end
    local elegido = masLejano(#vacios > 0 and vacios or representantes(pueblos), ocupados)
    local punto = puntoEnPueblo(pueblos[elegido.pueblo], ocupados)
    table.insert(estado.grupos, { pueblo = elegido.pueblo, n = 1, primero = { x = punto.x, y = punto.y, z = punto.z } })
    return punto
end

local function malComienzo(candidatos, ocupados)
    local pueblos = porPueblo(candidatos)
    local chicos = {}
    for _, puntos in pairs(pueblos) do
        if #puntos <= MAXIMO_PUNTOS_PUEBLO_CHICO then
            for _, p in ipairs(puntos) do
                table.insert(chicos, p)
            end
        end
    end
    return justo(#chicos > 0 and chicos or candidatos, ocupados)
end

-- Elige el punto para un jugador nuevo. estado se guarda entre llamadas.
function Inicio.elegir(escenario, candidatos, ocupados, estado)
    if #candidatos == 0 then
        return nil
    end
    if escenario == "pueblo" then
        return puebloChico(candidatos, ocupados, estado)
    elseif escenario == "vecinos" then
        return vecinos(candidatos, ocupados, estado)
    elseif escenario == "triangulo" then
        return triangulo(candidatos, ocupados, estado)
    elseif escenario == "malcomienzo" then
        return malComienzo(candidatos, ocupados)
    end
    return justo(candidatos, ocupados)
end
