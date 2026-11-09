-- WorldQuest - Crisis: narrador y crisis pendientes

WorldQuest = WorldQuest or {}
WorldQuest.Crisis = WorldQuest.Crisis or {}

local Crisis = WorldQuest.Crisis
local Territorios = WorldQuest.Territorios
local CLAVE_DATOS = "WorldQuest_Crisis"

-- Narrador: la tension sube un punto por cada dia sin crisis
local PROBABILIDAD_POR_TENSION = 10 -- % por punto de tension
local PROBABILIDAD_MAXIMA = 80      -- % tope

Crisis.tipos = Crisis.tipos or {}

-- Agrega un tipo de crisis (una "ficha")
function Crisis.registrar(ficha)
    Crisis.tipos[ficha.id] = ficha
end

function Crisis.getDatos()
    local datos = ModData.getOrCreate(CLAVE_DATOS)
    datos.tension = datos.tension or 0
    datos.pendientes = datos.pendientes or {}
    return datos
end

local function horaActual()
    return getGameTime():getWorldAgeHours()
end

-- Mensaje al jugador (por ahora sobre su cabeza)
function Crisis.avisar(texto, tipo)
    -- Aviso grande en pantalla si esta disponible; si no, sobre la cabeza
    if WorldQuest.Banner then
        WorldQuest.Banner.mostrar(texto, tipo)
        print("[WorldQuest] " .. texto)
        return
    end
    local jugador = getPlayer()
    if jugador then
        jugador:Say(texto)
    end
    print("[WorldQuest] " .. texto)
end

-- true si el centro del territorio esta cargado (el jugador anda cerca)
function Crisis.estaCargado(territorio)
    return getCell():getGridSquare(territorio.x, territorio.y, 0) ~= nil
end

-- Deja una crisis pendiente. Si inmediata es true, se salta la espera del aviso
function Crisis.programar(idTipo, territorio, inmediata)
    local ficha = Crisis.tipos[idTipo]
    if not ficha then
        return
    end

    local espera = 0
    if not inmediata then
        espera = WorldQuest.Modificadores.horasAviso(territorio, ficha.horasAviso or 0)
    end

    table.insert(Crisis.getDatos().pendientes, {
        tipo = idTipo,
        territorio = territorio.id,
        hora = horaActual() + espera,
    })

    if ficha.textoAviso then
        Crisis.avisar(getText(ficha.textoAviso, territorio.nombre), "aviso")
    end
    print("[WorldQuest] Crisis programada: " .. idTipo .. " en " .. territorio.nombre .. " (en " .. espera .. " horas)")
end

-- Ejecuta las crisis pendientes cuya hora llego, si el territorio esta cargado
function Crisis.procesarPendientes()
    local pendientes = Crisis.getDatos().pendientes
    local ahora = horaActual()

    for i = #pendientes, 1, -1 do
        local pendiente = pendientes[i]
        local territorio = Territorios.buscarPorId(pendiente.territorio)
        local ficha = Crisis.tipos[pendiente.tipo]

        if not territorio or not ficha then
            -- Territorio abandonado o tipo que ya no existe: se descarta
            table.remove(pendientes, i)
        elseif ahora >= pendiente.hora and Crisis.estaCargado(territorio) then
            table.remove(pendientes, i)
            -- La ficha devuelve false si no pudo ejecutarse
            if ficha.ejecutar(territorio) ~= false and ficha.textoInicio then
                Crisis.avisar(getText(ficha.textoInicio, territorio.nombre), "crisis")
            end
        end
    end
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

-- Una vez al dia: el narrador decide si hay crisis
function Crisis.tirarDado()
    local lista = Territorios.getDatos().lista
    if #lista == 0 then
        return
    end

    local datos = Crisis.getDatos()
    datos.tension = datos.tension + 1
    local probabilidad = math.min(datos.tension * PROBABILIDAD_POR_TENSION * WorldQuest.Modificadores.factorNarrador() * WorldQuest.Opciones.frecuenciaCrisis(), PROBABILIDAD_MAXIMA)
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

Events.EveryDays.Add(Crisis.tirarDado)
Events.EveryTenMinutes.Add(Crisis.procesarPendientes)
