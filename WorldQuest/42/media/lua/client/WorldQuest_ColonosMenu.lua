-- WorldQuest - Colonos: ventana de llegada y lista en el clic derecho (cliente)

WorldQuest = WorldQuest or {}
WorldQuest.ColonosUI = WorldQuest.ColonosUI or {}

local ColonosUI = WorldQuest.ColonosUI
local MODO_PRUEBA = true

local function nombreHabilidad(id)
    return getText("IGUI_WQ_Hab_" .. id)
end

local function alResponder(target, boton, propuesta, territorio)
    if boton.internal == "YES" then
        WorldQuest.Colonos.aceptar(propuesta, territorio)
    end
end

-- Ventana: "X (Especialidad N) pide refugio en T. Lo aceptas?"
function ColonosUI.ofrecer(propuesta, territorio)
    local texto = getText("IGUI_WQ_ColonoPide", propuesta.nombre,
        nombreHabilidad(propuesta.especialidad),
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

local function onFillWorldObjectContextMenu(numJugador, context, worldobjects, test)
    local Colonos = WorldQuest.Colonos
    local jugador = getSpecificPlayer(numJugador)
    local territorio = WorldQuest.Territorios.buscarEn(math.floor(jugador:getX()), math.floor(jugador:getY()))
    if not territorio then
        return
    end

    local colonos = Colonos.delTerritorio(territorio)
    local opcion = context:addOption(getText("ContextMenu_WQ_Colonos",
        tostring(#colonos), tostring(Colonos.cupo(territorio))))
    local submenu = ISContextMenu:getNew(context)
    context:addSubMenu(opcion, submenu)

    if #colonos == 0 then
        local vacio = submenu:addOption(getText("ContextMenu_WQ_SinColonos"))
        vacio.notAvailable = true
    end

    for _, colono in ipairs(colonos) do
        local dias = Colonos.diasSinComer(colono)
        local texto
        if dias > 0 then
            texto = getText("ContextMenu_WQ_ColonoHambre", colono.nombre, tostring(dias))
        else
            texto = getText("ContextMenu_WQ_ColonoInfo", colono.nombre,
                nombreHabilidad(colono.especialidad),
                tostring(colono.habilidades[colono.especialidad]),
                tostring(colono.animo))
        end
        local linea = submenu:addOption(texto)
        linea.notAvailable = true
    end

    if MODO_PRUEBA and Colonos.ofrecerLlegada then
        submenu:addOption(getText("ContextMenu_WQ_ProbarLlegada"), territorio, Colonos.ofrecerLlegada)
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
