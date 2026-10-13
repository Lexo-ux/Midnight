extends Texture2D
## Icono dibujado en código para las conversaciones: el tipo de cada carta y los
## muros y puertas. Se distinguen por la FORMA (no solo por el color):
## - escuchar: ondas; verdad: llave; silencio: bocadillo con puntos;
##   presion: yunque que aprieta; revelar: estallido; conocimiento: libro;
##   recordar: flecha en círculo.
## - wall: ladrillos; wall_broken: ladrillos partidos; door: arco cerrado;
##   door_open: arco abierto con ✓; unknown: aro discontinuo con «?».
## Es una textura, así que sirve de icono de un Button o en un TextureRect.

const UiStyle := preload("res://scripts/ui_style.gd")
const SIZE: float = 64.0
const KINDS: PackedStringArray = ["escuchar", "verdad", "silencio", "presion", "revelar", "conocimiento", "recordar",
		"wall", "wall_broken", "door", "door_open", "unknown"]

var kind: String = "unknown"
var pixels: float = SIZE


static func make(icon_kind: String, size_px: float = SIZE) -> Texture2D:
	var icon: Texture2D = load("res://scripts/conv_icon.gd").new()
	icon.set("kind", icon_kind if KINDS.has(icon_kind) else "unknown")
	icon.set("pixels", size_px)
	return icon


func _get_width() -> int:
	return int(pixels)


func _get_height() -> int:
	return int(pixels)


func _has_alpha() -> bool:
	return true


func _draw(to_canvas_item: RID, pos: Vector2, _modulate: Color, _transpose: bool) -> void:
	_paint(to_canvas_item, Rect2(pos, Vector2(pixels, pixels)))


func _draw_rect(to_canvas_item: RID, rect: Rect2, _tile: bool, _modulate: Color, _transpose: bool) -> void:
	_paint(to_canvas_item, rect)


func _draw_rect_region(to_canvas_item: RID, rect: Rect2, _src_rect: Rect2, _modulate: Color, _transpose: bool, _clip_uv: bool) -> void:
	_paint(to_canvas_item, rect)


# --- Dibujo (en un lienzo de 64×64 que se escala al rectángulo) -------------------

var _item: RID
var _origin: Vector2
var _scale: float = 1.0


func _paint(item: RID, rect: Rect2) -> void:
	_item = item
	var side := minf(rect.size.x, rect.size.y)
	_scale = side / SIZE
	_origin = rect.position + (rect.size - Vector2(side, side)) * 0.5
	match kind:
		"escuchar":
			_circle(Vector2(18, 32), 8, UiStyle.NEON_CYAN)
			for i: int in 3:
				_arc(Vector2(18, 32), 16.0 + i * 11.0, -0.9, 0.9, UiStyle.NEON_CYAN)
		"verdad":
			_ring(Vector2(20, 24), 12, UiStyle.NEON_YELLOW)
			_bar(Vector2(30, 32), Vector2(56, 52), UiStyle.NEON_YELLOW)
			_bar(Vector2(46, 44), Vector2(40, 52), UiStyle.NEON_YELLOW)
			_bar(Vector2(52, 50), Vector2(46, 58), UiStyle.NEON_YELLOW)
		"silencio":
			_poly([Vector2(8, 12), Vector2(56, 12), Vector2(56, 44), Vector2(30, 44), Vector2(18, 56), Vector2(20, 44), Vector2(8, 44)], UiStyle.PAPER)
			for i: int in 3:
				_circle(Vector2(20 + i * 12, 28), 4, UiStyle.INK, false)
		"presion":
			_poly([Vector2(10, 34), Vector2(54, 34), Vector2(46, 46), Vector2(18, 46)], UiStyle.NEON_PINK)
			_poly([Vector2(24, 46), Vector2(40, 46), Vector2(44, 58), Vector2(20, 58)], UiStyle.NEON_PINK)
			_poly([Vector2(26, 4), Vector2(38, 4), Vector2(38, 16), Vector2(46, 16), Vector2(32, 30), Vector2(18, 16), Vector2(26, 16)], UiStyle.NEON_PINK)
		"revelar":
			var star: Array[Vector2] = []
			for i: int in 16:
				star.append(Vector2(32, 32) + Vector2.UP.rotated(TAU * i / 16.0) * (28.0 if i % 2 == 0 else 13.0))
			_poly(star, UiStyle.NEON_GREEN)
			_circle(Vector2(32, 32), 6, UiStyle.INK, false)
		"conocimiento":
			_poly([Vector2(32, 16), Vector2(56, 10), Vector2(56, 50), Vector2(32, 56)], UiStyle.PAPER)
			_poly([Vector2(32, 16), Vector2(8, 10), Vector2(8, 50), Vector2(32, 56)], UiStyle.PAPER)
			for i: int in 3:
				_line(Vector2(38, 22 + i * 9), Vector2(50, 19 + i * 9), 3.0)
				_line(Vector2(14, 19 + i * 9), Vector2(26, 22 + i * 9), 3.0)
		"recordar":
			_arc(Vector2(32, 32), 20, -2.6, 2.0, UiStyle.NEON_YELLOW)
			_poly([Vector2(6, 22), Vector2(22, 18), Vector2(16, 34)], UiStyle.NEON_YELLOW)
		"wall", "wall_broken":
			_poly([Vector2(6, 14), Vector2(58, 14), Vector2(58, 54), Vector2(6, 54)], Color("c8642e"))
			_line(Vector2(6, 27), Vector2(58, 27), 3.0)
			_line(Vector2(6, 41), Vector2(58, 41), 3.0)
			for x: float in [24.0, 44.0]:
				_line(Vector2(x, 14), Vector2(x, 27), 3.0)
				_line(Vector2(x - 10, 27), Vector2(x - 10, 41), 3.0)
				_line(Vector2(x, 41), Vector2(x, 54), 3.0)
			if kind == "wall_broken":
				_polyline([Vector2(28, 6), Vector2(36, 24), Vector2(26, 36), Vector2(38, 60)], UiStyle.PAPER, 7.0)
				_polyline([Vector2(28, 6), Vector2(36, 24), Vector2(26, 36), Vector2(38, 60)], UiStyle.INK, 3.0)
		"door", "door_open":
			var arch: Array[Vector2] = [Vector2(14, 58), Vector2(14, 26)]
			for i: int in 9:
				arch.append(Vector2(32, 26) + Vector2.LEFT.rotated(PI * i / 8.0) * 18.0)
			arch.append(Vector2(50, 58))
			_poly(arch, Color("8a5a3a") if kind == "door" else UiStyle.INK)
			if kind == "door":
				_circle(Vector2(42, 42), 3, UiStyle.NEON_YELLOW, false)
			else:
				_circle(Vector2(46, 46), 14, UiStyle.NEON_GREEN)
				_polyline([Vector2(39, 46), Vector2(45, 52), Vector2(54, 40)], UiStyle.INK, 4.0)
		_:
			for i: int in 12:
				if i % 2 == 0:
					_arc(Vector2(32, 32), 24, TAU * i / 12.0, TAU * (i + 1) / 12.0, UiStyle.INK, 5.0, false)
			var font := ThemeDB.fallback_font
			var font_size := int(36 * _scale)
			var width := font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			font.draw_string(_item, _p(Vector2(32, 45)) - Vector2(width * 0.5, 0), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, UiStyle.INK)


func _p(v: Vector2) -> Vector2:
	return _origin + v * _scale


func _line(a: Vector2, b: Vector2, width: float, color: Color = UiStyle.INK) -> void:
	RenderingServer.canvas_item_add_line(_item, _p(a), _p(b), color, width * _scale, true)


## Trazo grueso con contorno (dos pasadas).
func _bar(a: Vector2, b: Vector2, color: Color) -> void:
	_line(a, b, 12.0)
	_line(a, b, 6.0, color)


func _polyline(points: Array, color: Color, width: float) -> void:
	var scaled := PackedVector2Array()
	for p: Vector2 in points:
		scaled.append(_p(p))
	RenderingServer.canvas_item_add_polyline(_item, scaled, PackedColorArray([color]), width * _scale, true)


func _poly(points: Array, fill: Color) -> void:
	var scaled := PackedVector2Array()
	for p: Vector2 in points:
		scaled.append(_p(p))
	RenderingServer.canvas_item_add_polygon(_item, scaled, PackedColorArray([fill]))
	scaled.append(scaled[0])
	RenderingServer.canvas_item_add_polyline(_item, scaled, PackedColorArray([UiStyle.INK]), 4.0 * _scale, true)


func _circle(c: Vector2, r: float, fill: Color, outline: bool = true) -> void:
	if outline:
		RenderingServer.canvas_item_add_circle(_item, _p(c), (r + 2.5) * _scale, UiStyle.INK)
	RenderingServer.canvas_item_add_circle(_item, _p(c), r * _scale, fill)


func _ring(c: Vector2, r: float, color: Color) -> void:
	_arc(c, r, 0.0, TAU, color)


## Arco de rotulador: contorno negro y relleno de color.
func _arc(c: Vector2, r: float, from: float, to: float, color: Color, width: float = 6.0, outline: bool = true) -> void:
	var points := PackedVector2Array()
	for i: int in 17:
		points.append(_p(c + Vector2.RIGHT.rotated(lerpf(from, to, i / 16.0)) * r))
	if outline:
		RenderingServer.canvas_item_add_polyline(_item, points, PackedColorArray([UiStyle.INK]), (width + 5.0) * _scale, true)
	RenderingServer.canvas_item_add_polyline(_item, points, PackedColorArray([color]), width * _scale, true)
