-- WorldQuest - Silueta para colocar una obra en el mundo (cliente)
-- Usa el mismo sistema que el menu de construccion del juego: un objeto derivado
-- de ISBuildingObject que se arrastra con el mouse. Verde: se puede; rojo: fuera
-- del territorio. Al hacer clic, le pide al servidor que fije el lugar de la obra.

WorldQuest = WorldQuest or {}
WorldQuest.CursorObra = WorldQuest.CursorObra or {}

local CursorObra = WorldQuest.CursorObra
local SPRITE = "blends_street_01_55"   -- casilla de ripio del juego, solo para la silueta

local Clase = nil

-- La clase se arma recien al usarla: ISBuildingObject vive en la carpeta server
local function clase()
    if Clase then
        return Clase
    end
    require "BuildingObjects/ISBuildingObject"
    if not ISBuildingObject then
        return nil
    end
    Clase = ISBuildingObject:derive("WorldQuestCursorObra")

    function Clase:new(jugador, territorio, proyecto, tamano)
        local o = {}
        setmetatable(o, self)
        self.__index = self
        o:init()
        o:setSprite(SPRITE)
        o:setNorthSprite(SPRITE)
        o.player = jugador:getPlayerNum()
        o.character = jugador
        o.territorio = territorio
        o.proyecto = proyecto
        o.tamano = tamano or 1
        o.skipBuildAction = true
        o.noNeedHammer = true
        o.dragNilAfterPlace = true
        return o
    end

    function Clase:isValid(square)
        if not square then
            return false
        end
        local t = WorldQuest.Territorios.buscarPorId(self.territorio)
        return t ~= nil and WorldQuest.Territorios.contiene(t, square:getX(), square:getY())
    end

    function Clase:haveMaterial(square)
        return true
    end

    function Clase:tryBuild(x, y, z)
        if self:isValid(getCell():getGridSquare(x, y, z)) then
            WorldQuest.Red.pedir("ubicarObra", { id = self.territorio, x = x, y = y })
        else
            WorldQuest.Red.recibir("decir", { clave = "IGUI_WQ_ObraFuera", p = WorldQuest.Red.empacar({}) })
        end
        getCell():setDrag(nil, self.player)
    end

    function Clase:render(x, y, z, square)
        local valido = self:isValid(square)
        local r, g = 0.9, 0.25
        if valido then
            r, g = 0.25, 0.9
        end
        local sprite = getSprite(SPRITE)
        if not sprite then
            return
        end
        for dx = 0, self.tamano - 1 do
            for dy = 0, self.tamano - 1 do
                pcall(function() sprite:RenderGhostTileColor(x + dx, y + dy, z, r, g, 0.25, 0.6) end)
            end
        end
    end

    return Clase
end

-- Empieza a arrastrar la silueta de la obra en curso del territorio
function CursorObra.empezar(territorio)
    local jugador = getPlayer()
    if not jugador or not territorio or not territorio.proyecto then
        return
    end
    local C = clase()
    if not C then
        print("[WorldQuest] No se pudo crear la silueta de obra (ISBuildingObject no disponible)")
        return
    end
    local definicion = WorldQuest.Proyectos.buscar(territorio.proyecto.id)
    local cursor = C:new(jugador, territorio.id, territorio.proyecto.id, definicion and definicion.tamano or 1)
    getCell():setDrag(cursor, jugador:getPlayerNum())
    jugador:Say(getText("IGUI_WQ_ObraElige"))
end
