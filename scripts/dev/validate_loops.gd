extends SceneTree
## Validador de bucles sin pantalla:
##   godot --headless --path . --script res://scripts/dev/validate_loops.gd -- [--max-states N] [--timeout S]
## Carga los JSON (referencias), recorre los bucles (alcanzabilidad de pistas y
## finales) y escribe el grafo de pistas en build/clue_graph.md (Mermaid).
## Sale con código 1 si encuentra problemas o si la búsqueda pasa de
## --max-states (2 000 000 por defecto) o de --timeout segundos (600 por defecto).
## También corre dentro de los tests.

const GameData := preload("res://scripts/game_data.gd")
const LoopValidator := preload("res://scripts/dev/loop_validator.gd")
const GRAPH_PATH: String = "res://build/clue_graph.md"
const DEFAULT_TIMEOUT_S: int = 600

var _has_run: bool = false


func _process(_delta: float) -> bool:
	if not _has_run:
		_has_run = true
		_run()
	return false


func _run() -> void:
	var started := Time.get_ticks_msec()
	var data := GameData.new()
	if not data.load_all():
		print("FAIL: los datos no pasan la validación de referencias (%d errores, arriba)." % data.errors.size())
		quit(1)
		return
	var validator := LoopValidator.new(data)
	validator.max_states = _int_arg("--max-states", LoopValidator.DEFAULT_MAX_STATES)
	validator.timeout_ms = _int_arg("--timeout", DEFAULT_TIMEOUT_S) * 1000
	validator.reset_limits()
	var report := validator.validate()
	var result: Dictionary = report["result"]
	print("Pasadas: %d · estados explorados: %d · pistas alcanzables: %d de %d · %.1f s" % [result["passes"], validator.total_states,
			result["clues"].size(), data.clue_ids.size(), (Time.get_ticks_msec() - started) / 1000.0])
	if result.has("hotspot_clues"):
		print("Pistas que revela algún punto interactivo: %d (%d puntos)" % [result["hotspot_clues"].size(), data.hotspots.size()])
		print("Puertas de conversación abiertas: %d" % result["doors"].size())
		for ending: String in result["endings"]:
			print("Final «%s»: alcanzable desde la pasada %d" % [ending, result["endings"][ending]])
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
		var file := FileAccess.open(GRAPH_PATH, FileAccess.WRITE)
		file.store_string(validator.clue_graph_markdown(result))
		file.close()
		print("Grafo de pistas: %s" % ProjectSettings.globalize_path(GRAPH_PATH))
	if report["problems"].is_empty():
		print("PASS: todas las referencias existen y todas las pistas, puertas y finales son alcanzables.")
		quit(0)
	else:
		for problem: String in report["problems"]:
			print("FAIL: " + problem)
		quit(1)


## `--nombre N` de los argumentos tras `--` (o de los de Godot).
func _int_arg(name: String, fallback: int) -> int:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		args = OS.get_cmdline_args()
	var index := args.find(name)
	if index >= 0 and index + 1 < args.size() and args[index + 1].is_valid_int():
		return args[index + 1].to_int()
	return fallback
