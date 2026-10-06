# Cabin Chaos — Plan de desarrollo

Leyenda: ⬜ pendiente · 🔄 en curso · ✅ hecha (esperando/obtenida confirmación del usuario)

Cada fase termina ejecutable, con bloque "Cómo probar" y espera confirmación antes de la siguiente. El game feel es criterio de aceptación en todas.

## Decisiones cerradas
- Victoria binaria: pasajeros ganan con ≥1 misión completada **o** satisfacción 0; si no, tripulación.
- El piloto puede salir de cabina con piloto automático (estabilidad se degrada).
- Monitor de cámaras para el piloto; sin sistema numérico de sospecha.
- Código en inglés; docs y UI en español.
- Personaje con autoridad del cliente (no a prueba de trampas; aceptado).

## Fases

### Fase 0 — Fundamentos y documentación ✅
Docs, estructura, Input Map, warnings de tipado, capas de colisión, escena principal vacía (`res://scenes/main/main.tscn`).

### Fase 1 — Prototipo local del personaje ✅
Sandbox, `CharacterBody3D`, cámara 3ª persona con `SpringArm3D`, interacción, agarrar/soltar/lanzar caja. Escrito consciente de la red (`is_multiplayer_authority()`).

### Fase 2 — Multijugador básico ✅
Autoload `Network`, Host/Join por IP, spawner, synchronizer con interpolación, nombres, desconexiones.

### Fase 3 — Interacciones sincronizadas ✅
Agarrar/lanzar en red (el portador es autoridad del objeto mientras lo sostiene), carrito, asientos, puerta del baño con seguro, compartimento y maleta.

### Fase 4 — Greybox del avión + esqueleto del loop ⬜
Avión completo con primitivas; `Match` con `LOBBY → FLIGHT → RESULTS`, roles, revancha limpia.

### Fase 5 — Roles y sistemas principales ⬜
Panel y cámaras del piloto, servir bebidas, satisfacción, HUD por rol, `GameBalance`. **Playtest 1.**

### Fase 6 — Caos físico (turbulencia) ⬜
Turbulencia, tropiezos, derrames, objetos voladores, recuperación.

### Fase 7 — Misiones secretas y captura ⬜
Sistema de misiones, 3 misiones, captura, condición de victoria. **Playtest 2.**

### Fase 8 — Loop completo y ritmo ⬜
Fases del vuelo, tormentas, 1–2 incidentes, resultados con momentos. **Playtest 3.**

### Fase 9 — Game feel y pulido ⬜
Squash & stretch, partículas, sonidos mínimos, balance, bugs.

## Pendientes conocidos
- `scenes/match/match.tscn` tiene un `Level` provisional (geometría del sandbox más cajas, carrito, maleta, asientos, baño con puerta y compartimento colocados a mano); lo reemplaza `plane.tscn` en la **Fase 4**. Entonces `scenes/test/sandbox.tscn` puede borrarse o dejarse solo como banco de pruebas.
- Cada traspaso de autoridad de un objeto (agarrar/soltar) imprime 2–3 avisos benignos `Ignoring sync data from non-authority`: un paquete del dueño anterior llega antes de que el receptor conozca al nuevo y Godot lo descarta.
- La línea de visión al elegir objetivo es solo de interfaz: el host no la valida (aceptado, no es a prueba de trampas).
- Posible empujón: al abrir la tapa del compartimento a menos de ~0.6 m del frente, la tapa puede empujar al jugador durante el giro (0.3 s). Si molesta, hacer que la tapa no colisione con jugadores.
- Sentado, el personaje no colisiona (se deshabilita su cápsula en su propio peer); los demás pueden atravesarlo.
- El jugador que entra a mitad de partida ve el estado discreto (puerta, asiento, compartimento) correcto tras ~1 snapshot; no hay estado inicial intermedio garantizado.
- `DebugTools` (autoload, atajos F1–F8) aún no existe; se crea cuando una fase lo necesite.
- Interpolación de remotos: lerp simple. Evaluar buffer con timestamp si hay jitter en Tailscale.
- Sin verificar: partida llena (5º jugador) y juego por Tailscale.
- Un jugador que se une con la partida ya en marcha aparece en su slot directamente; el flujo `LOBBY → FLIGHT → RESULTS` y el bloqueo de unión en vuelo llegan en la **Fase 4**.

## Estructura de carpetas

La estructura y sus reglas viven en `CLAUDE.md` → "Arquitectura del proyecto" (fuente única de verdad): `scenes/` (solo .tscn), `scripts/` (solo .gd, espejo de scenes + `autoload/`, `systems/`, `components/`, `resources/`) y `resources/` (solo instancias .tres).
Las carpetas se crean cuando se necesitan (git no versiona carpetas vacías). Escena de la Fase 1: `res://scenes/test/sandbox.tscn`.

## Registro de fases cerradas
- **Fase 0:** verificada con `godot --headless --import` y ejecución de 30 frames de `main.tscn` (0 errores/warnings); Input Map comprobado con un script que lista las acciones. Nota: F5/F8 coinciden con atajos del editor (Run/Stop); dentro de la ventana del juego funcionan, pero si molestan se reasignan.
- **Fase 1:** verificada con `--headless --import`, 120 frames del sandbox (0 errores/warnings), ejecución real con el MCP de Godot (renderer GL Compatibility, 0 errores) y un script temporal headless que comprobó: aterrizaje, avance, límite de velocidad, frenado, salto, selección de objetivo, agarrar (la caja queda a 0.01 m del punto de agarre), lanzar (12 m/s) e interruptor. Limitación: en headless no se puede capturar el ratón, así que agarrar/lanzar se probó llamando a la lógica, no con clics; cámara y feel requieren prueba manual.
- **Fase 2:** verificada con `--headless --import`, carga de `main.tscn` y del sandbox offline (0 errores/warnings) y con dos procesos headless reales (host + cliente) y una sonda temporal: ambos ven el roster y 2 jugadores con autoridad correcta, nombres y slots (colores); un desplazamiento de 1.5 m del cliente se replica al host; al cerrar el cliente el host elimina su personaje; al cerrar el host el cliente vuelve al menú con "El host cerró la partida". Sin verificar: input real, suavidad visual de la interpolación, partida llena (5º jugador), Tailscale.
- **Fase 3:** verificada con `--headless --import`, carga de `main.tscn`, del sandbox offline y de `Match` completo como host (0 errores/warnings), y con procesos headless reales (host + 2 clientes) y una sonda temporal fuera del repo. 3a: agarrar (el `holder_id` y la autoridad pasan al cliente), lanzar (la caja vuela y la autoridad vuelve al host), disputa simultánea (gana uno), desconexión del portador (el objeto queda libre) y rotura del agarre por distancia. 3b: carrito arrastrado por un cliente; puerta con seguro (un segundo jugador no puede abrirla; si quien lo puso se desconecta, el seguro se quita); asientos (ocupado rechaza, un solo asiento por jugador, sentarse/levantarse); compartimento; estado de puerta y compartimento abiertos antes de unirse visto por quien llega tarde. Corregido tras la prueba manual: la tapa del compartimento le quitaba el objetivo a la maleta (ahora se eligen por separado lo que se agarra y lo que se usa). Probado por el usuario en el editor con varias instancias. Sin verificar: Tailscale, partida llena (5º jugador), el empuje de la tapa sobre un jugador cercano y el feel del carrito en pasillos estrechos (llegan con el avión en la Fase 4).
