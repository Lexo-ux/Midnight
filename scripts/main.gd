extends Control
## Pantalla principal: la escena del lugar donde está el protagonista
## controlado, en primera persona (solo sus manos). Lee GameState, llama a sus
## acciones y se redibuja cuando cambia. Solo guarda estado visual: qué lugar se
## mira desde el mapa, a quién se ha elegido y la animación del relevo.
##
## Arriba: hora, bucle, Ajustes, y Mapa, Cuaderno y Herramientas. En medio: la
## escena. Abajo, al alcance del pulgar: lo que se puede hacer allí y el
## selector Sazil/Akba con sus retratos.

const GameData := preload("res://scripts/game_data.gd")
const ArtLibrary := preload("res://scripts/art_library.gd")
const SWITCH_BUTTON_SCENE := preload("res://scenes/switch_button.tscn")
## Acciones que no dependen del lugar (la bolsa de Sazil).
const BAG_VERBS: PackedStringArray = ["leer", "retener"]
const SWEEP_SECONDS: float = 0.22
const SWEEP_WIDTH_RATIO: float = 0.45
const SWEEP_ALPHA: float = 0.45
const BUTTON_MIN_HEIGHT: int = 120

@onready var _place_view: Control = %PlaceView
@onready var _hands: Control = %Hands
@onready var _time_label: Label = %TimeLabel
@onready var _loop_label: Label = %LoopLabel
@onready var _caption: Label = %Caption
@onready var _status: Label = %Status
@onready var _back_button: Button = %BackButton
@onready var _map_button: Button = %MapButton
@onready var _notebook_button: Button = %NotebookButton
@onready var _tools_button: Button = %ToolsButton
@onready var _settings_button: Button = %SettingsButton
@onready var _description: Label = %Description
@onready var _people: HBoxContainer = %People
@onready var _people_scroll: ScrollContainer = %PeopleScroll
@onready var _actions: VBoxContainer = %Actions
@onready var _switcher: HBoxContainer = %Switcher
@onready var _sweep: ColorRect = %Sweep
@onready var _map: Control = %MapView
@onready var _dialogue: Control = %DialogueView
@onready var _notebook: Control = %NotebookView
@onready var _tools: Control = %ToolsView
@onready var _settings: Control = %SettingsView
@onready var _loop_end: Control = %LoopEndView

var _art: ArtLibrary = ArtLibrary.new()
var _switch_buttons: Dictionary[String, Button] = {}
## Lugar que se mira desde el mapa sin estar allí ("" = donde está el protagonista).
var _view_place: String = ""
## Persona elegida en la escena ("" = acciones del lugar).
var _selected: String = ""
## Cambia con cada acción o relevo: entonces se olvidan la vista previa y la persona elegida.
var _route_key: String = ""
var _sweep_tween: Tween
var _refresh_queued: bool = false


func _ready() -> void:
	var data := GameState.data
	if not data.is_loaded():
		_caption.text = data.text("error_carga") if not data.ui_text.is_empty() else "Error"
		return
	_art.load_manifest()
	_place_view.bind(GameState, _art)
	_place_view.hotspot_tapped.connect(func(id: String) -> void: GameState.perform_hotspot(id))
	_place_view.person_tapped.connect(_select_person)
	_hands.bind(_art)
	_map.bind(GameState)
	_map.place_chosen.connect(_preview_place)
	for actor: String in data.protagonist_ids:
		var button: Button = SWITCH_BUTTON_SCENE.instantiate()
		_switcher.add_child(button)
		button.setup(GameState, _art, actor)
		button.chosen.connect(func(id: String) -> void: GameState.switch_to(id))
		_switch_buttons[actor] = button
	_map_button.text = data.text("boton_mapa")
	_notebook_button.text = data.text("boton_cuaderno")
	_tools_button.text = data.text("boton_herramientas")
	_settings_button.text = data.text("boton_ajustes")
	_back_button.text = data.text("escena_volver")
	_map_button.pressed.connect(func() -> void: _map.open())
	_notebook_button.pressed.connect(func() -> void: _notebook.open())
	_tools_button.pressed.connect(func() -> void: _tools.open())
	_settings_button.pressed.connect(func() -> void: _settings.open())
	_back_button.pressed.connect(func() -> void: _preview_place(""))
	_loop_end.notebook_requested.connect(func() -> void: _notebook.open())
	GameState.changed.connect(_queue_refresh)
	GameState.switched.connect(_play_sweep)
	GameState.settings_changed.connect(_on_settings_changed)
	_apply_text_size()
	_refresh()


func _queue_refresh() -> void:
	if not _refresh_queued:
		_refresh_queued = true
		_refresh.call_deferred()


func _refresh() -> void:
	_refresh_queued = false
	var data := GameState.data
	var actor := GameState.active_actor()
	var route_key := "%d|%d|%s" % [GameState.loop_number, GameState.sim.s["route"].size(), actor]
	if route_key != _route_key:
		_route_key = route_key
		_view_place = ""
		_selected = ""
	var here := GameState.position_of(actor)
	var place := _view_place if _view_place != "" else here
	var preview := place != here
	if not GameState.people_at(place).has(_selected):
		_selected = ""
	_time_label.text = GameData.format_time(GameState.current_time())
	_loop_label.text = data.text("bucle").format({"n": GameState.loop_number})
	_place_view.refresh(place, preview, _selected)
	var reduced: bool = GameState.settings["reduced_motion"]
	_hands.show_hands(actor, GameState.hands_state(actor), 0.0 if reduced else data.scene_camera["hands_ms"] / 1000.0)
	_refresh_caption(place, preview)
	_refresh_status()
	_refresh_switcher()
	var actions := GameState.get_actions()
	_refresh_people(place, actions)
	_refresh_actions(place, here, actions)
	_dialogue.sync()
	_loop_end.sync(_dialogue.has_pending())


func _refresh_caption(place: String, preview: bool) -> void:
	var data := GameState.data
	var actor := GameState.active_actor()
	_back_button.visible = preview and data.has_scene(place)
	if _back_button.visible:
		_caption.text = data.text("escena_lejos").format({"lugar": data.locations[place]["name"]})
		return
	if not data.has_scene(place):
		_caption.text = data.locations[place]["name"]
		return
	var station := GameState.station_of(actor, place)
	if station == "":
		station = data.scenes[place]["entry"]
	var station_name: String = data.scenes[place]["stations"][data.scenes[place]["station_index"][station]]["name"]
	var values: Dictionary = {"lugar": data.locations[place]["name"], "estacion": station_name}
	if data.locations[place]["open"] < 0:
		_caption.text = data.text("escena_lugar").format(values)
		return
	values["estado"] = data.text("lugar_abierto" if data.is_open(place, GameState.current_time()) else "lugar_cerrado")
	_caption.text = data.text("escena_lugar_horario").format(values)


func _refresh_status() -> void:
	var data := GameState.data
	var actor := GameState.active_actor()
	var lines: PackedStringArray = []
	if GameState.is_disabled(actor):
		lines.append(data.text("atrapado_aviso"))
	elif GameState.is_exhausted(actor):
		lines.append(data.text("acciones_akba_agotado"))
	if actor == "akba" or GameState.rastro() > 0:
		lines.append(data.text("rastro_desgaste").format({"rastro": GameState.rastro(), "rastro_max": data.rastro_max,
				"desgaste": GameState.desgaste(), "desgaste_max": data.desgaste_max}))
	_status.text = "\n".join(lines)
	_status.visible = not lines.is_empty()


func _refresh_switcher() -> void:
	var data := GameState.data
	for actor: String in _switch_buttons:
		var status: String
		if GameState.is_disabled(actor):
			status = data.text("estado_atrapado")
		elif GameState.is_exhausted(actor):
			status = data.text("estado_agotado")
		else:
			status = data.text("estado_en").format({"lugar": data.locations[GameState.position_of(actor)]["short"]})
		_switch_buttons[actor].refresh(actor == GameState.active_actor(), status, GameState.can_switch())


## Una ficha por persona del lugar (o la elegida y «Todas las acciones»).
func _refresh_people(place: String, actions: Array[Dictionary]) -> void:
	var data := GameState.data
	for child: Node in _people.get_children():
		_people.remove_child(child)
		child.queue_free()
	var present := GameState.people_at(place)
	_people_scroll.visible = not present.is_empty() and data.has_scene(place)
	if _selected != "":
		_people.add_child(_chip(data.text("escena_todas"), false, _select_person.bind(_selected)))
	for person: String in present:
		var has_actions := actions.any(func(action: Dictionary) -> bool: return action["place"] == place and action["target"] == person)
		var chip := _chip(data.people[person]["name"], person == _selected, _select_person.bind(person))
		chip.disabled = not has_actions
		_people.add_child(chip)
	var description := ""
	if data.has_scene(place):
		for variant: Dictionary in data.locations[place]["card"]:
			if variant["actor"] in [GameState.active_actor(), "any"] and GameState.sim.check(variant["if"], {"place": place}):
				description = variant["text"]
				break
	_description.text = description
	_description.visible = description != ""


## Las acciones de la persona elegida o, si no hay, las del lugar y la bolsa.
func _refresh_actions(place: String, here: String, actions: Array[Dictionary]) -> void:
	for child: Node in _actions.get_children():
		_actions.remove_child(child)
		child.queue_free()
	for action: Dictionary in actions:
		var bag := BAG_VERBS.has(action["verb"])
		var shown: bool = bag if place != action["place"] else (bag or action["target"] == _selected)
		if not shown:
			continue
		var button := Button.new()
		button.text = _action_label(action, here)
		button.custom_minimum_size = Vector2(0, BUTTON_MIN_HEIGHT)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(func() -> void: GameState.perform(action))
		_actions.add_child(button)


func _chip(text: String, active: bool, on_pressed: Callable) -> Button:
	var chip := Button.new()
	chip.text = text
	chip.custom_minimum_size = Vector2(0, BUTTON_MIN_HEIGHT)
	chip.theme_type_variation = &"TabActive" if active else &""
	chip.pressed.connect(on_pressed)
	return chip


## Texto del botón de una acción, con los formatos de ui_text.json.
func _action_label(action: Dictionary, here: String) -> String:
	var data := GameState.data
	var values: Dictionary = {}
	if action["target"] != "":
		values["nombre"] = data.people[action["target"]]["name"]
	match action["verb"]:
		"esperar":
			return data.text("accion_esperar" if action["place"] == here else "accion_ir")
		"observar":
			return data.text("accion_observar" if action["target"] != "" else "accion_observar_lugar").format(values)
		"seguir":
			return data.text("accion_seguir").format(values)
		"hablar":
			values["tema"] = data.talks[action["id"]]["label"]
			return data.text("accion_hablar").format(values)
		"interactuar":
			var interaction: Dictionary = data.interactions[action["id"]]
			return data.text("accion_" + interaction["verb"]).format({"texto": interaction["label"]})
		_:
			values["carta"] = data.letters[action["id"]]["label"]
			return data.text("accion_" + action["verb"]).format(values)


func _select_person(person: String) -> void:
	_selected = "" if _selected == person else person
	_queue_refresh()


## Desde el mapa: mirar un lugar sin gastar tiempo ("" = volver a donde se está).
func _preview_place(place: String) -> void:
	_view_place = "" if place == GameState.position_of(GameState.active_actor()) else place
	_selected = ""
	_queue_refresh()


## El relevo: un barrido de luz desde el lado de quien entra (Sazil por la
## izquierda, Akba por la derecha) mientras cambia la mirada de la escena. Si se
## cambia muy rápido, el barrido anterior se corta y empieza otro. Con
## movimiento reducido no hay barrido.
func _play_sweep(actor: String) -> void:
	if _sweep_tween != null and _sweep_tween.is_valid():
		_sweep_tween.kill()
	if GameState.settings["reduced_motion"]:
		_sweep.hide()
		return
	var data := GameState.data
	var width := size.x * SWEEP_WIDTH_RATIO
	var from_left := data.protagonist_ids.find(actor) == 0
	var color: Color = data.people[actor]["colors"]["body"].lightened(0.5)
	color.a = SWEEP_ALPHA
	_sweep.color = color
	_sweep.size = Vector2(width, size.y)
	_sweep.position = Vector2(-width if from_left else size.x, 0)
	_sweep.show()
	_sweep_tween = create_tween()
	_sweep_tween.tween_property(_sweep, "position:x", size.x if from_left else -width, SWEEP_SECONDS)
	_sweep_tween.tween_callback(_sweep.hide)


func _on_settings_changed() -> void:
	_apply_text_size()
	_queue_refresh()


func _apply_text_size() -> void:
	var data := GameState.data
	var sizes: Dictionary = data.text_sizes[GameState.settings["text_size"]]
	for type: String in ["Label", "Button", "CheckButton"]:
		theme.set_font_size("font_size", type, sizes["body"])
	for type: String in ["TitleLabel", "PaperTitle", "SwitchName"]:
		theme.set_font_size("font_size", type, sizes["title"])
	theme.set_font_size("font_size", "NightTitle", sizes["title"] + 12)
