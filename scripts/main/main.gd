extends Node
## Orquestador: alterna entre el menú de conexión y la partida. No contiene lógica de juego.
## Argumentos de línea de comandos (tras `--`): `--host`, `--join=IP`, `--name=X`.

const MATCH_SCENE: PackedScene = preload("res://scenes/match/match.tscn")

var _match: Node = null

@onready var _menu: Control = %ConnectMenu


func _ready() -> void:
	_menu.host_requested.connect(_on_host_requested)
	_menu.join_requested.connect(_on_join_requested)
	Network.connected.connect(_on_connected)
	Network.disconnected.connect(_on_disconnected)
	_apply_cmdline_args()


func _apply_cmdline_args() -> void:
	var player_name: String = ""
	var join_ip: String = ""
	var should_host: bool = false
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--host":
			should_host = true
		elif arg.begins_with("--join="):
			join_ip = arg.trim_prefix("--join=")
		elif arg.begins_with("--name="):
			player_name = arg.trim_prefix("--name=")
	if should_host:
		_on_host_requested(player_name)
	elif not join_ip.is_empty():
		_on_join_requested(join_ip, player_name)


func _on_host_requested(player_name: String) -> void:
	var error: Error = Network.host(player_name)
	if error != OK:
		_menu.set_status("No se pudo crear la partida (¿puerto %d en uso?)" % Network.DEFAULT_PORT)


func _on_join_requested(ip: String, player_name: String) -> void:
	var error: Error = Network.join(ip, player_name)
	if error != OK:
		_menu.set_status("IP no válida")
		return
	_menu.set_status("Conectando…", true)


func _on_connected() -> void:
	if _match != null:
		return
	_menu.visible = false
	_match = MATCH_SCENE.instantiate()
	_match.name = "Match" # Mismo nombre en todos los peers: lo exige el MultiplayerSpawner.
	add_child(_match)


func _on_disconnected(reason: String) -> void:
	if _match != null:
		# Deja de procesar ya: en este mismo frame la conexión está cerrada y los nodos de Match la consultan.
		_match.process_mode = Node.PROCESS_MODE_DISABLED
		_match.queue_free()
		_match = null
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_menu.visible = true
	_menu.set_status(reason)
