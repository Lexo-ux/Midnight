extends Control
## Primera persona: solo se ven las manos del protagonista controlado, abajo y
## en el centro. El estado (idle, hold_letter, point, light, reach, wait) sale de
## su última acción (grip: al sostener en un quiebre) (data/scenes.json, hands.by_verb).
## La imagen es la de la ranura `hands_<actor>_<estado>` (4:3): la de verdad o,
## mientras no llegue, su provisional generado (assets/art_provisional/). Si no
## hay ninguna, manos planas dibujadas aquí: Sazil, cartera (correa de la bolsa,
## cartas); Akba, vigilante (mangas del abrigo y el colgante poliédrico que brilla).
## Nunca recibe toques: no tapa los botones de acción.

const ArtLibrary := preload("res://scripts/art_library.gd")
const GameData := preload("res://scripts/game_data.gd")

## Espacio de diseño de las manos (el de la ranura, 4:3; se escala al control).
const DESIGN := Vector2(1080, 810)
## Las manos dibujadas se pensaron en 1080×720: bajan para apoyarse en el borde.
const DRAWN_OFFSET: float = 90.0
const SKIN := {"sazil": Color("f2c9b0"), "akba": Color("c9d9cc")}
const SLEEVE := {"sazil": Color("f4f1f8"), "akba": Color("1f2a33")}
const OUTLINE := Color("1a1420")
const STRAP := Color("7a4b23")
const PAPER := Color("f7f0e2")
const SEAL := Color("b5543f")
const GLOW := Color("7dffb0")
const DROP: float = 90.0

var _art: ArtLibrary
var _actor: String = "sazil"
var _state: String = "idle"
var _texture_rect: TextureRect
var _tween: Tween
## 0 = manos en su sitio, 1 = bajadas y transparentes (a mitad de un cambio).
var _dip: float = 0.0:
	set(value):
		_dip = value
		if _texture_rect != null:
			_texture_rect.position.y = value * DROP * _scale()
		modulate.a = 1.0 - value * 0.8
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texture_rect = TextureRect.new()
	_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_texture_rect)
	resized.connect(queue_redraw)


func bind(art: ArtLibrary) -> void:
	_art = art


## Cambia a las manos de `actor` en `state`. `seconds` 0 = sin transición.
func show_hands(actor: String, state: String, seconds: float) -> void:
	if actor == _actor and state == _state and _texture_rect.texture == _texture_for(actor, state):
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if seconds <= 0.0:
		_apply(actor, state)
		_dip = 0.0
		return
	_tween = create_tween()
	_tween.tween_property(self, "_dip", 1.0, seconds * 0.5)
	_tween.tween_callback(_apply.bind(actor, state))
	_tween.tween_property(self, "_dip", 0.0, seconds * 0.5)


func _apply(actor: String, state: String) -> void:
	_actor = actor
	_state = state
	_texture_rect.texture = _texture_for(actor, state)
	queue_redraw()


func _texture_for(actor: String, state: String) -> Texture2D:
	if _art == null:
		return null
	return _art.small_texture(ArtLibrary.hands_slot(actor, state))


func _scale() -> float:
	return minf(size.x / DESIGN.x, size.y / DESIGN.y)


# --- Manos provisionales ------------------------------------------------------

func _draw() -> void:
	if _texture_rect.texture != null:
		return
	var k := _scale()
	draw_set_transform(Vector2((size.x - DESIGN.x * k) * 0.5, size.y - DESIGN.y * k + (DRAWN_OFFSET + _dip * DROP) * k), 0.0, Vector2(k, k))
	var akba: bool = _actor == "akba"
	if not akba:
		# La correa de la bolsa de correo cruza por la izquierda.
		draw_line(Vector2(0, 360), Vector2(330, 720), STRAP, 46.0)
	match _state:
		"hold_letter":
			_arm(Vector2(250, 720), Vector2(420, 470), 0.3, "grip")
			_arm(Vector2(830, 720), Vector2(660, 470), -0.3, "grip")
			_letter(Rect2(400, 330, 280, 180))
		"point":
			_arm(Vector2(180, 720), Vector2(260, 600), 0.0, "rest")
			_arm(Vector2(900, 720), Vector2(700, 380), -0.55, "point")
		"light":
			_arm(Vector2(180, 720), Vector2(260, 600), 0.0, "rest")
			_arm(Vector2(820, 720), Vector2(600, 330), -0.25, "grip")
			if akba:
				_pendant(Vector2(600, 210), true)
		"reach":
			_arm(Vector2(220, 720), Vector2(400, 380), 0.35, "open")
			_arm(Vector2(860, 720), Vector2(680, 380), -0.35, "open")
		"grip":
			# Sostener en un quiebre: las dos manos adelante, cerradas, agarrando.
			_arm(Vector2(260, 720), Vector2(470, 330), 0.55, "grip")
			_arm(Vector2(820, 720), Vector2(610, 330), -0.55, "grip")
			draw_line(Vector2(470, 300), Vector2(610, 300), OUTLINE, 18.0)
		"wait":
			_arm(Vector2(300, 720), Vector2(480, 600), 0.9, "rest")
			_arm(Vector2(780, 720), Vector2(600, 600), -0.9, "rest")
		_:
			_arm(Vector2(180, 720), Vector2(270, 590), 0.15, "rest")
			_arm(Vector2(900, 720), Vector2(810, 590), -0.15, "rest")
	if akba and _state != "light":
		_pendant(Vector2(830, 520), false)
	draw_set_transform(Vector2.ZERO)


## Antebrazo (manga) de `from` a `to` y una mano con forma `pose` girada `tilt`.
func _arm(from: Vector2, to: Vector2, tilt: float, pose: String) -> void:
	var sleeve: Color = SLEEVE[_actor]
	draw_line(from, to, OUTLINE, 132.0)
	draw_line(from, to, sleeve, 116.0)
	if _actor == "akba":
		var cuff := to.lerp(from, 0.18)
		draw_line(cuff - Vector2(60, 0).rotated(tilt), cuff + Vector2(60, 0).rotated(tilt), sleeve.lightened(0.15), 26.0)
	_hand(to, tilt, pose)


func _hand(at: Vector2, tilt: float, pose: String) -> void:
	var skin: Color = SKIN[_actor]
	var up := Vector2.UP.rotated(tilt)
	var side := Vector2.RIGHT.rotated(tilt)
	draw_circle(at, 66, OUTLINE)
	draw_circle(at, 58, skin)
	var fingers := 4
	for i: int in fingers:
		var base := at + up * 40 + side * (-42 + i * 28)
		var length := 70.0
		match pose:
			"point":
				length = 120.0 if i == 1 else 30.0
			"grip", "rest":
				length = 34.0
			"open":
				length = 82.0
		var tip := base + up.rotated((i - 1.5) * (0.18 if pose == "open" else 0.05)) * length
		draw_line(base, tip, OUTLINE, 34.0)
		draw_line(base, tip, skin, 24.0)
		draw_circle(tip, 12, skin)
	var thumb := at - side * 58 + up * 6
	draw_line(at - side * 30, thumb - side * (30 if pose == "open" else 10), OUTLINE, 36.0)
	draw_line(at - side * 30, thumb - side * (30 if pose == "open" else 10), skin, 26.0)


func _letter(rect: Rect2) -> void:
	draw_rect(rect.grow(6), OUTLINE)
	draw_rect(rect, PAPER)
	draw_polyline(PackedVector2Array([rect.position, rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.55), Vector2(rect.end.x, rect.position.y)]),
			OUTLINE, 6.0)
	draw_circle(rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.55), 22, SEAL)


## El colgante poliédrico de Akba con su cadena; `raised` = en alto, brillando.
func _pendant(at: Vector2, raised: bool) -> void:
	var glow_alpha := 0.35 if raised else 0.18
	for ring: int in 4:
		draw_circle(at, (160.0 if raised else 70.0) - ring * 16.0, Color(GLOW, glow_alpha * (ring + 1) / 4.0))
	draw_line(at + Vector2(0, -150 if raised else -120), at + Vector2(0, -38), OUTLINE, 6.0)
	var points := PackedVector2Array()
	for i: int in 6:
		points.append(at + Vector2(0, -38).rotated(TAU * i / 6.0))
	draw_colored_polygon(points, GLOW.darkened(0.25))
	points.append(points[0])
	draw_polyline(points, OUTLINE, 5.0)
	draw_line(points[0], points[3], OUTLINE, 3.0)
	draw_line(points[1], points[4], OUTLINE, 3.0)
	draw_circle(at, 10, Color(1, 1, 1, 0.8))
