extends StaticBody3D
## Interruptor de prueba para validar el flujo [E] → Interactable → señal. Solo vive en el sandbox.

@export var material_off: Material
@export var material_on: Material

var _is_on: bool = false

@onready var _mesh: MeshInstance3D = %Mesh
@onready var _interactable: Interactable = %Interactable


func _ready() -> void:
	_interactable.interacted.connect(_on_interacted)
	_apply_state()


func _on_interacted(_by: Node3D) -> void:
	_is_on = not _is_on
	_apply_state()


func _apply_state() -> void:
	_mesh.material_override = material_on if _is_on else material_off
	_interactable.prompt_text = "Apagar" if _is_on else "Encender"
