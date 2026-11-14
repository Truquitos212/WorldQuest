-- WorldQuest - Diplomacia (servidor): guerra, paz, pactos, alianzas, tributos y reputacion
-- Solo el lider de una faccion hace diplomacia.

require "WorldQuest_Diplomacia"
require "WorldQuest_EconomiaServidor"

local D = WorldQuest.Diplomacia
local Red = WorldQuest.Red
local Facciones = WorldQuest.Facciones
local Territorios = WorldQuest.Territorios
local R = WorldQuest.Recursos

Red.agregarClave("WorldQuest_Diplomacia")

local MINUTOS_MIN_GUERRA = 5        -- antes de esto no se puede proponer paz
local MINUTOS_PROPUESTA = 8         -- lo que dura una propuesta sin respuesta
local MINUTOS_CASUS_BELLI = 10      -- tras un tributo negado, la guerra no cuesta reputacion
local MAX_TRIBUTO = { comida = 20000, madera = 300, metal = 150, medicina = 60, municion = 400, cigarros = 60 }

-- Lo que cuesta en reputacion pasar de un estado a otro
local COSTO = {
    guerraDesdeAlianza = 25,
    guerraDesdePacto = 15,
    guerraDesdeNeutral = 5,
    romperAlianza = 10,
    romperPacto = 5,
}

local function ahora()
    return getGameTime():getWorldAgeHours()
end

local function liderDe(jugador)
    local f = Facciones.deJugador(jugador)
    if not f or f.lider ~= jugador:getUsername() then
        if jugador then
            Red.decir(jugador, "IGUI_WQ_Dipl_SoloLider")
        end
        return nil
    end
    if WorldQuest.Conflicto and WorldQuest.Conflicto.esObservador(f) then
        return nil
    end
    return f
end

function D.cambiarReputacion(f, delta)
    if not f or delta == 0 then
        return
    end
    f.reputacion = math.max(0, math.min(100, D.reputacion(f) + delta))
    Red.cambio()
end

function D.fijarEstado(a, b, estado)
    local datos = D.getDatos()
    local k = D.llave(a.id, b.id)
    local anterior = datos.relaciones[k] or { estado = "neutral" }
    datos.relaciones[k] = { estado = estado, desde = ahora(), casusBelli = anterior.casusBelli }
    -- Las propuestas viejas entre los dos ya no sirven
    for i = #datos.propuestas, 1, -1 do
        local p = datos.propuestas[i]
        if (p.de == a.id and p.para == b.id) or (p.de == b.id and p.para == a.id) then
            if p.tipo ~= "tributo" then
                table.remove(datos.propuestas, i)
            end
        end
    end
    Red.cambio()
    if D.alCambiar then
        for _, funcion in ipairs(D.alCambiar) do
            pcall(funcion, a, b, estado, anterior.estado)
        end
    end
end

-- Otros sistemas se enteran de cada cambio de estado
function D.escuchar(funcion)
    D.alCambiar = D.alCambiar or {}
    table.insert(D.alCambiar, funcion)
end

function D.declararGuerra(a, b)
    local rel = D.relacion(a.id, b.id)
    if rel.estado == "guerra" then
        return false
    end
    local costo = COSTO.guerraDesdeNeutral
    if rel.estado == "alianza" then
        costo = COSTO.guerraDesdeAlianza
    elseif rel.estado == "pacto" then
        costo = COSTO.guerraDesdePacto
    end
    local cb = rel.casusBelli
    if cb and cb.faccion == a.id and ahora() <= cb.hasta then
        costo = 0
    end
    D.cambiarReputacion(a, -costo)
    D.fijarEstado(a, b, "guerra")
    Red.avisar("IGUI_WQ_Dipl_Guerra", { a.nombre, b.nombre }, "crisis")
    print("[WorldQuest] Guerra: " .. a.nombre .. " contra " .. b.nombre .. " (reputacion -" .. costo .. ")")
    return true
end

-- TRIBUTOS --------------------------------------------------------------------------

-- Territorio de la faccion cargado y con suficiente del recurso (o nil)
local function territorioQuePaga(f, recurso, cantidad)
    for _, t in ipairs(Territorios.getDatos().lista) do
        if t.faccion == f.id and WorldQuest.Crisis.estaCargado(t) then
            local c = WorldQuest.Almacen.contar(t)
            if (c[recurso] or 0) >= cantidad then
                return t
            end
        end
    end
    return nil
end

-- Territorio donde una faccion recibe lo que le mandan: el del puesto de mando, si no el primero
function D.territorioPrincipal(f)
    if f.puesto then
        local t = Territorios.buscarPorId(f.puesto.territorio)
        if t and t.faccion == f.id then
            return t
        end
    end
    for _, t in ipairs(Territorios.getDatos().lista) do
        if t.faccion == f.id then
            return t
        end
    end
    return nil
end

-- Pasa recursos de una faccion a otra. Devuelve true si se pudo.
function D.transferir(desde, hacia, recurso, cantidad)
    local origen = territorioQuePaga(desde, recurso, cantidad)
    local destino = D.territorioPrincipal(hacia)
    if not origen or not destino then
        return false
    end
    local sacados = WorldQuest.Almacen.sacar(origen, recurso, cantidad)
    local items = {}
    for _, tipo in ipairs(sacados) do
        items[tipo] = (items[tipo] or 0) + 1
    end
    WorldQuest.Economia.entregar(destino, nil, items)
    WorldQuest.Economia.actualizarConteo(origen)
    return true
end

-- ORDENES ---------------------------------------------------------------------------

Red.orden("declararGuerra", function(jugador, args)
    local a = liderDe(jugador)
    local b = Facciones.porId(tonumber(args.faccion))
    if not a or not b or a == b then
        return
    end
    D.declararGuerra(a, b)
end)

Red.orden("romperTrato", function(jugador, args)
    local a = liderDe(jugador)
    local b = Facciones.porId(tonumber(args.faccion))
    if not a or not b or a == b then
        return
    end
    local estado = D.estado(a.id, b.id)
    if estado == "alianza" then
        D.cambiarReputacion(a, -COSTO.romperAlianza)
    elseif estado == "pacto" then
        D.cambiarReputacion(a, -COSTO.romperPacto)
    else
        return
    end
    D.fijarEstado(a, b, "neutral")
    Red.avisar("IGUI_WQ_Dipl_Roto", { a.nombre, b.nombre, { clave = "IGUI_WQ_Estado_" .. estado } }, "aviso")
end)

Red.orden("proponer", function(jugador, args)
    local a = liderDe(jugador)
    local b = Facciones.porId(tonumber(args.faccion))
    local tipo = args.tipo
    if not a or not b or a == b then
        return
    end
    local rel = D.relacion(a.id, b.id)
    local estado = rel.estado
    local valida = (tipo == "paz" and estado == "guerra")
        or (tipo == "pacto" and estado == "neutral")
        or (tipo == "alianza" and (estado == "neutral" or estado == "pacto"))
        or (tipo == "tributo")
    if not valida then
        Red.decir(jugador, "IGUI_WQ_Dipl_NoValida")
        return
    end
    if tipo == "paz" and WorldQuest.Reloj.minutosDePartida(ahora() - (rel.desde or 0)) < MINUTOS_MIN_GUERRA then
        Red.decir(jugador, "IGUI_WQ_Dipl_GuerraReciente", { tostring(MINUTOS_MIN_GUERRA) })
        return
    end

    local propuesta = { de = a.id, para = b.id, tipo = tipo,
        expira = ahora() + WorldQuest.Reloj.horasDeJuego(MINUTOS_PROPUESTA) }
    if tipo == "tributo" then
        local recurso = args.recurso
        local cantidad = math.floor(tonumber(args.cantidad) or 0)
        if not MAX_TRIBUTO[recurso] or cantidad <= 0 then
            return
        end
        propuesta.recurso = recurso
        propuesta.cantidad = math.min(cantidad, MAX_TRIBUTO[recurso])
        propuesta.direccion = (args.direccion == "pide") and "pide" or "ofrece"
    end

    local datos = D.getDatos()
    for _, p in ipairs(datos.propuestas) do
        if p.de == a.id and p.para == b.id and p.tipo == tipo then
            Red.decir(jugador, "IGUI_WQ_Dipl_YaPropuesto")
            return
        end
    end
    propuesta.id = datos.siguienteId
    datos.siguienteId = datos.siguienteId + 1
    table.insert(datos.propuestas, propuesta)
    Red.cambio()

    local args2 = { a.nombre, { clave = "IGUI_WQ_Propuesta_" .. tipo } }
    if tipo == "tributo" then
        local clave = propuesta.direccion == "pide" and "IGUI_WQ_Dipl_PideTributo" or "IGUI_WQ_Dipl_OfreceTributo"
        args2 = { a.nombre, R.texto({ [propuesta.recurso] = propuesta.cantidad }) }
        Red.avisarFaccion(b, clave, args2, "aviso")
    else
        Red.avisarFaccion(b, "IGUI_WQ_Dipl_Propone", args2, "aviso")
    end
    Red.decir(jugador, "IGUI_WQ_Dipl_Enviada", { b.nombre })
    local lider = Red.jugador(b.lider)
    if lider and (isServer() or lider:getUsername() == b.lider) then
        Red.enviar("propuesta", { id = propuesta.id, tipo = tipo, de = a.nombre, recurso = propuesta.recurso,
            cantidad = propuesta.cantidad, direccion = propuesta.direccion }, lider)
    end
end)

local function quitarPropuesta(id)
    local lista = D.getDatos().propuestas
    for i = #lista, 1, -1 do
        if lista[i].id == id then
            local p = lista[i]
            table.remove(lista, i)
            Red.cambio()
            return p
        end
    end
    return nil
end

Red.orden("responderPropuesta", function(jugador, args)
    local b = liderDe(jugador)
    local id = tonumber(args.id)
    if not b or not id then
        return
    end
    local p = nil
    for _, q in ipairs(D.getDatos().propuestas) do
        if q.id == id and q.para == b.id then
            p = q
        end
    end
    if not p then
        return
    end
    local a = Facciones.porId(p.de)
    quitarPropuesta(id)
    if not a then
        return
    end

    if args.acepta ~= true then
        Red.avisarFaccion(a, "IGUI_WQ_Dipl_Rechazada", { b.nombre, { clave = "IGUI_WQ_Propuesta_" .. p.tipo } }, "aviso")
        if p.tipo == "tributo" and p.direccion == "pide" then
            -- Negar un tributo da motivo para la guerra sin perder reputacion
            local datos = D.getDatos()
            local k = D.llave(a.id, b.id)
            local rel = datos.relaciones[k] or { estado = "neutral" }
            rel.casusBelli = { faccion = a.id, hasta = ahora() + WorldQuest.Reloj.horasDeJuego(MINUTOS_CASUS_BELLI) }
            datos.relaciones[k] = rel
            Red.avisarFaccion(a, "IGUI_WQ_Dipl_CasusBelli", { b.nombre, tostring(MINUTOS_CASUS_BELLI) }, "aviso")
        end
        return
    end

    if p.tipo == "paz" then
        D.fijarEstado(a, b, "neutral")
        Red.avisar("IGUI_WQ_Dipl_Paz", { a.nombre, b.nombre }, "aviso")
    elseif p.tipo == "pacto" then
        D.fijarEstado(a, b, "pacto")
        Red.avisar("IGUI_WQ_Dipl_Pacto", { a.nombre, b.nombre }, "aviso")
    elseif p.tipo == "alianza" then
        D.fijarEstado(a, b, "alianza")
        Red.avisar("IGUI_WQ_Dipl_Alianza", { a.nombre, b.nombre }, "aviso")
    elseif p.tipo == "tributo" then
        local paga, recibe = a, b
        if p.direccion == "pide" then
            paga, recibe = b, a
        end
        local texto = R.texto({ [p.recurso] = p.cantidad })
        if D.transferir(paga, recibe, p.recurso, p.cantidad) then
            if p.direccion == "ofrece" then
                D.cambiarReputacion(paga, 3)
            end
            Red.avisarFaccion(recibe, "IGUI_WQ_Dipl_TributoRecibido", { paga.nombre, texto }, "aviso")
            Red.avisarFaccion(paga, "IGUI_WQ_Dipl_TributoPagado", { recibe.nombre, texto }, "aviso")
        else
            Red.avisarFaccion(paga, "IGUI_WQ_Dipl_TributoSinRecursos", { texto }, "crisis")
            Red.avisarFaccion(recibe, "IGUI_WQ_Dipl_TributoFallo", { paga.nombre }, "aviso")
        end
    end
end)

-- CICLO: propuestas vencidas y reputacion que vuelve de a poco a lo normal --------

local function alPasarCiclo(ciclo)
    local datos = D.getDatos()
    local h = ahora()
    for i = #datos.propuestas, 1, -1 do
        local p = datos.propuestas[i]
        if h > p.expira or not Facciones.porId(p.de) or not Facciones.porId(p.para) then
            table.remove(datos.propuestas, i)
        end
    end
    if ciclo % 3 == 0 then
        for _, f in ipairs(Facciones.getDatos().lista) do
            local normal = D.REPUTACION_INICIAL_DE[f.tipo] or D.REPUTACION_INICIAL
            local r = D.reputacion(f)
            if r < normal then
                f.reputacion = r + 1
            elseif r > normal then
                f.reputacion = r - 1
            end
        end
    end
    -- Relaciones con facciones que ya no existen
    for k, _ in pairs(datos.relaciones) do
        local a, b = k:match("^(%d+)-(%d+)$")
        if not Facciones.porId(tonumber(a)) or not Facciones.porId(tonumber(b)) then
            datos.relaciones[k] = nil
        end
    end
end

WorldQuest.Reloj.alCiclo(alPasarCiclo)
