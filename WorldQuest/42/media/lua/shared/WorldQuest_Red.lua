-- WorldQuest - Red: ordenes del cliente al servidor, avisos y sincronizacion de datos
-- En partida solitaria todo corre en el mismo lugar y las ordenes se ejecutan al tiro.
-- En multijugador el servidor es el dueno de los datos: los clientes piden una orden,
-- el servidor la valida, la aplica y manda los datos actualizados a todos.

WorldQuest = WorldQuest or {}
WorldQuest.Red = WorldQuest.Red or {}

local Red = WorldQuest.Red
Red.MODULO = "WorldQuest"
-- Todas las claves van aqui (este archivo lo cargan cliente y servidor): asi el
-- cliente en multijugador sabe que datos pedir y aceptar
Red.CLAVES = { "WorldQuest_Territorios", "WorldQuest_Colonos", "WorldQuest_Crisis", "WorldQuest_Registro", "WorldQuest_Facciones",
    "WorldQuest_Expediciones", "WorldQuest_Diplomacia", "WorldQuest_Comercio", "WorldQuest_Mercenarios", "WorldQuest_Mundo",
    "WorldQuest_Niebla", "WorldQuest_Conflicto", "WorldQuest_Victoria", "WorldQuest_Caos" }

-- Otros archivos agregan sus claves de datos para que viajen a los clientes
function Red.agregarClave(clave)
    for _, c in ipairs(Red.CLAVES) do
        if c == clave then
            return
        end
    end
    table.insert(Red.CLAVES, clave)
end
local CLAVE_REGISTRO = "WorldQuest_Registro"
local MAX_REGISTRO = 150

local ordenes = {}      -- nombre -> function(jugador, args)   (servidor)
local mensajes = {}     -- nombre -> function(args)            (cliente)
local cambios = false

-- true donde viven los datos (servidor o partida solitaria)
function Red.esServidor()
    return not isClient()
end

-- true donde hay pantalla (cliente o partida solitaria)
function Red.esCliente()
    return not isServer()
end

-- TEXTOS -----------------------------------------------------------------
-- Los textos viajan como clave de traduccion + argumentos, y cada cliente los
-- traduce a su idioma. Un argumento puede ser otro texto: { clave = ..., args = {...} }

function Red.empacar(args)
    local p = { n = 0 }
    for i, valor in ipairs(args or {}) do
        if type(valor) == "table" then
            p["a" .. i] = { clave = valor.clave, p = Red.empacar(valor.args) }
        else
            p["a" .. i] = tostring(valor)
        end
        p.n = i
    end
    return p
end

function Red.traducir(clave, p)
    local a = {}
    for i = 1, (p and p.n or 0) do
        local valor = p["a" .. i]
        if type(valor) == "table" then
            a[i] = Red.traducir(valor.clave, valor.p)
        else
            a[i] = valor
        end
    end
    local n = #a
    if n == 0 then return getText(clave) end
    if n == 1 then return getText(clave, a[1]) end
    if n == 2 then return getText(clave, a[1], a[2]) end
    if n == 3 then return getText(clave, a[1], a[2], a[3]) end
    return getText(clave, a[1], a[2], a[3], a[4])
end

local function textoLog(args)
    local partes = {}
    for _, valor in ipairs(args or {}) do
        if type(valor) == "table" then
            table.insert(partes, tostring(valor.clave))
        else
            table.insert(partes, tostring(valor))
        end
    end
    return table.concat(partes, ", ")
end

-- SERVIDOR ---------------------------------------------------------------

function Red.orden(nombre, funcion)
    ordenes[nombre] = funcion
end

-- Marca que los datos cambiaron: se mandan a los clientes en el proximo minuto
function Red.cambio()
    cambios = true
end

function Red.ejecutar(jugador, nombre, args)
    local funcion = ordenes[nombre]
    if not funcion then
        print("[WorldQuest] Orden desconocida: " .. tostring(nombre))
        return
    end
    local ok, err = pcall(funcion, jugador, args or {})
    if not ok then
        print("[WorldQuest] Error en la orden " .. tostring(nombre) .. ": " .. tostring(err))
    end
    Red.cambio()
end

-- Manda los datos a todos los clientes (solo hace algo en multijugador)
function Red.transmitir()
    cambios = false
    if not isServer() then
        return
    end
    for _, clave in ipairs(Red.CLAVES) do
        ModData.transmit(clave)
    end
end

-- Jugador conectado por nombre de usuario (nil si no esta)
function Red.jugador(usuario)
    if not isServer() then
        return getPlayer()
    end
    if not usuario then
        return nil
    end
    local lista = getOnlinePlayers()
    if not lista then
        return nil
    end
    for i = 0, lista:size() - 1 do
        local jugador = lista:get(i)
        if jugador:getUsername() == usuario then
            return jugador
        end
    end
    return nil
end

-- Mensaje del servidor a un jugador, o a todos si jugador es nil
function Red.enviar(nombre, args, jugador)
    args = args or {}
    if isServer() then
        if jugador then
            sendServerCommand(jugador, Red.MODULO, nombre, args)
        else
            sendServerCommand(Red.MODULO, nombre, args)
        end
    else
        Red.recibir(nombre, args)
    end
end

-- Registro de eventos de la partida (lo muestra la pestana Registro)
function Red.getRegistro()
    local datos = ModData.getOrCreate(CLAVE_REGISTRO)
    datos.lista = datos.lista or {}
    return datos
end

local function anotar(clave, p, tipo, faccion)
    local lista = Red.getRegistro().lista
    table.insert(lista, { h = getGameTime():getWorldAgeHours(), clave = clave, p = p, tipo = tipo, faccion = faccion })
    while #lista > MAX_REGISTRO do
        table.remove(lista, 1)
    end
    Red.cambio()
end

-- Aviso grande en pantalla. tipo: "aviso" o "crisis". Queda anotado en el registro.
function Red.avisar(clave, args, tipo, jugador)
    print("[WorldQuest] Aviso " .. clave .. " (" .. textoLog(args) .. ")")
    local p = Red.empacar(args)
    if not isClient() then
        anotar(clave, p, tipo)
    end
    Red.enviar("aviso", { clave = clave, p = p, tipo = tipo }, jugador)
end

-- Aviso solo para los miembros conectados de una faccion; queda en su registro privado
function Red.avisarFaccion(f, clave, args, tipo)
    if not f then
        return
    end
    print("[WorldQuest] Aviso a " .. tostring(f.nombre) .. ": " .. clave .. " (" .. textoLog(args) .. ")")
    local p = Red.empacar(args)
    if not isClient() then
        anotar(clave, p, tipo, f.id)
    end
    for usuario, _ in pairs(f.miembros or {}) do
        local jugador = Red.jugador(usuario)
        if jugador and (isServer() or jugador:getUsername() == usuario) then
            Red.enviar("aviso", { clave = clave, p = p, tipo = tipo }, jugador)
        end
    end
end

-- Frase sobre la cabeza de un jugador
function Red.decir(jugador, clave, args)
    Red.enviar("decir", { clave = clave, p = Red.empacar(args) }, jugador)
end

-- CLIENTE ----------------------------------------------------------------

function Red.mensaje(nombre, funcion)
    mensajes[nombre] = funcion
end

function Red.recibir(nombre, args)
    local funcion = mensajes[nombre]
    if not funcion then
        return
    end
    local ok, err = pcall(funcion, args or {})
    if not ok then
        print("[WorldQuest] Error en el mensaje " .. tostring(nombre) .. ": " .. tostring(err))
    end
end

-- Pide una orden al servidor
function Red.pedir(nombre, args)
    args = args or {}
    if isClient() then
        sendClientCommand(getPlayer(), Red.MODULO, nombre, args)
    else
        Red.ejecutar(getPlayer(), nombre, args)
    end
end

-- EVENTOS ----------------------------------------------------------------
-- Se registran siempre y revisan adentro donde corren: asi no dependen de
-- si el juego ya sabe que es cliente o servidor al cargar los archivos.

local function alRecibirOrden(modulo, nombre, jugador, args)
    if modulo == Red.MODULO and isServer() then
        Red.ejecutar(jugador, nombre, args)
    end
end

local function alRecibirMensaje(modulo, nombre, args)
    if modulo == Red.MODULO then
        Red.recibir(nombre, args)
    end
end

local function alRecibirDatos(clave, datos)
    if isServer() then
        return
    end
    for _, nuestra in ipairs(Red.CLAVES) do
        if clave == nuestra then
            if type(datos) == "table" then
                ModData.add(clave, datos)
                if WorldQuest.Panel and WorldQuest.Panel.instancia then
                    WorldQuest.Panel.instancia:refrescar(true)
                end
            end
            return
        end
    end
end

local function alEmpezar()
    if isClient() then
        for _, clave in ipairs(Red.CLAVES) do
            ModData.request(clave)
        end
        print("[WorldQuest] Red: datos pedidos al servidor")
    end
end

local function cadaMinuto()
    if cambios and isServer() then
        Red.transmitir()
    end
end

local function cadaDiezMinutos()
    if isServer() then
        Red.transmitir()
    end
end

Events.OnClientCommand.Add(alRecibirOrden)
Events.OnServerCommand.Add(alRecibirMensaje)
Events.OnReceiveGlobalModData.Add(alRecibirDatos)
Events.OnGameStart.Add(alEmpezar)
Events.EveryOneMinute.Add(cadaMinuto)
Events.EveryTenMinutes.Add(cadaDiezMinutos)
