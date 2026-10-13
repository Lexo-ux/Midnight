extends "res://scripts/dev/tests/test_suite.gd"
## Recorridos guionizados hasta «Otra vez» y «Un buen día» (cada final tiene al
## menos uno con una conversación con cartas y un momento de quiebre), el Velo 3
## de quien se salva, y la prueba de que «Un buen día» solo se alcanza con las
## acciones pensadas para ello: si se prohíben, el validador de bucles (con el
## Cuaderno completo) ya no lo encuentra.

const OTRA_VEZ: String = "res://data/dev/walkthrough_otra_vez.json"
const BUEN_DIA: String = "res://data/dev/walkthrough_un_buen_dia.json"
const BUEN_DIA_QUIEBRES: String = "res://data/dev/walkthrough_un_buen_dia_quiebres.json"
const WALKTHROUGHS: Array[String] = [OTRA_VEZ, BUEN_DIA, BUEN_DIA_QUIEBRES]


func test_walkthrough_otra_vez() -> bool:
	_check_walkthrough(OTRA_VEZ)
	return true


func test_walkthrough_un_buen_dia() -> bool:
	_check_walkthrough(BUEN_DIA)
	return true


func test_walkthrough_un_buen_dia_with_breakpoints() -> bool:
	_check_walkthrough(BUEN_DIA_QUIEBRES)
	return true


func test_every_ending_has_a_run_with_a_conversation_and_a_breakpoint() -> bool:
	var data := new_state().data
	var covered: Dictionary = {}
	for path: String in WALKTHROUGHS:
		var walkthrough: Dictionary = read_json(path)
		var conversation := false
		var sustained := false
		for step: Dictionary in walkthrough["steps"]:
			var command: Dictionary = step.get("act", {})
			conversation = conversation or (command.get("verb", "") == "hablar" and data.conversations.has(command.get("id", "")))
			sustained = sustained or data.breakpoint_by_interaction.has(command.get("id", ""))
		if conversation and sustained:
			covered[walkthrough["expected_ending"]] = true
	for ending: Dictionary in data.endings:
		check(covered.has(ending["id"]), "el final «%s» tiene un recorrido con conversación y quiebre" % ending["id"])
	return true


func test_saving_people_gives_velo_three() -> bool:
	var untouched := new_state()
	untouched.skip_to(untouched.data.day_end)
	for person: String in untouched.data.npc_ids():
		check(untouched.velo_level(person) == 0, "un día sin tocar no da Velo a %s" % person)
	var state := new_state()
	play_walkthrough(state, read_json(BUEN_DIA_QUIEBRES))
	for person: String in ["lina", "tun", "beto"]:
		check(state.velo_level(person) == 3, "salvar a %s da Velo 3" % person)
	check(state.velo_level("marcos") == 0, "Marcos no tiene Velo 3 por salvarlo")
	return true


func test_un_buen_dia_needs_the_intended_actions() -> bool:
	var data := new_state().data
	var validator := LoopValidator.new(data)
	var everything := _full_cuaderno(data)
	var ending: String = read_json(BUEN_DIA)["expected_ending"]
	check(validator.explore_loop(everything)["found"].has("ending:" + ending),
			"con el Cuaderno completo, «Un buen día» se puede alcanzar")
	var intended: Dictionary = read_json(BUEN_DIA)["intended"]
	for requirement: String in intended:
		var banned: Dictionary = {}
		for id: String in intended[requirement]:
			banned[id] = true
		var found: Dictionary = validator.explore_loop(everything, banned)["found"]
		check(not found.has("ending:" + ending),
				"sin %s, «Un buen día» no debería alcanzarse (requisito «%s»)" % [intended[requirement], requirement])
	return true


func _check_walkthrough(path: String) -> void:
	var walkthrough: Dictionary = read_json(path)
	var state := new_state()
	if not play_walkthrough(state, walkthrough):
		return
	check(state.is_loop_over(), "%s: el recorrido debería llegar a medianoche" % path.get_file())
	check(state.ending_id() == walkthrough["expected_ending"],
			"%s: final esperado %s, llegó «%s»" % [path.get_file(), walkthrough["expected_ending"], state.ending_id()])
	check(state.loop_number == walkthrough["expected_loop"],
			"%s: se esperaba el bucle %d, llegó al %d" % [path.get_file(), walkthrough["expected_loop"], state.loop_number])
	check(state.endings_seen.has(state.ending_id()) and state.has_clue("final_" + state.ending_id()),
			"%s: el final queda en el Cuaderno" % path.get_file())


func _full_cuaderno(data: GameData) -> Dictionary:
	var cuaderno: Dictionary = {}
	for id: String in data.clue_ids:
		cuaderno[id] = {"loop": 1, "by": data.start_active, "time": data.loop_start}
	return cuaderno
