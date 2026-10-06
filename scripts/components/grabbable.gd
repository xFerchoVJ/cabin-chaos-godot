class_name Grabbable
extends Node
## Componente: añadido como hijo de un RigidBody3D (capa 3 "grabbables"), permite agarrarlo y lanzarlo en red.
## Flujo: el cliente pide agarrar por RPC → el host valida y fija `holder_id` → `holder_id` se replica con un
## MultiplayerSynchronizer (HolderSync, autoridad del host) → en cada peer su setter reasigna la autoridad
## del cuerpo: mientras se sostiene la tiene el portador (se siente instantáneo); en reposo, el host.
## El cuerpo sigue siendo dinámico mientras se sostiene: se mueve por velocidad hacia el punto de agarre,
## así tiene inercia y choca con las paredes en vez de atravesarlas.
## Requiere un hermano NetworkedBody y un hijo MultiplayerSynchronizer `HolderSync` que replique `holder_id`.

## Se emite en todos los peers cuando cambia el portador (0 = nadie).
signal holder_changed(new_holder_id: int)

const HOST_ID: int = 1

@export var prompt_text: String = "Agarrar"
## Qué tan rápido corrige la distancia al punto de agarre (más alto = más pegado a la mano).
@export var follow_stiffness: float = 18.0
@export var max_follow_speed: float = 12.0
## Frenado de la rotación mientras se sostiene (evita que gire como loco).
@export var spin_damping: float = 8.0
## Si el objeto queda más lejos que esto del punto de agarre (atascado), se suelta solo.
@export var break_distance: float = 3.0
## Multiplicador de la velocidad del portador mientras lo lleva.
@export_range(0.1, 1.0) var carry_speed_multiplier: float = 0.8
## El host rechaza agarrar si el personaje está más lejos que esto del objeto.
@export var max_grab_distance: float = 3.0
## El host recorta la velocidad de lanzamiento a este máximo (m/s).
@export var max_throw_speed: float = 25.0
## Si es false, solo se puede soltar (el carrito no se lanza).
@export var throwable: bool = true
## Desplaza el punto de agarre respecto a la mano del personaje (en el espacio local de la mano).
@export var hold_offset: Vector3 = Vector3.ZERO
## Si es true, el objeto gira para mirar hacia donde mira el portador (el carrito sigue tu dirección).
@export var align_to_holder: bool = false
## Qué tan rápido corrige el giro cuando `align_to_holder` está activo.
@export var align_speed: float = 8.0

## Peer que lo sostiene (0 = libre). Lo fija el host; se replica a los demás.
var holder_id: int = 0:
	set = _set_holder_id

var _holder: Player = null
## El portador ya lo soltó localmente y espera a que el host lo confirme (no debe seguir tirando del objeto).
var _local_released: bool = false
var _networked: NetworkedBody = null
var _initial_transform: Transform3D = Transform3D.IDENTITY

@onready var _body: RigidBody3D = get_parent() as RigidBody3D


func _ready() -> void:
	add_to_group("grabbables")
	add_to_group("match_resettable")
	_initial_transform = _body.global_transform
	_networked = NetworkedBody.find_in(_body)
	if multiplayer.is_server():
		Network.player_left.connect(_on_player_left)


func _physics_process(delta: float) -> void:
	if not is_held_locally() or _holder == null:
		return
	var target: Vector3 = _holder.get_hold_point().to_global(hold_offset)
	var to_target: Vector3 = target - _body.global_position
	if to_target.length() > break_distance:
		release_local()
		return
	_body.linear_velocity = (to_target * follow_stiffness).limit_length(max_follow_speed)
	if align_to_holder:
		var yaw_error: float = wrapf(_holder.get_hold_point().global_rotation.y - _body.global_rotation.y, -PI, PI)
		_body.angular_velocity = Vector3(0.0, yaw_error * align_speed, 0.0)
	else:
		_body.angular_velocity *= clampf(1.0 - spin_damping * delta, 0.0, 1.0)


## Devuelve el componente Grabbable hijo de `body`, o null si no tiene.
static func find_in(body: Node) -> Grabbable:
	for child: Node in body.get_children():
		if child is Grabbable:
			return child as Grabbable
	return null


func is_held() -> bool:
	return holder_id != 0


## Este peer es el portador y aún no lo ha soltado.
func is_held_locally() -> bool:
	return holder_id == multiplayer.get_unique_id() and not _local_released


## Solo host (lo llama Match): lo suelta y lo devuelve quieto a su sitio inicial.
func reset() -> void:
	holder_id = 0
	_body.global_transform = _initial_transform
	_body.linear_velocity = Vector3.ZERO
	_body.angular_velocity = Vector3.ZERO


## Pide al host agarrar el objeto. El resultado llega por `holder_changed`.
func request_grab() -> void:
	_request_grab.rpc_id(HOST_ID)


## Suelta el objeto dándole `velocity` (m/s). Solo tiene efecto en el portador.
## El portador lo suelta de inmediato (feedback instantáneo) y el host lo confirma.
func release_local(velocity: Vector3 = Vector3.ZERO) -> void:
	if not is_held_locally():
		return
	_local_released = true
	_body.linear_velocity = velocity
	_request_release.rpc_id(HOST_ID, velocity)


func _set_holder_id(value: int) -> void:
	if value == holder_id:
		return
	holder_id = value
	_local_released = false
	if not is_node_ready():
		return
	_set_collision_exceptions(false)
	_holder = Player.find_by_peer(get_tree(), value) if value != 0 else null
	_set_collision_exceptions(true)
	_networked.set_body_authority(value if value != 0 else HOST_ID)
	holder_changed.emit(value)


func _set_collision_exceptions(active: bool) -> void:
	if not is_instance_valid(_holder):
		return
	if active:
		_body.add_collision_exception_with(_holder)
		_holder.add_collision_exception_with(_body)
	else:
		_body.remove_collision_exception_with(_holder)
		_holder.remove_collision_exception_with(_body)


## Solo host: libera el objeto en su último estado replicado y le da `velocity`.
func _release_as_host(velocity: Vector3) -> void:
	holder_id = 0
	_body.linear_velocity = velocity


func _on_player_left(id: int) -> void:
	if holder_id == id:
		_release_as_host(Vector3.ZERO)


@rpc("any_peer", "call_local", "reliable")
func _request_grab() -> void:
	if not multiplayer.is_server():
		return
	var sender: int = Network.get_sender_id()
	if holder_id != 0:
		return # El primero que llega al host gana.
	var player: Player = Player.find_by_peer(get_tree(), sender)
	if player == null or player.global_position.distance_to(_body.global_position) > max_grab_distance:
		return
	for node: Node in get_tree().get_nodes_in_group("grabbables"):
		if (node as Grabbable).holder_id == sender:
			return # Una cosa a la vez.
	holder_id = sender


@rpc("any_peer", "call_local", "reliable")
func _request_release(velocity: Vector3) -> void:
	if not multiplayer.is_server():
		return
	if Network.get_sender_id() != holder_id:
		return
	_release_as_host(velocity.limit_length(max_throw_speed))
