extends Control
## Icono dibujado de un protagonista: sol para Sazil, luna para Akba. Así se
## distinguen por forma y no solo por color. Solo se redibuja al cambiar.

const RAYS: int = 8

var icon: String = "sol"
var color: Color = Color.WHITE
## Color del fondo, para recortar la luna.
var cutout: Color = Color.BLACK


func set_icon(icon_name: String, icon_color: Color, background: Color) -> void:
	icon = icon_name
	color = icon_color
	cutout = background
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius: float = minf(size.x, size.y) * 0.5
	if icon == "sol":
		draw_circle(center, radius * 0.45, color)
		for i: int in RAYS:
			var direction := Vector2.RIGHT.rotated(TAU * i / RAYS)
			draw_line(center + direction * radius * 0.6, center + direction * radius * 0.92, color, maxf(radius * 0.12, 2.0), true)
	else:
		draw_circle(center, radius * 0.8, color)
		draw_circle(center + Vector2(radius * 0.38, -radius * 0.22), radius * 0.66, cutout)
