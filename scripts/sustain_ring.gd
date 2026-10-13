extends Control
## Lo que se ve al sostener: la fisura (una grieta luminosa del Umbral con
## contorno de rotulador, que se va cerrando y tornasola del verde al carmesí)
## y, si el quiebre tiene tiempo, un anillo de marcas que se van llenando. El
## avance se lee por la forma (marcas largas y llenas o cortas y vacías, y el
## arco), no solo por el color. En pausa todo se apaga y sale el símbolo de
## pausa encima. Sin asignaciones por fotograma: la grieta se calcula al cambiar
## de tamaño.

const UiStyle := preload("res://scripts/ui_style.gd")
const PAUSE_ICON := preload("res://assets/ui/icons/pause.svg")
const CRACK_CORE := Color(1, 1, 1, 0.9)
const RING_EMPTY := Color(0.79, 0.75, 0.92, 0.45)
const TICKS: int = 24
const PAUSED_ALPHA: float = 0.35
## Puntos de la grieta en fracciones del control (fijos: siempre la misma grieta).
const CRACK_SHAPE: PackedVector2Array = [
	Vector2(0.52, 0.0), Vector2(0.47, 0.12), Vector2(0.55, 0.24), Vector2(0.46, 0.37), Vector2(0.53, 0.5),
	Vector2(0.44, 0.63), Vector2(0.54, 0.76), Vector2(0.48, 0.88), Vector2(0.51, 1.0)]

var progress: float = 0.0
var timed: bool = true
var paused: bool = false
## 0-1: cuánto se abre la grieta (se cierra al sostener).
var opening: float = 1.0
## 0-1: brillo de la grieta (lo mueve breakpoint_view.gd; 0 con movimiento reducido).
var shimmer: float = 0.0

var _crack: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_rebuild)
	_rebuild()


func set_state(new_progress: float, is_timed: bool, is_paused: bool = false) -> void:
	if is_equal_approx(new_progress, progress) and is_timed == timed and is_paused == paused:
		return
	progress = new_progress
	timed = is_timed
	paused = is_paused
	opening = 1.0 - 0.7 * progress
	queue_redraw()


func set_shimmer(value: float) -> void:
	if not is_equal_approx(value, shimmer):
		shimmer = value
		queue_redraw()


func _rebuild() -> void:
	_crack.resize(CRACK_SHAPE.size())
	for i: int in CRACK_SHAPE.size():
		_crack[i] = CRACK_SHAPE[i] * size
	queue_redraw()


func _draw() -> void:
	var alpha := PAUSED_ALPHA if paused else 1.0
	var width := maxf(size.x * 0.035 * opening, 3.0)
	var glow := UiStyle.UMBRAL.lerp(UiStyle.UMBRAL_EDGE, shimmer * 0.5)
	draw_polyline(_crack, Color(glow, 0.3 * alpha), width * 3.0, true)
	draw_polyline(_crack, Color(UiStyle.INK, alpha), width + UiStyle.OUTLINE * 2.0, true)
	draw_polyline(_crack, Color(glow, alpha), width, true)
	draw_polyline(_crack, Color(CRACK_CORE, alpha), maxf(width * 0.3, 1.5), true)
	if timed:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.42
		draw_arc(center, radius, 0.0, TAU, 96, Color(RING_EMPTY, alpha), 6.0, true)
		if progress > 0.0:
			var arc_to := -PI * 0.5 + TAU * progress
			draw_arc(center, radius, -PI * 0.5, arc_to, 96, Color(UiStyle.INK, alpha), 14.0 + UiStyle.OUTLINE * 2.0, true)
			draw_arc(center, radius, -PI * 0.5, arc_to, 96, Color(UiStyle.NEON_YELLOW, alpha), 14.0, true)
		var filled := int(floor(progress * TICKS))
		for i: int in TICKS:
			var angle := -PI * 0.5 + TAU * i / TICKS
			var direction := Vector2(cos(angle), sin(angle))
			var inner := center + direction * (radius + 16.0)
			var outer := center + direction * (radius + (42.0 if i < filled else 26.0))
			if i < filled:
				draw_line(inner, outer, Color(UiStyle.INK, alpha), 8.0 + UiStyle.OUTLINE, true)
			draw_line(inner, outer, Color(UiStyle.NEON_YELLOW if i < filled else RING_EMPTY, alpha), 8.0 if i < filled else 4.0, true)
	if paused:
		var icon_size := Vector2(PAUSE_ICON.get_width(), PAUSE_ICON.get_height())
		draw_texture(PAUSE_ICON, (size - icon_size) * 0.5)
