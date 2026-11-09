-- WorldQuest - Ordenes que los jugadores le piden al servidor
-- Cada orden valida (dueno, datos, opciones) antes de cambiar algo. En partida
-- solitaria se ejecutan al tiro; en multijugador llegan desde los clientes.

require "WorldQuest_Crisis"

local Red = WorldQuest.Red
local Territorios = WorldQuest.Territorios
local Almacen = WorldQuest.Almacen
local Colonos = WorldQuest.Colonos
local Niveles = WorldQuest.Niveles
local Proyectos = WorldQuest.Proyectos
local Crisis = WorldQuest.Crisis

local RADIO_INICIAL = 20
local ROLES = { ninguno = true, agricultor = true, explorador = true, constructor = true, guardia = true, medico = true }

local CANTIDADES_PRUEBA = {
    ["Base.Plank"] = 100,
    ["Base.Nails"] = 200,
    ["Base.Log"] = 40,
    ["Base.TinnedBeans"] = 20,
}

-- AYUDAS ----------------------------------------------------------------

local function usuario(jugador)
    return jugador and jugador:getUsername() or nil
end

-- Territorio de la orden si el jugador manda en el; si no, avisa y devuelve nil.
-- Un territorio antiguo sin dueno pasa a ser de quien le da la primera orden, y
-- uno antiguo sin faccion pasa a la faccion de su dueno.
local function territorioPropio(jugador, id)
    local t = Territorios.buscarPorId(id)
    if not t then
        return nil
    end
    local u = usuario(jugador)
    if t.faccion == nil and t.dueno == nil then
        t.dueno = u
    end
    if t.faccion == nil and t.dueno == u then
        local f = WorldQuest.Facciones.de(u)
        if f then
            t.faccion = f.id
        end
    end
    if not Territorios.esDueno(t, jugador) then
        Red.decir(jugador, "IGUI_WQ_NoEresDueno", { t.nombre })
        return nil
    end
    return t
end

local function nombreSprite(objeto)
    local sprite = objeto:getSprite()
    return sprite and sprite:getName() or nil
end

-- Mueble con contenedor en la casilla de la orden. Primero por su posicion en la
-- casilla; si no calza, el primero con el mismo dibujo.
local function buscarMueble(args)
    if not (args.x and args.y and args.z) then
        return nil
    end
    local casilla = getCell():getGridSquare(args.x, args.y, args.z)
    if not casilla then
        return nil
    end
    local objetos = casilla:getObjects()
    local i = args.i
    if i and i >= 0 and i < objetos:size() then
        local objeto = objetos:get(i)
        if Almacen.tieneContenedor(objeto) and (args.sprite == nil or nombreSprite(objeto) == args.sprite) then
            return objeto
        end
    end
    for k = 0, objetos:size() - 1 do
        local objeto = objetos:get(k)
        if Almacen.tieneContenedor(objeto) and (args.sprite == nil or nombreSprite(objeto) == args.sprite) then
            return objeto
        end
    end
    return nil
end

local function colonoPorId(id)
    for _, colono in ipairs(Colonos.getDatos().lista) do
        if colono.id == id then
            return colono
        end
    end
    return nil
end

-- TERRITORIOS -------------------------------------------------------------

Red.orden("reclamar", function(jugador, args)
    local x, y = tonumber(args.x), tonumber(args.y)
    if not x or not y then
        return
    end
    x, y = math.floor(x), math.floor(y)
    local faccion = WorldQuest.Facciones.deJugador(jugador)
    if not faccion then
        Red.decir(jugador, "IGUI_WQ_SinFaccion")
        return
    end
    local maximo = WorldQuest.Modificadores.maxTerritorios(faccion)
    if maximo then
        local tiene = 0
        for _, t in ipairs(Territorios.getDatos().lista) do
            if t.faccion == faccion.id then
                tiene = tiene + 1
            end
        end
        if tiene >= maximo then
            Red.decir(jugador, "IGUI_WQ_MaxTerritorios", { tostring(maximo) })
            return
        end
    end
    if Territorios.buscarSuperpuesto(x, y, RADIO_INICIAL) then
        Red.decir(jugador, "IGUI_WQ_NoReclamable")
        return
    end
    local nombre = Territorios.limpiarNombre(args.nombre)
        or ("Territorio " .. tostring(Territorios.getDatos().contador + 1))
    local t = Territorios.crear(nombre, x, y, RADIO_INICIAL)
    t.dueno = usuario(jugador)
    t.faccion = faccion.id
    Red.decir(jugador, "IGUI_WQ_Reclamado", { t.nombre })
    print("[WorldQuest] Territorio reclamado: " .. t.nombre .. " en " .. x .. ", " .. y .. " por " .. tostring(t.dueno))
end)

Red.orden("renombrar", function(jugador, args)
    local t = territorioPropio(jugador, args.id)
    local nombre = Territorios.limpiarNombre(args.nombre)
    if not t or not nombre then
        return
    end
    local anterior = t.nombre
    Territorios.renombrar(t, nombre)
    Red.decir(jugador, "IGUI_WQ_Renombrado", { nombre })
    print("[WorldQuest] Territorio renombrado: " .. anterior .. " -> " .. nombre)
end)

Red.orden("abandonar", function(jugador, args)
    local t = territorioPropio(jugador, args.id)
    if not t then
        return
    end
    Territorios.eliminar(t)
    Red.decir(jugador, "IGUI_WQ_Abandonado", { t.nombre })
    print("[WorldQuest] Territorio abandonado: " .. t.nombre)
end)

-- ALMACENES ---------------------------------------------------------------

Red.orden("marcarAlmacen", function(jugador, args)
    local t = territorioPropio(jugador, args.id)
    local objeto = buscarMueble(args)
    if not t or not objeto then
        return
    end
    local casilla = objeto:getSquare()
    if not Territorios.contiene(t, casilla:getX(), casilla:getY()) or Almacen.territorioDe(objeto) then
        return
    end
    Almacen.marcar(objeto, t)
    Almacen.guardarMueble(objeto)
    print("[WorldQuest] Almacen marcado en " .. t.nombre)
end)

Red.orden("quitarAlmacen", function(jugador, args)
    local t = territorioPropio(jugador, args.id)
    local objeto = buscarMueble(args)
    if not t or not objeto or Almacen.territorioDe(objeto) ~= t.id then
        return
    end
    Almacen.desmarcar(objeto, t)
    objeto:getModData()[Almacen.CLAVE_NOMBRE] = nil
    Almacen.guardarMueble(objeto)
    print("[WorldQuest] Almacen quitado de " .. t.nombre)
end)

Red.orden("renombrarAlmacen", function(jugador, args)
    local objeto = buscarMueble(args)
    local nombre = Territorios.limpiarNombre(args.nombre)
    if not objeto or not nombre then
        return
    end
    local t = territorioPropio(jugador, Almacen.territorioDe(objeto))
    if not t then
        return
    end
    objeto:getModData()[Almacen.CLAVE_NOMBRE] = nombre
    Almacen.guardarMueble(objeto)
end)

-- COLONIA -----------------------------------------------------------------

Red.orden("mejorar", function(jugador, args)
    local t = territorioPropio(jugador, args.id)
    if not t or not Niveles.mejorar(t) then
        return
    end
    Red.avisar("IGUI_WQ_NivelSubido", { t.nombre, { clave = "IGUI_WQ_Nivel_" .. Niveles.datos(t).id } }, "aviso")
end)

Red.orden("construir", function(jugador, args)
    local t = territorioPropio(jugador, args.id)
    local proyecto = Proyectos.buscar(args.proyecto)
    if not t or not proyecto or Proyectos.construido(t, proyecto.id) then
        return
    end
    if Proyectos.iniciar(t, proyecto) then
        Red.avisar("IGUI_WQ_ProyectoIniciado", { { clave = "IGUI_WQ_Proyecto_" .. proyecto.id }, t.nombre }, "aviso")
    end
end)

-- Lugar de la obra en curso (dentro del territorio). Se puede cambiar mientras dure.
Red.orden("ubicarObra", function(jugador, args)
    local t = territorioPropio(jugador, args.id)
    local x, y = tonumber(args.x), tonumber(args.y)
    if not t or not t.proyecto or not x or not y then
        return
    end
    x, y = math.floor(x), math.floor(y)
    if not Territorios.contiene(t, x, y) then
        Red.decir(jugador, "IGUI_WQ_ObraFuera")
        return
    end
    t.proyecto.x = x
    t.proyecto.y = y
    t.proyecto.sinUbicar = nil
    Red.decir(jugador, "IGUI_WQ_ObraUbicada", { { clave = "IGUI_WQ_Proyecto_" .. t.proyecto.id } })
end)

Red.orden("rol", function(jugador, args)
    local colono = colonoPorId(args.colono)
    if not colono or not ROLES[args.rol] then
        return
    end
    if territorioPropio(jugador, colono.territorio) then
        colono.rol = args.rol
        print("[WorldQuest] " .. colono.nombre .. " ahora es " .. colono.rol)
    end
end)

Red.orden("aceptarColono", function(jugador, args)
    local propuesta = Colonos.tomarPropuesta(args.pid)
    if not propuesta then
        return
    end
    local t = territorioPropio(jugador, propuesta.territorio)
    if t then
        Colonos.aceptar(propuesta, t)
    end
end)

Red.orden("rechazarColono", function(jugador, args)
    Colonos.tomarPropuesta(args.pid)
end)

-- CUERPOS (capa de Bandits, la maneja el cliente del dueno) -----------------

Red.orden("cuerpoPedido", function(jugador, args)
    if type(args.nombre) ~= "string" then
        return
    end
    local datos = Colonos.getDatos()
    datos.cuerpos = datos.cuerpos or {}
    datos.cuerpos[args.nombre] = true
end)

Red.orden("cuerpoAtendido", function(jugador, args)
    local datos = Colonos.getDatos()
    if datos.cuerpos then
        datos.cuerpos[args.nombre] = nil
    end
    if datos.bajas then
        datos.bajas[args.nombre] = nil
    end
end)

Red.orden("colonoMurio", function(jugador, args)
    local datos = Colonos.getDatos()
    for i = #datos.lista, 1, -1 do
        local colono = datos.lista[i]
        if colono.nombre == args.nombre then
            table.remove(datos.lista, i)
            if datos.cuerpos then
                datos.cuerpos[colono.nombre] = nil
            end
            local t = Territorios.buscarPorId(colono.territorio)
            print("[WorldQuest] " .. colono.nombre .. " fue atacado por " .. tostring(args.quien))
            Red.avisar("IGUI_WQ_ColonoMuerto", { colono.nombre, t and t.nombre or "?" }, "crisis")
            return
        end
    end
end)

-- PRUEBAS (solo con la opcion de partida Herramientas de prueba) ------------

Red.orden("probarCrisis", function(jugador, args)
    if not WorldQuest.Opciones.pruebas() then
        return
    end
    local t = territorioPropio(jugador, args.id)
    if not t or not Crisis.tipos[args.tipo] then
        return
    end
    Crisis.programar(args.tipo, t, args.ahora == true)
    if args.ahora == true then
        Crisis.procesarPendientes()
    end
end)

Red.orden("probarLlegada", function(jugador, args)
    if not WorldQuest.Opciones.pruebas() then
        return
    end
    local t = territorioPropio(jugador, args.id)
    if t then
        Colonos.ofrecerLlegada(t)
    end
end)

Red.orden("llenarAlmacen", function(jugador, args)
    if not WorldQuest.Opciones.pruebas() then
        return
    end
    local t = territorioPropio(jugador, args.id)
    if not t then
        return
    end
    local mueble = Almacen.objetos(t)[1]
    if not mueble then
        Red.decir(jugador, "IGUI_WQ_SinAlmacen", { t.nombre })
        return
    end
    local contenedor = mueble:getContainerByIndex(0)
    for tipo, cantidad in pairs(CANTIDADES_PRUEBA) do
        for i = 1, cantidad do
            Almacen.agregar(contenedor, tipo)
        end
    end
    print("[WorldQuest] Almacen de prueba lleno en " .. t.nombre)
end)
