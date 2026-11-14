-- WorldQuest - Mundo (servidor): registra los lugares que descubren los jugadores y
-- entrega lo que producen a la faccion que los controla.

require "WorldQuest_Mundo"
require "WorldQuest_EconomiaServidor"

local Mundo = WorldQuest.Mundo
local E = WorldQuest.Economia
local Red = WorldQuest.Red
local Facciones = WorldQuest.Facciones

Red.agregarClave("WorldQuest_Mundo")

local DISTANCIA_MINIMA = 150      -- entre dos lugares del mismo tipo

Red.orden("lugarVisto", function(jugador, args)
    local tipo = Mundo.tipo(args.tipo)
    local x, y = tonumber(args.x), tonumber(args.y)
    local pueblo = type(args.pueblo) == "string" and string.sub(args.pueblo, 1, 40) or "Knox"
    if not tipo or not x or not y then
        return
    end
    -- Un lugar de cada tipo por ciudad, y lejos de otro igual
    for _, l in ipairs(Mundo.getDatos().lugares) do
        if l.tipo == tipo.id and l.pueblo == pueblo then
            return
        end
    end
    if Mundo.cercano(tipo.id, x, y, DISTANCIA_MINIMA) then
        return
    end
    local datos = Mundo.getDatos()
    local lugar = { id = datos.siguienteId, tipo = tipo.id, x = math.floor(x), y = math.floor(y), pueblo = pueblo,
        descubierto = getGameTime():getWorldAgeHours() }
    datos.siguienteId = datos.siguienteId + 1
    table.insert(datos.lugares, lugar)
    Red.cambio()
    local f = Facciones.deJugador(jugador)
    if f then
        Red.avisarFaccion(f, "IGUI_WQ_Lugar_Descubierto", { { clave = "IGUI_WQ_Lugar_" .. tipo.id }, pueblo }, "aviso")
    end
    print("[WorldQuest] Lugar nuevo: " .. tipo.id .. " en " .. pueblo .. " (" .. lugar.x .. ", " .. lugar.y .. ")")
end)

-- Cada ciclo: los lugares controlados entregan lo suyo al territorio que los cubre
local function alPasarCiclo()
    local protegido = WorldQuest.Conflicto and WorldQuest.Conflicto.protegido
    for _, l in ipairs(Mundo.getDatos().lugares) do
        local f, t = Mundo.controlador(l)
        local tipo = Mundo.tipo(l.tipo)
        if f and t and tipo and not (protegido and protegido(t)) then
            local factor = WorldQuest.Opciones.produccion()
            if Mundo.tieneCiudad(f, l.pueblo) then
                factor = factor * Mundo.BONO_CIUDAD
            end
            local entrega = {}
            for recurso, n in pairs(tipo.da) do
                entrega[recurso] = math.floor(n * factor)
            end
            if next(entrega) then
                E.entregar(t, entrega)
            end
            -- Cambio de dueno: aviso a la nueva faccion
            if l.faccion ~= f.id then
                l.faccion = f.id
                Red.avisar("IGUI_WQ_Lugar_Controlado", { f.nombre, { clave = "IGUI_WQ_Lugar_" .. tipo.id }, l.pueblo }, "aviso")
            end
        elseif not f and l.faccion then
            l.faccion = nil
        end
    end
end

WorldQuest.Reloj.alCiclo(alPasarCiclo)
