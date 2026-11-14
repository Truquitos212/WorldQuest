-- WorldQuest - Niebla de guerra (servidor): calcula que ve cada faccion y guarda una
-- foto de los territorios ajenos que tiene a la vista.

require "WorldQuest_Niebla"

local Niebla = WorldQuest.Niebla
local Red = WorldQuest.Red
local Facciones = WorldQuest.Facciones
local Territorios = WorldQuest.Territorios

Red.agregarClave("WorldQuest_Niebla")

local function zonasPropias(f)
    local zonas = {}
    for _, t in ipairs(Territorios.getDatos().lista) do
        if t.faccion == f.id then
            table.insert(zonas, { x = t.x, y = t.y, r = t.radio + Niebla.VISION_BASE })
        end
    end
    for usuario, _ in pairs(f.miembros or {}) do
        local j = isServer() and Red.jugador(usuario) or nil
        if not isServer() then
            local local_ = getPlayer()
            if local_ and local_:getUsername() == usuario then
                j = local_
            end
        end
        if j then
            table.insert(zonas, { x = math.floor(j:getX()), y = math.floor(j:getY()), r = Niebla.VISION_JUGADOR })
        end
    end
    if WorldQuest.Economia then
        local ahora = getGameTime():getWorldAgeHours()
        for _, v in ipairs(WorldQuest.Economia.getExpediciones().lista) do
            if v.faccion == f.id and v.tipo ~= "caravana" then
                local x, y = WorldQuest.Economia.posicionViaje(v, ahora)
                table.insert(zonas, { x = math.floor(x), y = math.floor(y), r = Niebla.VISION_VIAJE })
            end
        end
    end
    return zonas
end

-- Foto de un territorio tal como esta ahora
function Niebla.fotografiar(t, completa)
    local foto = { id = t.id, nombre = t.nombre, x = t.x, y = t.y, radio = t.radio, nivel = t.nivel or 1,
        faccion = t.faccion, colonosVistos = #WorldQuest.Colonos.delTerritorio(t), h = getGameTime():getWorldAgeHours(),
        almacenes = t.almacenes, mejoras = t.mejoras }
    if completa then
        foto.recursos = t.recursos
        foto.defensa = WorldQuest.Modificadores.defensa(t)
    end
    return foto
end

-- Guarda una foto para la faccion (la usa el espionaje para ver todo)
function Niebla.revelar(f, t, completa)
    local datos = Niebla.getDatos()
    local k = tostring(f.id)
    datos.vistos[k] = datos.vistos[k] or {}
    datos.vistos[k][tostring(t.id)] = Niebla.fotografiar(t, completa)
    Red.cambio()
end

local function actualizar()
    if isClient() or not Niebla.activa() then
        return
    end
    local datos = Niebla.getDatos()
    local D = WorldQuest.Diplomacia
    local propias = {}
    for _, f in ipairs(Facciones.getDatos().lista) do
        propias[f.id] = zonasPropias(f)
    end
    for _, f in ipairs(Facciones.getDatos().lista) do
        local k = tostring(f.id)
        -- Lo propio mas lo de los aliados
        local zonas = {}
        for _, otra in ipairs(Facciones.getDatos().lista) do
            if otra.id == f.id or (D and D.aliados(f.id, otra.id)) then
                for _, z in ipairs(propias[otra.id] or {}) do
                    table.insert(zonas, z)
                end
            end
        end
        datos.vision[k] = zonas
        datos.todo[k] = WorldQuest.Mundo ~= nil and WorldQuest.Mundo.controlaTipo(f, "radio") or nil
        -- Fotos de lo ajeno que esta a la vista
        datos.vistos[k] = datos.vistos[k] or {}
        for _, t in ipairs(Territorios.getDatos().lista) do
            local ajeno = t.faccion ~= f.id and not (t.faccion and D and D.aliados(f.id, t.faccion))
            if ajeno and Niebla.vePunto(f, t.x, t.y) then
                local anterior = datos.vistos[k][tostring(t.id)]
                local foto = Niebla.fotografiar(t, false)
                if anterior and anterior.recursos then
                    foto.recursos, foto.defensa = anterior.recursos, anterior.defensa
                end
                datos.vistos[k][tostring(t.id)] = foto
            elseif not ajeno then
                datos.vistos[k][tostring(t.id)] = nil
            end
        end
        -- Fotos de territorios que ya no existen: se borran cuando se vuelve a mirar ahi
        for id, foto in pairs(datos.vistos[k]) do
            if not Territorios.buscarPorId(tonumber(id)) and Niebla.vePunto(f, foto.x, foto.y) then
                datos.vistos[k][id] = nil
            end
        end
    end
    -- Facciones que ya no existen
    for k, _ in pairs(datos.vision) do
        if not Facciones.porId(tonumber(k)) then
            datos.vision[k], datos.vistos[k], datos.todo[k] = nil, nil, nil
        end
    end
    Red.cambio()
end

Events.EveryTenMinutes.Add(actualizar)
