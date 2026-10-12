extends "res://scripts/dev/tests/test_suite.gd"
## Determinismo: las mismas acciones dan el mismo estado; «Repetir mi ruta»
## reproduce el bucle anterior hasta la hora elegida; «Saltar a la hora» llega
## al mismo estado que esperar paso a paso.

const SEEDS: Array[int] = [7, 52, 1977, 20261012]


func test_same_actions_same_state() -> bool:
	for seed_value: int in SEEDS:
		var a := new_state()
		var b := new_state()
		var commands := _random_loop(a, seed_value)
		for command: Dictionary in commands:
			if command.has("switch"):
				b.switch_to(command["switch"])
			else:
				b.perform(command)
		check(snapshot_text(a) == snapshot_text(b), "semilla %d: las mismas acciones dan estados distintos" % seed_value)
		free_state(a)
		free_state(b)
	return true


func test_repeat_route_reproduces_previous_loop() -> bool:
	for seed_value: int in SEEDS:
		var state := new_state()
		var hour := GameData.parse_time("19:00")
		var at_hour := ""
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		while not state.is_loop_over():
			if state.current_time() == hour and at_hour == "":
				at_hour = world_text(state)
			_random_step(state, rng)
		state.start_next_loop()
		check(state.can_replay(), "semilla %d: al empezar el bucle se puede repetir la ruta" % seed_value)
		check(state.replay_route(hour), "semilla %d: la ruta se repite" % seed_value)
		check(state.current_time() == hour, "semilla %d: la repetición para a las 19:00" % seed_value)
		check(world_text(state) == at_hour, "semilla %d: la repetición reproduce el mundo del bucle anterior" % seed_value)
		check(not state.can_replay(), "semilla %d: solo se repite al empezar un bucle" % seed_value)
		free_state(state)
	return true


func test_skip_to_hour_lands_on_routine_state() -> bool:
	var skipped := new_state()
	var walked := new_state()
	var target := GameData.parse_time("20:00")
	check(skipped.skip_to(target), "se puede saltar a las 20:00")
	routine_until(walked, target)
	check(skipped.current_time() == target, "el salto termina a las 20:00")
	check(world_text(skipped) == world_text(walked), "saltar a la hora es lo mismo que dejar a los dos en su rutina")
	check(not skipped.skip_to(GameData.parse_time("19:00")), "no se puede saltar hacia atrás")
	check(skipped.skip_to(skipped.data.day_end) and skipped.is_loop_over(), "saltar a medianoche termina el bucle")
	return true


## Un bucle entero con acciones y cambios al azar (con semilla). Devuelve los comandos.
func _random_loop(state: GameStateScript, seed_value: int) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var commands: Array[Dictionary] = []
	while not state.is_loop_over():
		commands.append(_random_step(state, rng))
	return commands


func _random_step(state: GameStateScript, rng: RandomNumberGenerator) -> Dictionary:
	if rng.randf() < 0.3:
		var actor: String = state.data.protagonist_ids[rng.randi_range(0, 1)]
		state.switch_to(actor)
		return {"switch": actor}
	var actions := state.get_actions()
	var command: Dictionary = {"verb": Simulation.ROUTINE_VERB} if actions.is_empty() else actions[rng.randi_range(0, actions.size() - 1)]
	state.perform(command)
	return command
