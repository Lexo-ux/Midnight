extends "res://scripts/dev/tests/test_suite.gd"
## El Cuaderno del Umbral: sobrevive a los bucles y al guardado; el Velo 1
## llega al conocer el horario completo; las pistas pedidas no tocan la simulación.


func test_entries_persist_across_loops_and_saves() -> bool:
	var state := new_state(TEST_SAVE_PATH, true)
	act(state, "hablar", "mercado", "beto", "beto_titular")
	check(state.has_clue("rumor_titular_panadera"), "el titular de Beto se apunta")
	var entry: Dictionary = state.cuaderno["rumor_titular_panadera"]
	check(entry["loop"] == 1 and entry["by"] == "sazil" and entry["time"] == GameData.parse_time("14:00"),
			"la entrada recuerda bucle, quién y a qué hora")
	state.skip_to(state.data.day_end)
	state.start_next_loop()
	check(state.has_clue("rumor_titular_panadera") and state.has_clue("final_otra_vez"), "el Cuaderno sobrevive a medianoche")
	var loaded := new_state(TEST_SAVE_PATH, false, true)
	check(loaded.cuaderno == state.cuaderno, "el Cuaderno sobrevive a guardar y cargar")
	check(loaded.loop_number == 2, "la partida cargada sigue en el bucle 2")
	return true


func test_velo_one_needs_the_full_schedule() -> bool:
	var state := new_state()
	state.switch_to("akba")
	act(state, "observar", "mercado", "lina")
	check(state.velo_level("lina") == 0, "Akba solo apunta el tramo de ahora: Lina sigue en silueta")
	state.switch_to("sazil")
	act(state, "observar", "mercado", "lina")
	for segment: Dictionary in state.data.relevant_schedule("lina"):
		check(state.has_clue("horario_" + segment["id"]), "Sazil apunta el horario entero de Lina")
	check(state.velo_level("lina") == 1, "con el horario completo, Lina pasa a Velo 1")
	check(state.velo_level("ruth") == 0, "los demás siguen en silueta")
	return true


func test_hints_do_not_touch_the_simulation() -> bool:
	var state := new_state()
	act(state, "observar", "mercado")
	var before := loop_text(state)
	var cuaderno_before: Dictionary = state.cuaderno.duplicate(true)
	for i: int in 4:
		state.reveal_hint("q_bolsa")
	check(state.hints["q_bolsa"] == 3, "hay tres niveles de pista y no más")
	check(loop_text(state) == before, "pedir pistas no cambia el bucle")
	check(state.cuaderno == cuaderno_before, "pedir pistas no añade nada al Cuaderno")
	state.skip_to(state.data.day_end)
	state.start_next_loop()
	check(state.hints["q_bolsa"] == 3, "las pistas pedidas se recuerdan entre bucles")
	return true


func test_questions_open_from_clues() -> bool:
	var state := new_state()
	var visible: PackedStringArray = []
	for item: Dictionary in state.get_questions():
		visible.append(item["question"]["id"])
	check(visible == PackedStringArray(["q_bolsa"]), "al empezar solo hay una pregunta, la de la bolsa: %s" % [visible])
	act(state, "leer", "mercado", "", "orden_lina")
	visible.clear()
	for item: Dictionary in state.get_questions():
		visible.append(item["question"]["id"])
		if item["question"]["id"] == "q_bolsa":
			check(item["resolved"], "leer la carta resuelve la pregunta de la bolsa")
	check(visible.has("q_lina") and visible.has("q_ruth"), "la línea tachada abre preguntas sobre Lina y Ruth: %s" % [visible])
	return true
