extends Control
## Arte provisional de una capa de un lugar mientras no llega el de verdad:
## formas planas en la paleta del juego (cielo, tejados, puestos, la torre del
## reloj...), con una etiqueta discreta «PROVISIONAL · <ranura>». Las formas se
## calculan una vez al prepararla (con semilla fija por lugar y capa) y solo se
## dibujan cuando hace falta; nada se crea por fotograma.
##
## Se dibuja en coordenadas del lienzo de la escena (p. ej. 2880x1920); la
## escena la escala.

const GameData := preload("res://scripts/game_data.gd")

const WALLS: PackedColorArray = [Color("6b5a9a"), Color("8a6fb3"), Color("5a4c86"), Color("7d5f9e")]
const ROOF := Color("3a2f5e")
const WINDOW := Color("f2c66b")
const ACCENT := Color("e0a23a")
const STONE := Color("4b4566")
const SHADOW := Color("1b1530")
const CRACK := Color("5affc8")
const CRACK_EDGE := Color("ff5aa8")
const LABEL_SIZE: int = 44

## Cada forma: {kind: "poly"|"circle"|"line", points, color, radius, width}.
var _shapes: Array[Dictionary] = []
var _sky_top: Color = Color.BLACK
var _sky_bottom: Color = Color.BLACK
var _ground_y: float = 0.0
var _opaque: bool = false
var _label: String = ""
var _label_position: Vector2 = Vector2.ZERO


func setup(data: GameData, place: String, layer: String) -> void:
	custom_minimum_size = data.canvas_size
	size = data.canvas_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shapes.clear()
	_ground_y = data.scenes[place]["ground_y"]
	_opaque = layer.begins_with("bg_")
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(place + "/" + layer)
	match layer:
		"bg_day", "bg_dusk", "bg_night":
			_build_background(data, layer, rng)
		"mid":
			_build_mid(data, place, rng)
		"fg":
			_build_foreground(data, rng)
		"akba_overlay":
			_build_cracks(data, place, rng)
	var slot := "%s_%s" % [place, layer]
	_label = "%s · %s" % [data.text("arte_provisional"), slot]
	var row: int = ["bg_day", "bg_dusk", "bg_night", "mid", "fg", "akba_overlay"].find(layer)
	_label_position = Vector2(60 + row * 40, 90 + row * 56)
	queue_redraw()


func _draw() -> void:
	if _opaque:
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]),
				PackedColorArray([_sky_top, _sky_top, _sky_bottom, _sky_bottom]))
	for shape: Dictionary in _shapes:
		match shape["kind"]:
			"poly":
				draw_colored_polygon(shape["points"], shape["color"])
			"circle":
				draw_circle(shape["points"][0], shape["radius"], shape["color"])
			"line":
				draw_polyline(shape["points"], shape["color"], shape["width"], true)
	draw_string(get_theme_default_font(), _label_position, _label, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE,
			Color(1, 1, 1, 0.35))


# --- Capas ----------------------------------------------------------------

## Cielo, ciudad lejana y suelo. Colores de la paleta de settings.json.
func _build_background(data: GameData, layer: String, rng: RandomNumberGenerator) -> void:
	var key: Dictionary = data.palette[{"bg_day": 1, "bg_dusk": 2, "bg_night": data.palette.size() - 1}[layer]]
	_sky_top = key["sky"]
	_sky_bottom = key["horizon"]
	var night: bool = layer == "bg_night"
	if night:
		for i: int in 120:
			_circle(Vector2(rng.randf() * size.x, rng.randf() * _ground_y * 0.55), rng.randf_range(2.0, 5.0), Color(1, 1, 0.92, 0.85))
		_circle(Vector2(size.x * 0.22, 260), 90, Color("f5edc8"))
	elif layer == "bg_day":
		_circle(Vector2(size.x * 0.3, 240), 110, Color(1, 0.97, 0.85, 0.9))
	var far: Color = key["horizon"].darkened(0.45 if not night else 0.2)
	var x := -40.0
	while x < size.x:
		var width := rng.randf_range(160, 320)
		var top := _ground_y - rng.randf_range(420, 760)
		_rect(Rect2(x, top, width, _ground_y - top), far)
		_poly([Vector2(x - 10, top), Vector2(x + width * 0.5, top - rng.randf_range(80, 180)), Vector2(x + width + 10, top)], far.darkened(0.2))
		if rng.randf() < 0.6:
			_rect(Rect2(x + width * 0.35, top + 90, 40, 56), WINDOW if night else far.lightened(0.2))
		x += width + rng.randf_range(-20, 40)
	var ground: Color = key["card"].darkened(0.55) if not night else Color("26244a")
	_rect(Rect2(0, _ground_y - 60, size.x, size.y - _ground_y + 60), ground)
	for row: int in 6:
		var y := _ground_y + row * 60.0
		_line([Vector2(0, y), Vector2(size.x, y)], ground.darkened(0.25), 4.0)


## Edificios cercanos propios de cada lugar (recortados, con transparencia).
func _build_mid(data: GameData, place: String, rng: RandomNumberGenerator) -> void:
	var ground := _ground_y
	match place:
		"relojeria":
			# Patio con pozo a la izquierda, la relojería en el centro y casas a la derecha.
			_rect(Rect2(220, ground - 380, 820, 380), STONE)
			_rect(Rect2(500, ground - 260, 180, 200), STONE.darkened(0.3))
			_poly([Vector2(470, ground - 260), Vector2(590, ground - 360), Vector2(710, ground - 260)], ROOF)
			_house(1060, 840, ground, 1150, WALLS[0], rng)
			_circle(Vector2(1480, ground - 520), 230, Color("cfd8f0"))
			_circle(Vector2(1480, ground - 520), 200, Color("9fb0d8"))
			_circle(Vector2(1480, ground - 1000), 110, Color("efe6cf"))
			_line([Vector2(1480, ground - 1000), Vector2(1480, ground - 1070)], SHADOW, 10.0)
			_line([Vector2(1480, ground - 1000), Vector2(1530, ground - 1000)], SHADOW, 10.0)
			_house(2000, 420, ground, 820, WALLS[1], rng)
			_house(2420, 460, ground, 980, WALLS[3], rng)
		"mercado":
			for i: int in 4:
				var stall_x: float = [220, 840, 1460, 2060][i]
				_stall(stall_x, ground, WALLS[i % WALLS.size()], [ACCENT, Color("c75b8f"), Color("4fb3a5"), Color("e07a3a")][i])
			_poly([Vector2(870, ground - 330), Vector2(1230, ground - 330), Vector2(1190, ground - 150), Vector2(910, ground - 150)], Color("8a5a3a"))
			_circle(Vector2(940, ground - 120), 60, SHADOW)
			_circle(Vector2(1160, ground - 120), 60, SHADOW)
		"plaza":
			_house(120, 520, ground, 900, WALLS[2], rng)
			_poly([Vector2(160, ground), Vector2(560, ground), Vector2(560, ground - 260)], STONE)
			_rect(Rect2(1090, ground - 1500, 180, 1500), WALLS[0].darkened(0.2))
			_poly([Vector2(1060, ground - 1500), Vector2(1180, ground - 1700), Vector2(1300, ground - 1500)], ROOF)
			_circle(Vector2(1180, ground - 1300), 80, Color("efe6cf"))
			_house(1900, 460, ground, 860, WALLS[1], rng)
			_house(2360, 520, ground, 1000, WALLS[3], rng)
			_rect(Rect2(2300, ground - 360, 560, 30), ACCENT)


## Marco oscuro y bajo en primer plano: macetas y matas en las esquinas de
## abajo, sin nada que cruce la escena.
func _build_foreground(_data: GameData, rng: RandomNumberGenerator) -> void:
	for side: int in 2:
		var left := 0.0 if side == 0 else size.x - 620.0
		# Un seto bajo con el borde de arriba irregular.
		var hedge: Array[Vector2] = [Vector2(left, size.y)]
		for i: int in 13:
			hedge.append(Vector2(left + i * 620.0 / 12.0, size.y - rng.randf_range(150, 210)))
		hedge.append(Vector2(left + 620.0, size.y))
		_poly(hedge, SHADOW)
		var pot_x := left + (80.0 if side == 0 else 400.0)
		_poly([Vector2(pot_x, size.y), Vector2(pot_x + 140, size.y), Vector2(pot_x + 120, size.y - 260), Vector2(pot_x + 20, size.y - 260)], SHADOW.lightened(0.05))


## Grietas que brillan (solo se suman a la escena con la mirada de Akba).
func _build_cracks(data: GameData, place: String, rng: RandomNumberGenerator) -> void:
	var origins: Array[Vector2] = []
	for hotspot: Dictionary in data.scenes[place]["hotspots"]:
		if hotspot["fissure"]:
			origins.append(Vector2(hotspot["x"], hotspot["y"]))
	if origins.is_empty():
		origins.append(Vector2(size.x * 0.5, _ground_y - 100))
	for origin: Vector2 in origins:
		for branch: int in 6:
			var points := PackedVector2Array([origin])
			var direction := Vector2.RIGHT.rotated(rng.randf() * TAU)
			var point := origin
			for step: int in 7:
				direction = direction.rotated(rng.randf_range(-0.6, 0.6))
				point += direction * rng.randf_range(40, 90)
				points.append(point)
			_shapes.append({"kind": "line", "points": points, "color": CRACK if branch % 2 == 0 else CRACK_EDGE, "width": 9.0})
	for i: int in 30:
		_circle(Vector2(rng.randf() * size.x, rng.randf() * _ground_y), rng.randf_range(4, 12), Color(CRACK, 0.6))


# --- Piezas ---------------------------------------------------------------

func _house(x: float, width: float, ground: float, height: float, wall: Color, rng: RandomNumberGenerator) -> void:
	_rect(Rect2(x, ground - height, width, height), wall)
	_poly([Vector2(x - 30, ground - height), Vector2(x + width * 0.5, ground - height - rng.randf_range(160, 260)), Vector2(x + width + 30, ground - height)], ROOF)
	var rows := int(height / 260.0)
	for row: int in rows:
		for column: int in 2:
			_rect(Rect2(x + width * (0.2 + column * 0.45), ground - height + 120 + row * 240, width * 0.18, 120), WINDOW.darkened(0.15))
	_rect(Rect2(x + width * 0.4, ground - 240, width * 0.2, 240), ROOF)


func _stall(x: float, ground: float, wall: Color, awning: Color) -> void:
	_rect(Rect2(x, ground - 300, 520, 300), wall)
	for stripe: int in 6:
		var stripe_x := x - 40 + stripe * 100.0
		_poly([Vector2(stripe_x, ground - 560), Vector2(stripe_x + 100, ground - 560), Vector2(stripe_x + 100, ground - 440), Vector2(stripe_x, ground - 440)],
				awning if stripe % 2 == 0 else awning.lightened(0.45))
	_line([Vector2(x + 10, ground - 440), Vector2(x + 10, ground - 300)], SHADOW, 12.0)
	_line([Vector2(x + 510, ground - 440), Vector2(x + 510, ground - 300)], SHADOW, 12.0)


func _rect(rect: Rect2, color: Color) -> void:
	_poly([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)], color)


func _poly(points: Array[Vector2], color: Color) -> void:
	_shapes.append({"kind": "poly", "points": PackedVector2Array(points), "color": color})


func _circle(center: Vector2, radius: float, color: Color) -> void:
	_shapes.append({"kind": "circle", "points": PackedVector2Array([center]), "radius": radius, "color": color})


func _line(points: Array[Vector2], color: Color, width: float) -> void:
	_shapes.append({"kind": "line", "points": PackedVector2Array(points), "color": color, "width": width})
