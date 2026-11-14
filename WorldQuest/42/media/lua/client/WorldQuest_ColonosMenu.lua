-- WorldQuest - Colonos: ventana de llegada (cliente)
-- La lista, la ficha y los roles estan en el panel de la colonia

WorldQuest = WorldQuest or {}
WorldQuest.ColonosUI = WorldQuest.ColonosUI or {}

local ColonosUI = WorldQuest.ColonosUI
local Red = WorldQuest.Red

local function alResponder(target, boton, pid)
    if boton.internal == "YES" then
        Red.pedir("aceptarColono", { pid = pid })
    else
        Red.pedir("rechazarColono", { pid = pid })
    end
end

-- El servidor pregunta si aceptamos a un sobreviviente
function ColonosUI.ofrecer(args)
    local texto = getText("IGUI_WQ_ColonoPide", args.nombre,
        getText("IGUI_WQ_Hab_" .. args.especialidad),
        tostring(args.nivel),
        args.territorio)
    -- Rasgos y oficio, para decidir mejor
    if type(args.rasgos) == "string" and args.rasgos ~= "" then
        local nombres = {}
        for r in string.gmatch(args.rasgos, "[^,]+") do
            table.insert(nombres, getText("IGUI_WQ_RasgoColono_" .. r))
        end
        texto = texto .. " " .. getText("IGUI_WQ_ColonoPideRasgos", table.concat(nombres, ", "),
            getText("IGUI_WQ_Oficio_" .. tostring(args.oficio)))
    end

    local ancho, alto = 500, 150
    local x = (getCore():getScreenWidth() - ancho) / 2
    local y = (getCore():getScreenHeight() - alto) / 2
    local ventana = ISModalDialog:new(x, y, ancho, alto, texto, true,
        nil, alResponder, 0, args.pid)
    ventana:initialise()
    ventana:addToUIManager()
end

Red.mensaje("ofrecerColono", ColonosUI.ofrecer)

-- Opcion de prueba: forzar la llegada de un colono
local function probarLlegada(territorio)
    Red.pedir("probarLlegada", { id = territorio.id })
end

local function onFillWorldObjectContextMenu(numJugador, context, worldobjects, test)
    if not WorldQuest.Opciones.pruebas() then
        return
    end
    local jugador = getSpecificPlayer(numJugador)
    local territorio = WorldQuest.Territorios.buscarEn(math.floor(jugador:getX()), math.floor(jugador:getY()))
    if territorio then
        context:addOption(getText("ContextMenu_WQ_ProbarLlegada"), territorio, probarLlegada)
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
