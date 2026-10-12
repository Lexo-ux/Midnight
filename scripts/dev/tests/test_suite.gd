extends RefCounted
## Base de los módulos de test (ver run_tests.gd). Los GameState creados con
## new_state() no cargan ni guardan la partida del jugador y se liberan al
## terminar cada test.

const GameStateScript := preload("res://scripts/game_state.gd")
const GameData := preload("res://scripts/game_data.gd")
const Simulation := preload("res://scripts/simulation.gd")
const SaveManager := preload("res://scripts/save_manager.gd")
const LoopValidator := preload("res://scripts/dev/loop_validator.gd")

const TEST_SAVE_PATH: String = "user://test_savegame.json"

var tree: SceneTree

var _failures: PackedStringArray = []
var _nodes: Array[Node] = []


func check(condition: bool, message: String) -> bool:
	if not condition:
		_failures.append(message)
	return condition


func take_failures() -> PackedStringArray:
	var failures := _failures
	_failures = []
	return failures


func cleanup() -> void:
	for node: Node in _nodes:
		if is_instance_valid(node):
			tree.root.remove_child(node)
			node.free()
	_nodes.clear()
	SaveManager.delete(TEST_SAVE_PATH)


func new_state(save_path: String = TEST_SAVE_PATH, autosave: bool = false, load_save: bool = false) -> GameStateScript:
	var state: GameStateScript = GameStateScript.new()
	state.save_path = save_path
	state.autosave_enabled = autosave
	state.load_save_on_ready = load_save
	tree.root.add_child(state)
	_nodes.append(state)
	return state


func free_state(state: GameStateScript) -> void:
	_nodes.erase(state)
	tree.root.remove_child(state)
	state.free()


func read_json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


## Hace una acción concreta con el protagonista activo. Falla el test si no está disponible.
func act(state: GameStateScript, verb: String, place: String, target: String = "", id: String = "") -> bool:
	var ok := state.perform({"verb": verb, "place": place, "target": target, "id": id})
	return check(ok, "%s no pudo hacer %s/%s/%s/%s a las %s" % [state.active_actor(), verb, place, target, id,
			GameData.format_time(state.current_time())])


## Avanza con los dos en su rutina hasta `minute`.
func routine_until(state: GameStateScript, minute: int) -> void:
	while state.current_time() < minute and not state.is_loop_over():
		state.sim.step({"verb": Simulation.ROUTINE_VERB})


func loop_text(state: GameStateScript) -> String:
	return JSON.stringify(state.export_snapshot()["loop"], "", false)


func snapshot_text(state: GameStateScript) -> String:
	return JSON.stringify(state.export_snapshot(), "", false)


## Lo que de verdad es el mundo (sin ruta, registro ni diálogo pendiente).
func world_text(state: GameStateScript) -> String:
	var loop: Dictionary = state.export_snapshot()["loop"]
	for key: String in ["route", "log", "outcome"]:
		loop.erase(key)
	return JSON.stringify(loop, "", false)


## Sustituye el estado del bucle a mano (tests de caja blanca).
func patch_loop(state: GameStateScript, changes: Dictionary) -> void:
	for key: String in changes:
		state.sim.s[key] = changes[key]


## Juega un recorrido de data/dev/*.json. Devuelve false (y apunta el fallo) si un paso es imposible.
func play_walkthrough(state: GameStateScript, walkthrough: Dictionary) -> bool:
	var steps: Array = walkthrough["steps"]
	for i: int in steps.size():
		var step: Dictionary = steps[i]
		var ok := false
		if step.has("act"):
			ok = state.perform(step["act"])
		elif step.has("switch"):
			ok = state.switch_to(step["switch"])
		elif step.has("skip"):
			ok = state.skip_to(GameData.parse_time(step["skip"]))
		elif step.has("next_loop"):
			ok = state.start_next_loop()
		elif step.has("replay"):
			ok = state.replay_route(GameData.parse_time(step["replay"]))
		if not ok:
			return check(false, "paso %d %s imposible a las %s (bucle %d, %s)" % [i, step,
					GameData.format_time(state.current_time()), state.loop_number, state.active_actor()])
	return true


## Copia profunda de todos los JSON de data/ (para romperlos a propósito).
func data_sources() -> Dictionary:
	var sources: Dictionary = {}
	for key: String in GameData.FILES:
		sources[key] = read_json(GameData.FILES[key])
	return sources
