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
Docs, estructura, Input Map, warnings de tipado, capas de colisión, escena principal vacía (`res://main/main.tscn`).
Pendiente de entorno (acción del usuario): instalar Git (no está en PATH) y hacer `git init`.

### Fase 1 — Prototipo local del personaje ⬜
Sandbox, `CharacterBody3D`, cámara 3ª persona con `SpringArm3D`, interacción, agarrar/soltar/lanzar caja. Escrito consciente de la red (`is_multiplayer_authority()`).

### Fase 2 — Multijugador básico ⬜
Autoload `Network`, Host/Join por IP, spawner, synchronizer con interpolación, nombres, desconexiones.

### Fase 3 — Interacciones sincronizadas ⬜
Agarrar/lanzar con autoridad del host, carrito, asientos, puerta del baño con seguro, compartimento.

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

## Estructura de carpetas

La estructura y sus reglas viven en `CLAUDE.md` → "Arquitectura del proyecto" (fuente única de verdad): `scenes/` (solo .tscn), `scripts/` (solo .gd, espejo de scenes + `autoload/`, `systems/`, `components/`, `resources/`) y `resources/` (solo instancias .tres).
Las carpetas se crean cuando se necesitan (git no versiona carpetas vacías). Escena de la Fase 1: `res://scenes/test/sandbox.tscn`.

## Registro de fases cerradas
- **Fase 0:** verificada con `godot --headless --import` y ejecución de 30 frames de `main.tscn` (0 errores/warnings); Input Map comprobado con un script que lista las acciones. Nota: F5/F8 coinciden con atajos del editor (Run/Stop); dentro de la ventana del juego funcionan, pero si molestan se reasignan.
