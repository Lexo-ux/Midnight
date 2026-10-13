extends Control
## El relevo entre Sazil y Akba: una franja inclinada de rotulador (relleno del
## color de quien entra y bordes negros) cruza la pantalla desde su lado
## (Sazil por la izquierda, Akba por la derecha) mientras cambia la mirada de la
## escena. Dura ≤ 250 ms; con movimiento reducido no se ve. Nunca recibe toques.

const UiStyle := preload("res://scripts/ui_style.gd")
const WIDTH_RATIO: float = 0.4
const SKEW_RATIO: float = 0.12
const FILL_ALPHA: float = 0.5

var _color: Color = Color.WHITE
var _from_left: bool = true
var _tween: Tween
## 0 = antes de entrar, 1 = ya salió por el otro lado.
var progress: float = 0.0:
	set(value):
		progress = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func play(from_left: bool, color: Color, seconds: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_from_left = from_left
	_color = Color(color, FILL_ALPHA)
	progress = 0.0
	show()
	_tween = create_tween()
	_tween.tween_property(self, "progress", 1.0, minf(seconds, UiStyle.MOTION_MAX_SECONDS))
	_tween.tween_callback(hide)


func stop() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	hide()


func _draw() -> void:
	var width := size.x * WIDTH_RATIO
	var skew := size.x * SKEW_RATIO
	var travel := size.x + width + skew * 2.0
	var x := -width - skew + travel * progress
	if not _from_left:
		x = size.x + skew - travel * progress
	var band := PackedVector2Array([Vector2(x + skew, 0), Vector2(x + width + skew, 0), Vector2(x + width - skew, size.y), Vector2(x - skew, size.y)])
	draw_colored_polygon(band, _color)
	draw_line(band[0], band[3], UiStyle.INK, UiStyle.OUTLINE * 2.0, true)
	draw_line(band[1], band[2], UiStyle.INK, UiStyle.OUTLINE * 2.0, true)
