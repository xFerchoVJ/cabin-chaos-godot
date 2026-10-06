class_name MatchHud
extends CanvasLayer
## HUD de partida: estado del lobby o rol y tiempo restante del vuelo. Solo lee; nunca modifica el estado.

var _match: Match = null

@onready var _label: Label = %StatusLabel


func _process(_delta: float) -> void:
	if _match == null:
		return
	match _match.state:
		Match.State.LOBBY:
			var hint: String = "Inicia el vuelo desde el menú [Esc]" if multiplayer.is_server() else "Espera a que el host inicie el vuelo"
			_label.text = "Lobby · Jugadores %d/%d\n%s" % [Network.players.size(), Network.MAX_PLAYERS, hint]
		Match.State.FLIGHT:
			var seconds: int = ceili(_match.time_left)
			var role: String = Match.role_name(_match.get_role(multiplayer.get_unique_id()))
			_label.text = "Eres: %s · %d:%02d" % [role, seconds / 60, seconds % 60]
		Match.State.RESULTS:
			_label.text = ""


func setup(match_node: Match) -> void:
	_match = match_node
