# Cabin Chaos — Arquitectura de red

## Stack
High-level multiplayer de Godot: `ENetMultiplayerPeer`, `MultiplayerSpawner`, `MultiplayerSynchronizer`, RPCs y multiplayer authority. Un jugador es host (peer id 1), los demás se conectan por IP (Tailscale; sin NAT traversal ni matchmaking). Máximo 4 peers.

Conceptos clave:
- **Peer id:** identificador de cada instancia; el host siempre es `1`.
- **Multiplayer authority:** el peer que "manda" sobre un nodo (por defecto el host). Solo la autoridad modifica y sincroniza ese nodo.
- **RPC:** llamada a función en otro peer (`@rpc`). Con `rpc_id(1, ...)` se llama al host.

## Principio rector
**El host es la fuente de verdad** de todo estado de juego. **Cada jugador es autoridad de su propio personaje** (se siente instantáneo; no es a prueba de trampas, lo cual aceptamos entre amigos). Prioridad: consistencia y jugabilidad sobre precisión física.

## Tabla de autoridad

| Sistema | Autoridad | Replicación |
|---|---|---|
| Estado de partida, roles, misiones, satisfacción, incidentes, turbulencia, timer | Host | Variables sincronizadas en `Match` + RPCs de eventos |
| Personaje (posición, rotación, estado: normal/tumbado/capturado/sentado) | Dueño (cliente) | `MultiplayerSynchronizer` del dueño; remotos interpolan |
| Input | Dueño | No se envía; se envía el resultado |
| Objetos físicos (cajas, maletas, vasos, objetos del carrito) | Host en reposo o lanzados; **el portador mientras los sostiene** | `NetworkedBody` replica transform desde la autoridad; el resto los congela (`freeze` kinematic) e interpola |
| Carrito | Igual que los objetos físicos (portador mientras lo lleva) | Mismo mecanismo; se agarra con clic, no se lanza, y gira hacia donde mira el portador |
| Quién sostiene un objeto (`holder_id`) | Host | Variable ON_CHANGE; su setter reasigna la autoridad del cuerpo en cada peer |
| Puertas, seguro, compartimentos, asientos | Host | Cliente pide por RPC, host decide y replica estado discreto (`is_open`, `locked_by`, `occupant_id`); cada peer anima por su cuenta |
| UI y cámara | Local | Nunca se replican |

## Patrón "petición → validación → broadcast"
Todo cambio de estado compartido:
1. El cliente llama `rpc_id(1, "request_x", ...)`.
2. El host valida: remitente (`multiplayer.get_remote_sender_id()`), distancia, estado actual, cooldowns.
3. Si es válido, el host cambia el estado y lo replica (propiedad sincronizada o RPC a todos).
4. El cliente puede mostrar feedback optimista inmediato (sonido, "pop"), pero el estado real lo dicta el host.

## Las cinco preguntas (antes de implementar cualquier mecánica física)
1. ¿Quién tiene autoridad?
2. ¿Cómo se replica el estado?
3. ¿Qué pasa si dos jugadores interactúan a la vez? (el primero que llega al host gana)
4. ¿Qué pasa si un jugador se desconecta?
5. ¿Hay algún objeto que dos peers simulen a la vez? (prohibido)

## Decisiones físicas
- **El carrito no se empuja por colisión:** se agarra (interacción explícita) y sigue al portador. Mientras lo lleva, el portador es su autoridad (se siente instantáneo). Motivo: en el host, un jugador remoto es una "marioneta" que se teletransporta según la red y no empuja `RigidBody3D` de forma estable.
- Roces casuales jugador→objeto: el host aplica un impulso pequeño al detectar solapamiento con `Area3D`.
- **Turbulencia:** el host emite el evento por RPC; cada cliente aplica el impulso a su propio personaje; el host aplica impulsos a los objetos.
- **Captura:** el host valida y envía RPC al dueño del capturado, que desactiva su input y sigue al aeromozo. Nunca se mueve un cuerpo ajeno directamente.
- **Tumbado/tropiezo:** estado falso (inclinar modelo + sin control unos segundos), sin ragdoll.
- Movimiento remoto: interpolación (lerp) hacia la última posición recibida.

## Desconexiones
- **Cliente:** el host suelta sus objetos (`Grabbable`, en su último estado replicado), libera su asiento y le quita el seguro de la puerta si lo puso (cada componente escucha `Network.player_left`), y elimina su personaje. La captura se libera cuando exista (Fase 7). Si tenía rol clave la partida termina en resultados ("abandono").
- **Host:** fin de partida para todos y vuelta al menú. Sin migración de host.

## Reinicio (revancha)
`Match` (host) pasa `LOBBY → FLIGHT → RESULTS → LOBBY`. Los sistemas son nodos hijos de `Match` (no autoloads) y exponen `reset()`; reiniciar es limpiar y volver a instanciar. Todo sistema nuevo nace sabiendo reiniciarse.

## Autoloads
Solo dos: `Network` (conexión, roster, señales de conexión/desconexión; **implementado**) y `DebugTools` (atajos F1–F8, solo en builds de debug; **aún no existe**).

## Estado de implementación
- **Hecho (Fase 2):** conexión Host/Join, roster, spawner de jugadores, personaje con autoridad del dueño + interpolación (lerp simple hacia la última posición), desconexión de cliente y de host.
- **Hecho (Fase 3):** objetos y estado discreto con el patrón petición → validación → broadcast (ver "Interacciones en red").
- **Sin verificar:** partida llena (5º jugador), jitter por Tailscale. Si la interpolación se nota a tirones en red real, pasar a un buffer con timestamp.

## Interacciones en red (Fase 3)
Los objetos de la escena (`Match/Level/...`) existen en todos los peers con la misma ruta: no hay spawner, solo `MultiplayerSynchronizer` con visibilidad pública. Cada uno lleva sus RPC en un nodo con el mismo path en todos los peers.

- **`Grabbable`** (`scripts/components/grabbable.gd`): el cliente llama `request_grab` (RPC `any_peer`, `call_local`, al host). El host valida remitente con personaje, distancia (`max_grab_distance`), objeto libre y que el remitente no sostenga ya otra cosa (el primero que llega gana), y fija `holder_id`. `holder_id` se replica con un synchronizer del host (`HolderSync`, ON_CHANGE); su setter, en todos los peers, aplica las excepciones de colisión con el portador y reasigna la autoridad del cuerpo (portador o host). Solo el portador simula el seguimiento hacia su mano. Soltar/lanzar: el portador aplica la velocidad localmente y envía `_request_release(velocity)`; el host valida que sea el portador, recorta a `max_throw_speed`, toma el último transform replicado y devuelve la autoridad al host.
- **`NetworkedBody`** (`scripts/components/networked_body.gd`): hijo de un `RigidBody3D` con un `TransformSync` (`sync_position`, `sync_rotation`, ALWAYS). La autoridad escribe y simula; el resto congela el cuerpo (kinematic) e interpola. Al cambiar de autoridad parte del último estado recibido (sin saltos).
- **`Interactable`** (`scripts/components/interactable.gd`): `interact()` → RPC al host; el host valida personaje y distancia (`max_interact_distance`) y emite `interacted(by)` **solo en el host**. El objeto cambia su estado ahí y lo replica con un synchronizer ON_CHANGE (`spawn = true`, así un jugador que llega tarde recibe el estado actual). Los clientes solo pintan.
- **Estado discreto:** `Door` (`is_open`, `locked_by`), `Seat` (`occupant_id`), `OverheadBin` (`is_open`). Los setters animan (con `HingeSwing`) o mueven al personaje propio en cada peer. Reglas en el host: seguro solo con la puerta cerrada y nadie abre con seguro puesto; un asiento ocupado rechaza y cada jugador ocupa un solo asiento.
- **Sentarse:** el host fija `occupant_id`; el setter de `Seat`, en el peer dueño, llama `Player.sit_down`/`stand_up`. El personaje sigue replicándose con su synchronizer normal; sentado no se mueve.
- **Línea de visión:** `Player` descarta objetivos tapados con un rayo contra la capa 1. Solo interfaz; el host no la valida.
- **Avisos benignos:** en cada traspaso de autoridad de un objeto aparecen 2–3 `Ignoring sync data from non-authority` (paquete del dueño anterior que llega antes que el cambio de `holder_id`). No afectan.

## Registro de jugadores (roster)
`Network.players` (`peer id → {name, slot}`) lo mantiene el host. Un cliente, al conectar, llama `_request_register.rpc_id(1, nombre)`; el host sanea el nombre, asigna el primer slot libre (0–3: color y punto de aparición) y replica el roster con `_sync_roster.rpc`. `Match` (solo en el host) spawnea/borra el `Player` de cada peer con un `MultiplayerSpawner` y `spawn_function`; el nodo se llama como el peer id y de ahí sale su autoridad.

## Argumentos de arranque
Tras `--` en la línea de comandos: `--host`, `--join=IP`, `--name=Nombre`. En *Customize Run Instances* sirven para saltarse el menú.

## Probar red
Debug → Customize Run Instances (2–4). Primera instancia: Host. Resto: Join `127.0.0.1`. Con Tailscale: IP `100.x.y.z` del host, puerto por defecto 7777.
