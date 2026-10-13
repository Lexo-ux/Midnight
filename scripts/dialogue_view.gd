extends Control
## Diálogo del último paso: una línea cada vez, con la cara (según el Velo:
## silueta, rostro o retrato; los protagonistas, su retrato) y el nombre de
## quien habla. Al final, lo nuevo en el Cuaderno. Cerrarlo no cuesta tiempo.

const ArtLibrary := preload("res://scripts/art_library.gd")

@onready var _portrait: Control = %SpeakerPortrait
@onready var _speaker: Label = %Speaker
@onready var _line: Label = %Line
@onready var _clues: Label = %NewClues
@onready var _next: Button = %Next

var _index: int = 0
## Qué diálogo se está mostrando, para empezar de nuevo si llega otro.
var _shown: String = ""
var _art: ArtLibrary


func _ready() -> void:
	_next.pressed.connect(_on_next)


func bind(art: ArtLibrary) -> void:
	_art = art


## Muestra el diálogo pendiente (desde la primera línea si es nuevo) o se oculta.
func sync() -> void:
	if not has_pending():
		_shown = ""
		hide()
		return
	var key := "%d|%d|%s|%s" % [GameState.loop_number, GameState.current_time(), GameState.outcome_lines(), GameState.outcome_clues()]
	if key != _shown or not visible:
		_shown = key
		_index = 0
		show()
		_render()


func has_pending() -> bool:
	return not GameState.outcome_lines().is_empty() or not GameState.outcome_clues().is_empty()


func _render() -> void:
	var data := GameState.data
	var lines := GameState.outcome_lines()
	var clues := GameState.outcome_clues()
	var last := _index >= lines.size() - 1
	if lines.is_empty():
		_speaker.text = data.text("dialogo_nuevo")
		_line.text = ""
		_portrait.hide()
	else:
		var line: Dictionary = lines[_index]
		_portrait.show()
		_portrait.show_person(data, _art, line["speaker"], GameState.velo_level(line["speaker"]))
		_speaker.text = data.people[line["speaker"]]["name"]
		_line.text = line["text"]
	_clues.visible = last and not clues.is_empty()
	if _clues.visible:
		var titles: PackedStringArray = []
		for id: String in clues:
			titles.append("• " + data.clues[id]["title"])
		_clues.text = "%s\n%s" % [data.text("dialogo_nuevo"), "\n".join(titles)]
	_next.text = data.text("dialogo_continuar" if last else "dialogo_seguir")


func _on_next() -> void:
	if _index < GameState.outcome_lines().size() - 1:
		_index += 1
		_render()
	else:
		_shown = ""
		hide()
		GameState.dismiss_outcome()
