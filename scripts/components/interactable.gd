class_name Interactable
extends Node
## Componente: añadido como hijo de un cuerpo (capa 4 "interactables"), lo marca como usable con [E].
## En red: el cliente pide usarlo por RPC, el host valida remitente y distancia y emite `interacted`
## solo en el host. El objeto dueño decide qué cambia y replica ese estado; los clientes solo lo pintan.

## Se emite únicamente en el host, con el personaje que lo usó.
signal interacted(by: Node3D)

const HOST_ID: int = 1

@export var prompt_text: String = "Usar"
## El host rechaza el uso si el personaje está más lejos que esto del objeto.
@export var max_interact_distance: float = 3.0


## Devuelve el componente Interactable hijo de `body`, o null si no tiene.
static func find_in(body: Node) -> Interactable:
	for child: Node in body.get_children():
		if child is Interactable:
			return child as Interactable
	return null


## Pide al host usar el objeto.
func interact() -> void:
	_request_interact.rpc_id(HOST_ID)


@rpc("any_peer", "call_local", "reliable")
func _request_interact() -> void:
	if not multiplayer.is_server():
		return
	var player: Player = Player.find_by_peer(get_tree(), Network.get_sender_id())
	var target: Node3D = get_parent() as Node3D
	if player == null or target == null:
		return
	if player.global_position.distance_to(target.global_position) > max_interact_distance:
		return
	interacted.emit(player)
