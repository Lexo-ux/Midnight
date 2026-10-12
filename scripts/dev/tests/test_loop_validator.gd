extends "res://scripts/dev/tests/test_suite.gd"
## El validador de bucles: los datos reales pasan (todas las pistas de la
## ventana y todos los finales son alcanzables) y un final imposible por la hora
## se detecta.


func test_real_data_passes_the_loop_validator() -> bool:
	var data := new_state().data
	var validator := LoopValidator.new(data)
	var report := validator.validate()
	check(report["problems"].is_empty(), "el validador encontró problemas: %s" % [report["problems"]])
	var result: Dictionary = report["result"]
	print("        %d pasadas, %d estados, %d pistas, finales %s" % [result["passes"], result["states"],
			result["clues"].size(), result["endings"]])
	var graph := validator.clue_graph_markdown(result)
	check(graph.contains("flowchart LR") and graph.contains("FINAL_un_buen_dia"), "el grafo de pistas incluye los finales")
	return true


func test_ending_impossible_by_time_is_reported() -> bool:
	# Sostener a Lina exige que esté al borde a las 15:00, y eso exige que el patio
	# NO esté sellado antes: pedir las dos cosas a la vez es imposible por la hora.
	var sources := data_sources()
	sources["endings"]["endings"][0]["if"] = {"ALL": ["patio_sellado", "lina_sostenida", "akba_forzo"]}
	var data := GameData.new()
	if not check(data.load_sources(sources), "la copia debería pasar la validación estática: %s" % [data.errors]):
		return true
	var everything: Dictionary = {}
	for id: String in data.clue_ids:
		everything[id] = {"loop": 1, "by": data.start_active, "time": data.loop_start}
	var problems: PackedStringArray = LoopValidator.new(data).validate(everything)["problems"]
	var reported := false
	for problem: String in problems:
		reported = reported or problem.contains("el final \"un_buen_dia\" es inalcanzable")
	check(reported, "el validador debería avisar de que «Un buen día» es inalcanzable: %s" % [problems])
	return true
