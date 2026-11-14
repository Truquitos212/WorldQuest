-- WorldQuest - Conflicto (servidor): asaltos, espionaje, sabotaje, captura en vivo,
-- observadores y proteccion por desconexion.
--   Asalto simulado: colonos elegidos viajan a una base enemiga (en guerra) para
--     saquearla, capturarla o eliminarla.
--   Captura en vivo: un jugador se queda dentro de una base enemiga sin defensores
--     cerca hasta completar la captura.
--   Espionaje y sabotaje: un colono se infiltra en cualquier base no aliada.

require "WorldQuest_Conflicto"
require "WorldQuest_EconomiaServidor"
require "WorldQuest_ComercioServidor"
require "WorldQuest_NieblaServidor"

local Conflicto = WorldQuest.Conflicto
local E = WorldQuest.Economia
local R = WorldQuest.Recursos
local Red = WorldQuest.Red
local Facciones = WorldQuest.Facciones
local Territorios = WorldQuest.Territorios
local Colonos = WorldQuest.Colonos
local Almacen = WorldQuest.Almacen
local M = WorldQuest.Modificadores
local D = WorldQuest.Diplomacia

Red.agregarClave("WorldQuest_Conflicto")

local PORCENTAJE_SAQUEO = 35
local MARGEN_CAPTURA = 1.3        -- ataque contra defensa para capturar
local MARGEN_ELIMINAR = 1.5
local MAX_ASALTANTES = 8
local MINUTOS_CAPTURA_BASE = 2    -- mas uno por cada 20 de defensa

local function ahora()
    return getGameTime():getWorldAgeHours()
end

-- PROTECCION, OBSERVADORES Y PERDIDAS ------------------------------------------------

local function conectados(f)
    local n = 0
    for usuario, _ in pairs(f.miembros or {}) do
        if isServer() then
            if Red.jugador(usuario) then
                n = n + 1
            end
        else
            local j = getPlayer()
            if j and j:getUsername() == usuario then
                n = n + 1
            end
        end
    end
    return n
end

local function territoriosDe(f)
    local lista = {}
    for _, t in ipairs(Territorios.getDatos().lista) do
        if t.faccion == f.id then
            table.insert(lista, t)
        end
    end
    return lista
end
Conflicto.territoriosDe = territoriosDe

function Conflicto.revisarEliminacion(f)
    if not f or f.eliminada or not f.tuvoTerritorio then
        return
    end
    if #territoriosDe(f) == 0 then
        f.eliminada = true
        f.puesto = nil
        Red.avisar("IGUI_WQ_Conf_Eliminada", { f.nombre }, "crisis")
        Red.cambio()
        if WorldQuest.Victoria and WorldQuest.Victoria.alEliminar then
            pcall(WorldQuest.Victoria.alEliminar, f)
        end
    end
end

local function cadaMinuto()
    if isClient() then
        return
    end
    for _, f in ipairs(Facciones.getDatos().lista) do
        if #territoriosDe(f) > 0 then
            f.tuvoTerritorio = true
        end
        local protegida = conectados(f) == 0
        if protegida ~= (f.proteccion == true) then
            f.proteccion = protegida or nil
            Red.avisar(protegida and "IGUI_WQ_Conf_Protegida" or "IGUI_WQ_Conf_SinProteccion", { f.nombre }, "aviso")
            Red.cambio()
        end
    end
end

-- Lo que una base perdio mientras no estaba cargada se saca al cargarla
local function aplicarPerdidas()
    if isClient() then
        return
    end
    for _, t in ipairs(Territorios.getDatos().lista) do
        if t.perdidas and next(t.perdidas) and WorldQuest.Crisis.estaCargado(t) then
            for recurso, n in pairs(t.perdidas) do
                Almacen.sacar(t, recurso, n)
            end
            t.perdidas = nil
            E.actualizarConteo(t)
            Red.cambio()
        end
    end
end

-- Saca un porcentaje de los recursos de la base: items reales si esta cargada, si no
-- se descuenta del ultimo conteo y queda como perdida pendiente.
-- Devuelve items (si cargada) y recursos (si no).
function Conflicto.saquear(t, porcentaje, soloRecurso)
    local items, recursos = {}, R.vacio()
    if WorldQuest.Crisis.estaCargado(t) then
        local conteo = Almacen.contar(t)
        for _, r in ipairs({ "comida", "madera", "metal", "medicina", "municion", "cigarros" }) do
            if not soloRecurso or soloRecurso == r then
                local n = math.floor((conteo[r] or 0) * porcentaje / 100)
                if n > 0 then
                    for _, tipo in ipairs(Almacen.sacar(t, r, n)) do
                        items[tipo] = (items[tipo] or 0) + 1
                    end
                end
            end
        end
        E.actualizarConteo(t)
        return items, nil
    end
    t.perdidas = t.perdidas or {}
    for r, cantidad in pairs(t.recursos or {}) do
        if not soloRecurso or soloRecurso == r then
            local n = math.floor(cantidad * porcentaje / 100)
            if n > 0 then
                recursos[r] = n
                t.perdidas[r] = (t.perdidas[r] or 0) + n
                t.recursos[r] = cantidad - n
            end
        end
    end
    return nil, recursos
end

local function quitarColono(c, motivo)
    E.perderColono(c, motivo)
end

-- La base pasa a otra faccion. Parte de sus colonos se va.
function Conflicto.capturarTerritorio(t, f)
    local anterior = Facciones.deTerritorio(t)
    t.faccion = f.id
    t.dueno = f.lider
    t.proyecto = nil
    for _, c in ipairs(Colonos.delTerritorio(t)) do
        if ZombRand(100) < 50 then
            quitarColono(c, nil)
        else
            c.orden = nil
            c.rol = "ninguno"
        end
    end
    if anterior and anterior.puesto and anterior.puesto.territorio == t.id then
        anterior.puesto = nil
    end
    Conflicto.getDatos().capturas[tostring(t.id)] = nil
    Red.avisar("IGUI_WQ_Conf_Capturado", { f.nombre, t.nombre, anterior and anterior.nombre or "?" }, "crisis")
    Red.cambio()
    if WorldQuest.Victoria and WorldQuest.Victoria.anotarBatalla then
        WorldQuest.Victoria.anotarBatalla(f, anterior, true)
    end
    Conflicto.revisarEliminacion(anterior)
end

function Conflicto.eliminarTerritorio(t, f)
    local anterior = Facciones.deTerritorio(t)
    for _, c in ipairs(Colonos.delTerritorio(t)) do
        quitarColono(c, nil)
    end
    Territorios.eliminar(t)
    Conflicto.getDatos().capturas[tostring(t.id)] = nil
    Red.avisar("IGUI_WQ_Conf_Destruido", { f.nombre, t.nombre }, "crisis")
    Red.cambio()
    if WorldQuest.Victoria and WorldQuest.Victoria.anotarBatalla then
        WorldQuest.Victoria.anotarBatalla(f, anterior, true)
    end
    Conflicto.revisarEliminacion(anterior)
end

-- ORDENES SOBRE UNA BASE AJENA -------------------------------------------------------

local function preparar(jugador, args, maximo)
    local colonos, f, t = E.colonosParaViaje(jugador, args.colonos, maximo)
    local objetivo = Territorios.buscarPorId(tonumber(args.territorio))
    if not f or not t or #colonos == 0 then
        Red.decir(jugador, "IGUI_WQ_ExpedicionSinColonos")
        return nil
    end
    if not objetivo then
        return nil
    end
    return colonos, f, t, objetivo
end

Red.orden("asaltar", function(jugador, args)
    local colonos, f, t, objetivo = preparar(jugador, args, MAX_ASALTANTES)
    if not colonos then
        return
    end
    local acciones = Conflicto.acciones(f, objetivo)
    if not acciones.asaltar then
        Red.decir(jugador, acciones.protegido and "IGUI_WQ_Conf_EstaProtegida" or "IGUI_WQ_Conf_SoloGuerra")
        return
    end
    local modo = args.modo
    if modo ~= "capturar" and modo ~= "eliminar" then
        modo = "saquear"
    end
    E.crearViaje("asalto", f, t, colonos, objetivo.x, objetivo.y, { objetivo = objetivo.id, modo = modo, minutosExplorar = 1 })
    Red.avisarFaccion(f, "IGUI_WQ_Conf_AsaltoSale", { tostring(#colonos), objetivo.nombre, { clave = "IGUI_WQ_Conf_Modo_" .. modo } }, "aviso")
end)

Red.orden("espiar", function(jugador, args)
    local colonos, f, t, objetivo = preparar(jugador, args, 1)
    if not colonos then
        return
    end
    if not Conflicto.acciones(f, objetivo).espiar then
        Red.decir(jugador, "IGUI_WQ_Conf_NoEspiar")
        return
    end
    E.crearViaje("espionaje", f, t, colonos, objetivo.x, objetivo.y, { objetivo = objetivo.id, minutosExplorar = 2 })
    Red.avisarFaccion(f, "IGUI_WQ_Conf_EspiaSale", { colonos[1].nombre, objetivo.nombre }, "aviso")
end)

Red.orden("sabotear", function(jugador, args)
    local colonos, f, t, objetivo = preparar(jugador, args, 2)
    if not colonos then
        return
    end
    if not Conflicto.acciones(f, objetivo).espiar then
        Red.decir(jugador, "IGUI_WQ_Conf_NoEspiar")
        return
    end
    local blanco = args.blanco
    if blanco ~= "comida" and blanco ~= "obra" and blanco ~= "exodo" and blanco ~= "almacen" then
        blanco = "comida"
    end
    E.crearViaje("sabotaje", f, t, colonos, objetivo.x, objetivo.y, { objetivo = objetivo.id, blanco = blanco, minutosExplorar = 2 })
    Red.avisarFaccion(f, "IGUI_WQ_Conf_SabotajeSale", { tostring(#colonos), objetivo.nombre }, "aviso")
end)

-- RESOLUCION DE LOS VIAJES -------------------------------------------------------------

local function nombres(colonos)
    local n = {}
    for _, c in ipairs(colonos) do
        table.insert(n, c.nombre)
    end
    return table.concat(n, ", ")
end

E.TIPOS_VIAJE.asalto = function(v, t, colonos)
    local f = Facciones.porId(v.faccion)
    local objetivo = Territorios.buscarPorId(v.objetivo)
    if not f or not objetivo or objetivo.faccion == f.id then
        Red.avisarFaccion(f, "IGUI_WQ_Conf_SinObjetivo", {}, "aviso")
        return nil, nil
    end
    local defensor = Facciones.deTerritorio(objetivo)
    if not defensor or not D.enGuerra(f.id, defensor.id) or Conflicto.protegido(objetivo) then
        Red.avisarFaccion(f, "IGUI_WQ_Conf_AsaltoCancelado", { objetivo.nombre }, "aviso")
        return nil, nil
    end
    local ataque = WorldQuest.Comercio.fuerzaColonos(colonos, t) * (0.8 + ZombRand(41) / 100)
    local defensa = M.defensa(objetivo) + 5
    print("[WorldQuest] Asalto de " .. f.nombre .. " a " .. objetivo.nombre .. ": " .. math.floor(ataque) .. " contra " .. defensa)
    local muertos = {}
    if ataque <= defensa then
        for _, c in ipairs(colonos) do
            if ZombRand(100) < 40 then
                table.insert(muertos, c)
            end
        end
        Red.avisar("IGUI_WQ_Conf_AsaltoRechazado", { objetivo.nombre, f.nombre }, "aviso")
        if WorldQuest.Victoria and WorldQuest.Victoria.anotarBatalla then
            WorldQuest.Victoria.anotarBatalla(defensor, f, false)
        end
        return nil, muertos
    end
    for _, c in ipairs(colonos) do
        if ZombRand(100) < 15 then
            table.insert(muertos, c)
        end
    end
    -- Cae un defensor
    local defensores = Colonos.delTerritorio(objetivo)
    if #defensores > 0 and ZombRand(100) < 50 then
        local victima = defensores[ZombRand(#defensores) + 1]
        quitarColono(victima, "muerto")
        Red.avisarFaccion(defensor, "IGUI_WQ_AsaltoMuerte", { victima.nombre, objetivo.nombre }, "crisis")
    end
    if v.modo == "eliminar" and ataque >= defensa * MARGEN_ELIMINAR then
        Conflicto.eliminarTerritorio(objetivo, f)
        return nil, muertos
    end
    if v.modo == "capturar" and ataque >= defensa * MARGEN_CAPTURA then
        Conflicto.capturarTerritorio(objetivo, f)
        return nil, muertos
    end
    -- Saqueo (tambien si no alcanzo para capturar o eliminar)
    local items, recursos = Conflicto.saquear(objetivo, M.saqueo(objetivo, PORCENTAJE_SAQUEO))
    v.botinItems = items
    Red.avisar("IGUI_WQ_Conf_Saqueado", { f.nombre, objetivo.nombre }, "crisis")
    if WorldQuest.Victoria and WorldQuest.Victoria.anotarBatalla then
        WorldQuest.Victoria.anotarBatalla(f, defensor, true)
    end
    return recursos, muertos
end

-- Probabilidad (0 a 100) de que un infiltrado tenga exito
local function exito(base, colonos, objetivo, divisor)
    local mejor = 0
    for _, c in ipairs(colonos) do
        mejor = math.max(mejor, c.habilidades.exploracion)
    end
    return math.max(10, math.min(90, base + mejor * 4 - math.floor(M.defensa(objetivo) / divisor)))
end

local function atrapados(f, objetivo, colonos, costoReputacion)
    local defensor = Facciones.deTerritorio(objetivo)
    if defensor then
        Red.avisarFaccion(defensor, "IGUI_WQ_Conf_EspiaAtrapado", { f.nombre, objetivo.nombre }, "aviso")
    end
    if defensor and not D.enGuerra(f.id, defensor.id) then
        D.cambiarReputacion(f, -costoReputacion)
    end
    Red.avisarFaccion(f, "IGUI_WQ_Conf_TuEspiaAtrapado", { nombres(colonos), objetivo.nombre }, "crisis")
end

E.TIPOS_VIAJE.espionaje = function(v, t, colonos)
    local f = Facciones.porId(v.faccion)
    local objetivo = Territorios.buscarPorId(v.objetivo)
    if not f or not objetivo then
        return nil, nil
    end
    if ZombRand(100) < exito(55, colonos, objetivo, 5) then
        WorldQuest.Niebla.revelar(f, objetivo, true)
        Red.avisarFaccion(f, "IGUI_WQ_Conf_Informe", { objetivo.nombre, tostring(#Colonos.delTerritorio(objetivo)),
            tostring(M.defensa(objetivo)), R.texto(objetivo.recursos or {}) }, "aviso")
        return nil, nil
    end
    atrapados(f, objetivo, colonos, 5)
    return nil, colonos
end

E.TIPOS_VIAJE.sabotaje = function(v, t, colonos)
    local f = Facciones.porId(v.faccion)
    local objetivo = Territorios.buscarPorId(v.objetivo)
    if not f or not objetivo then
        return nil, nil
    end
    if ZombRand(100) >= exito(45, colonos, objetivo, 4) then
        atrapados(f, objetivo, colonos, 10)
        return nil, colonos
    end
    local defensor = Facciones.deTerritorio(objetivo)
    local hecho = "comida"
    if v.blanco == "obra" and objetivo.proyecto then
        objetivo.proyecto.restante = objetivo.proyecto.restante + 3
        hecho = "obra"
    elseif v.blanco == "exodo" and WorldQuest.Victoria and WorldQuest.Victoria.sabotearExodo
        and WorldQuest.Victoria.sabotearExodo(defensor) then
        hecho = "exodo"
    elseif v.blanco == "almacen" then
        Conflicto.saquear(objetivo, 20, "madera")
        Conflicto.saquear(objetivo, 20, "metal")
        hecho = "almacen"
    else
        Conflicto.saquear(objetivo, 30, "comida")
    end
    Red.cambio()
    -- La mitad de las veces se sabe quien fue
    if defensor then
        if ZombRand(100) < 50 then
            Red.avisarFaccion(defensor, "IGUI_WQ_Conf_SaboteadoPor", { objetivo.nombre, f.nombre, { clave = "IGUI_WQ_Conf_Blanco_" .. hecho } }, "crisis")
        else
            Red.avisarFaccion(defensor, "IGUI_WQ_Conf_Saboteado", { objetivo.nombre, { clave = "IGUI_WQ_Conf_Blanco_" .. hecho } }, "crisis")
        end
    end
    Red.avisarFaccion(f, "IGUI_WQ_Conf_SabotajeOk", { objetivo.nombre, { clave = "IGUI_WQ_Conf_Blanco_" .. hecho } }, "aviso")
    return nil, nil
end

-- CAPTURA EN VIVO --------------------------------------------------------------------

local function adentro(f, t)
    local n = 0
    for usuario, _ in pairs(f.miembros or {}) do
        local j = Red.jugador(usuario)
        if j and (isServer() or j:getUsername() == usuario) and not j:isDead()
            and Territorios.contiene(t, math.floor(j:getX()), math.floor(j:getY())) then
            n = n + 1
        end
    end
    return n
end

Red.orden("capturar", function(jugador, args)
    local f = Facciones.deJugador(jugador)
    local t = Territorios.buscarPorId(tonumber(args.territorio))
    if not f or not t then
        return
    end
    if not Conflicto.acciones(f, t).asaltar then
        Red.decir(jugador, Conflicto.protegido(t) and "IGUI_WQ_Conf_EstaProtegida" or "IGUI_WQ_Conf_SoloGuerra")
        return
    end
    if not Territorios.contiene(t, math.floor(jugador:getX()), math.floor(jugador:getY())) then
        return
    end
    local necesario = MINUTOS_CAPTURA_BASE + math.floor(M.defensa(t) / 20)
    Conflicto.getDatos().capturas[tostring(t.id)] = { faccion = f.id, avance = 0, necesario = necesario }
    Red.cambio()
    local defensor = Facciones.deTerritorio(t)
    Red.avisarFaccion(f, "IGUI_WQ_Conf_CapturaEmpieza", { t.nombre, tostring(necesario) }, "aviso")
    if defensor then
        Red.avisarFaccion(defensor, "IGUI_WQ_Conf_CapturaContra", { f.nombre, t.nombre }, "crisis")
    end
end)

local ultimaCaptura = nil
local function avanzarCapturas()
    if isClient() then
        return
    end
    local h = ahora()
    ultimaCaptura = ultimaCaptura or h
    local minutos = WorldQuest.Reloj.minutosDePartida(h - ultimaCaptura)
    ultimaCaptura = h
    local capturas = Conflicto.getDatos().capturas
    for id, c in pairs(capturas) do
        local t = Territorios.buscarPorId(tonumber(id))
        local f = Facciones.porId(c.faccion)
        local defensor = t and Facciones.deTerritorio(t)
        if not t or not f or not defensor or not D.enGuerra(f.id, defensor.id) then
            capturas[id] = nil
        else
            local atacantes = adentro(f, t)
            local defensores = adentro(defensor, t)
            if atacantes == 0 then
                capturas[id] = nil
                Red.avisarFaccion(f, "IGUI_WQ_Conf_CapturaPerdida", { t.nombre }, "aviso")
            elseif defensores == 0 then
                c.avance = c.avance + minutos
                c.disputa = nil
                if c.avance >= c.necesario then
                    Conflicto.capturarTerritorio(t, f)
                end
            else
                c.disputa = true
            end
        end
        Red.cambio()
    end
end

Events.EveryOneMinute.Add(cadaMinuto)
Events.EveryOneMinute.Add(avanzarCapturas)
Events.EveryTenMinutes.Add(aplicarPerdidas)
