extends "res://scripts/dev/tests/test_suite.gd"
## Task 05: escenas por las que se camina. La cámara (límites y mirar
## alrededor gratis), las estaciones (deterministas, guardadas y repetidas con
## «Repetir mi ruta»), los puntos interactivos (mirada, ventana y mismo
## resultado que observar), las dos miradas y el mapa (gratis, sin lugares por
## explorar elegibles y sin desvelar rutinas que no se saben).


func test_camera_clamp_is_pure_and_bounded() -> bool:
	check(SceneRules.clamp_camera(-100.0, 1000.0, 2880.0) == 500.0, "no se sale por la izquierda")
	check(SceneRules.clamp_camera(5000.0, 1000.0, 2880.0) == 2380.0, "no se sale por la derecha")
	check(SceneRules.clamp_camera(1200.0, 1000.0, 2880.0) == 1200.0, "dentro del lienzo no cambia")
	check(SceneRules.clamp_camera(10.0, 3000.0, 2880.0) == 1440.0, "una vista más ancha que el lienzo se centra")
	check(SceneRules.clamp_camera(777.0, 1000.0, 2880.0) == SceneRules.clamp_camera(777.0, 1000.0, 2880.0), "es pura")
	return true


func test_free_look_never_touches_the_simulation() -> bool:
	var state := new_state()
	var view := new_place_view(state)
	view.refresh("mercado", false, "")
	var before := snapshot_text(state)
	var half: float = view.view_width() * 0.5
	for dx: float in [300.0, -900.0, 9000.0, -9000.0, 42.0, -3.0]:
		view.pan_by(dx)
		check(view.camera_x >= half - 0.01 and view.camera_x <= state.data.canvas_size.x - half + 0.01,
				"la cámara se queda dentro del lienzo (%.0f)" % view.camera_x)
	check(snapshot_text(state) == before, "mirar alrededor no cambia la partida ni la hora")
	act(state, "esperar", "mercado")
	view.refresh("mercado", false, "")
	view.focus_x(state.data.station_x("mercado", state.station_of("sazil", "mercado")), 0.0)
	check(is_equal_approx(view.camera_x, SceneRules.clamp_camera(state.data.station_x("mercado", state.station_of("sazil", "mercado")),
			view.view_width(), state.data.canvas_size.x)), "tras la acción la cámara vuelve a la estación")
	return true


func test_stations_follow_the_last_action() -> bool:
	var state := new_state()
	check(state.hands_state("sazil") == "idle", "al empezar, manos en reposo")
	act(state, "observar", "mercado", "lina")
	check(state.station_of("sazil", "mercado") == "pan", "observar a Lina lleva a su puesto")
	check(state.hands_state("sazil") == "point", "observar: Sazil señala")
	act(state, "esperar", "mercado")
	check(state.station_of("sazil", "mercado") == "callejon", "esperar avanza a la siguiente estación")
	act(state, "esperar", "mercado")
	check(state.station_of("sazil", "mercado") == "hierbas", "y a la siguiente")
	act(state, "esperar", "plaza")
	check(state.station_of("sazil", "plaza") == "centro", "llegar esperando deja en la entrada")
	check(state.perform_hotspot("plaza_de_siempre"), "Sazil puede tocar la plaza de siempre")
	check(state.station_of("sazil", "plaza") == "centro", "el punto lleva a su estación")
	act(state, "leer", "plaza", "", "orden_lina")
	check(state.station_of("sazil", "plaza") == "centro", "leer la carta no mueve")
	check(state.hands_state("sazil") == "hold_letter", "leer: la carta en las manos")
	check(state.station_of("akba", "plaza") == "", "Akba aún no ha hecho nada allí")
	state.switch_to("akba")
	act(state, "observar", "plaza")
	check(state.hands_state("akba") == "light" and state.hands_state("sazil") == "hold_letter", "Akba alza el colgante; Sazil sigue con la carta")
	check(state.station_of("akba", "plaza") == "centro", "observar el lugar lleva a su estación de observar")
	return true


func test_stations_are_deterministic_saved_and_replayed() -> bool:
	var a := new_state()
	var b := new_state()
	for state: GameStateScript in [a, b]:
		act(state, "retener", "mercado", "", "orden_lina")
		act(state, "hablar", "mercado", "marcos", "marcos_sazil")
		state.switch_to("akba")
		check(state.perform_hotspot("callejon_frio"), "Akba toca el frío del callejón")
		state.switch_to("sazil")
		act(state, "esperar", "plaza")
		act(state, "esperar", "plaza")
	check(JSON.stringify(a.sim.s["stations"]) == JSON.stringify(b.sim.s["stations"]), "mismas acciones, mismas estaciones")
	check(a.station_of("akba", "mercado") == "callejon", "el punto deja a Akba en su estación")
	check(SaveManager.write(TEST_SAVE_PATH, a.export_snapshot()), "se guarda")
	var loaded := new_state(TEST_SAVE_PATH, false, true)
	check(snapshot_text(loaded) == snapshot_text(a), "las estaciones (y la estación del punto en la ruta) vuelven igual")
	var stations: String = JSON.stringify(a.sim.s["stations"])
	a.skip_to(a.data.day_end)
	a.start_next_loop()
	check(a.replay_route(a.data.day_end), "se repite la ruta")
	check(JSON.stringify(a.sim.s["stations"]) == stations, "«Repetir mi ruta» deja las mismas estaciones")
	return true


func test_version_two_save_migrates_without_stations() -> bool:
	var played := new_state()
	act(played, "observar", "mercado", "lina")
	var save: Dictionary = played.export_snapshot()
	save["version"] = 2
	save["loop"].erase("stations")
	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(save))
	file.close()
	var loaded := new_state(TEST_SAVE_PATH, false, true)
	check(loaded.loop_number == played.loop_number and loaded.current_time() == played.current_time(), "la partida de la versión 2 se carga")
	check(loaded.station_of("sazil", "mercado") == "", "sin estaciones: la cámara irá a la entrada")
	check(loaded.has_clue("horario_lina_mercado"), "el Cuaderno se conserva")
	return true


func test_hotspots_exist_only_in_their_look_and_window() -> bool:
	var data := new_state().data
	var grieta: Dictionary = data.hotspots["grieta_pozo"]
	check(SceneRules.hotspot_visible(grieta, "akba", 840), "la grieta se ve con Akba a las 14:00")
	check(not SceneRules.hotspot_visible(grieta, "sazil", 840), "Sazil no ve la grieta")
	check(not SceneRules.hotspot_visible(grieta, "akba", 900), "a las 15:00 la grieta ya no está (es la fisura)")
	check(SceneRules.hotspot_visible(data.hotspots["fisura_patio"], "akba", 900), "la fisura existe desde las 15:00")
	var state := new_state()
	var view := new_place_view(state)
	view.refresh("relojeria", false, "")
	check(view.visible_hotspot_ids().has("escaparate_relojes") and not view.visible_hotspot_ids().has("grieta_pozo"),
			"con la mirada de Sazil solo están sus puntos: %s" % [view.visible_hotspot_ids()])
	state.switch_to("akba")
	view.refresh("relojeria", false, "")
	check(view.visible_hotspot_ids().has("grieta_pozo") and not view.visible_hotspot_ids().has("escaparate_relojes"),
			"con la de Akba, la grieta: %s" % [view.visible_hotspot_ids()])
	check(not state.perform_hotspot("escaparate_relojes"), "Akba no puede tocar un punto de Sazil")
	return true


func test_touching_a_hotspot_is_observing_the_place() -> bool:
	var by_hotspot := new_state()
	var by_action := new_state()
	for state: GameStateScript in [by_hotspot, by_action]:
		state.switch_to("akba")
	check(by_hotspot.perform_hotspot("grieta_pozo"), "se toca la grieta")
	act(by_action, "observar", "relojeria")
	check(world_without_view(by_hotspot) == world_without_view(by_action), "el mundo queda igual que al observar")
	check(by_hotspot.outcome_lines() == by_action.outcome_lines() and by_hotspot.outcome_clues() == by_action.outcome_clues(),
			"mismas líneas y mismas pistas")
	check(by_hotspot.has_clue("hecho_grieta_dormida") and by_hotspot.hotspot_discovered("grieta_pozo"), "la pista queda en el Cuaderno")
	check(by_hotspot.current_time() == by_hotspot.data.loop_start + by_hotspot.data.step_minutes, "cuesta los 30 minutos de siempre")
	return true


func test_every_hotspot_points_to_something_real() -> bool:
	var data := new_state().data
	for id: String in data.hotspots:
		var hotspot: Dictionary = data.hotspots[id]
		var exists := false
		match hotspot["link_kind"]:
			"clue":
				exists = data.clues.has(hotspot["link_id"])
			"letter":
				exists = data.letters.has(hotspot["link_id"])
			"event":
				exists = data.events.any(func(event: Dictionary) -> bool: return event["id"] == hotspot["link_id"])
		check(exists, "el punto %s enlaza algo que existe" % id)
		check(data.scenes[hotspot["place"]]["station_index"].has(hotspot["station"]), "el punto %s está en una estación" % id)
	var sources := data_sources()
	sources["scenes"]["places"]["plaza"]["hotspots"][0]["link"] = {"clue": "pista_inventada"}
	var broken := GameData.new()
	check(not broken.load_sources(sources), "un punto con un enlace inventado no pasa la validación")
	check(" ".join(broken.errors).contains("pista_inventada"), "y el error lo nombra: %s" % [broken.errors])
	return true


func test_switching_changes_the_look_only() -> bool:
	var state := new_state()
	var view := new_place_view(state)
	act(state, "esperar", "relojeria")
	view.refresh("relojeria", false, "")
	check(view.look == "sazil" and not view._overlay.visible, "mirada cálida de Sazil, sin superposición")
	var world := world_without_view(state, ["active"])
	var time := state.current_time()
	state.switch_to("akba")
	view.refresh(state.position_of("sazil"), true, "")
	check(view.look == "akba" and view._overlay.visible, "mirada de Akba con su superposición")
	check(world_without_view(state, ["active"]) == world and state.current_time() == time, "la simulación no cambia")
	for i: int in 31:
		state.switch_to(state.data.protagonist_ids[i % 2])
		view.refresh(state.position_of("sazil"), state.active_actor() != "sazil", "")
	check(view.look == state.active_actor(), "tras cambiar muy rápido, la mirada es la del activo")
	check(world_without_view(state, ["active"]) == world, "y el mundo sigue igual")
	return true


func test_map_is_free_and_shows_only_what_is_known() -> bool:
	var state := new_state()
	var map := new_map_view(state)
	var before := snapshot_text(state)
	map.open()
	map.hide()
	map.open()
	check(snapshot_text(state) == before, "abrir y cerrar el mapa no cuesta nada")
	check(map.node_button("plaza") != null and not map.node_button("plaza").disabled, "la plaza se puede elegir")
	check(map.node_button("correos") != null and map.node_button("correos").disabled, "Correos (sin explorar) no se puede elegir")
	for node: Dictionary in state.map_nodes():
		check(node["selectable"] == state.data.has_scene(node["place"]), "solo los lugares con escena se eligen (%s)" % node["place"])
		check(node["people"].is_empty(), "sin rutinas sabidas no se ve a nadie (%s)" % node["place"])
	state.velo["lina"] = 1
	var lina_seen := false
	for node: Dictionary in state.map_nodes():
		lina_seen = lina_seen or node["people"].has("lina")
		check(not node["people"].has("beto"), "a Beto (rutina sin saber) no se le ve")
	check(lina_seen, "con su rutina entera en el Cuaderno, Lina sale en el mapa")
	return true


func test_map_travel_uses_the_existing_costs() -> bool:
	var state := new_state()
	var map := new_map_view(state)
	var chosen: Array[String] = []
	map.place_chosen.connect(func(place: String) -> void: chosen.append(place))
	map.open()
	var before := snapshot_text(state)
	map.node_button("relojeria").pressed.emit()
	check(chosen == ["relojeria"] and not map.visible, "tocar un lugar lo elige y cierra el mapa")
	check(snapshot_text(state) == before, "elegirlo en el mapa no cuesta nada")
	var start := state.current_time()
	act(state, "esperar", "relojeria")
	check(state.current_time() == start + 30 and state.position_of("sazil") == "relojeria", "ir y esperar allí: 30 minutos, como siempre")
	act(state, "observar", "plaza")
	check(state.current_time() == start + 60 and state.position_of("sazil") == "plaza", "actuar en otro lugar lleva allí en la misma acción")
	return true
