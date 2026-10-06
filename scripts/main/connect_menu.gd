extends Control
## Menú de conexión: pide nombre e IP y emite lo que el usuario quiere hacer. No toca la red.

signal host_requested(player_name: String)
signal join_requested(ip: String, player_name: String)

@onready var _name_edit: LineEdit = %NameEdit
@onready var _ip_edit: LineEdit = %IpEdit
@onready var _host_button: Button = %HostButton
@onready var _join_button: Button = %JoinButton
@onready var _status_label: Label = %StatusLabel


func _ready() -> void:
	_host_button.pressed.connect(func() -> void: host_requested.emit(_name_edit.text))
	_join_button.pressed.connect(func() -> void: join_requested.emit(_ip_edit.text.strip_edges(), _name_edit.text))


## Muestra un mensaje de estado y bloquea los botones mientras se conecta.
func set_status(text: String, busy: bool = false) -> void:
	_status_label.text = text
	_host_button.disabled = busy
	_join_button.disabled = busy
