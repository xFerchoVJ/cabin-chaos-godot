class_name GameBalance
extends Resource
## Datos de balance de la partida. La instancia vive en `resources/game_balance.tres`.

@export_group("Partida")
## Duración del vuelo (segundos) hasta pasar a resultados.
@export var flight_duration: float = 300.0
## Jugadores mínimos para que el host pueda iniciar el vuelo (1 permite probar solo).
@export_range(1, 4) var min_players_to_start: int = 1
