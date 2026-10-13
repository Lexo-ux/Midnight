extends PanelContainer
## El mapa de Much (pantalla completa). Los lugares del corte vertical son nodos
## grandes que se pueden tocar; el resto de la ciudad sale en gris, «sin
## explorar», listo para cuando crezca. Muestra dónde están los dos
## protagonistas (sol y luna) y, de los habitantes, solo a quien ya tiene su
## rutina entera en el Cuaderno. Abrirlo y cerrarlo no cuesta tiempo: tocar un
## lugar solo avisa (`place_chosen`); el viaje lo hace la acción que se elija
## allí, con los costes de siempre.
##
## Cada lugar lleva su icono (ranura `map_<lugar>`; sin explorar,
## `map_unexplored`). Dónde estás se ve por forma: aro amarillo grueso y un
## alfiler encima; los demás lugares a los que se puede ir llevan una ficha con
## lo que cuesta llegar (una acción: 30 minutos).

signal place_chosen(place: String)

const GameStateScript := preload("res://scripts/game_state.gd")
const ArtLibrary := preload("res://scripts/art_library.gd")
const UiStyle := preload("res://scripts/ui_style.gd")
const SILHOUETTE_SCENE := preload("res://scenes/silhouette.tscn")
const ICON_SCRIPT := preload("res://scripts/protagonist_icon.gd")
const PIN := preload("res://assets/ui/icons/pin.svg")
const CLOCK := preload("res://assets/ui/icons/clock.svg")

const NODE_SIZE: float = 168.0
const MARKER_SIZE: float = 64.0
const NODE_WIDTH: float = 300.0
const ICON_INSET: float = 22.0
const ROAD_WIDTH: float = 16.0
const ROAD := Color("8a84ad")

@onready var _title: Label = %Title
@onready var _help: Label = %Help
@onready var _legend: Label = %Legend
@onready var _canvas: Control = %Canvas
@onready var _close: Button = %Close

var _state: GameStateScript
var _art: ArtLibrary
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


func bind(state: GameStateScript, art: ArtLibrary = null) -> void:
	_state = state
	_art = art


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
	_legend.text = data.text("mapa_leyenda").format({"min": data.step_minutes})
	_close.text = data.text("cerrar")
	for child: Node in _canvas.get_children():
		_canvas.remove_child(child)
		child.queue_free()
	_centers.clear()
	_buttons.clear()
	var area := _canvas.size
	var active := _state.active_actor()
	# Los lugares sin explorar primero: los que se pueden elegir (y sus fichas) quedan encima.
	var nodes := _state.map_nodes()
	nodes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return not a["selectable"] and b["selectable"])
	for node: Dictionary in nodes:
		var center := Vector2(clampf(node["x"] * area.x, NODE_WIDTH * 0.5, maxf(area.x - NODE_WIDTH * 0.5, NODE_WIDTH * 0.5)),
				clampf(node["y"] * area.y, NODE_SIZE * 0.6, maxf(area.y - NODE_SIZE * 1.2, NODE_SIZE * 0.6)))
		_centers[node["place"]] = center
		_canvas.add_child(_make_node(node, center, active))
	_canvas.queue_redraw()


func _make_node(node: Dictionary, center: Vector2, active: String) -> Control:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	box.theme_type_variation = &"VBoxTight"
	box.custom_minimum_size = Vector2(NODE_WIDTH, 0)
	box.position = center - Vector2(NODE_WIDTH * 0.5, NODE_SIZE * 0.5)
	var data := _state.data
	var button := Button.new()
	button.custom_minimum_size = Vector2(NODE_SIZE, NODE_SIZE)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.disabled = not node["selectable"]
	var here: bool = node["protagonists"].has(active)
	button.theme_type_variation = &"MapNodeHere" if here else (&"MapNode" if node["selectable"] else &"MapNodeLocked")
	if node["selectable"]:
		button.pressed.connect(_choose.bind(node["place"]))
	box.add_child(button)
	var art := _art.texture_for("map_" + node["place"] if node["selectable"] else "map_unexplored") if _art != null else null
	if art != null:
		var picture := TextureRect.new()
		picture.texture = art
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, int(ICON_INSET))
		button.add_child(picture)
	if here:
		var pin := TextureRect.new()
		pin.texture = PIN
		pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pin.position = Vector2(NODE_SIZE * 0.5 - PIN.get_width() * 0.5, -PIN.get_height() * 0.8)
		button.add_child(pin)
	# Sol y luna de los protagonistas, abajo a la derecha del nodo.
	var markers := HBoxContainer.new()
	markers.theme_type_variation = &"HBoxTight"
	markers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	markers.position = Vector2(NODE_SIZE - MARKER_SIZE * 0.7, NODE_SIZE - MARKER_SIZE * 0.8)
	button.add_child(markers)
	for actor: String in node["protagonists"]:
		var plate := PanelContainer.new()
		plate.theme_type_variation = &"PlateRound" if data.people[actor]["icon"] == "sol" else &"PlateChamfer"
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		markers.add_child(plate)
		var icon: Control = ICON_SCRIPT.new()
		icon.custom_minimum_size = Vector2(MARKER_SIZE, MARKER_SIZE)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.add_child(icon)
		var sun: bool = data.people[actor]["icon"] == "sol"
		icon.set_icon(data.people[actor]["icon"], UiStyle.INK if sun else UiStyle.AKBA_FILL_ACTIVE, UiStyle.PAPER if sun else Color("c9c6f0"))
	if node["label"] != "":
		var label := Label.new()
		label.text = node["label"]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.theme_type_variation = &"MapLabel" if node["selectable"] else &"NightMuted"
		box.add_child(label)
	if node["selectable"]:
		# Qué cuesta: estás aquí, o una acción (30 min) para llegar.
		var badge := PanelContainer.new()
		badge.theme_type_variation = &"BadgePanel"
		badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var row := HBoxContainer.new()
		row.theme_type_variation = &"HBoxTight"
		badge.add_child(row)
		var mark := TextureRect.new()
		mark.texture = PIN if here else CLOCK
		mark.custom_minimum_size = Vector2(40, 40)
		mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(mark)
		var cost := Label.new()
		cost.theme_type_variation = &"Badge"
		cost.text = data.text("mapa_aqui") if here else data.text("mapa_viaje").format({"min": data.step_minutes})
		row.add_child(cost)
		box.add_child(badge)
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


func _choose(place: String) -> void:
	hide()
	place_chosen.emit(place)


## Caminos de rotulador: trazo negro con el centro claro.
func _draw_roads() -> void:
	for pass_index: int in 2:
		for road: Array in _state.data.map_roads:
			if _centers.has(road[0]) and _centers.has(road[1]):
				_canvas.draw_line(_centers[road[0]], _centers[road[1]], UiStyle.INK if pass_index == 0 else ROAD,
						ROAD_WIDTH + (UiStyle.OUTLINE * 2.0 if pass_index == 0 else 0.0), true)
