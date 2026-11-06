-- WorldQuest - Niveles: opciones de asentamiento en el clic derecho (cliente)

local function mejorar(territorio)
    local Niveles = WorldQuest.Niveles
    if Niveles.mejorar(territorio) then
        local texto = getText("IGUI_WQ_NivelSubido", territorio.nombre, Niveles.nombre(Niveles.datos(territorio)))
        if WorldQuest.Banner then
            WorldQuest.Banner.mostrar(texto, "aviso")
        end
        print("[WorldQuest] " .. texto)
    end
end

local function onFillWorldObjectContextMenu(numJugador, context, worldobjects, test)
    local Niveles = WorldQuest.Niveles
    local jugador = getSpecificPlayer(numJugador)
    local territorio = WorldQuest.Territorios.buscarEn(math.floor(jugador:getX()), math.floor(jugador:getY()))
    if not territorio or not Niveles then
        return
    end

    local opcion = context:addOption(getText("ContextMenu_WQ_Asentamiento", Niveles.nombre(Niveles.datos(territorio))))
    local submenu = ISContextMenu:getNew(context)
    context:addSubMenu(opcion, submenu)

    local siguiente = Niveles.siguiente(territorio)
    if not siguiente then
        local maximo = submenu:addOption(getText("IGUI_WQ_NivelMaximo"))
        maximo.notAvailable = true
        return
    end

    local costo = submenu:addOption(getText("ContextMenu_WQ_Costo", Niveles.textoCosto(siguiente.costo, siguiente.colonos)))
    costo.notAvailable = true

    local puede, motivo = Niveles.puedeMejorar(territorio)
    if puede then
        submenu:addOption(getText("ContextMenu_WQ_Mejorar", Niveles.nombre(siguiente)), territorio, mejorar)
    else
        local bloqueado = submenu:addOption(getText("ContextMenu_WQ_MejorarBloqueado", Niveles.nombre(siguiente), motivo))
        bloqueado.notAvailable = true
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
