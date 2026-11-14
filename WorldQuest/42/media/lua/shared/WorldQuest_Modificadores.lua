-- WorldQuest - Modificadores: efectos de nivel, estructuras y obras sobre los demas sistemas

WorldQuest = WorldQuest or {}
WorldQuest.Modificadores = WorldQuest.Modificadores or {}

local M = WorldQuest.Modificadores

-- Efecto de la faccion duena del territorio (tabla en WorldQuest_Balance.lua)
local function efecto(t, clave)
    if WorldQuest.Balance then
        return WorldQuest.Balance.valor(t, clave)
    end
    return nil
end
M.efecto = efecto

local function nivel(t)
    return t.nivel or 1
end

function M.tieneMejora(t, id)
    return t.mejoras ~= nil and t.mejoras[id] == true
end

function M.estructura(t, id)
    return (t.estructuras and t.estructuras[id]) or 0
end

-- Colonos que estan en la base (los de expedicion no cuentan)
local function colonosDe(t)
    local resultado = {}
    if WorldQuest.Colonos then
        for _, c in ipairs(WorldQuest.Colonos.delTerritorio(t)) do
            if not c.expedicion then
                table.insert(resultado, c)
            end
        end
    end
    return resultado
end
M.colonosEnBase = colonosDe

-- Efecto de la especializacion de la base (WorldQuest_Economia.lua)
local function especial(t, clave, neutro)
    if WorldQuest.Economia then
        return WorldQuest.Economia.efectoEspecialidad(t, clave, neutro)
    end
    return neutro
end

-- Cupo de colonos: 3 base + 1 por cama, con tope segun el nivel
function M.cupo(t)
    local tope = 3
    if WorldQuest.Niveles then
        tope = WorldQuest.Niveles.datos(t).cupoMax
    end
    return math.max(1, math.min(tope, 3 + M.estructura(t, "camas") + (efecto(t, "cupo") or 0)))
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
    tamano = tamano * (efecto(t, "horda") or 1)
    return math.max(1, math.floor(tamano))
end

-- Avisos: la torre de vigilancia avisa 5 minutos antes (solo crisis con aviso)
function M.minutosAviso(t, base)
    if base <= 0 then
        return base
    end
    local minutos = base + (efecto(t, "aviso") or 0)
    if M.tieneMejora(t, "torre") then
        minutos = minutos + 5
    end
    return minutos
end

-- true si dos territorios son del mismo dueno (misma faccion, o mismo jugador si no tienen)
local function mismoDueno(a, b)
    if a.faccion or b.faccion then
        return a.faccion == b.faccion
    end
    return a.dueno == b.dueno
end

-- Llegadas: una radio en cualquier territorio del mismo dueno las duplica
function M.probabilidadLlegada(base, territorio)
    for _, t in ipairs(WorldQuest.Territorios.getDatos().lista) do
        if M.tieneMejora(t, "radio") and (territorio == nil or mismoDueno(t, territorio)) then
            base = base * 2
            break
        end
    end
    if territorio then
        base = base * (efecto(territorio, "llegadas") or 1)
        -- Una escuela o iglesia controlada atrae gente
        local duena = WorldQuest.Facciones and WorldQuest.Facciones.deTerritorio(territorio)
        if duena and WorldQuest.Mundo and WorldQuest.Mundo.controlaTipo(duena, "escuela") then
            base = base * 1.3
        end
        -- Con mala fama llegan menos sobrevivientes
        local f = WorldQuest.Facciones and WorldQuest.Facciones.deTerritorio(territorio)
        if f and WorldQuest.Diplomacia and WorldQuest.Diplomacia.malaFama(f) then
            base = base * 0.75
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
    return extra + (efecto(t, "animo") or 0) + especial(t, "animo", 0)
end

-- Produccion diaria de un rol: huertos ayudan al agricultor, el taller al constructor
function M.produccion(t, rol, base)
    if rol == "agricultor" then
        return (base + math.min(5, math.floor(M.estructura(t, "huertos") / 4))) * (efecto(t, "agricultor") or 1) * especial(t, "agricultor", 1)
    elseif rol == "constructor" then
        if M.tieneMejora(t, "taller") then
            base = base * 2
        end
        return base * (efecto(t, "troncos") or 1) * especial(t, "troncos", 1)
    elseif rol == "explorador" then
        return base * (efecto(t, "botin") or 1) * especial(t, "botin", 1)
    elseif rol == "metal" then
        return base * (efecto(t, "metal") or 1) * especial(t, "metal", 1)
    elseif rol == "medico" then
        return base * especial(t, "medicina", 1)
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
            -- Orden "defender aqui" del mapa de mando: suma como medio guardia
            if colono.orden and colono.orden.tipo == "defender" then
                defensa = defensa + 3 + colono.habilidades.combate
            end
        end
    end
    if M.tieneMejora(t, "torre") then
        defensa = defensa + 5
    end
    if M.tieneMejora(t, "muralla") then
        defensa = defensa + 15
    end
    -- Mercenarios contratados que cuidan la base
    if WorldQuest.Mercenarios then
        defensa = defensa + WorldQuest.Mercenarios.defensaExtra(t)
    end
    return math.floor(defensa * (efecto(t, "defensa") or 1) * especial(t, "defensa", 1))
end

-- Comida que come cada colono por ciclo en este territorio
function M.racion(t)
    return WorldQuest.Colonos.RACION * (efecto(t, "racion") or 1)
end

-- Animo bajo el cual un colono puede enloquecer (la resistencia lo baja)
function M.umbralLocura(t, base)
    return base - (efecto(t, "resistenciaLocura") or 0)
end

-- Riesgo (en %) de que un explorador no vuelva
function M.riesgoExplorador(t, base)
    return base * (efecto(t, "riesgo") or 1)
end

-- Porcentaje de comida que se pierde en la crisis de comida
function M.perdidaComida(t, base)
    return base * (efecto(t, "perdidaComida") or 1)
end

-- Porcentaje de comida y materiales que se llevan los asaltantes si ganan
function M.saqueo(t, base)
    return base * (efecto(t, "saqueo") or 1)
end

-- Trabajo de obra que aporta el territorio por ciclo, con la velocidad de la faccion
function M.obras(t, base)
    return base * (efecto(t, "obras") or 1)
end

-- Maximo de territorios de una faccion (nil = sin limite)
function M.maxTerritorios(f)
    if not f or not WorldQuest.Balance then
        return nil
    end
    return WorldQuest.Balance.efectos(f.tipo, f.rasgo).maxTerritorios
end
