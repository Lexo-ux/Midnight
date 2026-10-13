extends RefCounted
## Guarda y carga la partida en JSON (por defecto `user://savegame.json`) con
## número de versión. Al cargar lo valida todo contra los datos del juego: una
## partida dañada, de otra versión (por ejemplo la del prototipo de Marta, la
## versión 1) o con ids desconocidos se descarta con un aviso y el juego empieza
## de cero. Las partidas de la versión 2 se migran. Nunca detiene el juego.

const GameData := preload("res://scripts/game_data.gd")

## Versión 1: prototipo de las Tasks 01-02 (se descarta). Versión 2: Medianoche en
## Much (Task 03). Versión 3: añade las estaciones de cada protagonista en cada
## lugar y la estación de los puntos interactivos en la ruta (Task 05).
## Versión 4 (Task 04): marcas de Akba, Velo 2-3, el estado de las
## conversaciones del bucle, las cartas y decisiones de quiebre en la ruta y los
## ajustes de sonido, vibración, quiebres y consejos.
## Súbela si cambia el formato y añade aquí la migración desde la anterior.
const SAVE_VERSION: int = 4
## Versiones que se migran al cargar (encadenadas: 2 -> 3 -> 4).
const MIGRATABLE_VERSIONS: Array[int] = [2, 3]
const HAPTIC_LEVELS: PackedStringArray = ["off", "low", "normal"]
const BREAKPOINT_MODES: PackedStringArray = ["hold", "toggle"]
const BREAKPOINT_TIMES: PackedStringArray = ["20", "40", "none"]
const VOLUME_KEYS: PackedStringArray = ["volume_master", "volume_music", "volume_ambience", "volume_sfx"]
## Ajustes de una partida nueva (y de lo que falte al migrar).
const DEFAULT_SETTINGS: Dictionary = {
	"reduced_motion": false, "text_size": 1,
	"volume_master": 0.8, "volume_music": 0.7, "volume_ambience": 0.6, "volume_sfx": 0.8, "mute": false,
	"haptics": "normal", "breakpoint_mode": "hold", "breakpoint_time": "20", "breakpoint_chosen": false, "tips_seen": false,
}

## Lo que devuelve _whole() cuando un número no vale.
const INVALID: int = -1_000_000


static func write(path: String, snapshot: Dictionary) -> bool:
	var save: Dictionary = {"version": SAVE_VERSION}
	save.merge(snapshot)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("[SaveManager] No se pudo escribir %s (%s)." % [path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(save, "\t", false))
	file.close()
	return true


## Devuelve la instantánea validada, o {} si no hay partida guardada o no es válida.
static func read(path: String, data: GameData) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	var result: Dictionary
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		result = _invalid("JSON inválido en la línea %d" % json.get_error_line())
	else:
		result = validate(json.data, data)
	if result["error"] != "":
		push_warning("[SaveManager] La partida guardada en %s no es válida (%s). Se empieza una partida nueva." % [path, result["error"]])
		return {}
	return result["snapshot"]


static func delete(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## Comprueba una partida ya parseada. Devuelve {error, snapshot}; `snapshot`
## sale normalizado (enteros como int) y listo para GameState.import_snapshot().
static func validate(save: Variant, data: GameData) -> Dictionary:
	if not save is Dictionary:
		return _invalid("el contenido no es un objeto JSON")
	var root: Dictionary = save
	var version: Variant = root.get("version")
	if not _is_whole(version) or (int(version) != SAVE_VERSION and not MIGRATABLE_VERSIONS.has(int(version))):
		return _invalid("versión %s no compatible, se esperaba %d" % [int(version) if _is_whole(version) else version, SAVE_VERSION])
	if int(version) == 2:
		root = _migrate_from_v2(root)
	if int(version) <= 3:
		root = _migrate_from_v3(root, data)
	var loop_number := _whole(root.get("loop_number"), 1, 1_000_000)
	if loop_number == INVALID:
		return _invalid("loop_number no válido")

	var cuaderno: Dictionary = {}
	var cuaderno_data: Variant = root.get("cuaderno")
	if not cuaderno_data is Dictionary:
		return _invalid("cuaderno no es un objeto")
	for id: Variant in cuaderno_data:
		var entry: Variant = cuaderno_data[id]
		if not data.clues.has(str(id)) or not entry is Dictionary or entry.size() != 3:
			return _invalid("pista no válida \"%s\"" % id)
		var learned := _whole(entry.get("loop"), 1, loop_number)
		var time := _whole(entry.get("time"), 0, data.day_end)
		if learned == INVALID or time == INVALID or not data.is_protagonist(str(entry.get("by", ""))):
			return _invalid("pista mal anotada \"%s\"" % id)
		cuaderno[str(id)] = {"loop": learned, "by": entry["by"], "time": time}

	var velo := _id_map(root.get("velo"), data.npc_ids(), 0, 3)
	var endings_seen := _id_map(root.get("endings_seen"), _ending_ids(data), 1, loop_number)
	var hints := _id_map(root.get("hints"), _question_ids(data), 0, 3)
	if velo.has("error") or endings_seen.has("error") or hints.has("error"):
		return _invalid("Velo, finales vistos o pistas pedidas no válidos")

	var marks := _marks(root.get("marks"), data, loop_number)
	if marks.has("error"):
		return _invalid("marcas de Akba no válidas")
	var settings := _settings(root.get("settings"), data)
	if settings.has("error"):
		return _invalid("ajustes no válidos")

	var last_route: Variant = _route(root.get("last_route"), data)
	if last_route == null:
		return _invalid("ruta del bucle anterior no válida")
	var loop := _loop_state(root.get("loop"), data)
	if loop.has("error"):
		return _invalid(loop["error"])

	return {
		"error": "",
		"snapshot": {
			"loop_number": loop_number,
			"cuaderno": cuaderno,
			"velo": velo,
			"marks": marks,
			"endings_seen": endings_seen,
			"hints": hints,
			"settings": settings,
			"last_route": last_route,
			"loop": loop,
		},
	}


static func _loop_state(source: Variant, data: GameData) -> Dictionary:
	if not source is Dictionary:
		return {"error": "falta el estado del bucle"}
	var time := _whole(source.get("time"), data.loop_start, data.day_end)
	if time == INVALID or time % data.step_minutes != 0:
		return {"error": "hora no válida"}
	var active: Variant = source.get("active")
	if not active is String or not data.is_protagonist(active):
		return {"error": "protagonista activo desconocido \"%s\"" % active}

	var positions_data: Variant = source.get("positions")
	if not positions_data is Dictionary or positions_data.size() != data.person_ids.size():
		return {"error": "posiciones no válidas"}
	var positions: Dictionary = {}
	for id: String in data.person_ids:
		var place: Variant = positions_data.get(id)
		if not place is String or not data.locations.has(place):
			return {"error": "posición no válida para \"%s\"" % id}
		positions[id] = place

	var flags: Dictionary = {}
	var flags_data: Variant = source.get("flags")
	if not flags_data is Dictionary:
		return {"error": "banderas no válidas"}
	for id: Variant in flags_data:
		var stamp := _whole(flags_data[id], 0, time)
		if not data.set_flags.has(str(id)) or stamp == INVALID:
			return {"error": "bandera no válida \"%s\"" % id}
		flags[str(id)] = stamp

	var letters_data: Variant = source.get("letters")
	if not letters_data is Dictionary or letters_data.size() != data.letter_ids.size():
		return {"error": "cartas no válidas"}
	var letters: Dictionary = {}
	for id: String in data.letter_ids:
		var letter: Variant = letters_data.get(id)
		if not letter is Dictionary or letter.size() != 2 or not GameData.LETTER_STATES.has(letter.get("state", "")) \
				or not letter.get("read") is bool:
			return {"error": "carta no válida \"%s\"" % id}
		letters[id] = {"state": letter["state"], "read": letter["read"]}

	var rastro := _whole(source.get("rastro"), 0, data.rastro_max)
	var desgaste := _whole(source.get("desgaste"), 0, data.desgaste_max)
	var exhausted := _whole(source.get("exhausted_until"), -1, data.day_end + 60)
	if rastro == INVALID or desgaste == INVALID or exhausted == INVALID:
		return {"error": "Rastro o Desgaste no válidos"}

	var trail := _true_set(source.get("trail"), data.was_at_refs.keys())
	var events_done := _true_set(source.get("events_done"), _event_ids(data))
	if trail.has("error") or events_done.has("error"):
		return {"error": "registro de eventos o posiciones no válido"}

	var log: Array = []
	var log_data: Variant = source.get("log")
	if not log_data is Array:
		return {"error": "registro no válido"}
	for entry: Variant in log_data:
		if not entry is Dictionary or entry.size() != 3 or not events_done.has(entry.get("event", "")) \
				or not data.locations.has(entry.get("place", "")) or _whole(entry.get("t"), data.loop_start, time) == INVALID:
			return {"error": "registro no válido"}
		log.append({"t": int(entry["t"]), "event": entry["event"], "place": entry["place"]})

	var route: Variant = _route(source.get("route"), data)
	if route == null:
		return {"error": "ruta no válida"}

	var outcome_data: Variant = source.get("outcome")
	if not outcome_data is Dictionary or outcome_data.size() != 2 or not outcome_data.get("lines") is Array \
			or not outcome_data.get("clues") is Array:
		return {"error": "diálogo pendiente no válido"}
	var lines: Array = []
	for line: Variant in outcome_data["lines"]:
		if not line is Dictionary or line.size() != 2 or not data.people.has(line.get("speaker", "")) or not line.get("text") is String:
			return {"error": "diálogo pendiente no válido"}
		lines.append({"speaker": line["speaker"], "text": line["text"]})
	var outcome_clues: Array = []
	for id: Variant in outcome_data["clues"]:
		if not id is String or not data.clues.has(id):
			return {"error": "diálogo pendiente no válido"}
		outcome_clues.append(id)

	var ending: Variant = source.get("ending")
	if not ending is String or (ending != "" and not _ending_ids(data).has(ending)) or (ending != "") != (time >= data.day_end):
		return {"error": "final no válido"}
	var stations := _stations(source.get("stations"), data)
	if stations.has("error"):
		return {"error": "estaciones no válidas"}
	var conversations := _conversations(source.get("conversations"), data)
	if conversations.has("error"):
		return {"error": "conversaciones del bucle no válidas"}
	if source.size() != 16:
		return {"error": "el estado del bucle tiene claves de más o de menos"}

	return {
		"time": time,
		"active": active,
		"positions": positions,
		"flags": flags,
		"letters": letters,
		"rastro": rastro,
		"desgaste": desgaste,
		"exhausted_until": exhausted,
		"trail": trail,
		"events_done": events_done,
		"log": log,
		"route": route,
		"outcome": {"lines": lines, "clues": outcome_clues},
		"ending": ending,
		"stations": stations,
		"conversations": conversations,
	}


## La versión 2 no tenía estaciones: cada protagonista empieza sin ninguna (la
## cámara va a la entrada del lugar). Lo demás no cambió.
static func _migrate_from_v2(save: Dictionary) -> Dictionary:
	var migrated: Dictionary = save.duplicate(true)
	if migrated.get("loop") is Dictionary and not migrated["loop"].has("stations"):
		migrated["loop"]["stations"] = {}
	return migrated


## De la 3 a la 4: sin marcas ni conversaciones, ajustes nuevos por defecto, y
## los temas guionizados que pasaron a conversaciones con cartas (Lina, Tun,
## Beto, Ruth) se quedan en la ruta como «esperar» allí: mismo tiempo y lugar.
## Lo que ya activaron sigue en las banderas del bucle; al repetir la ruta no se
## repite.
static func _migrate_from_v3(save: Dictionary, data: GameData) -> Dictionary:
	var migrated: Dictionary = save.duplicate(true)
	if migrated.get("loop") is Dictionary:
		if not migrated["loop"].has("conversations"):
			migrated["loop"]["conversations"] = {}
		if migrated["loop"].get("route") is Array:
			_replace_removed_talks(migrated["loop"]["route"], data)
	if migrated.get("last_route") is Array:
		_replace_removed_talks(migrated["last_route"], data)
	if not migrated.has("marks"):
		migrated["marks"] = {}
	if migrated.get("settings") is Dictionary:
		var settings: Dictionary = DEFAULT_SETTINGS.duplicate()
		settings.merge(migrated["settings"], true)
		migrated["settings"] = settings
	return migrated


static func _replace_removed_talks(route: Array, data: GameData) -> void:
	for entry: Variant in route:
		if not entry is Dictionary or not entry.get("command") is Dictionary:
			continue
		var command: Dictionary = entry["command"]
		var id: Variant = command.get("id", "")
		if command.get("verb", "") == "hablar" and id is String and not data.talks.has(id) and not data.conversations.has(id):
			command["verb"] = "esperar"
			command["target"] = ""
			command["id"] = ""


static func _settings(source: Variant, data: GameData) -> Dictionary:
	if not source is Dictionary or source.size() != DEFAULT_SETTINGS.size():
		return {"error": true}
	for key: String in ["reduced_motion", "mute", "breakpoint_chosen", "tips_seen"]:
		if not source.get(key) is bool:
			return {"error": true}
	for key: String in VOLUME_KEYS:
		var volume: Variant = source.get(key)
		if not (volume is float or volume is int) or volume < 0.0 or volume > 1.0:
			return {"error": true}
	if _whole(source.get("text_size"), 0, data.text_sizes.size() - 1) == INVALID or not HAPTIC_LEVELS.has(source.get("haptics", "")) \
			or not BREAKPOINT_MODES.has(source.get("breakpoint_mode", "")) or not BREAKPOINT_TIMES.has(source.get("breakpoint_time", "")):
		return {"error": true}
	var settings: Dictionary = source.duplicate()
	settings["text_size"] = int(source["text_size"])
	for key: String in VOLUME_KEYS:
		settings[key] = float(source[key])
	return settings


## {persona: {count, loop}}: cuántas veces la marcó Akba y en qué bucle la última.
static func _marks(source: Variant, data: GameData, loop_number: int) -> Dictionary:
	if not source is Dictionary:
		return {"error": true}
	var result: Dictionary = {}
	for person: Variant in source:
		var mark: Variant = source[person]
		if not data.npc_ids().has(str(person)) or not mark is Dictionary or mark.size() != 2:
			return {"error": true}
		var count := _whole(mark.get("count"), 1, 1_000_000)
		var loop := _whole(mark.get("loop"), 1, loop_number)
		if count == INVALID or loop == INVALID:
			return {"error": true}
		result[str(person)] = {"count": count, "loop": loop}
	return result


## {persona: {confianza, closed, won}} de las conversaciones de este bucle.
static func _conversations(source: Variant, data: GameData) -> Dictionary:
	if not source is Dictionary:
		return {"error": true}
	var result: Dictionary = {}
	for person: Variant in source:
		var state: Variant = source[person]
		var conversation_id: String = data.conversation_by_person.get(str(person), "")
		if conversation_id == "" or not state is Dictionary or state.size() != 3 or not state.get("closed") is bool \
				or not state.get("won") is Array:
			return {"error": true}
		var confianza := _whole(state.get("confianza"), 0, data.card_rules["confianza_max"])
		if confianza == INVALID:
			return {"error": true}
		var won: Array = []
		for door: Variant in state["won"]:
			if not data.conversation_elements.has(door) or data.conversation_elements[door]["conversation"] != conversation_id:
				return {"error": true}
			won.append(door)
		result[str(person)] = {"confianza": confianza, "closed": state["closed"], "won": won}
	return result


## {protagonista: {lugar con escena: estación}}; {"error": ...} si no encaja.
static func _stations(source: Variant, data: GameData) -> Dictionary:
	if not source is Dictionary:
		return {"error": true}
	var result: Dictionary = {}
	for actor: String in data.protagonist_ids:
		var per_place: Variant = source.get(actor, {})
		if not per_place is Dictionary:
			return {"error": true}
		result[actor] = {}
		for place: Variant in per_place:
			var station: Variant = per_place[place]
			if not data.has_scene(str(place)) or not station is String or not data.scenes[place]["station_index"].has(station):
				return {"error": true}
			result[actor][str(place)] = station
	for actor: Variant in source:
		if not data.is_protagonist(str(actor)):
			return {"error": true}
	return result


## Lista de pasos grabados; null si algo no encaja.
static func _route(source: Variant, data: GameData) -> Variant:
	if not source is Array:
		return null
	var route: Array = []
	for entry: Variant in source:
		if not entry is Dictionary or entry.size() != 2:
			return null
		var t := _whole(entry.get("t"), data.loop_start, data.day_end)
		if t == INVALID:
			return null
		if entry.has("switch"):
			if not data.is_protagonist(str(entry["switch"])):
				return null
			route.append({"t": t, "switch": entry["switch"]})
			continue
		var command: Variant = entry.get("command")
		if not command is Dictionary or not GameData.COMMAND_VERBS.has(command.get("verb", "")):
			return null
		var station: Variant = command.get("station", "")
		var extras: int = int(command.has("station")) + int(command.has("cards")) + int(command.has("decision"))
		if command.size() != 4 + extras:
			return null
		for key: String in ["place", "target", "id"]:
			if not command.get(key) is String:
				return null
		if command["place"] != "" and not data.locations.has(command["place"]):
			return null
		if command["target"] != "" and not data.people.has(command["target"]):
			return null
		var id: String = command["id"]
		if id != "" and not (data.talks.has(id) or data.interactions.has(id) or data.letters.has(id) or data.conversations.has(id)):
			return null
		var plain: Dictionary = {"verb": command["verb"], "place": command["place"], "target": command["target"], "id": id}
		if command.has("station"):
			if not station is String or not data.has_scene(command["place"]) or not data.scenes[command["place"]]["station_index"].has(station):
				return null
			plain["station"] = station
		if command.has("cards"):
			if not data.conversations.has(id) or not _cards_valid(command["cards"], data):
				return null
			plain["cards"] = Array(command["cards"]).duplicate()
		if command.has("decision"):
			if not data.breakpoint_by_interaction.has(id) or not GameData.DECISIONS.has(command["decision"]):
				return null
			plain["decision"] = command["decision"]
		route.append({"t": t, "command": plain})
	return route


## Cartas jugadas en una conversación: ids de carta o "conocimiento:pista:puerta".
static func _cards_valid(source: Variant, data: GameData) -> bool:
	if not source is Array or source.is_empty():
		return false
	for card: Variant in source:
		if not card is String:
			return false
		if card.begins_with("conocimiento:"):
			var parts: PackedStringArray = card.split(":")
			if parts.size() != 3 or not data.clues.has(parts[1]) or not data.conversation_elements.has(parts[2]):
				return false
		elif not data.cards.has(card):
			return false
	return true


## {id: entero entre lo y hi} con ids permitidos; {"error": ...} si no encaja.
static func _id_map(source: Variant, allowed: Array, lo: int, hi: int) -> Dictionary:
	if not source is Dictionary:
		return {"error": true}
	var result: Dictionary = {}
	for id: Variant in source:
		var value := _whole(source[id], lo, hi)
		if not allowed.has(str(id)) or value == INVALID:
			return {"error": true}
		result[str(id)] = value
	return result


static func _true_set(source: Variant, allowed: Array) -> Dictionary:
	if not source is Dictionary:
		return {"error": true}
	var result: Dictionary = {}
	for id: Variant in source:
		if not allowed.has(str(id)) or source[id] != true:
			return {"error": true}
		result[str(id)] = true
	return result


static func _ending_ids(data: GameData) -> Array:
	return data.endings.map(func(ending: Dictionary) -> String: return ending["id"])


static func _question_ids(data: GameData) -> Array:
	return data.questions.map(func(question: Dictionary) -> String: return question["id"])


static func _event_ids(data: GameData) -> Array:
	return data.events.map(func(event: Dictionary) -> String: return event["id"])


## El entero si está entre lo y hi; INVALID si no.
static func _whole(value: Variant, lo: int, hi: int) -> int:
	if not _is_whole(value) or int(value) < lo or int(value) > hi:
		return INVALID
	return int(value)


static func _is_whole(value: Variant) -> bool:
	return (value is int or value is float) and float(value) == floorf(value)


static func _invalid(message: String) -> Dictionary:
	return {"error": message, "snapshot": {}}
