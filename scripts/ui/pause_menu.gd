extends CanvasLayer
## Panel visible mientras el ratón está liberado (Esc): lista de jugadores y salida al menú.
## No pausa el juego: es online y los demás siguen jugando.

@onready var _players_label: Label = %PlayersLabel
@onready var _leave_button: Button = %LeaveButton


func _ready() -> void:
	_leave_button.pressed.connect(Network.quit_to_menu)
	Network.roster_changed.connect(_refresh_list)
	_refresh_list()


func _process(_delta: float) -> void:
	visible = Input.mouse_mode != Input.MOUSE_MODE_CAPTURED


func _refresh_list() -> void:
	var lines: PackedStringArray = []
	for id: int in Network.players:
		var suffix: String = " (host)" if id == 1 else ""
		lines.append("%s%s" % [Network.get_player_name(id), suffix])
	_players_label.text = "\n".join(lines)
