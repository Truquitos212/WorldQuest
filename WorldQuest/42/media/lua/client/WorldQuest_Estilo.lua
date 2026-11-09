-- WorldQuest - Estilo visual del Centro de mando (cliente)
-- Por ahora hay un solo estilo. En la Fase 3 cada faccion tendra el suyo
-- (Estilo.actual elegira segun la faccion del jugador).

WorldQuest = WorldQuest or {}
WorldQuest.Estilo = WorldQuest.Estilo or {}

local Estilo = WorldQuest.Estilo

local ESTILOS = {
    neutral = {
        texto = { 1, 1, 1 },
        gris = { 0.7, 0.7, 0.7 },
        acento = { 1, 0.85, 0.5 },
        alerta = { 1, 0.5, 0.4 },
        bien = { 0.5, 0.9, 0.5 },
        frio = { 0.6, 0.8, 1 },
        seleccion = { 0.3, 0.5, 0.7 },
        fondoAyuda = { 0.08, 0.08, 0.08 },
        bordeAyuda = { 1, 0.85, 0.5 },
    },
}

function Estilo.actual()
    return ESTILOS.neutral
end
