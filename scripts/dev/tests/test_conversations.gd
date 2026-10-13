extends "res://scripts/dev/tests/test_suite.gd"
## Conversaciones con cartas (data/cards.json, scripts/conversation.gd): muros y
## puertas, cada tipo de carta, Confianza, turnos, la victoria a la fuerza que
## marca a la persona, el Velo 2-3 y que una conversación sin cartas no cuesta nada.


func test_listening_reveals_in_order_and_silence_is_free() -> bool:
	var state := new_state()
	var conv := state.start_conversation("lina")
	check(conv["turns"] == 4 and conv["confianza"] == 3, "se empieza con 4 turnos y Confianza 3")
	check(conv["hand"] == ["escuchar", "verdad_lina_no_ir", "silencio", "escuchar"], "la mano son las 4 primeras del mazo: %s" % [conv["hand"]])
	state.play_card(conv, "silencio")
	check(conv["turns"] == 4 and conv["lines"].size() == 2, "Silencio no gasta turno y da otra frase")
	state.play_card(conv, "escuchar")
	check(conv["revealed"].has("lina_muro_ruth") and conv["clues"].has("clave_lina_ruth"), "Escuchar descubre el primer muro y lo apunta")
	check(conv["turns"] == 3, "Escuchar gasta un turno")
	state.play_card(conv, "escuchar")
	check(conv["revealed"].has("lina_no_ir"), "el segundo Escuchar descubre la puerta siguiente")
	check(not state.play_card(conv, "presion"), "no se puede jugar una carta que no está en la mano")
	return true


func test_truth_needs_known_walls_and_its_condition() -> bool:
	var state := new_state()
	var conv := state.start_conversation("lina")
	state.play_card(conv, "verdad_lina_no_ir")
	check(conv["result"] == "" and conv["confianza"] == 2, "Verdad con el muro sin descubrir cuesta 1 de Confianza")
	conv = state.start_conversation("lina")
	state.play_card(conv, "escuchar")
	state.play_card(conv, "verdad_lina_no_ir")
	check(conv["result"] == "" and conv["confianza"] == 2, "sin saber lo de la fisura, la puerta no se abre")
	_know(state, ["hecho_fisura_patio"])
	conv = state.start_conversation("lina")
	state.play_card(conv, "escuchar")
	state.play_card(conv, "verdad_lina_no_ir")
	check(conv["result"] == "win" and conv["door"] == "lina_no_ir" and not conv["forced"],
			"con el muro descubierto y la condición, Verdad abre la puerta")
	return true


func test_pressure_breaks_walls_and_hurts_fragile_people_more() -> bool:
	var state := new_state()
	state.switch_to("akba")
	var conv := state.start_conversation("lina")
	state.play_card(conv, "presion")
	check(conv["broken"].has("lina_muro_ruth") and conv["clues"].has("clave_lina_ruth"), "Presión rompe el primer muro")
	check(conv["confianza"] == 2, "Presión cuesta 1 de Confianza")
	conv = state.start_conversation("tun")
	state.play_card(conv, "presion")
	check(conv["confianza"] == 1, "Tun es frágil: Presión le cuesta 2")
	return true


func test_revelar_depends_on_the_person() -> bool:
	var state := new_state()
	state.switch_to("akba")
	var conv := state.start_conversation("beto")
	state.play_card(conv, "revelar")
	check(conv["confianza"] == 5, "a Beto, Revelar lo convence (+2)")
	conv = state.start_conversation("tun")
	state.play_card(conv, "revelar")
	check(conv["result"] == "closed" and conv["confianza"] == 0, "a Tun, Revelar lo aterra y se cierra")
	conv = state.start_conversation("lina")
	state.play_card(conv, "revelar")
	check(conv["result"] == "" and conv["confianza"] == 2, "a Lina, Revelar sin poder abrir cuesta Confianza")
	return true


func test_knowledge_opens_through_walls_without_force() -> bool:
	var state := new_state()
	_know(state, ["hecho_ruth_otra_vez"])
	for actor: String in state.data.protagonist_ids:
		state.switch_to(actor)
		var conv := state.start_conversation("tun")
		var card := "conocimiento:hecho_ruth_otra_vez:tun_libreta"
		check(conv["hand"].has(card), "%s: lo sabido da una carta de Conocimiento" % actor)
		state.play_card(conv, card)
		check(conv["result"] == "win" and conv["door"] == "tun_libreta" and not conv["forced"],
				"%s: Conocimiento abre la puerta aunque el muro siga ahí, sin forzar" % actor)
	var fresh := new_state()
	check(not fresh.start_conversation("tun")["hand"].any(func(card: String) -> bool: return card.begins_with("conocimiento:")),
			"sin la pista no hay carta de Conocimiento")
	return true


func test_known_walls_and_doors_start_revealed() -> bool:
	var state := new_state()
	_know(state, ["clave_lina_ruth"])
	check(state.start_conversation("lina")["revealed"].has("lina_muro_ruth"), "lo apuntado en el Cuaderno empieza descubierto")
	return true


func test_running_out_of_turns_is_neutral_and_keeps_confianza() -> bool:
	var state := new_state()
	var conv := state.start_conversation("lina")
	for card: String in ["escuchar", "escuchar", "verdad_lina_masa", "verdad_lina_no_ir"]:
		state.play_card(conv, card)
	check(conv["result"] == "neutral" and conv["turns"] == 0, "sin turnos, la conversación queda en «otro rato»")
	var kept: int = conv["confianza"]
	check(state.commit_conversation(conv), "la conversación cuenta como acción")
	check(state.sim.s["conversations"]["lina"]["confianza"] == kept, "la Confianza que queda se guarda en el bucle")
	check(state.start_conversation("lina")["confianza"] == kept, "la siguiente conversación del bucle empieza con esa Confianza")
	return true


func test_closed_person_returns_next_loop() -> bool:
	var state := new_state()
	state.switch_to("akba")
	var conv := state.start_conversation("tun")
	state.play_card(conv, "revelar")
	check(state.commit_conversation(conv), "cerrar a alguien también cuesta media hora")
	for actor: String in state.data.protagonist_ids:
		check(not state.sim.actions_for(actor).any(func(action: Dictionary) -> bool: return action["id"] == "conv_tun"),
				"%s ya no puede hablar con Tun en este bucle" % actor)
	state.skip_to(state.data.day_end)
	check(state.start_next_loop(), "empieza otro bucle")
	check(not state.sim.s["conversations"].has("tun"), "en el bucle siguiente Tun vuelve a hablar")
	return true


func test_forced_win_marks_the_person() -> bool:
	var state := new_state()
	_know(state, ["hecho_fisura_patio"])
	state.switch_to("akba")
	var rastro := state.rastro()
	var conv := state.start_conversation("lina")
	state.play_card(conv, "presion")
	state.play_card(conv, "revelar")
	check(conv["result"] == "win" and conv["forced"], "Akba gana a la fuerza (Presión y Revelar)")
	check(state.commit_conversation(conv), "la conversación forzada cuenta")
	check(state.sim.s["flags"].has("lina_no_ira"), "la puerta forzada también cambia el día")
	check(state.sim.s["flags"].has("akba_forzo") and state.rastro() == rastro + state.data.card_rules["forced_rastro"],
			"forzar cuesta Rastro y deja la marca de que Akba forzó")
	check(state.marks.get("lina", {}).get("count", 0) == 1, "Lina queda marcada")
	check(state.velo["lina"] == 2 and state.velo_level("lina") == 1, "Velo 2 ganado, pero se ve 1 por la marca")
	state.skip_to(state.data.day_end)
	state.start_next_loop()
	var next := state.start_conversation("lina")
	check(next["confianza"] == 2, "en el bucle siguiente empieza con 1 de Confianza menos")
	check(next["lines"][0] == state.data.conversations["conv_lina"]["fear"], "y con miedo")
	return true


func test_velo_two_on_a_door_and_three_on_the_secret() -> bool:
	var state := new_state()
	_know(state, ["hecho_fisura_patio"])
	var conv := state.start_conversation("lina")
	state.play_card(conv, "escuchar")
	state.play_card(conv, "verdad_lina_no_ir")
	check(state.commit_conversation(conv), "Sazil convence a Lina")
	check(state.velo_level("lina") == 2, "abrir una puerta da Velo 2 (rostro)")
	var other := new_state()
	_know(other, ["hecho_lina_desaparece"])
	conv = other.start_conversation("lina")
	other.play_card(conv, "conocimiento:hecho_lina_desaparece:lina_infancia")
	check(conv["result"] == "win" and conv["door"] == "lina_infancia", "Conocimiento abre la segunda puerta de Lina")
	check(other.commit_conversation(conv), "la conversación cuenta")
	check(other.has_clue("secreto_lina_nina") and other.velo_level("lina") == 3, "su secreto da Velo 3 (retrato)")
	return true


func test_leaving_without_cards_costs_nothing() -> bool:
	var state := new_state()
	var before := snapshot_text(state)
	check(not state.commit_conversation(state.start_conversation("lina")), "sin cartas no hay acción")
	check(not state.perform({"verb": "hablar", "place": state.position_of("lina"), "target": "lina", "id": "conv_lina"}),
			"«hablar» con una conversación necesita cartas")
	check(not state.perform({"verb": "esperar", "place": "mercado", "target": "", "id": "", "cards": ["escuchar"]}),
			"las cartas solo valen en una conversación")
	check(snapshot_text(state) == before, "abrir y dejar una conversación no cambia la partida")
	return true


func test_cards_out_of_decks_and_scripted_marcos() -> bool:
	var data := new_state().data
	check(data.cards.has("recordar") and data.cards["recordar"]["type"] == "recordar", "Recordar existe en los datos (gancho)")
	for id: String in data.conversations:
		for actor: String in data.protagonist_ids:
			check(not Array(data.conversations[id]["decks"][actor]).has("recordar"), "%s: Recordar no está en ningún mazo" % id)
	check(not data.conversation_by_person.has("marcos"), "Marcos sigue con temas guionizados")
	check(data.talks.values().any(func(talk: Dictionary) -> bool: return talk["person"] == "marcos"), "Marcos tiene sus temas")
	for person: String in ["lina", "tun", "beto", "ruth"]:
		check(data.conversation_by_person.has(person), "%s tiene conversación con cartas" % person)
	return true


func _know(state: GameStateScript, ids: Array[String]) -> void:
	for id: String in ids:
		state.cuaderno[id] = {"loop": 1, "by": "sazil", "time": state.data.loop_start}
