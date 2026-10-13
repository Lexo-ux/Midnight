extends Control
## Lo que se ve al sostener: la fisura (una grieta luminosa, dibujada) y, si el
## quiebre tiene tiempo, un anillo de marcas que se van llenando. El avance se
## lee por la forma (marcas llenas o vacías y el arco), no solo por el color.
## Sin asignaciones por fotograma: la grieta se calcula al cambiar de tamaño.

const CRACK := Color("7dffb0")
const CRACK_CORE := Color(1, 1, 1, 0.9)
const RING_EMPTY := Color(0.7, 0.71, 0.86, 0.35)
const RING_FULL := Color(1, 0.93, 0.78, 1)
const TICKS: int = 24
## Puntos de la grieta en fracciones del control (fijos: siempre la misma grieta).
const CRACK_SHAPE: PackedVector2Array = [
	Vector2(0.52, 0.0), Vector2(0.47, 0.12), Vector2(0.55, 0.24), Vector2(0.46, 0.37), Vector2(0.53, 0.5),
	Vector2(0.44, 0.63), Vector2(0.54, 0.76), Vector2(0.48, 0.88), Vector2(0.51, 1.0)]

var progress: float = 0.0
var timed: bool = true
## 0-1: cuánto se abre la grieta (se cierra al sostener).
var opening: float = 1.0

var _crack: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_rebuild)
	_rebuild()


func set_state(new_progress: float, is_timed: bool) -> void:
	if is_equal_approx(new_progress, progress) and is_timed == timed:
		return
	progress = new_progress
	timed = is_timed
	opening = 1.0 - 0.7 * progress
	queue_redraw()


func _rebuild() -> void:
	_crack.resize(CRACK_SHAPE.size())
	for i: int in CRACK_SHAPE.size():
		_crack[i] = CRACK_SHAPE[i] * size
	queue_redraw()


func _draw() -> void:
	var width := maxf(size.x * 0.035 * opening, 3.0)
	draw_polyline(_crack, Color(CRACK, 0.35), width * 3.0, true)
	draw_polyline(_crack, CRACK, width, true)
	draw_polyline(_crack, CRACK_CORE, maxf(width * 0.3, 1.5), true)
	if not timed:
		return
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.42
	draw_arc(center, radius, 0.0, TAU, 96, RING_EMPTY, 6.0, true)
	if progress > 0.0:
		draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * progress, 96, RING_FULL, 14.0, true)
	var filled := int(floor(progress * TICKS))
	for i: int in TICKS:
		var angle := -PI * 0.5 + TAU * i / TICKS
		var direction := Vector2(cos(angle), sin(angle))
		var inner := center + direction * (radius + 16.0)
		var outer := center + direction * (radius + (40.0 if i < filled else 26.0))
		draw_line(inner, outer, RING_FULL if i < filled else RING_EMPTY, 8.0 if i < filled else 4.0, true)
