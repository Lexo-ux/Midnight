extends Control
## El Cuaderno del Umbral: Personas, Lugares, La línea del día y Preguntas
## abiertas (con tres niveles de pista que se piden a mano, o con «¿Qué hago?»).
## Solo lee GameState; pedir una pista no toca la simulación.
##
## Personas: la cara según el Velo (silueta, rasgos, rostro, retrato; ver
## scripts/portrait_view.gd), el nivel en puntos (llenos o huecos) y, al final,
## los créditos de los retratos de la comunidad.
##
## Cada persona, lugar y pregunta va en su ficha; lo que falta, apagado y con
## un punto hueco (forma, no solo color). Las pestañas se reparten en 4 o, si
## el texto no cabe (texto muy grande), en 2 columnas: nunca desbordan.

const ArtLibrary := preload("res://scripts/art_library.gd")
const PortraitView := preload("res://scripts/portrait_view.gd")
const UiMotion := preload("res://scripts/ui_motion.gd")
const UiStyle := preload("res://scripts/ui_style.gd")
const Pips := preload("res://scripts/confianza_pips.gd")
const VELO_MAX: int = 3
const PAGES: PackedStringArray = ["personas", "lugares", "linea", "preguntas"]
const SILHOUETTE_SIZE: int = 160

@onready var _title: Label = %Title
@onready var _tabs: GridContainer = %Tabs
@onready var _content: VBoxContainer = %Content
@onready var _scroll: ScrollContainer = %Scroll
@onready var _close: Button = %Close

var page: String = "personas"
## Aviso de «¿Qué hago?» cuando ya no quedan pistas ("" = ninguno).
var notice: String = ""
var _art: ArtLibrary


func _ready() -> void:
	_close.pressed.connect(hide)
	GameState.changed.connect(func() -> void:
		if visible:
			_render())


func bind(art: ArtLibrary) -> void:
	_art = art


func open(start_page: String = "") -> void:
	if start_page != "":
		page = start_page
	notice = ""
	UiMotion.fade_in(self, GameState.settings["reduced_motion"])
	_render()


## «¿Qué hago?»: la siguiente pista de la primera pregunta abierta, en su página.
func what_now() -> void:
	var question := GameState.next_hint()
	open("preguntas")
	notice = "" if question != "" else GameState.data.text("que_hago_nada")
	_render()


func show_page(page_id: String) -> void:
	page = page_id
	notice = ""
	_scroll.scroll_vertical = 0
	_render()


func _render() -> void:
	var data := GameState.data
	_title.text = data.text("cuaderno_titulo")
	_close.text = data.text("cerrar")
	for child: Node in _tabs.get_children():
		_tabs.remove_child(child)
		child.queue_free()
	var widest := 0.0
	for page_id: String in PAGES:
		var tab := Button.new()
		tab.text = data.text("pestana_" + page_id)
		UiStyle.touch(tab, &"TabSelected" if page_id == page else &"Tab")
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.pressed.connect(show_page.bind(page_id))
		_tabs.add_child(tab)
		widest = maxf(widest, tab.get_combined_minimum_size().x)
	# Cuatro pestañas iguales si caben; si no, dos filas de dos.
	var gap := float(_tabs.get_theme_constant("h_separation"))
	var room := _tabs.size.x if _tabs.size.x > 0.0 else size.x
	_tabs.columns = PAGES.size() if widest * PAGES.size() + gap * (PAGES.size() - 1) <= room else 2
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
		var card := _card()
		var row := HBoxContainer.new()
		var level := GameState.velo_level(id)
		var portrait := PortraitView.new()
		portrait.custom_minimum_size = Vector2(SILHOUETTE_SIZE, SILHOUETTE_SIZE)
		portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(portrait)
		portrait.show_person(data, _art, id, level)
		var texts := VBoxContainer.new()
		texts.theme_type_variation = &"VBoxTight"
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(texts)
		texts.add_child(_label("%s · %s" % [data.people[id]["name"], data.text("velo_%d" % mini(level, VELO_MAX))], &"PaperTitle"))
		var velo_row := HBoxContainer.new()
		velo_row.theme_type_variation = &"HBoxTight"
		velo_row.add_child(_label(data.text("personas_velo"), &"PaperMuted", false))
		var pips: Control = Pips.new()
		pips.custom_minimum_size = Vector2(150, 40)
		pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		velo_row.add_child(pips)
		pips.set_value(mini(level, VELO_MAX), VELO_MAX)
		texts.add_child(velo_row)
		var credit: Variant = data.people[id]["portrait_credit"]
		if level >= 3 and credit != null:
			var author: String = credit["author"]
			if credit["link"] != "":
				author += " · " + credit["link"]
			texts.add_child(_label(data.text("velo_credito").format({"autor": author}), &"PaperMuted"))
		for segment: Dictionary in data.relevant_schedule(id):
			var known := GameState.has_clue("horario_" + segment["id"])
			texts.add_child(_label("%s %s  %s" % ["●" if known else "○", _time(segment["from"]), segment["label"] if known else data.text("horario_hueco")],
					&"PaperLabel" if known else &"PaperMuted"))
		var facts: PackedStringArray = []
		for clue_id: String in data.clue_ids:
			var clue: Dictionary = data.clues[clue_id]
			if clue["person"] == id and clue["type"] != "Horario" and GameState.has_clue(clue_id):
				facts.append("• %s (%s): %s" % [clue["title"], clue["type"], clue["text"]])
		texts.add_child(_label(data.text("personas_sabido"), &"PaperMuted"))
		texts.add_child(_label("\n".join(facts) if not facts.is_empty() else data.text("personas_nada"),
				&"PaperLabel" if not facts.is_empty() else &"PaperMuted"))
		card.add_child(row)
	_render_credits()


## Quién hizo cada retrato (la comunidad); los que faltan, pendientes.
func _render_credits() -> void:
	var data := GameState.data
	var card := _card()
	card.add_child(_label(data.text("creditos_titulo"), &"PaperTitle"))
	card.add_child(_label(data.text("creditos_ayuda"), &"PaperMuted"))
	for id: String in data.npc_ids():
		var credit: Variant = data.people[id]["portrait_credit"]
		var person_name: String = data.people[id]["name"]
		if credit == null:
			card.add_child(_label("○ " + data.text("creditos_pendiente").format({"nombre": person_name}), &"PaperMuted"))
		else:
			var author: String = credit["author"]
			if credit["link"] != "":
				author += " · " + credit["link"]
			card.add_child(_label("● " + data.text("creditos_autor").format({"nombre": person_name, "autor": author})))


func _render_places() -> void:
	var data := GameState.data
	for place: String in data.visible_location_ids():
		var card := _card()
		card.add_child(_label(data.locations[place]["name"], &"PaperTitle"))
		var entries: Array[Dictionary] = []
		for clue_id: String in GameState.cuaderno:
			if data.clues[clue_id]["place"] == place:
				entries.append({"clue": data.clues[clue_id], "entry": GameState.cuaderno[clue_id]})
		entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["entry"]["time"] < b["entry"]["time"])
		if entries.is_empty():
			card.add_child(_label("○ " + data.text("lugares_nada"), &"PaperMuted"))
		for item: Dictionary in entries:
			var header: String = data.text("lugares_por").format({"hora": _time(item["entry"]["time"]),
					"quien": data.people[item["entry"]["by"]]["name"]})
			card.add_child(_label("%s — %s: %s" % [header, item["clue"]["title"], item["clue"]["text"]]))


func _render_timeline() -> void:
	var data := GameState.data
	_content.add_child(_label(data.text("linea_intro").format({"inicio": _time(data.loop_start)})))
	var card := _card()
	for item: Dictionary in data.timeline:
		var known := GameState.has_clue(item["clue"])
		card.add_child(_label("%s %s   %s" % ["●" if known else "○", _time(item["time"]), item["label"] if known else data.text("linea_hueco")],
				&"PaperLabel" if known else &"PaperMuted"))


func _render_questions() -> void:
	var data := GameState.data
	var questions := GameState.get_questions()
	var ask := Button.new()
	ask.text = data.text("que_hago")
	UiStyle.touch(ask, &"Primary")
	ask.pressed.connect(what_now)
	_content.add_child(ask)
	if notice != "":
		_content.add_child(_label(notice, &"PaperMuted"))
	if questions.is_empty():
		_card().add_child(_label("○ " + data.text("preguntas_nada"), &"PaperMuted"))
	var hint_names: PackedStringArray = data.text("preguntas_pista_nombres").split("|")
	for item: Dictionary in questions:
		var question: Dictionary = item["question"]
		var card := _card()
		var title: String = ("● " if item["resolved"] else "○ ") + question["text"]
		if item["resolved"]:
			title += "  (%s)" % data.text("preguntas_resuelta")
		card.add_child(_label(title, &"PaperTitle"))
		for level: int in item["hint_level"]:
			card.add_child(_label("%s: %s" % [hint_names[level], question["hints"][level]]))
		if item["hint_level"] < 3:
			var button := Button.new()
			button.text = data.text("preguntas_pista").format({"n": item["hint_level"] + 1})
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			UiStyle.touch(button)
			button.pressed.connect(func() -> void: GameState.reveal_hint(question["id"]))
			card.add_child(button)


## Una ficha nueva al final de la página; devuelve dónde van sus líneas.
func _card() -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"Card"
	_content.add_child(panel)
	var box := VBoxContainer.new()
	box.theme_type_variation = &"VBoxTight"
	panel.add_child(box)
	return box


func _label(text: String, variation: StringName = &"PaperLabel", wrap: bool = true) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	label.theme_type_variation = variation
	return label


func _time(minute: int) -> String:
	return GameState.GameData.format_time(minute)
