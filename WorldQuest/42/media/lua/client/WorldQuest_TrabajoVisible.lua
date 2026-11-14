-- WorldQuest - Trabajo visible (cliente, capa opcional con Bandits)
-- Con el mod Bandits, el cuerpo de cada colono camina a su lugar de trabajo segun su
-- rol y se queda ahi: agricultores en los huertos, constructores en la obra, guardias
-- en el borde (hacia la amenaza si hay una), medicos al centro. Sin Bandits no hace nada.
-- Las ordenes del mapa de mando mandan por sobre esto.

require "WorldQuest_MapaMando"

WorldQuest = WorldQuest or {}
WorldQuest.Trabajo = WorldQuest.Trabajo or {}

local Trabajo = WorldQuest.Trabajo
local Mando = WorldQuest.MapaMando

local DISTANCIA_CAMBIO = 3          -- casillas: si el lugar cambia menos que esto, no se reordena
local VIGENCIA_HUERTOS_MS = 300000  -- se vuelven a buscar los huertos cada 5 minutos

local destinos = {}                 -- nombre -> { x, y }
local huertos = {}                  -- id territorio -> { ms, lista = { {x, y} } }

local function buscarHuertos(t)
    local cache = huertos[t.id]
    local ahora = getTimestampMs()
    if cache and ahora - cache.ms < VIGENCIA_HUERTOS_MS then
        return cache.lista
    end
    local lista = {}
    local celda = getCell()
    for x = t.x - t.radio, t.x + t.radio, 2 do
        for y = t.y - t.radio, t.y + t.radio, 2 do
            if WorldQuest.Territorios.contiene(t, x, y) then
                local casilla = celda:getGridSquare(x, y, 0)
                if casilla then
                    local objetos = casilla:getObjects()
                    for i = 0, objetos:size() - 1 do
                        local sprite = objetos:get(i):getSprite()
                        local nombre = sprite and sprite:getName()
                        if nombre and string.find(nombre, "vegetation_farming", 1, true) then
                            table.insert(lista, { x = x, y = y })
                            break
                        end
                    end
                end
            end
        end
    end
    huertos[t.id] = { ms = ahora, lista = lista }
    return lista
end

local function enBorde(t, angulo, adentro)
    local r = math.max(2, t.radio - (adentro or 3))
    return math.floor(t.x + math.cos(angulo) * r), math.floor(t.y + math.sin(angulo) * r)
end

-- Amenaza avisada contra el territorio (para mandar a los guardias hacia ese lado)
local function amenaza(t)
    for _, p in ipairs(WorldQuest.Crisis.getDatos().pendientes) do
        if p.territorio == t.id and p.ox then
            return math.atan2(p.oy - t.y, p.ox - t.x)
        end
    end
    return nil
end

-- Lugar de trabajo de un colono (o nil si no tiene)
function Trabajo.lugar(colono, t, indice)
    local rol = colono.rol
    if rol == "agricultor" then
        local lista = buscarHuertos(t)
        if #lista > 0 then
            local h = lista[(indice % #lista) + 1]
            return h.x, h.y
        end
    elseif rol == "constructor" then
        if t.proyecto and t.proyecto.x then
            return t.proyecto.x + (indice % 2), t.proyecto.y + 1
        end
    elseif rol == "guardia" then
        local angulo = amenaza(t) or (indice * 2.4)
        return enBorde(t, angulo + (indice % 3 - 1) * 0.3, 3)
    elseif rol == "medico" then
        return t.x + 1, t.y + 1
    elseif rol == "explorador" then
        return enBorde(t, indice * 1.7, 1)
    end
    -- Sin lugar propio: junto al almacen
    local a = t.almacenes and t.almacenes[1]
    if a and rol ~= "ninguno" then
        return a.x + 1 + (indice % 2), a.y + 1
    end
    return nil
end

local function actualizar()
    local Cuerpos = WorldQuest.Cuerpos
    if isServer() or not Cuerpos or not Cuerpos.activo() then
        return
    end
    local jugador = getPlayer()
    if not jugador then
        return
    end
    local cuerpos = Cuerpos.cercanos()
    for _, t in ipairs(WorldQuest.Territorios.getDatos().lista) do
        if Cuerpos.soyResponsable(t, jugador) and getCell():getGridSquare(t.x, t.y, 0) then
            for i, colono in ipairs(WorldQuest.Colonos.delTerritorio(t)) do
                local nombre = colono.nombre
                local libre = colono.orden == nil and not colono.expedicion
                local x, y = nil, nil
                if libre and cuerpos[nombre] then
                    x, y = Trabajo.lugar(colono, t, i)
                end
                local anterior = destinos[nombre]
                if x then
                    if not anterior or math.abs(anterior.x - x) + math.abs(anterior.y - y) > DISTANCIA_CAMBIO then
                        if anterior then
                            Mando.soltarDestino(nombre)
                        end
                        destinos[nombre] = { x = x, y = y }
                        Mando.mover(nombre, x, y, 0)
                    end
                elseif anterior and libre then
                    -- Ya no tiene lugar de trabajo: vuelve a descansar en la base
                    destinos[nombre] = nil
                    Mando.soltarDestino(nombre)
                    Cuerpos.cambiarPrograma(nombre, "Camper")
                elseif anterior then
                    -- Una orden del mapa manda: se olvida el lugar de trabajo
                    destinos[nombre] = nil
                end
            end
        end
    end
end

Events.EveryTenMinutes.Add(actualizar)
