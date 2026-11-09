-- WorldQuest - Modificadores: efectos de nivel, estructuras y obras sobre los demas sistemas

WorldQuest = WorldQuest or {}
WorldQuest.Modificadores = WorldQuest.Modificadores or {}

local M = WorldQuest.Modificadores

local function nivel(t)
    return t.nivel or 1
end

function M.tieneMejora(t, id)
    return t.mejoras ~= nil and t.mejoras[id] == true
end

function M.estructura(t, id)
    return (t.estructuras and t.estructuras[id]) or 0
end

local function colonosDe(t)
    if WorldQuest.Colonos then
        return WorldQuest.Colonos.delTerritorio(t)
    end
    return {}
end

-- Cupo de colonos: 3 base + 1 por cama, con tope segun el nivel
function M.cupo(t)
    local tope = 3
    if WorldQuest.Niveles then
        tope = WorldQuest.Niveles.datos(t).cupoMax
    end
    return math.min(tope, 3 + M.estructura(t, "camas"))
end

-- Narrador mas agresivo mientras mas grande sea la base mas grande
function M.factorNarrador()
    local maximo = 1
    for _, t in ipairs(WorldQuest.Territorios.getDatos().lista) do
        maximo = math.max(maximo, nivel(t))
    end
    return 1 + 0.25 * (maximo - 1)
end

-- Horda: crece con el nivel, la muralla la reduce
function M.tamanoHorda(t, base)
    local tamano = base * nivel(t)
    if M.tieneMejora(t, "muralla") then
        tamano = tamano * 0.6
    end
    return math.max(1, math.floor(tamano))
end

-- Avisos: la torre de vigilancia avisa 5 minutos antes (solo crisis con aviso)
function M.minutosAviso(t, base)
    if base > 0 and M.tieneMejora(t, "torre") then
        return base + 5
    end
    return base
end

-- Llegadas: una radio en cualquier territorio las duplica
function M.probabilidadLlegada(base)
    for _, t in ipairs(WorldQuest.Territorios.getDatos().lista) do
        if M.tieneMejora(t, "radio") then
            return base * 2
        end
    end
    return base
end

-- Animo extra diario por comodidades y medico
function M.animoDiario(t)
    local extra = 0
    if M.estructura(t, "cocinas") > 0 then
        extra = extra + 2
    end
    if M.estructura(t, "generadores") > 0 then
        extra = extra + 2
    end
    for _, colono in ipairs(colonosDe(t)) do
        if colono.rol == "medico" then
            extra = extra + 3
            break
        end
    end
    return extra
end

-- Produccion diaria de un rol: huertos ayudan al agricultor, el taller al constructor
function M.produccion(t, rol, base)
    if rol == "agricultor" then
        return base + math.min(5, math.floor(M.estructura(t, "huertos") / 4))
    elseif rol == "constructor" and M.tieneMejora(t, "taller") then
        return base * 2
    end
    return base
end

-- Defensa contra asaltantes: guardias, combate de todos y obras
function M.defensa(t)
    local defensa = 0
    for _, colono in ipairs(colonosDe(t)) do
        if colono.rol == "guardia" then
            defensa = defensa + 5 + colono.habilidades.combate * 2
        else
            defensa = defensa + colono.habilidades.combate
        end
    end
    if M.tieneMejora(t, "torre") then
        defensa = defensa + 5
    end
    if M.tieneMejora(t, "muralla") then
        defensa = defensa + 15
    end
    return defensa
end
