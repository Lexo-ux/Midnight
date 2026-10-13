extends RefCounted
## Motor determinista de un bucle de Much. No tiene azar ni toca la escena:
## todo el estado del bucle vive en `s` (un Dictionary fácil de copiar y guardar).
##
## Un paso (30 minutos de reloj compartido):
##   1. el protagonista controlado hace su acción (y va a ese lugar);
##   2. el otro protagonista hace lo que le toca por rutina (Sazil reparte);
##   3. avanza el reloj y todos se colocan según su rutina y las banderas;
##   4. se evalúan los eventos de esa hora, una sola vez cada uno;
##   5. a medianoche se decide el final.
## Las condiciones se evalúan en el momento en que algo ocurre; lo ya ocurrido
## nunca se reescribe.
##
## Además guarda, solo para la presentación, la estación de cada protagonista en
## cada lugar (`stations`): sale de su última acción allí y nunca cambia reglas.
##
## Conversaciones con cartas: «hablar» con una persona que tiene conversación
## lleva en la orden la lista de cartas jugadas ("cards"); aquí se vuelve a
## jugar (scripts/conversation.gd) y se aplica el resultado. Momentos de
## quiebre: la orden de su interacción lleva "decision" ("sostuvo" o "soltó");
## nunca el tiempo que se mantuvo pulsado.

const GameData := preload("res://scripts/game_data.gd")
const SceneRules := preload("res://scripts/scene_rules.gd")
const Conversation := preload("res://scripts/conversation.gd")

const ROUTINE_VERB: String = "rutina"

var data: GameData
## Cuaderno permanente: id de pista -> {loop, by, time}. Se lee en las condiciones.
var cuaderno: Dictionary = {}
## Velo ganado (0-3) y marcas de Akba por persona, permanentes y compartidos con
## GameState: persona -> nivel; persona -> {count, loop}.
var velo: Dictionary = {}
var marks: Dictionary = {}
var loop_number: int = 1
## Modo exploración (validador): no toca el cuaderno ni prepara textos; lo
## descubierto va a `found` y el cuaderno queda fijo durante todo el bucle.
var exploring: bool = false
var found: Dictionary = {}
## Solo para exploration_key(): bandera (o "trail:quien@lugar@minuto") -> último
## minuto en que puede importar. Lo calcula el validador desde los datos.
var key_horizons: Dictionary = {}

## Estado del bucle.
var s: Dictionary = {}

## Índices de los datos (no cambian durante la partida), para que un paso sea
## barato: el validador simula cientos de miles.
var _visible_places: Array[String] = []
var _npcs: Array[String] = []
## persona -> ids de sus temas; lugar -> ids de sus interacciones.
var _talks_by_person: Dictionary = {}
var _interactions_by_place: Dictionary = {}
## persona -> {override: [tramos], normal: [tramos]}, del más tardío al más
## temprano (y, a igual hora, el último de la lista primero).
var _routine_desc: Dictionary = {}


func _init(game_data: GameData) -> void:
	data = game_data
	_visible_places = data.visible_location_ids()
	_npcs = data.npc_ids()
	for id: String in data.talks:
		var person: String = data.talks[id]["person"]
		if not _talks_by_person.has(person):
			_talks_by_person[person] = []
		_talks_by_person[person].append(id)
	for id: String in data.interactions:
		var place: String = data.interactions[id]["place"]
		if not _interactions_by_place.has(place):
			_interactions_by_place[place] = []
		_interactions_by_place[place].append(id)
	for person: String in data.person_ids:
		var routine: Array = data.people[person]["routine"]
		var order: Array = range(routine.size())
		order.sort_custom(func(a: int, b: int) -> bool:
			return routine[a]["from"] > routine[b]["from"] or (routine[a]["from"] == routine[b]["from"] and a > b))
		var groups: Dictionary = {"override": [], "normal": []}
		for i: int in order:
			groups["override" if routine[i]["override"] else "normal"].append(routine[i])
		_routine_desc[person] = groups


func begin_loop() -> void:
	var letters: Dictionary = {}
	for id: String in data.letter_ids:
		letters[id] = {"state": "bolsa", "read": false}
	s = {
		"time": data.loop_start,
		"active": data.start_active,
		"positions": {},
		"flags": {},
		"letters": letters,
		"rastro": 0,
		"desgaste": 0,
		"exhausted_until": -1,
		"trail": {},
		"events_done": {},
		"log": [],
		"route": [],
		"outcome": {"lines": [], "clues": []},
		"ending": "",
		"stations": {},
		"conversations": {},
	}
	for id: String in data.protagonist_ids:
		s["stations"][id] = {}
	_place_everyone("", {})
	_run_events()


func clone_state() -> Dictionary:
	return s.duplicate(true)


# --- Acciones -------------------------------------------------------------

func is_over() -> bool:
	return s["ending"] != ""


func switch_to(actor: String) -> bool:
	if is_over() or not data.is_protagonist(actor):
		return false
	if actor != s["active"]:
		s["active"] = actor
		if not exploring:
			s["route"].append({"t": s["time"], "switch": actor})
	return true


func is_disabled(actor: String) -> bool:
	var condition: Variant = data.people[actor]["disabled_if"]
	return condition != null and check(condition, {})


## Acciones que puede hacer `actor` ahora. Cada una es {verb, place, target, id, label}.
func actions_for(actor: String) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	if is_over() or is_disabled(actor):
		return actions
	var t: int = s["time"]
	var here: String = s["positions"][actor]
	if actor == "akba" and t < s["exhausted_until"]:
		actions.append(_action("esperar", here))
		return actions
	for place: String in _visible_places:
		actions.append(_action("esperar", place))
		actions.append(_action("observar", place))
		if actor != "akba" and not data.is_open(place, t):
			continue
		for person: String in people_at(place):
			actions.append(_action("observar", place, person))
			actions.append(_action("seguir", place, person))
			var conversation_id: String = data.conversation_by_person.get(person, "")
			if conversation_id != "" and not s["conversations"].get(person, {}).get("closed", false):
				actions.append(_action("hablar", place, person, conversation_id))
			for talk_id: String in _talks_by_person.get(person, []):
				var talk: Dictionary = data.talks[talk_id]
				if talk["actor"] in [actor, "any"] and check(talk["if"], {"place": place, "actor": actor}):
					actions.append(_action("hablar", place, person, talk_id))
		for id: String in _interactions_by_place.get(place, []):
			var interaction: Dictionary = data.interactions[id]
			if interaction["actor"] == actor and _interaction_open(interaction, t) \
					and _can_afford(interaction) and check(interaction["if"], {"place": place, "actor": actor}):
				actions.append(_action("interactuar", place, "", id))
		for letter_id: String in data.letter_ids:
			var letter: Dictionary = data.letters[letter_id]
			if letter["carrier"] != actor or s["letters"][letter_id]["state"] != "bolsa":
				continue
			if s["positions"][letter["recipient"]] == place:
				actions.append(_action("entregar", place, letter["recipient"], letter_id))
			for divert: Dictionary in letter["divert"]:
				if s["positions"][divert["to"]] == place:
					actions.append(_action("desviar", place, divert["to"], letter_id))
	for letter_id: String in data.letter_ids:
		var letter: Dictionary = data.letters[letter_id]
		var state: Dictionary = s["letters"][letter_id]
		if letter["carrier"] == actor and state["state"] == "bolsa":
			if not state["read"]:
				actions.append(_action("leer", here, "", letter_id))
			actions.append(_action("retener", here, "", letter_id))
	return actions


func is_available(actor: String, command: Dictionary) -> bool:
	var key := command_key(command)
	for action: Dictionary in actions_for(actor):
		if command_key(action) == key:
			return true
	return false


## Acción «pura»: solo da pistas y lleva al protagonista a un lugar (observar,
## seguir, esperar, leer, o hablar sin activar banderas). Para el validador
## equivale a esperar en ese lugar.
func is_pure_action(action: Dictionary) -> bool:
	match action["verb"]:
		"esperar", "observar", "seguir", "leer":
			return true
		"hablar":
			if data.conversations.has(action["id"]):
				return false
			var effects: Dictionary = data.talks[action["id"]]["effects"]
			return effects["set"].is_empty() and effects["rastro"] == 0
	return false


## Pistas que daría una acción pura ahora mismo, sin hacerla.
func preview_clues(actor: String, action: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	var target: String = action["target"]
	match action["verb"]:
		"observar":
			var variants: Array = data.people[target]["observe"] if target != "" else data.locations[action["place"]]["observe"]
			var chosen := _first_variant(variants, actor, {"place": action["place"], "actor": actor})
			if not chosen.is_empty():
				ids.append_array(chosen["clues"])
			if target != "":
				ids.append_array(_schedule_clues(target, actor, false))
		"seguir":
			ids.append_array(_schedule_clues(target, actor, true))
		"hablar":
			ids.append_array(data.talks[action["id"]]["effects"]["clues"])
		"leer":
			ids.append_array(data.letters[action["id"]]["read"]["effects"]["clues"])
	return ids


static func command_key(command: Dictionary) -> String:
	return "%s|%s|%s|%s" % [command.get("verb", ""), command.get("place", ""), command.get("target", ""), command.get("id", "")]


## Un paso de 30 minutos. `command` es una acción de actions_for() del
## protagonista activo, o {"verb": "rutina"} para que siga su rutina.
func step(command: Dictionary) -> bool:
	if is_over():
		return false
	var actor: String = s["active"]
	var acted: bool = command.get("verb", "") != ROUTINE_VERB
	if acted and not exploring and not is_available(actor, command):
		return false
	# Cartas solo en conversaciones y decisiones solo en quiebres (si no, la ruta
	# grabada no se podría volver a cargar).
	var is_conversation: bool = acted and command["verb"] == "hablar" and data.conversations.has(command["id"])
	if command.has("cards") and not is_conversation:
		return false
	if command.has("decision") and (not GameData.DECISIONS.has(command["decision"]) or command.get("verb", "") != "interactuar"
			or not data.breakpoint_by_interaction.has(command.get("id", ""))):
		return false
	var conversation: Dictionary = {}
	if is_conversation:
		conversation = Conversation.replay(data, command["id"], actor, conversation_context(actor, command["target"]),
				command.get("cards", []))
		if conversation.is_empty():
			return false
	s["outcome"] = {"lines": [], "clues": []}
	if not exploring:
		s["route"].append({"t": s["time"], "command": _plain_command(command)})
	var from_place: String = s["positions"][actor]
	if acted:
		_apply(actor, command, conversation)
	for id: String in data.protagonist_ids:
		if not acted or id != actor:
			_routine_tasks(id)
	s["time"] = s["time"] + data.step_minutes
	if s["time"] >= s["exhausted_until"]:
		s["exhausted_until"] = -1
	_place_everyone(actor if acted else "", command)
	if acted and not exploring:
		_note_station(actor, command, from_place)
	_run_events()
	if s["time"] >= data.day_end:
		_finish_loop()
	return true


# --- Consultas ------------------------------------------------------------

## Habitantes (no protagonistas) que están en `place` ahora.
func people_at(place: String) -> Array[String]:
	var here: Array[String] = []
	for id: String in _npcs:
		if s["positions"].get(id, "") == place:
			here.append(id)
	return here


func has_clue(id: String) -> bool:
	return cuaderno.has(id)


## Lo que una conversación con `person` necesita saber del mundo ahora mismo.
## La Confianza que quedó en este bucle se conserva; si Akba la marcó en el
## bucle anterior, empieza con 1 menos y con miedo.
func conversation_context(actor: String, person: String) -> Dictionary:
	var place: String = s["positions"].get(person, "")
	var state: Dictionary = s["conversations"].get(person, {})
	var frightened: bool = marks.get(person, {}).get("loop", -1) == loop_number - 1 and not state.has("confianza")
	var start: int = data.people[person]["confianza_inicial"] - (1 if frightened else 0)
	return {
		"knows": has_clue,
		"check": func(condition: Variant) -> bool: return check(condition, {"place": place, "actor": actor}),
		"confianza": state.get("confianza", start),
		"frightened": frightened,
		"won": state.get("won", []),
	}


func check(condition: Variant, context: Dictionary) -> bool:
	if condition == null:
		return true
	if condition is String:
		return s["flags"].has(condition)
	if condition is Array:
		for item: Variant in condition:
			if not check(item, context):
				return false
		return true
	var key: String = ""
	for name: String in condition:
		key = name
		break
	var value: Variant = condition[key]
	match key:
		"ALL":
			return check(value, context)
		"ANY":
			for item: Variant in value:
				if check(item, context):
					return true
			return false
		"NOT":
			if value is Array:
				for item: Variant in value:
					if check(item, context):
						return false
				return true
			return not check(value, context)
		"clue":
			return has_clue(value)
		"at":
			return s["positions"].get(value["who"], "") == value["place"]
		"together":
			return s["positions"].get(value[0], "a") == s["positions"].get(value[1], "b")
		"was_at":
			return s["trail"].has("%s@%s@%d" % [value["who"], value["place"], GameData.parse_time(value["time"])])
		"rastro_min":
			return s["rastro"] >= data.threshold(value)
		"rastro_max":
			return s["rastro"] <= data.threshold(value)
		"letter":
			return s["letters"][value["id"]]["state"] == value["state"]
		"night":
			return data.is_night(s["time"]) == value
		"interior":
			return data.locations.has(context.get("place", "")) and data.locations[context["place"]]["interior"] == value
		"time_from":
			return s["time"] >= GameData.parse_time(value)
		"time_to":
			return s["time"] < GameData.parse_time(value)
		"flag_earlier":
			return s["flags"].has(value) and s["flags"][value] < s["time"]
	return false


## Clave compacta del estado para la exploración: solo lo que cambia el futuro.
## Los eventos ya ocurridos se deducen de la hora y las banderas; la posición de
## Akba solo cuenta cuando Marcos lo busca, y la de Sazil, a través del rastro
## de las condiciones was_at (`trail`). Las banderas y rastros cuyo horizonte
## (`key_horizons`, último minuto en que alguna condición puede leerlos) ya pasó
## no cuentan.
func exploration_key() -> String:
	var t: int = s["time"]
	var flags: Array = []
	for flag: String in s["flags"]:
		if key_horizons.get(flag, data.day_end) >= t:
			flags.append(flag)
	flags.sort()
	var letters: PackedStringArray = []
	for id: String in data.letter_ids:
		letters.append(s["letters"][id]["state"])
	var trail: Array = []
	for key: String in s["trail"]:
		if key_horizons.get("trail:" + key, data.day_end) >= t:
			trail.append(key)
	trail.sort()
	# Las conversaciones no cuentan: lo que una puerta abierta cambia del futuro
	# ya está en sus banderas (con su horizonte), y sus pistas ya se anotaron en
	# `found`. Fundir dos estados que solo difieren en puertas abiertas (o en la
	# Confianza que queda) solo puede permitir volver a ganar una puerta, que no
	# añade nada salvo el coste de forzar: una aproximación generosa.
	var hunted: bool = s["rastro"] >= data.rastro_max or s["flags"].has("marcos_busca_akba")
	return "%d|%s|%s|%d|%d|%d|%s|%s|%s" % [s["time"], ",".join(flags), ",".join(letters), s["rastro"],
			s["desgaste"], s["exhausted_until"], s["positions"]["akba"] if hunted else "-", ",".join(trail), s["ending"]]


# --- Interno --------------------------------------------------------------

func _action(verb: String, place: String, target: String = "", id: String = "") -> Dictionary:
	return {"verb": verb, "place": place, "target": target, "id": id}


## La orden tal cual se graba en la ruta. "station" solo viene de tocar un punto
## interactivo; no cambia la acción, solo adónde mira la cámara.
func _plain_command(command: Dictionary) -> Dictionary:
	var plain: Dictionary = {"verb": command.get("verb", ""), "place": command.get("place", ""),
			"target": command.get("target", ""), "id": command.get("id", "")}
	if command.get("station", "") != "":
		plain["station"] = command["station"]
	if command.has("cards"):
		plain["cards"] = Array(command["cards"]).duplicate()
	if command.has("decision"):
		plain["decision"] = command["decision"]
	return plain


func _note_station(actor: String, command: Dictionary, from_place: String) -> void:
	var place: String = command["place"]
	var stations: Dictionary = s["stations"][actor]
	var station := SceneRules.station_after(data, command, from_place, stations.get(place, ""))
	if station != "":
		stations[place] = station


func _interaction_open(interaction: Dictionary, t: int) -> bool:
	if not interaction["times"].is_empty():
		return interaction["times"].has(t)
	return t >= interaction["from"] and t < interaction["to"]


func _can_afford(interaction: Dictionary) -> bool:
	return not GameData.FORCING_VERBS.has(interaction["verb"]) or s["desgaste"] < data.desgaste_max


func _apply(actor: String, command: Dictionary, conversation: Dictionary) -> void:
	var place: String = command["place"]
	var target: String = command["target"]
	var context: Dictionary = {"place": place, "actor": actor}
	match command["verb"]:
		"esperar":
			_say(actor, data.text("linea_esperar_" + actor), {})
		"observar":
			var variants: Array = data.people[target]["observe"] if target != "" else data.locations[place]["observe"]
			var chosen := _first_variant(variants, actor, context)
			if not chosen.is_empty():
				_play_lines(chosen["lines"])
				for id: String in chosen["clues"]:
					_grant(id, actor)
			if target != "":
				_learn_schedule(target, actor, false)
		"seguir":
			_say(actor, data.text("linea_seguir_" + actor), {"nombre": data.people[target]["name"]})
			_learn_schedule(target, actor, true)
		"hablar":
			if not conversation.is_empty():
				_apply_conversation(actor, conversation)
				return
			var talk: Dictionary = data.talks[command["id"]]
			_play_lines(talk["lines"])
			_apply_effects(talk["effects"], actor)
		"interactuar":
			# Un momento de quiebre en el que se soltó: pasa la media hora y nada más.
			if command.get("decision", "sostuvo") == "soltó":
				return
			var interaction: Dictionary = data.interactions[command["id"]]
			_play_lines(interaction["lines"])
			_apply_effects(interaction["effects"], actor)
			if GameData.FORCING_VERBS.has(interaction["verb"]):
				_force(interaction["rastro"])
		"leer":
			s["letters"][command["id"]]["read"] = true
			_play_part(data.letters[command["id"]]["read"], actor)
		"retener":
			s["letters"][command["id"]]["state"] = "retenida"
			_play_part(data.letters[command["id"]]["retain"], actor)
		"entregar":
			s["letters"][command["id"]]["state"] = "entregada"
			_play_part(data.letters[command["id"]]["deliver"], actor)
		"desviar":
			s["letters"][command["id"]]["state"] = "desviada"
			for divert: Dictionary in data.letters[command["id"]]["divert"]:
				if divert["to"] == target:
					_play_part(divert, actor)


## El resultado de una conversación ya jugada. Sus líneas ya se vieron en la
## conversación; aquí quedan las pistas, la puerta abierta y lo que cuesta.
func _apply_conversation(actor: String, conv: Dictionary) -> void:
	var person: String = conv["person"]
	var conversation: Dictionary = data.conversations[conv["conversation"]]
	# Mismo orden de claves que al cargar la partida (la ida y vuelta es exacta).
	var state: Dictionary = {"confianza": conv["confianza"], "closed": conv["result"] == "closed",
			"won": s["conversations"].get(person, {}).get("won", [])}
	for clue: String in conv["clues"]:
		_grant(clue, actor)
	if conv["result"] == "win":
		var door: Dictionary = data.conversation_elements[conv["door"]]
		_apply_effects(door["effects"], actor)
		state["won"] = state["won"] + [door["id"]]
		_raise_velo(person, 2)
		if exploring:
			found["door:" + door["id"]] = true
		if conv["forced"]:
			_force(data.card_rules["forced_rastro"])
			if not exploring:
				var mark: Dictionary = marks.get(person, {"count": 0, "loop": 0})
				marks[person] = {"count": mark["count"] + 1, "loop": loop_number}
	var trust: Variant = conversation["trust"]
	if trust != null and not state["closed"] and trust["actor"] == actor and conv["confianza"] >= trust["min"]:
		for flag: String in trust["set"]:
			_set_flag(flag)
	s["conversations"][person] = state


func _raise_velo(person: String, level: int) -> void:
	if not exploring and velo.get(person, 0) < level:
		velo[person] = level


## El Umbral se paga: Desgaste (doble de día), Rastro y la marca de que Akba forzó algo.
func _force(rastro: int) -> void:
	var t: int = s["time"]
	var cost: int = data.desgaste_cost * (1 if data.is_night(t) else data.desgaste_day_multiplier)
	s["desgaste"] = mini(s["desgaste"] + cost, data.desgaste_max)
	s["rastro"] = mini(s["rastro"] + rastro, data.rastro_max)
	_set_flag("akba_forzo")
	if s["desgaste"] >= data.desgaste_max:
		s["exhausted_until"] = (floori(t / 60.0) + 1) * 60


## Sazil reparte por su cuenta las cartas cuyo destinatario está donde ella está.
func _routine_tasks(actor: String) -> void:
	if not data.people[actor]["delivers_letters"] or is_disabled(actor):
		return
	for id: String in data.letter_ids:
		var letter: Dictionary = data.letters[id]
		if letter["carrier"] == actor and s["letters"][id]["state"] == "bolsa" \
				and s["positions"][letter["recipient"]] == s["positions"][actor]:
			s["letters"][id]["state"] = "entregada"
			_apply_effects(letter["deliver"]["effects"], actor)


func _place_everyone(acted_actor: String, command: Dictionary) -> void:
	var t: int = s["time"]
	var positions: Dictionary = s["positions"]
	var following := ""
	for id: String in data.protagonist_ids:
		if id == acted_actor and not is_disabled(id):
			if command["verb"] == "seguir":
				following = command["target"]
				continue
			positions[id] = command["place"]
		else:
			positions[id] = _routine_place(id, t)
	for id: String in _npcs:
		positions[id] = _routine_place(id, t)
	if following != "":
		positions[acted_actor] = positions[following]
	for id: String in data.protagonist_ids:
		var key := "%s@%s@%d" % [id, positions[id], t]
		if data.was_at_refs.has(key):
			s["trail"][key] = true


## Dónde está una persona a la hora `t`: el tramo "override" más reciente que se
## cumpla; si no, el tramo normal más reciente que se cumpla (a igual hora, el
## último de la lista).
func _routine_place(id: String, t: int) -> String:
	var chosen: Dictionary = {}
	var groups: Dictionary = _routine_desc[id]
	for group: String in ["override", "normal"]:
		for segment: Dictionary in groups[group]:
			if segment["from"] <= t and check(segment["if"], {"place": segment["place"]}):
				chosen = segment
				break
		if not chosen.is_empty():
			break
	if chosen.is_empty():
		chosen = data.people[id]["routine"][0]
	if chosen["follow"] != "":
		return s["positions"].get(chosen["follow"], data.people[id]["routine"][0]["place"])
	return chosen["place"]


func _run_events() -> void:
	var t: int = s["time"]
	for event: Dictionary in data.events:
		if s["events_done"].has(event["id"]) or (event["time"] != t and event["time"] != -1):
			continue
		var place: String = event["place"]
		if place.begins_with("@"):
			place = s["positions"][place.substr(1)]
		var context: Dictionary = {"place": place}
		if not check(event["if"], context):
			continue
		var variant: Dictionary = {}
		for candidate: Dictionary in event["variants"]:
			if check(candidate["if"], context):
				variant = candidate
				break
		if variant.is_empty():
			continue
		s["events_done"][event["id"]] = true
		if not exploring:
			s["log"].append({"t": t, "event": event["id"], "place": place})
		_apply_effects(variant["effects"], "")
		for witness: String in data.protagonist_ids:
			if s["positions"][witness] != place:
				continue
			var part: Dictionary = variant["witness"].get(witness, variant["witness"].get("any", {}))
			if part.is_empty():
				continue
			if witness == s["active"]:
				_play_lines(part["lines"])
			for id: String in part["clues"]:
				_grant(id, witness)


func _finish_loop() -> void:
	var chosen: Dictionary = data.default_ending()
	for ending: Dictionary in data.endings:
		if not ending["default"] and check(ending["if"], {}):
			chosen = ending
			break
	s["ending"] = chosen["id"]
	_grant(chosen["clue"], s["active"])
	# Velo 3 por salvar a alguien: sigue entero a medianoche.
	for id: String in data.npc_ids():
		var velo3: Variant = data.people[id]["velo3"]
		if velo3 != null and velo3["saved_if"] != null and check(velo3["saved_if"], {}):
			_raise_velo(id, 3)
	if exploring:
		found["ending:" + chosen["id"]] = true


func _first_variant(variants: Array, actor: String, context: Dictionary) -> Dictionary:
	for variant: Dictionary in variants:
		if variant["actor"] in [actor, "any"] and check(variant["if"], context):
			return variant
	return {}


## Horario: Sazil se fija y lo apunta entero; Akba solo el tramo de ahora.
## Seguir a alguien revela además adónde va después.
func _learn_schedule(person: String, actor: String, next_too: bool) -> void:
	for id: String in _schedule_clues(person, actor, next_too):
		_grant(id, actor)


func _schedule_clues(person: String, actor: String, next_too: bool) -> Array[String]:
	var t: int = s["time"]
	var ids: Array[String] = []
	var schedule := data.relevant_schedule(person)
	for i: int in schedule.size():
		var segment: Dictionary = schedule[i]
		var current: bool = segment["from"] <= t and t < segment["window_end"]
		var upcoming: bool = next_too and i > 0 and schedule[i - 1]["from"] <= t and t < schedule[i - 1]["window_end"]
		if actor == "sazil" and not next_too or current or upcoming:
			ids.append("horario_" + segment["id"])
	return ids


func _apply_effects(effects: Dictionary, actor: String) -> void:
	for flag: String in effects["set"]:
		_set_flag(flag)
	for id: String in effects["clues"]:
		_grant(id, actor if actor != "" else s["active"])
	if effects["rastro"] != 0:
		s["rastro"] = clampi(s["rastro"] + effects["rastro"], 0, data.rastro_max)


func _set_flag(flag: String) -> void:
	if not s["flags"].has(flag):
		s["flags"][flag] = s["time"]


func _grant(id: String, by: String) -> void:
	if exploring:
		found[id] = true
		return
	if cuaderno.has(id):
		return
	cuaderno[id] = {"loop": loop_number, "by": by, "time": s["time"]}
	s["outcome"]["clues"].append(id)
	# Velo 3 por descubrir el secreto de alguien.
	var person: String = data.clues[id]["person"]
	if person != "" and data.people[person]["velo3"] != null and data.people[person]["velo3"]["secret"] == id:
		_raise_velo(person, 3)


func _play_part(part: Dictionary, actor: String) -> void:
	_play_lines(part["lines"])
	_apply_effects(part["effects"], actor)


func _play_lines(lines: Array) -> void:
	if exploring:
		return
	for line: Dictionary in lines:
		s["outcome"]["lines"].append({"speaker": line["speaker"], "text": line["text"]})


func _say(speaker: String, template: String, values: Dictionary) -> void:
	if not exploring:
		s["outcome"]["lines"].append({"speaker": speaker, "text": template.format(values)})
