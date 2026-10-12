extends SceneTree
## Validador de bucles sin pantalla:
##   godot --headless --path . --script res://scripts/dev/validate_loops.gd
## Carga los JSON (referencias), recorre los bucles (alcanzabilidad de pistas y
## finales) y escribe el grafo de pistas en build/clue_graph.md (Mermaid).
## Sale con código 1 si encuentra problemas. También corre dentro de los tests.

const GameData := preload("res://scripts/game_data.gd")
const LoopValidator := preload("res://scripts/dev/loop_validator.gd")
const GRAPH_PATH: String = "res://build/clue_graph.md"

var _has_run: bool = false


func _process(_delta: float) -> bool:
	if not _has_run:
		_has_run = true
		_run()
	return false


func _run() -> void:
	var data := GameData.new()
	if not data.load_all():
		print("FAIL: los datos no pasan la validación de referencias (%d errores, arriba)." % data.errors.size())
		quit(1)
		return
	var validator := LoopValidator.new(data)
	var report := validator.validate()
	var result: Dictionary = report["result"]
	print("Pasadas: %d · estados explorados: %d · pistas alcanzables: %d de %d" % [result["passes"], result["states"],
			result["clues"].size(), data.clue_ids.size()])
	for ending: String in result["endings"]:
		print("Final «%s»: alcanzable desde la pasada %d" % [ending, result["endings"][ending]])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
	var file := FileAccess.open(GRAPH_PATH, FileAccess.WRITE)
	file.store_string(validator.clue_graph_markdown(result))
	file.close()
	print("Grafo de pistas: %s" % ProjectSettings.globalize_path(GRAPH_PATH))
	if report["problems"].is_empty():
		print("PASS: todas las referencias existen y todas las pistas y finales son alcanzables.")
		quit(0)
	else:
		for problem: String in report["problems"]:
			print("FAIL: " + problem)
		quit(1)
