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
        or not Facciones.emblemaValido(args.emblema) then
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
