# WorldQuest — Documento de diseño

Mod de colonia estilo RimWorld para Project Zomboid (Build 42).
Territorios, colonos, recursos y crisis en Knox County.

## Sistemas terminados

### Territorios
- Círculos guardados en ModData, con id fijo, nombre editable y radio.
- Reclamar, renombrar y abandonar desde el clic derecho, sin superposición.
- Avisos al entrar y salir. Dibujo en el mapa con relleno, borde, nombre y alertas.

### Crisis
- Narrador con tensión: sube cada día sin crisis y baja a cero cuando ocurre una.
- Cada crisis es una ficha (id, horas de aviso, textos, función ejecutar).
- Crisis actuales: horda (con aviso), incendio en una casa (sorpresa),
  pérdida de comida (sorpresa), tormenta con frío extremo en el territorio (con aviso).
- Solo se ejecutan si el territorio está cargado; si no, esperan al jugador.

## Decisiones de diseño

### Colonos: dos capas
1. **Simulación (propia):** los colonos son datos (nombre, rol, habilidades,
   hambre, ánimo) y producen o consumen aunque el jugador esté lejos.
2. **Cuerpos (opcional):** si el mod Bandits está instalado, los colonos aparecen
   como NPCs en el territorio. Cuando lleguen los NPCs oficiales (Build 43),
   se reemplaza solo esta capa.

### Recursos: items reales en un almacén
- El jugador marca muebles como "Almacén de la colonia".
- Los colonos consumen y producen items reales del juego en esos muebles.

### Estructuras: mezcla
- **Detectadas:** el mod reconoce lo que el jugador construye con el sistema
  del juego dentro del territorio (camas = cupos de colonos, huertos, mesas de trabajo...).
- **Proyectos del mod:** construcciones abstractas que los colonos levantan con
  materiales del almacén y tiempo (torre de vigilancia, muralla, radio...).

### Progresión
- Niveles: Refugio → Campamento → Asentamiento → Fortaleza.
- Subir de nivel cuesta recursos y colonos; aumenta el radio del territorio,
  los cupos y desbloquea estructuras.
- El narrador escala con la riqueza de la base.

## Hoja de ruta
1. Almacén de la colonia: marcar muebles y contar recursos.
2. Colonos como datos: llegada por evento, roles, hambre y ánimo, consumo diario.
3. Producción por rol: agricultor, explorador, constructor, guardia, médico.
4. Niveles de asentamiento.
5. Estructuras detectadas y proyectos del mod.
6. Crisis de colonos: locura, asaltantes y bandidos (resueltos por puntaje).
7. Cuerpos de colonos con Bandits (capa opcional).