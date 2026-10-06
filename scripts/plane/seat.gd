class_name Seat
extends StaticBody3D
## Asiento. El host asigna `occupant_id` (0 = libre) y se replica; en cada peer el setter hace sentarse o
## levantarse al personaje propio si le toca. Un jugador solo ocupa un asiento a la vez.

## Dónde aparece el personaje al levantarse, en el espacio local del asiento (por defecto, al pasillo).
@export var exit_offset: Vector3 = Vector3(1.0, 0.2, 0.0)

## Replicado por el MultiplayerSynchronizer desde el host.
var occupant_id: int = 0:
	set = _set_occupant_id

@onready var _interactable: Interactable = %Interactable
@onready var _sit_point: Marker3D = %SitPoint


func _ready() -> void:
	add_to_group("seats")
	_interactable.interacted.connect(_on_interacted)
	if multiplayer.is_server():
		Network.player_left.connect(_on_player_left)
	_refresh()


func get_sit_point() -> Marker3D:
	return _sit_point


func get_exit_position() -> Vector3:
	return to_global(exit_offset)


## Pide al host levantarse. Solo lo acepta si quien pregunta es el ocupante.
func request_stand() -> void:
	_request_stand.rpc_id(Interactable.HOST_ID)


func _set_occupant_id(value: int) -> void:
	if value == occupant_id:
		return
	var previous: int = occupant_id
	occupant_id = value
	if not is_node_ready():
		return
	_refresh()
	var me: int = multiplayer.get_unique_id()
	var player: Player = Player.find_by_peer(get_tree(), me)
	if player == null:
		return
	if value == me:
		player.sit_down(self)
	elif previous == me:
		player.stand_up(self)


func _refresh() -> void:
	_interactable.prompt_text = "Ocupado" if occupant_id != 0 else "Sentarse"


func _on_interacted(by: Node3D) -> void:
	if occupant_id != 0:
		return
	var id: int = by.get_multiplayer_authority()
	for node: Node in get_tree().get_nodes_in_group("seats"):
		if (node as Seat).occupant_id == id:
			return # Ya está sentado en otro asiento.
	occupant_id = id


func _on_player_left(id: int) -> void:
	if occupant_id == id:
		occupant_id = 0


@rpc("any_peer", "call_local", "reliable")
func _request_stand() -> void:
	if not multiplayer.is_server():
		return
	if Network.get_sender_id() == occupant_id:
		occupant_id = 0
