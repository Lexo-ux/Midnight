extends Control
## La escena de un lugar, en primera persona: capas con paralaje (fondo de día,
## atardecer y noche, `mid`, superposición de Akba y primer plano), la gente que
## está allí según la simulación, los puntos interactivos y la luz de la hora.
##
## - Cada acción lleva la cámara a la estación de lo que toca (≤400 ms; al
##   instante con movimiento reducido); «esperar» la desliza despacio a la
##   siguiente mientras cambia la luz.
## - Arrastrar con un dedo mira alrededor dentro del lienzo: no cuesta tiempo ni
##   toca la simulación. La siguiente acción recentra la cámara.
## - La mirada de Sazil es cálida y cotidiana; la de Akba, más fría, con la capa
##   akba_overlay y sus fisuras tornasoladas.
## Solo guarda estado visual; todo lo demás lo lee de GameState.

signal hotspot_tapped(hotspot_id: String)
signal person_tapped(person_id: String)

const GameStateScript := preload("res://scripts/game_state.gd")
const GameData := preload("res://scripts/game_data.gd")
const SceneRules := preload("res://scripts/scene_rules.gd")
const ArtLibrary := preload("res://scripts/art_library.gd")
const PlaceholderArt := preload("res://scripts/placeholder_art.gd")
const SILHOUETTE_SCENE := preload("res://scenes/silhouette.tscn")
const SHIMMER := preload("res://assets/shaders/akba_shimmer.gdshader")

const BG_FACTOR: float = 0.4
const MID_FACTOR: float = 1.0
const FG_FACTOR: float = 1.3
## El primer plano va algo más oscuro que el resto.
const FG_SHADE: float = 0.3
## Diámetro mínimo en pantalla de lo que se puede tocar (personas y puntos).
const TOUCH_MIN: float = 130.0
const HINT_RADIUS: float = 70.0
const PERSON_SPREAD: float = 200.0
const PERSON_WIDTH_RATIO: float = 0.8
const OTHER_ALPHA: float = 0.8
const HINT_COLOR := Color(1.0, 0.95, 0.8, 0.85)
const FISSURE_COLOR := Color("5affc8")
const LABEL_SIZE: int = 76

@onready var _world: Control = $World
@onready var _light: ColorRect = $Light
@onready var _grade: ColorRect = $Grade
@onready var _offstage: Label = $Offstage

var place: String = ""
var look: String = ""
## Centro de la cámara en px del lienzo (plano `mid`).
var camera_x: float = 0.0:
	set(value):
		camera_x = value
		_apply_camera()

var _state: GameStateScript
var _data: GameData
var _art: ArtLibrary
## [{node, factor}] en orden de dibujo.
var _layers: Array[Dictionary] = []
var _bg: Dictionary = {}
var _overlay: Control
var _overlay_art: CanvasItem
var _fg: Control
var _people_layer: Control
var _hotspot_layer: Control
## persona -> Rect2 en px del lienzo.
var _people: Dictionary = {}
var _hotspots: Array[Dictionary] = []
var _selected: String = ""
var _action_key: String = ""
var _near_station: String = ""
var _camera_tween: Tween
var _light_tween: Tween
var _minute_from: float = 0.0
var _minute_to: float = 0.0
var _grade_from: Dictionary = {}
var _grade_to: Dictionary = {}
var _light_blend: float = 1.0:
	set(value):
		_light_blend = value
		_apply_light()
var _pressing: bool = false
var _dragging: bool = false
var _press_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(func() -> void: camera_x = camera_x)


func bind(state: GameStateScript, art: ArtLibrary) -> void:
	_state = state
	_data = state.data
	_art = art


## Escala del lienzo a la pantalla: el lienzo llena el alto de la vista.
func view_scale() -> float:
	return size.y / _data.canvas_size.y if size.y > 0.0 else 1.0


## Ancho visible en px del lienzo.
func view_width() -> float:
	return size.x / view_scale()


## Redibuja la escena de `view_place`. `preview`: el protagonista aún no está
## allí (se mira desde el mapa). `selected`: persona elegida ("" ninguna).
func refresh(view_place: String, preview: bool, selected: String) -> void:
	var actor := _state.active_actor()
	if not _data.has_scene(view_place):
		_show_offstage(actor)
		return
	_offstage.hide()
	_world.show()
	_light.show()
	_grade.show()
	var arrived := view_place != place
	if arrived:
		_build_place(view_place)
	look = actor
	_selected = selected
	var reduced: bool = _state.settings["reduced_motion"]
	var route: Array = _state.sim.s["route"]
	var key := "%d|%d|%s|%s" % [_state.loop_number, route.size(), view_place, preview]
	var moved := key != _action_key
	_action_key = key
	var seconds := 0.0
	if not reduced and not arrived and moved:
		var waited: bool = not route.is_empty() and route[-1].has("command") and route[-1]["command"]["verb"] == "esperar"
		seconds = _data.scene_camera["wait_glide_ms" if waited else "glide_ms"] / 1000.0
	if arrived or moved:
		var station := "" if preview else _state.station_of(actor, view_place)
		if station == "":
			station = _data.scenes[view_place]["entry"]
		focus_x(_data.station_x(view_place, station), seconds)
	_set_light(_state.current_time(), seconds if not arrived else 0.0)
	var overlay_on: bool = _data.looks[look]["overlay"]
	_overlay.visible = overlay_on
	if _overlay_art != null and _overlay_art.material != null:
		(_overlay_art.material as ShaderMaterial).set_shader_parameter("animate", not reduced)
	_rebuild_people(view_place)
	_refresh_hotspots()


## Lleva la cámara a `x` (px del lienzo) en `seconds` (0 = al instante).
func focus_x(x: float, seconds: float) -> void:
	if _camera_tween != null and _camera_tween.is_valid():
		_camera_tween.kill()
	var target := SceneRules.clamp_camera(x, view_width(), _data.canvas_size.x)
	if seconds <= 0.0:
		camera_x = target
		return
	_camera_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_camera_tween.tween_property(self, "camera_x", target, seconds)


## Mirar alrededor: desplaza la cámara `screen_dx` px de pantalla. Gratis.
func pan_by(screen_dx: float) -> void:
	if _camera_tween != null and _camera_tween.is_valid():
		_camera_tween.kill()
	camera_x = SceneRules.clamp_camera(camera_x - screen_dx / view_scale(), view_width(), _data.canvas_size.x)


## Ids de los puntos interactivos que se pueden tocar ahora (para los tests).
func visible_hotspot_ids() -> Array[String]:
	var ids: Array[String] = []
	for hotspot: Dictionary in _hotspots:
		ids.append(hotspot["id"])
	return ids


# --- Construcción -------------------------------------------------------------

func _build_place(new_place: String) -> void:
	for child: Node in _world.get_children():
		_world.remove_child(child)
		child.queue_free()
	_layers.clear()
	_bg.clear()
	place = new_place
	var art := _art.enter_place(new_place)
	for layer: String in ["bg_night", "bg_dusk", "bg_day"]:
		_bg[layer] = _add_layer(art[layer], layer, BG_FACTOR)
	_add_layer(art["mid"], "mid", MID_FACTOR)
	_overlay = _add_layer(art["akba_overlay"], "akba_overlay", MID_FACTOR)
	_overlay_art = _overlay.get_child(0) if _overlay.get_child_count() > 0 else null
	if _overlay_art != null:
		var material := ShaderMaterial.new()
		material.shader = SHIMMER
		_overlay_art.material = material
	_people_layer = _add_layer({"texture": null, "placeholder": false}, "people", MID_FACTOR)
	_hotspot_layer = _add_layer({"texture": null, "placeholder": false}, "hotspots", MID_FACTOR)
	_hotspot_layer.draw.connect(_draw_hotspots)
	_fg = _add_layer(art["fg"], "fg", FG_FACTOR)
	_people.clear()
	_near_station = ""


## Una capa del tamaño del lienzo: textura, provisional o vacía.
func _add_layer(slot: Dictionary, layer: String, factor: float) -> Control:
	var holder := Control.new()
	holder.name = layer
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size = _data.canvas_size
	_world.add_child(holder)
	if slot["texture"] != null:
		var picture := TextureRect.new()
		picture.texture = slot["texture"]
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_SCALE
		picture.size = _data.canvas_size
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(picture)
	elif slot["placeholder"]:
		var placeholder := PlaceholderArt.new()
		holder.add_child(placeholder)
		placeholder.setup(_data, place, layer)
	_layers.append({"node": holder, "factor": factor})
	return holder


func _rebuild_people(view_place: String) -> void:
	for child: Node in _people_layer.get_children():
		_people_layer.remove_child(child)
		child.queue_free()
	_people.clear()
	var by_station: Dictionary = {}
	var others: Array[String] = []
	for id: String in _state.people_at(view_place):
		var station := SceneRules.person_station(_data, view_place, id)
		if not by_station.has(station):
			by_station[station] = []
		by_station[station].append(id)
	for actor: String in _data.protagonist_ids:
		if actor != look and _state.position_of(actor) == view_place:
			others.append(actor)
	var height := _data.npc_height
	var ground: float = _data.scenes[view_place]["ground_y"]
	for station: String in by_station:
		var group: Array = by_station[station]
		for i: int in group.size():
			var x := _data.station_x(view_place, station) + (i - (group.size() - 1) * 0.5) * PERSON_SPREAD
			_people[group[i]] = _add_figure(group[i], Rect2(x - height * PERSON_WIDTH_RATIO * 0.5, ground - height,
					height * PERSON_WIDTH_RATIO, height), group[i] == _selected, 1.0)
	for actor: String in others:
		var station := _state.station_of(actor, view_place)
		if station == "":
			station = _data.scenes[view_place]["entry"]
		var x := _data.station_x(view_place, station) + PERSON_SPREAD * 0.75
		_add_figure(actor, Rect2(x - height * 0.4, ground - height, height * PERSON_WIDTH_RATIO, height), false, OTHER_ALPHA)


func _add_figure(person: String, rect: Rect2, highlighted: bool, alpha: float) -> Rect2:
	var figure: Control = SILHOUETTE_SCENE.instantiate()
	figure.position = rect.position
	figure.size = rect.size
	figure.modulate.a = alpha
	_people_layer.add_child(figure)
	figure.show_person(_data, person, _state.velo_level(person), highlighted)
	return rect


func _refresh_hotspots() -> void:
	_hotspots.clear()
	for hotspot: Dictionary in _data.scenes[place]["hotspots"]:
		if _state.hotspot_available(hotspot["id"]):
			_hotspots.append(hotspot)
	_hotspot_layer.queue_redraw()


func _show_offstage(actor: String) -> void:
	_world.hide()
	_light.hide()
	_grade.hide()
	_hotspots.clear()
	_people.clear()
	place = ""
	_action_key = ""
	var where: String = _state.position_of(actor)
	_offstage.text = _data.text("escena_fuera").format({"nombre": _data.people[actor]["name"],
			"lugar": _data.locations[where]["name"] if _data.locations.has(where) else where})
	_offstage.show()


# --- Cámara y luz -------------------------------------------------------------

func _apply_camera() -> void:
	if _data == null or _layers.is_empty() or place == "":
		return
	var zoom := view_scale()
	var anchor := _data.canvas_size.x * 0.5
	for layer: Dictionary in _layers:
		var node: Control = layer["node"]
		var center: float = anchor + (camera_x - anchor) * layer["factor"]
		node.scale = Vector2(zoom, zoom)
		node.position = Vector2(size.x * 0.5 - center * zoom, 0.0)
	var near := SceneRules.nearest_station(_data, place, camera_x)
	if near != _near_station:
		_near_station = near
		_hotspot_layer.queue_redraw()


## La luz pasa de la hora mostrada a `minute` en `seconds` (0 = al instante).
func _set_light(minute: int, seconds: float) -> void:
	if _light_tween != null and _light_tween.is_valid():
		_light_tween.kill()
	_minute_from = lerpf(_minute_from, _minute_to, _light_blend) if not _grade_to.is_empty() else float(minute)
	_grade_from = SceneRules.grading_at(_data, _minute_from, look)
	_minute_to = float(minute)
	_grade_to = SceneRules.grading_at(_data, _minute_to, look)
	if seconds <= 0.0:
		_light_blend = 1.0
		return
	_light_blend = 0.0
	_light_tween = create_tween()
	_light_tween.tween_property(self, "_light_blend", 1.0, seconds)


func _apply_light() -> void:
	if _grade_to.is_empty() or _bg.is_empty():
		return
	var t := _light_blend
	var weights := SceneRules.bg_weights(_data, lerpf(_minute_from, _minute_to, t))
	var dusk_alpha := weights.x + weights.y
	(_bg["bg_night"] as Control).visible = dusk_alpha < 1.0
	(_bg["bg_dusk"] as Control).modulate.a = dusk_alpha
	(_bg["bg_day"] as Control).modulate.a = weights.x / dusk_alpha if dusk_alpha > 0.0 else 0.0
	var tint: Color = (_grade_from["tint"] as Color).lerp(_grade_to["tint"], t)
	_world.modulate = tint
	_fg.self_modulate = Color(1.0 - FG_SHADE, 1.0 - FG_SHADE, 1.0 - FG_SHADE)
	var light: Color = (_grade_from["light"] as Color).lerp(_grade_to["light"], t)
	light.a = lerpf(_grade_from["light_strength"], _grade_to["light_strength"], t)
	_light.color = light
	var material := _grade.material as ShaderMaterial
	material.set_shader_parameter(&"vignette", lerpf(_grade_from["vignette"], _grade_to["vignette"], t))
	material.set_shader_parameter(&"grain", lerpf(_grade_from["grain"], _grade_to["grain"], t))


# --- Toques -------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if _data == null or place == "":
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressing = true
			_dragging = false
			_press_position = event.position
		elif _pressing:
			_pressing = false
			if not _dragging:
				_tap(event.position)
		accept_event()
	elif event is InputEventMouseMotion and _pressing:
		if not _dragging and absf(event.position.x - _press_position.x) > _data.scene_camera["drag_threshold_px"]:
			_dragging = true
		if _dragging:
			pan_by(event.relative.x)
		accept_event()


## Qué hay bajo un toque: primero los puntos interactivos, luego las personas.
func _tap(screen: Vector2) -> void:
	var zoom := view_scale()
	var point := Vector2((screen.x - size.x * 0.5) / zoom + camera_x, screen.y / zoom)
	var reach := maxf(HINT_RADIUS * 1.6, TOUCH_MIN * 0.5 / zoom)
	for hotspot: Dictionary in _hotspots:
		if point.distance_to(Vector2(hotspot["x"], hotspot["y"])) <= reach:
			hotspot_tapped.emit(hotspot["id"])
			return
	var grow := maxf(0.0, (TOUCH_MIN / zoom - _data.npc_height * PERSON_WIDTH_RATIO) * 0.5)
	for person: String in _people:
		if (_people[person] as Rect2).grow(grow).has_point(point):
			person_tapped.emit(person)
			return


func _draw_hotspots() -> void:
	var font := get_theme_default_font()
	for hotspot: Dictionary in _hotspots:
		var discovered := _state.hotspot_discovered(hotspot["id"])
		if not discovered and hotspot["station"] != _near_station:
			continue
		var center := Vector2(hotspot["x"], hotspot["y"])
		var color: Color = FISSURE_COLOR if hotspot["fissure"] else HINT_COLOR
		_hotspot_layer.draw_arc(center, HINT_RADIUS, 0.0, TAU, 48, Color(color, 0.35), 18.0, true)
		_hotspot_layer.draw_arc(center, HINT_RADIUS, 0.0, TAU, 48, color, 6.0, true)
		_hotspot_layer.draw_circle(center, 12.0, color)
		if discovered:
			var text: String = hotspot["label"]
			var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE).x
			_hotspot_layer.draw_string_outline(font, center + Vector2(-width * 0.5, -HINT_RADIUS - 24), text,
					HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, 10, Color(0, 0, 0, 0.7))
			_hotspot_layer.draw_string(font, center + Vector2(-width * 0.5, -HINT_RADIUS - 24), text,
					HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, color)
