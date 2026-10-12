extends PanelContainer
## Herramientas contra la repetición: «Saltar a la hora» (los dos siguen su
## rutina) y «Repetir mi ruta» (las acciones del bucle anterior, solo al
## empezar un bucle).

@onready var _title: Label = %Title
@onready var _skip_title: Label = %SkipTitle
@onready var _skip_help: Label = %SkipHelp
@onready var _skip_hours: GridContainer = %SkipHours
@onready var _replay_title: Label = %ReplayTitle
@onready var _replay_help: Label = %ReplayHelp
@onready var _replay_hours: GridContainer = %ReplayHours
@onready var _close: Button = %Close


func _ready() -> void:
	_close.pressed.connect(hide)


func open() -> void:
	var data := GameState.data
	_title.text = data.text("herramientas_titulo")
	_skip_title.text = data.text("saltar_titulo")
	_skip_help.text = data.text("saltar_ayuda")
	_replay_title.text = data.text("repetir_titulo")
	_close.text = data.text("cerrar")
	_fill(_skip_hours, GameState.skip_targets(), GameState.skip_to)
	var replay := GameState.replay_targets()
	_replay_help.text = data.text("repetir_ayuda" if not replay.is_empty() else "repetir_no")
	_fill(_replay_hours, replay, GameState.replay_route)
	show()


func _fill(grid: GridContainer, minutes: Array[int], action: Callable) -> void:
	for child: Node in grid.get_children():
		child.queue_free()
	for minute: int in minutes:
		var button := Button.new()
		button.text = GameState.GameData.format_time(minute)
		button.custom_minimum_size = Vector2(0, 120)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void:
			hide()
			action.call(minute))
		grid.add_child(button)
