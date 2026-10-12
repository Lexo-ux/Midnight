extends Control
## Fondo del diorama: degradado de cielo a horizonte según la hora del mundo,
## con estrellas de noche. Los colores salen de settings.json (palette). Las
## estrellas no parpadean, así que sirven también con movimiento reducido.

const STAR_COUNT: int = 90
const STAR_SEED: int = 52

var _sky: Color = Color.BLACK
var _horizon: Color = Color.BLACK
var _stars: float = 0.0
var _star_points: PackedVector2Array = []
var _star_sizes: PackedFloat32Array = []


func _ready() -> void:
	# Posiciones fijas: misma semilla siempre (solo es decoración de la UI).
	var rng := RandomNumberGenerator.new()
	rng.seed = STAR_SEED
	for i: int in STAR_COUNT:
		_star_points.append(Vector2(rng.randf(), rng.randf() * 0.7))
		_star_sizes.append(rng.randf_range(1.5, 3.5))


func set_colors(sky: Color, horizon: Color, stars: float) -> void:
	if sky == _sky and horizon == _horizon and is_equal_approx(stars, _stars):
		return
	_sky = sky
	_horizon = horizon
	_stars = stars
	queue_redraw()


func _draw() -> void:
	var points := PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)])
	draw_polygon(points, PackedColorArray([_sky, _sky, _horizon, _horizon]))
	if _stars <= 0.0:
		return
	var star_color := Color(1, 1, 0.95, _stars)
	for i: int in _star_points.size():
		draw_circle(_star_points[i] * size, _star_sizes[i], star_color)
