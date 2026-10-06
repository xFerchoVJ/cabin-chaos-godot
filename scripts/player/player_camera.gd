class_name PlayerCamera
extends Node3D
## Rig de cámara en 3ª persona. Jerarquía: este nodo (yaw) → Pitch → SpringArm3D → Camera3D.
## El SpringArm3D acerca la cámara cuando hay una pared detrás para que no la atraviese.
## Es `top_level` para seguir al jugador con suavizado en vez de heredar su transform al instante.

@export var mouse_sensitivity: float = 0.12 ## grados por píxel
@export var min_pitch: float = -70.0 ## grados (negativo = mirar hacia abajo)
@export var max_pitch: float = 50.0
@export var arm_length: float = 4.5
@export var height_offset: float = 1.3
@export var follow_speed: float = 14.0

var target: Node3D = null

@onready var _pitch: Node3D = %Pitch
@onready var _spring_arm: SpringArm3D = %SpringArm3D
@onready var _camera: Camera3D = %Camera3D


func _ready() -> void:
	top_level = true
	_spring_arm.spring_length = arm_length
	_pitch.rotation.x = deg_to_rad(-20.0)
	# El techo del avión choca con todo menos con la cámara: así no la acerca al personaje.
	for node: Node in get_tree().get_nodes_in_group("camera_transparent"):
		_spring_arm.add_excluded_object((node as CollisionObject3D).get_rid())
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	var click := event as InputEventMouseButton
	if motion != null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= deg_to_rad(motion.relative.x * mouse_sensitivity)
		_pitch.rotation.x = clampf(
			_pitch.rotation.x - deg_to_rad(motion.relative.y * mouse_sensitivity),
			deg_to_rad(min_pitch),
			deg_to_rad(max_pitch)
		)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif click != null and click.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		# El clic que recaptura el ratón no debe contar como "agarrar".
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if target == null:
		return
	var goal: Vector3 = target.global_position + Vector3.UP * height_offset
	global_position = global_position.lerp(goal, 1.0 - exp(-follow_speed * delta))


## Asigna el objetivo a seguir y coloca la cámara sobre él sin suavizado.
func setup(new_target: Node3D) -> void:
	target = new_target
	global_position = target.global_position + Vector3.UP * height_offset
	_camera.make_current()


## Ángulo horizontal (radianes) hacia donde mira la cámara.
func get_yaw() -> float:
	return rotation.y


## Dirección 3D hacia donde apunta la cámara.
func get_aim_direction() -> Vector3:
	return -_camera.global_basis.z
