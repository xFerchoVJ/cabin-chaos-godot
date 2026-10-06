class_name Match
extends Node3D
## Partida. El host decide quién existe (MultiplayerSpawner), el flujo LOBBY → FLIGHT → RESULTS → LOBBY y los roles.
## `state`, `roles` y `result_text` se replican desde el host (StateSync, ON_CHANGE) y `time_left` (TimerSync) cada
## 0.25 s; entre paquetes cada peer lo descuenta localmente. Los sistemas futuros serán nodos hijos con `reset()`.
## Reinicio: no se re-instancia el avión; el host llama `reset()` a todo nodo del grupo `match_resettable`.

signal state_changed
signal roles_changed

enum State { LOBBY, FLIGHT, RESULTS }
enum Role { NONE, PILOT, STEWARD, PASSENGER }

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
## Rol que recibe cada jugador, en orden de reparto; el índice coincide con el hijo de `RoleSpawns`.
## Con 2 jugadores ya hay tripulación contra pasajero; con 3 aparece el piloto.
const ROLE_ORDER: Array[Role] = [Role.STEWARD, Role.PASSENGER, Role.PILOT, Role.PASSENGER]
const ROLE_NAMES: Dictionary = {
	Role.NONE: "Sin rol",
	Role.PILOT: "Piloto",
	Role.STEWARD: "Aeromozo",
	Role.PASSENGER: "Pasajero",
}

@export var balance: GameBalance

## Replicados por los MultiplayerSynchronizer desde el host.
var state: State = State.LOBBY:
	set = _set_state
## peer id → Role. Se reasigna siempre completo (así el synchronizer detecta el cambio).
var roles: Dictionary = {}:
	set = _set_roles
var result_text: String = ""
var time_left: float = 0.0

@onready var _players: Node3D = %Players
@onready var _spawner: MultiplayerSpawner = %PlayerSpawner
@onready var _lobby_spawns: Node3D = %LobbySpawns
@onready var _role_spawns: Node3D = %RoleSpawns
@onready var _hud: MatchHud = %Hud
@onready var _results: MatchResults = %Results
@onready var _pause_menu: PauseMenu = %PauseMenu


func _ready() -> void:
	# Debe configurarse en TODOS los peers: es la función que construye el jugador al replicarse.
	_spawner.spawn_function = _create_player
	_hud.setup(self)
	_results.setup(self)
	_pause_menu.setup(self)
	if not multiplayer.is_server():
		return
	Network.player_registered.connect(_spawn_player)
	Network.player_left.connect(_on_player_left)
	for id: int in Network.players:
		_spawn_player(id)


func _process(delta: float) -> void:
	if state != State.FLIGHT:
		return
	time_left = maxf(time_left - delta, 0.0)
	if multiplayer.is_server() and time_left <= 0.0:
		_end_flight("Gana la tripulación")


static func role_name(role: Role) -> String:
	return ROLE_NAMES.get(role, "")


func get_role(id: int) -> Role:
	return roles.get(id, Role.NONE)


## Solo host. Reparte roles, coloca a cada jugador en su puesto y empieza el vuelo.
func start_flight() -> void:
	if not multiplayer.is_server() or state != State.LOBBY:
		return
	if Network.players.size() < balance.min_players_to_start:
		return
	_reset_level()
	var ids: Array = Network.players.keys()
	ids.shuffle()
	var new_roles: Dictionary = {}
	for i: int in ids.size():
		var id: int = ids[i]
		new_roles[id] = ROLE_ORDER[i % ROLE_ORDER.size()]
		_teleport_player(id, _role_spawns.get_child(i % _role_spawns.get_child_count()))
	roles = new_roles
	result_text = ""
	time_left = balance.flight_duration
	state = State.FLIGHT


## Solo host. Termina el vuelo ya (atajo de depuración para no esperar los 5 minutos).
func land_now() -> void:
	if multiplayer.is_server() and state == State.FLIGHT:
		time_left = 0.0


## Solo host. Deja avión y jugadores como al empezar y vuelve al lobby.
func rematch() -> void:
	if not multiplayer.is_server() or state != State.RESULTS:
		return
	_reset_level()
	for id: int in Network.players:
		_teleport_player(id, _lobby_spawn_for(id))
	roles = {}
	result_text = ""
	time_left = 0.0
	state = State.LOBBY


func _set_state(value: State) -> void:
	if value == state:
		return
	state = value
	if multiplayer.is_server():
		# Solo se puede entrar a la partida desde el lobby.
		Network.accepting_players = state == State.LOBBY
	if is_node_ready():
		state_changed.emit()


func _set_roles(value: Dictionary) -> void:
	roles = value
	if is_node_ready():
		roles_changed.emit()


func _end_flight(text: String) -> void:
	if state != State.FLIGHT:
		return
	result_text = text
	state = State.RESULTS


func _reset_level() -> void:
	get_tree().call_group("match_resettable", "reset")


func _lobby_spawn_for(id: int) -> Node3D:
	return _lobby_spawns.get_child(Network.get_slot(id) % _lobby_spawns.get_child_count())


func _teleport_player(id: int, point: Node3D) -> void:
	var player: Player = Player.find_by_peer(get_tree(), id)
	if player != null:
		player.request_teleport(point.global_position)


func _spawn_player(id: int) -> void:
	_spawner.spawn({"id": id, "position": _lobby_spawn_for(id).global_position})


func _on_player_left(id: int) -> void:
	var player: Node = _players.get_node_or_null(str(id))
	if player != null:
		player.queue_free()
	var role: Role = get_role(id)
	if not roles.has(id):
		return
	var remaining: Dictionary = roles.duplicate()
	remaining.erase(id)
	roles = remaining
	if state == State.FLIGHT and (role == Role.PILOT or role == Role.STEWARD):
		_end_flight("Partida terminada: se desconectó el %s" % role_name(role).to_lower())


func _create_player(data: Dictionary) -> Node:
	var player: Node3D = PLAYER_SCENE.instantiate()
	player.name = str(data["id"])
	player.position = data["position"]
	return player
