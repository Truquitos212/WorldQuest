-- WorldQuest - Facciones: ordenes del servidor (crear, unirse, salir)

local Red = WorldQuest.Red
local Facciones = WorldQuest.Facciones
local Territorios = WorldQuest.Territorios

local function usuario(jugador)
    return jugador and jugador:getUsername() or nil
end

-- Los territorios que el jugador reclamo antes de tener faccion pasan a ella
local function migrar(nombreUsuario, f)
    for _, t in ipairs(Territorios.getDatos().lista) do
        if t.faccion == nil and t.dueno == nombreUsuario then
            t.faccion = f.id
        end
    end
end

Red.orden("crearFaccion", function(jugador, args)
    local u = usuario(jugador)
    if not u then
        return
    end
    if Facciones.de(u) then
        Red.decir(jugador, "IGUI_WQ_YaTienesFaccion")
        return
    end
    local nombre = Territorios.limpiarNombre(args.nombre)
    if not nombre or not Facciones.tipoValido(args.tipo) or not Facciones.color(args.color)
        or not Facciones.emblemaValido(args.emblema) or not WorldQuest.Balance.rasgoValido(args.tipo, args.rasgo) then
        return
    end
    if Facciones.porNombre(nombre) then
        Red.decir(jugador, "IGUI_WQ_FaccionNombreUsado", { nombre })
        return
    end

    local datos = Facciones.getDatos()
    local f = {
        id = datos.siguienteId,
        tipo = args.tipo,
        nombre = nombre,
        color = args.color,
        emblema = args.emblema,
        rasgo = args.rasgo,
        lider = u,
        miembros = { [u] = true },
        solicitudes = {},
    }
    datos.siguienteId = datos.siguienteId + 1
    table.insert(datos.lista, f)
    migrar(u, f)
    Red.avisar("IGUI_WQ_FaccionCreada", { nombre, { clave = "IGUI_WQ_Faccion_" .. f.tipo } }, "aviso")
    print("[WorldQuest] Faccion creada: " .. nombre .. " (" .. f.tipo .. ") por " .. u)
end)

-- Para facciones creadas antes de que existieran los rasgos: el lider elige uno, una vez
Red.orden("elegirRasgo", function(jugador, args)
    local u = usuario(jugador)
    local f = Facciones.de(u)
    if not f or f.lider ~= u or f.rasgo or not WorldQuest.Balance.rasgoValido(f.tipo, args.rasgo) then
        return
    end
    f.rasgo = args.rasgo
    Red.decir(jugador, "IGUI_WQ_RasgoElegido", { { clave = "IGUI_WQ_Rasgo_" .. f.rasgo } })
end)

Red.orden("pedirUnion", function(jugador, args)
    local u = usuario(jugador)
    local f = Facciones.porId(args.faccion)
    if not u or not f then
        return
    end
    if Facciones.de(u) then
        Red.decir(jugador, "IGUI_WQ_YaTienesFaccion")
        return
    end
    local lider = Red.jugador(f.lider)
    if not lider then
        Red.decir(jugador, "IGUI_WQ_LiderDesconectado", { f.nombre })
        return
    end
    f.solicitudes = f.solicitudes or {}
    f.solicitudes[u] = true
    Red.enviar("pedirUnion", { faccion = f.id, usuario = u }, lider)
    Red.decir(jugador, "IGUI_WQ_SolicitudEnviada", { f.nombre })
end)

Red.orden("responderUnion", function(jugador, args)
    local u = usuario(jugador)
    local f = Facciones.de(u)
    if not f or f.lider ~= u or type(args.usuario) ~= "string" then
        return
    end
    if not (f.solicitudes and f.solicitudes[args.usuario]) then
        return
    end
    f.solicitudes[args.usuario] = nil
    local solicitante = Red.jugador(args.usuario)

    if args.acepta ~= true or Facciones.de(args.usuario) then
        if solicitante then
            Red.decir(solicitante, "IGUI_WQ_UnionRechazada", { f.nombre })
        end
        return
    end
    f.miembros[args.usuario] = true
    migrar(args.usuario, f)
    Red.avisar("IGUI_WQ_UnionAceptada", { args.usuario, f.nombre }, "aviso")
end)

Red.orden("salirFaccion", function(jugador, args)
    local u = usuario(jugador)
    local f = Facciones.de(u)
    if not f then
        return
    end
    if f.lider == u then
        if Facciones.cantidadMiembros(f) > 1 then
            Red.decir(jugador, "IGUI_WQ_LiderNoSale")
            return
        end
        -- El ultimo miembro disuelve la faccion; sus territorios vuelven a ser suyos
        for _, t in ipairs(Territorios.getDatos().lista) do
            if t.faccion == f.id then
                t.faccion = nil
                t.dueno = u
            end
        end
        local lista = Facciones.getDatos().lista
        for i = #lista, 1, -1 do
            if lista[i] == f then
                table.remove(lista, i)
            end
        end
        Red.avisar("IGUI_WQ_FaccionDisuelta", { f.nombre }, "aviso")
        return
    end
    f.miembros[u] = nil
    Red.decir(jugador, "IGUI_WQ_SalisteFaccion", { f.nombre })
end)

-- PUESTO DE MANDO ------------------------------------------------------------
-- El lider marca un lugar en un territorio de su faccion. Mientras este cerca,
-- los colonos le llevan comida del almacen de ese territorio.

local RADIO_PUESTO = 4            -- casillas alrededor del puesto
local CALORIAS_POR_COMIDA = 500   -- lo que le llevan cada vez, como maximo
local ESPERA_HORAS = 0.2          -- tiempo minimo de juego entre comidas

local ultimaComida = {}           -- usuario -> hora de juego

local function cercaDe(jugador, x, y, z, radio)
    local dx, dy = jugador:getX() - (x + 0.5), jugador:getY() - (y + 0.5)
    return math.floor(jugador:getZ()) == z and (dx * dx + dy * dy) <= radio * radio
end

Red.orden("marcarPuesto", function(jugador, args)
    local u = usuario(jugador)
    local f = Facciones.de(u)
    local x, y, z = tonumber(args.x), tonumber(args.y), tonumber(args.z) or 0
    if not f or f.lider ~= u or not x or not y then
        return
    end
    x, y, z = math.floor(x), math.floor(y), math.floor(z)
    local t = Territorios.buscarEn(x, y)
    if not t or t.faccion ~= f.id then
        Red.decir(jugador, "IGUI_WQ_PuestoFuera")
        return
    end
    if not cercaDe(jugador, x, y, z, RADIO_PUESTO) then
        return
    end
    f.puesto = { x = x, y = y, z = z, territorio = t.id }
    Red.decir(jugador, "IGUI_WQ_PuestoMarcado", { t.nombre })
    print("[WorldQuest] Puesto de mando de " .. f.nombre .. " en " .. t.nombre)
end)

Red.orden("alimentarLider", function(jugador, args)
    local u = usuario(jugador)
    local f = Facciones.de(u)
    if not f or f.lider ~= u or not f.puesto then
        return
    end
    local p = f.puesto
    local t = Territorios.buscarPorId(p.territorio)
    if not t or t.faccion ~= f.id or not cercaDe(jugador, p.x, p.y, p.z, RADIO_PUESTO) then
        return
    end
    local ahora = getGameTime():getWorldAgeHours()
    if ultimaComida[u] and ahora - ultimaComida[u] < ESPERA_HORAS then
        return
    end
    ultimaComida[u] = ahora

    local calorias = 0
    WorldQuest.Almacen.recorrerItems(t, function(item, contenedor)
        if calorias < CALORIAS_POR_COMIDA and item:IsFood() and not item:isRotten() then
            local c = item:getCalories()
            if c > 0 then
                WorldQuest.Almacen.quitar(contenedor, item)
                calorias = calorias + c
            end
        end
    end)
    if calorias <= 0 then
        Red.decir(jugador, "IGUI_WQ_PuestoSinComida")
        return
    end
    Red.enviar("alimentado", { calorias = math.floor(calorias) }, jugador)
end)
