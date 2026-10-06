# Cabin Chaos — guía para Claude

Party game multijugador (4 jugadores) de caos en un avión. Godot 4.7, GDScript tipado, Jolt Physics, renderer GL Compatibility.
Diseño: `GAME_DESIGN.md` · Red: `NETWORKING.md` · Estado y fases: `DEVELOPMENT_PLAN.md`

## Forma de trabajar
- Fases pequeñas; cada una termina ejecutable. **No avanzar de fase sin confirmación del usuario.**
- El usuario es senior backend (Rails) y principiante en gamedev: explicar brevemente cada concepto nuevo de Godot (qué es, para qué sirve, por qué lo usamos). No explicar programación general.
- No sobreingenierizar, no añadir features fuera del MVP sin preguntar. Avisar si algo es poco divertido o riesgoso. No dar la razón por inercia.
- Verificar con el MCP de Godot y `godot --headless` antes de pedir pruebas. Nunca afirmar haber probado lo que no se ejecutó; decir explícitamente qué requiere prueba manual.
- Al cerrar fase: actualizar `DEVELOPMENT_PLAN.md` y la sección "Estado actual" de este archivo, sugerir mensaje de commit (flujo de ramas: ver "Flujo de Git") y dar el bloque **"Cómo probar"**: escena exacta a ejecutar, cómo lanzarla (instancias/host/join), pasos numerados, qué se debe ver, qué evaluar del feel (con los `@export` tuneables) y qué no pude verificar.
- **Game feel es criterio de aceptación en cada fase**: inercia, suavizado, feedback inmediato, valores tuneables con `@export`.
- Arte: solo primitivas (cajas, cápsulas, esferas, colores planos). No descargar assets.

## Flujo de Git (obligatorio)
- **`main` siempre contiene solo trabajo probado y aceptado por el usuario.** Nunca se trabaja ni se commitea directo en `main` (excepto el commit inicial del repo).
- **Cada fase (y cada tarea o bugfix aparte) vive en su propia rama**, creada desde `main` actualizado al empezar:
  - Fases: `fase-N-nombre-corto` (ej. `fase-1-personaje-local`).
  - Otros: `feat/...`, `fix/...`, `chore/...` en kebab-case.
- Durante la fase se puede commitear en la rama para guardar avance (commits pequeños, mensaje en español, imperativo).
- **Al terminar la fase:** verificar (headless + bloque "Cómo probar") → el usuario prueba y **acepta** → recién entonces: commit final de cierre (con `DEVELOPMENT_PLAN.md` y "Estado actual" actualizados) → merge a `main` (`git merge --no-ff` para conservar el historial de la fase) → opcionalmente borrar la rama.
- **No hacer merge, commit en `main` ni push sin que el usuario lo haya pedido o aceptado explícitamente.** Si el usuario encuentra un bug durante la prueba, se arregla en la misma rama antes del merge.
- Antes de crear la rama o commitear, revisar `git status` y que no haya archivos basura (`.godot/`, `.claude/settings.local.json` están ignorados).
- Nunca hacer coautor en el commit, el commit es sólo del usuario.
- Conventional commits.

## Arquitectura del proyecto (obligatoria)

Separación por **tipo de archivo** en el primer nivel y por **dominio** en el segundo. Las subcarpetas de `scenes/` y `scripts/` se **reflejan** una a una.

```
res://
├─ CLAUDE.md, GAME_DESIGN.md, NETWORKING.md, DEVELOPMENT_PLAN.md, project.godot, icon.svg   (únicos archivos en la raíz)
├─ scenes/              SOLO .tscn
│  ├─ main/             main.tscn, connect_menu.tscn
│  ├─ player/           player.tscn, player_camera.tscn
│  ├─ plane/            plane.tscn, seat.tscn, door.tscn, overhead_bin.tscn, cockpit.tscn...
│  ├─ props/            cart.tscn, cup.tscn, bag.tscn, grabbable_box.tscn
│  ├─ match/            match.tscn
│  ├─ ui/               hud.tscn, pilot_panel.tscn, results.tscn
│  └─ test/             sandbox.tscn y escenas de prueba (nunca referenciadas por el juego real)
├─ scripts/             SOLO .gd
│  ├─ autoload/         network.gd, debug_tools.gd  (únicos scripts sin escena)
│  ├─ main/  player/  plane/  props/  match/  ui/      (espejo de scenes/)
│  ├─ systems/          satisfaction.gd, turbulence.gd, missions.gd, incidents.gd (nodos hijos de Match)
│  ├─ components/       piezas reutilizables adjuntables a cualquier nodo (interactable.gd, grabbable.gd, seat_slot.gd...)
│  └─ resources/        definiciones de Resource: game_balance.gd, mission_definition.gd
└─ resources/           SOLO instancias .tres/.res: game_balance.tres, missions/*.tres, materials/*.tres
```

Reglas:
1. **Un script por escena, mismo nombre, ruta espejo:** `scenes/player/player.tscn` ↔ `scripts/player/player.gd`. Quien busque una escena encuentra su script sin pensar.
2. **Nada suelto en la raíz** salvo los archivos listados. Si un archivo nuevo no encaja en ninguna carpeta, **preguntar al usuario antes de inventar una**.
3. **Comportamiento reutilizable = componente** (`scripts/components/`), no herencia profunda ni copy-paste. Ej.: `Grabbable`, `Interactable` como nodos/scripts que se añaden a cualquier objeto.
4. **Sistemas de partida** (`scripts/systems/`) son nodos hijos de `Match`, no autoloads. Solo hay 2 autoloads: `Network` y `DebugTools`.
5. **Datos de balance en Resources**, nunca números mágicos en la lógica. La *clase* va en `scripts/resources/`, las *instancias* en `resources/`.
6. **Materiales:** reutilizar `.tres` de `resources/materials/` (colores planos por nombre: `mat_player_red`, `mat_seat_gray`...). No crear materiales inline repetidos.
7. **Referencias entre escenas por ruta `res://` o `preload`/`@export`**, nunca rutas relativas frágiles (`../../Algo`). Para hijos propios usar `@onready` con `%NombreUnico`.
8. **Las escenas de `scenes/test/` no se importan desde el juego real.** Se pueden borrar sin romper nada.
9. **Main solo orquesta** (menú ↔ partida). La lógica de juego vive en `Match` y sus sistemas; la de jugador en `Player`.
10. **Mover o renombrar archivos solo desde el editor de Godot o actualizando referencias** (rutas `res://` y UIDs); verificar con `--headless --import` después.
11. Nombres: nodos en `PascalCase`, archivos y carpetas en `snake_case`, un `class_name` solo si el tipo se usa desde otros scripts.
12. Cada fase debe dejar el árbol limpio: sin archivos huérfanos, sin escenas temporales y sin código comentado.

## Convenciones GDScript
- Todo tipado: variables, parámetros y retornos (`-> void`). Los warnings de tipado están activos en `project.godot`; no dejarlos en el código.
- Archivos y carpetas en `snake_case`; `class_name` en PascalCase solo para tipos reutilizados.
- Orden en un script: `class_name`/`extends`, `signal`, `enum`, `const`, `@export`, vars públicas, vars privadas (`_x`), `@onready`, callbacks de Godot, métodos públicos, métodos privados.
- Señales en pasado (`grabbed`, `satisfaction_changed`). "Call down, signal up": un nodo llama métodos de sus hijos y emite señales hacia sus padres.
- Constantes de balance en un `Resource` (clase en `scripts/resources/game_balance.gd`, instancia en `resources/game_balance.tres`), no números mágicos.
- Código e identificadores en inglés; documentación y textos de UI en español.
- Capas de colisión 3D: 1 `world`, 2 `players`, 3 `grabbables`, 4 `interactables`.

## Input Map (definido en project.godot)
`move_forward/back/left/right` (WASD), `jump` (Espacio), `interact` (E), `grab` (clic izq.), `throw` (clic der.), `debug_1`..`debug_8` (F1–F8).

## Reglas de red (resumen; ver `NETWORKING.md`)
- Host autoritativo para todo estado de juego y objetos físicos compartidos.
- Cada jugador es autoridad de su propio personaje; los demás lo interpolan.
- Los clientes nunca modifican estado compartido: piden por RPC, el host valida y replica.
- Todo RPC que llega al host valida remitente (`multiplayer.get_remote_sender_id()`), distancia y estado.
- Toda feature nueva debe funcionar con al menos 2 instancias.
- Todo sistema debe saber reiniciarse para la revancha.

## Entorno
- Godot: `C:\Users\PC\Desktop\Godot_v4.7.2-stable_win64.exe`
- Verificación headless: `& $godot --headless --path . --quit` (parseo/carga) y `--quit-after N` para ejecutar N frames.
- Multi-instancia en el editor: Debug → Customize Run Instances. Primera instancia = Host; el resto = Join a `127.0.0.1`.
- Git no estaba instalado al empezar (Fase 0): ver `DEVELOPMENT_PLAN.md`.

## Estado actual
Fases 0 y 1 aceptadas y en `main`. Fase 2 (multijugador básico) implementada en la rama `fase-2-multijugador-basico`, esperando prueba manual y aceptación del usuario antes de mergear. Siguiente: Fase 3 — interacciones sincronizadas. Detalle en `DEVELOPMENT_PLAN.md`.
