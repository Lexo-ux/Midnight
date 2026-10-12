extends PanelContainer
## Medianoche: el final de este bucle y su entrada en el Cuaderno. Todos los
## finales del corte vertical devuelven al bucle.

signal notebook_requested

@onready var _midnight: Label = %Midnight
@onready var _title: Label = %EndingTitle
@onready var _text: Label = %EndingText
@onready var _entry: Label = %Entry
@onready var _notebook: Button = %OpenNotebook
@onready var _next: Button = %NextLoop

## Qué final se está mostrando.
var _shown: String = ""


func _ready() -> void:
	_next.pressed.connect(func() -> void: GameState.start_next_loop())
	_notebook.pressed.connect(func() -> void: notebook_requested.emit())


## Se muestra a medianoche (una vez cerrado el diálogo pendiente) y se oculta al empezar otro bucle.
func sync(dialogue_pending: bool) -> void:
	if not GameState.is_loop_over() or dialogue_pending:
		hide()
		return
	if not visible or _shown != "%d|%s" % [GameState.loop_number, GameState.ending_id()]:
		open()


func open() -> void:
	_shown = "%d|%s" % [GameState.loop_number, GameState.ending_id()]
	var data := GameState.data
	var ending: Dictionary = {}
	for candidate: Dictionary in data.endings:
		if candidate["id"] == GameState.ending_id():
			ending = candidate
	var clue: Dictionary = data.clues[ending["clue"]]
	_midnight.text = data.text("final_medianoche")
	_title.text = ending["title"]
	_text.text = ending["text"]
	_entry.text = "%s · %s" % [clue["type"], clue["text"]]
	_notebook.text = data.text("boton_cuaderno")
	_next.text = data.text("final_otro_bucle")
	show()
