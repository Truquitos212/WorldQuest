-- WorldQuest - Red: mensajes que el servidor manda a los jugadores (cliente)

WorldQuest = WorldQuest or {}

local Red = WorldQuest.Red

-- Aviso grande en pantalla (si no hay banner, sobre la cabeza)
Red.mensaje("aviso", function(args)
    local texto = Red.traducir(args.clave, args.p)
    if WorldQuest.Banner then
        WorldQuest.Banner.mostrar(texto, args.tipo)
    else
        local jugador = getPlayer()
        if jugador then
            jugador:Say(texto)
        end
    end
    print("[WorldQuest] " .. texto)
end)

-- Frase sobre la cabeza del jugador
Red.mensaje("decir", function(args)
    local texto = Red.traducir(args.clave, args.p)
    local jugador = getPlayer()
    if jugador then
        jugador:Say(texto)
    end
    print("[WorldQuest] " .. texto)
end)
