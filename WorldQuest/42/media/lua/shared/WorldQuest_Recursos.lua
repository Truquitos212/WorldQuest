-- WorldQuest - Los cinco recursos de la economia
-- Cada recurso cuenta muchos items reales del almacen:
--   comida (en calorias), madera (tablas y troncos; el tronco vale mas),
--   metal (clavos, chatarra, laminas, piezas), medicina y municion.
-- Sin moneda: todo es trueque. Los cigarros no son recurso, pero valen en el trueque.

WorldQuest = WorldQuest or {}
WorldQuest.Recursos = WorldQuest.Recursos or {}

local R = WorldQuest.Recursos

R.LISTA = { "comida", "madera", "metal", "medicina", "municion" }

-- Unidades por item, por tipo exacto
R.ITEMS = {
    -- madera
    ["Base.Plank"] = { "madera", 1 },
    ["Base.Log"] = { "madera", 3 },
    ["Base.LogStacks2"] = { "madera", 6 },
    ["Base.LogStacks3"] = { "madera", 9 },
    ["Base.LogStacks4"] = { "madera", 12 },
    ["Base.TreeBranch2"] = { "madera", 0.25 },
    ["Base.Firewood"] = { "madera", 0.5 },
    -- metal
    ["Base.Nails"] = { "metal", 0.1 },
    ["Base.NailsBox"] = { "metal", 10 },
    ["Base.NailsCarton"] = { "metal", 100 },
    ["Base.Screws"] = { "metal", 0.1 },
    ["Base.ScrewsBox"] = { "metal", 10 },
    ["Base.ScrapMetal"] = { "metal", 1 },
    ["Base.UnusableMetal"] = { "metal", 1 },
    ["Base.SmallSheetMetal"] = { "metal", 2 },
    ["Base.SheetMetal"] = { "metal", 4 },
    ["Base.MetalBar"] = { "metal", 2 },
    ["Base.MetalPipe"] = { "metal", 2 },
    ["Base.Wire"] = { "metal", 1 },
    ["Base.Hinge"] = { "metal", 0.5 },
    ["Base.IronIngot"] = { "metal", 5 },
    ["Base.SteelIngot"] = { "metal", 6 },
    -- medicina
    ["Base.Bandage"] = { "medicina", 1 },
    ["Base.AlcoholBandage"] = { "medicina", 1.5 },
    ["Base.RippedSheets"] = { "medicina", 0.5 },
    ["Base.Disinfectant"] = { "medicina", 2 },
    ["Base.AlcoholWipes"] = { "medicina", 1 },
    ["Base.Pills"] = { "medicina", 2 },
    ["Base.PillsAntiDep"] = { "medicina", 2 },
    ["Base.PillsBeta"] = { "medicina", 2 },
    ["Base.PillsVitamins"] = { "medicina", 1 },
    ["Base.Antibiotics"] = { "medicina", 4 },
    ["Base.SutureNeedle"] = { "medicina", 2 },
    ["Base.Splint"] = { "medicina", 1 },
    ["Base.FirstAidKit"] = { "medicina", 6 },
    -- municion (una unidad por bala)
    ["Base.Bullets9mm"] = { "municion", 1 },
    ["Base.Bullets9mmBox"] = { "municion", 50 },
    ["Base.Bullets45"] = { "municion", 1 },
    ["Base.Bullets45Box"] = { "municion", 50 },
    ["Base.Bullets38"] = { "municion", 1 },
    ["Base.Bullets38Box"] = { "municion", 50 },
    ["Base.Bullets44"] = { "municion", 1 },
    ["Base.Bullets44Box"] = { "municion", 50 },
    ["Base.ShotgunShells"] = { "municion", 1 },
    ["Base.ShotgunShellsBox"] = { "municion", 24 },
    ["Base.223Bullets"] = { "municion", 1 },
    ["Base.223Box"] = { "municion", 40 },
    ["Base.308Bullets"] = { "municion", 1 },
    ["Base.308Box"] = { "municion", 40 },
    ["Base.556Bullets"] = { "municion", 1 },
    ["Base.556Box"] = { "municion", 40 },
}

-- Valor de trueque de una unidad de cada recurso (comida: por cada 100 kcal)
R.VALOR = { comida = 1, madera = 1, metal = 1.5, medicina = 4, municion = 0.5, cigarros = 2 }

-- Lo que se usa al crear items de un recurso (produccion, botin, entregas)
R.TIPO_BASE = {
    comida = { "Base.TinnedBeans", "Base.TinnedSoup", "Base.CannedCorn" },
    madera = { "Base.Plank" },
    metal = { "Base.ScrapMetal" },
    medicina = { "Base.Bandage" },
    municion = { "Base.Bullets9mm", "Base.ShotgunShells" },
    cigarros = { "Base.Cigarettes" },
}

-- Recurso y unidades de un item (o nil). Comida en calorias.
function R.clasificar(item)
    if item:IsFood() then
        local calorias = item:getCalories()
        if not item:isRotten() and calorias > 0 then
            return "comida", calorias
        end
        return nil
    end
    local tipo = item:getFullType()
    local fila = R.ITEMS[tipo]
    if fila then
        return fila[1], fila[2]
    end
    if string.find(tipo, "Cigar", 1, true) then
        return "cigarros", 1
    end
    local ok, categoria = pcall(function() return item:getDisplayCategory() end)
    if ok then
        if categoria == "Ammo" then
            return "municion", 1
        elseif categoria == "FirstAid" then
            return "medicina", 1
        end
    end
    return nil
end

-- Tabla vacia con los cinco recursos y los cigarros
function R.vacio()
    return { comida = 0, madera = 0, metal = 0, medicina = 0, municion = 0, cigarros = 0 }
end

-- Valor de trueque de una tabla de recursos
function R.valor(recursos)
    local total = 0
    for clave, valor in pairs(R.VALOR) do
        local cantidad = recursos[clave] or 0
        if clave == "comida" then
            cantidad = cantidad / 100
        end
        total = total + cantidad * valor
    end
    return math.floor(total)
end

-- Numero corto para mostrar: 1234 -> 1.2k
function R.corto(n)
    n = math.floor(n or 0)
    if n >= 10000 then
        return tostring(math.floor(n / 1000)) .. "k"
    elseif n >= 1000 then
        return string.format("%.1fk", n / 1000)
    end
    return tostring(n)
end

function R.nombre(id)
    return getText("IGUI_WQ_Recurso_" .. id)
end

-- "20 madera, 4 metal" en el orden de la lista
function R.texto(tabla)
    local partes = {}
    for _, id in ipairs(R.LISTA) do
        if (tabla[id] or 0) > 0 then
            if id == "comida" then
                table.insert(partes, getText("IGUI_WQ_Recurso_kcal", R.corto(tabla[id])))
            else
                table.insert(partes, R.corto(tabla[id]) .. " " .. R.nombre(id))
            end
        end
    end
    if (tabla.cigarros or 0) > 0 then
        table.insert(partes, R.corto(tabla.cigarros) .. " " .. R.nombre("cigarros"))
    end
    return table.concat(partes, ", ")
end
