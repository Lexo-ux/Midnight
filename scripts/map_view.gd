extends PanelContainer
## El mapa de Much (pantalla completa). Los lugares del corte vertical son nodos
## grandes que se pueden tocar; el resto de la ciudad sale en gris, «sin
## explorar», listo para cuando crezca. Muestra dónde están los dos
## protagonistas (sol y luna) y, de los habitantes, solo a quien ya tiene su
## rutina entera en el Cuaderno. Abrirlo y cerrarlo no cuesta tiempo: tocar un
## lugar solo avisa (`place_chosen`); el viaje lo hace la acción que se elija
## allí, con los costes de siempre.

signal place_chosen(place: String)

const GameStateScript := preload("res://scripts/game_state.gd")
const SILHOUETTE_SCENE := preload("res://scenes/silhouette.tscn")
const ICON_SCRIPT := preload("res://scripts/protagonist_icon.gd")

const NODE_SIZE: float = 150.0
const MARKER_SIZE: float = 60.0
const NODE_WIDTH: float = 260.0
const ROAD := Color(0.93, 0.89, 0.8, 0.35)
const OPEN_FILL := Color("e9cf9e")
const OPEN_BORDER := Color("6b3f1a")
const HERE_BORDER := Color("fff4d6")
const LOCKED_FILL := Color(0.45, 0.45, 0.52, 0.55)

@onready var _title: Label = %Title
@onready var _help: Label = %Help
@onready var _legend: Label = %Legend
@onready var _canvas: Control = %Canvas
@onready var _close: Button = %Close

var _state: GameStateScript
## lugar -> centro del nodo en el lienzo del mapa.
var _centers: Dictionary = {}
## lugar -> botón (para los tests).
var _buttons: Dictionary = {}


func _ready() -> void:
	_close.pressed.connect(hide)
	_canvas.draw.connect(_draw_roads)
	_canvas.resized.connect(func() -> void:
		if visible:
			_render())


func bind(state: GameStateScript) -> void:
	_state = state


func open() -> void:
	show()
	_render()


## El botón de un lugar (null si no está en el mapa).
func node_button(place: String) -> Button:
	return _buttons.get(place)


func _render() -> void:
	var data := _state.data
	_title.text = data.text("mapa_titulo")
	_help.text = data.text("mapa_ayuda")
	_legend.text = data.text("mapa_leyenda")
	_close.text = data.text("cerrar")
	for child: Node in _canvas.get_children():
		_canvas.remove_child(child)
		child.queue_free()
	_centers.clear()
	_buttons.clear()
	var area := _canvas.size
	var active := _state.active_actor()
	for node: Dictionary in _state.map_nodes():
		var center := Vector2(clampf(node["x"] * area.x, NODE_WIDTH * 0.5, maxf(area.x - NODE_WIDTH * 0.5, NODE_WIDTH * 0.5)),
				clampf(node["y"] * area.y, NODE_SIZE * 0.5, maxf(area.y - NODE_SIZE, NODE_SIZE * 0.5)))
		_centers[node["place"]] = center
		_canvas.add_child(_make_node(node, center, active))
	_canvas.queue_redraw()


func _make_node(node: Dictionary, center: Vector2, active: String) -> Control:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	box.add_theme_constant_override("separation", 4)
	box.custom_minimum_size = Vector2(NODE_WIDTH, 0)
	box.position = center - Vector2(NODE_WIDTH * 0.5, NODE_SIZE * 0.5)
	var button := Button.new()
	button.custom_minimum_size = Vector2(NODE_SIZE, NODE_SIZE)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.disabled = not node["selectable"]
	var here: bool = node["protagonists"].has(active)
	for state_name: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state_name, _node_style(node["selectable"], here, state_name == "pressed"))
	if node["selectable"]:
		button.pressed.connect(_choose.bind(node["place"]))
	box.add_child(button)
	var markers := HBoxContainer.new()
	markers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	markers.alignment = BoxContainer.ALIGNMENT_CENTER
	markers.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.add_child(markers)
	for actor: String in node["protagonists"]:
		var icon: Control = ICON_SCRIPT.new()
		icon.custom_minimum_size = Vector2(MARKER_SIZE, MARKER_SIZE)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		markers.add_child(icon)
		var person: Dictionary = _state.data.people[actor]
		icon.set_icon(person["icon"], person["colors"]["body"].darkened(0.2) if actor == active else person["colors"]["body"].lightened(0.3),
				OPEN_FILL if node["selectable"] else LOCKED_FILL)
	if node["label"] != "":
		var label := Label.new()
		label.text = node["label"]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.theme_type_variation = &"NightLabel" if node["selectable"] else &"NightMuted"
		box.add_child(label)
	if not node["people"].is_empty():
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(row)
		for person: String in node["people"]:
			var silhouette: Control = SILHOUETTE_SCENE.instantiate()
			silhouette.custom_minimum_size = Vector2(MARKER_SIZE, MARKER_SIZE)
			row.add_child(silhouette)
			silhouette.show_person(_state.data, person, _state.velo_level(person))
	_buttons[node["place"]] = button
	return box


func _node_style(selectable: bool, here: bool, pressed: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = (OPEN_FILL.darkened(0.15) if pressed else OPEN_FILL) if selectable else LOCKED_FILL
	style.set_corner_radius_all(int(NODE_SIZE))
	style.set_border_width_all(10 if here else 5)
	style.border_color = HERE_BORDER if here else (OPEN_BORDER if selectable else Color(0, 0, 0, 0.3))
	return style


func _choose(place: String) -> void:
	hide()
	place_chosen.emit(place)


func _draw_roads() -> void:
	for road: Array in _state.data.map_roads:
		if _centers.has(road[0]) and _centers.has(road[1]):
			_canvas.draw_line(_centers[road[0]], _centers[road[1]], ROAD, 14.0, true)
