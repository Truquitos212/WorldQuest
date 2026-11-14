-- WorldQuest - Economia (servidor): conteo de recursos, entregas y expediciones

require "WorldQuest_Crisis"
require "WorldQuest_Economia"

local E = WorldQuest.Economia
local R = WorldQuest.Recursos
local Red = WorldQuest.Red
local Territorios = WorldQuest.Territorios
local Colonos = WorldQuest.Colonos
local Almacen = WorldQuest.Almacen
local Facciones = WorldQuest.Facciones
local M = WorldQuest.Modificadores

-- CONTEO: cada ciclo, el ultimo conteo de cada territorio cargado queda guardado ----

function E.actualizarConteo(t)
    if not WorldQuest.Crisis.estaCargado(t) then
        return
    end
    local c = Almacen.contar(t)
    local recursos = R.vacio()
    for clave, _ in pairs(recursos) do
        recursos[clave] = c[clave] or 0
    end
    t.recursos = recursos
end

local function alPasarCiclo()
    for _, t in ipairs(Territorios.getDatos().lista) do
        E.actualizarConteo(t)
        t.riqueza = E.riquezaTerritorio(t)
    end
    for _, f in ipairs(Facciones.getDatos().lista) do
        f.riqueza = E.riquezaFaccion(f)
    end
end

-- ENTREGAS: lo que llega a una base lejana se guarda hasta que este cargada ----------

-- recursos: { comida = kcal, madera = n, ... }; items: { ["Base.X"] = n }
function E.entregar(t, recursos, items)
    if not t then
        return
    end
    t.entregas = t.entregas or {}
    for clave, valor in pairs(recursos or {}) do
        if valor and valor > 0 then
            t.entregas[clave] = (t.entregas[clave] or 0) + valor
        end
    end
    if items then
        t.entregaItems = t.entregaItems or {}
        for tipo, n in pairs(items) do
            t.entregaItems[tipo] = (t.entregaItems[tipo] or 0) + n
        end
    end
    Red.cambio()
end

local function contenedorDe(t)
    for _, objeto in ipairs(Almacen.objetos(t)) do
        if objeto:getContainerCount() > 0 then
            return objeto:getContainerByIndex(0)
        end
    end
    return nil
end

local function repartirEntregas()
    if isClient() then
        return
    end
    for _, t in ipairs(Territorios.getDatos().lista) do
        if (t.entregas and next(t.entregas)) or (t.entregaItems and next(t.entregaItems)) then
            if WorldQuest.Crisis.estaCargado(t) then
                local contenedor = contenedorDe(t)
                if contenedor then
                    for clave, valor in pairs(t.entregas or {}) do
                        Almacen.agregarRecurso(contenedor, clave, valor)
                    end
                    for tipo, n in pairs(t.entregaItems or {}) do
                        for i = 1, math.min(n, 500) do
                            Almacen.agregar(contenedor, tipo)
                        end
                    end
                    t.entregas = nil
                    t.entregaItems = nil
                    Red.cambio()
                    print("[WorldQuest] Entregas guardadas en " .. t.nombre)
                end
            end
        end
    end
end

-- EXPEDICIONES ---------------------------------------------------------------------

-- Tipos de viaje: cada uno decide que pasa al llegar. Devuelve botin (recursos) o nil.
E.TIPOS_VIAJE = E.TIPOS_VIAJE or {}

local BOTIN_POR_TIRADA = { comida = 500, madera = 4, metal = 3, medicina = 2, municion = 12, cigarros = 2 }
local PESOS_BOTIN = { comida = 30, madera = 15, metal = 20, medicina = 12, municion = 15, cigarros = 8 }
local RIESGO_BASE = 6

local function recursoAlAzar(sesgo)
    local total = 0
    for clave, peso in pairs(PESOS_BOTIN) do
        total = total + peso + ((sesgo == clave) and 40 or 0)
    end
    local tiro = ZombRand(total)
    for _, clave in ipairs({ "comida", "madera", "metal", "medicina", "municion", "cigarros" }) do
        tiro = tiro - (PESOS_BOTIN[clave] + ((sesgo == clave) and 40 or 0))
        if tiro < 0 then
            return clave
        end
    end
    return "comida"
end

function E.colonosDeViaje(v)
    local resultado = {}
    local ids = {}
    for _, id in ipairs(v.colonos or {}) do
        ids[id] = true
    end
    for _, c in ipairs(Colonos.getDatos().lista) do
        if ids[c.id] then
            table.insert(resultado, c)
        end
    end
    return resultado
end

-- Quita colonos muertos en el viaje
function E.perderColono(colono, motivo)
    local lista = Colonos.getDatos().lista
    for i = #lista, 1, -1 do
        if lista[i] == colono then
            table.remove(lista, i)
        end
    end
    Colonos.registrarBaja(colono, motivo or "desaparecido")
end

-- Exploracion: botin segun la zona y la habilidad; algunos pueden no volver
E.TIPOS_VIAJE.exploracion = function(v, t, colonos)
    local botin = R.vacio()
    local sesgo = E.sesgoZona and E.sesgoZona(v.dx, v.dy) or nil
    local distancia = math.sqrt((v.dx - v.ox) ^ 2 + (v.dy - v.oy) ^ 2)
    local peligro = 1 + distancia / E.DISTANCIA_MAXIMA + (E.peligroZona and E.peligroZona(v.dx, v.dy) or 0)
    local muertos = {}
    for _, c in ipairs(colonos) do
        local riesgo = math.max(1, M.riesgoExplorador(t, (RIESGO_BASE - math.floor(c.habilidades.combate / 2)) * peligro))
        if ZombRand(100) < riesgo then
            table.insert(muertos, c)
        else
            local tiradas = 2 + math.floor(c.habilidades.exploracion / 3)
            for i = 1, tiradas do
                local r = recursoAlAzar(sesgo)
                botin[r] = botin[r] + BOTIN_POR_TIRADA[r]
            end
            if c.habilidades.exploracion < 10 and ZombRand(100) < 25 then
                c.habilidades.exploracion = c.habilidades.exploracion + 1
            end
        end
    end
    local factor = M.produccion(t, "explorador", 1) * WorldQuest.Opciones.produccion()
    for clave, valor in pairs(botin) do
        botin[clave] = math.floor(valor * factor)
    end
    return botin, muertos
end

-- Crea un viaje (lo usan las expediciones y, despues, espionaje, asaltos y caravanas)
function E.crearViaje(tipo, f, t, colonos, dx, dy, extra)
    local datos = E.getExpediciones()
    local distancia = math.sqrt((dx - t.x) ^ 2 + (dy - t.y) ^ 2)
    local ahora = getGameTime():getWorldAgeHours()
    local minutos = distancia / math.max(1, E.velocidad(t))
    local v = {
        id = datos.siguienteId,
        tipo = tipo,
        faccion = f.id,
        territorio = t.id,
        colonos = {},
        nombres = {},
        ox = t.x, oy = t.y, dx = math.floor(dx), dy = math.floor(dy),
        salida = ahora,
        llegada = ahora + WorldQuest.Reloj.horasDeJuego(minutos),
        minutosTramo = minutos,
    }
    for clave, valor in pairs(extra or {}) do
        v[clave] = valor
    end
    datos.siguienteId = datos.siguienteId + 1
    for _, c in ipairs(colonos) do
        c.expedicion = v.id
        c.orden = nil
        table.insert(v.colonos, c.id)
        table.insert(v.nombres, c.nombre)
    end
    table.insert(datos.lista, v)
    Red.cambio()
    return v
end

local function quitarViaje(v)
    local lista = E.getExpediciones().lista
    for i = #lista, 1, -1 do
        if lista[i] == v then
            table.remove(lista, i)
        end
    end
    for _, c in ipairs(E.colonosDeViaje(v)) do
        c.expedicion = nil
    end
    Red.cambio()
end
E.quitarViaje = quitarViaje

local function avanzarViajes()
    if isClient() then
        return
    end
    local ahora = getGameTime():getWorldAgeHours()
    local lista = E.getExpediciones().lista
    for i = #lista, 1, -1 do
        local v = lista[i]
        local t = Territorios.buscarPorId(v.territorio)
        local f = Facciones.porId(v.faccion)
        local colonos = E.colonosDeViaje(v)
        if not t or not f or (#colonos == 0 and not v.sinColonos) then
            quitarViaje(v)
        elseif not v.vuelta and ahora >= v.llegada then
            -- Llegaron: se resuelve lo que fueron a hacer
            local resolver = E.TIPOS_VIAJE[v.tipo] or E.TIPOS_VIAJE.exploracion
            local ok, botin, muertos = pcall(resolver, v, t, colonos)
            if not ok then
                print("[WorldQuest] Error al resolver el viaje " .. tostring(v.tipo) .. ": " .. tostring(botin))
                botin, muertos = nil, nil
            end
            for _, c in ipairs(muertos or {}) do
                E.perderColono(c, "desaparecido")
                Red.avisarFaccion(f, "IGUI_WQ_ExpedicionPerdio", { c.nombre }, "crisis")
            end
            v.botin = botin
            v.finExplorar = ahora + WorldQuest.Reloj.horasDeJuego(v.minutosExplorar or E.MINUTOS_EXPLORANDO)
            v.vuelta = v.finExplorar + WorldQuest.Reloj.horasDeJuego(v.minutosTramo or 0)
            Red.cambio()
            if v.sinVuelta then
                quitarViaje(v)
            end
        elseif v.vuelta and ahora >= v.vuelta then
            -- Volvieron a la base
            if v.botin and R.valor(v.botin) > 0 then
                E.entregar(t, v.botin)
                Red.avisarFaccion(f, "IGUI_WQ_ExpedicionVolvio", { t.nombre, R.texto(v.botin) }, "aviso")
            elseif v.tipo == "exploracion" then
                Red.avisarFaccion(f, "IGUI_WQ_ExpedicionVacia", { t.nombre }, "aviso")
            end
            if E.alVolver then
                pcall(E.alVolver, v, t, f)
            end
            quitarViaje(v)
        end
    end
end

-- ORDEN: enviar colonos de expedicion a un punto del mapa -------------------------

-- Colonos de la lista que son de la faccion del jugador, estan en la base y son del mismo territorio
function E.colonosParaViaje(jugador, ids, maximo)
    local f = Facciones.deJugador(jugador)
    local resultado, t = {}, nil
    if not f or type(ids) ~= "table" then
        return resultado, f, nil
    end
    local buscados = {}
    for _, id in ipairs(ids) do
        buscados[tonumber(id) or -1] = true
    end
    for _, c in ipairs(Colonos.getDatos().lista) do
        if buscados[c.id] and not c.expedicion then
            local suyo = Territorios.buscarPorId(c.territorio)
            if suyo and suyo.faccion == f.id and (t == nil or suyo == t) and #resultado < (maximo or E.MAX_COLONOS) then
                t = suyo
                table.insert(resultado, c)
            end
        end
    end
    return resultado, f, t
end

Red.orden("expedicion", function(jugador, args)
    local x, y = tonumber(args.x), tonumber(args.y)
    if not x or not y then
        return
    end
    local colonos, f, t = E.colonosParaViaje(jugador, args.colonos)
    if not f or not t or #colonos == 0 then
        Red.decir(jugador, "IGUI_WQ_ExpedicionSinColonos")
        return
    end
    if WorldQuest.Conflicto and WorldQuest.Conflicto.esObservador(f) then
        return
    end
    local distancia = math.sqrt((x - t.x) ^ 2 + (y - t.y) ^ 2)
    if distancia > E.DISTANCIA_MAXIMA then
        Red.decir(jugador, "IGUI_WQ_ExpedicionLejos", { tostring(E.DISTANCIA_MAXIMA) })
        return
    end
    if Territorios.contiene(t, x, y) then
        Red.decir(jugador, "IGUI_WQ_ExpedicionCerca")
        return
    end
    local v = E.crearViaje("exploracion", f, t, colonos, x, y)
    Red.avisarFaccion(f, "IGUI_WQ_ExpedicionSale", { tostring(#colonos), t.nombre, tostring(math.ceil(v.minutosTramo * 2 + E.MINUTOS_EXPLORANDO)) }, "aviso")
end)

-- Llamar de vuelta: el viaje se corta y vuelven desde donde esten
Red.orden("llamarExpedicion", function(jugador, args)
    local f = Facciones.deJugador(jugador)
    local id = tonumber(args.id)
    if not f or not id then
        return
    end
    local ahora = getGameTime():getWorldAgeHours()
    for _, v in ipairs(E.getExpediciones().lista) do
        if v.id == id and v.faccion == f.id and not v.vuelta then
            local x, y = E.posicionViaje(v, ahora)
            local recorrido = math.sqrt((x - v.ox) ^ 2 + (y - v.oy) ^ 2)
            local t = Territorios.buscarPorId(v.territorio)
            local minutos = recorrido / math.max(1, E.velocidad(t))
            v.dx, v.dy = math.floor(x), math.floor(y)
            v.llegada = ahora
            v.finExplorar = ahora
            v.vuelta = ahora + WorldQuest.Reloj.horasDeJuego(minutos)
            v.botin = nil
            v.cancelada = true
            Red.cambio()
            Red.decir(jugador, "IGUI_WQ_ExpedicionLlamada")
            return
        end
    end
end)

WorldQuest.Reloj.alCiclo(alPasarCiclo)
Events.EveryOneMinute.Add(avanzarViajes)
Events.EveryTenMinutes.Add(repartirEntregas)
