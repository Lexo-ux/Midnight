extends Control
## El Cuaderno del Umbral: Personas, Lugares, La línea del día y Preguntas
## abiertas (con tres niveles de pista que se piden a mano). Solo lee GameState;
## pedir una pista no toca la simulación.

const SILHOUETTE_SCENE := preload("res://scenes/silhouette.tscn")
const PAGES: PackedStringArray = ["personas", "lugares", "linea", "preguntas"]
const SILHOUETTE_SIZE: int = 140

@onready var _title: Label = %Title
@onready var _tabs: HBoxContainer = %Tabs
@onready var _content: VBoxContainer = %Content
@onready var _scroll: ScrollContainer = %Scroll
@onready var _close: Button = %Close

var page: String = "personas"


func _ready() -> void:
	_close.pressed.connect(hide)
	GameState.changed.connect(func() -> void:
		if visible:
			_render())


func open(start_page: String = "") -> void:
	if start_page != "":
		page = start_page
	show()
	_render()


func show_page(page_id: String) -> void:
	page = page_id
	_scroll.scroll_vertical = 0
	_render()


func _render() -> void:
	var data := GameState.data
	_title.text = data.text("cuaderno_titulo")
	_close.text = data.text("cerrar")
	for child: Node in _tabs.get_children():
		child.queue_free()
	for page_id: String in PAGES:
		var tab := Button.new()
		tab.text = data.text("pestana_" + page_id)
		tab.custom_minimum_size = Vector2(0, 120)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.theme_type_variation = &"TabActive" if page_id == page else &""
		tab.pressed.connect(show_page.bind(page_id))
		_tabs.add_child(tab)
	for child: Node in _content.get_children():
		child.queue_free()
	match page:
		"personas":
			_render_people()
		"lugares":
			_render_places()
		"linea":
			_render_timeline()
		_:
			_render_questions()


func _render_people() -> void:
	var data := GameState.data
	for id: String in data.npc_ids():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 24)
		var silhouette: Control = SILHOUETTE_SCENE.instantiate()
		silhouette.custom_minimum_size = Vector2(SILHOUETTE_SIZE, SILHOUETTE_SIZE)
		silhouette.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(silhouette)
		silhouette.show_person(data, id, GameState.velo_level(id))
		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(texts)
		var level := GameState.velo_level(id)
		texts.add_child(_label("%s · %s" % [data.people[id]["name"], data.text("velo_%d" % mini(level, 1))], &"PaperTitle"))
		for segment: Dictionary in data.relevant_schedule(id):
			var known := GameState.has_clue("horario_" + segment["id"])
			texts.add_child(_label("%s  %s" % [_time(segment["from"]), segment["label"] if known else data.text("horario_hueco")]))
		var facts: PackedStringArray = []
		for clue_id: String in data.clue_ids:
			var clue: Dictionary = data.clues[clue_id]
			if clue["person"] == id and clue["type"] != "Horario" and GameState.has_clue(clue_id):
				facts.append("• %s (%s): %s" % [clue["title"], clue["type"], clue["text"]])
		texts.add_child(_label(data.text("personas_sabido")))
		texts.add_child(_label("\n".join(facts) if not facts.is_empty() else data.text("personas_nada")))
		_content.add_child(row)
		_content.add_child(HSeparator.new())


func _render_places() -> void:
	var data := GameState.data
	for place: String in data.visible_location_ids():
		_content.add_child(_label(data.locations[place]["name"], &"PaperTitle"))
		var entries: Array[Dictionary] = []
		for clue_id: String in GameState.cuaderno:
			if data.clues[clue_id]["place"] == place:
				entries.append({"clue": data.clues[clue_id], "entry": GameState.cuaderno[clue_id]})
		entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["entry"]["time"] < b["entry"]["time"])
		if entries.is_empty():
			_content.add_child(_label(data.text("lugares_nada")))
		for item: Dictionary in entries:
			var header: String = data.text("lugares_por").format({"hora": _time(item["entry"]["time"]),
					"quien": data.people[item["entry"]["by"]]["name"]})
			_content.add_child(_label("%s — %s: %s" % [header, item["clue"]["title"], item["clue"]["text"]]))
		_content.add_child(HSeparator.new())


func _render_timeline() -> void:
	var data := GameState.data
	_content.add_child(_label(data.text("linea_intro").format({"inicio": _time(data.loop_start)})))
	for item: Dictionary in data.timeline:
		var known := GameState.has_clue(item["clue"])
		_content.add_child(_label("%s   %s" % [_time(item["time"]), item["label"] if known else data.text("linea_hueco")],
				&"PaperLabel" if known else &"PaperMuted"))


func _render_questions() -> void:
	var data := GameState.data
	var questions := GameState.get_questions()
	if questions.is_empty():
		_content.add_child(_label(data.text("preguntas_nada")))
	var hint_names: PackedStringArray = data.text("preguntas_pista_nombres").split("|")
	for item: Dictionary in questions:
		var question: Dictionary = item["question"]
		var title: String = question["text"]
		if item["resolved"]:
			title += "  (%s)" % data.text("preguntas_resuelta")
		_content.add_child(_label(title, &"PaperTitle"))
		for level: int in item["hint_level"]:
			_content.add_child(_label("%s: %s" % [hint_names[level], question["hints"][level]]))
		if item["hint_level"] < 3:
			var button := Button.new()
			button.text = data.text("preguntas_pista").format({"n": item["hint_level"] + 1})
			button.custom_minimum_size = Vector2(0, 120)
			button.pressed.connect(func() -> void: GameState.reveal_hint(question["id"]))
			_content.add_child(button)
		_content.add_child(HSeparator.new())


func _label(text: String, variation: StringName = &"PaperLabel") -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.theme_type_variation = variation
	return label


func _time(minute: int) -> String:
	return GameState.GameData.format_time(minute)
