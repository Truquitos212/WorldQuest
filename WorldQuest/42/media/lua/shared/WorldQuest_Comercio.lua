-- WorldQuest - Comercio y mercenarios (datos)
-- Ofertas de trueque entre facciones que viajan en caravanas visibles en el mapa,
-- y grupos de mercenarios con personalidad, simpatia por cada faccion e inventario real.
-- Los cambios los hace el servidor (server/WorldQuest_ComercioServidor.lua y
-- server/WorldQuest_MercenariosServidor.lua).

require "WorldQuest_Recursos"

WorldQuest = WorldQuest or {}
WorldQuest.Comercio = WorldQuest.Comercio or {}
WorldQuest.Mercenarios = WorldQuest.Mercenarios or {}

local C = WorldQuest.Comercio
local Merc = WorldQuest.Mercenarios
local CLAVE_COMERCIO = "WorldQuest_Comercio"
local CLAVE_MERCENARIOS = "WorldQuest_Mercenarios"

-- COMERCIO ------------------------------------------------------------------------

C.MAX_CANTIDAD = { comida = 30000, madera = 400, metal = 200, medicina = 80, municion = 500, cigarros = 80 }
C.RECURSOS = { "comida", "madera", "metal", "medicina", "municion", "cigarros" }

function C.getDatos()
    local datos = ModData.getOrCreate(CLAVE_COMERCIO)
    datos.ofertas = datos.ofertas or {}
    datos.siguienteId = datos.siguienteId or 1
    return datos
end

-- true si dos facciones pueden comerciar (cualquiera que no este en guerra)
function C.puedenComerciar(a, b)
    if not a or not b or a == b then
        return false
    end
    return not (WorldQuest.Diplomacia and WorldQuest.Diplomacia.enGuerra(a, b))
end

function C.ofertasPara(id)
    local lista = {}
    for _, o in ipairs(C.getDatos().ofertas) do
        if o.para == id then
            table.insert(lista, o)
        end
    end
    return lista
end

function C.ofertasDe(id)
    local lista = {}
    for _, o in ipairs(C.getDatos().ofertas) do
        if o.de == id then
            table.insert(lista, o)
        end
    end
    return lista
end

-- true si la faccion puede emboscar esa caravana (guerra con el dueno o con el destino)
function C.puedeEmboscar(f, v)
    local D = WorldQuest.Diplomacia
    if not f or not v or v.tipo ~= "caravana" or v.faccion == f.id or not D then
        return false
    end
    return D.enGuerra(f.id, v.faccion) or (v.para ~= nil and v.para ~= f.id and D.enGuerra(f.id, v.para))
end

-- MERCENARIOS ------------------------------------------------------------------------

Merc.PERSONALIDADES = { "codiciosos", "leales", "traicioneros", "idealistas", "oportunistas" }
Merc.NOMBRES = { "Cuervos", "Chacales", "Viudas", "Halcones", "Coyotes", "Serpientes", "Toros", "Lobos Grises",
    "Hienas", "Zorros", "Buitres", "Osos", "Linces", "Escorpiones" }
Merc.HOSTIL = 25          -- bajo esta simpatia te cazan
Merc.AMIGO = 60           -- sobre esta comercian

-- Que piden a cambio segun su personalidad, y cuanto recargan
Merc.PRECIO = {
    codiciosos   = { quiere = "municion", margen = 1.5 },
    leales       = { quiere = "comida",   margen = 1.0 },
    traicioneros = { quiere = "cigarros", margen = 0.8 },
    idealistas   = { quiere = "medicina", margen = 0.7 },
    oportunistas = { quiere = "cigarros", margen = 1.2 },
}

-- Personalidades "duras" y "turbias" (para Moteros y Fugados)
Merc.DUROS = { codiciosos = true, traicioneros = true }
Merc.TURBIOS = { traicioneros = true, oportunistas = true }

function Merc.getDatos()
    local datos = ModData.getOrCreate(CLAVE_MERCENARIOS)
    datos.grupos = datos.grupos or {}
    datos.siguienteId = datos.siguienteId or 1
    return datos
end

function Merc.porId(id)
    for _, g in ipairs(Merc.getDatos().grupos) do
        if g.id == id then
            return g
        end
    end
    return nil
end

-- Simpatia de un grupo por una faccion (0 a 100)
function Merc.simpatia(g, f)
    if not g or not f then
        return 50
    end
    local base = (g.simpatia and g.simpatia[tostring(f.id)])
    if base == nil then
        base = 50
        local B = WorldQuest.Balance
        if B then
            local ef = B.efectos(f.tipo, f.rasgo)
            base = base + (ef.simpatiaMercenarios or 0)
            if Merc.DUROS[g.personalidad] then
                base = base + (ef.simpatiaDuros or 0)
            end
            if Merc.TURBIOS[g.personalidad] then
                base = base + (ef.simpatiaTurbios or 0)
            end
        end
        if WorldQuest.Diplomacia then
            base = base + math.floor((WorldQuest.Diplomacia.reputacion(f) - 50) / 2)
        end
    end
    return math.max(0, math.min(100, base))
end

-- "hostil", "neutral", "amigo" o "contratado" (por esta faccion)
function Merc.actitud(g, f)
    if f and g.contratadoPor == f.id then
        return "contratado"
    end
    local s = Merc.simpatia(g, f)
    if s < Merc.HOSTIL then
        return "hostil"
    elseif s > Merc.AMIGO then
        return "amigo"
    end
    return "neutral"
end

-- Precio en unidades del recurso que quieren, para comprar un item de cierto valor
function Merc.precio(g, valor, f)
    local p = Merc.PRECIO[g.personalidad] or Merc.PRECIO.leales
    local unidad = WorldQuest.Recursos.VALOR[p.quiere] or 1
    if p.quiere == "comida" then
        unidad = unidad / 100
    end
    local factor = p.margen
    if f and WorldQuest.Balance then
        factor = factor * (WorldQuest.Balance.efectos(f.tipo, f.rasgo).precioMercenarios or 1)
    end
    return math.max(1, math.ceil(valor / unidad * factor)), p.quiere
end

-- Valor de trueque de un item por su tipo (1 si no es de ningun recurso)
function Merc.valorItem(tipo)
    local fila = WorldQuest.Recursos.ITEMS[tipo]
    if fila then
        local v = WorldQuest.Recursos.VALOR[fila[1]] or 1
        return math.max(0.5, fila[2] * v)
    end
    if Merc.ARMAS[tipo] then
        return Merc.ARMAS[tipo]
    end
    if string.find(tipo, "Cigar", 1, true) then
        return WorldQuest.Recursos.VALOR.cigarros
    end
    return 2
end

-- Armas que pueden llevar, con su valor
Merc.ARMAS = { ["Base.Pistol"] = 40, ["Base.Shotgun"] = 60, ["Base.HuntingKnife"] = 10, ["Base.Machete"] = 15,
    ["Base.BaseballBat"] = 6, ["Base.Crowbar"] = 8 }

-- Costo de contratar al grupo por un contrato (en unidades de lo que quieren)
Merc.MINUTOS_CONTRATO = 20
function Merc.costoContrato(g, f)
    return Merc.precio(g, g.fuerza * 3, f)
end

-- Por que no te aceptan un contrato (nil si aceptan)
function Merc.motivoRechazo(g, f)
    if g.contratadoPor and g.contratadoPor ~= f.id then
        return "IGUI_WQ_Merc_Ocupados"
    end
    if Merc.actitud(g, f) == "hostil" then
        return "IGUI_WQ_Merc_Hostiles"
    end
    if g.personalidad == "idealistas" and WorldQuest.Diplomacia and WorldQuest.Diplomacia.reputacion(f) < 50 then
        return "IGUI_WQ_Merc_IdealistasNo"
    end
    if g.personalidad == "oportunistas" and not Merc.esPrimero(f) then
        return "IGUI_WQ_Merc_OportunistasNo"
    end
    return nil
end

-- true si la faccion va primera (en la tabla de puntos si existe; si no, en riqueza)
function Merc.esPrimero(f)
    if WorldQuest.Victoria and WorldQuest.Victoria.primera then
        local primera = WorldQuest.Victoria.primera()
        return primera ~= nil and primera.id == f.id
    end
    local mejor, valor = nil, -1
    for _, otra in ipairs(WorldQuest.Facciones.getDatos().lista) do
        if (otra.riqueza or 0) > valor then
            mejor, valor = otra, otra.riqueza or 0
        end
    end
    return mejor ~= nil and mejor.id == f.id
end

-- Fuerza de los mercenarios contratados que cuidan este territorio
function Merc.defensaExtra(t)
    local extra = 0
    for _, g in ipairs(Merc.getDatos().grupos) do
        if g.contratadoPor and g.guarda == t.id and t.faccion == g.contratadoPor then
            extra = extra + g.fuerza
        end
    end
    return extra
end

-- Nombre visible de un item por su tipo
function Merc.nombreItem(tipo)
    local ok, nombre = pcall(getItemNameFromFullType, tipo)
    if ok and type(nombre) == "string" and nombre ~= "" then
        return nombre
    end
    return (string.gsub(tostring(tipo), "^.-%.", ""))
end

function Merc.nombre(g)
    return getText("IGUI_WQ_Merc_Nombre", tostring(g.nombre))
end
