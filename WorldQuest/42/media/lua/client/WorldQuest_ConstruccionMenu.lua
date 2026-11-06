-- WorldQuest - Construccion: estructuras y obras en el clic derecho (cliente)

local function revisar(territorio)
    WorldQuest.Estructuras.actualizar(territorio)
end

local function iniciar(territorio, proyecto)
    local Proyectos = WorldQuest.Proyectos
    if Proyectos.iniciar(territorio, proyecto) then
        local texto = getText("IGUI_WQ_ProyectoIniciado", Proyectos.nombre(proyecto.id), territorio.nombre)
        if WorldQuest.Banner then
            WorldQuest.Banner.mostrar(texto, "aviso")
        end
        print("[WorldQuest] " .. texto)
    end
end

local function onFillWorldObjectContextMenu(numJugador, context, worldobjects, test)
    local Proyectos = WorldQuest.Proyectos
    local Niveles = WorldQuest.Niveles
    local jugador = getSpecificPlayer(numJugador)
    local territorio = WorldQuest.Territorios.buscarEn(math.floor(jugador:getX()), math.floor(jugador:getY()))
    if not territorio or not Proyectos or not Niveles then
        return
    end

    local opcion = context:addOption(getText("ContextMenu_WQ_Construccion"))
    local submenu = ISContextMenu:getNew(context)
    context:addSubMenu(opcion, submenu)

    -- Estructuras detectadas
    local e = territorio.estructuras or { camas = 0, huertos = 0, cocinas = 0, generadores = 0 }
    local info = submenu:addOption(getText("ContextMenu_WQ_EstructurasInfo",
        tostring(e.camas), tostring(e.huertos), tostring(e.cocinas), tostring(e.generadores)))
    info.notAvailable = true
    submenu:addOption(getText("ContextMenu_WQ_RevisarEstructuras"), territorio, revisar)

    -- Obra en curso
    if territorio.proyecto then
        local enCurso = submenu:addOption(getText("ContextMenu_WQ_ProyectoEnCurso",
            Proyectos.nombre(territorio.proyecto.id), tostring(territorio.proyecto.restante)))
        enCurso.notAvailable = true
    end

    -- Obras disponibles
    for _, proyecto in ipairs(Proyectos.LISTA) do
        local nombre = Proyectos.nombre(proyecto.id)
        if Proyectos.construido(territorio, proyecto.id) then
            local hecho = submenu:addOption(getText("ContextMenu_WQ_ProyectoHecho", nombre))
            hecho.notAvailable = true
        else
            local texto = getText("ContextMenu_WQ_Proyecto", nombre,
                Niveles.textoCosto(proyecto.costo), tostring(proyecto.trabajo))
            local puede, motivo = Proyectos.puedeIniciar(territorio, proyecto)
            if puede then
                submenu:addOption(texto, territorio, iniciar, proyecto)
            else
                local bloqueado = submenu:addOption(getText("ContextMenu_WQ_ProyectoBloqueado", texto, motivo))
                bloqueado.notAvailable = true
            end
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
