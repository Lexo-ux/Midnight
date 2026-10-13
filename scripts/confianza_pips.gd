extends Control
## La Confianza como puntos: llenos los que hay, solo el borde los que faltan
## (se distinguen por la forma, no solo por el color).

const FILL := Color("8b5a2b")
const EMPTY := Color(0.17, 0.14, 0.1, 0.55)
const GAP: float = 14.0

var value: int = 0
var maximum: int = 5


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func set_value(new_value: int, new_maximum: int) -> void:
	value = new_value
	maximum = maxi(new_maximum, 1)
	queue_redraw()


func _draw() -> void:
	var radius := minf(size.y * 0.5, (size.x - GAP * (maximum - 1)) / (2.0 * maximum)) - 2.0
	if radius <= 0.0:
		return
	for i: int in maximum:
		var center := Vector2(radius + 2.0 + i * (2.0 * radius + GAP), size.y * 0.5)
		if i < value:
			draw_circle(center, radius, FILL)
		else:
			draw_arc(center, radius - 2.0, 0.0, TAU, 32, EMPTY, 4.0, true)
