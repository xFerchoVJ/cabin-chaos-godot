extends Node3D
## Partida. En esta fase solo gestiona la aparición y desaparición de jugadores.
## Solo el host decide quién existe; el MultiplayerSpawner replica la creación/borrado a los clientes.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")

@onready var _players: Node3D = %Players
@onready var _spawner: MultiplayerSpawner = %PlayerSpawner
@onready var _spawn_points: Node3D = %SpawnPoints


func _ready() -> void:
	# Debe configurarse en TODOS los peers: es la función que construye el jugador al replicarse.
	_spawner.spawn_function = _create_player
	if not multiplayer.is_server():
		return
	Network.player_registered.connect(_spawn_player)
	Network.player_left.connect(_despawn_player)
	for id: int in Network.players:
		_spawn_player(id)


func _spawn_player(id: int) -> void:
	var slot: int = Network.get_slot(id)
	var point: Node3D = _spawn_points.get_child(slot % _spawn_points.get_child_count())
	_spawner.spawn({"id": id, "position": point.global_position})


func _despawn_player(id: int) -> void:
	var player: Node = _players.get_node_or_null(str(id))
	if player != null:
		player.queue_free()


func _create_player(data: Dictionary) -> Node:
	var player: Node3D = PLAYER_SCENE.instantiate()
	player.name = str(data["id"])
	player.position = data["position"]
	return player
