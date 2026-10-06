class_name Grabbable
extends Node
## Componente: añadido como hijo de un RigidBody3D (capa 3 "grabbables"), permite agarrarlo y lanzarlo.
## El cuerpo sigue siendo dinámico mientras se sostiene: se mueve por velocidad hacia el punto de
## agarre, así tiene inercia y choca con las paredes en vez de atravesarlas.

signal grabbed(holder: PhysicsBody3D)
signal released

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

var _holder: PhysicsBody3D = null
var _hold_point: Node3D = null

@onready var _body: RigidBody3D = get_parent() as RigidBody3D


func _physics_process(delta: float) -> void:
	if _hold_point == null:
		return
	var to_target: Vector3 = _hold_point.global_position - _body.global_position
	if to_target.length() > break_distance:
		release()
		return
	_body.linear_velocity = (to_target * follow_stiffness).limit_length(max_follow_speed)
	_body.angular_velocity *= clampf(1.0 - spin_damping * delta, 0.0, 1.0)


## Devuelve el componente Grabbable hijo de `body`, o null si no tiene.
static func find_in(body: Node) -> Grabbable:
	for child: Node in body.get_children():
		if child is Grabbable:
			return child as Grabbable
	return null


func is_held() -> bool:
	return _holder != null


func grab(holder: PhysicsBody3D, hold_point: Node3D) -> void:
	if is_held():
		return
	_holder = holder
	_hold_point = hold_point
	_body.add_collision_exception_with(holder)
	holder.add_collision_exception_with(_body)
	grabbed.emit(holder)


func release() -> void:
	if not is_held():
		return
	_body.remove_collision_exception_with(_holder)
	_holder.remove_collision_exception_with(_body)
	_holder = null
	_hold_point = null
	released.emit()


## Suelta el objeto y le da `velocity` (m/s) en una sola acción.
func throw(velocity: Vector3) -> void:
	release()
	_body.linear_velocity = velocity
