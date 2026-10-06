class_name HingeSwing
extends Node
## Componente: abre y cierra una hoja (puerta, tapa) girándola sobre su origen, que debe ser la bisagra.
## Solo anima: quién decide abrir y cómo se replica el estado lo resuelve el objeto que lo usa.

## Hoja que gira (normalmente un AnimatableBody3D, para que empuje a quien tenga encima).
@export var panel_path: NodePath
## Eje de giro en el espacio local del padre de la hoja.
@export var axis: Vector3 = Vector3.UP
## Ángulo de la hoja abierta, en grados.
@export var open_angle: float = -100.0
@export var swing_time: float = 0.25

var _angle: float = 0.0
var _tween: Tween = null

@onready var _panel: Node3D = get_node(panel_path) as Node3D


## Lleva la hoja a abierta o cerrada. Sin `animate` salta directo (estado inicial).
func set_open(open: bool, animate: bool = true) -> void:
	var target: float = deg_to_rad(open_angle) if open else 0.0
	if _tween != null:
		_tween.kill()
	if not animate or swing_time <= 0.0:
		_apply(target)
		return
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_method(_apply, _angle, target, swing_time)


func _apply(angle: float) -> void:
	_angle = angle
	_panel.transform.basis = Basis(axis, angle)
