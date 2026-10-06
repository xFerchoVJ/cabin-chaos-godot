extends Node3D
## Puerta con bisagra y, opcionalmente, seguro interior (el del baño). El host decide; `is_open` y
## `locked_by` (peer que puso el seguro, 0 = sin seguro) se replican con un MultiplayerSynchronizer
## y cada peer anima la hoja por su cuenta. Con seguro puesto nadie puede abrirla.
## Reglas: el seguro solo se pone con la puerta cerrada; cualquiera que alcance el botón lo quita
## (está en la cara interior, tapado por la pared desde fuera). Si quien lo puso se desconecta, se quita.

@export var has_lock: bool = false
@export var material_locked: Material
@export var material_unlocked: Material

## Replicados por el MultiplayerSynchronizer desde el host.
var is_open: bool = false:
	set = _set_is_open
var locked_by: int = 0:
	set = _set_locked_by

@onready var _hinge: HingeSwing = %HingeSwing
@onready var _indicator: MeshInstance3D = %Indicator
@onready var _door_interactable: Interactable = %DoorInteractable
@onready var _lock_button: StaticBody3D = %LockButton
@onready var _lock_mesh: MeshInstance3D = %LockMesh
@onready var _lock_interactable: Interactable = %LockInteractable


func _ready() -> void:
	add_to_group("match_resettable")
	_door_interactable.interacted.connect(_on_door_interacted)
	if has_lock:
		_lock_interactable.interacted.connect(_on_lock_interacted)
	else:
		_lock_button.queue_free()
		_indicator.queue_free()
	if multiplayer.is_server():
		Network.player_left.connect(_on_player_left)
	_hinge.set_open(is_open, false)
	_refresh()


## Solo host (lo llama Match): cerrada y sin seguro.
func reset() -> void:
	locked_by = 0
	is_open = false


func _set_is_open(value: bool) -> void:
	if value == is_open:
		return
	is_open = value
	if is_node_ready():
		_hinge.set_open(is_open)
		_refresh()


func _set_locked_by(value: int) -> void:
	if value == locked_by:
		return
	locked_by = value
	if is_node_ready():
		_refresh()


## Texto de los avisos y color del seguro según el estado actual (en todos los peers).
func _refresh() -> void:
	if locked_by != 0:
		_door_interactable.prompt_text = "Puerta con seguro"
	else:
		_door_interactable.prompt_text = "Cerrar puerta" if is_open else "Abrir puerta"
	if not has_lock:
		return
	var material: Material = material_locked if locked_by != 0 else material_unlocked
	_lock_mesh.material_override = material
	_indicator.material_override = material
	if locked_by != 0:
		_lock_interactable.prompt_text = "Quitar seguro"
	else:
		_lock_interactable.prompt_text = "Cierra la puerta para poner seguro" if is_open else "Poner seguro"


func _on_door_interacted(_by: Node3D) -> void:
	if locked_by == 0:
		is_open = not is_open


func _on_lock_interacted(by: Node3D) -> void:
	if locked_by != 0:
		locked_by = 0
	elif not is_open:
		locked_by = by.get_multiplayer_authority()


func _on_player_left(id: int) -> void:
	if locked_by == id:
		locked_by = 0
