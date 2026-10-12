extends "res://scripts/dev/tests/test_suite.gd"
## Partidas aleatorias (con semilla, reproducibles) con cambios de protagonista
## y herramientas al azar. En cada paso comprueba que el jugador siempre tenga
## algo que hacer y que cada bucle termine en un número acotado de pasos.
## Imprime la semilla de cualquier fallo: para reproducirlo, pon RUNS = 1 y
## BASE_SEED = esa semilla.

const RUNS: int = 300
const BASE_SEED: int = 20261012
const MAX_STEPS_PER_LOOP: int = 200
const MAX_LOOPS_PER_RUN: int = 3
const SWITCH_CHANCE: float = 0.25
const TOOL_CHANCE: float = 0.06


func test_random_runs_never_softlock() -> bool:
	var state := new_state()
	var stats: Dictionary = {"loops": 0, "steps": 0, "skips": 0, "replays": 0, "endings": {}}
	for run: int in RUNS:
		var seed_value: int = BASE_SEED + run
		var problem := _play_random_run(state, seed_value, stats)
		check(problem == "", "semilla %d: %s" % [seed_value, problem])
	print("        %d partidas, %d bucles, %d pasos, %d saltos, %d repeticiones, finales %s" % [RUNS, stats["loops"],
			stats["steps"], stats["skips"], stats["replays"], stats["endings"]])
	return true


func _play_random_run(state: GameStateScript, seed_value: int, stats: Dictionary) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	state.new_game()
	for loop_index: int in rng.randi_range(1, MAX_LOOPS_PER_RUN):
		if state.can_replay() and rng.randf() < 0.5:
			var targets := state.replay_targets()
			if not state.replay_route(targets[rng.randi_range(0, targets.size() - 1)]):
				return "«Repetir mi ruta» falló en el bucle %d" % state.loop_number
			stats["replays"] += 1
		var steps := 0
		while not state.is_loop_over():
			steps += 1
			if steps > MAX_STEPS_PER_LOOP:
				return "el bucle %d no termina en %d pasos" % [state.loop_number, MAX_STEPS_PER_LOOP]
			var problem := _softlock_problem(state)
			if problem != "":
				return "bucle %d, %s: %s" % [state.loop_number, GameData.format_time(state.current_time()), problem]
			_random_action(state, rng, stats)
		stats["loops"] += 1
		stats["steps"] += steps
		stats["endings"][state.ending_id()] = stats["endings"].get(state.ending_id(), 0) + 1
		if not state.start_next_loop():
			return "no se pudo empezar otro bucle tras el %d" % state.loop_number
	return ""


## "" si el jugador puede hacer algo; si no, qué falla.
func _softlock_problem(state: GameStateScript) -> String:
	if state.current_time() < state.data.loop_start or state.current_time() >= state.data.day_end:
		return "hora fuera de la ventana"
	if not state.can_switch():
		return "no se puede cambiar de protagonista con el bucle en curso"
	for actor: String in state.data.protagonist_ids:
		if not state.sim.actions_for(actor).is_empty():
			return ""
	return "ningún protagonista tiene acciones"


func _random_action(state: GameStateScript, rng: RandomNumberGenerator, stats: Dictionary) -> void:
	var roll := rng.randf()
	if roll < SWITCH_CHANCE:
		state.switch_to(state.data.protagonist_ids[rng.randi_range(0, 1)])
		return
	if roll < SWITCH_CHANCE + TOOL_CHANCE:
		var targets := state.skip_targets()
		state.skip_to(targets[rng.randi_range(0, targets.size() - 1)])
		stats["skips"] += 1
		return
	var actions := state.get_actions()
	if actions.is_empty():
		# Akba atrapado: lo que queda es cambiar a Sazil.
		for actor: String in state.data.protagonist_ids:
			if not state.sim.actions_for(actor).is_empty():
				state.switch_to(actor)
				return
		return
	state.perform(actions[rng.randi_range(0, actions.size() - 1)])
	if rng.randf() < 0.5:
		state.dismiss_outcome()
