-- WorldQuest - Modo Caos (servidor): Militares, Fugados de rama dura y la Horda que piensa.
-- Solo corre con la opcion de partida Modo de juego = Caos.

require "WorldQuest_Caos"
require "WorldQuest_VictoriaServidor"
require "WorldQuest_ConflictoServidor"

local Caos = WorldQuest.Caos
local V = WorldQuest.Victoria
local E = WorldQuest.Economia
local R = WorldQuest.Recursos
local Red = WorldQuest.Red
local Facciones = WorldQuest.Facciones
local Territorios = WorldQuest.Territorios
local Crisis = WorldQuest.Crisis
local Conflicto = WorldQuest.Conflicto
local M = WorldQuest.Modificadores
local D = WorldQuest.Diplomacia

Red.agregarClave("WorldQuest_Caos")

-- Ritmo, en minutos de partida
local CADA_REDADA = 40
local CADA_ATAQUE_FUGADOS = 25
local CADA_DEMANDA = 40
local MINUTOS_DEMANDA = 6
local MINUTOS_TRANQUILOS = 30
local CADA_CONTROL = 60
local ESPERA_HORDA = 30
local AMENAZA_POR_MINUTO = 0.125

local function minutos()
    return V.getDatos().minutos
end

local function dificultad()
    return WorldQuest.Opciones.caosDificultad()
end

local function vivas()
    local lista = {}
    for _, f in ipairs(Facciones.getDatos().lista) do
        if not Conflicto.esObservador(f) and #V.territoriosDe(f) > 0 then
            table.insert(lista, f)
        end
    end
    return lista
end

local function riquezaTotal()
    local total = 0
    for _, f in ipairs(vivas()) do
        total = total + (f.riqueza or 0)
    end
    return total
end

local function subirAmenaza(n)
    local d = Caos.getDatos()
    d.amenaza = math.max(0, math.min(100, d.amenaza + n))
    Red.cambio()
end
Caos.subirAmenaza = subirAmenaza

local function puntoLejos(x, y, minimo, maximo)
    local angulo = ZombRand(360) * math.pi / 180
    local d = minimo + ZombRand(math.max(1, maximo - minimo))
    return math.floor(x + math.cos(angulo) * d), math.floor(y + math.sin(angulo) * d)
end

-- Centro de todas las bases
local function centro()
    local x, y, n = 0, 0, 0
    for _, t in ipairs(Territorios.getDatos().lista) do
        x, y, n = x + t.x, y + t.y, n + 1
    end
    if n == 0 then
        return nil
    end
    return x / n, y / n
end

local function preparar()
    local d = Caos.getDatos()
    if d.listo then
        return true
    end
    local cx, cy = centro()
    if not cx then
        return false
    end
    local bx, by = puntoLejos(cx, cy, 900, 1600)
    d.base = { x = bx, y = by, fuerza = 25, riqueza = 0, nombre = "Los Fugados" }
    d.controles = {}
    local m = minutos()
    d.proximaRedada = m + CADA_REDADA
    d.proximoAtaque = m + CADA_ATAQUE_FUGADOS
    d.proximaDemanda = m + 15
    d.proximoControl = m
    d.hordaHasta = m + 20
    d.ultimoMinuto = m
    d.listo = true
    Red.avisar("IGUI_WQ_Caos_Empieza", {}, "crisis")
    Red.cambio()
    return true
end

local function moverControles()
    local d = Caos.getDatos()
    local bases = Territorios.getDatos().lista
    d.controles = {}
    local n = math.min(4, 2 + math.floor(#Facciones.getDatos().lista / 2))
    for i = 1, n do
        if #bases >= 2 then
            -- Entre dos bases al azar, donde pasan las caravanas
            local a = bases[ZombRand(#bases) + 1]
            local b = bases[ZombRand(#bases) + 1]
            local f = 0.3 + ZombRand(40) / 100
            table.insert(d.controles, { x = math.floor(a.x + (b.x - a.x) * f + ZombRand(200) - 100),
                y = math.floor(a.y + (b.y - a.y) * f + ZombRand(200) - 100) })
        elseif #bases == 1 then
            local x, y = puntoLejos(bases[1].x, bases[1].y, 300, 700)
            table.insert(d.controles, { x = x, y = y })
        end
    end
    d.proximoControl = minutos() + CADA_CONTROL
    Red.cambio()
end

-- CRISIS PROPIAS DEL CAOS --------------------------------------------------------------

local function atacar(territorio, ataque, perdidaRecursos, nombreClave)
    local defensa = M.defensa(territorio)
    print("[WorldQuest] Caos (" .. nombreClave .. ") contra " .. territorio.nombre .. ": " .. math.floor(ataque) .. " contra " .. defensa)
    if defensa >= ataque then
        Red.avisar("IGUI_WQ_Caos_Rechazado", { { clave = nombreClave }, territorio.nombre }, "aviso")
        return false
    end
    local robado = R.vacio()
    for recurso, pct in pairs(perdidaRecursos) do
        local items, recursos = Conflicto.saquear(territorio, pct, recurso)
        for tipo, n in pairs(items or {}) do
            local r, u = nil, 0
            local fila = R.ITEMS[tipo]
            if fila then
                r, u = fila[1], fila[2]
            end
            if r then
                robado[r] = robado[r] + u * n
            end
        end
        for r, n in pairs(recursos or {}) do
            robado[r] = (robado[r] or 0) + n
        end
    end
    local colonos = WorldQuest.Colonos.delTerritorio(territorio)
    if #colonos > 0 then
        local victima = colonos[ZombRand(#colonos) + 1]
        E.perderColono(victima, "muerto")
        Red.avisar("IGUI_WQ_AsaltoMuerte", { victima.nombre, territorio.nombre }, "crisis")
    end
    Red.avisar("IGUI_WQ_Caos_Golpe", { { clave = nombreClave }, territorio.nombre }, "crisis")
    return true, robado
end

Crisis.registrar({
    id = "redada",
    minutosAviso = 6,
    soloProgramada = true,
    textoAviso = "IGUI_WQ_Caos_AvisoRedada",
    ejecutar = function(territorio, pendiente)
        local ataque = (30 + 10 * (territorio.nivel or 1) + riquezaTotal() / 100) * dificultad() * (0.85 + ZombRand(31) / 100)
        local gano = atacar(territorio, ataque, { municion = 50, medicina = 50 }, "IGUI_WQ_Caos_Militares")
        subirAmenaza(gano and 5 or -3)
        return true
    end,
})

Crisis.registrar({
    id = "fugados",
    minutosAviso = 8,
    soloProgramada = true,
    textoAviso = "IGUI_WQ_Caos_AvisoFugados",
    ejecutar = function(territorio, pendiente)
        local base = Caos.base()
        if not base then
            return false
        end
        local ataque = base.fuerza * (0.8 + ZombRand(41) / 100)
        local gano, robado = atacar(territorio, ataque, { comida = 30, madera = 30, metal = 30, medicina = 30, municion = 30 }, "IGUI_WQ_Caos_Fugados")
        if gano then
            base.riqueza = base.riqueza + R.valor(robado or {})
            subirAmenaza(4)
        else
            base.riqueza = math.max(0, base.riqueza - 150)
            subirAmenaza(-2)
        end
        return true
    end,
})

-- MILITARES ------------------------------------------------------------------------

local function redada()
    local d = Caos.getDatos()
    d.proximaRedada = minutos() + CADA_REDADA
    local f = V.primera()
    if not f or Conflicto.faccionProtegida(f) then
        return
    end
    local t = E.territorioPrincipal(f)
    if t then
        Crisis.programar("redada", t, false, { textoArgs = { t.nombre } })
    end
end

local function revisarControles()
    local d = Caos.getDatos()
    local ahora = getGameTime():getWorldAgeHours()
    local lista = E.getExpediciones().lista
    for i = #lista, 1, -1 do
        local v = lista[i]
        if not v.revisado then
            local x, y = E.posicionViaje(v, ahora)
            if Caos.enControl(x, y) then
                v.revisado = true
                local f = Facciones.porId(v.faccion)
                if ZombRand(100) < 25 then
                    if v.tipo == "caravana" then
                        E.quitarViaje(v)
                        Red.avisarFaccion(f, "IGUI_WQ_Caos_CaravanaConfiscada", {}, "crisis")
                    elseif v.botin then
                        v.botin = nil
                        v.botinItems = nil
                        Red.avisarFaccion(f, "IGUI_WQ_Caos_BotinConfiscado", {}, "crisis")
                    end
                end
            end
        end
    end
end

-- FUGADOS DE RAMA DURA ---------------------------------------------------------------

local function crecerBase(minutosPasados)
    local base = Caos.base()
    if not base then
        return
    end
    base.riqueza = base.riqueza + (0.5 + 0.25 * #vivas()) * minutosPasados
    base.fuerza = math.min(250, math.floor((25 + base.riqueza / 30) * dificultad() * (1 + riquezaTotal() / 8000)))
end

local function objetivoFugados()
    local d = Caos.getDatos()
    local base = Caos.base()
    local mejor, mejorPeso = nil, nil
    local m = minutos()
    for _, f in ipairs(vivas()) do
        local tranquilo = (d.tranquilos[tostring(f.id)] or 0) > m
        if not tranquilo and not Conflicto.faccionProtegida(f) then
            for _, t in ipairs(V.territoriosDe(f)) do
                local distancia = math.sqrt((t.x - base.x) ^ 2 + (t.y - base.y) ^ 2)
                local peso = distancia
                if d.prioridad[tostring(f.id)] then
                    peso = peso * 0.2
                end
                if Caos.esFugado(f) and not d.prioridad[tostring(f.id)] then
                    peso = peso * 2   -- a los suyos los atacan menos
                end
                if not mejorPeso or peso < mejorPeso then
                    mejor, mejorPeso = t, peso
                end
            end
        end
    end
    return mejor
end

local function ataqueFugados()
    local d = Caos.getDatos()
    d.proximoAtaque = minutos() + CADA_ATAQUE_FUGADOS
    local base = Caos.base()
    if not base then
        return
    end
    local t = objetivoFugados()
    if t then
        Crisis.programar("fugados", t, false, { ox = base.x, oy = base.y, textoArgs = { t.nombre } })
    end
end

local function demandas()
    local d = Caos.getDatos()
    local m = minutos()
    -- Vencidas sin respuesta: cuentan como negadas
    for id, dem in pairs(d.demandas) do
        if m >= dem.expira then
            d.demandas[id] = nil
            d.prioridad[id] = true
            local f = Facciones.porId(tonumber(id))
            if f then
                Red.avisarFaccion(f, "IGUI_WQ_Caos_TributoVencido", {}, "crisis")
            end
        end
    end
    if m < (d.proximaDemanda or 0) or not Caos.base() then
        return
    end
    d.proximaDemanda = m + CADA_DEMANDA
    for _, f in ipairs(vivas()) do
        if Caos.esFugado(f) and not d.demandas[tostring(f.id)] then
            d.demandas[tostring(f.id)] = { expira = m + MINUTOS_DEMANDA }
            local texto = R.texto({ [Caos.TRIBUTO.recurso] = Caos.TRIBUTO.cantidad })
            Red.avisarFaccion(f, "IGUI_WQ_Caos_PidenTributo", { texto, tostring(MINUTOS_DEMANDA) }, "crisis")
            local lider = Red.jugador(f.lider)
            if lider and (isServer() or lider:getUsername() == f.lider) then
                Red.enviar("caosTributo", { texto = texto }, lider)
            end
        end
    end
    Red.cambio()
end

local function liderFugado(jugador)
    local f = Facciones.deJugador(jugador)
    if not f or f.lider ~= jugador:getUsername() or not Caos.activo() then
        return nil
    end
    return f
end

Red.orden("pagarFugados", function(jugador, args)
    local f = liderFugado(jugador)
    local d = Caos.getDatos()
    if not f or not d.demandas[tostring(f.id)] then
        return
    end
    if not E.cobrar(f, Caos.TRIBUTO.recurso, Caos.TRIBUTO.cantidad) then
        Red.decir(jugador, "IGUI_WQ_Com_NoTienes", { R.texto({ [Caos.TRIBUTO.recurso] = Caos.TRIBUTO.cantidad }) })
        return
    end
    d.demandas[tostring(f.id)] = nil
    d.prioridad[tostring(f.id)] = nil
    d.tranquilos[tostring(f.id)] = minutos() + MINUTOS_TRANQUILOS
    local base = Caos.base()
    if base then
        base.riqueza = base.riqueza + Caos.TRIBUTO.cantidad * (R.VALOR[Caos.TRIBUTO.recurso] or 1)
    end
    D.cambiarReputacion(f, -8)
    Red.avisar("IGUI_WQ_Caos_PagoTributo", { f.nombre }, "aviso")
end)

Red.orden("negarFugados", function(jugador, args)
    local f = liderFugado(jugador)
    local d = Caos.getDatos()
    if not f or not d.demandas[tostring(f.id)] then
        return
    end
    d.demandas[tostring(f.id)] = nil
    d.prioridad[tostring(f.id)] = true
    Red.avisarFaccion(f, "IGUI_WQ_Caos_NegoTributo", {}, "crisis")
    Red.cambio()
end)

-- Diplomacia unica: Los Fugados pueden pagar para desviar un ataque hacia otro
Red.orden("desviarAtaque", function(jugador, args)
    local f = liderFugado(jugador)
    if not f or not Caos.esFugado(f) then
        return
    end
    local pendientes = Crisis.getDatos().pendientes
    local elegido = nil
    for _, p in ipairs(pendientes) do
        local t = Territorios.buscarPorId(p.territorio)
        if p.tipo == "fugados" and t and t.faccion == f.id then
            elegido = p
        end
    end
    if not elegido then
        return
    end
    if not E.cobrar(f, Caos.COSTO_DESVIO.recurso, Caos.COSTO_DESVIO.cantidad) then
        Red.decir(jugador, "IGUI_WQ_Com_NoTienes", { R.texto({ [Caos.COSTO_DESVIO.recurso] = Caos.COSTO_DESVIO.cantidad }) })
        return
    end
    if ZombRand(100) < 30 then
        Red.avisarFaccion(f, "IGUI_WQ_Caos_DesvioFallo", {}, "crisis")
        return
    end
    local otros = {}
    for _, t in ipairs(Territorios.getDatos().lista) do
        if t.faccion and t.faccion ~= f.id and not Conflicto.protegido(t) then
            table.insert(otros, t)
        end
    end
    if #otros == 0 then
        Red.avisarFaccion(f, "IGUI_WQ_Caos_DesvioFallo", {}, "crisis")
        return
    end
    local nuevo = otros[ZombRand(#otros) + 1]
    elegido.territorio = nuevo.id
    Red.cambio()
    Red.avisarFaccion(f, "IGUI_WQ_Caos_DesvioOk", { nuevo.nombre }, "aviso")
    Red.avisar("IGUI_WQ_Caos_AvisoFugados", { nuevo.nombre }, "aviso")
end)

-- Asalto a la base de los Fugados con colonos elegidos
Red.orden("asaltarFugados", function(jugador, args)
    local colonos, f, t = E.colonosParaViaje(jugador, args.colonos, 8)
    local base = Caos.base()
    if not f or not t or #colonos == 0 or not base then
        Red.decir(jugador, "IGUI_WQ_ExpedicionSinColonos")
        return
    end
    E.crearViaje("asaltoCaos", f, t, colonos, base.x, base.y, { minutosExplorar = 1 })
    Red.avisarFaccion(f, "IGUI_WQ_Caos_AsaltoSale", { tostring(#colonos) }, "aviso")
end)

E.TIPOS_VIAJE.asaltoCaos = function(v, t, colonos)
    local f = Facciones.porId(v.faccion)
    local base = Caos.base()
    if not f or not base then
        return nil, nil
    end
    local ataque = WorldQuest.Comercio.fuerzaColonos(colonos, t) * (0.8 + ZombRand(41) / 100)
    local defensa = base.fuerza * 0.8
    local muertos = {}
    if ataque <= defensa then
        for _, c in ipairs(colonos) do
            if ZombRand(100) < 45 then
                table.insert(muertos, c)
            end
        end
        Red.avisarFaccion(f, "IGUI_WQ_Caos_AsaltoPerdio", {}, "crisis")
        return nil, muertos
    end
    for _, c in ipairs(colonos) do
        if ZombRand(100) < 20 then
            table.insert(muertos, c)
        end
    end
    -- Botin: parte de lo que juntaron
    local botin = R.vacio()
    local parte = math.min(base.riqueza, base.riqueza * 0.3)
    botin.municion = math.floor(parte / 2)
    botin.comida = math.floor(parte * 50)
    base.riqueza = base.riqueza - parte
    base.fuerza = base.fuerza - math.floor(ataque / 2)
    V.anotarBatalla(f, nil, true)
    if base.fuerza <= 0 then
        base.fuerza = 0
        subirAmenaza(-30)
        f.batallasGanadas = (f.batallasGanadas or 0) + 3
        Red.avisar("IGUI_WQ_Caos_BaseDestruida", { f.nombre }, "aviso")
    else
        subirAmenaza(-5)
        Red.avisar("IGUI_WQ_Caos_BaseGolpeada", { f.nombre }, "aviso")
    end
    return botin, muertos
end

-- LA HORDA QUE PIENSA ------------------------------------------------------------------

-- Momento critico: alguien esta por ganar, o acaba de haber una batalla
local function momentoCritico()
    local d = V.getDatos()
    for k, _ in pairs(d.cuentas) do
        local id = tonumber(k:match("^(%d+):"))
        local f = Facciones.porId(id)
        if f and not Conflicto.faccionProtegida(f) then
            return f
        end
    end
    local ultima = d.batallas[#d.batallas]
    if ultima and d.minutos - ultima.m <= 5 then
        local f = Facciones.porId(ultima.g)
        if f and not Conflicto.faccionProtegida(f) then
            return f
        end
    end
    return nil
end

local function hordaQuePiensa()
    local d = Caos.getDatos()
    if minutos() < (d.hordaHasta or 0) then
        return
    end
    local f = momentoCritico()
    if not f then
        return
    end
    local t = E.territorioPrincipal(f)
    if not t then
        return
    end
    d.hordaHasta = minutos() + ESPERA_HORDA
    -- Se divide y llega por varios lados a la vez
    local grupos = 2 + ZombRand(2)
    local inicio = ZombRand(360)
    for i = 1, grupos do
        local angulo = (inicio + (i - 1) * 360 / grupos) * math.pi / 180
        local distancia = t.radio + 30
        Crisis.programar("horda", t, false, { ox = math.floor(t.x + math.cos(angulo) * distancia),
            oy = math.floor(t.y + math.sin(angulo) * distancia), textoArgs = { t.nombre } })
    end
    Red.avisar("IGUI_WQ_Caos_HordaPiensa", { t.nombre, tostring(grupos) }, "crisis")
end

-- CICLO -------------------------------------------------------------------------------

local function alPasarCiclo()
    if not Caos.activo() or V.terminada() or isClient() then
        return
    end
    if not preparar() then
        return
    end
    local d = Caos.getDatos()
    local m = minutos()
    local pasados = math.max(0, m - (d.ultimoMinuto or m))
    d.ultimoMinuto = m
    subirAmenaza(AMENAZA_POR_MINUTO * dificultad() * pasados)
    crecerBase(pasados)
    if m >= (d.proximoControl or 0) then
        moverControles()
    end
    if m >= (d.proximaRedada or 0) then
        redada()
    end
    if m >= (d.proximoAtaque or 0) then
        ataqueFugados()
    end
    demandas()
    revisarControles()
    hordaQuePiensa()
    Red.cambio()
end

-- Si los enemigos ganan, pierden todos
V.derrotaCaos = function()
    if not Caos.activo() or not Caos.getDatos().listo then
        return false
    end
    if Caos.getDatos().amenaza >= 100 then
        return true
    end
    local hubo = false
    for _, f in ipairs(Facciones.getDatos().lista) do
        if f.tuvoTerritorio then
            hubo = true
        end
    end
    return hubo and #vivas() == 0
end

WorldQuest.Reloj.alCiclo(alPasarCiclo)
