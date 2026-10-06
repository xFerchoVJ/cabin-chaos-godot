class_name NetworkedBody
extends Node
## Componente: hijo de un RigidBody3D. Replica su posición y rotación desde su autoridad hacia los demás.
## La autoridad simula la física (cuerpo dinámico); el resto lo congela (freeze kinematic) y lo interpola
## hacia el último estado recibido. La autoridad la cambia `Grabbable` (host en reposo, portador al agarrar).
## Requiere un hijo MultiplayerSynchronizer llamado `TransformSync` que replique sync_position y sync_rotation.

## Qué tan rápido el cuerpo remoto alcanza el último estado recibido.
@export var interpolation_speed: float = 15.0
## Si el cuerpo remoto está más lejos que esto del estado recibido, se teletransporta.
@export var snap_distance: float = 3.0

## Replicados por el MultiplayerSynchronizer desde la autoridad hacia los demás.
var sync_position: Vector3 = Vector3.ZERO
var sync_rotation: Quaternion = Quaternion.IDENTITY

@onready var _body: RigidBody3D = get_parent() as RigidBody3D
@onready var _sync: MultiplayerSynchronizer = %TransformSync


func _ready() -> void:
	_body.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	_capture()
	_body.freeze = not _sync.is_multiplayer_authority()


func _physics_process(delta: float) -> void:
	if _sync.is_multiplayer_authority():
		_capture()
	else:
		_follow(delta)


## Devuelve el componente NetworkedBody hijo de `body`, o null si no tiene.
static func find_in(body: Node) -> NetworkedBody:
	for child: Node in body.get_children():
		if child is NetworkedBody:
			return child as NetworkedBody
	return null


## Cambia quién simula el cuerpo. Quien lo recibe parte del último estado replicado (sin saltos);
## quien lo cede lo congela y pasa a interpolar.
func set_body_authority(peer_id: int) -> void:
	if _sync.get_multiplayer_authority() == peer_id:
		return
	_sync.set_multiplayer_authority(peer_id)
	if _sync.is_multiplayer_authority():
		_body.global_position = sync_position
		_body.global_basis = Basis(sync_rotation)
		_body.freeze = false
		_body.linear_velocity = Vector3.ZERO
		_body.angular_velocity = Vector3.ZERO
	else:
		_body.freeze = true


func _capture() -> void:
	sync_position = _body.global_position
	sync_rotation = _body.global_basis.get_rotation_quaternion()


func _follow(delta: float) -> void:
	if _body.global_position.distance_to(sync_position) > snap_distance:
		_body.global_position = sync_position
		_body.global_basis = Basis(sync_rotation)
		return
	var weight: float = 1.0 - exp(-interpolation_speed * delta)
	_body.global_position = _body.global_position.lerp(sync_position, weight)
	var current: Quaternion = _body.global_basis.get_rotation_quaternion()
	_body.global_basis = Basis(current.slerp(sync_rotation, weight))
