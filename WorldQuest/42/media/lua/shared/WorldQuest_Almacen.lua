-- WorldQuest - Almacen de la colonia: datos y conteo de recursos

WorldQuest = WorldQuest or {}
WorldQuest.Almacen = WorldQuest.Almacen or {}

local Almacen = WorldQuest.Almacen
local MARCA = "WQ_Almacen" -- clave en el ModData del mueble: id del territorio
Almacen.CLAVE_NOMBRE = "WQ_AlmacenNombre" -- nombre propio del almacen (nil = nombre por defecto)

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

local function nombreSprite(objeto)
    local sprite = objeto:getSprite()
    return sprite and sprite:getName() or nil
end

-- true si la posicion guardada p corresponde al objeto
local function calza(p, objeto)
    local casilla = objeto:getSquare()
    return casilla ~= nil and p.x == casilla:getX() and p.y == casilla:getY() and p.z == casilla:getZ()
        and Almacen.tieneContenedor(objeto) and (p.sprite == nil or p.sprite == nombreSprite(objeto))
end

-- Devuelve el id del territorio dueno del almacen, o nil si no es almacen.
-- Si la marca del mueble todavia no llego al cliente, se busca por su posicion.
function Almacen.territorioDe(objeto)
    local marca = objeto:getModData()[MARCA]
    if marca then
        return marca
    end
    if WorldQuest.Territorios then
        for _, t in ipairs(WorldQuest.Territorios.getDatos().lista) do
            for _, p in ipairs(t.almacenes or {}) do
                if calza(p, objeto) then
                    return t.id
                end
            end
        end
    end
    return nil
end

function Almacen.marcar(objeto, territorio)
    local casilla = objeto:getSquare()
    objeto:getModData()[MARCA] = territorio.id
    territorio.almacenes = territorio.almacenes or {}
    for _, p in ipairs(territorio.almacenes) do
        if p.x == casilla:getX() and p.y == casilla:getY() and p.z == casilla:getZ() then
            return
        end
    end
    table.insert(territorio.almacenes, { x = casilla:getX(), y = casilla:getY(), z = casilla:getZ(), sprite = nombreSprite(objeto) })
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

-- Muebles marcados como almacen del territorio (solo los que estan cargados).
-- Primero por la marca del mueble; si en esa casilla no hay ninguno marcado
-- (la marca aun no llega a este cliente), el mueble guardado en esa posicion.
function Almacen.objetos(territorio)
    local resultado = {}
    local celda = getCell()
    for _, p in ipairs(territorio.almacenes or {}) do
        local casilla = celda:getGridSquare(p.x, p.y, p.z)
        if casilla then
            local objetos = casilla:getObjects()
            local encontrado = false
            for i = 0, objetos:size() - 1 do
                local objeto = objetos:get(i)
                if objeto:getModData()[MARCA] == territorio.id then
                    table.insert(resultado, objeto)
                    encontrado = true
                end
            end
            if not encontrado then
                for i = 0, objetos:size() - 1 do
                    local objeto = objetos:get(i)
                    if calza(p, objeto) then
                        table.insert(resultado, objeto)
                        break
                    end
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
            Almacen.quitar(contenedor, item)
            faltan[recurso] = faltan[recurso] - 1
        end
    end)
end

-- ITEMS: en multijugador el servidor cambia el contenedor y avisa a los clientes

-- Agrega un item por tipo (por ejemplo "Base.Plank"); devuelve el item o nil
function Almacen.agregar(contenedor, tipo)
    local item = contenedor:AddItem(tipo)
    if item and isServer() then
        pcall(sendAddItemToContainer, contenedor, item)
    end
    return item
end

-- Saca un item del contenedor
function Almacen.quitar(contenedor, item)
    contenedor:DoRemoveItem(item)
    if isServer() then
        pcall(sendRemoveItemFromContainer, contenedor, item)
    end
end

-- Guarda los cambios del ModData del mueble y los manda a los clientes
function Almacen.guardarMueble(objeto)
    if isServer() then
        pcall(function() objeto:transmitModData() end)
    end
end
