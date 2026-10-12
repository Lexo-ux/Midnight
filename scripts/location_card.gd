extends PanelContainer
## Tarjeta de un lugar en el diorama. Plegada: nombre, si está abierto, quién
## está (siluetas) y si hay un protagonista. Al tocarla se despliega en el sitio
## (sin transición de diapositiva) con lo que ve el protagonista activo y sus
## acciones ahí.

signal header_pressed(place: String)
signal action_chosen(command: Dictionary)

const SILHOUETTE_SCENE := preload("res://scenes/silhouette.tscn")
const ICON_SCRIPT := preload("res://scripts/protagonist_icon.gd")
const ACTION_MIN_HEIGHT: int = 120
const MARKER_SIZE: int = 72

@onready var _header: Button = %Header
@onready var _name: Label = %PlaceName
@onready var _state: Label = %PlaceState
@onready var _people: HBoxContainer = %People
@onready var _body: VBoxContainer = %Body
@onready var _description: Label = %Description
@onready var _actions: VBoxContainer = %Actions

var place: String = ""
var _style: StyleBoxFlat


func _ready() -> void:
	_style = (get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
	add_theme_stylebox_override("panel", _style)
	_header.pressed.connect(func() -> void: header_pressed.emit(place))


func setup(place_id: String) -> void:
	place = place_id


## Redibuja la tarjeta. `actions` son las acciones del protagonista activo en este lugar.
func refresh(expanded: bool, card_color: Color, ink: Color, actions: Array[Dictionary]) -> void:
	var data := GameState.data
	var minute := GameState.current_time()
	_style.bg_color = card_color
	for label: Label in [_name, _state, _description]:
		label.add_theme_color_override("font_color", ink)
	_name.text = data.locations[place]["name"]
	var state_key := "lugar_abierto" if data.is_open(place, minute) else "lugar_cerrado"
	_state.text = data.text(state_key)
	if GameState.position_of(GameState.active_actor()) == place:
		_state.text += " · " + data.text("lugar_aqui")
	_refresh_people(card_color)
	_body.visible = expanded
	if not expanded:
		return
	_description.text = _card_text()
	for child: Node in _actions.get_children():
		child.queue_free()
	for action: Dictionary in actions:
		var button := Button.new()
		button.text = action_label(action)
		button.custom_minimum_size = Vector2(0, ACTION_MIN_HEIGHT)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(func() -> void: action_chosen.emit(action))
		_actions.add_child(button)


## Texto del botón de una acción, con los formatos de ui_text.json.
static func action_label(action: Dictionary) -> String:
	var data := GameState.data
	var values: Dictionary = {}
	if action["target"] != "":
		values["nombre"] = data.people[action["target"]]["name"]
	match action["verb"]:
		"esperar":
			return data.text("accion_esperar")
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


func _card_text() -> String:
	var sim := GameState.sim
	for variant: Dictionary in GameState.data.locations[place]["card"]:
		if variant["actor"] in [GameState.active_actor(), "any"] and sim.check(variant["if"], {"place": place}):
			return variant["text"]
	return ""


func _refresh_people(card_color: Color) -> void:
	for child: Node in _people.get_children():
		child.queue_free()
	for person: String in GameState.people_at(place):
		var silhouette: Control = SILHOUETTE_SCENE.instantiate()
		_people.add_child(silhouette)
		silhouette.show_person(person, GameState.velo_level(person))
	for actor: String in GameState.data.protagonist_ids:
		if GameState.position_of(actor) == place:
			var marker: Control = ICON_SCRIPT.new()
			marker.custom_minimum_size = Vector2(MARKER_SIZE, MARKER_SIZE)
			marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_people.add_child(marker)
			var person: Dictionary = GameState.data.people[actor]
			marker.set_icon(person["icon"], person["colors"]["body"], card_color)
