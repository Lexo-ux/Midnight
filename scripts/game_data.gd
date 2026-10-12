extends RefCounted
## Carga y valida todo el contenido de Medianoche en Much (`data/*.json`).
##
## Ante cualquier problema, cada error se notifica con push_error (en español),
## queda en `errors` y no se carga nada. Las referencias (lugares, personas,
## pistas, banderas, cartas, finales) se comprueban todas; la alcanzabilidad la
## comprueba el validador de bucles (scripts/dev/loop_validator.gd).

const FILES: Dictionary = {
	"settings": "res://data/settings.json",
	"locations": "res://data/locations.json",
	"npcs": "res://data/npcs.json",
	"events": "res://data/events.json",
	"clues": "res://data/clues.json",
	"endings": "res://data/endings.json",
	"letters": "res://data/letters.json",
	"ui_text": "res://data/ui_text.json",
}

const CLUE_TYPES: PackedStringArray = ["Horario", "Hecho", "Secreto", "Rumor", "Clave", "Final"]
const INTERACTION_VERBS: PackedStringArray = ["forzar", "sellar", "actuar"]
const FORCING_VERBS: PackedStringArray = ["forzar", "sellar"]
const LETTER_STATES: PackedStringArray = ["bolsa", "entregada", "retenida", "desviada"]
## Banderas que activa el motor, no los datos.
const ENGINE_FLAGS: PackedStringArray = ["akba_forzo"]
const CONDITION_KEYS: PackedStringArray = [
	"ALL", "ANY", "NOT", "clue", "at", "together", "was_at", "rastro_min", "rastro_max",
	"letter", "night", "interior", "time_from", "time_to", "flag_earlier",
]

var errors: PackedStringArray = []

# --- Ajustes ---
var loop_start: int = 0
var day_end: int = 0
var step_minutes: int = 30
var day_starts: int = 0
var night_starts: int = 0
var start_active: String = ""
var rastro_thresholds: Dictionary = {}
var rastro_max: int = 0
var desgaste_max: int = 0
var desgaste_cost: int = 1
var desgaste_day_multiplier: int = 2
var palette: Array[Dictionary] = []
## Tinta oscura y clara: la UI elige la que contrasta con el color de cada tarjeta.
var ink_dark: Color = Color.BLACK
var ink_light: Color = Color.WHITE
var text_sizes: Array[Dictionary] = []

# --- Contenido ---
var location_ids: Array[String] = []
var locations: Dictionary = {}
var person_ids: Array[String] = []
var protagonist_ids: Array[String] = []
var people: Dictionary = {}
var talks: Dictionary = {}
var interactions: Dictionary = {}
var events: Array[Dictionary] = []
var timeline: Array[Dictionary] = []
var clue_ids: Array[String] = []
var clues: Dictionary = {}
var questions: Array[Dictionary] = []
var endings: Array[Dictionary] = []
var letter_ids: Array[String] = []
var letters: Dictionary = {}
var ui_text: Dictionary = {}

## Banderas que activa algún efecto (más las del motor) y las que algo comprueba.
var set_flags: Dictionary = {}
var checked_flags: Dictionary = {}
## Pistas que aparecen en alguna condición (cambian lo que se puede hacer).
var referenced_clues: Dictionary = {}
## "quien@lugar@minuto" usados en condiciones was_at: el rastro de posiciones que hay que guardar.
var was_at_refs: Dictionary = {}

var _problems: PackedStringArray = []
## Pistas que concede algún efecto, testigo, horario o final.
var _granted_clues: Dictionary = {}


func load_all() -> bool:
	var sources: Dictionary = {}
	_problems = []
	_clear()
	for key: String in FILES:
		sources[key] = _read_json(FILES[key])
	if not _problems.is_empty():
		return _fail()
	return load_sources(sources)


## Valida contenido ya parseado: {settings, locations, npcs, events, clues, endings, letters, ui_text}.
func load_sources(sources: Dictionary) -> bool:
	_problems = []
	errors = []
	_clear()
	_parse_settings(sources.get("settings"))
	_parse_ui_text(sources.get("ui_text"))
	if _problems.is_empty():
		_parse_locations_and_people(sources.get("locations"), sources.get("npcs"))
	if _problems.is_empty():
		_parse_clues(sources.get("clues"))
	if _problems.is_empty():
		# Las rutinas generan las pistas de Horario, que luego pueden citar eventos y temas.
		_parse_letters(sources.get("letters"))
		_parse_routines(sources.get("npcs"))
		_parse_people_details(sources.get("npcs"))
		_parse_location_details(sources.get("locations"))
		_parse_events(sources.get("events"))
		_parse_endings(sources.get("endings"))
		_parse_questions(sources.get("clues"))
	if _problems.is_empty():
		_check_cross_references()
	if not _problems.is_empty():
		return _fail()
	return true


func is_loaded() -> bool:
	return not location_ids.is_empty()


# --- Consultas ------------------------------------------------------------

func visible_location_ids() -> Array[String]:
	var ids: Array[String] = []
	for id: String in location_ids:
		if locations[id]["visible"]:
			ids.append(id)
	return ids


func is_protagonist(id: String) -> bool:
	return protagonist_ids.has(id)


func npc_ids() -> Array[String]:
	var ids: Array[String] = []
	for id: String in person_ids:
		if not is_protagonist(id):
			ids.append(id)
	return ids


func is_open(place: String, minute: int) -> bool:
	var location: Dictionary = locations[place]
	if location["open"] < 0:
		return true
	return minute >= location["open"] and minute < location["close"]


func is_night(minute: int) -> bool:
	return minute >= night_starts or minute < day_starts


func threshold(value: Variant) -> int:
	return rastro_thresholds[value] if value is String else int(value)


## Segmentos canónicos (de horario) de una persona que tocan la ventana del bucle.
func relevant_schedule(person: String) -> Array[Dictionary]:
	var segments: Array[Dictionary] = []
	for segment: Dictionary in people[person]["routine"]:
		if segment["schedule"] and segment["window_end"] > loop_start and segment["from"] < day_end:
			segments.append(segment)
	return segments


func default_ending() -> Dictionary:
	for ending: Dictionary in endings:
		if ending["default"]:
			return ending
	return {}


func text(key: String) -> String:
	return ui_text.get(key, key)


static func parse_time(value: Variant) -> int:
	if not value is String:
		return -1
	var parts: PackedStringArray = value.split(":")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return -1
	var hours := parts[0].to_int()
	var minutes := parts[1].to_int()
	if hours < 0 or hours > 24 or minutes < 0 or minutes > 59 or (hours == 24 and minutes != 0):
		return -1
	return hours * 60 + minutes


static func format_time(minute: int) -> String:
	return "%02d:%02d" % [floori(minute / 60.0), minute % 60]


# --- Análisis -------------------------------------------------------------

func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		_problems.append("No existe el archivo %s." % path)
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		_problems.append("%s, línea %d: JSON inválido (%s)." % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data


func _parse_settings(source: Variant) -> void:
	const WHERE := "settings.json"
	if not _expect_dict(source, WHERE, ["loop_start", "day_end", "step_minutes", "day_starts", "night_starts",
			"start_active", "rastro", "desgaste", "palette", "ink", "text_sizes"]):
		return
	var ink: Variant = source.get("ink")
	if _expect_dict(ink, WHERE + ", ink", ["dark", "light"]):
		ink_dark = _color(ink.get("dark"), WHERE + ", ink.dark")
		ink_light = _color(ink.get("light"), WHERE + ", ink.light")
	loop_start = _time(source.get("loop_start"), WHERE + ", loop_start")
	day_end = _time(source.get("day_end"), WHERE + ", day_end")
	step_minutes = _int(source.get("step_minutes"), WHERE + ", step_minutes", 1)
	day_starts = _time(source.get("day_starts"), WHERE + ", day_starts")
	night_starts = _time(source.get("night_starts"), WHERE + ", night_starts")
	start_active = _string(source.get("start_active"), WHERE + ", start_active")
	if step_minutes > 0 and (loop_start % step_minutes != 0 or day_end % step_minutes != 0 or loop_start >= day_end):
		_problems.append(WHERE + ": loop_start y day_end deben ser múltiplos de step_minutes, y loop_start anterior a day_end.")
	var rastro: Variant = source.get("rastro")
	if _expect_dict(rastro, WHERE + ", rastro", ["thresholds", "max"]):
		rastro_max = _int(rastro.get("max"), WHERE + ", rastro.max", 1)
		var thresholds: Variant = rastro.get("thresholds")
		if not thresholds is Dictionary or thresholds.is_empty():
			_problems.append(WHERE + ": rastro.thresholds debe ser un objeto {nombre: valor}.")
		else:
			for name: Variant in thresholds:
				rastro_thresholds[name] = _int(thresholds[name], "%s, rastro.thresholds.%s" % [WHERE, name], 0)
	var desgaste: Variant = source.get("desgaste")
	if _expect_dict(desgaste, WHERE + ", desgaste", ["max", "cost", "day_multiplier"]):
		desgaste_max = _int(desgaste.get("max"), WHERE + ", desgaste.max", 1)
		desgaste_cost = _int(desgaste.get("cost"), WHERE + ", desgaste.cost", 1)
		desgaste_day_multiplier = _int(desgaste.get("day_multiplier"), WHERE + ", desgaste.day_multiplier", 1)
	var palette_data: Variant = source.get("palette")
	if not palette_data is Array or palette_data.size() < 2:
		_problems.append(WHERE + ": palette debe ser una lista de al menos dos colores por hora.")
	else:
		var previous := -1
		for i: int in palette_data.size():
			var where := "%s, palette #%d" % [WHERE, i]
			var entry: Variant = palette_data[i]
			if not _expect_dict(entry, where, ["time", "sky", "horizon", "card", "stars"]):
				continue
			var key_time := _time(entry.get("time"), where + ", time")
			if key_time <= previous:
				_problems.append(where + ": las horas de la paleta deben ir en orden creciente.")
			previous = key_time
			var colors: Dictionary = {"time": key_time, "stars": clampf(float(entry.get("stars", 0.0)), 0.0, 1.0)}
			for key: String in ["sky", "horizon", "card"]:
				colors[key] = _color(entry.get(key), "%s, %s" % [where, key])
			palette.append(colors)
	var sizes: Variant = source.get("text_sizes")
	if not sizes is Array or sizes.size() != 3:
		_problems.append(WHERE + ": text_sizes debe tener exactamente 3 tamaños.")
	else:
		for i: int in sizes.size():
			var where := "%s, text_sizes #%d" % [WHERE, i]
			if not _expect_dict(sizes[i], where, ["name", "body", "title"]):
				continue
			var body := _int(sizes[i].get("body"), where + ", body", 40)
			text_sizes.append({"name": _string(sizes[i].get("name"), where + ", name"), "body": body,
					"title": _int(sizes[i].get("title"), where + ", title", body)})


func _parse_ui_text(source: Variant) -> void:
	if not source is Dictionary:
		_problems.append("ui_text.json: la raíz debe ser un objeto {clave: texto}.")
		return
	for key: Variant in source:
		if not source[key] is String:
			_problems.append("ui_text.json: \"%s\" debe ser texto." % key)
		else:
			ui_text[key] = source[key]


func _parse_locations_and_people(locations_source: Variant, npcs_source: Variant) -> void:
	if _expect_dict(locations_source, "locations.json", ["locations"]):
		var list: Variant = locations_source.get("locations")
		if not list is Array or list.is_empty():
			_problems.append("locations.json: \"locations\" debe ser una lista.")
		else:
			for i: int in list.size():
				var source: Variant = list[i]
				var where := "locations.json, lugar #%d" % i
				if not _expect_dict(source, where, ["id", "name", "short", "visible", "interior", "open", "close", "card", "observe", "interactions"]):
					continue
				var id := _id(source.get("id"), where, locations)
				if id == "":
					continue
				var visible: bool = source.get("visible", false) == true
				var open_time := -1
				var close_time := -1
				if source.has("open") or source.has("close"):
					open_time = _time(source.get("open"), "locations.json, \"%s\", open" % id)
					close_time = _time(source.get("close"), "locations.json, \"%s\", close" % id)
				location_ids.append(id)
				var name := _string(source.get("name"), "locations.json, \"%s\", name" % id)
				locations[id] = {"id": id, "name": name, "short": source.get("short", name),
						"visible": visible, "interior": source.get("interior", false) == true,
						"open": open_time, "close": close_time, "card": [], "observe": []}
	if not _expect_dict(npcs_source, "npcs.json", ["people"]):
		return
	var people_list: Variant = npcs_source.get("people")
	if not people_list is Array or people_list.is_empty():
		_problems.append("npcs.json: \"people\" debe ser una lista.")
		return
	for i: int in people_list.size():
		var source: Variant = people_list[i]
		var where := "npcs.json, persona #%d" % i
		if not source is Dictionary:
			_problems.append(where + " debe ser un objeto.")
			continue
		var id := _id(source.get("id"), where, people)
		if id == "":
			continue
		person_ids.append(id)
		if source.get("protagonist", false) == true:
			protagonist_ids.append(id)
		people[id] = {"id": id}
	if protagonist_ids.size() != 2:
		_problems.append("npcs.json: debe haber exactamente dos protagonistas (\"protagonist\": true).")
	elif not protagonist_ids.has(start_active):
		_problems.append("settings.json: start_active \"%s\" no es un protagonista." % start_active)


func _parse_routines(source: Dictionary) -> void:
	for raw: Dictionary in source["people"]:
		var id: String = raw["id"]
		people[id]["name"] = _string(raw.get("name"), "npcs.json, \"%s\", name" % id)
		people[id]["routine"] = _parse_routine(raw.get("routine"), id, "npcs.json, \"%s\"" % id)


func _parse_people_details(source: Dictionary) -> void:
	var people_list: Array = source["people"]
	for i: int in people_list.size():
		var raw: Dictionary = people_list[i]
		var id: String = raw["id"]
		var where := "npcs.json, \"%s\"" % id
		_check_keys(raw, ["id", "name", "protagonist", "trait", "silhouette_path", "colors", "velo",
				"icon", "delivers_letters", "disabled_if", "routine", "observe", "talks"], where)
		var person: Dictionary = people[id]
		person["trait"] = _string(raw.get("trait"), where + ", trait")
		var path: Variant = raw.get("silhouette_path")
		if not path is String or not path.begins_with("res://"):
			_problems.append(where + ": \"silhouette_path\" debe ser una ruta res://.")
		person["silhouette_path"] = path if path is String else ""
		var colors: Variant = raw.get("colors")
		if _expect_dict(colors, where + ", colors", ["body", "trait"]):
			person["colors"] = {"body": _color(colors.get("body"), where + ", colors.body"),
					"trait": _color(colors.get("trait"), where + ", colors.trait")}
		var velo: Variant = raw.get("velo", {})
		if _expect_dict(velo, where + ", velo", ["face_path", "portrait_path", "credit"]):
			person["velo"] = velo.duplicate()
		person["protagonist"] = protagonist_ids.has(id)
		person["icon"] = raw.get("icon", "")
		if person["protagonist"] and not person["icon"] in ["sol", "luna"]:
			_problems.append(where + ": un protagonista necesita \"icon\": \"sol\" o \"luna\".")
		person["delivers_letters"] = raw.get("delivers_letters", false) == true
		person["disabled_if"] = _condition(raw.get("disabled_if"), where + ", disabled_if")
		person["observe"] = _parse_variants(raw.get("observe", []), where + ", observe", true)
		for talk_index: int in raw.get("talks", []).size():
			_parse_talk(raw["talks"][talk_index], id, "%s, tema #%d" % [where, talk_index])


func _parse_routine(source: Variant, person: String, where: String) -> Array[Dictionary]:
	var routine: Array[Dictionary] = []
	if not source is Array or source.is_empty():
		_problems.append(where + ": \"routine\" debe ser una lista con al menos un tramo.")
		return routine
	var segment_ids: Dictionary = {}
	for i: int in source.size():
		var raw: Variant = source[i]
		var seg_where := "%s, rutina #%d" % [where, i]
		if not _expect_dict(raw, seg_where, ["id", "from", "place", "follow", "if", "override", "schedule", "label"]):
			continue
		var id := _string(raw.get("id"), seg_where + ", id")
		if segment_ids.has(id):
			_problems.append("%s: el tramo \"%s\" está repetido." % [where, id])
		segment_ids[id] = true
		var segment: Dictionary = {
			"id": id, "person": person, "from": _time(raw.get("from"), seg_where + ", from"),
			"place": raw.get("place", ""), "follow": raw.get("follow", ""),
			"if": _condition(raw.get("if"), seg_where + ", if"),
			"override": raw.get("override", false) == true,
			"schedule": raw.get("schedule", false) == true, "label": raw.get("label", ""),
			"window_end": day_end,
		}
		if (segment["place"] == "") == (segment["follow"] == ""):
			_problems.append(seg_where + ": cada tramo necesita \"place\" o \"follow\" (solo uno).")
		elif segment["place"] != "" and not locations.has(segment["place"]):
			_problems.append("%s: lugar desconocido \"%s\"." % [seg_where, segment["place"]])
		elif segment["follow"] != "" and not people.has(segment["follow"]):
			_problems.append("%s: persona desconocida \"%s\"." % [seg_where, segment["follow"]])
		if segment["schedule"]:
			if segment["override"] or segment["follow"] != "":
				_problems.append(seg_where + ": un tramo de horario no puede ser override ni follow.")
			if not _is_filled(segment["label"]):
				_problems.append(seg_where + ": un tramo de horario necesita \"label\".")
		routine.append(segment)
	# Cada tramo de horario dura hasta el siguiente tramo de horario.
	var schedule: Array[Dictionary] = []
	for segment: Dictionary in routine:
		if segment["schedule"]:
			if not schedule.is_empty() and segment["from"] <= schedule[-1]["from"]:
				_problems.append("%s: los tramos de horario deben ir en orden de hora." % where)
			schedule.append(segment)
	for i: int in schedule.size():
		if i + 1 < schedule.size():
			schedule[i]["window_end"] = schedule[i + 1]["from"]
		var clue_id: String = "horario_" + schedule[i]["id"]
		if clues.has(clue_id):
			_problems.append("clues.json: \"%s\" lo genera el horario de %s; no lo declares a mano." % [clue_id, person])
		clue_ids.append(clue_id)
		clues[clue_id] = {"id": clue_id, "type": "Horario", "title": people[person].get("name", person),
				"text": schedule[i]["label"], "person": person, "place": schedule[i]["place"],
				"time": schedule[i]["from"], "segment": schedule[i]["id"]}
		_granted_clues[clue_id] = true
	return routine


func _parse_talk(raw: Variant, person: String, where: String) -> void:
	if not _expect_dict(raw, where, ["id", "label", "actor", "if", "lines", "effects"]):
		return
	var id := _id(raw.get("id"), where, talks)
	if id == "":
		return
	where = "npcs.json, tema \"%s\"" % id
	var actor: String = raw.get("actor", "")
	if actor != "any" and not protagonist_ids.has(actor):
		_problems.append("%s: \"actor\" debe ser un protagonista o \"any\", no \"%s\"." % [where, actor])
	talks[id] = {"id": id, "person": person, "label": _string(raw.get("label"), where + ", label"),
			"actor": actor, "if": _condition(raw.get("if"), where + ", if"),
			"lines": _lines(raw.get("lines"), where), "effects": _effects(raw.get("effects", {}), where)}


func _parse_location_details(source: Dictionary) -> void:
	for raw: Dictionary in source["locations"]:
		var id: String = raw["id"]
		var where := "locations.json, \"%s\"" % id
		var location: Dictionary = locations[id]
		if location["visible"]:
			location["card"] = _parse_variants(raw.get("card", []), where + ", card", false)
			location["observe"] = _parse_variants(raw.get("observe", []), where + ", observe", true)
			if location["card"].is_empty() or location["observe"].is_empty():
				_problems.append(where + ": un lugar visible necesita \"card\" y \"observe\".")
		for i: int in raw.get("interactions", []).size():
			_parse_interaction(raw["interactions"][i], id, "%s, interacción #%d" % [where, i])


func _parse_interaction(raw: Variant, place: String, where: String) -> void:
	if not _expect_dict(raw, where, ["id", "actor", "verb", "label", "times", "from", "to", "if", "rastro", "lines", "effects"]):
		return
	var id := _id(raw.get("id"), where, interactions)
	if id == "":
		return
	where = "locations.json, interacción \"%s\"" % id
	var actor: String = raw.get("actor", "")
	var verb: String = raw.get("verb", "")
	if not protagonist_ids.has(actor):
		_problems.append("%s: \"actor\" debe ser un protagonista." % where)
	if not INTERACTION_VERBS.has(verb):
		_problems.append("%s: \"verb\" debe ser uno de %s." % [where, INTERACTION_VERBS])
	if FORCING_VERBS.has(verb) and actor != "akba":
		_problems.append("%s: solo Akba puede forzar o sellar." % where)
	var times: Array[int] = []
	for value: Variant in raw.get("times", []):
		times.append(_time(value, where + ", times"))
	interactions[id] = {"id": id, "place": place, "actor": actor, "verb": verb,
			"label": _string(raw.get("label"), where + ", label"), "times": times,
			"from": _time(raw.get("from", "00:00"), where + ", from"), "to": _time(raw.get("to", "24:00"), where + ", to"),
			"if": _condition(raw.get("if"), where + ", if"), "rastro": int(raw.get("rastro", 0)),
			"lines": _lines(raw.get("lines"), where), "effects": _effects(raw.get("effects", {}), where)}


func _parse_clues(source: Variant) -> void:
	if not _expect_dict(source, "clues.json", ["clues", "questions"]):
		return
	var list: Variant = source.get("clues")
	if not list is Array:
		_problems.append("clues.json: \"clues\" debe ser una lista.")
		return
	for i: int in list.size():
		var raw: Variant = list[i]
		var where := "clues.json, pista #%d" % i
		if not _expect_dict(raw, where, ["id", "type", "title", "text", "person", "place", "time"]):
			continue
		var id := _id(raw.get("id"), where, clues)
		if id == "":
			continue
		where = "clues.json, \"%s\"" % id
		var type: String = raw.get("type", "")
		if not CLUE_TYPES.has(type) or type == "Horario":
			_problems.append("%s: \"type\" debe ser uno de Hecho, Secreto, Rumor, Clave o Final (los Horario se generan desde las rutinas)." % where)
		var person: String = raw.get("person", "")
		if person != "" and not people.has(person):
			_problems.append("%s: persona desconocida \"%s\"." % [where, person])
		var place: String = raw.get("place", "")
		if place != "" and not locations.has(place):
			_problems.append("%s: lugar desconocido \"%s\"." % [where, place])
		clue_ids.append(id)
		clues[id] = {"id": id, "type": type, "title": _string(raw.get("title"), where + ", title"),
				"text": _string(raw.get("text"), where + ", text"), "person": person, "place": place,
				"time": _time(raw["time"], where + ", time") if raw.has("time") else -1}


func _parse_questions(source: Dictionary) -> void:
	var list: Variant = source.get("questions")
	if not list is Array or list.is_empty():
		_problems.append("clues.json: \"questions\" debe ser una lista con al menos una pregunta.")
		return
	var ids: Dictionary = {}
	for i: int in list.size():
		var raw: Variant = list[i]
		var where := "clues.json, pregunta #%d" % i
		if not _expect_dict(raw, where, ["id", "text", "appears_if", "resolved_if", "hints"]):
			continue
		var id := _id(raw.get("id"), where, ids)
		if id == "":
			continue
		ids[id] = true
		where = "clues.json, pregunta \"%s\"" % id
		var hints: Variant = raw.get("hints")
		if not hints is Array or hints.size() != 3 or not _all_filled(hints):
			_problems.append(where + ": \"hints\" debe tener 3 textos: rumor, pregunta dirigida y revelación.")
			hints = ["", "", ""]
		var question: Dictionary = {"id": id, "text": _string(raw.get("text"), where + ", text"),
				"appears_if": _condition(raw.get("appears_if"), where + ", appears_if"),
				"resolved_if": _condition(raw.get("resolved_if"), where + ", resolved_if"), "hints": hints}
		for key: String in ["appears_if", "resolved_if"]:
			if not _only_clue_atoms(question[key]):
				_problems.append("%s: \"%s\" solo puede usar pistas (clue, ALL, ANY, NOT)." % [where, key])
		questions.append(question)


func _parse_letters(source: Variant) -> void:
	if not _expect_dict(source, "letters.json", ["letters"]):
		return
	for i: int in source.get("letters", []).size():
		var raw: Variant = source["letters"][i]
		var where := "letters.json, carta #%d" % i
		if not _expect_dict(raw, where, ["id", "label", "sender", "recipient", "carrier", "read", "deliver", "retain", "divert"]):
			continue
		var id := _id(raw.get("id"), where, letters)
		if id == "":
			continue
		where = "letters.json, \"%s\"" % id
		for key: String in ["sender", "recipient", "carrier"]:
			if not people.has(raw.get(key, "")):
				_problems.append("%s: \"%s\" es una persona desconocida (\"%s\")." % [where, key, raw.get(key, "")])
		if people.has(raw.get("carrier", "")) and not protagonist_ids.has(raw["carrier"]):
			_problems.append(where + ": \"carrier\" debe ser un protagonista.")
		var letter: Dictionary = {"id": id, "label": _string(raw.get("label"), where + ", label"),
				"sender": raw.get("sender", ""), "recipient": raw.get("recipient", ""), "carrier": raw.get("carrier", "")}
		for key: String in ["read", "deliver", "retain"]:
			var part: Variant = raw.get(key)
			if _expect_dict(part, "%s, %s" % [where, key], ["lines", "effects"]):
				letter[key] = {"lines": _lines(part.get("lines"), "%s, %s" % [where, key]),
						"effects": _effects(part.get("effects", {}), "%s, %s" % [where, key])}
		var diverts: Array[Dictionary] = []
		for raw_divert: Variant in raw.get("divert", []):
			var divert_where := where + ", divert"
			if not _expect_dict(raw_divert, divert_where, ["to", "lines", "effects"]):
				continue
			if not people.has(raw_divert.get("to", "")) or protagonist_ids.has(raw_divert.get("to", "")):
				_problems.append("%s: \"to\" debe ser un habitante, no \"%s\"." % [divert_where, raw_divert.get("to", "")])
			diverts.append({"to": raw_divert.get("to", ""), "lines": _lines(raw_divert.get("lines"), divert_where),
					"effects": _effects(raw_divert.get("effects", {}), divert_where)})
		letter["divert"] = diverts
		letter_ids.append(id)
		letters[id] = letter


func _parse_events(source: Variant) -> void:
	if not _expect_dict(source, "events.json", ["events", "timeline"]):
		return
	var event_ids: Dictionary = {}
	for i: int in source.get("events", []).size():
		var raw: Variant = source["events"][i]
		var where := "events.json, evento #%d" % i
		if not _expect_dict(raw, where, ["id", "time", "place", "if", "variants"]):
			continue
		var id := _id(raw.get("id"), where, event_ids)
		if id == "":
			continue
		event_ids[id] = true
		where = "events.json, \"%s\"" % id
		var time_value: int = -1 if raw.get("time") == "any" else _time(raw.get("time"), where + ", time")
		if time_value >= 0 and time_value % step_minutes != 0:
			_problems.append("%s: la hora debe caer en un paso de %d minutos." % [where, step_minutes])
		var place: String = raw.get("place", "")
		if place.begins_with("@"):
			if not protagonist_ids.has(place.substr(1)):
				_problems.append("%s: \"place\" con @ debe nombrar a un protagonista." % where)
		elif not locations.has(place):
			_problems.append("%s: lugar desconocido \"%s\"." % [where, place])
		var variants: Array[Dictionary] = []
		var raw_variants: Variant = raw.get("variants")
		if not raw_variants is Array or raw_variants.is_empty():
			_problems.append(where + ": necesita al menos una variante.")
		else:
			for v: int in raw_variants.size():
				var variant_where := "%s, variante #%d" % [where, v]
				var raw_variant: Variant = raw_variants[v]
				if not _expect_dict(raw_variant, variant_where, ["if", "effects", "witness"]):
					continue
				var witness: Dictionary = {}
				var raw_witness: Variant = raw_variant.get("witness", {})
				if not raw_witness is Dictionary:
					_problems.append(variant_where + ": \"witness\" debe ser un objeto.")
				else:
					for who: Variant in raw_witness:
						if who != "any" and not protagonist_ids.has(who):
							_problems.append("%s: testigo desconocido \"%s\"." % [variant_where, who])
						var part: Variant = raw_witness[who]
						if _expect_dict(part, "%s, witness.%s" % [variant_where, who], ["lines", "clues"]):
							witness[who] = {"lines": _lines(part.get("lines"), variant_where),
									"clues": _clue_list(part.get("clues", []), variant_where)}
				variants.append({"if": _condition(raw_variant.get("if"), variant_where + ", if"),
						"effects": _effects(raw_variant.get("effects", {}), variant_where), "witness": witness})
		events.append({"id": id, "time": time_value, "place": place,
				"if": _condition(raw.get("if"), where + ", if"), "variants": variants})
	for i: int in source.get("timeline", []).size():
		var raw: Variant = source["timeline"][i]
		var where := "events.json, línea del día #%d" % i
		if not _expect_dict(raw, where, ["time", "label", "clue"]):
			continue
		timeline.append({"time": _time(raw.get("time"), where), "label": _string(raw.get("label"), where),
				"clue": _clue_ref(raw.get("clue"), where)})


func _parse_endings(source: Variant) -> void:
	if not _expect_dict(source, "endings.json", ["endings"]):
		return
	var ids: Dictionary = {}
	var defaults := 0
	for i: int in source.get("endings", []).size():
		var raw: Variant = source["endings"][i]
		var where := "endings.json, final #%d" % i
		if not _expect_dict(raw, where, ["id", "title", "text", "if", "clue", "default"]):
			continue
		var id := _id(raw.get("id"), where, ids)
		if id == "":
			continue
		ids[id] = true
		where = "endings.json, \"%s\"" % id
		var is_default: bool = raw.get("default", false) == true
		if is_default:
			defaults += 1
		elif raw.get("if") == null:
			_problems.append(where + ": un final que no es el de por defecto necesita \"if\".")
		var clue: String = _clue_ref(raw.get("clue"), where)
		_granted_clues[clue] = true
		endings.append({"id": id, "title": _string(raw.get("title"), where + ", title"),
				"text": _string(raw.get("text"), where + ", text"), "if": _condition(raw.get("if"), where + ", if"),
				"clue": clue, "default": is_default})
	if defaults != 1:
		_problems.append("endings.json: debe haber exactamente un final con \"default\": true (el de «Otra vez»).")


func _parse_variants(source: Variant, where: String, with_effects: bool) -> Array[Dictionary]:
	var variants: Array[Dictionary] = []
	if not source is Array:
		_problems.append(where + " debe ser una lista.")
		return variants
	for i: int in source.size():
		var raw: Variant = source[i]
		var item_where := "%s #%d" % [where, i]
		var keys: Array = ["actor", "if", "lines", "clues"] if with_effects else ["actor", "if", "text"]
		if not _expect_dict(raw, item_where, keys):
			continue
		var actor: String = raw.get("actor", "any")
		if actor != "any" and not protagonist_ids.has(actor):
			_problems.append("%s: actor desconocido \"%s\"." % [item_where, actor])
		var variant: Dictionary = {"actor": actor, "if": _condition(raw.get("if"), item_where + ", if")}
		if with_effects:
			variant["lines"] = _lines(raw.get("lines"), item_where)
			variant["clues"] = _clue_list(raw.get("clues", []), item_where)
		else:
			variant["text"] = _string(raw.get("text"), item_where + ", text")
		variants.append(variant)
	return variants


func _effects(raw: Variant, where: String) -> Dictionary:
	var effects: Dictionary = {"set": [], "clues": [], "rastro": 0}
	if not _expect_dict(raw, where + ", effects", ["set", "clues", "rastro"]):
		return effects
	for flag: Variant in raw.get("set", []):
		if not _is_filled(flag):
			_problems.append(where + ": \"set\" contiene una bandera vacía.")
			continue
		effects["set"].append(flag)
		set_flags[flag] = where
	effects["clues"] = _clue_list(raw.get("clues", []), where)
	effects["rastro"] = int(raw.get("rastro", 0))
	return effects


func _clue_list(raw: Variant, where: String) -> Array[String]:
	var ids: Array[String] = []
	if not raw is Array:
		_problems.append(where + ": la lista de pistas debe ser una lista.")
		return ids
	for value: Variant in raw:
		var id := _clue_ref(value, where)
		if id != "":
			ids.append(id)
			_granted_clues[id] = true
	return ids


func _clue_ref(value: Variant, where: String) -> String:
	if not value is String or not clues.has(value):
		_problems.append("%s: pista desconocida \"%s\"." % [where, value])
		return ""
	return value


func _lines(raw: Variant, where: String) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	if not raw is Array or raw.is_empty():
		_problems.append(where + ": \"lines\" debe ser una lista con al menos una línea.")
		return lines
	for line: Variant in raw:
		if not _expect_dict(line, where + ", línea", ["speaker", "text"]):
			continue
		if not people.has(line.get("speaker", "")):
			_problems.append("%s: quien habla es desconocido (\"%s\"); cada línea necesita una persona." % [where, line.get("speaker", "")])
		lines.append({"speaker": line.get("speaker", ""), "text": _string(line.get("text"), where + ", text")})
	return lines


## Valida una condición y anota lo que referencia. Devuelve la condición tal cual (o null).
func _condition(raw: Variant, where: String) -> Variant:
	if raw == null:
		return null
	_check_condition(raw, where)
	return raw


func _check_condition(raw: Variant, where: String) -> void:
	if raw is String:
		checked_flags[raw] = where
		return
	if raw is Array:
		for item: Variant in raw:
			_check_condition(item, where)
		return
	if not raw is Dictionary or raw.size() != 1:
		_problems.append("%s: cada condición es una bandera o un objeto con una sola clave de %s." % [where, CONDITION_KEYS])
		return
	var key: String = raw.keys()[0]
	var value: Variant = raw[key]
	match key:
		"ALL", "ANY":
			if not value is Array or value.is_empty():
				_problems.append("%s: \"%s\" necesita una lista." % [where, key])
			else:
				_check_condition(value, where)
		"NOT":
			_check_condition(value, where)
		"clue":
			referenced_clues[_clue_ref(value, where)] = true
		"at", "was_at":
			if not value is Dictionary or not people.has(value.get("who", "")) or not locations.has(value.get("place", "")):
				_problems.append("%s: \"%s\" necesita {who, place} con una persona y un lugar existentes." % [where, key])
			elif key == "was_at":
				var minute := _time(value.get("time"), where + ", was_at.time")
				if not protagonist_ids.has(value["who"]):
					_problems.append(where + ": \"was_at\" solo funciona con protagonistas.")
				was_at_refs["%s@%s@%d" % [value["who"], value["place"], minute]] = true
		"together":
			if not value is Array or value.size() != 2 or not people.has(value[0]) or not people.has(value[1]):
				_problems.append(where + ": \"together\" necesita dos personas existentes.")
		"rastro_min", "rastro_max":
			if not (value is String and rastro_thresholds.has(value)) and not _is_whole(value):
				_problems.append("%s: \"%s\" necesita un número o un umbral de settings (%s)." % [where, key, rastro_thresholds.keys()])
		"letter":
			if not value is Dictionary or not letters.has(value.get("id", "")) or not LETTER_STATES.has(value.get("state", "")):
				_problems.append("%s: \"letter\" necesita {id, state} con una carta existente y un estado de %s." % [where, LETTER_STATES])
		"night", "interior":
			if not value is bool:
				_problems.append("%s: \"%s\" necesita true o false." % [where, key])
		"time_from", "time_to":
			_time(value, "%s, %s" % [where, key])
		"flag_earlier":
			if not _is_filled(value):
				_problems.append(where + ": \"flag_earlier\" necesita una bandera.")
			else:
				checked_flags[value] = where
		_:
			_problems.append("%s: clave de condición desconocida \"%s\"." % [where, key])


func _only_clue_atoms(raw: Variant) -> bool:
	if raw == null:
		return true
	if raw is Array:
		return raw.all(_only_clue_atoms)
	if not raw is Dictionary or raw.size() != 1:
		return false
	var key: String = raw.keys()[0]
	if key in ["ALL", "ANY", "NOT"]:
		return _only_clue_atoms(raw[key])
	return key == "clue"


func _check_cross_references() -> void:
	for flag: String in ENGINE_FLAGS:
		set_flags[flag] = "motor"
	for flag: String in checked_flags:
		if not set_flags.has(flag):
			_problems.append("la bandera \"%s\" se comprueba en %s, pero ningún efecto la activa." % [flag, checked_flags[flag]])
	for flag: String in set_flags:
		if not checked_flags.has(flag):
			_problems.append("la bandera \"%s\" se activa en %s, pero nada la comprueba." % [flag, set_flags[flag]])
	for id: String in clue_ids:
		if not _granted_clues.has(id):
			_problems.append("clues.json: la pista \"%s\" no la concede nada." % id)
	for id: String in protagonist_ids:
		var routine: Array = people[id]["routine"]
		if routine.is_empty() or routine[0]["from"] > loop_start:
			_problems.append("npcs.json, \"%s\": el primer tramo de la rutina debe empezar antes de loop_start." % id)


# --- Utilidades -----------------------------------------------------------

func _expect_dict(value: Variant, where: String, allowed: Array) -> bool:
	if not value is Dictionary:
		_problems.append(where + " debe ser un objeto.")
		return false
	_check_keys(value, allowed, where)
	return true


func _check_keys(source: Dictionary, allowed: Array, where: String) -> void:
	for key: Variant in source:
		if not allowed.has(key):
			_problems.append("%s: clave desconocida \"%s\"." % [where, key])


func _id(value: Variant, where: String, existing: Dictionary) -> String:
	if not _is_filled(value):
		_problems.append(where + " necesita un \"id\" de texto no vacío.")
		return ""
	if existing.has(value):
		_problems.append("%s: el id \"%s\" está repetido." % [where, value])
		return ""
	return value


func _time(value: Variant, where: String) -> int:
	var minute := parse_time(value)
	if minute < 0:
		_problems.append("%s: hora no válida \"%s\" (usa \"HH:MM\")." % [where, value])
	return minute


func _int(value: Variant, where: String, minimum: int) -> int:
	if not _is_whole(value) or int(value) < minimum:
		_problems.append("%s: debe ser un entero mayor o igual que %d." % [where, minimum])
		return minimum
	return int(value)


func _string(value: Variant, where: String) -> String:
	if not _is_filled(value):
		_problems.append(where + ": falta un texto no vacío.")
		return ""
	return value


func _color(value: Variant, where: String) -> Color:
	if not value is String or not Color.html_is_valid(value):
		_problems.append("%s: color no válido \"%s\" (usa \"#rrggbb\")." % [where, value])
		return Color.MAGENTA
	return Color.html(value)


func _is_filled(value: Variant) -> bool:
	return value is String and not value.strip_edges().is_empty()


func _all_filled(values: Array) -> bool:
	return values.all(_is_filled)


func _is_whole(value: Variant) -> bool:
	return (value is int or value is float) and float(value) == floorf(value)


func _fail() -> bool:
	for message: String in _problems:
		push_error("[GameData] " + message)
	errors = _problems.duplicate()
	_clear()
	return false


func _clear() -> void:
	location_ids.clear()
	locations.clear()
	person_ids.clear()
	protagonist_ids.clear()
	people.clear()
	talks.clear()
	interactions.clear()
	events.clear()
	timeline.clear()
	clue_ids.clear()
	clues.clear()
	questions.clear()
	endings.clear()
	letter_ids.clear()
	letters.clear()
	ui_text.clear()
	palette.clear()
	text_sizes.clear()
	rastro_thresholds.clear()
	set_flags.clear()
	checked_flags.clear()
	referenced_clues.clear()
	was_at_refs.clear()
	_granted_clues.clear()
