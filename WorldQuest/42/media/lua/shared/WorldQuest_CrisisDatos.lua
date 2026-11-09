-- WorldQuest - Crisis: datos compartidos (los lee el panel y el mapa en el cliente)
-- La logica del narrador y de cada crisis corre en el servidor (server/WorldQuest_Crisis*.lua)

WorldQuest = WorldQuest or {}
WorldQuest.Crisis = WorldQuest.Crisis or {}

local Crisis = WorldQuest.Crisis
local CLAVE_DATOS = "WorldQuest_Crisis"

-- El narrador tira el dado cada CICLOS_NARRADOR ciclos
Crisis.CICLOS_NARRADOR = 3

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
