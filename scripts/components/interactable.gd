class_name Interactable
extends Node
## Componente: añadido como hijo de un cuerpo (capa 4 "interactables"), lo marca como usable con [E].
## No decide qué pasa al usarlo: emite `interacted` y el dueño del objeto reacciona.

signal interacted(by: Node3D)

@export var prompt_text: String = "Usar"


## Devuelve el componente Interactable hijo de `body`, o null si no tiene.
static func find_in(body: Node) -> Interactable:
	for child: Node in body.get_children():
		if child is Interactable:
			return child as Interactable
	return null


func interact(by: Node3D) -> void:
	interacted.emit(by)
