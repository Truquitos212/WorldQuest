-- WorldQuest - Puntuacion y victoria (datos y reglas)
-- Varias formas de ganar en la misma partida:
--   Exodo: terminar primero el megaproyecto de evacuacion.
--   Dominacion: controlar la mayoria de los lugares importantes o eliminar a los demas.
--   Economia: llegar primero a cierta riqueza.
-- Cumplir una condicion no gana al instante: hay que mantenerla un rato con el
-- contador visible para todos. Si nadie gana antes del limite, gana quien va primero.
-- La logica corre en el servidor (server/WorldQuest_VictoriaServidor.lua).

WorldQuest = WorldQuest or {}
WorldQuest.Victoria = WorldQuest.Victoria or {}

local V = WorldQuest.Victoria
local CLAVE_DATOS = "WorldQuest_Victoria"

V.VIAS = { "exodo", "dominacion", "economia" }

-- Segun la duracion (rapida, normal, larga)
V.LIMITE_HORAS = { 6, 10, 12 }       -- final por tiempo (12 h es el tope absoluto)
V.MINUTOS_CUENTA = { 10, 12, 15 }    -- cuenta regresiva para ganar
V.META_RIQUEZA = { 3500, 6000, 10000 }
V.MINUTOS_PRESION = 0.8              -- desde este tramo del limite, el narrador aprieta

-- Exodo: lo que hay que pagar para empezar la evacuacion y los colonos que necesitas
V.EXODO_COSTO = { comida = 15000, medicina = 40, municion = 150, madera = 150, metal = 60 }
V.EXODO_COLONOS = 10
V.EXODO_SABOTAJE = 15                -- avance que se pierde con un sabotaje

-- Dominacion: parte de los lugares conocidos que hay que controlar
V.DOMINACION_PARTE = 0.55
V.DOMINACION_MINIMO = 3

-- Puntos
V.PUNTOS = { territorio = 10, nivel = 8, colonio = 3, riqueza = 1 / 20, ciudad = 15, batalla = 5, lugar = 5 }

function V.getDatos()
    local datos = ModData.getOrCreate(CLAVE_DATOS)
    datos.minutos = datos.minutos or 0
    datos.cuentas = datos.cuentas or {}       -- "idFaccion:via" -> minuto en que empezo
    datos.exodo = datos.exodo or {}           -- id faccion -> { avance, territorio }
    datos.historia = datos.historia or {}     -- { m, f = { [id] = { p, c, t, r } } }
    datos.batallas = datos.batallas or {}     -- { m, g, p }
    datos.eliminadas = datos.eliminadas or {} -- { m, f }
    return datos
end

local function indiceDuracion()
    return WorldQuest.Opciones.duracion()
end

function V.limiteMinutos()
    local horas = WorldQuest.Opciones.limiteHoras()
    if not horas or horas <= 0 then
        horas = V.LIMITE_HORAS[indiceDuracion()] or 10
    end
    return math.min(12, horas) * 60
end

function V.minutosCuenta()
    return V.MINUTOS_CUENTA[indiceDuracion()] or 12
end

function V.metaRiqueza()
    return V.META_RIQUEZA[indiceDuracion()] or 6000
end

function V.terminada()
    return V.getDatos().ganador ~= nil
end

local function territoriosDe(f)
    local lista = {}
    for _, t in ipairs(WorldQuest.Territorios.getDatos().lista) do
        if t.faccion == f.id then
            table.insert(lista, t)
        end
    end
    return lista
end
V.territoriosDe = territoriosDe

function V.colonosDe(f)
    local n = 0
    for _, t in ipairs(territoriosDe(f)) do
        n = n + #WorldQuest.Colonos.delTerritorio(t)
    end
    return n
end

-- Ciudades completas que controla la faccion
function V.ciudadesDe(f)
    local Mundo = WorldQuest.Mundo
    if not Mundo then
        return 0
    end
    local vistas, n = {}, 0
    for _, l in ipairs(Mundo.getDatos().lugares) do
        if not vistas[l.pueblo] then
            vistas[l.pueblo] = true
            if Mundo.tieneCiudad(f, l.pueblo) then
                n = n + 1
            end
        end
    end
    return n
end

-- Puntos de una faccion (los calcula el servidor y los guarda en f.puntos)
function V.calcularPuntos(f)
    if not f or (WorldQuest.Conflicto and WorldQuest.Conflicto.esObservador(f)) then
        return 0
    end
    local P = V.PUNTOS
    local puntos = 0
    for _, t in ipairs(territoriosDe(f)) do
        puntos = puntos + P.territorio + ((t.nivel or 1) - 1) * P.nivel
    end
    puntos = puntos + V.colonosDe(f) * P.colonio
    puntos = puntos + (f.riqueza or 0) * P.riqueza
    if WorldQuest.Mundo then
        for _, l in ipairs(WorldQuest.Mundo.deFaccion(f)) do
            local tipo = WorldQuest.Mundo.tipo(l.tipo)
            puntos = puntos + (tipo and tipo.puntos or 1) * P.lugar
        end
    end
    puntos = puntos + V.ciudadesDe(f) * P.ciudad
    puntos = puntos + (f.batallasGanadas or 0) * P.batalla
    local exodo = V.getDatos().exodo[tostring(f.id)]
    if exodo then
        puntos = puntos + math.floor((exodo.avance or 0) / 4)
    end
    return math.floor(puntos)
end

-- Facciones en juego ordenadas por puntos (la primera va ganando)
function V.tabla()
    local lista = {}
    for _, f in ipairs(WorldQuest.Facciones.getDatos().lista) do
        table.insert(lista, f)
    end
    table.sort(lista, function(a, b)
        local ea = WorldQuest.Conflicto and WorldQuest.Conflicto.esObservador(a)
        local eb = WorldQuest.Conflicto and WorldQuest.Conflicto.esObservador(b)
        if ea ~= eb then
            return not ea
        end
        if (a.puntos or 0) ~= (b.puntos or 0) then
            return (a.puntos or 0) > (b.puntos or 0)
        end
        return a.id < b.id
    end)
    return lista
end

function V.primera()
    local lista = V.tabla()
    local f = lista[1]
    if f and not (WorldQuest.Conflicto and WorldQuest.Conflicto.esObservador(f)) then
        return f
    end
    return nil
end

-- REQUISITOS DEL EXODO -----------------------------------------------------------

-- Territorio con helipuerto de la faccion (o nil)
function V.helipuerto(f)
    for _, t in ipairs(territoriosDe(f)) do
        if t.mejoras and t.mejoras.helipuerto then
            return t
        end
    end
    return nil
end

-- Contacto por radio militar: controlar una torre de radio o una base militar. Si en
-- el mundo todavia no se conoce ninguna, sirve la obra Radio.
function V.tieneRadioMilitar(f)
    local Mundo = WorldQuest.Mundo
    if Mundo then
        if Mundo.controlaTipo(f, "radio") or Mundo.controlaTipo(f, "militar") then
            return true
        end
        for _, l in ipairs(Mundo.getDatos().lugares) do
            if l.tipo == "radio" or l.tipo == "militar" then
                return false
            end
        end
    end
    for _, t in ipairs(territoriosDe(f)) do
        if t.mejoras and t.mejoras.radio then
            return true
        end
    end
    return false
end

-- Lista de requisitos { id, ok } para empezar la evacuacion
function V.requisitosExodo(f)
    local recursos = WorldQuest.Economia and WorldQuest.Economia.recursosFaccion(f) or {}
    local alcanza = true
    for r, n in pairs(V.EXODO_COSTO) do
        if (recursos[r] or 0) < n then
            alcanza = false
        end
    end
    return {
        { id = "radio", ok = V.tieneRadioMilitar(f) },
        { id = "helipuerto", ok = V.helipuerto(f) ~= nil },
        { id = "colonos", ok = V.colonosDe(f) >= V.EXODO_COLONOS },
        { id = "recursos", ok = alcanza },
    }
end

function V.exodo(f)
    return f and V.getDatos().exodo[tostring(f.id)] or nil
end

-- DOMINACION Y ECONOMIA ------------------------------------------------------------

function V.lugaresParaDominar()
    local total = WorldQuest.Mundo and #WorldQuest.Mundo.getDatos().lugares or 0
    return math.max(V.DOMINACION_MINIMO, math.ceil(total * V.DOMINACION_PARTE)), total
end

-- true si la faccion cumple la condicion de esa via ahora
function V.cumple(f, via)
    if not f or (WorldQuest.Conflicto and WorldQuest.Conflicto.esObservador(f)) then
        return false
    end
    if via == "exodo" then
        local e = V.exodo(f)
        return e ~= nil and (e.avance or 0) >= 100 and V.helipuerto(f) ~= nil
    elseif via == "dominacion" then
        local necesarios = V.lugaresParaDominar()
        if WorldQuest.Mundo and #WorldQuest.Mundo.deFaccion(f) >= necesarios then
            return true
        end
        -- Todas las demas eliminadas (si hubo rivales)
        local rivales, vivos = 0, 0
        for _, otra in ipairs(WorldQuest.Facciones.getDatos().lista) do
            if otra.id ~= f.id then
                rivales = rivales + 1
                if not (WorldQuest.Conflicto and WorldQuest.Conflicto.esObservador(otra)) then
                    vivos = vivos + 1
                end
            end
        end
        return rivales > 0 and vivos == 0
    elseif via == "economia" then
        return (f.riqueza or 0) >= V.metaRiqueza()
    end
    return false
end

-- Minutos que faltan de la cuenta regresiva (o nil si no corre)
function V.cuenta(f, via)
    local desde = V.getDatos().cuentas[tostring(f.id) .. ":" .. via]
    if not desde then
        return nil
    end
    return math.max(0, math.ceil(V.minutosCuenta() - (V.getDatos().minutos - desde)))
end

-- "1:05" a partir de minutos
function V.reloj(minutos)
    minutos = math.max(0, math.floor(minutos or 0))
    return string.format("%d:%02d", math.floor(minutos / 60), minutos % 60)
end
