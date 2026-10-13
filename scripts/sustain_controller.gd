extends RefCounted
## Sostener en un momento de quiebre: una máquina de estados pura con un reloj
## inyectado (milisegundos), así se prueba sin pantalla. La simulación nunca
## ve el tiempo: solo recibe la decisión final, "sostuvo" o "soltó".
##
## Modos:
## - "hold": mantener pulsado hasta llenar el anillo. Soltar antes es soltar.
## - "toggle": tocar para empezar a sostener; tocar otra vez es soltar.
## Tiempo: los milisegundos a llenar, o 0 («sin tiempo»): entonces no hay que
## sostener nada; confirm() decide «sostuvo» y let_go() «soltó».
##
## Pausa (la app pierde el foco o sale un diálogo del sistema): no cuenta como
## soltar. Al volver, se espera a que se vuelva a pulsar (o tocar) para seguir
## desde donde iba.

const SUSTAINED: String = "sostuvo"
const RELEASED: String = "soltó"

var mode: String = "hold"
var duration_ms: int = 20000
var clock: Callable
## "idle": esperando; "holding": sosteniendo; "paused": la app se fue;
## "resuming": volvió y espera otro toque; "done": decidido.
var state: String = "idle"
var result: String = ""

var _accumulated_ms: int = 0
var _since_ms: int = 0


func _init(controller_mode: String, milliseconds: int, now: Callable) -> void:
	mode = controller_mode
	duration_ms = maxi(milliseconds, 0)
	clock = now


func is_timed() -> bool:
	return duration_ms > 0


## Avance de 0 a 1 (con el reloj de ahora).
func progress() -> float:
	if not is_timed():
		return 0.0
	return clampf(float(_elapsed()) / float(duration_ms), 0.0, 1.0)


## Llamar en cada fotograma (o en los tests): si se llenó, decide «sostuvo».
func update() -> void:
	if state == "holding" and is_timed() and _elapsed() >= duration_ms:
		_accumulated_ms = duration_ms
		_finish(SUSTAINED)


func press() -> void:
	if mode == "hold" and is_timed() and state in ["idle", "resuming"]:
		_start()


func release() -> void:
	if mode == "hold" and state == "holding":
		update()
		if state == "holding":
			_finish(RELEASED)


func tap() -> void:
	if mode != "toggle" or not is_timed():
		return
	if state in ["idle", "resuming"]:
		_start()
	elif state == "holding":
		update()
		if state == "holding":
			_finish(RELEASED)


## Sin tiempo: decidir sostener.
func confirm() -> void:
	if not is_timed() and state != "done":
		_finish(SUSTAINED)


## Soltar a propósito (el botón «Soltar»), en cualquier modo.
func let_go() -> void:
	if state != "done":
		_finish(RELEASED)


func pause() -> void:
	if state == "holding":
		_accumulated_ms = _elapsed()
		state = "paused"
	elif state in ["idle", "resuming"]:
		state = "paused"


func resume() -> void:
	if state == "paused":
		state = "resuming" if _accumulated_ms > 0 else "idle"


func _start() -> void:
	_since_ms = clock.call()
	state = "holding"


func _elapsed() -> int:
	if state == "holding":
		return _accumulated_ms + (int(clock.call()) - _since_ms)
	return _accumulated_ms


func _finish(decision: String) -> void:
	if state == "holding":
		_accumulated_ms = mini(_elapsed(), duration_ms) if is_timed() else 0
	state = "done"
	result = decision
