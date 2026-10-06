# Cabin Chaos

Party game multijugador cómico de 4 jugadores ambientado en un vuelo comercial. Un piloto, un aeromozo y dos pasajeros con objetivos en conflicto; la comedia surge de la física torpe, los objetos voladores y la comunicación entre amigos (Discord). Todo el arte son primitivas de colores planos.

**Estado:** en desarrollo por fases. Hechas las fases 0–4 (personaje, red, interacciones sincronizadas, avión greybox y loop `LOBBY → FLIGHT → RESULTS`). Siguiente: roles y sistemas principales. Ver [`DEVELOPMENT_PLAN.md`](DEVELOPMENT_PLAN.md).

## Stack
- Godot 4.7, GDScript tipado
- Jolt Physics, renderer GL Compatibility
- Red: multijugador de alto nivel de Godot (ENet), host autoritativo, hasta 4 jugadores

## Cómo ejecutarlo
1. Abre el proyecto con Godot 4.7 y ejecuta `res://scenes/main/main.tscn` (escena principal).
2. Un jugador pulsa **Crear partida (Host)**; los demás **Unirse** con su IP (puerto 7777; para jugar a distancia, por ejemplo con Tailscale).
3. En el lobby, el host abre el menú con `Esc` y pulsa **Iniciar vuelo**.

Para probar con varias instancias en el editor: *Debug → Customize Run Instances*. Argumentos de arranque (tras `--`) que saltan el menú: `--host`, `--join=IP`, `--name=Nombre`.

## Controles
| Acción | Tecla |
|---|---|
| Mover | WASD |
| Saltar | Espacio |
| Interactuar | E |
| Agarrar / soltar | Clic izquierdo |
| Lanzar | Clic derecho |
| Menú (libera el ratón) | Esc |

## Documentación
- [`GAME_DESIGN.md`](GAME_DESIGN.md): concepto, roles, misiones y reglas de victoria
- [`NETWORKING.md`](NETWORKING.md): arquitectura de red y patrones de sincronización
- [`DEVELOPMENT_PLAN.md`](DEVELOPMENT_PLAN.md): fases, estado y pendientes
- [`CLAUDE.md`](CLAUDE.md): convenciones de código, estructura de carpetas y flujo de trabajo
