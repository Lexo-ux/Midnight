extends Control
## Pantalla principal: el diorama vertical de Much. Lee GameState, llama a sus
## acciones y se redibuja cuando cambia. Solo guarda estado visual: qué tarjeta
## está desplegada y la animación del relevo.
##
## Arriba: hora, bucle y el selector Sazil/Akba. En medio: una tarjeta por
## lugar. Abajo, al alcance del pulgar: Cuaderno, Herramientas y Ajustes.

const GameData := preload("res://scripts/game_data.gd")
const SWITCH_BUTTON_SCENE := preload("res://scenes/switch_button.tscn")
const LOCATION_CARD_SCENE := preload("res://scenes/location_card.tscn")
const LocationCard := preload("res://scripts/location_card.gd")
## Acciones que no dependen del lugar (la bolsa de Sazil).
const BAG_VERBS: PackedStringArray = ["leer", "retener"]
const SWEEP_SECONDS: float = 0.22
const SWEEP_WIDTH_RATIO: float = 0.45
const SWEEP_ALPHA: float = 0.45

@onready var _sky: Control = %Sky
@onready var _time_label: Label = %TimeLabel
@onready var _loop_label: Label = %LoopLabel
@onready var _switcher: HBoxContainer = %Switcher
@onready var _status: Label = %Status
@onready var _bag: VBoxContainer = %Bag
@onready var _city: VBoxContainer = %CityList
@onready var _notebook_button: Button = %NotebookButton
@onready var _tools_button: Button = %ToolsButton
@onready var _settings_button: Button = %SettingsButton
@onready var _sweep: ColorRect = %Sweep
@onready var _dialogue: Control = %DialogueView
@onready var _notebook: Control = %NotebookView
@onready var _tools: Control = %ToolsView
@onready var _settings: Control = %SettingsView
@onready var _loop_end: Control = %LoopEndView

var _switch_buttons: Dictionary[String, Button] = {}
var _cards: Dictionary[String, LocationCard] = {}
var _expanded: String = ""
var _sweep_tween: Tween
var _refresh_queued: bool = false


func _ready() -> void:
	var data := GameState.data
	if not data.is_loaded():
		_status.text = data.text("error_carga") if not data.ui_text.is_empty() else "Error"
		return
	for actor: String in data.protagonist_ids:
		var button: Button = SWITCH_BUTTON_SCENE.instantiate()
		_switcher.add_child(button)
		button.setup(actor)
		button.chosen.connect(func(id: String) -> void: GameState.switch_to(id))
		_switch_buttons[actor] = button
	for place: String in data.visible_location_ids():
		var card: LocationCard = LOCATION_CARD_SCENE.instantiate()
		_city.add_child(card)
		card.setup(place)
		card.header_pressed.connect(_on_card_header)
		card.action_chosen.connect(func(command: Dictionary) -> void: GameState.perform(command))
		_cards[place] = card
	_notebook_button.text = data.text("boton_cuaderno")
	_tools_button.text = data.text("boton_herramientas")
	_settings_button.text = data.text("boton_ajustes")
	_notebook_button.pressed.connect(func() -> void: _notebook.open())
	_tools_button.pressed.connect(func() -> void: _tools.open())
	_settings_button.pressed.connect(func() -> void: _settings.open())
	_loop_end.notebook_requested.connect(func() -> void: _notebook.open())
	GameState.changed.connect(_queue_refresh)
	GameState.switched.connect(_play_sweep)
	GameState.settings_changed.connect(_apply_text_size)
	_expanded = _default_expanded()
	_apply_text_size()
	_refresh()


func _queue_refresh() -> void:
	if not _refresh_queued:
		_refresh_queued = true
		_refresh.call_deferred()


func _refresh() -> void:
	_refresh_queued = false
	var data := GameState.data
	var minute := GameState.current_time()
	var colors := _palette_at(minute)
	_sky.set_colors(colors["sky"], colors["horizon"], colors["stars"])
	var header_ink: Color = data.ink_dark if colors["sky"].get_luminance() > 0.5 else data.ink_light
	var card_ink: Color = data.ink_dark if colors["card"].get_luminance() > 0.5 else data.ink_light
	for label: Label in [_time_label, _loop_label, _status]:
		label.add_theme_color_override("font_color", header_ink)
	_time_label.text = GameData.format_time(minute)
	_loop_label.text = data.text("bucle").format({"n": GameState.loop_number})
	_refresh_switcher()
	_refresh_status()
	var actions := GameState.get_actions()
	_refresh_bag(actions)
	if not _cards.has(_expanded):
		_expanded = _default_expanded()
	for place: String in _cards:
		var here: Array[Dictionary] = []
		for action: Dictionary in actions:
			if action["place"] == place and not BAG_VERBS.has(action["verb"]):
				here.append(action)
		_cards[place].refresh(place == _expanded, colors["card"], card_ink, here)
	_refresh_overlays()


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


func _refresh_bag(actions: Array[Dictionary]) -> void:
	for child: Node in _bag.get_children():
		child.queue_free()
	for action: Dictionary in actions:
		if BAG_VERBS.has(action["verb"]):
			var button := Button.new()
			button.text = LocationCard.action_label(action)
			button.custom_minimum_size = Vector2(0, 120)
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.pressed.connect(func() -> void: GameState.perform(action))
			_bag.add_child(button)
	_bag.visible = _bag.get_child_count() > 0


## El diálogo pendiente va primero; después, si es medianoche, el final.
func _refresh_overlays() -> void:
	_dialogue.sync()
	_loop_end.sync(_dialogue.has_pending())


func _on_card_header(place: String) -> void:
	_expanded = "" if _expanded == place else place
	_queue_refresh()


func _default_expanded() -> String:
	var here := GameState.position_of(GameState.active_actor())
	if _cards.has(here):
		return here
	return GameState.data.visible_location_ids()[0]


## El relevo: un barrido de luz desde el lado de quien entra (Sazil por la
## izquierda, Akba por la derecha). Si se cambia muy rápido, el barrido anterior
## se corta y empieza otro. Con movimiento reducido no hay barrido.
func _play_sweep(actor: String) -> void:
	_expanded = _default_expanded()
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


func _apply_text_size() -> void:
	var data := GameState.data
	var sizes: Dictionary = data.text_sizes[GameState.settings["text_size"]]
	for type: String in ["Label", "Button", "CheckButton"]:
		theme.set_font_size("font_size", type, sizes["body"])
	for type: String in ["TitleLabel", "PaperTitle", "SwitchName"]:
		theme.set_font_size("font_size", type, sizes["title"])
	theme.set_font_size("font_size", "NightTitle", sizes["title"] + 12)


## Colores del cielo, el horizonte y las tarjetas interpolados por la hora del mundo.
func _palette_at(minute: int) -> Dictionary:
	var palette := GameState.data.palette
	if minute <= palette[0]["time"]:
		return palette[0]
	for i: int in range(1, palette.size()):
		var next: Dictionary = palette[i]
		if minute <= next["time"]:
			var previous: Dictionary = palette[i - 1]
			var weight: float = float(minute - previous["time"]) / float(next["time"] - previous["time"])
			return {
				"sky": previous["sky"].lerp(next["sky"], weight),
				"horizon": previous["horizon"].lerp(next["horizon"], weight),
				"card": previous["card"].lerp(next["card"], weight),
				"stars": lerpf(previous["stars"], next["stars"], weight),
			}
	return palette[-1]
