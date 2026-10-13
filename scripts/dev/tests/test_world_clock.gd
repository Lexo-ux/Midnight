extends "res://scripts/dev/tests/test_suite.gd"
## Reloj compartido: cada acción mueve el mundo entero 30 minutos; cambiar de
## protagonista no cuesta nada; quien no se controla sigue su rutina y solo se
## desvía cuando una bandera lo dice.


func test_every_action_advances_everyone_thirty_minutes() -> bool:
	var state := new_state()
	var start := state.current_time()
	check(start == state.data.loop_start, "el bucle empieza a las 14:00")
	act(state, "observar", "mercado")
	check(state.current_time() == start + 30, "observar cuesta 30 minutos")
	state.switch_to("akba")
	act(state, "esperar", "plaza")
	check(state.current_time() == start + 60, "la acción de Akba mueve el mismo reloj")
	for id: String in state.data.npc_ids():
		check(state.position_of(id) == state.sim._routine_place(id, state.current_time()),
				"%s está donde dice su rutina a las 15:00" % id)
	return true


func test_switching_costs_nothing() -> bool:
	var state := new_state()
	talk(state, "lina", ["silencio"])
	var before := world_text(state)
	var time := state.current_time()
	for i: int in 5:
		state.switch_to("akba")
		state.switch_to("sazil")
	check(state.current_time() == time, "cambiar de protagonista no mueve el reloj")
	check(world_text(state) == before, "cambiar de protagonista no cambia el mundo")
	check(state.switch_to("akba") and state.active_actor() == "akba", "se puede cambiar en cualquier momento")
	return true


func test_uncontrolled_protagonist_follows_routine() -> bool:
	var state := new_state()
	state.switch_to("akba")
	for i: int in 6:
		act(state, "esperar", "plaza")
		check(state.position_of("sazil") == state.sim._routine_place("sazil", state.current_time()),
				"Sazil sigue su rutina a las %s" % GameData.format_time(state.current_time()))
	check(state.letter_state("orden_lina")["state"] == "entregada", "Sazil entrega el pedido por su cuenta, como cada día")
	state.switch_to("sazil")
	routine_until(state, GameData.parse_time("18:00"))
	check(state.position_of("akba") == "observatorio", "Akba, sin control, vuelve a su rutina en el Observatorio")
	return true


func test_people_deviate_only_through_flags() -> bool:
	var canonical := new_state()
	routine_until(canonical, GameData.parse_time("21:00"))
	check(canonical.position_of("beto") == "plaza", "sin intervenir, Beto está en la plaza a las 21:00")
	check(canonical.position_of("tun") == "plaza", "sin intervenir, Tun está en la plaza a las 21:00")
	check(canonical.position_of("lina") == "umbral", "sin intervenir, la fisura se lleva a Lina")
	var warned := new_state()
	act(warned, "esperar", "mercado")
	act(warned, "hablar", "mercado", "marcos", "marcos_sazil")
	talk(warned, "beto", ["escuchar", "verdad_beto_imprenta"])
	check(warned.sim.s["flags"].has("beto_avisado"), "el recado de la imprenta, en conversación, activa beto_avisado")
	routine_until(warned, GameData.parse_time("20:00"))
	check(warned.position_of("beto") == "plaza", "Beto sigue en la plaza hasta su nueva hora")
	routine_until(warned, GameData.parse_time("20:30"))
	check(warned.position_of("beto") == "imprenta", "con beto_avisado, Beto se va a la imprenta a las 20:30")
	return true


func test_loop_ends_at_midnight() -> bool:
	var state := new_state()
	var steps := 0
	while not state.is_loop_over():
		state.perform({"verb": Simulation.ROUTINE_VERB})
		steps += 1
	check(steps == 20, "un bucle de 14:00 a 24:00 son 20 acciones (fueron %d)" % steps)
	check(state.ending_id() == "otra_vez", "si nadie interviene, el final es «Otra vez»")
	check(not state.can_switch() and state.get_actions().is_empty(), "a medianoche no se puede actuar ni cambiar")
	check(state.start_next_loop() and state.current_time() == state.data.loop_start, "el bucle siguiente vuelve a las 14:00")
	return true
