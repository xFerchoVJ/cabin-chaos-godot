extends CharacterBody3D
## Personaje controlado por su dueño (autoridad multijugador). Movimiento relativo a la cámara,
## salto con coyote time y jump buffer, interacción con [E] y agarrar/soltar/lanzar con el ratón.

@export_group("Movimiento")
@export var max_speed: float = 6.0
@export var acceleration: float = 35.0
@export var deceleration: float = 28.0
## Fracción de aceleración/frenada disponible en el aire.
@export_range(0.0, 1.0) var air_control: float = 0.4
## Qué tan rápido gira el modelo hacia donde se mueve.
@export var turn_speed: float = 14.0

@export_group("Salto")
@export var jump_velocity: float = 8.5
@export var gravity: float = 24.0
@export var fall_gravity_multiplier: float = 1.5
## Al soltar el botón en la subida, la velocidad vertical se multiplica por esto (salto corto).
@export_range(0.0, 1.0) var jump_cut_multiplier: float = 0.5
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.12

@export_group("Agarrar y lanzar")
@export var throw_speed: float = 12.0
## Grados extra hacia arriba sobre la dirección de la cámara (da arco al lanzamiento).
@export var throw_up_angle: float = 12.0
@export_range(0.0, 1.0) var throw_inherit_velocity: float = 0.5
## Mínimo producto punto entre la dirección de la cámara y el objeto para poder seleccionarlo.
@export_range(-1.0, 1.0) var min_view_dot: float = 0.2

var _held: Grabbable = null
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _target_body: Node3D = null
var _target_grabbable: Grabbable = null
var _target_interactable: Interactable = null

@onready var _camera: PlayerCamera = %PlayerCamera
@onready var _model: Node3D = %Model
@onready var _hold_point: Marker3D = %HoldPoint
@onready var _interaction_area: Area3D = %InteractionArea
@onready var _prompt: Label3D = %PromptLabel


func _ready() -> void:
	if not is_multiplayer_authority():
		# Personaje de otro jugador: sin input ni cámara; la red lo mueve.
		_camera.queue_free()
		_prompt.queue_free()
		set_physics_process(false)
		set_process(false)
		set_process_unhandled_input(false)
		return
	_camera.setup(self)


func _process(_delta: float) -> void:
	_update_target()
	_update_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event.is_action_pressed("grab"):
		if _held != null:
			_held.release()
		elif _target_grabbable != null:
			_grab(_target_grabbable)
	elif event.is_action_pressed("throw") and _held != null:
		_throw()
	elif event.is_action_pressed("interact") and _target_interactable != null:
		_target_interactable.interact(self)


func _physics_process(delta: float) -> void:
	var yaw: float = _camera.get_yaw()
	var input: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction: Vector3 = Basis(Vector3.UP, yaw) * Vector3(input.x, 0.0, input.y)
	var moving: bool = direction.length_squared() > 0.0001

	var speed: float = max_speed * (_held.carry_speed_multiplier if _held != null else 1.0)
	var rate: float = acceleration if moving else deceleration
	if not is_on_floor():
		rate *= air_control
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(direction * speed, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	_apply_vertical(delta)
	move_and_slide()

	# Con un objeto en la mano el modelo mira hacia donde apunta la cámara (lanzas hacia donde miras).
	if _held != null:
		_turn_model(yaw, delta)
	elif moving:
		_turn_model(atan2(-direction.x, -direction.z), delta)


func _apply_vertical(delta: float) -> void:
	if is_on_floor():
		_coyote_timer = coyote_time
	else:
		_coyote_timer -= delta
		var factor: float = fall_gravity_multiplier if velocity.y < 0.0 else 1.0
		velocity.y -= gravity * factor * delta

	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer -= delta

	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		velocity.y = jump_velocity
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
	elif Input.is_action_just_released("jump") and velocity.y > 0.0:
		velocity.y *= jump_cut_multiplier


func _turn_model(target_yaw: float, delta: float) -> void:
	_model.rotation.y = lerp_angle(_model.rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))


func _update_target() -> void:
	_target_body = null
	_target_grabbable = null
	_target_interactable = null
	var forward: Vector3 = Basis(Vector3.UP, _camera.get_yaw()) * Vector3.FORWARD
	var best_distance: float = INF
	for body: Node3D in _interaction_area.get_overlapping_bodies():
		var grabbable: Grabbable = Grabbable.find_in(body) if _held == null else null
		var interactable: Interactable = Interactable.find_in(body)
		if grabbable == null and interactable == null:
			continue
		if grabbable != null and grabbable.is_held():
			continue
		var offset: Vector3 = body.global_position - global_position
		offset.y = 0.0
		var distance: float = offset.length()
		if distance > 0.01 and offset.normalized().dot(forward) < min_view_dot:
			continue
		if distance < best_distance:
			best_distance = distance
			_target_body = body
			_target_grabbable = grabbable
			_target_interactable = interactable


func _update_prompt() -> void:
	var lines: PackedStringArray = []
	if _held != null:
		lines.append("[Clic] Soltar   [Clic der.] Lanzar")
	elif _target_grabbable != null:
		lines.append("[Clic] " + _target_grabbable.prompt_text)
	if _target_interactable != null:
		lines.append("[E] " + _target_interactable.prompt_text)
	_prompt.visible = not lines.is_empty()
	if lines.is_empty():
		return
	_prompt.text = "\n".join(lines)
	if _held != null or _target_body == null:
		_prompt.global_position = global_position + Vector3.UP * 1.5
	else:
		_prompt.global_position = _target_body.global_position + Vector3.UP * 1.0


func _grab(grabbable: Grabbable) -> void:
	_held = grabbable
	_held.released.connect(_on_held_released, CONNECT_ONE_SHOT)
	_held.grab(self, _hold_point)


func _throw() -> void:
	var direction: Vector3 = _camera.get_aim_direction()
	direction = (direction + Vector3.UP * tan(deg_to_rad(throw_up_angle))).normalized()
	var flat_velocity := Vector3(velocity.x, 0.0, velocity.z)
	_held.throw(direction * throw_speed + flat_velocity * throw_inherit_velocity)


func _on_held_released() -> void:
	_held = null
