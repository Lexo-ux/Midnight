extends "res://scripts/dev/tests/test_suite.gd"
## Guardado: ida y vuelta exacta (también con conversaciones, marcas de Akba,
## decisiones de quiebre y los ajustes nuevos de la versión 4), migración desde
## la versión 3, autoguardado tras cada acción y cada cambio, y vuelta a una
## partida nueva (sin romperse) con partidas dañadas, de otra versión (como la
## del prototipo de Marta) o con ids desconocidos.

const ROUND_TRIP_SEED: int = 4242


func test_round_trip_is_exact() -> bool:
	var state := new_state()
	var rng := RandomNumberGenerator.new()
	rng.seed = ROUND_TRIP_SEED
	var checked := 0
	for step: int in 70:
		if state.is_loop_over():
			_check_round_trip(state, "medianoche del bucle %d" % state.loop_number)
			state.start_next_loop()
		elif rng.randf() < 0.3:
			state.switch_to(state.data.protagonist_ids[rng.randi_range(0, 1)])
		else:
			var command := random_command(state, rng)
			state.perform({"verb": Simulation.ROUTINE_VERB} if command.is_empty() else command)
		if step % 5 == 0:
			_check_round_trip(state, "paso %d" % step)
			checked += 1
		if step == 30:
			state.reveal_hint("q_bolsa")
			state.set_text_size(2)
	check(checked >= 10, "se comprobaron pocas instantáneas")
	return true


func test_v4_round_trip_keeps_conversations_marks_and_settings() -> bool:
	var state := new_state()
	state.cuaderno["hecho_fisura_patio"] = {"loop": 1, "by": "sazil", "time": state.data.loop_start}
	state.switch_to("akba")
	var conv := state.start_conversation("lina")
	state.play_card(conv, "presion")
	state.play_card(conv, "revelar")
	check(state.commit_conversation(conv), "Akba fuerza a Lina")
	state.switch_to("sazil")
	talk(state, "beto", ["escuchar", "silencio"])
	state.set_volume("volume_music", 0.35)
	state.set_mute(true)
	state.set_haptics("low")
	state.set_breakpoint_mode("toggle")
	state.set_breakpoint_time("40")
	state.set_breakpoint_chosen(true)
	state.set_tips_seen(true)
	check(not state.marks.is_empty() and not state.sim.s["conversations"].is_empty(), "hay marcas y conversaciones que guardar")
	_check_round_trip(state, "versión 4")
	var bad: Dictionary = state.export_snapshot()
	bad["version"] = SaveManager.SAVE_VERSION
	bad["settings"].erase("haptics")
	_write(JSON.stringify(bad))
	_check_fresh(new_state(TEST_SAVE_PATH, false, true), "ajustes incompletos")
	return true


func test_v3_save_migrates_to_v4() -> bool:
	var state := new_state()
	act(state, "observar", "mercado")
	var save: Dictionary = JSON.parse_string(JSON.stringify(state.export_snapshot()))
	save["version"] = 3
	save.erase("marks")
	save["loop"].erase("conversations")
	save["settings"] = {"reduced_motion": true, "text_size": 2}
	# Temas guionizados de la Task 05 que ahora son conversaciones con cartas.
	save["loop"]["route"].append({"t": 870, "command": {"verb": "hablar", "place": "mercado", "target": "lina", "id": "lina_hola"}})
	save["last_route"] = [{"t": 840, "command": {"verb": "hablar", "place": "mercado", "target": "lina", "id": "lina_no_vayas"}}]
	var result := SaveManager.validate(save, state.data)
	if not check(result["error"] == "", "una partida de la versión 3 se migra: %s" % result["error"]):
		return true
	var snapshot: Dictionary = result["snapshot"]
	check(snapshot["settings"].size() == SaveManager.DEFAULT_SETTINGS.size(), "los ajustes nuevos se completan por defecto")
	check(snapshot["settings"]["reduced_motion"] and snapshot["settings"]["text_size"] == 2, "los ajustes que había se conservan")
	check(snapshot["settings"]["haptics"] == "normal" and not snapshot["settings"]["tips_seen"], "vibración normal y consejos sin ver")
	check(snapshot["marks"].is_empty() and snapshot["loop"]["conversations"].is_empty(), "sin marcas ni conversaciones")
	var old: Dictionary = snapshot["last_route"][0]["command"]
	check(old["verb"] == "esperar" and old["place"] == "mercado" and old["id"] == "", "un tema que ya no existe queda como esperar allí")
	check(snapshot["loop"]["route"][-1]["command"]["verb"] == "esperar", "también en la ruta del bucle en curso")
	var loaded := new_state()
	loaded.import_snapshot(snapshot)
	check(loaded.current_time() == state.current_time() and not loaded.get_actions().is_empty(), "la partida migrada se puede jugar")
	return true


func test_autosave_after_every_action_and_switch() -> bool:
	var state := new_state(TEST_SAVE_PATH, true)
	act(state, "observar", "mercado")
	check(_saved_text(state) == snapshot_text(state), "se guarda tras cada acción")
	state.switch_to("akba")
	check(_saved_text(state) == snapshot_text(state), "se guarda tras cambiar de protagonista")
	state.skip_to(state.data.day_end)
	state.start_next_loop()
	check(_saved_text(state) == snapshot_text(state), "se guarda al empezar un bucle")
	return true


func test_corrupted_save_starts_fresh() -> bool:
	_write("{ esto no es json")
	_check_fresh(new_state(TEST_SAVE_PATH, false, true), "archivo dañado")
	return true


func test_marta_prototype_save_starts_fresh() -> bool:
	# Formato de la versión 1 (Tasks 01-02): debe descartarse con un aviso.
	_write(JSON.stringify({"version": 1, "loop_number": 3, "active_character_id": "civil",
			"knowledge": {"plan_del_sobre": 1}, "flags": {}, "active_ending_id": "",
			"characters": {"civil": {"clock": 60}, "despertado": {"clock": 0}}}))
	_check_fresh(new_state(TEST_SAVE_PATH, false, true), "partida del prototipo de Marta")
	return true


func test_unknown_ids_start_fresh() -> bool:
	var played := new_state()
	talk(played, "lina", ["silencio"])
	var mutations: Array[Callable] = [
		func(save: Dictionary) -> void: save["cuaderno"]["pista_inventada"] = {"loop": 1, "by": "sazil", "time": 840},
		func(save: Dictionary) -> void: save["loop"]["flags"]["bandera_inventada"] = 840,
		func(save: Dictionary) -> void: save["loop"]["positions"]["lina"] = "luna",
		func(save: Dictionary) -> void: save["loop"]["active"] = "rosa",
		func(save: Dictionary) -> void: save["loop"]["time"] = 845,
		func(save: Dictionary) -> void: save["velo"]["ruth"] = 7,
		func(save: Dictionary) -> void: save["loop"]["route"].append({"t": 840, "command": {"verb": "volar", "place": "", "target": "", "id": ""}}),
	]
	for i: int in mutations.size():
		var save: Dictionary = played.export_snapshot()
		save["version"] = SaveManager.SAVE_VERSION
		mutations[i].call(save)
		_write(JSON.stringify(save))
		_check_fresh(new_state(TEST_SAVE_PATH, false, true), "mutación %d" % i)
	return true


func _check_round_trip(state: GameStateScript, where: String) -> void:
	var original := snapshot_text(state)
	check(SaveManager.write(TEST_SAVE_PATH, state.export_snapshot()), "%s: no se pudo guardar" % where)
	var loaded := new_state(TEST_SAVE_PATH, false, true)
	check(snapshot_text(loaded) == original, "%s: la partida cargada no es idéntica" % where)
	free_state(loaded)


func _check_fresh(state: GameStateScript, where: String) -> void:
	check(state.data.is_loaded(), "%s: los datos deberían cargar" % where)
	check(state.loop_number == 1 and state.cuaderno.is_empty() and state.current_time() == state.data.loop_start,
			"%s: debería empezar una partida nueva" % where)
	check(state.active_actor() == state.data.start_active and not state.get_actions().is_empty(),
			"%s: la partida nueva se puede jugar" % where)


func _saved_text(state: GameStateScript) -> String:
	var result := SaveManager.validate(read_json(TEST_SAVE_PATH), state.data)
	check(result["error"] == "", "el archivo guardado es válido: %s" % result["error"])
	return JSON.stringify(result["snapshot"], "", false)


func _write(text: String) -> void:
	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()
