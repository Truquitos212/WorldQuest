-- WorldQuest - Mapa de mando: ordenes a colonos y escuadras (servidor)

local Red = WorldQuest.Red
local Facciones = WorldQuest.Facciones
local Territorios = WorldQuest.Territorios
local Colonos = WorldQuest.Colonos

local MAX_ESCUADRAS = 8
local TIPOS = { defender = true, volver = true, llamar = true, ir = true, mantener = true }

-- Colonos de la lista que son de la faccion del jugador
local function colonosPropios(jugador, ids)
    local f = Facciones.deJugador(jugador)
    local resultado = {}
    if not f or type(ids) ~= "table" then
        return resultado, f
    end
    local buscados = {}
    for _, id in ipairs(ids) do
        buscados[tonumber(id) or -1] = true
    end
    for _, colono in ipairs(Colonos.getDatos().lista) do
        if buscados[colono.id] and not colono.expedicion then
            local t = Territorios.buscarPorId(colono.territorio)
            if t and t.faccion == f.id then
                table.insert(resultado, colono)
            end
        end
    end
    return resultado, f
end

Red.orden("ordenColonos", function(jugador, args)
    if not TIPOS[args.tipo] then
        return
    end
    local colonos = colonosPropios(jugador, args.colonos)
    local x, y = tonumber(args.x), tonumber(args.y)
    local aplicadas = 0
    for _, colono in ipairs(colonos) do
        if args.tipo == "defender" then
            local t = Territorios.buscarPorId(colono.territorio)
            if x and y and t and Territorios.contiene(t, x, y) then
                colono.orden = { tipo = "defender", x = math.floor(x), y = math.floor(y) }
                aplicadas = aplicadas + 1
            end
        elseif args.tipo == "volver" then
            colono.orden = nil
            aplicadas = aplicadas + 1
        elseif args.tipo == "ir" and x and y then
            colono.orden = { tipo = "ir", x = math.floor(x), y = math.floor(y) }
            aplicadas = aplicadas + 1
        elseif args.tipo == "mantener" then
            -- Cada uno se queda donde esta (el cliente manda su posicion)
            local p = type(args.posiciones) == "table" and args.posiciones[tostring(colono.id)]
            local px, py = p and tonumber(p.x), p and tonumber(p.y)
            if px and py then
                colono.orden = { tipo = "mantener", x = math.floor(px), y = math.floor(py) }
                aplicadas = aplicadas + 1
            end
        elseif args.tipo == "llamar" then
            colono.orden = { tipo = "llamar", usuario = jugador:getUsername() }
            aplicadas = aplicadas + 1
        end
    end
    if args.tipo == "defender" and aplicadas < #colonos then
        Red.decir(jugador, "IGUI_WQ_Mando_DefenderFuera")
    end
    print("[WorldQuest] Orden " .. args.tipo .. " a " .. aplicadas .. " colonos")
end)

Red.orden("crearEscuadra", function(jugador, args)
    local colonos, f = colonosPropios(jugador, args.colonos)
    local nombre = Territorios.limpiarNombre(args.nombre)
    if not f or not nombre or #colonos == 0 then
        return
    end
    f.escuadras = f.escuadras or {}
    -- Mismo nombre: se reemplaza
    for i = #f.escuadras, 1, -1 do
        if string.lower(f.escuadras[i].nombre) == string.lower(nombre) then
            table.remove(f.escuadras, i)
        end
    end
    if #f.escuadras >= MAX_ESCUADRAS then
        Red.decir(jugador, "IGUI_WQ_Mando_MaxEscuadras", { tostring(MAX_ESCUADRAS) })
        return
    end
    local ids = {}
    for _, colono in ipairs(colonos) do
        table.insert(ids, colono.id)
    end
    table.insert(f.escuadras, { nombre = nombre, colonos = ids })
    Red.decir(jugador, "IGUI_WQ_Mando_EscuadraCreada", { nombre, tostring(#ids) })
end)

Red.orden("borrarEscuadra", function(jugador, args)
    local f = Facciones.deJugador(jugador)
    if not f or not f.escuadras then
        return
    end
    for i = #f.escuadras, 1, -1 do
        if f.escuadras[i].nombre == args.nombre then
            table.remove(f.escuadras, i)
        end
    end
end)
