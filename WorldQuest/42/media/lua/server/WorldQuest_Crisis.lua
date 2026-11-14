-- WorldQuest - Crisis: narrador y crisis pendientes (servidor)

require "WorldQuest_CrisisDatos"

WorldQuest = WorldQuest or {}
WorldQuest.Crisis = WorldQuest.Crisis or {}

local Crisis = WorldQuest.Crisis
local Territorios = WorldQuest.Territorios
local Red = WorldQuest.Red

-- Narrador: la tension sube un punto por cada tirada sin crisis
local PROBABILIDAD_POR_TENSION = 10 -- % por punto de tension
local PROBABILIDAD_MAXIMA = 80      -- % tope

local function horaActual()
    return getGameTime():getWorldAgeHours()
end

-- true si el centro del territorio esta cargado (algun jugador anda cerca)
function Crisis.estaCargado(territorio)
    return getCell():getGridSquare(territorio.x, territorio.y, 0) ~= nil
end

-- Punto al azar alrededor del territorio, a cierta distancia del borde
function Crisis.puntoAlrededor(territorio, distanciaExtra)
    local angulo = ZombRand(360) * math.pi / 180
    local distancia = territorio.radio + distanciaExtra
    return math.floor(territorio.x + math.cos(angulo) * distancia),
           math.floor(territorio.y + math.sin(angulo) * distancia)
end

-- Deja una crisis pendiente. Si inmediata es true, se salta la espera del aviso
function Crisis.programar(idTipo, territorio, inmediata)
    local ficha = Crisis.tipos[idTipo]
    if not ficha then
        return
    end

    local espera = 0
    if not inmediata then
        espera = WorldQuest.Modificadores.minutosAviso(territorio, ficha.minutosAviso or 0)
    end

    local pendiente = {
        tipo = idTipo,
        territorio = territorio.id,
        desde = horaActual(),
        hora = horaActual() + WorldQuest.Reloj.horasDeJuego(espera),
        conAviso = ficha.textoAviso ~= nil,
    }
    -- Amenazas que llegan desde afuera: el mapa muestra por donde vienen
    if ficha.origen then
        pendiente.ox, pendiente.oy = Crisis.puntoAlrededor(territorio, ficha.origen)
    end
    table.insert(Crisis.getDatos().pendientes, pendiente)
    Red.cambio()

    if ficha.textoAviso then
        Red.avisar(ficha.textoAviso, { territorio.nombre }, "aviso")
    end
    print("[WorldQuest] Crisis programada: " .. idTipo .. " en " .. territorio.nombre .. " (en " .. espera .. " min)")
end

-- Ejecuta las crisis pendientes cuya hora llego, si el territorio esta cargado
function Crisis.procesarPendientes()
    if isClient() then
        return
    end
    local pendientes = Crisis.getDatos().pendientes
    local ahora = horaActual()

    for i = #pendientes, 1, -1 do
        local pendiente = pendientes[i]
        local territorio = Territorios.buscarPorId(pendiente.territorio)
        local ficha = Crisis.tipos[pendiente.tipo]

        if not territorio or not ficha then
            -- Territorio abandonado o tipo que ya no existe: se descarta
            table.remove(pendientes, i)
            Red.cambio()
        elseif ahora >= pendiente.hora and Crisis.estaCargado(territorio) then
            table.remove(pendientes, i)
            Red.cambio()
            -- La ficha devuelve false si no pudo ejecutarse
            if ficha.ejecutar(territorio, pendiente) ~= false and ficha.textoInicio then
                Red.avisar(ficha.textoInicio, { territorio.nombre }, "crisis")
            end
        end
    end
end

-- Presion extra del narrador (la sube el final por tiempo y el modo Caos)
function Crisis.presion()
    local p = 1
    for _, funcion in ipairs(Crisis.presiones or {}) do
        local ok, valor = pcall(funcion)
        if ok and type(valor) == "number" then
            p = p * valor
        end
    end
    return p
end

function Crisis.agregarPresion(funcion)
    Crisis.presiones = Crisis.presiones or {}
    table.insert(Crisis.presiones, funcion)
end

local function tipoAlAzar()
    local ids = {}
    for id, _ in pairs(Crisis.tipos) do
        table.insert(ids, id)
    end
    if #ids == 0 then
        return nil
    end
    return ids[ZombRand(#ids) + 1]
end

-- El narrador decide si hay crisis
function Crisis.tirarDado()
    -- Las facciones protegidas por desconexion no reciben crisis
    local lista = {}
    for _, t in ipairs(Territorios.getDatos().lista) do
        if not (WorldQuest.Conflicto and WorldQuest.Conflicto.protegido(t)) then
            table.insert(lista, t)
        end
    end
    if #lista == 0 then
        return
    end

    local datos = Crisis.getDatos()
    datos.tension = datos.tension + 1
    local probabilidad = math.min(datos.tension * PROBABILIDAD_POR_TENSION * WorldQuest.Modificadores.factorNarrador()
        * WorldQuest.Opciones.frecuenciaCrisis() * Crisis.presion(), PROBABILIDAD_MAXIMA)
    print("[WorldQuest] Narrador: tension " .. datos.tension .. ", probabilidad " .. probabilidad .. "%")

    if ZombRand(100) >= probabilidad then
        return
    end

    local tipo = tipoAlAzar()
    if not tipo then
        return
    end

    datos.tension = 0
    Crisis.programar(tipo, lista[ZombRand(#lista) + 1])
end

WorldQuest.Reloj.alCiclo(function(ciclo)
    if ciclo % Crisis.CICLOS_NARRADOR == 0 then
        Crisis.tirarDado()
    end
end)
Events.EveryOneMinute.Add(Crisis.procesarPendientes)
