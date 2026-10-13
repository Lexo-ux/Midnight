extends "res://scripts/dev/tests/test_suite.gd"
## Interfaz de la Task 04 sobre la escena principal (con el autoload GameState,
## sin guardar nada): caras según el Velo (y el arte de verdad sustituyendo al
## provisional), el botón «atrás» que cierra lo de más arriba y nunca sale,
## los consejos una sola vez, la pantalla de conversación (con la marca de
## forzar) y la de quiebre (elegir modo una vez, decidir, continuar).

const MAIN_SCENE := preload("res://scenes/main.tscn")
const PortraitView := preload("res://scripts/portrait_view.gd")


func test_portrait_follows_velo_and_real_art_replaces_placeholders() -> bool:
	var data := new_state().data
	var art := ArtLibrary.new()
	art.load_manifest()
	for person: String in data.npc_ids():
		for level: int in [2, 3]:
			var slot := ArtLibrary.face_slot(person, level)
			check(art.slots.has(slot) and art.slots[slot]["fallback"] == "placeholder", "hay ranura provisional %s" % slot)
	var view: Control = add_node(PortraitView.new())
	view.size = Vector2(200, 200)
	for level: int in [0, 1]:
		view.show_person(data, art, "lina", level)
		check(view.mode == "silhouette", "Velo %d: silueta" % level)
	for level: int in [2, 3]:
		view.show_person(data, art, "lina", level)
		check(view.mode == "placeholder", "Velo %d sin arte: cara provisional" % level)
	var with_art := ArtLibrary.new()
	with_art.load_manifest()
	with_art.slots["npc_lina_velo2"]["path"] = "res://icon.svg"
	view.show_person(data, with_art, "lina", 2)
	check(view.mode == "art", "cuando llega el arte de la comunidad, se usa sin tocar código")
	view.show_person(data, art, "sazil", 0)
	var real := art.has_file(ArtLibrary.portrait_slot("sazil", "idle"))
	check(view.mode == ("portrait" if real else "silhouette"), "los protagonistas enseñan su retrato de verdad")
	return true


func test_back_closes_the_top_overlay_and_never_quits() -> bool:
	var main := _main(false)
	var tips: Control = main.get_node("%TipsView")
	var conv: Control = main.get_node("%ConversationView")
	var settings: Control = main.get_node("%SettingsView")
	check(tips.visible, "en la primera partida salen los consejos")
	main.go_back()
	check(not tips.visible and GameState.settings["tips_seen"], "atrás cierra los consejos y no vuelven a salir")
	var time := GameState.current_time()
	conv.open("lina")
	main.go_back()
	check(not conv.visible and GameState.current_time() == time, "sin cartas jugadas, atrás deja la conversación gratis")
	conv.open("lina")
	GameState.play_card(conv.conv, "escuchar")
	main.go_back()
	check(conv.visible and conv.get_node("%Confirm").visible, "con cartas jugadas, atrás pregunta antes de salir")
	main.go_back()
	check(conv.visible and not conv.get_node("%Confirm").visible, "atrás otra vez sigue hablando")
	main.go_back()
	conv.get_node("%ConfirmYes").pressed.emit()
	check(not conv.visible and GameState.current_time() == time + GameState.data.step_minutes,
			"dejarla con cartas jugadas cuenta como media hora")
	main.go_back()
	check(settings.visible and main.is_inside_tree(), "sin nada abierto, atrás abre Ajustes (nunca sale)")
	main.go_back()
	check(not settings.visible, "y atrás los cierra")
	var again := _main(true)
	check(not again.get_node("%TipsView").visible, "con los consejos vistos no vuelven a salir")
	return true


func test_conversation_screen_shows_the_forced_mark() -> bool:
	var main := _main(true)
	GameState.cuaderno["hecho_fisura_patio"] = {"loop": 1, "by": "sazil", "time": GameState.data.loop_start}
	GameState.switch_to("akba")
	var conv: Control = main.get_node("%ConversationView")
	conv.open("lina")
	check(conv.get_node("%Cards").get_child_count() == conv.conv["hand"].size() and conv.conv["hand"].size() == 5,
			"una carta por cada una de la mano (4 del mazo y 1 de Conocimiento)")
	GameState.play_card(conv.conv, "presion")
	conv._render()
	check(conv.element_text(0).contains(GameState.data.text("conv_roto")), "el muro roto se ve roto")
	GameState.play_card(conv.conv, "revelar")
	conv._render()
	check(conv.get_node("%Result").visible and conv.get_node("%ResultText").visible, "ganar a la fuerza avisa de la marca")
	conv.get_node("%Continue").pressed.emit()
	check(GameState.marks.has("lina") and not conv.visible, "al continuar cuenta y Lina queda marcada")
	return true


func test_breakpoint_screen_choice_decision_and_resolution() -> bool:
	var main := _main(true)
	GameState.perform({"verb": "esperar", "place": "relojeria", "target": "", "id": ""})
	GameState.perform({"verb": "hablar", "place": "mercado", "target": "lina", "id": "conv_lina", "cards": ["escuchar", "silencio", "escuchar"]})
	var action: Dictionary = {}
	for candidate: Dictionary in GameState.breakpoint_actions():
		if candidate["id"] == "tirar_de_lina":
			action = candidate
	if not check(not action.is_empty(), "a las 15:00 está el quiebre de Lina"):
		return true
	var view: Control = main.get_node("%BreakpointView")
	view.open(action)
	check(view.get_node("%Choice").visible and not view.get_node("%Controls").visible, "la primera vez se elige cómo sostener")
	GameState.set_breakpoint_time("none")
	view.get_node("%ChoiceOk").pressed.emit()
	check(GameState.settings["breakpoint_chosen"] and view.controller != null and not view.controller.is_timed(),
			"elegido «sin tiempo»: no hay anillo")
	view.get_node("%Sustain").pressed.emit()
	check(view.get_node("%Done").visible and view.controller.result == "sostuvo", "sin tiempo, sostener decide")
	var time := GameState.current_time()
	view.get_node("%DoneContinue").pressed.emit()
	check(not view.visible and GameState.current_time() == time + GameState.data.step_minutes, "continuar hace el quiebre (media hora)")
	check(GameState.sim.s["flags"].has("lina_salvada"), "y Lina queda a salvo")
	check(GameState.sim.s["route"][-1]["command"].get("decision", "") == "sostuvo", "la partida solo recibe la decisión")
	return true


## La escena principal sobre una partida nueva del autoload, sin guardar.
func _main(tips_seen: bool) -> Control:
	GameState.autosave_enabled = false
	GameState.new_game()
	for key: String in SaveManager.DEFAULT_SETTINGS:
		GameState.settings[key] = SaveManager.DEFAULT_SETTINGS[key]
	GameState.settings["tips_seen"] = tips_seen
	var main: Control = add_node(MAIN_SCENE.instantiate())
	main.size = Vector2(1080, 1920)
	return main
