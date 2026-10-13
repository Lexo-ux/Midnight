extends PanelContainer
## Medianoche: el final de este bucle (su ilustración, título y texto) y su
## entrada en el Cuaderno. Todos los finales del corte vertical devuelven al
## bucle; al empezar otro, main.gd pone la transición del reloj que vuelve atrás.
## La ilustración es la ranura `ending_<id>` (la de verdad o su provisional).

signal notebook_requested
signal next_loop_started

const ArtLibrary := preload("res://scripts/art_library.gd")
const UiMotion := preload("res://scripts/ui_motion.gd")

@onready var _midnight: Label = %Midnight
@onready var _illustration: TextureRect = %Illustration
@onready var _title: Label = %EndingTitle
@onready var _text: Label = %EndingText
@onready var _entry: Label = %Entry
@onready var _notebook: Button = %OpenNotebook
@onready var _next: Button = %NextLoop

## Qué final se está mostrando.
var _shown: String = ""
var _art: ArtLibrary


func _ready() -> void:
	_next.pressed.connect(func() -> void:
		if GameState.start_next_loop():
			next_loop_started.emit())
	_notebook.pressed.connect(func() -> void: notebook_requested.emit())


func bind(art: ArtLibrary) -> void:
	_art = art


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
	var picture := _art.texture_for(ending_slot(ending["id"])) if _art != null else null
	_illustration.texture = picture
	_illustration.visible = picture != null
	_title.text = ending["title"]
	_text.text = ending["text"]
	_entry.text = "%s · %s" % [clue["type"], clue["text"]]
	_notebook.text = data.text("boton_cuaderno")
	_next.text = data.text("final_otro_bucle")
	UiMotion.fade_in(self, GameState.settings["reduced_motion"])


## Ranura de la ilustración de un final.
static func ending_slot(ending_id: String) -> String:
	return "ending_" + ending_id
