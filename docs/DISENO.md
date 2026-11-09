# WorldQuest — Documento de diseño

Mod de colonia estilo RimWorld para Project Zomboid (Build 42.21).

## Estado: 7 de 7 fases implementadas (sin probar desde la fase 3)

| Sistema | Estado |
|---|---|
| Territorios (reclamar, renombrar, abandonar, mapa, avisos) | Probado |
| Traducciones ES/EN | Probado |
| Crisis: horda, incendio, comida, tormenta con frío | Probado |
| Aviso en pantalla y crisis en el mapa | Sin probar |
| Fase 1: Almacén de la colonia | Sin probar |
| Fase 2: Colonos (llegada, hambre, ánimo) | Sin probar |
| Fase 3: Producción por rol | Sin probar |
| Fase 4: Niveles Refugio → Fortaleza | Sin probar |
| Fase 5: Estructuras detectadas y obras | Sin probar |
| Fase 6: Locura y asaltantes | Sin probar |
| Fase 7: Cuerpos con Bandits (opcional) | Sin probar |

## Decisiones de diseño
- Colonos en dos capas: simulación propia + cuerpos con Bandits (Bandits2) si está activo.
- Recursos como items reales en muebles marcados como almacén.
- Estructuras: detectadas (camas, huertos, cocinas, generadores) + obras del mod (torre, taller, muralla, radio).
- Efectos centralizados en WorldQuest_Modificadores.lua.

## Pendiente para la versión 1.0
1. Probar en el juego todo lo marcado "Sin probar" y corregir errores.
2. Balancear números (producción, costos, probabilidades, ánimo).
3. Desactivar MODO_PRUEBA en los menús de prueba.
4. Preparar la publicación en el Workshop (poster, workshop.txt, descripción).
5. Multijugador: separar cliente y servidor con comandos (hoy funciona en un jugador).

## WorldQuest 2.0: modo estrategia (visión)

Llevar la supervivencia a otro nivel: dejar de controlar a un personaje y manejar
la colonia desde la vista isométrica, como un juego de estrategia.
Inspiración: RimWorld, Command & Conquer y The Walking Dead.

### Decisiones
- El jugador es un **comandante invisible**: solo cámara y órdenes, como en RimWorld.
- Bandits como requisito o como modo aparte: se decide después de investigar.

### Ideas
- Ubicar a los colonos: lista con "Ir a", marcados en el mapa y en el mundo, botón "Llamar".
- Seleccionar colonos con el mouse y darles órdenes: mover, quedarse, trabajar.
- Elegir dónde se construye cada obra con un cursor fantasma.
- Que los colonos construyan y trabajen de verdad (caminar al sitio, animaciones),
  y que al terminar aparezca la estructura real en el mundo.

### Investigación pendiente
1. Cámara: ¿se puede volver fantasma al personaje (invisible, sin colisión, sin daño)
   desde un mod en una partida normal? ¿Se puede alejar más el zoom?
2. Órdenes: cómo escribir un programa propio de Bandits que obedezca órdenes.
3. Clics en el mundo: cómo saber qué casilla o qué NPC está bajo el mouse.