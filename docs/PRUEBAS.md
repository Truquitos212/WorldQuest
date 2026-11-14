# WorldQuest — Plan de prueba multijugador

Una sola sesión larga con tu primo, hosteando desde el juego. La idea es pasar por
todo sin cerrar el juego, anotar lo que falle y después revisar el log de una.

## Antes de entrar
1. Aplica los parches y revisa que el junction siga apuntando al repo.
2. Crea la partida con **Hostear** y en las opciones de WorldQuest pon:
   - Herramientas de prueba: **sí**
   - Duración: **Rápida**
   - Niebla de guerra: **sí**
   - Modo de inicio: **Pueblo chico** (así quedan cerca para probar rápido)
   - Modo de juego: **Estándar** (el Caos va en una segunda partida)
3. Si tienen Bandits, actívenlo los dos (es opcional).

## Ronda 1 — Base (los dos)
- [ ] Al entrar se abre sola la ventana de facción. Cada uno crea la suya (tipos distintos).
- [ ] Reclamar territorio, marcar almacén, `[Prueba] Llenar almacén`.
- [ ] Centro de mando: las pestañas se ven bien en 940 px; los recursos salen con su ícono.
- [ ] Arriba a la derecha está la tabla de puntos (clic en el título la pliega).
- [ ] Clic derecho > `Probar llegada de colono`: la ventana muestra rasgos y oficio. Aceptar 4 o 5.
- [ ] Ficha del colono: oficio, edad, rasgos con su ayuda, estado.
- [ ] Asignar roles; mejorar a Campamento (cuesta madera y metal).

## Ronda 2 — Mapa de mando y expediciones
- [ ] En el mapa: elegir colonos (clic o Shift + arrastrar) y darles órdenes.
- [ ] Clic derecho lejos de la base: **Enviar de expedición aquí**. Se ve el ícono viajando.
- [ ] Pestaña Mapa: el viaje aparece; clic para llamarlo de vuelta.
- [ ] Al volver llega el botín (o "Por guardar" si nadie estaba cerca).
- [ ] `[Prueba] Probar crisis > Con aviso > Horda`: en el mapa se ve la amenaza acercarse.

## Ronda 3 — Diplomacia y comercio
- [ ] Pestaña Diplomacia: proponer pacto, el otro acepta desde la ventana que le salta.
- [ ] Ofrecer y exigir un tributo; negarlo da motivo de guerra sin costo.
- [ ] Pestaña Comercio: oferta, el otro acepta, salen dos caravanas ($ en el mapa).
- [ ] `[Prueba] Mercenarios amigos cerca`: comerciar y contratar; la defensa sube.
- [ ] `[Prueba] Mercenarios hostiles cerca`: al rato atacan la base.

## Ronda 4 — Guerra y mundo
- [ ] Declarar guerra. El otro deja de ver tu base si está lejos (niebla) y queda la foto.
- [ ] Emboscar una caravana del enemigo con colonos elegidos.
- [ ] Clic derecho sobre la base enemiga con colonos: asaltar (saquear), espiar y sabotear.
- [ ] Entrar a la base enemiga y **Capturar** con clic derecho; el otro entra y la captura queda en disputa.
- [ ] `[Prueba] Poner un lugar aquí` (comisaría) dentro de tu territorio: entrega munición por ciclo.
- [ ] Caminar por un pueblo: en el registro aparecen lugares descubiertos de verdad.
- [ ] Que uno se desconecte: el otro ve "(protegida)" en la tabla y no puede atacarlo.

## Ronda 5 — Victoria
- [ ] Pestaña Objetivos: requisitos del Éxodo con [x] y [ ].
- [ ] Construir Helipuerto (pide Asentamiento), iniciar la evacuación.
- [ ] `[Prueba] Evacuación al 95%`: arranca la cuenta regresiva, se ve en la tabla.
- [ ] Sabotear la evacuación desde la otra facción: baja y se corta la cuenta.
- [ ] `[Prueba] Adelantar 30 min de partida` varias veces hasta el final por tiempo.
- [ ] Sale el resumen final con la línea de tiempo.

## Ronda 6 — Modo Caos (partida nueva)
- [ ] Modo de juego: **Caos**. Al rato aparece la base de los Fugados y los controles.
- [ ] La tabla muestra la amenaza; redadas y ataques llegan con aviso.
- [ ] Si alguien es de Los Fugados: le piden tributo; pagar, negarse y desviar un ataque.
- [ ] Asaltar la base de los Fugados con colonos.
- [ ] `[Prueba] Subir 30 la amenaza` hasta 100: pierden todos.

## Si algo falla
Anota qué estabas haciendo y busca las líneas del mod en el log:

```powershell
Select-String -Path "$env:USERPROFILE\Zomboid\console.txt" -Pattern "WorldQuest" | Select-Object -Last 80
```

Al hostear desde el juego, lo que pasa en el servidor queda en otro archivo:

```powershell
Select-String -Path "$env:USERPROFILE\Zomboid\server-console.txt" -Pattern "WorldQuest.*Error|Error.*WorldQuest" | Select-Object -Last 40
```
