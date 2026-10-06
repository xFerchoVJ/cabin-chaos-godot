extends Node
## Autoload: conexión ENet, lista de jugadores (roster) y señales de red.
## El host es peer 1 y la fuente de verdad del roster; los clientes piden registrarse por RPC.

signal connected
signal disconnected(reason: String)
signal player_registered(id: int)
signal player_left(id: int)
signal roster_changed

const DEFAULT_PORT: int = 7777
const MAX_PLAYERS: int = 4
const MAX_NAME_LENGTH: int = 16

## peer id → { "name": String, "slot": int }. Slot 0–3 define color y punto de aparición.
var players: Dictionary = {}

var _local_name: String = ""


func _ready() -> void:
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func host(player_name: String, port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var error: Error = peer.create_server(port, MAX_PLAYERS - 1)
	if error != OK:
		return error
	multiplayer.multiplayer_peer = peer
	_local_name = player_name
	_register(1, player_name)
	connected.emit()
	return OK


func join(ip: String, player_name: String, port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var error: Error = peer.create_client(ip, port)
	if error != OK:
		return error
	multiplayer.multiplayer_peer = peer
	_local_name = player_name
	return OK


## Cierra la conexión y limpia el roster. No emite `disconnected` (lo decide quien llama).
func leave() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	players.clear()


## Salida voluntaria: cierra la conexión y avisa a Main para volver al menú (sin mensaje).
func quit_to_menu() -> void:
	leave()
	disconnected.emit("")


func get_player_name(id: int) -> String:
	var info: Dictionary = players.get(id, {})
	return info.get("name", "")


func get_slot(id: int) -> int:
	var info: Dictionary = players.get(id, {})
	return info.get("slot", 0)


func _register(id: int, requested_name: String) -> void:
	var slot: int = _free_slot()
	var clean: String = requested_name.strip_edges().left(MAX_NAME_LENGTH)
	if clean.is_empty():
		clean = "Jugador %d" % (slot + 1)
	players[id] = {"name": clean, "slot": slot}
	_sync_roster.rpc(players)
	roster_changed.emit()
	player_registered.emit(id)


func _free_slot() -> int:
	var used: Array[int] = []
	for info: Dictionary in players.values():
		used.append(info["slot"])
	for slot: int in MAX_PLAYERS:
		if not used.has(slot):
			return slot
	return 0


@rpc("any_peer", "call_remote", "reliable")
func _request_register(requested_name: String) -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if players.has(sender) or players.size() >= MAX_PLAYERS:
		return
	_register(sender, requested_name)


@rpc("authority", "call_remote", "reliable")
func _sync_roster(new_roster: Dictionary) -> void:
	players = new_roster
	roster_changed.emit()


func _on_connected_to_server() -> void:
	_request_register.rpc_id(1, _local_name)
	connected.emit()


func _on_connection_failed() -> void:
	leave()
	disconnected.emit("No se pudo conectar (¿IP incorrecta o partida llena?)")


func _on_server_disconnected() -> void:
	leave()
	disconnected.emit("El host cerró la partida")


func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server():
		return
	players.erase(id)
	_sync_roster.rpc(players)
	roster_changed.emit()
	player_left.emit(id)
