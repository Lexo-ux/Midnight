extends Control
## Transición de un bucle a otro: sobre la noche, el reloj de Much vuelve atrás
## de medianoche a la hora de inicio y la pantalla se funde. Dura ≤ 1,2 s, un
## toque (o el botón «atrás») la salta y con movimiento reducido no hay
## transición: corte. No toca la partida: GameState ya empezó el bucle nuevo.
## La esfera es la ranura `loop_reset_clock` (sin agujas: las agujas las mueve
## este script).

signal finished

const ArtLibrary := preload("res://scripts/art_library.gd")
const UiStyle := preload("res://scripts/ui_style.gd")
const CLOCK_SLOT: String = "loop_reset_clock"
const REWIND_SECONDS: float = 0.95
const FADE_SECONDS: float = 0.2

@onready var _face: TextureRect = %Face
@onready var _hands: Control = %ClockHands
@onready var _loop: Label = %LoopTitle

## Minuto que marcan las agujas ahora.
var minute: float = 0.0:
	set(value):
		minute = value
		if _hands != null:
			_hands.queue_redraw()
var _tween: Tween


func _ready() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_hands.draw.connect(_draw_hands)


## Rebobina de `from_minute` a `to_minute` (los dos en minutos del día).
## `reduced`: sin transición. Devuelve false si no se mostró.
func play(art: ArtLibrary, title: String, from_minute: int, to_minute: int, reduced: bool) -> bool:
	if reduced:
		finished.emit()
		return false
	_face.texture = art.texture_for(CLOCK_SLOT) if art != null else null
	_loop.text = title
	if _tween != null and _tween.is_valid():
		_tween.kill()
	minute = float(from_minute)
	modulate.a = 1.0
	show()
	_tween = create_tween()
	_tween.tween_property(self, "minute", float(to_minute), REWIND_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_SECONDS)
	_tween.tween_callback(_end)
	return true


func is_playing() -> bool:
	return visible


## Saltar: se corta ya.
func skip() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_end()


func _end() -> void:
	hide()
	modulate.a = 1.0
	finished.emit()


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		skip()
		accept_event()


func _draw_hands() -> void:
	var center := _hands.size * 0.5
	var radius := minf(_hands.size.x, _hands.size.y) * 0.5
	if _face.texture == null:
		_hands.draw_circle(center, radius * 0.84, UiStyle.PAPER)
		_hands.draw_arc(center, radius * 0.84, 0.0, TAU, 96, UiStyle.INK, UiStyle.OUTLINE * 2.0, true)
	var hours := fmod(minute / 60.0, 12.0)
	var hour_hand := Vector2.UP.rotated(TAU * hours / 12.0) * radius * 0.42
	var minute_hand := Vector2.UP.rotated(TAU * fmod(minute, 60.0) / 60.0) * radius * 0.64
	_hands.draw_line(center, center + hour_hand, UiStyle.INK, radius * 0.07, true)
	_hands.draw_line(center, center + minute_hand, UiStyle.INK, radius * 0.045, true)
	_hands.draw_circle(center, radius * 0.06, UiStyle.INK)
