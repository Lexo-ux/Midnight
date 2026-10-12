extends SceneTree
## Ejecuta todos los tests sin pantalla:
##   godot --headless --path . --script res://scripts/dev/run_tests.gd
## Cada método `test_*` de los módulos es un test; debe terminar con `return true`
## (si un error de script lo corta, devuelve null y cuenta como FAIL).
## Sale con código 1 si algún test falla.

const TEST_MODULES: Array[String] = [
	"res://scripts/dev/tests/test_data_validation.gd",
	"res://scripts/dev/tests/test_world_clock.gd",
	"res://scripts/dev/tests/test_determinism.gd",
	"res://scripts/dev/tests/test_rastro_desgaste.gd",
	"res://scripts/dev/tests/test_letters.gd",
	"res://scripts/dev/tests/test_cuaderno.gd",
	"res://scripts/dev/tests/test_save_load.gd",
	"res://scripts/dev/tests/test_walkthroughs.gd",
	"res://scripts/dev/tests/test_loop_validator.gd",
	"res://scripts/dev/tests/test_scenes.gd",
	"res://scripts/dev/tests/test_art_pipeline.gd",
	"res://scripts/dev/tests/test_softlock_fuzz.gd",
]

var _has_run: bool = false


## En _initialize() la raíz aún no está en el árbol y los _ready() no se
## ejecutarían, así que los tests corren en el primer fotograma.
func _process(_delta: float) -> bool:
	if not _has_run:
		_has_run = true
		_run_all()
	return false


func _run_all() -> void:
	var passed: int = 0
	var failed: int = 0
	var started := Time.get_ticks_msec()
	for path: String in TEST_MODULES:
		var suite: RefCounted = load(path).new()
		suite.set("tree", self)
		for method: Dictionary in suite.get_method_list():
			var test_name: String = method["name"]
			if not test_name.begins_with("test_"):
				continue
			var test_started := Time.get_ticks_msec()
			var completed: Variant = suite.call(test_name)
			suite.call("cleanup")
			var failures: PackedStringArray = suite.call("take_failures")
			if completed != true:
				failures.append("el test no terminó (error de script o falta `return true`)")
			var label := "%s.%s (%.1f s)" % [path.get_file().get_basename(), test_name,
					(Time.get_ticks_msec() - test_started) / 1000.0]
			if failures.is_empty():
				passed += 1
				print("PASS  " + label)
			else:
				failed += 1
				print("FAIL  " + label)
				for failure: String in failures:
					print("        - " + failure)
	print("\n%d tests: %d PASS, %d FAIL (%.0f s)" % [passed + failed, passed, failed,
			(Time.get_ticks_msec() - started) / 1000.0])
	quit(1 if failed > 0 else 0)
