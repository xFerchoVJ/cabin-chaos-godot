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
| Objetos físicos (vasos, maletas, objetos del carrito) | Host | Synchronizer del host; `freeze` en clientes |
| Carrito | Host | Sigue al portador; colisiona solo en el host |
| Puertas, seguro, compartimentos, asientos | Host | Cliente pide por RPC, host decide y replica |
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
- **El carrito no se empuja por colisión:** se agarra (interacción explícita) y el host lo hace seguir al portador. Motivo: en el host, un jugador remoto es una "marioneta" que se teletransporta según la red y no empuja `RigidBody3D` de forma estable.
- Roces casuales jugador→objeto: el host aplica un impulso pequeño al detectar solapamiento con `Area3D`.
- **Turbulencia:** el host emite el evento por RPC; cada cliente aplica el impulso a su propio personaje; el host aplica impulsos a los objetos.
- **Captura:** el host valida y envía RPC al dueño del capturado, que desactiva su input y sigue al aeromozo. Nunca se mueve un cuerpo ajeno directamente.
- **Tumbado/tropiezo:** estado falso (inclinar modelo + sin control unos segundos), sin ragdoll.
- Movimiento remoto: interpolación (lerp) hacia la última posición recibida.

## Desconexiones
- **Cliente:** el host suelta sus objetos, libera su asiento/captura, elimina su personaje. Si tenía rol clave la partida termina en resultados ("abandono").
- **Host:** fin de partida para todos y vuelta al menú. Sin migración de host.

## Reinicio (revancha)
`Match` (host) pasa `LOBBY → FLIGHT → RESULTS → LOBBY`. Los sistemas son nodos hijos de `Match` (no autoloads) y exponen `reset()`; reiniciar es limpiar y volver a instanciar. Todo sistema nuevo nace sabiendo reiniciarse.

## Autoloads
Solo dos: `Network` (conexión, roster, señales de conexión/desconexión; **implementado**) y `DebugTools` (atajos F1–F8, solo en builds de debug; **aún no existe**).

## Estado de implementación
- **Hecho (Fase 2):** conexión Host/Join, roster, spawner de jugadores, personaje con autoridad del dueño + interpolación (lerp simple hacia la última posición), desconexión de cliente y de host.
- **Pendiente (Fase 3):** todo lo de la tabla de autoridad sobre objetos. `Grabbable` e `Interactable` hoy funcionan solo en local (sin RPC ni sincronización); se rehacen con el patrón petición → validación → broadcast.
- **Sin verificar:** partida llena (5º jugador), jitter por Tailscale. Si la interpolación se nota a tirones en red real, pasar a un buffer con timestamp.

## Registro de jugadores (roster)
`Network.players` (`peer id → {name, slot}`) lo mantiene el host. Un cliente, al conectar, llama `_request_register.rpc_id(1, nombre)`; el host sanea el nombre, asigna el primer slot libre (0–3: color y punto de aparición) y replica el roster con `_sync_roster.rpc`. `Match` (solo en el host) spawnea/borra el `Player` de cada peer con un `MultiplayerSpawner` y `spawn_function`; el nodo se llama como el peer id y de ahí sale su autoridad.

## Argumentos de arranque
Tras `--` en la línea de comandos: `--host`, `--join=IP`, `--name=Nombre`. En *Customize Run Instances* sirven para saltarse el menú.

## Probar red
Debug → Customize Run Instances (2–4). Primera instancia: Host. Resto: Join `127.0.0.1`. Con Tailscale: IP `100.x.y.z` del host, puerto por defecto 7777.
