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