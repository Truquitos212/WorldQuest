-- WorldQuest - Victoria (servidor): reloj de la partida, puntos, cuentas regresivas,
-- evacuacion (Exodo), final por tiempo y resumen.

require "WorldQuest_Victoria"
require "WorldQuest_EconomiaServidor"
require "WorldQuest_Crisis"

local V = WorldQuest.Victoria
local E = WorldQuest.Economia
local Red = WorldQuest.Red
local Facciones = WorldQuest.Facciones
local Territorios = WorldQuest.Territorios
local M = WorldQuest.Modificadores

Red.agregarClave("WorldQuest_Victoria")

local MINUTOS_FOTO = 5          -- cada cuanto se guarda la historia para el resumen
local MAX_HISTORIA = 160
local MAX_BATALLAS = 120

local function datos()
    return V.getDatos()
end

-- HISTORIA Y BATALLAS ----------------------------------------------------------------

local function foto()
    local d = datos()
    local f = {}
    for _, faccion in ipairs(Facciones.getDatos().lista) do
        f[tostring(faccion.id)] = { p = faccion.puntos or 0, c = V.colonosDe(faccion), t = #V.territoriosDe(faccion),
            r = math.floor(faccion.riqueza or 0) }
    end
    table.insert(d.historia, { m = math.floor(d.minutos), f = f })
    while #d.historia > MAX_HISTORIA do
        -- Se queda con una de cada dos fotos viejas
        local nueva = {}
        for i, h in ipairs(d.historia) do
            if i % 2 == 1 or i > #d.historia - 20 then
                table.insert(nueva, h)
            end
        end
        d.historia = nueva
    end
end

function V.anotarBatalla(ganador, perdedor, gano)
    if not ganador then
        return
    end
    ganador.batallasGanadas = (ganador.batallasGanadas or 0) + 1
    local d = datos()
    table.insert(d.batallas, { m = math.floor(d.minutos), g = ganador.id, p = perdedor and perdedor.id or nil })
    while #d.batallas > MAX_BATALLAS do
        table.remove(d.batallas, 1)
    end
    Red.cambio()
end

function V.alEliminar(f)
    local d = datos()
    table.insert(d.eliminadas, { m = math.floor(d.minutos), f = f.id })
    -- Su evacuacion y sus cuentas se pierden
    d.exodo[tostring(f.id)] = nil
    for _, via in ipairs(V.VIAS) do
        d.cuentas[tostring(f.id) .. ":" .. via] = nil
    end
end

-- FIN DE LA PARTIDA -------------------------------------------------------------------

local function terminar(f, via)
    local d = datos()
    if d.ganador then
        return
    end
    for _, faccion in ipairs(Facciones.getDatos().lista) do
        faccion.puntos = V.calcularPuntos(faccion)
    end
    foto()
    d.ganador = { faccion = f and f.id or nil, via = via, m = math.floor(d.minutos) }
    Red.cambio()
    if f then
        Red.avisar("IGUI_WQ_Vic_Gano", { f.nombre, { clave = "IGUI_WQ_Vic_Via_" .. via } }, "aviso")
    else
        Red.avisar("IGUI_WQ_Vic_NadieGano", { { clave = "IGUI_WQ_Vic_Via_" .. via } }, "crisis")
    end
    Red.transmitir()
    Red.enviar("finPartida", { faccion = f and f.id or -1, via = via })
    print("[WorldQuest] Fin de la partida: " .. (f and f.nombre or "nadie") .. " por " .. via)
end
V.terminar = terminar

-- EXODO ---------------------------------------------------------------------------

Red.orden("iniciarExodo", function(jugador, args)
    local f = Facciones.deJugador(jugador)
    if not f or f.lider ~= jugador:getUsername() or V.terminada() then
        return
    end
    if V.exodo(f) then
        return
    end
    for _, r in ipairs(V.requisitosExodo(f)) do
        if not r.ok then
            Red.decir(jugador, "IGUI_WQ_Vic_FaltaRequisito", { { clave = "IGUI_WQ_Vic_Req_" .. r.id } })
            return
        end
    end
    -- Se paga de las bases cargadas: primero se revisa que alcance todo
    for recurso, n in pairs(V.EXODO_COSTO) do
        if not E.territorioConRecurso(f, recurso, n) then
            Red.decir(jugador, "IGUI_WQ_Com_NoTienes", { WorldQuest.Recursos.texto({ [recurso] = n }) })
            return
        end
    end
    for recurso, n in pairs(V.EXODO_COSTO) do
        E.cobrar(f, recurso, n)
    end
    local t = V.helipuerto(f)
    datos().exodo[tostring(f.id)] = { avance = 0, territorio = t.id }
    Red.cambio()
    Red.avisar("IGUI_WQ_Vic_ExodoEmpieza", { f.nombre, t.nombre }, "aviso")
end)

-- Sabotaje contra la evacuacion (lo usa el conflicto). true si habia que sabotear.
function V.sabotearExodo(f)
    local e = V.exodo(f)
    if not e then
        return false
    end
    e.avance = math.max(0, (e.avance or 0) - V.EXODO_SABOTAJE)
    datos().cuentas[tostring(f.id) .. ":exodo"] = nil
    Red.cambio()
    return true
end

local function avanzarExodo()
    local d = datos()
    for id, e in pairs(d.exodo) do
        local f = Facciones.porId(tonumber(id))
        local t = Territorios.buscarPorId(e.territorio)
        if not f or not t or t.faccion ~= f.id or not (t.mejoras and t.mejoras.helipuerto) then
            d.exodo[id] = nil
            if f then
                Red.avisar("IGUI_WQ_Vic_ExodoPerdido", { f.nombre }, "crisis")
            end
        elseif (e.avance or 0) < 100 and not (WorldQuest.Conflicto and WorldQuest.Conflicto.protegido(t)) then
            local trabajo = 2
            for _, c in ipairs(M.colonosEnBase(t)) do
                if c.rol == "constructor" then
                    trabajo = trabajo + 1 + math.floor(c.habilidades.construccion / 5)
                end
            end
            -- Las partidas largas avanzan mas lento por ciclo, pero tienen mas ciclos
            local escala = WorldQuest.Reloj.minutosCiclo() / 4
            e.avance = math.min(100, (e.avance or 0) + M.obras(t, trabajo) * escala)
            if e.avance >= 100 then
                Red.avisar("IGUI_WQ_Vic_ExodoListo", { f.nombre, tostring(V.minutosCuenta()) }, "crisis")
            end
        end
    end
end

-- RELOJ, PUNTOS Y CUENTAS --------------------------------------------------------------

local ultimaHora = nil
local avisoPresion = false

local function cadaMinuto()
    if isClient() then
        return
    end
    local h = getGameTime():getWorldAgeHours()
    ultimaHora = ultimaHora or h
    local delta = WorldQuest.Reloj.minutosDePartida(h - ultimaHora)
    ultimaHora = h
    local d = datos()
    if d.ganador or #Facciones.getDatos().lista == 0 or delta <= 0 then
        return
    end
    local antes = d.minutos
    d.minutos = d.minutos + math.min(delta, 5)
    if math.floor(antes / MINUTOS_FOTO) ~= math.floor(d.minutos / MINUTOS_FOTO) then
        foto()
    end

    -- Puntos
    for _, f in ipairs(Facciones.getDatos().lista) do
        f.puntos = V.calcularPuntos(f)
    end

    -- Cuentas regresivas: empiezan al cumplir, se cortan si se deja de cumplir
    for _, f in ipairs(Facciones.getDatos().lista) do
        for _, via in ipairs(V.VIAS) do
            local k = tostring(f.id) .. ":" .. via
            if V.cumple(f, via) then
                if not d.cuentas[k] then
                    d.cuentas[k] = d.minutos
                    Red.avisar("IGUI_WQ_Vic_CuentaEmpieza", { f.nombre, { clave = "IGUI_WQ_Vic_Via_" .. via }, tostring(V.minutosCuenta()) }, "crisis")
                elseif d.minutos - d.cuentas[k] >= V.minutosCuenta() then
                    terminar(f, via)
                    return
                end
            elseif d.cuentas[k] then
                d.cuentas[k] = nil
                Red.avisar("IGUI_WQ_Vic_CuentaCortada", { f.nombre, { clave = "IGUI_WQ_Vic_Via_" .. via } }, "aviso")
            end
        end
    end

    -- Modo Caos: si los enemigos ganan, pierden todos
    if V.derrotaCaos and V.derrotaCaos() then
        terminar(nil, "caos")
        return
    end

    -- Final por tiempo
    local limite = V.limiteMinutos()
    if not avisoPresion and d.minutos >= limite * V.MINUTOS_PRESION then
        avisoPresion = true
        d.presion = true
        Red.avisar("IGUI_WQ_Vic_Presion", { tostring(math.ceil(limite - d.minutos)) }, "crisis")
    end
    if d.minutos >= limite then
        terminar(V.primera(), "tiempo")
    end
    Red.cambio()
end

-- Al acercarse el limite, el narrador sube la presion
WorldQuest.Crisis.agregarPresion(function()
    if datos().presion then
        return 2
    end
    return 1
end)

local function alEmpezar()
    avisoPresion = datos().presion == true
end

WorldQuest.Reloj.alCiclo(avanzarExodo)
Events.EveryOneMinute.Add(cadaMinuto)
Events.OnGameStart.Add(alEmpezar)
if Events.OnServerStarted then
    Events.OnServerStarted.Add(alEmpezar)
end
