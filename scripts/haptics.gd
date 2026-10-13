extends Node
## La vibración (autoload `Haptics`), con patrones en data/haptics.json y tres
## niveles en los ajustes: apagada, baja o normal. Usa Input.vibrate_handheld,
## que no hace nada donde no hay motor de vibración (escritorio, sin pantalla).
## En Android hace falta el permiso VIBRATE en la exportación (docs/haptics.md);
## sin él, la llamada tampoco falla: simplemente no vibra.
## El movimiento reducido no la apaga: la vibración tiene su propio ajuste.

const DATA_PATH: String = "res://data/haptics.json"

var errors: PackedStringArray = []
## nivel -> multiplicador de intensidad.
var levels: Dictionary = {}
## patrón -> [[espera_ms, duración_ms, intensidad 0-1], ...]
var patterns: Dictionary = {}
## Pulsos al sostener en un quiebre: cada cuánto al empezar y al final (ms).
var sustain_start_ms: int = 900
var sustain_end_ms: int = 260
var level: String = "normal"
## Últimas vibraciones pedidas [{duration_ms, amplitude}] (para los tests).
var history: Array[Dictionary] = []


func _ready() -> void:
	load_data()


func load_data() -> bool:
	errors = []
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) if FileAccess.file_exists(DATA_PATH) else null
	if not source is Dictionary:
		errors.append("haptics.json no es un objeto JSON.")
		return _fail()
	levels = source.get("levels", {})
	for name: String in ["off", "low", "normal"]:
		if not levels.has(name):
			errors.append("haptics.json: falta el nivel \"%s\"." % name)
	var raw: Variant = source.get("patterns", {})
	for name: Variant in raw:
		var steps: Variant = raw[name]
		if not steps is Array or not steps.all(func(step: Variant) -> bool: return step is Array and step.size() == 3):
			errors.append("haptics.json: el patrón \"%s\" debe ser [[espera, duración, intensidad], ...]." % name)
			continue
		patterns[name] = steps
	var interval: Variant = source.get("sustain_interval_ms", {})
	sustain_start_ms = int(interval.get("start", 900))
	sustain_end_ms = int(interval.get("end", 260))
	if not errors.is_empty():
		return _fail()
	return true


func set_level(new_level: String) -> void:
	if levels.has(new_level):
		level = new_level


## Vibra con un patrón. false si está apagada o el patrón no existe.
func play(pattern: String) -> bool:
	var scale: float = levels.get(level, 0.0)
	if scale <= 0.0 or not patterns.has(pattern):
		return false
	for step: Array in patterns[pattern]:
		if step[0] <= 0 or not is_inside_tree():
			_vibrate(int(step[1]), float(step[2]) * scale)
		else:
			get_tree().create_timer(step[0] / 1000.0).timeout.connect(_vibrate.bind(int(step[1]), float(step[2]) * scale))
	return true


## Cada cuánto vibrar al sostener, según el avance (0-1): más rápido al final.
func sustain_interval_ms(progress: float) -> int:
	return int(lerpf(sustain_start_ms, sustain_end_ms, clampf(progress, 0.0, 1.0)))


func _vibrate(duration_ms: int, amplitude: float) -> void:
	history.append({"duration_ms": duration_ms, "amplitude": amplitude})
	if history.size() > 32:
		history.pop_front()
	Input.vibrate_handheld(duration_ms, clampf(amplitude, 0.0, 1.0))


func _fail() -> bool:
	for message: String in errors:
		push_error("[Haptics] " + message)
	return false
