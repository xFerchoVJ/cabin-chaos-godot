extends Node3D
## Compartimento superior con tapa abatible. El host alterna `is_open` al usarlo y se replica; cada peer
## anima la tapa. Cerrada, la tapa tapa la vista y no se puede agarrar lo que hay dentro.

## Replicado por el MultiplayerSynchronizer desde el host.
var is_open: bool = false:
	set = _set_is_open

@onready var _hinge: HingeSwing = %HingeSwing
@onready var _interactable: Interactable = %LidInteractable


func _ready() -> void:
	_interactable.interacted.connect(_on_interacted)
	_hinge.set_open(is_open, false)
	_refresh()


func _set_is_open(value: bool) -> void:
	if value == is_open:
		return
	is_open = value
	if is_node_ready():
		_hinge.set_open(is_open)
		_refresh()


func _refresh() -> void:
	_interactable.prompt_text = "Cerrar compartimento" if is_open else "Abrir compartimento"


func _on_interacted(_by: Node3D) -> void:
	is_open = not is_open
