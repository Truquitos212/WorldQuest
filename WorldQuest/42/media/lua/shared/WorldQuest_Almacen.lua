-- WorldQuest - Almacen de la colonia: datos y conteo de recursos

WorldQuest = WorldQuest or {}
WorldQuest.Almacen = WorldQuest.Almacen or {}

local Almacen = WorldQuest.Almacen
local MARCA = "WQ_Almacen" -- clave en el ModData del mueble

-- Materiales que cuenta el almacen: tipo de item -> recurso
Almacen.MATERIALES = {
    ["Base.Plank"] = "tablas",
    ["Base.Nails"] = "clavos",
    ["Base.Log"] = "troncos",
}

-- true si el objeto tiene al menos un contenedor
function Almacen.tieneContenedor(objeto)
    return objeto ~= nil and objeto:getContainerCount() > 0
end

-- Devuelve el id del territorio dueno del almacen, o nil si no es almacen
function Almacen.territorioDe(objeto)
    return objeto:getModData()[MARCA]
end

function Almacen.marcar(objeto, territorio)
    local casilla = objeto:getSquare()
    objeto:getModData()[MARCA] = territorio.id
    territorio.almacenes = territorio.almacenes or {}
    table.insert(territorio.almacenes, { x = casilla:getX(), y = casilla:getY(), z = casilla:getZ() })
end

function Almacen.desmarcar(objeto, territorio)
    local casilla = objeto:getSquare()
    objeto:getModData()[MARCA] = nil
    local lista = territorio.almacenes or {}
    for i = #lista, 1, -1 do
        local p = lista[i]
        if p.x == casilla:getX() and p.y == casilla:getY() and p.z == casilla:getZ() then
            table.remove(lista, i)
        end
    end
end

-- Muebles marcados como almacen del territorio (solo los que estan cargados)
function Almacen.objetos(territorio)
    local resultado = {}
    local celda = getCell()
    for _, p in ipairs(territorio.almacenes or {}) do
        local casilla = celda:getGridSquare(p.x, p.y, p.z)
        if casilla then
            local objetos = casilla:getObjects()
            for i = 0, objetos:size() - 1 do
                local objeto = objetos:get(i)
                if objeto:getModData()[MARCA] == territorio.id then
                    table.insert(resultado, objeto)
                end
            end
        end
    end
    return resultado
end

-- Llama a funcion(item, contenedor) para cada item de los almacenes
function Almacen.recorrerItems(territorio, funcion)
    for _, objeto in ipairs(Almacen.objetos(territorio)) do
        for c = 0, objeto:getContainerCount() - 1 do
            local contenedor = objeto:getContainerByIndex(c)
            local items = contenedor:getItems()
            for k = items:size() - 1, 0, -1 do
                funcion(items:get(k), contenedor)
            end
        end
    end
end

-- Cuenta los recursos del territorio
function Almacen.contar(territorio)
    local recursos = { comidas = 0, calorias = 0, tablas = 0, clavos = 0, troncos = 0 }
    Almacen.recorrerItems(territorio, function(item)
        if item:IsFood() then
            recursos.comidas = recursos.comidas + 1
            recursos.calorias = recursos.calorias + math.max(0, item:getCalories())
        else
            local material = Almacen.MATERIALES[item:getFullType()]
            if material then
                recursos[material] = recursos[material] + 1
            end
        end
    end)
    recursos.calorias = math.floor(recursos.calorias)
    return recursos
end

-- Saca del almacen un costo, por ejemplo { tablas = 20, clavos = 40 }
function Almacen.gastar(territorio, costo)
    local faltan = {}
    for recurso, cantidad in pairs(costo) do
        faltan[recurso] = cantidad
    end
    Almacen.recorrerItems(territorio, function(item, contenedor)
        local recurso = Almacen.MATERIALES[item:getFullType()]
        if recurso and (faltan[recurso] or 0) > 0 then
            contenedor:DoRemoveItem(item)
            faltan[recurso] = faltan[recurso] - 1
        end
    end)
end
