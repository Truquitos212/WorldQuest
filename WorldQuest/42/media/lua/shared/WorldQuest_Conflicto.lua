-- WorldQuest - Conflicto: proteccion por desconexion, observadores y capturas (datos)
-- La logica corre en el servidor (server/WorldQuest_ConflictoServidor.lua).

WorldQuest = WorldQuest or {}
WorldQuest.Conflicto = WorldQuest.Conflicto or {}

local Conflicto = WorldQuest.Conflicto
local CLAVE_DATOS = "WorldQuest_Conflicto"

function Conflicto.getDatos()
    local datos = ModData.getOrCreate(CLAVE_DATOS)
    datos.capturas = datos.capturas or {}   -- id territorio -> { faccion, avance, necesario }
    return datos
end

-- Una faccion sin nadie conectado queda protegida: no la atacan, no consume y no produce
function Conflicto.faccionProtegida(f)
    return f ~= nil and f.proteccion == true
end

function Conflicto.protegido(t)
    local f = t and WorldQuest.Facciones.deTerritorio(t)
    return Conflicto.faccionProtegida(f)
end

-- Quien se queda sin territorios por la guerra pasa a observador
function Conflicto.esObservador(f)
    return f ~= nil and f.eliminada == true
end

-- Captura en curso de un territorio (o nil)
function Conflicto.captura(t)
    return t and Conflicto.getDatos().capturas[tostring(t.id)] or nil
end

-- Lo que se puede hacer contra un territorio ajeno: { asaltar = bool, espiar = bool }
function Conflicto.acciones(f, t)
    local r = { asaltar = false, espiar = false }
    if not f or not t or t.faccion == nil or t.faccion == f.id or Conflicto.esObservador(f) then
        return r
    end
    local D = WorldQuest.Diplomacia
    if D and D.aliados(f.id, t.faccion) then
        return r
    end
    local protegido = Conflicto.protegido(t)
    r.espiar = not protegido
    r.asaltar = not protegido and D ~= nil and D.enGuerra(f.id, t.faccion)
    r.protegido = protegido
    return r
end
