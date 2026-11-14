-- WorldQuest - Comercio (servidor): ofertas de trueque, caravanas y emboscadas
-- Una oferta aceptada saca los recursos de ambas bases y los manda en caravanas
-- que cruzan el mapa. Quien este en guerra con el dueno de una caravana puede emboscarla.

require "WorldQuest_Comercio"
require "WorldQuest_EconomiaServidor"
require "WorldQuest_Diplomacia"

local C = WorldQuest.Comercio
local E = WorldQuest.Economia
local R = WorldQuest.Recursos
local Red = WorldQuest.Red
local Facciones = WorldQuest.Facciones
local Territorios = WorldQuest.Territorios
local D = WorldQuest.Diplomacia
local M = WorldQuest.Modificadores

Red.agregarClave("WorldQuest_Comercio")

local MINUTOS_OFERTA = 10
local MAX_OFERTAS = 6
local ALCANCE_EMBOSCADA = 1500

local function ahora()
    return getGameTime():getWorldAgeHours()
end

local function miembro(jugador)
    local f = Facciones.deJugador(jugador)
    if f and WorldQuest.Conflicto and WorldQuest.Conflicto.esObservador(f) then
        return nil
    end
    return f
end

local function cantidadValida(recurso, cantidad)
    cantidad = math.floor(tonumber(cantidad) or 0)
    if not C.MAX_CANTIDAD[recurso] or cantidad <= 0 then
        return nil
    end
    return math.min(cantidad, C.MAX_CANTIDAD[recurso])
end

-- OFERTAS ---------------------------------------------------------------------------

Red.orden("ofertaComercio", function(jugador, args)
    local a = miembro(jugador)
    local b = Facciones.porId(tonumber(args.faccion))
    local da = cantidadValida(args.daRecurso, args.daCantidad)
    local pide = cantidadValida(args.pideRecurso, args.pideCantidad)
    if not a or not b or not da or not pide then
        return
    end
    if not C.puedenComerciar(a.id, b.id) then
        Red.decir(jugador, "IGUI_WQ_Com_EnGuerra", { b.nombre })
        return
    end
    if #C.ofertasDe(a.id) >= MAX_OFERTAS then
        Red.decir(jugador, "IGUI_WQ_Com_MuchasOfertas", { tostring(MAX_OFERTAS) })
        return
    end
    if not E.territorioConRecurso(a, args.daRecurso, da) then
        Red.decir(jugador, "IGUI_WQ_Com_NoTienes", { R.texto({ [args.daRecurso] = da }) })
        return
    end
    local datos = C.getDatos()
    local oferta = { id = datos.siguienteId, de = a.id, para = b.id, autor = jugador:getUsername(),
        daRecurso = args.daRecurso, daCantidad = da, pideRecurso = args.pideRecurso, pideCantidad = pide,
        expira = ahora() + WorldQuest.Reloj.horasDeJuego(MINUTOS_OFERTA) }
    datos.siguienteId = datos.siguienteId + 1
    table.insert(datos.ofertas, oferta)
    Red.cambio()
    Red.avisarFaccion(b, "IGUI_WQ_Com_OfertaNueva", { a.nombre, R.texto({ [oferta.daRecurso] = da }), R.texto({ [oferta.pideRecurso] = pide }) }, "aviso")
    Red.decir(jugador, "IGUI_WQ_Com_OfertaEnviada", { b.nombre })
end)

local function quitarOferta(id)
    local lista = C.getDatos().ofertas
    for i = #lista, 1, -1 do
        if lista[i].id == id then
            local o = lista[i]
            table.remove(lista, i)
            Red.cambio()
            return o
        end
    end
    return nil
end

Red.orden("cancelarOferta", function(jugador, args)
    local f = Facciones.deJugador(jugador)
    for _, o in ipairs(C.getDatos().ofertas) do
        if f and o.id == tonumber(args.id) and o.de == f.id then
            quitarOferta(o.id)
            return
        end
    end
end)

-- Sale una caravana de origen (territorio) a la base principal de la faccion destino
function C.mandarCaravana(dueno, origen, destinoFaccion, items, extra)
    local destino = E.territorioPrincipal(destinoFaccion)
    if not destino then
        return nil
    end
    local v = E.crearViaje("caravana", dueno, origen, {}, destino.x, destino.y, {
        sinColonos = true, sinVuelta = true, carga = items, destino = destino.id, para = destinoFaccion.id,
        extra = extra, valor = 0,
    })
    local valor = 0
    for tipo, n in pairs(items or {}) do
        valor = valor + WorldQuest.Mercenarios.valorItem(tipo) * n
    end
    v.valor = math.floor(valor)
    return v
end

Red.orden("responderOferta", function(jugador, args)
    local b = miembro(jugador)
    local id = tonumber(args.id)
    if not b or not id then
        return
    end
    local oferta = nil
    for _, o in ipairs(C.getDatos().ofertas) do
        if o.id == id and o.para == b.id then
            oferta = o
        end
    end
    if not oferta then
        return
    end
    quitarOferta(id)
    local a = Facciones.porId(oferta.de)
    if not a then
        return
    end
    if args.acepta ~= true then
        Red.avisarFaccion(a, "IGUI_WQ_Com_Rechazada", { b.nombre }, "aviso")
        return
    end
    if not C.puedenComerciar(a.id, b.id) then
        return
    end
    local tA = E.territorioConRecurso(a, oferta.daRecurso, oferta.daCantidad)
    local tB = E.territorioConRecurso(b, oferta.pideRecurso, oferta.pideCantidad)
    if not tA or not tB then
        Red.avisarFaccion(a, "IGUI_WQ_Com_Fallo", { b.nombre }, "aviso")
        Red.avisarFaccion(b, "IGUI_WQ_Com_Fallo", { a.nombre }, "aviso")
        if not tB then
            Red.decir(jugador, "IGUI_WQ_Com_NoTienes", { R.texto({ [oferta.pideRecurso] = oferta.pideCantidad }) })
        end
        return
    end
    local itemsA = E.cobrar(a, oferta.daRecurso, oferta.daCantidad, tA)
    local itemsB = E.cobrar(b, oferta.pideRecurso, oferta.pideCantidad, tB)
    -- Bono de comercio de quien recibe (La Caravana)
    local function bono(f, recurso, cantidad)
        local extra = WorldQuest.Balance.efectos(f.tipo, f.rasgo).comercio
        if extra and extra > 1 then
            return { [recurso] = math.floor(cantidad * (extra - 1)) }
        end
        return nil
    end
    C.mandarCaravana(a, tA, b, itemsA, bono(b, oferta.daRecurso, oferta.daCantidad))
    C.mandarCaravana(b, tB, a, itemsB, bono(a, oferta.pideRecurso, oferta.pideCantidad))
    Red.avisarFaccion(a, "IGUI_WQ_Com_Aceptada", { b.nombre }, "aviso")
    Red.avisarFaccion(b, "IGUI_WQ_Com_Aceptada", { a.nombre }, "aviso")
end)

-- CARAVANAS Y EMBOSCADAS ---------------------------------------------------------

E.TIPOS_VIAJE.caravana = function(v, t, colonos)
    local destino = Territorios.buscarPorId(v.destino)
    local para = Facciones.porId(v.para)
    local dueno = Facciones.porId(v.faccion)
    if destino then
        E.entregar(destino, v.extra, v.carga)
        if para then
            Red.avisarFaccion(para, "IGUI_WQ_Com_CaravanaLlego", { destino.nombre, dueno and dueno.nombre or "?" }, "aviso")
        end
    end
    return nil, nil
end

local function buscarViaje(id)
    for _, v in ipairs(E.getExpediciones().lista) do
        if v.id == id then
            return v
        end
    end
    return nil
end

Red.orden("emboscar", function(jugador, args)
    local colonos, f, t = E.colonosParaViaje(jugador, args.colonos)
    local caravana = buscarViaje(tonumber(args.caravana))
    if not f or not t or #colonos == 0 or not caravana then
        Red.decir(jugador, "IGUI_WQ_ExpedicionSinColonos")
        return
    end
    if not C.puedeEmboscar(f, caravana) then
        Red.decir(jugador, "IGUI_WQ_Com_NoEmboscar")
        return
    end
    local x, y = E.posicionViaje(caravana)
    if math.sqrt((x - t.x) ^ 2 + (y - t.y) ^ 2) > ALCANCE_EMBOSCADA then
        Red.decir(jugador, "IGUI_WQ_ExpedicionLejos", { tostring(ALCANCE_EMBOSCADA) })
        return
    end
    E.crearViaje("emboscada", f, t, colonos, x, y, { objetivo = caravana.id, minutosExplorar = 1 })
    Red.avisarFaccion(f, "IGUI_WQ_Com_EmboscadaSale", { tostring(#colonos) }, "aviso")
end)

-- Fuerza de ataque de un grupo de colonos
function C.fuerzaColonos(colonos, t)
    local fuerza = 0
    for _, c in ipairs(colonos) do
        fuerza = fuerza + math.max(1, 5 + c.habilidades.combate * 2 + WorldQuest.Colonos.efecto(c, "defensa"))
    end
    return fuerza * (M.efecto(t, "asalto") or 1)
end

E.TIPOS_VIAJE.emboscada = function(v, t, colonos)
    local f = Facciones.porId(v.faccion)
    local caravana = buscarViaje(v.objetivo)
    if not caravana then
        Red.avisarFaccion(f, "IGUI_WQ_Com_EmboscadaTarde", {}, "aviso")
        return nil, nil
    end
    local duenoCaravana = Facciones.porId(caravana.faccion)
    local ataque = C.fuerzaColonos(colonos, t)
    local escolta = 10 + (caravana.valor or 0) / 20
    local seguridad = duenoCaravana and (WorldQuest.Balance.efectos(duenoCaravana.tipo, duenoCaravana.rasgo).seguridad or 1) or 1
    local probabilidad = math.floor(100 * ataque / (ataque + escolta) * seguridad)
    print("[WorldQuest] Emboscada: ataque " .. ataque .. " contra escolta " .. escolta .. " (" .. probabilidad .. "%)")
    if ZombRand(100) < probabilidad then
        v.botinItems = caravana.carga
        E.quitarViaje(caravana)
        Red.avisarFaccion(f, "IGUI_WQ_Com_EmboscadaGano", {}, "aviso")
        if duenoCaravana then
            Red.avisarFaccion(duenoCaravana, "IGUI_WQ_Com_CaravanaRobada", { f.nombre }, "crisis")
        end
        local para = Facciones.porId(caravana.para)
        if para and para ~= duenoCaravana then
            Red.avisarFaccion(para, "IGUI_WQ_Com_CaravanaRobada", { f.nombre }, "crisis")
        end
        if WorldQuest.Victoria and WorldQuest.Victoria.anotarBatalla then
            WorldQuest.Victoria.anotarBatalla(f, duenoCaravana, true)
        end
        return nil, nil
    end
    -- Perdieron: puede caer uno
    local muertos = {}
    if #colonos > 0 and ZombRand(100) < 50 then
        table.insert(muertos, colonos[ZombRand(#colonos) + 1])
    end
    Red.avisarFaccion(f, "IGUI_WQ_Com_EmboscadaPerdio", {}, "crisis")
    if duenoCaravana then
        Red.avisarFaccion(duenoCaravana, "IGUI_WQ_Com_CaravanaDefendida", { f.nombre }, "aviso")
    end
    return nil, muertos
end

-- CICLO: ofertas vencidas ----------------------------------------------------------

WorldQuest.Reloj.alCiclo(function()
    local lista = C.getDatos().ofertas
    local h = ahora()
    for i = #lista, 1, -1 do
        local o = lista[i]
        if h > o.expira or not Facciones.porId(o.de) or not Facciones.porId(o.para) then
            table.remove(lista, i)
        end
    end
end)
