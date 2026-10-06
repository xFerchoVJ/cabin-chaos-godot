class_name MatchResults
extends CanvasLayer
## Pantalla de resultados: ganador, roles de cada jugador y botón de revancha (solo el host).

var _match: Match = null

@onready var _result_label: Label = %ResultLabel
@onready var _roles_label: Label = %RolesLabel
@onready var _rematch_button: Button = %RematchButton
@onready var _wait_label: Label = %WaitLabel


func _ready() -> void:
	visible = false
	_rematch_button.pressed.connect(_on_rematch_pressed)
	_rematch_button.visible = multiplayer.is_server()
	_wait_label.visible = not multiplayer.is_server()


func setup(match_node: Match) -> void:
	_match = match_node
	_match.state_changed.connect(_on_state_changed)
	_match.roles_changed.connect(_refresh)


func _on_state_changed() -> void:
	visible = _match.state == Match.State.RESULTS
	if visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_refresh()
	elif _match.state == Match.State.LOBBY:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _refresh() -> void:
	_result_label.text = _match.result_text
	var lines: PackedStringArray = []
	for id: int in Network.players:
		lines.append("%s — %s" % [Network.get_player_name(id), Match.role_name(_match.get_role(id))])
	_roles_label.text = "\n".join(lines)


func _on_rematch_pressed() -> void:
	_match.rematch()
