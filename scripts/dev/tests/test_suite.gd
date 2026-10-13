extends RefCounted
## Base de los módulos de test (ver run_tests.gd). Los GameState creados con
## new_state() no cargan ni guardan la partida del jugador y se liberan al
## terminar cada test.

const GameStateScript := preload("res://scripts/game_state.gd")
const GameData := preload("res://scripts/game_data.gd")
const Simulation := preload("res://scripts/simulation.gd")
const SaveManager := preload("res://scripts/save_manager.gd")
const LoopValidator := preload("res://scripts/dev/loop_validator.gd")
const SceneRules := preload("res://scripts/scene_rules.gd")
const ArtLibrary := preload("res://scripts/art_library.gd")
const PLACE_VIEW_SCENE := preload("res://scenes/place_view.tscn")
const MAP_VIEW_SCENE := preload("res://scenes/map_view.tscn")

const TEST_SAVE_PATH: String = "user://test_savegame.json"
## Tamaño de la escena en los tests (el de la pantalla del juego).
const VIEW_SIZE := Vector2(1080, 1100)

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


## Añade un nodo al árbol durante el test (se libera al terminar).
func add_node(node: Node) -> Node:
	tree.root.add_child(node)
	_nodes.append(node)
	return node


## La escena de un lugar con el arte del manifiesto real, atada a `state`.
func new_place_view(state: GameStateScript) -> Control:
	var view: Control = add_node(PLACE_VIEW_SCENE.instantiate())
	view.size = VIEW_SIZE
	var art := ArtLibrary.new()
	art.load_manifest()
	view.bind(state, art)
	return view


func new_map_view(state: GameStateScript) -> Control:
	var map: Control = add_node(MAP_VIEW_SCENE.instantiate())
	map.size = Vector2(1080, 1920)
	map.bind(state)
	return map


## El mundo del bucle sin lo que es solo de presentación o de registro.
func world_without_view(state: GameStateScript, also: Array[String] = []) -> String:
	var loop: Dictionary = state.export_snapshot()["loop"]
	for key: String in ["route", "log", "outcome", "stations"] + also:
		loop.erase(key)
	return JSON.stringify(loop, "", false)


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


## Una conversación con cartas con `person` (donde esté), con el protagonista
## activo. Falla el test si no se puede.
func talk(state: GameStateScript, person: String, cards: Array) -> bool:
	var ok := state.perform({"verb": "hablar", "place": state.position_of(person), "target": person,
			"id": state.data.conversation_by_person[person], "cards": cards})
	return check(ok, "%s no pudo hablar con %s jugando %s a las %s" % [state.active_actor(), person, cards,
			GameData.format_time(state.current_time())])


## Una acción al azar del protagonista activo, lista para perform() ({} si no
## hay ninguna). Las conversaciones con cartas se juegan de verdad con cartas al
## azar (de 1 a 6, hasta que terminen) y los quiebres llevan una decisión al azar.
func random_command(state: GameStateScript, rng: RandomNumberGenerator) -> Dictionary:
	var actions := state.get_actions()
	if actions.is_empty():
		return {}
	var command: Dictionary = actions[rng.randi_range(0, actions.size() - 1)].duplicate()
	var data := state.data
	if command["verb"] == "hablar" and data.conversations.has(command["id"]):
		var conv := state.start_conversation(command["target"])
		var plays := rng.randi_range(1, 6)
		while conv["result"] == "" and plays > 0 and not conv["hand"].is_empty():
			state.play_card(conv, conv["hand"][rng.randi_range(0, conv["hand"].size() - 1)])
			plays -= 1
		command["cards"] = conv["played"].duplicate()
	elif command["verb"] == "interactuar" and data.breakpoint_by_interaction.has(command["id"]):
		command["decision"] = GameData.DECISIONS[rng.randi_range(0, GameData.DECISIONS.size() - 1)]
	return command


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
