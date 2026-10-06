class_name PauseMenu
extends CanvasLayer
## Panel visible mientras el ratón está liberado (Esc): lista de jugadores, controles del host y salida al menú.
## No pausa el juego: es online y los demás siguen jugando.

var _match: Match = null

@onready var _players_label: Label = %PlayersLabel
@onready var _start_button: Button = %StartButton
@onready var _land_button: Button = %LandButton
@onready var _leave_button: Button = %LeaveButton


func _ready() -> void:
	_leave_button.pressed.connect(Network.quit_to_menu)
	_start_button.pressed.connect(_on_start_pressed)
	_land_button.pressed.connect(_on_land_pressed)
	Network.roster_changed.connect(_refresh_list)
	_refresh_list()


func _process(_delta: float) -> void:
	visible = Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
	if _match == null:
		return
	var is_host: bool = multiplayer.is_server()
	_start_button.visible = is_host and _match.state == Match.State.LOBBY
	_start_button.disabled = Network.players.size() < _match.balance.min_players_to_start
	# Atajo de depuración para no esperar el vuelo completo al probar.
	_land_button.visible = is_host and _match.state == Match.State.FLIGHT and OS.is_debug_build()


func setup(match_node: Match) -> void:
	_match = match_node


func _refresh_list() -> void:
	var lines: PackedStringArray = []
	for id: int in Network.players:
		var suffix: String = " (host)" if id == 1 else ""
		lines.append("%s%s" % [Network.get_player_name(id), suffix])
	_players_label.text = "\n".join(lines)


func _on_start_pressed() -> void:
	_match.start_flight()


func _on_land_pressed() -> void:
	_match.land_now()
