-- WorldQuest - Modo Caos (cliente): base de los Fugados y controles militares en el
-- mapa, pestana Caos, linea de amenaza en la tabla y la ventana del tributo.

require "WorldQuest_Panel"
require "WorldQuest_MapaMando"
require "WorldQuest_Dialogos"
require "WorldQuest_VictoriaCliente"
require "ISUI/ISButton"

local Caos = WorldQuest.Caos
local Panel = WorldQuest.Panel
local Mando = WorldQuest.MapaMando
local V = WorldQuest.Victoria
local Red = WorldQuest.Red
local Facciones = WorldQuest.Facciones
local R = WorldQuest.Recursos
local MARGEN, ALTO_LINEA = Panel.MARGEN, Panel.ALTO_LINEA

local function miFaccion()
    local j = getPlayer()
    return j and Facciones.deJugador(j)
end

-- TABLA: la amenaza siempre a la vista
V.extraTabla = function()
    if not Caos.activo() then
        return nil
    end
    local a = math.floor(Caos.getDatos().amenaza or 0)
    return getText("IGUI_WQ_Caos_Amenaza", tostring(a)), 1, 0.35 + (100 - a) / 200, 0.3
end

-- MAPA ---------------------------------------------------------------------------------

Mando.agregarDibujo(function(mapa)
    if not Caos.activo() then
        return
    end
    local api = mapa.mapAPI
    local base = Caos.base()
    if base then
        local sx, sy = api:worldToUIX(base.x, base.y), api:worldToUIY(base.x, base.y)
        mapa:drawRect(sx - 11, sy - 11, 22, 22, 0.95, 0.35, 0.05, 0.05)
        mapa:drawRectBorder(sx - 11, sy - 11, 22, 22, 1, 1, 0.55, 0.1)
        mapa:drawTextCentre("F", sx, sy - 7, 1, 0.75, 0.3, 1, UIFont.Small)
        mapa:drawText(getText("IGUI_WQ_Caos_BaseMapa", tostring(base.fuerza)), sx + 14, sy - 7, 1, 0.6, 0.3, 1, UIFont.Small)
    end
    -- Controles militares: anillo de puntos
    for _, c in ipairs(Caos.getDatos().controles) do
        for i = 0, 23 do
            local angulo = i / 24 * 2 * math.pi
            local wx = c.x + math.cos(angulo) * Caos.RADIO_CONTROL
            local wy = c.y + math.sin(angulo) * Caos.RADIO_CONTROL
            mapa:drawRect(api:worldToUIX(wx, wy) - 2, api:worldToUIY(wx, wy) - 2, 4, 4, 0.9, 0.45, 0.6, 0.25)
        end
        local sx, sy = api:worldToUIX(c.x, c.y), api:worldToUIY(c.x, c.y)
        mapa:drawTextCentre(getText("IGUI_WQ_Caos_ControlMapa"), sx, sy - 7, 0.55, 0.75, 0.35, 1, UIFont.Small)
    end
end)

local function cercaDeBase(mapa, wx, wy)
    local base = Caos.activo() and Caos.base()
    return base ~= nil and Mando.distanciaPantalla(mapa, base.x, base.y, wx, wy) <= 16
end

table.insert(Mando.quiereMenu, function(wx, wy, t, mapa)
    return cercaDeBase(mapa, wx, wy)
end)

Mando.agregarOpcion(function(context, wx, wy, t, n, mapa)
    if not cercaDeBase(mapa, wx, wy) then
        return
    end
    local base = Caos.base()
    local titulo = context:addOption(getText("IGUI_WQ_Caos_BaseMapa", tostring(base.fuerza)), nil, nil)
    titulo.notAvailable = true
    if n > 0 then
        local ids = Mando.idsSeleccion()
        local o = context:addOption(getText("IGUI_WQ_Caos_AsaltarBase"), nil, function()
            Red.pedir("asaltarFugados", { colonos = ids })
            Mando.limpiar()
        end)
        o.toolTip = Mando.tooltip(getText("IGUI_WQ_Ayuda_Caos_AsaltarBase"))
    end
end)

-- TRIBUTO: ventana al recibir la exigencia ------------------------------------------------

Red.mensaje("caosTributo", function(args)
    WorldQuest.Dialogos.confirmar(getText("IGUI_WQ_Caos_PreguntaTributo", tostring(args.texto)), function(si)
        Red.pedir(si and "pagarFugados" or "negarFugados", {})
    end)
end)

-- PESTANA CAOS ----------------------------------------------------------------------------
local Vista = Panel.Vista:derive("WorldQuestVistaCaos")

function Vista:createChildren()
    self.botonPagar = ISButton:new(MARGEN, 0, 160, 24, getText("IGUI_WQ_Caos_Pagar"), self, Vista.alPagar)
    self.botonPagar:initialise()
    self:addChild(self.botonPagar)
    self.botonNegar = ISButton:new(MARGEN + 170, 0, 160, 24, getText("IGUI_WQ_Caos_Negar"), self, Vista.alNegar)
    self.botonNegar:initialise()
    self:addChild(self.botonNegar)
    self.botonDesviar = ISButton:new(MARGEN, 0, 330, 24, getText("IGUI_WQ_Caos_Desviar",
        R.texto({ [Caos.COSTO_DESVIO.recurso] = Caos.COSTO_DESVIO.cantidad })), self, Vista.alDesviar)
    self.botonDesviar:initialise()
    self.botonDesviar:setTooltip(getText("IGUI_WQ_Ayuda_Caos_Desviar"))
    self:addChild(self.botonDesviar)
end

function Vista:alPagar()
    Red.pedir("pagarFugados", {})
end

function Vista:alNegar()
    Red.pedir("negarFugados", {})
end

function Vista:alDesviar()
    Red.pedir("desviarAtaque", {})
end

-- Ataque de los Fugados avisado contra la faccion (o nil)
local function ataqueContra(f)
    for _, p in ipairs(WorldQuest.Crisis.getDatos().pendientes) do
        local t = WorldQuest.Territorios.buscarPorId(p.territorio)
        if p.tipo == "fugados" and t and f and t.faccion == f.id then
            return p, t
        end
    end
    return nil
end

function Vista:dibujar()
    local e = Panel.E()
    local d = Caos.getDatos()
    local f = miFaccion()
    local y = MARGEN
    self:texto(getText("IGUI_WQ_Caos_Amenaza", tostring(math.floor(d.amenaza or 0))), MARGEN, y, e.alerta, Panel.FUENTE_TITULO, Panel.ayuda("Caos_Amenaza"))
    y = y + ALTO_LINEA * 2
    self:barra(MARGEN, y, self.width - MARGEN * 2, d.amenaza or 0, 100, 0.8, 0.25, 0.15)
    y = y + ALTO_LINEA + 6

    self:texto(getText("IGUI_WQ_Caos_Militares"), MARGEN, y, e.acento, nil, Panel.ayuda("Caos_Militares"))
    y = y + ALTO_LINEA
    self:texto(getText("IGUI_WQ_Caos_Controles", tostring(#d.controles), tostring(V.reloj((d.proximaRedada or 0) - V.getDatos().minutos))),
        MARGEN + 8, y, e.texto)
    y = y + ALTO_LINEA * 2

    self:texto(getText("IGUI_WQ_Caos_Fugados"), MARGEN, y, e.acento, nil, Panel.ayuda("Caos_Fugados"))
    y = y + ALTO_LINEA
    local base = Caos.base()
    if base then
        self:texto(getText("IGUI_WQ_Caos_BaseInfo", tostring(base.fuerza), R.corto(base.riqueza)), MARGEN + 8, y, e.texto)
    else
        self:texto(getText(d.listo and "IGUI_WQ_Caos_SinBase" or "IGUI_WQ_Caos_AunNo"), MARGEN + 8, y, e.gris)
    end
    y = y + ALTO_LINEA
    local esLider = f and f.lider == getPlayer():getUsername()
    local demanda = Caos.demanda(f)
    self.botonPagar:setVisible(demanda ~= nil)
    self.botonNegar:setVisible(demanda ~= nil)
    if demanda then
        self:texto(getText("IGUI_WQ_Caos_PidenTributo", R.texto({ [Caos.TRIBUTO.recurso] = Caos.TRIBUTO.cantidad }),
            tostring(math.max(0, math.ceil(demanda.expira - V.getDatos().minutos)))), MARGEN + 8, y, e.alerta)
        y = y + ALTO_LINEA + 2
        self.botonPagar:setY(y)
        self.botonNegar:setY(y)
        self.botonPagar:setEnable(esLider)
        self.botonNegar:setEnable(esLider)
        y = y + 30
    elseif f and (d.tranquilos[tostring(f.id)] or 0) > V.getDatos().minutos then
        self:texto(getText("IGUI_WQ_Caos_Tranquilos", tostring(math.ceil(d.tranquilos[tostring(f.id)] - V.getDatos().minutos))), MARGEN + 8, y, e.bien)
        y = y + ALTO_LINEA
    elseif f and d.prioridad[tostring(f.id)] then
        self:texto(getText("IGUI_WQ_Caos_EresObjetivo"), MARGEN + 8, y, e.alerta)
        y = y + ALTO_LINEA
    end
    local _, atacada = ataqueContra(f)
    local puedeDesviar = atacada ~= nil and Caos.esFugado(f)
    self.botonDesviar:setVisible(puedeDesviar)
    if puedeDesviar then
        self:texto(getText("IGUI_WQ_Caos_VienenPorTi", atacada.nombre), MARGEN + 8, y, e.alerta)
        y = y + ALTO_LINEA + 2
        self.botonDesviar:setY(y)
        self.botonDesviar:setEnable(esLider)
        y = y + 30
    end
    y = y + ALTO_LINEA
    self:texto(getText("IGUI_WQ_Caos_Horda"), MARGEN, y, e.acento, nil, Panel.ayuda("Caos_Horda"))
    y = y + ALTO_LINEA
    self:parrafo(getText("IGUI_WQ_Caos_HordaTexto"), MARGEN + 8, y, self.width - MARGEN * 2, e.gris)
end

Panel.registrar(95, Vista, "IGUI_WQ_Tab_Caos", function() return Caos.activo() end)
