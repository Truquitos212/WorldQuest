-- WorldQuest - Mercenarios (servidor)
-- Grupos chicos que recorren el mapa. Segun su simpatia por cada faccion: los hostiles
-- la cazan (asaltan sus bases y sus caravanas), los neutrales la ignoran y los amigos
-- comercian. Tienen inventario real y finito, y se pueden contratar por un tiempo.

require "WorldQuest_Comercio"
require "WorldQuest_EconomiaServidor"
require "WorldQuest_Crisis"

local Merc = WorldQuest.Mercenarios
local E = WorldQuest.Economia
local R = WorldQuest.Recursos
local Red = WorldQuest.Red
local Facciones = WorldQuest.Facciones
local Territorios = WorldQuest.Territorios
local Crisis = WorldQuest.Crisis
local M = WorldQuest.Modificadores

Red.agregarClave("WorldQuest_Mercenarios")

local MAX_GRUPOS = 5
local CASILLAS_POR_MINUTO = 20
local ALCANCE_ASALTO = 400
local ALCANCE_CARAVANA = 200
local ESPERA_ASALTO = 6              -- ciclos entre ataques del mismo grupo
local PROBABILIDAD_ASALTO = 15       -- % por ciclo si hay una base hostil cerca
local PROBABILIDAD_TRAICION = 4      -- % por ciclo de un contrato con traicioneros
local POOL = { "Base.TinnedBeans", "Base.TinnedSoup", "Base.CannedCorn", "Base.Bandage", "Base.Pills",
    "Base.Bullets9mm", "Base.Bullets9mmBox", "Base.ShotgunShells", "Base.ScrapMetal", "Base.Nails", "Base.Plank",
    "Base.Cigarettes", "Base.Pistol", "Base.Shotgun", "Base.HuntingKnife", "Base.Machete", "Base.Disinfectant" }

local function ahora()
    return getGameTime():getWorldAgeHours()
end

local function alAzar(lista)
    return lista[ZombRand(#lista) + 1]
end

local function distancia(ax, ay, bx, by)
    return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2)
end

local function cambiarSimpatia(g, f, delta)
    g.simpatia = g.simpatia or {}
    g.simpatia[tostring(f.id)] = math.max(0, math.min(100, Merc.simpatia(g, f) + delta))
    Red.cambio()
end
Merc.cambiarSimpatia = cambiarSimpatia

-- APARICION Y MOVIMIENTO ---------------------------------------------------------

local function nombreLibre()
    local usados = {}
    for _, g in ipairs(Merc.getDatos().grupos) do
        usados[g.nombre] = true
    end
    local libres = {}
    for _, n in ipairs(Merc.NOMBRES) do
        if not usados[n] then
            table.insert(libres, n)
        end
    end
    return #libres > 0 and alAzar(libres) or alAzar(Merc.NOMBRES)
end

local function puntoCerca(x, y, minimo, maximo)
    local angulo = ZombRand(360) * math.pi / 180
    local d = minimo + ZombRand(math.max(1, maximo - minimo))
    return math.floor(x + math.cos(angulo) * d), math.floor(y + math.sin(angulo) * d)
end

function Merc.crearGrupo(x, y)
    local datos = Merc.getDatos()
    local inventario = {}
    for i = 1, 8 + ZombRand(7) do
        local tipo = alAzar(POOL)
        inventario[tipo] = (inventario[tipo] or 0) + 1 + ZombRand(3)
    end
    local g = {
        id = datos.siguienteId,
        nombre = nombreLibre(),
        personalidad = alAzar(Merc.PERSONALIDADES),
        fuerza = 8 + ZombRand(23),
        x = x, y = y, dx = x, dy = y,
        inventario = inventario,
        simpatia = {},
        esperaAsalto = 0,
    }
    datos.siguienteId = datos.siguienteId + 1
    table.insert(datos.grupos, g)
    Red.cambio()
    print("[WorldQuest] Mercenarios nuevos: " .. g.nombre .. " (" .. g.personalidad .. ", fuerza " .. g.fuerza .. ")")
    return g
end

local function quitarGrupo(g)
    local lista = Merc.getDatos().grupos
    for i = #lista, 1, -1 do
        if lista[i] == g then
            table.remove(lista, i)
        end
    end
    Red.cambio()
end
Merc.quitarGrupo = quitarGrupo

local function objetivoGrupos()
    return math.min(MAX_GRUPOS, 2 + math.floor(#Facciones.getDatos().lista / 2))
end

local function aparecer()
    local territorios = Territorios.getDatos().lista
    if #territorios == 0 then
        return
    end
    if #Merc.getDatos().grupos < objetivoGrupos() then
        local t = alAzar(territorios)
        local x, y = puntoCerca(t.x, t.y, 400, 1200)
        Merc.crearGrupo(x, y)
    end
end

-- Nuevo destino: si esta contratado, la base que cuida; si no, un paseo hacia alguna base
local function nuevoDestino(g)
    if g.contratadoPor and g.guarda then
        local t = Territorios.buscarPorId(g.guarda)
        if t then
            g.dx, g.dy = t.x + 6, t.y + 6
            return
        end
    end
    local territorios = Territorios.getDatos().lista
    if #territorios > 0 and ZombRand(100) < 50 then
        local t = alAzar(territorios)
        g.dx, g.dy = puntoCerca(t.x, t.y, 150, 500)
    else
        g.dx, g.dy = puntoCerca(g.x, g.y, 200, 800)
    end
end

local ultimaHora = nil
local function mover()
    if isClient() then
        return
    end
    local h = ahora()
    ultimaHora = ultimaHora or h
    local minutos = WorldQuest.Reloj.minutosDePartida(h - ultimaHora)
    ultimaHora = h
    if minutos <= 0 then
        return
    end
    local paso = CASILLAS_POR_MINUTO * minutos * 4 / WorldQuest.Reloj.minutosCiclo()
    for _, g in ipairs(Merc.getDatos().grupos) do
        local d = distancia(g.x, g.y, g.dx, g.dy)
        if d <= paso then
            g.x, g.y = g.dx, g.dy
            nuevoDestino(g)
        else
            g.x = g.x + (g.dx - g.x) / d * paso
            g.y = g.y + (g.dy - g.y) / d * paso
        end
    end
end

-- ASALTOS DE MERCENARIOS (crisis que solo se programa) ----------------------------

local PORCENTAJE_SAQUEO = 30

Crisis.registrar({
    id = "mercenarios",
    minutosAviso = 6,
    soloProgramada = true,
    textoAviso = "IGUI_WQ_Merc_AvisoAsalto",
    ejecutar = function(territorio, pendiente)
        local g = pendiente and Merc.porId(pendiente.grupo)
        if not g then
            return false
        end
        local ataque = g.fuerza * 2 + ZombRand(10)
        local defensa = M.defensa(territorio)
        print("[WorldQuest] Asalto de " .. g.nombre .. ": ataque " .. ataque .. " contra defensa " .. defensa)
        if defensa >= ataque then
            g.fuerza = g.fuerza - 3
            WorldQuest.Red.avisar("IGUI_WQ_Merc_Rechazados", { Merc.nombre(g), territorio.nombre }, "aviso")
            if g.fuerza < 5 then
                quitarGrupo(g)
            end
            return true
        end
        -- Se llevan parte de la comida y los materiales
        WorldQuest.Almacen.recorrerItems(territorio, function(item, contenedor)
            local recurso = R.clasificar(item)
            if recurso and ZombRand(100) < M.saqueo(territorio, PORCENTAJE_SAQUEO) then
                local tipo = item:getFullType()
                WorldQuest.Almacen.quitar(contenedor, item)
                g.inventario[tipo] = (g.inventario[tipo] or 0) + 1
            end
        end)
        E.actualizarConteo(territorio)
        WorldQuest.Red.avisar("IGUI_WQ_Merc_Saqueo", { Merc.nombre(g), territorio.nombre }, "crisis")
        return true
    end,
})

local function asaltar(g, t)
    g.esperaAsalto = ESPERA_ASALTO
    g.dx, g.dy = t.x, t.y
    Crisis.programar("mercenarios", t, false, { grupo = g.id, ox = math.floor(g.x), oy = math.floor(g.y),
        textoArgs = { Merc.nombre(g), t.nombre } })
end

local function alPasarCiclo()
    aparecer()
    local h = ahora()
    local protegido = WorldQuest.Conflicto and WorldQuest.Conflicto.protegido
    for _, g in ipairs(Merc.getDatos().grupos) do
        g.esperaAsalto = math.max(0, (g.esperaAsalto or 0) - 1)
        local f = g.contratadoPor and Facciones.porId(g.contratadoPor)
        if g.contratadoPor and not f then
            g.contratadoPor, g.guarda = nil, nil
        end
        if f then
            if h >= (g.contratoHasta or 0) then
                -- Fin del contrato
                g.contratadoPor, g.guarda = nil, nil
                cambiarSimpatia(g, f, 5)
                Red.avisarFaccion(f, "IGUI_WQ_Merc_FinContrato", { Merc.nombre(g) }, "aviso")
                nuevoDestino(g)
            elseif g.personalidad == "traicioneros" and ZombRand(100) < PROBABILIDAD_TRAICION then
                -- Traicion: se dan vuelta y atacan la base que cuidaban
                local t = Territorios.buscarPorId(g.guarda)
                g.contratadoPor, g.guarda = nil, nil
                g.simpatia = g.simpatia or {}
                g.simpatia[tostring(f.id)] = 5
                Red.avisarFaccion(f, "IGUI_WQ_Merc_Traicion", { Merc.nombre(g) }, "crisis")
                if t then
                    asaltar(g, t)
                end
            end
        elseif g.esperaAsalto == 0 then
            -- Hostiles: buscan una base cercana de una faccion que odian
            for _, t in ipairs(Territorios.getDatos().lista) do
                local duena = Facciones.deTerritorio(t)
                if duena and Merc.actitud(g, duena) == "hostil" and not (protegido and protegido(t))
                    and distancia(g.x, g.y, t.x, t.y) <= ALCANCE_ASALTO and ZombRand(100) < PROBABILIDAD_ASALTO then
                    asaltar(g, t)
                    break
                end
            end
        end
        -- Caravanas de facciones que odian, si pasan cerca
        if not g.contratadoPor then
            for _, v in ipairs(E.getExpediciones().lista) do
                local duena = v.tipo == "caravana" and Facciones.porId(v.faccion)
                if duena and Merc.actitud(g, duena) == "hostil" then
                    local x, y = E.posicionViaje(v, h)
                    local seguridad = WorldQuest.Balance.efectos(duena.tipo, duena.rasgo).seguridad or 1
                    if distancia(g.x, g.y, x, y) <= ALCANCE_CARAVANA and ZombRand(100) < 30 * seguridad then
                        for tipo, n in pairs(v.carga or {}) do
                            g.inventario[tipo] = (g.inventario[tipo] or 0) + n
                        end
                        E.quitarViaje(v)
                        Red.avisarFaccion(duena, "IGUI_WQ_Merc_RobaronCaravana", { Merc.nombre(g) }, "crisis")
                        break
                    end
                end
            end
        end
    end
end

-- ORDENES --------------------------------------------------------------------------

local function faccionActiva(jugador)
    local f = Facciones.deJugador(jugador)
    if f and WorldQuest.Conflicto and WorldQuest.Conflicto.esObservador(f) then
        return nil
    end
    return f
end

Red.orden("comprarMercenario", function(jugador, args)
    local f = faccionActiva(jugador)
    local g = Merc.porId(tonumber(args.grupo))
    local tipo = args.tipo
    local cantidad = math.max(1, math.min(50, math.floor(tonumber(args.cantidad) or 1)))
    if not f or not g or type(tipo) ~= "string" then
        return
    end
    local actitud = Merc.actitud(g, f)
    if actitud ~= "amigo" and actitud ~= "contratado" then
        Red.decir(jugador, "IGUI_WQ_Merc_NoComercian", { Merc.nombre(g) })
        return
    end
    local hay = g.inventario[tipo] or 0
    cantidad = math.min(cantidad, hay)
    if cantidad <= 0 then
        return
    end
    local precio, quiere = Merc.precio(g, Merc.valorItem(tipo) * cantidad, f)
    local destino = E.territorioPrincipal(f)
    local pago = destino and E.cobrar(f, quiere, precio)
    if not pago then
        Red.decir(jugador, "IGUI_WQ_Com_NoTienes", { R.texto({ [quiere] = precio }) })
        return
    end
    g.inventario[tipo] = hay - cantidad
    if g.inventario[tipo] <= 0 then
        g.inventario[tipo] = nil
    end
    for t2, n in pairs(pago) do
        g.inventario[t2] = (g.inventario[t2] or 0) + n
    end
    E.entregar(destino, nil, { [tipo] = cantidad })
    cambiarSimpatia(g, f, 2)
    Red.decir(jugador, "IGUI_WQ_Merc_Compraste", { tostring(cantidad), Merc.nombreItem(tipo), destino.nombre })
end)

Red.orden("contratarMercenario", function(jugador, args)
    local f = faccionActiva(jugador)
    local g = Merc.porId(tonumber(args.grupo))
    if not f or not g then
        return
    end
    local motivo = Merc.motivoRechazo(g, f)
    if motivo then
        Red.decir(jugador, motivo, { Merc.nombre(g) })
        return
    end
    local guarda = Territorios.buscarPorId(tonumber(args.territorio))
    if not guarda or guarda.faccion ~= f.id then
        guarda = E.territorioPrincipal(f)
    end
    if not guarda then
        return
    end
    local precio, quiere = Merc.costoContrato(g, f)
    local pago = E.cobrar(f, quiere, precio)
    if not pago then
        Red.decir(jugador, "IGUI_WQ_Com_NoTienes", { R.texto({ [quiere] = precio }) })
        return
    end
    for tipo, n in pairs(pago) do
        g.inventario[tipo] = (g.inventario[tipo] or 0) + n
    end
    local extiende = g.contratadoPor == f.id
    g.contratadoPor = f.id
    g.guarda = guarda.id
    g.contratoHasta = math.max(g.contratoHasta or 0, ahora()) + WorldQuest.Reloj.horasDeJuego(Merc.MINUTOS_CONTRATO)
    nuevoDestino(g)
    cambiarSimpatia(g, f, 5)
    Red.avisarFaccion(f, extiende and "IGUI_WQ_Merc_Extendido" or "IGUI_WQ_Merc_Contratados",
        { Merc.nombre(g), guarda.nombre, tostring(Merc.MINUTOS_CONTRATO) }, "aviso")
end)

Red.orden("despedirMercenario", function(jugador, args)
    local f = faccionActiva(jugador)
    local g = Merc.porId(tonumber(args.grupo))
    if not f or not g or g.contratadoPor ~= f.id then
        return
    end
    g.contratadoPor, g.guarda = nil, nil
    nuevoDestino(g)
    Red.cambio()
end)

-- Mandar a los contratados a cuidar otra base propia
Red.orden("moverMercenario", function(jugador, args)
    local f = faccionActiva(jugador)
    local g = Merc.porId(tonumber(args.grupo))
    local t = Territorios.buscarPorId(tonumber(args.territorio))
    if not f or not g or g.contratadoPor ~= f.id or not t or t.faccion ~= f.id then
        return
    end
    g.guarda = t.id
    nuevoDestino(g)
    Red.cambio()
end)

WorldQuest.Reloj.alCiclo(alPasarCiclo)
Events.EveryOneMinute.Add(mover)
