-- WorldQuest - Tabla de balance de facciones y rasgos de lider
-- Regla: cada faccion tiene una ventaja fuerte, una menor y una debilidad que pesa
-- lo mismo que la ventaja fuerte. Los rasgos de lider son tres por faccion, de peso
-- parecido. Todos los numeros se ajustan jugando: cambiarlos aqui basta.
--
-- Claves de efecto:
--   multiplicadores (1 = sin cambio): agricultor, troncos, metal, botin, obras, defensa,
--     horda, llegadas, racion, riesgo, perdidaComida, saqueo, velocidad
--   sumas (0 = sin cambio): cupo, animo (por ciclo), resistenciaLocura, aviso (minutos)
--   limite: maxTerritorios

WorldQuest = WorldQuest or {}
WorldQuest.Balance = WorldQuest.Balance or {}

local B = WorldQuest.Balance

B.MULT = { agricultor = true, troncos = true, metal = true, botin = true, obras = true, defensa = true, horda = true,
    llegadas = true, racion = true, riesgo = true, perdidaComida = true, saqueo = true, velocidad = true }
B.SUMA = { cupo = true, animo = true, resistenciaLocura = true, aviso = true }

-- true si subir el numero le conviene a la faccion (para pintar verde o rojo)
B.BUENO_SUBIR = { agricultor = true, troncos = true, metal = true, velocidad = true, botin = true, obras = true, defensa = true,
    llegadas = true, cupo = true, animo = true, resistenciaLocura = true, aviso = true,
    horda = false, racion = false, riesgo = false, perdidaComida = false, saqueo = false, maxTerritorios = false }

-- Orden para mostrar los efectos
B.ORDEN = { "defensa", "horda", "saqueo", "agricultor", "troncos", "metal", "botin", "riesgo", "velocidad", "obras",
    "llegadas", "cupo", "animo", "resistenciaLocura", "racion", "perdidaComida", "aviso", "maxTerritorios" }

-- Efectos de cada faccion (lo que hoy se puede aplicar con los sistemas que existen)
B.FACCIONES = {
    -- Fuerte: defensa. Menor: disciplina. Debilidad: consumen mas
    leales      = { defensa = 1.3, resistenciaLocura = 10, racion = 1.25 },
    -- Fuerte: comida. Menor: animo. Debilidad: combate
    comuna      = { agricultor = 1.5, animo = 2, defensa = 0.75 },
    -- Fuerte: obras rapidas. Menor: mas madera y metal. Debilidad: poca comida
    chatarreros = { obras = 1.5, troncos = 1.3, metal = 1.4, agricultor = 0.6 },
    -- Fuerte: expediciones seguras (en lugar del comercio). Menor: mejor botin. Debilidad: 2 territorios
    caravana    = { riesgo = 0.5, botin = 1.2, maxTerritorios = 2 },
    -- Fuerte: saqueo. Menor: expediciones menos riesgosas. Debilidad: mala fama, llegan menos colonos
    carroneros  = { botin = 1.6, riesgo = 0.8, llegadas = 0.7 },
    -- Fuerte: atraen colonos. Menor: casi no enloquecen. Debilidad: economia lenta
    devotos     = { llegadas = 1.5, cupo = 1, resistenciaLocura = 15, agricultor = 0.85, troncos = 0.85, botin = 0.85 },
    -- Fuerte: movilidad (expediciones). Menor: (mercenarios, Fase 8). Debilidad: bases fragiles
    moteros     = { botin = 1.3, riesgo = 0.6, velocidad = 1.5, defensa = 0.75, horda = 1.2 },
    -- Fuerte: resisten asedios. Menor: racionan bien. Debilidad: crecen lento
    preppers    = { defensa = 1.2, saqueo = 0.5, perdidaComida = 0.25, racion = 0.85, llegadas = 0.5, cupo = -1 },
    -- Fuerte: combate y hordas. Menor: (criminales, Fase 8). Debilidad: poca disciplina
    fugados     = { defensa = 1.25, horda = 0.7, resistenciaLocura = -15, animo = -1 },
}

-- Efectos que llegan con sistemas futuros (se muestran como pendientes)
B.PENDIENTES = {
    leales = { "mercenarios" },
    caravana = { "comercio", "mercenarios" },
    carroneros = { "asaltos" },
    moteros = { "comercio", "asaltos", "mercenarios" },
    fugados = { "mercenarios", "caos" },
}

-- Rasgos de lider
B.RASGOS = {
    estratega    = { defensa = 1.15 },
    vigia        = { aviso = 3 },
    disciplinado = { resistenciaLocura = 8 },
    agronomo     = { agricultor = 1.2 },
    inspirador   = { animo = 1 },
    carismatico  = { llegadas = 1.25 },
    maestro      = { obras = 1.2 },
    intendente   = { racion = 0.85 },
    rastreador   = { botin = 1.2 },
}

B.RASGOS_DE = {
    leales      = { "estratega", "vigia", "disciplinado" },
    comuna      = { "agronomo", "inspirador", "carismatico" },
    chatarreros = { "maestro", "intendente", "estratega" },
    caravana    = { "rastreador", "carismatico", "intendente" },
    carroneros  = { "rastreador", "vigia", "maestro" },
    devotos     = { "inspirador", "carismatico", "disciplinado" },
    moteros     = { "rastreador", "vigia", "estratega" },
    preppers    = { "intendente", "estratega", "maestro" },
    fugados     = { "estratega", "inspirador", "rastreador" },
}

function B.rasgoValido(tipo, rasgo)
    for _, r in ipairs(B.RASGOS_DE[tipo] or {}) do
        if r == rasgo then
            return true
        end
    end
    return false
end

-- Junta los efectos de la faccion y del rasgo de su lider: clave -> valor
function B.efectos(tipo, rasgo)
    local total = {}
    local function sumar(tabla)
        for clave, valor in pairs(tabla or {}) do
            if B.MULT[clave] then
                total[clave] = (total[clave] or 1) * valor
            elseif B.SUMA[clave] then
                total[clave] = (total[clave] or 0) + valor
            else
                total[clave] = valor
            end
        end
    end
    sumar(B.FACCIONES[tipo])
    sumar(B.RASGOS[rasgo])
    return total
end

-- Valor de un efecto para un territorio (neutro si no tiene faccion)
local cache = {}
function B.valor(territorio, clave)
    local f = territorio and WorldQuest.Facciones and WorldQuest.Facciones.deTerritorio(territorio)
    local valor = nil
    if f then
        local llave = tostring(f.tipo) .. "/" .. tostring(f.rasgo)
        cache[llave] = cache[llave] or B.efectos(f.tipo, f.rasgo)
        valor = cache[llave][clave]
    end
    if valor == nil then
        if B.MULT[clave] then
            return 1
        elseif B.SUMA[clave] then
            return 0
        end
        return nil
    end
    return valor
end

-- Texto de un efecto ("Defensa +30%") y si es bueno para la faccion
function B.texto(clave, valor)
    local numero
    if B.MULT[clave] then
        local pct = math.floor((valor - 1) * 100 + 0.5)
        numero = (pct >= 0 and "+" or "") .. tostring(pct) .. "%"
    elseif B.SUMA[clave] then
        numero = (valor >= 0 and "+" or "") .. tostring(valor)
    else
        numero = tostring(valor)
    end
    local bueno
    if B.MULT[clave] then
        bueno = (valor >= 1) == B.BUENO_SUBIR[clave]
    elseif B.SUMA[clave] then
        bueno = (valor >= 0) == B.BUENO_SUBIR[clave]
    else
        bueno = false
    end
    return getText("IGUI_WQ_Efecto_" .. clave, numero), bueno
end

-- Lista ordenada de { texto, bueno } para mostrar
function B.lista(efectos)
    local resultado = {}
    for _, clave in ipairs(B.ORDEN) do
        local valor = efectos[clave]
        if valor ~= nil then
            local texto, bueno = B.texto(clave, valor)
            table.insert(resultado, { texto = texto, bueno = bueno })
        end
    end
    return resultado
end
