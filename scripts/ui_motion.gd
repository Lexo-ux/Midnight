extends RefCounted
## Transiciones y «jugo» de la interfaz: cortas (nunca más de 250 ms, salvo la
## transición de bucle, en loop_reset_view.gd) y ninguna con movimiento
## reducido. Solo tocan escala, posición y transparencia (nada de shaders).

const FADE_SECONDS: float = 0.18
const PRESS_SCALE: float = 0.94
const PRESS_SECONDS: float = 0.07
const RELEASE_SECONDS: float = 0.12
const TICK_SCALE: float = 1.14
const TICK_SECONDS: float = 0.2
const SHAKE_PIXELS: float = 18.0
const SHAKE_SECONDS: float = 0.24
const POP_SECONDS: float = 0.16
const POP_STAGGER: float = 0.04


## Muestra `node` con un fundido corto (o de golpe con movimiento reducido).
static func fade_in(node: CanvasItem, reduced_motion: bool) -> void:
	node.show()
	if reduced_motion or not node.is_inside_tree():
		node.modulate.a = 1.0
		return
	node.modulate.a = 0.0
	node.create_tween().tween_property(node, "modulate:a", 1.0, FADE_SECONDS)


## Botón pulsado: se aplasta un poco desde su centro.
static func press(control: Control, reduced_motion: bool) -> void:
	if reduced_motion or not control.is_inside_tree():
		return
	control.pivot_offset = control.size * 0.5
	control.create_tween().tween_property(control, "scale", Vector2.ONE * PRESS_SCALE, PRESS_SECONDS)


static func release(control: Control, reduced_motion: bool) -> void:
	if not control.is_inside_tree():
		return
	if reduced_motion:
		control.scale = Vector2.ONE
		return
	control.create_tween().tween_property(control, "scale", Vector2.ONE, RELEASE_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## El reloj avanza: un pequeño salto del texto.
static func tick(control: Control) -> void:
	if not control.is_inside_tree():
		return
	control.pivot_offset = control.size * 0.5
	var tween := control.create_tween()
	tween.tween_property(control, "scale", Vector2.ONE * TICK_SCALE, TICK_SECONDS * 0.4)
	tween.tween_property(control, "scale", Vector2.ONE, TICK_SECONDS * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Temblor corto (solo al ganar una conversación a la fuerza).
static func shake(control: Control, reduced_motion: bool) -> void:
	if reduced_motion or not control.is_inside_tree():
		return
	var home := control.position
	var tween := control.create_tween()
	var steps := 6
	for i: int in steps:
		var strength := SHAKE_PIXELS * (1.0 - float(i) / steps)
		tween.tween_property(control, "position", home + Vector2(strength if i % 2 == 0 else -strength, 0.0), SHAKE_SECONDS / steps)
	tween.tween_property(control, "position", home, SHAKE_SECONDS / steps)


## Aparece con un fundido, con un pequeño retraso según su posición (cartas
## que se reparten).
static func pop_in(control: Control, index: int, reduced_motion: bool) -> void:
	if reduced_motion or not control.is_inside_tree():
		return
	control.modulate.a = 0.0
	var tween := control.create_tween()
	tween.tween_interval(POP_STAGGER * index)
	tween.tween_property(control, "modulate:a", 1.0, POP_SECONDS)
