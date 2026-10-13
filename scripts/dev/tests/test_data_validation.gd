extends "res://scripts/dev/tests/test_suite.gd"
## Los datos reales pasan la validación y contienen el corte vertical; copias
## rotas a propósito fallan con el mensaje esperado.

const BROKEN_FILE_PATH: String = "user://test_broken.json"


func test_real_data_is_valid() -> bool:
	var data := GameData.new()
	check(data.load_all(), "los datos reales deberían ser válidos: %s" % [data.errors])
	return true


func test_slice_content_is_present() -> bool:
	var data := GameData.new()
	if not check(data.load_all(), "los datos reales no cargan"):
		return true
	check(data.visible_location_ids() == ["relojeria", "mercado", "plaza"], "los lugares visibles son relojería, mercado y plaza")
	check(data.npc_ids() == ["ruth", "tun", "lina", "marcos", "beto"], "los habitantes del corte son Ruth, Tun, Lina, Marcos y Beto")
	check(data.protagonist_ids == ["sazil", "akba"], "los protagonistas son Sazil y Akba")
	check(data.loop_start == GameData.parse_time("14:00") and data.day_end == GameData.parse_time("24:00"),
			"la ventana del corte es de 14:00 a 24:00")
	check((data.day_end - data.loop_start) / data.step_minutes == 20, "el corte tiene 20 acciones")
	var event_times: Dictionary = {}
	for event: Dictionary in data.events:
		event_times[event["id"]] = event["time"]
	check(event_times.get("fisura_patio") == GameData.parse_time("15:00"), "la fisura del patio es a las 15:00")
	check(event_times.get("tun_llega") == GameData.parse_time("20:00"), "Tun llega a la plaza a las 20:00")
	check(event_times.get("patrulla") == GameData.parse_time("21:00"), "la patrulla es a las 21:00")
	var marcos_arrives := false
	for segment: Dictionary in data.people["marcos"]["routine"]:
		if segment["schedule"] and segment["from"] == GameData.parse_time("14:00"):
			marcos_arrives = true
	check(marcos_arrives, "Marcos llega en el tren de las 14:00")
	var types: Dictionary = {}
	for id: String in data.clue_ids:
		types[data.clues[id]["type"]] = true
	for type: String in GameData.CLUE_TYPES:
		check(types.has(type), "hay pistas de tipo %s" % type)
	check(data.letters["orden_lina"]["recipient"] == "lina", "Sazil lleva el pedido que manda a Lina al taller")
	return true


func test_broken_copies_fail_with_clear_messages() -> bool:
	var cases: Array[Dictionary] = [
		{"name": "clave desconocida", "expect": "clave desconocida \"labell\"",
			"mutate": func(s: Dictionary) -> void: s["npcs"]["people"][5]["talks"][0]["labell"] = "x"},
		{"name": "lugar desconocido en una rutina", "expect": "lugar desconocido \"luna\"",
			"mutate": func(s: Dictionary) -> void: s["npcs"]["people"][2]["routine"][1]["place"] = "luna"},
		{"name": "pista desconocida", "expect": "pista desconocida \"pista_fantasma\"",
			"mutate": func(s: Dictionary) -> void: s["npcs"]["people"][5]["talks"][1]["if"] = {"clue": "pista_fantasma"}},
		{"name": "bandera que nadie activa", "expect": "la bandera \"bandera_fantasma\" se comprueba",
			"mutate": func(s: Dictionary) -> void: s["endings"]["endings"][0]["if"] = {"NOT": ["bandera_fantasma"]}},
		{"name": "bandera que nadie comprueba", "expect": "la bandera \"bandera_suelta\" se activa",
			"mutate": func(s: Dictionary) -> void: s["letters"]["letters"][0]["retain"]["effects"] = {"set": ["bandera_suelta"]}},
		{"name": "hora no válida", "expect": "hora no válida \"25:00\"",
			"mutate": func(s: Dictionary) -> void: s["events"]["events"][0]["time"] = "25:00"},
		{"name": "quien habla no existe", "expect": "quien habla es desconocido (\"rosa\")",
			"mutate": func(s: Dictionary) -> void: s["events"]["events"][0]["variants"][0]["witness"]["sazil"]["lines"][0]["speaker"] = "rosa"},
		{"name": "destinatario desconocido", "expect": "\"recipient\" es una persona desconocida",
			"mutate": func(s: Dictionary) -> void: s["letters"]["letters"][0]["recipient"] = "rosa"},
		{"name": "dos finales por defecto", "expect": "exactamente un final con \"default\": true",
			"mutate": func(s: Dictionary) -> void: s["endings"]["endings"][0]["default"] = true},
		{"name": "Sazil no puede forzar", "expect": "solo Akba puede forzar o sellar",
			"mutate": func(s: Dictionary) -> void: s["locations"]["locations"][0]["interactions"][0]["actor"] = "sazil"},
		{"name": "pregunta con banderas", "expect": "solo puede usar pistas",
			"mutate": func(s: Dictionary) -> void: s["clues"]["questions"][0]["appears_if"] = "lina_perdida"},
		{"name": "condición desconocida", "expect": "clave de condición desconocida \"tal_vez\"",
			"mutate": func(s: Dictionary) -> void: s["events"]["events"][0]["if"] = {"tal_vez": true}},
		{"name": "evento fuera de los pasos", "expect": "debe caer en un paso de 30 minutos",
			"mutate": func(s: Dictionary) -> void: s["events"]["events"][0]["time"] = "15:10"},
		{"name": "carta que no es de su mazo", "expect": "sazil no puede llevar la carta \"presion\"",
			"mutate": func(s: Dictionary) -> void: s["cards"]["conversations"][0]["decks"]["sazil"].append("presion")},
		{"name": "Verdad de otra persona", "expect": "la carta \"verdad_beto_imprenta\" abre una puerta de otra persona",
			"mutate": func(s: Dictionary) -> void: s["cards"]["conversations"][0]["decks"]["sazil"].append("verdad_beto_imprenta")},
		{"name": "puerta con muro ajeno", "expect": "cita un muro que no es suyo (\"beto_muro_broma\")",
			"mutate": func(s: Dictionary) -> void: s["cards"]["conversations"][0]["elements"][1]["walls"] = ["beto_muro_broma"]},
		{"name": "conversación y temas a la vez", "expect": "tiene conversación con cartas; no le pongas también temas",
			"mutate": _give_lina_a_talk},
		{"name": "Conocimiento de una puerta desconocida", "expect": "\"opens_door\" nombra una puerta desconocida \"puerta_fantasma\"",
			"mutate": func(s: Dictionary) -> void: s["clues"]["clues"][0]["opens_door"] = ["puerta_fantasma"]},
		{"name": "quiebre con una interacción de otro lugar", "expect": "\"interponerse\" no es una interacción de relojeria",
			"mutate": func(s: Dictionary) -> void: s["events"]["breakpoints"][0]["options"].append("interponerse")},
	]
	for test_case: Dictionary in cases:
		var sources := data_sources()
		test_case["mutate"].call(sources)
		var data := GameData.new()
		check(not data.load_sources(sources), "%s: la copia rota se aceptó" % test_case["name"])
		check(_contains(data.errors, test_case["expect"]),
				"%s: se esperaba «%s», llegó %s" % [test_case["name"], test_case["expect"], data.errors])
	return true


func test_malformed_json_fails() -> bool:
	var sources := data_sources()
	var file := FileAccess.open(BROKEN_FILE_PATH, FileAccess.WRITE)
	file.store_string("{ \"events\": [ ")
	file.close()
	var data := GameData.new()
	check(data._read_json(BROKEN_FILE_PATH) == null, "un JSON roto no debería leerse")
	check(_contains(data._problems, "JSON inválido"), "se esperaba «JSON inválido», llegó %s" % [data._problems])
	sources.erase("events")
	check(not data.load_sources(sources), "sin events.json no se carga")
	SaveManager.delete(BROKEN_FILE_PATH)
	return true


## Lina tiene conversación con cartas: un tema de Marcos copiado para ella.
func _give_lina_a_talk(s: Dictionary) -> void:
	var talk: Dictionary = s["npcs"]["people"][5]["talks"][0].duplicate(true)
	talk["id"] = "lina_tema_copiado"
	s["npcs"]["people"][4]["talks"] = [talk]


func _contains(messages: PackedStringArray, fragment: String) -> bool:
	for message: String in messages:
		if message.contains(fragment):
			return true
	return false
