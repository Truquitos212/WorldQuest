# WorldQuest — Documento de diseño

Mod para Project Zomboid (Build 42) que convierte la supervivencia en un juego de
estrategia multijugador: facciones, colonias, diplomacia, comercio, guerra y victoria.
Inspiración: RimWorld, Command & Conquer, Age of Empires y The Walking Dead.

---

## 1. Estado actual (v0.2)

### Hecho
- Territorios: reclamar con nombre, renombrar, abandonar con confirmación, sin superposición, dueño.
- Mapa: territorios con relleno, borde, nombre, nivel, almacenes y crisis anunciadas.
- Crisis con narrador de tensión: horda, incendio, pérdida de comida, tormenta con frío,
  locura y asaltantes. Aviso grande en pantalla.
- Almacén de la colonia: marcar muebles, nombre propio visible en la ventana de botín,
  resaltado solo para el dueño, conteo de recursos.
- Colonos: llegada por evento, hambre, ánimo, roles, producción diaria y habilidades que suben.
- Niveles Refugio → Campamento → Asentamiento → Fortaleza. Estructuras detectadas y obras.
- Cuerpos de colonos con Bandits (opcional).
- Panel de la colonia con pestañas y botón en la barra izquierda.
- Traducciones español e inglés.

### Pendiente de probar
- Producción, hambre, niveles, obras, locura y asaltantes en partida real.
- Causa de la muerte de colonos con cuerpo de Bandits (hay diagnóstico en el log).

---

## 2. Principios de interfaz
- Un solo botón abre el **Centro de mando**; todo el mod vive ahí en pestañas.
  El clic derecho queda solo para acciones sobre algo puntual.
- Todo tiene un **tooltip** de una o dos frases: qué es y para qué sirve. Nunca qué viene después.
- **Sin tutorial, sin spoilers**: solo pistas cortas la primera vez que aparece algo nuevo,
  que después se pueden releer en Ayuda. Se aprende jugando.
- **Información en capas**: primero un número, un color o un ícono; el detalle al hacer clic.
- **Mismo orden en todas las ventanas**; el **estilo visual depende de la facción**.
- Español e inglés desde el principio.

---

## 3. Facciones

Cada jugador lidera o integra una facción. Varios jugadores pueden compartir una facción
(no es co-op: cada facción es una sola identidad). Se elige y personaliza antes de empezar:
tipo de facción, nombre, color, emblema y líder (el personaje del jugador) con un rasgo de líder.

### Regla de balance
Cada facción tiene **una ventaja fuerte, una ventaja menor y una debilidad que pesa lo mismo
que la ventaja fuerte**. Se cubren entre ellas como piedra, papel o tijera: ninguna le gana a
todas. Los rasgos de líder siguen la misma regla (tres por facción, de peso parecido).
Los números se ajustan jugando, con una tabla de balance.

| Facción | Ventaja fuerte | Ventaja menor | Debilidad | Estilo |
|---|---|---|---|---|
| Los Leales | Defensa de territorios | Disciplina (menos locura) | Consumen más; los mercenarios desconfían | Radio militar, mapas de campaña |
| La Comuna | Producción de comida | Ánimo alto | Débiles en combate | Cuaderno a mano, tonos tierra |
| Los Chatarreros | Construcción rápida | Más madera y metal | Producen poca comida | Industrial, metal oxidado |
| La Caravana | Comercio y caravanas seguras | Simpatía de mercenarios | Pocos territorios | Mapas de rutas, libretas de cuentas |
| Los Carroñeros | Saqueo y asaltos | Botín extra en expediciones | Mala reputación con todos | Grafiti, cinta adhesiva |
| Los Devotos | Atraen colonos | Casi no enloquecen | Economía lenta | Vitrales, velas |
| Los Moteros | Movilidad: caravanas, expediciones y asaltos rápidos | Respeto de mercenarios duros | Bases frágiles | Cuero, cromo, parches |
| Los Preppers | Resisten asedios; almacenes grandes, comida que no se pudre | (a definir) | Crecen lento: les cuesta aceptar colonos | Manuales de supervivencia, latas |
| Los Fugados | Combate cuerpo a cuerpo, sin miedo a las hordas | Simpatía de criminales y mercenarios turbios | Poca disciplina: peleas y locura | Overoles naranjos, marcas carcelarias |

---

## 4. Inicio de partida

Se elige al crear la partida:
- **Justo**: un algoritmo evalúa lugares y reparte a todos a la misma distancia entre sí,
  con recursos parecidos cerca. Nadie empieza junto a nadie ni con ventaja.
- **Pueblo chico**: todos en el mismo pueblo, en casas distintas.
- **Aleatorio (algoritmo STERAK)**: elige al azar uno de estos escenarios y reparte con azar
  dentro de sus reglas. Al empezar aparece un mensaje discreto con el escenario.
  - **Vecinos**: dos jugadores por pueblo (si son impares, uno queda solo).
  - **Triángulo**: en el mismo pueblo, dos jugadores pegados y uno más lejos
    (desparejo a propósito).
  - **Mal comienzo**: todos en las peores ubicaciones, pero todos igual de mal.

---

## 5. El comandante y el mapa de mando
- Sin debug, el juego deshace el modo fantasma, el modo dios y el noclip: no hay cámara libre.
- El líder se queda en un **puesto de mando** en la base principal (la zona "viva").
  Mientras esté ahí, los colonos lo alimentan con comida del almacén.
- Se juega desde el **mapa**: colonos como íconos (color por estado, símbolo por rol),
  selección por clic o rectángulo, órdenes con clic derecho (ir aquí, mantener posición,
  defender, volver, llamar), colocar obras con una silueta, amenazas y expediciones visibles.
- **Escuadras** con nombre, creadas desde el Centro de mando, seleccionables de un clic.
- La habilidad de cada colono define la velocidad y la calidad de su trabajo.
- Lo cercano se ve con cuerpos; lo lejano (otras bases, expediciones, caravanas) se simula.

---

## 6. Economía
- **Cinco recursos**, cada uno contando muchos items reales:
  - **Comida** (en calorías), **Madera** (troncos y tablas; el tronco vale más),
    **Metal** (clavos, chatarra, láminas, piezas), **Medicina**, **Munición**.
- **Sin moneda: todo es trueque** (cigarros, comida y munición como valores de cambio).
- Especialización de bases según sus estructuras.
- Riqueza total de cada facción (para la victoria económica y para el enemigo del modo Caos).
- Expediciones simuladas a zonas lejanas.
- Agua y combustible: fuera de la v1.0 (el agua de B42 usa un sistema de líquidos por investigar).

---

## 7. Diplomacia, comercio y conflicto

### Diplomacia
- Ventana con cada facción: **guerra, neutral, pacto comercial o alianza**.
- Propuestas (paz, alianza, comercio, tributo) que llegan como notificación.
- Reputación: romper pactos cuesta caro.

### Comercio
- Ofertas entre facciones y **caravanas** visibles en el mapa, que pueden ser emboscadas.

### Mercenarios
- Grupos chicos por el mapa con **personalidad** (codiciosos, leales, traicioneros,
  idealistas, oportunistas) y un **medidor de simpatía** hacia cada facción.
- Hostiles te cazan; neutrales te ignoran; simpatizantes comercian.
- **Inventario real y finito**: lo que les compras, ya no lo tienen.
- **Contratables por un tiempo**, pagando lo que piden según su personalidad
  (cigarros, comida, munición). Los oportunistas solo siguen a quien va primero en la tabla.

### Conflicto
- Asaltos entre jugadores (en vivo si es cerca, simulados si es lejos), sabotaje y espionaje.
- Los territorios se pueden **capturar, saquear o eliminar**.
- Quien se queda sin territorios pasa a **observador**: el Centro de mando completo,
  sin niebla, con la tabla y el registro (no hay cámara libre).

### Niebla de guerra con desfase
- Solo ves lo que exploraste, **tal como estaba la última vez que lo viste**.

### Partidas cerradas
- No hay pausa en el multijugador de Zomboid. Si un jugador se desconecta, su facción
  queda en **protección**: no la atacan, no consume y no produce hasta que vuelva.

---

## 8. Mundo: puntos de interés
- Lugares **fijos** en cada ciudad, siempre los mismos. Cada uno da puntos y recursos:
  - Comisaría (munición), hospital o clínica (medicina), supermercado (comida),
    ferretería o aserradero (madera y metal), escuela o iglesia (colonos),
    torre de radio (revela niebla, clave para el Éxodo), base militar (puntos, munición,
    clave para el Éxodo).
- Controlar **todos** los de una ciudad da un **bono de ciudad**.
- Pendiente: definir la lista exacta por ciudad (Muldraugh, West Point, Riverside,
  Rosewood, March Ridge y las nuevas de B42).

---

## 9. Puntuación y victoria
- **Tabla de puntuación siempre visible** para todos, como en Age of Empires.
- Al final, **resumen por jugador con línea de tiempo** (crecimiento, pérdidas, batallas).

### Modo estándar: varias formas de ganar en la misma partida
- **Éxodo**: completar primero el megaproyecto de evacuación (radio militar, helipuerto,
  colonos y recursos). Los demás lo ven avanzar y pueden sabotearlo.
- **Dominación**: controlar la mayoría de los puntos de interés o eliminar a las demás facciones.
- **Economía**: llegar primero a cierta riqueza total.

### Modo Caos: tres enemigos controlados por el juego
- **Los Militares**: quieren barrer la zona. Redadas periódicas, controles, los más fuertes
  en combate directo.
- **Los Fugados (rama dura)**: los presos que solo quieren arrasar. Tienen su propia base
  y crecen saqueando a todos. Comparten origen y estilo con la facción Los Fugados.
  - Si un jugador es de Los Fugados: al principio lo atacan menos, pero le exigen tributo.
    Si paga, lo dejan tranquilo y arriesga su reputación con los demás (pueden verlo como traidor).
    Si no paga, pasa a ser su primer objetivo.
  - Diplomacia única: puede negociar con ellos (por ejemplo, desviar un ataque), con riesgo.
- **La Horda que piensa**: se divide, flanquea y aparece en los momentos críticos
  (cuando alguien está por ganar o en plena guerra).
- Obliga a aliarse. Si ganan los enemigos, pierden todos.

---

## 10. Hoja de ruta

### Hito 1 — "Lo que hay, sólido" (v0.3)
- **Fase 0: estabilizar**
  - Probar producción, hambre, niveles, obras, locura y asaltantes.
  - Resolver la muerte de colonos con cuerpo.
  - Reemplazar los MODO_PRUEBA por una opción de partida.
  - Opciones de sandbox (frecuencia de crisis, costos, producción).
- **Fase 1: Centro de mando**
  - Rehacer el panel como Centro de mando con pestañas: Colonia, Mapa, Diplomacia,
    Comercio, Objetivos, Registro y Ayuda.
  - Tooltips reutilizables, registro de eventos, pistas de primera vez.
  - Estilo visual por facción e íconos.

### Hito 2 — "Jugable con amigos" (v0.5)
- **Fase 2: base multijugador**
  - El servidor es dueño de los datos; los jugadores mandan órdenes con comandos.
  - Pasar a esa forma todo lo que hoy hace el cliente.
  - Probar hosteando desde el juego.
- **Fase 3: facciones**
  - Creación y personalización de la facción (tipo, nombre, color, emblema, líder y rasgo).
  - Territorios, colonos y almacenes de la facción. Puesto de mando.
  - Modos de inicio: Justo, Pueblo chico y Aleatorio (STERAK).

### Hito 3 — "Estrategia" (v0.7)
- **Fase 4: mapa de mando** (íconos, selección, órdenes, escuadras, colocar obras, amenazas).
- **Fase 5: colonos vivos** (programa propio de Bandits, trabajo visible, ficha completa,
  decidir si Bandits es obligatorio).
- **Fase 6: economía** (cinco recursos, trueque, especialización, riqueza, expediciones).

### Hito 4 — "Mundo político" (v0.9)
- **Fase 7: diplomacia** (estados, propuestas, reputación).
- **Fase 8: comercio y mercenarios** (ofertas, caravanas, mercenarios con personalidad).
- **Fase 9: conflicto y mundo** (asaltos, sabotaje, niebla con desfase, puntos de interés,
  captura de territorios, observador, protección por desconexión).

### Hito 5 — "Ganar" (v1.0)
- **Fase 10: victoria** (Éxodo, Dominación, Economía, tabla siempre visible, resumen final).
- **Fase 11: pulido y publicación** (balance con amigos, rendimiento, sonidos, Workshop).

### Hito 6 — "Caos" (v1.1)
- **Fase 12: modo Caos** (Militares, Fugados de rama dura y la Horda que piensa; dificultad).

---

## 11. Investigación pendiente
1. Integrar la facción al creador de personajes del juego (si no, ventana propia al aparecer).
2. Convertir un clic en el mapa a coordenadas del mundo.
3. Escribir un programa propio de Bandits que obedezca órdenes.
4. Ver y editar ropa e inventario de los NPCs de Bandits.
5. Algoritmo de inicio justo: cómo evaluar lugares del mapa.
6. Lista exacta de puntos de interés por ciudad.
7. Necesidades del comandante: modificarlas desde el mod sin trucos de administrador.
8. Sistema de líquidos de B42 (agua), para una versión futura.