-- WorldQuest - Colonos: ventana de llegada (cliente)
-- La lista, la ficha y los roles estan en el panel de la colonia

WorldQuest = WorldQuest or {}
WorldQuest.ColonosUI = WorldQuest.ColonosUI or {}

local ColonosUI = WorldQuest.ColonosUI
local MODO_PRUEBA = true

local function alResponder(target, boton, propuesta, territorio)
    if boton.internal == "YES" then
        WorldQuest.Colonos.aceptar(propuesta, territorio)
    end
end

function ColonosUI.ofrecer(propuesta, territorio)
    local texto = getText("IGUI_WQ_ColonoPide", propuesta.nombre,
        getText("IGUI_WQ_Hab_" .. propuesta.especialidad),
        tostring(propuesta.habilidades[propuesta.especialidad]),
        territorio.nombre)

    local ancho, alto = 500, 150
    local x = (getCore():getScreenWidth() - ancho) / 2
    local y = (getCore():getScreenHeight() - alto) / 2
    local ventana = ISModalDialog:new(x, y, ancho, alto, texto, true,
        nil, alResponder, 0, propuesta, territorio)
    ventana:initialise()
    ventana:addToUIManager()
end

-- Opcion de prueba: forzar la llegada de un colono
local function onFillWorldObjectContextMenu(numJugador, context, worldobjects, test)
    if not MODO_PRUEBA then
        return
    end
    local jugador = getSpecificPlayer(numJugador)
    local territorio = WorldQuest.Territorios.buscarEn(math.floor(jugador:getX()), math.floor(jugador:getY()))
    if territorio and WorldQuest.Colonos.ofrecerLlegada then
        context:addOption(getText("ContextMenu_WQ_ProbarLlegada"), territorio, WorldQuest.Colonos.ofrecerLlegada)
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
