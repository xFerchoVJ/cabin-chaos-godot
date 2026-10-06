class_name Player
extends CharacterBody3D
## Personaje controlado por su dueño (autoridad multijugador). Movimiento relativo a la cámara,
## salto con coyote time y jump buffer, interacción con [E] y agarrar/soltar/lanzar con el ratón.

enum State { NORMAL, SEATED }

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

@export_group("Red")
## Qué tan rápido el personaje remoto alcanza la última posición recibida.
@export var interpolation_speed: float = 15.0
## Si el remoto está más lejos que esto de la posición recibida, se teletransporta.
@export var snap_distance: float = 3.0
## Materiales de color por slot de jugador (0–3).
@export var slot_materials: Array[Material] = []

## Replicados por el MultiplayerSynchronizer desde el dueño hacia los demás.
var sync_position: Vector3 = Vector3.ZERO
var sync_yaw: float = 0.0

var _state: State = State.NORMAL
var _seat: Seat = null
var _held: Grabbable = null
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _target_body: Node3D = null
var _target_grabbable: Grabbable = null
var _target_interactable: Interactable = null

@onready var _camera: PlayerCamera = %PlayerCamera
@onready var _collision: CollisionShape3D = %CollisionShape3D
@onready var _model: Node3D = %Model
@onready var _hold_point: Marker3D = %HoldPoint
@onready var _interaction_area: Area3D = %InteractionArea
@onready var _prompt: Label3D = %PromptLabel
@onready var _body_mesh: MeshInstance3D = %Body
@onready var _name_label: Label3D = %NameLabel


func _enter_tree() -> void:
	# El nombre del nodo es el peer id del dueño. Debe fijarse antes de _ready y del synchronizer.
	if name.is_valid_int():
		set_multiplayer_authority(name.to_int())


func _ready() -> void:
	add_to_group("players")
	sync_position = global_position
	sync_yaw = _model.rotation.y
	# El color y el nombre salen del roster, que en un cliente puede llegar después de nacer.
	Network.roster_changed.connect(_refresh_identity)
	_refresh_identity()
	if is_multiplayer_authority():
		_name_label.queue_free()
		_camera.setup(self)
	else:
		# Personaje de otro jugador: sin input ni cámara; la red lo mueve.
		_camera.queue_free()
		_prompt.queue_free()
		set_process(false)
		set_process_unhandled_input(false)


func _process(_delta: float) -> void:
	_refresh_held()
	_update_target()
	_update_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if _state == State.SEATED:
		if event.is_action_pressed("interact") or event.is_action_pressed("jump"):
			_seat.request_stand()
		return
	if event.is_action_pressed("grab"):
		if _held != null:
			_held.release_local()
			_held = null
		elif _target_grabbable != null:
			_grab(_target_grabbable)
	elif event.is_action_pressed("throw") and _held != null:
		_throw()
	elif event.is_action_pressed("interact") and _target_interactable != null:
		_target_interactable.interact()


func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		_physics_local(delta)
		sync_position = global_position
		sync_yaw = _model.rotation.y
	else:
		_physics_remote(delta)


## Devuelve el personaje cuyo dueño es `peer_id`, o null. El host lo usa para validar a quién le llega un RPC.
static func find_by_peer(tree: SceneTree, peer_id: int) -> Player:
	for node: Node in tree.get_nodes_in_group("players"):
		if node.get_multiplayer_authority() == peer_id:
			return node as Player
	return null


func get_hold_point() -> Marker3D:
	return _hold_point


## Lo llama `Seat` en el peer dueño cuando el host le asigna el asiento: se coloca en él y deja de moverse.
func sit_down(seat: Seat) -> void:
	_state = State.SEATED
	_seat = seat
	velocity = Vector3.ZERO
	_collision.set_deferred("disabled", true)
	global_position = seat.get_sit_point().global_position
	_model.rotation.y = seat.global_rotation.y


## Lo llama `Seat` en el peer dueño cuando el host libera el asiento: reaparece junto a él con control.
func stand_up(seat: Seat) -> void:
	_state = State.NORMAL
	_seat = null
	velocity = Vector3.ZERO
	_collision.set_deferred("disabled", false)
	global_position = seat.get_exit_position()


func _physics_remote(delta: float) -> void:
	if global_position.distance_to(sync_position) > snap_distance:
		global_position = sync_position
	else:
		global_position = global_position.lerp(sync_position, 1.0 - exp(-interpolation_speed * delta))
	_turn_model(sync_yaw, delta)


func _refresh_identity() -> void:
	var id: int = name.to_int()
	if is_instance_valid(_name_label) and not _name_label.is_queued_for_deletion():
		_name_label.text = Network.get_player_name(id)
	var slot: int = Network.get_slot(id)
	if slot < slot_materials.size():
		_body_mesh.material_override = slot_materials[slot]


func _physics_local(delta: float) -> void:
	_refresh_held()
	if _state == State.SEATED:
		return
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
	if _state == State.SEATED:
		return
	var forward: Vector3 = Basis(Vector3.UP, _camera.get_yaw()) * Vector3.FORWARD
	# Se elige por separado lo que se agarra (clic) y lo que se usa (E): si no, una tapa o puerta
	# más cercana le quitaría el objetivo a la maleta que está justo detrás.
	var best_grab: float = INF
	var best_use: float = INF
	var grab_body: Node3D = null
	var use_body: Node3D = null
	for body: Node3D in _interaction_area.get_overlapping_bodies():
		var grabbable: Grabbable = Grabbable.find_in(body) if _held == null else null
		if grabbable != null and grabbable.is_held():
			grabbable = null
		var interactable: Interactable = Interactable.find_in(body)
		if grabbable == null and interactable == null:
			continue
		var offset: Vector3 = body.global_position - global_position
		offset.y = 0.0
		var distance: float = offset.length()
		if distance > 0.01 and offset.normalized().dot(forward) < min_view_dot:
			continue
		var improves_grab: bool = grabbable != null and distance < best_grab
		var improves_use: bool = interactable != null and distance < best_use
		if not (improves_grab or improves_use) or not _has_line_of_sight(body):
			continue
		if improves_grab:
			best_grab = distance
			grab_body = body
			_target_grabbable = grabbable
		if improves_use:
			best_use = distance
			use_body = body
			_target_interactable = interactable
	_target_body = grab_body if grab_body != null else use_body


## Un rayo contra el mundo (capa 1) desde el pecho hasta el objetivo: si algo lo tapa (pared, puerta,
## tapa cerrada), no se puede usar ni agarrar. Se corta un poco antes para no chocar con la superficie
## en la que está montado el objetivo.
func _has_line_of_sight(body: Node3D) -> bool:
	var from: Vector3 = global_position + Vector3.UP * 0.5
	var to: Vector3 = body.global_position
	var length: float = from.distance_to(to)
	if length < 0.5:
		return true
	to = to.move_toward(from, 0.25)
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, [get_rid(), (body as CollisionObject3D).get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _update_prompt() -> void:
	if _state == State.SEATED:
		_prompt.text = "[E] Levantarse"
		_prompt.global_position = global_position + Vector3.UP * 1.5
		_prompt.visible = true
		return
	var lines: PackedStringArray = []
	if _held != null:
		lines.append("[Clic] Soltar   [Clic der.] Lanzar" if _held.throwable else "[Clic] Soltar")
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
	var callback: Callable = _on_holder_changed.bind(grabbable)
	if not grabbable.holder_changed.is_connected(callback):
		grabbable.holder_changed.connect(callback)
	grabbable.request_grab()


func _throw() -> void:
	if not _held.throwable:
		_held.release_local()
		_held = null
		return
	var direction: Vector3 = _camera.get_aim_direction()
	direction = (direction + Vector3.UP * tan(deg_to_rad(throw_up_angle))).normalized()
	var flat_velocity := Vector3(velocity.x, 0.0, velocity.z)
	_held.release_local(direction * throw_speed + flat_velocity * throw_inherit_velocity)
	_held = null


## El host confirmó (o cambió) el portador de un objeto que pedimos agarrar.
func _on_holder_changed(new_holder_id: int, grabbable: Grabbable) -> void:
	if new_holder_id == get_multiplayer_authority():
		_held = grabbable
		return
	if _held == grabbable:
		_held = null
	var callback: Callable = _on_holder_changed.bind(grabbable)
	if grabbable.holder_changed.is_connected(callback):
		grabbable.holder_changed.disconnect(callback)


## Olvida el objeto si ya no lo sostenemos (se soltó solo por atasco o el host lo liberó).
func _refresh_held() -> void:
	if _held != null and not _held.is_held_locally():
		_held = null
