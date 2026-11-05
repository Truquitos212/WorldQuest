-- WorldQuest - punto de entrada del cliente

WorldQuest = WorldQuest or {}

print("[WorldQuest] Archivo cliente cargado")

local function onGameStart()
    print("[WorldQuest] Partida iniciada, mod funcionando")
end

Events.OnGameStart.Add(onGameStart)
