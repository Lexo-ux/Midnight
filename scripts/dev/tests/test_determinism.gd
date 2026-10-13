extends "res://scripts/dev/tests/test_suite.gd"
## Determinismo (también con conversaciones con cartas y decisiones de quiebre
## al azar): las mismas acciones dan el mismo estado; «Repetir mi ruta»
## reproduce el bucle anterior hasta la hora elegida (con conversaciones, lo
## aprendido puede cambiar cómo acaban, pero se repiten las mismas acciones a
## las mismas horas y en los mismos sitios); «Saltar a la hora» llega al mismo
## estado que esperar paso a paso.

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
			_random_step(state, rng, false)
		state.start_next_loop()
		check(state.can_replay(), "semilla %d: al empezar el bucle se puede repetir la ruta" % seed_value)
		check(state.replay_route(hour), "semilla %d: la ruta se repite" % seed_value)
		check(state.current_time() == hour, "semilla %d: la repetición para a las 19:00" % seed_value)
		check(world_text(state) == at_hour, "semilla %d: la repetición reproduce el mundo del bucle anterior" % seed_value)
		check(not state.can_replay(), "semilla %d: solo se repite al empezar un bucle" % seed_value)
		free_state(state)
	return true


## Con conversaciones, lo aprendido puede abrir antes una puerta (p. ej. Beto
## se va de la plaza avisado) y entonces la ruta se separa y para ahí. Lo que
## se repite siempre son las mismas acciones a las mismas horas y en los mismos
## sitios; si llega a la hora, los dos están donde estaban.
func test_repeat_route_with_conversations_keeps_times_and_places() -> bool:
	var conversations := 0
	var reached := 0
	for seed_value: int in SEEDS:
		var state := new_state()
		var hour := GameData.parse_time("21:00")
		var positions := {}
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		while not state.is_loop_over():
			if state.current_time() == hour and positions.is_empty():
				positions = {"sazil": state.position_of("sazil"), "akba": state.position_of("akba")}
			conversations += int(_random_step(state, rng).has("cards"))
		var original: Array = state.sim.s["route"].duplicate(true)
		state.start_next_loop()
		check(state.replay_route(hour), "semilla %d: la ruta se repite" % seed_value)
		var replayed: Array = state.sim.s["route"]
		check(not replayed.is_empty(), "semilla %d: se repite algo" % seed_value)
		for i: int in replayed.size():
			var a: Dictionary = original[i]
			var b: Dictionary = replayed[i]
			var same: bool = a["t"] == b["t"] and a.has("switch") == b.has("switch")
			if same and a.has("command"):
				same = a["command"]["place"] == b["command"]["place"]
			check(same, "semilla %d: el paso %d se repite a la misma hora y en el mismo sitio" % [seed_value, i])
		if state.current_time() == hour:
			reached += 1
			check(state.position_of("sazil") == positions["sazil"] and state.position_of("akba") == positions["akba"],
					"semilla %d: los dos acaban donde estaban" % seed_value)
		free_state(state)
	check(conversations > 0, "las rutas al azar tienen conversaciones")
	print("        %d de %d repeticiones llegan a las 21:00" % [reached, SEEDS.size()])
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


## Un paso al azar; sin `conversations`, las conversaciones con cartas se cambian por la rutina.
func _random_step(state: GameStateScript, rng: RandomNumberGenerator, conversations: bool = true) -> Dictionary:
	if rng.randf() < 0.3:
		var actor: String = state.data.protagonist_ids[rng.randi_range(0, 1)]
		state.switch_to(actor)
		return {"switch": actor}
	var command := random_command(state, rng)
	if command.is_empty() or (command.has("cards") and (command["cards"].is_empty() or not conversations)):
		command = {"verb": Simulation.ROUTINE_VERB}
	state.perform(command)
	return command
