-- WorldQuest - Estructuras: deteccion de lo que el jugador construyo en el territorio

require "WorldQuest_Territorios"

WorldQuest = WorldQuest or {}
WorldQuest.Estructuras = WorldQuest.Estructuras or {}

local Estructuras = WorldQuest.Estructuras
local Territorios = WorldQuest.Territorios
local PISOS = 3 -- se revisan los pisos 0, 1 y 2

local function nombreSprite(objeto)
    local sprite = objeto:getSprite()
    if sprite then
        return sprite:getName()
    end
    return nil
end

local function contiene(texto, parte)
    return texto ~= nil and string.find(texto, parte, 1, true) ~= nil
end

-- Cuenta camas, huertos, cocinas y generadores dentro del territorio
function Estructuras.revisar(t)
    local conteo = { camas = 0, huertos = 0, cocinas = 0, generadores = 0 }
    local casillasCama = 0
    local celda = getCell()

    for z = 0, PISOS - 1 do
        for x = t.x - t.radio, t.x + t.radio do
            for y = t.y - t.radio, t.y + t.radio do
                if Territorios.contiene(t, x, y) then
                    local casilla = celda:getGridSquare(x, y, z)
                    if casilla then
                        local objetos = casilla:getObjects()
                        for i = 0, objetos:size() - 1 do
                            local objeto = objetos:get(i)
                            local sprite = nombreSprite(objeto)
                            if contiene(sprite, "furniture_bedding") then
                                casillasCama = casillasCama + 1
                            elseif contiene(sprite, "vegetation_farming") then
                                conteo.huertos = conteo.huertos + 1
                            elseif instanceof(objeto, "IsoStove") or instanceof(objeto, "IsoBarbecue") or instanceof(objeto, "IsoFireplace") then
                                conteo.cocinas = conteo.cocinas + 1
                            elseif instanceof(objeto, "IsoGenerator") then
                                conteo.generadores = conteo.generadores + 1
                            end
                        end
                    end
                end
            end
        end
    end

    -- Cada cama ocupa 2 casillas
    conteo.camas = math.floor(casillasCama / 2)
    return conteo
end

-- Revisa y guarda el resultado en el territorio (solo si esta cargado)
function Estructuras.actualizar(t)
    if getCell():getGridSquare(t.x, t.y, 0) == nil then
        return
    end
    t.estructuras = Estructuras.revisar(t)
end
