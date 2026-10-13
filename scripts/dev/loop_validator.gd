extends RefCounted
## Validador de bucles: recorre en anchura los estados de un bucle con el mismo
## motor que el juego (Simulation en modo exploración) y responde qué pistas y
## qué finales se pueden alcanzar.
##
## Estado simplificado: los textos, el registro y la ruta no cuentan; dos estados
## son iguales si coinciden en hora, banderas, cartas, Rastro, Desgaste,
## posiciones de los protagonistas, eventos ya ocurridos y pistas del bucle que
## cambian condiciones (ver Simulation.exploration_key()).
##
## Entre bucles: cada pasada empieza con el Cuaderno de la anterior más todo lo
## descubierto en ella, hasta que no aparece nada nuevo. Unir lo descubierto en
## ramas distintas es una aproximación (generosa) del jugador que vuelve.
##
## Puntos interactivos (data/scenes.json): tocarlos es «observar» el lugar, así
## que aquí se anota qué pista da observar cada lugar, con qué mirada y a qué
## hora, y se comprueba que cada punto revele su pista dentro de su ventana.
##
## Conversaciones con cartas, ABSTRAÍDAS (ver _conversation_commands()): aquí
## nunca se buscan secuencias de cartas. Cada conversación da 1-4 órdenes, una
## por efecto distinto en el bucle (banderas nuevas, si fue a la fuerza). Sin
## esa abstracción la búsqueda no terminaba (más de 10 minutos). La prueba lenta
## scripts/dev/tests/slow/test_conversation_abstraction.gd (run_tests.gd -- --slow) comprueba que los resultados
## de Conversation.solve() son los mismos que probando todas las secuencias.
## Los quiebres: «sostuvo» es la interacción; «soltó» deja el mismo estado que
## esperar allí, que ya se explora.
##
## Límites: `max_states` (estados en total) y `timeout_ms`. Si se pasan, la
## búsqueda se corta, `aborted` explica qué dimensión del estado creció más y
## validate() lo da como problema. Nunca se ejecuta sin límite.

const GameData := preload("res://scripts/game_data.gd")
const Simulation := preload("res://scripts/simulation.gd")
const Conversation := preload("res://scripts/conversation.gd")

const MAX_PASSES: int = 8
const DEFAULT_MAX_STATES: int = 2000000
## Partes de Simulation.exploration_key(), para explicar un corte.
const KEY_DIMENSIONS: PackedStringArray = ["hora", "banderas", "cartas", "Rastro", "Desgaste", "agotamiento",
		"posición de Akba", "rastros was_at", "final"]

var data: GameData
var max_states: int = DEFAULT_MAX_STATES
## 0: sin límite de tiempo (los estados siguen limitados).
var timeout_ms: int = 0
## Estados explorados desde que se creó el validador (o desde reset_limits()).
var total_states: int = 0
## "" o el motivo del corte.
var aborted: String = ""
var _started_ms: int = 0
## Bandera (o "trail:...") -> último minuto en que alguna condición puede leerla.
var horizons: Dictionary = {}
## "lugar|protagonista|minuto|pista" -> true: observar el lugar dio esa pista.
var observed: Dictionary = {}


func _init(game_data: GameData) -> void:
	data = game_data
	horizons = _compute_horizons()
	reset_limits()


func reset_limits() -> void:
	total_states = 0
	aborted = ""
	_started_ms = Time.get_ticks_msec()


## Un bucle completo desde `cuaderno`. `banned` son ids de temas, interacciones
## o cartas (o "verbo:carta", p. ej. "retener:orden_lina") que no se pueden usar.
## Devuelve {found: {pista|ending:id: true}, states: int, aborted: String}.
func explore_loop(cuaderno: Dictionary, banned: Dictionary = {}) -> Dictionary:
	var sim := Simulation.new(data)
	sim.exploring = true
	sim.cuaderno = cuaderno
	sim.key_horizons = horizons
	sim.begin_loop()
	var frontier: Array[Dictionary] = [sim.clone_state()]
	var seen: Dictionary = {sim.exploration_key(): true}
	var states: int = 1
	while not frontier.is_empty() and aborted == "":
		var next_frontier: Array[Dictionary] = []
		for state: Dictionary in frontier:
			if total_states + states > max_states or (timeout_ms > 0 and Time.get_ticks_msec() - _started_ms > timeout_ms):
				aborted = _abort_reason(sim, frontier, total_states + states)
				break
			for command: Dictionary in _successor_commands(sim, state, banned):
				sim.s = state.duplicate(true)
				if command.has("actor"):
					sim.s["active"] = command["actor"]
				if not sim.step(command["command"]):
					continue
				var key := sim.exploration_key()
				if seen.has(key):
					continue
				seen[key] = true
				states += 1
				if not sim.is_over():
					next_frontier.append(sim.s)
		frontier = next_frontier
	total_states += states
	return {"found": sim.found, "states": states, "aborted": aborted}


## Por qué se cortó: límite pasado y la dimensión de la clave con más valores
## distintos en la frontera (la que más ha crecido).
func _abort_reason(sim: Simulation, frontier: Array[Dictionary], states: int) -> String:
	var distinct: Array[Dictionary] = []
	for i: int in KEY_DIMENSIONS.size():
		distinct.append({})
	for state: Dictionary in frontier:
		sim.s = state
		var parts := sim.exploration_key().split("|")
		for i: int in mini(parts.size(), KEY_DIMENSIONS.size()):
			distinct[i][parts[i]] = true
	var widest: int = 1
	for i: int in KEY_DIMENSIONS.size():
		if distinct[i].size() > distinct[widest].size():
			widest = i
	var limit := "%d estados" % max_states if states > max_states else "%d s" % (timeout_ms / 1000)
	return "búsqueda cortada (límite de %s) a las %s con %d estados y %d en la frontera; la dimensión que más creció: %s (%d valores distintos)." % [
			limit, GameData.format_time(frontier[0]["time"]), states, frontier.size(), KEY_DIMENSIONS[widest], distinct[widest].size()]


## Pasadas sucesivas hasta que no se descubre nada más.
## Devuelve {clues: {id: pasada}, endings: {id: pasada}, passes, states}.
func explore_all(banned: Dictionary = {}, start_cuaderno: Dictionary = {}) -> Dictionary:
	var cuaderno: Dictionary = start_cuaderno.duplicate()
	observed.clear()
	var clues: Dictionary = {}
	var endings: Dictionary = {}
	var doors: Dictionary = {}
	var pass_states: int = 0
	var passes: int = 0
	for pass_number: int in range(1, MAX_PASSES + 1):
		passes = pass_number
		var result := explore_loop(cuaderno, banned)
		pass_states += result["states"]
		if result["aborted"] != "":
			break
		# Solo cambian el bucle siguiente las pistas que aparecen en alguna condición.
		var changes_next_loop := false
		for key: String in result["found"]:
			if key.begins_with("ending:"):
				if not endings.has(key.substr(7)):
					endings[key.substr(7)] = pass_number
			elif key.begins_with("door:"):
				if not doors.has(key.substr(5)):
					doors[key.substr(5)] = pass_number
			elif not clues.has(key):
				clues[key] = pass_number
				cuaderno[key] = {"loop": pass_number, "by": data.start_active, "time": data.loop_start}
				changes_next_loop = changes_next_loop or data.referenced_clues.has(key)
		if not changes_next_loop:
			break
	return {"clues": clues, "endings": endings, "doors": doors, "passes": passes, "states": pass_states, "aborted": aborted}


## Comprueba todo y devuelve {problems, result}. Con `start_cuaderno` se parte de
## ese Cuaderno (los tests usan uno completo para comprobar solo lo que impone la hora).
func validate(start_cuaderno: Dictionary = {}) -> Dictionary:
	var problems: PackedStringArray = []
	var result := explore_all({}, start_cuaderno)
	if aborted != "":
		problems.append(aborted)
		return {"problems": problems, "result": result}
	for id: String in start_cuaderno:
		result["clues"][id] = 0
	for id: String in data.clue_ids:
		var clue: Dictionary = data.clues[id]
		if clue["type"] == "Horario" and not _schedule_clue_in_window(clue):
			continue
		if not result["clues"].has(id):
			problems.append("la pista \"%s\" es inalcanzable." % id)
	for ending: Dictionary in data.endings:
		if not result["endings"].has(ending["id"]):
			problems.append("el final \"%s\" es inalcanzable dentro de la ventana %s-%s." % [
				ending["id"], GameData.format_time(data.loop_start), GameData.format_time(data.day_end)])
	for id: String in data.conversation_elements:
		var element: Dictionary = data.conversation_elements[id]
		if element["kind"] == "door" and not result["doors"].has(id):
			problems.append("la puerta \"%s\" de %s no se abre por ningún camino." % [id, element["person"]])
	for door: String in data.door_sources:
		for clue: String in data.door_sources[door]:
			if not result["clues"].has(clue):
				problems.append("la carta de Conocimiento \"%s\" (puerta \"%s\") sale de una pista inalcanzable." % [clue, door])
	result["hotspot_clues"] = {}
	for id: String in data.hotspots:
		var hotspot: Dictionary = data.hotspots[id]
		if hotspot["link_kind"] != "clue":
			continue
		if hotspot_reveals(hotspot):
			result["hotspot_clues"][hotspot["link_id"]] = true
		else:
			problems.append("el punto \"%s\" nunca revela \"%s\" con su mirada entre las %s y las %s." % [id,
					hotspot["link_id"], GameData.format_time(hotspot["from"]), GameData.format_time(hotspot["to"])])
	return {"problems": problems, "result": result}


## Algún estado explorado, dentro de la ventana y con la mirada del punto, da su pista al observar el lugar.
func hotspot_reveals(hotspot: Dictionary) -> bool:
	for minute: int in range(hotspot["from"], hotspot["to"], data.step_minutes):
		for actor: String in data.protagonist_ids:
			if (hotspot["look"] == "both" or hotspot["look"] == actor) 					and observed.has("%s|%s|%d|%s" % [hotspot["place"], actor, minute, hotspot["link_id"]]):
				return true
	return false


## Grafo de pistas en Mermaid: qué pistas habilitan qué, y qué lleva a cada final.
func clue_graph_markdown(result: Dictionary) -> String:
	var lines: PackedStringArray = [
		"# Grafo de pistas de Medianoche en Much",
		"",
		"Generado por `scripts/dev/validate_loops.gd`. Una flecha A --> B significa que una",
		"acción o evento que exige A puede dar B. Las banderas van entre corchetes; el número",
		"tras cada pista es la primera pasada (bucle) en que el validador la alcanzó. Los",
		"círculos con línea de puntos son puntos interactivos de las escenas.",
		"",
		"```mermaid",
		"flowchart LR",
	]
	var edges: Dictionary = {}
	var sources: Array[Dictionary] = []
	for id: String in data.talks:
		sources.append({"if": data.talks[id]["if"], "effects": data.talks[id]["effects"]})
	for id: String in data.interactions:
		sources.append({"if": data.interactions[id]["if"], "effects": data.interactions[id]["effects"]})
	for location_id: String in data.location_ids:
		for variant: Dictionary in data.locations[location_id]["observe"]:
			sources.append({"if": variant["if"], "effects": {"set": [], "clues": variant["clues"]}})
	for id: String in data.conversation_elements:
		var element: Dictionary = data.conversation_elements[id]
		if element["kind"] == "door":
			sources.append({"if": element["if"], "effects": element["effects"]})
			for clue: String in data.door_sources.get(id, []):
				sources.append({"if": {"clue": clue}, "effects": element["effects"]})
	for event: Dictionary in data.events:
		for variant: Dictionary in event["variants"]:
			var witnessed: Array = []
			for part: Dictionary in variant["witness"].values():
				witnessed.append_array(part["clues"])
			sources.append({"if": [event["if"], variant["if"]], "effects": {"set": variant["effects"]["set"], "clues": witnessed}})
	for source: Dictionary in sources:
		var needs := _referenced(source["if"])
		for need: String in needs:
			for clue: String in source["effects"]["clues"]:
				edges["%s --> %s" % [_node(need, result), _node(clue, result)]] = true
			for flag: String in source["effects"]["set"]:
				edges["%s --> %s" % [_node(need, result), _node("[" + flag + "]", result)]] = true
	for ending: Dictionary in data.endings:
		for need: String in _referenced(ending["if"]):
			edges["%s --> %s" % [_node(need, result), _node("FINAL:" + ending["id"], result)]] = true
	for id: String in data.hotspots:
		var hotspot: Dictionary = data.hotspots[id]
		if hotspot["link_kind"] == "clue":
			edges['hs_%s(("%s")) -.-> %s' % [id, hotspot["label"], _node(hotspot["link_id"], result)]] = true
	var sorted: Array = edges.keys()
	sorted.sort()
	for edge: String in sorted:
		lines.append("    " + edge)
	lines.append("```")
	return "\n".join(lines) + "\n"


## Sucesores de un estado. Las acciones puras (ver Simulation.is_pure_action())
## no se simulan una a una: sus pistas se anotan directamente y basta con
## «esperar» una vez en cada lugar, que deja el mismo estado.
func _successor_commands(sim: Simulation, state: Dictionary, banned: Dictionary) -> Array[Dictionary]:
	sim.s = state
	var commands: Array[Dictionary] = [{"command": {"verb": Simulation.ROUTINE_VERB}}]
	for actor: String in data.protagonist_ids:
		sim.s["active"] = actor
		var waited: Dictionary = {}
		for action: Dictionary in sim.actions_for(actor):
			if banned.has(action["id"]) or banned.has("%s:%s" % [action["verb"], action["id"]]):
				continue
			if action["verb"] == "hablar" and data.conversations.has(action["id"]):
				commands.append_array(_conversation_commands(sim, actor, action, banned, waited))
				continue
			if not sim.is_pure_action(action):
				commands.append({"actor": actor, "command": action})
				continue
			for id: String in sim.preview_clues(actor, action):
				sim.found[id] = true
				if action["verb"] == "observar" and action["target"] == "":
					observed["%s|%s|%d|%s" % [action["place"], actor, state["time"], id]] = true
			if not waited.has(action["place"]):
				waited[action["place"]] = true
				commands.append({"actor": actor, "command": {"verb": "esperar", "place": action["place"], "target": "", "id": ""}})
	sim.s["active"] = state["active"]
	return commands


## Una conversación como órdenes, ABSTRAÍDA: nunca se buscan secuencias de
## cartas aquí. Conversation.listen() y Conversation.solve() (con caché por
## persona, puertas abiertas y lo que sabe el Cuaderno) dan los resultados
## posibles, y aquí se agrupan por su EFECTO en el bucle: banderas nuevas (de la
## puerta y de confianza) y si fue a la fuerza (Rastro, Desgaste, akba_forzo).
## Resultados sin efecto (solo pistas: escuchar, o una puerta que solo cuenta un
## secreto) se anotan y equivalen a esperar allí. Cada efecto distinto es una
## sola orden (1-4 por conversación).
func _conversation_commands(sim: Simulation, actor: String, action: Dictionary, banned: Dictionary,
		waited: Dictionary) -> Array[Dictionary]:
	var commands: Array[Dictionary] = []
	var by_effect: Dictionary = {}
	var context := sim.conversation_context(actor, action["target"])
	var outcomes: Array = []
	var listening := Conversation.listen(data, action["id"], actor, context)
	if not listening["cards"].is_empty():
		outcomes.append({"door": "", "cards": listening["cards"], "forced": false, "confianza": listening["confianza"],
				"clues": listening["clues"]})
	outcomes.append_array(Conversation.solve(data, action["id"], actor, context))
	var effects: Array[String] = []
	var unforced: Dictionary = {}
	for outcome: Dictionary in outcomes:
		var door: String = outcome["door"]
		if door != "" and banned.has("door:" + door):
			effects.append("banned")
			continue
		# Cualquier resultado es alcanzable desde aquí: sus pistas y su puerta cuentan ya.
		for clue: String in outcome["clues"]:
			sim.found[clue] = true
		if door != "":
			sim.found["door:" + door] = true
			for clue: String in data.conversation_elements[door]["effects"]["clues"]:
				sim.found[clue] = true
		var effect := _conversation_effect(sim, action["id"], actor, outcome)
		effects.append(effect)
		if not outcome["forced"]:
			unforced[effect.get_slice("|", 0) + "|" + effect.get_slice("|", 2) if effect != "" else "|0"] = true
	for i: int in outcomes.size():
		var effect := effects[i]
		if effect == "banned":
			continue
		if effect == "":
			if not waited.has(action["place"]):
				waited[action["place"]] = true
				commands.append({"actor": actor, "command": {"verb": "esperar", "place": action["place"], "target": "", "id": ""}})
			continue
		# Dominancia: ganar a la fuerza deja lo mismo que ganar sin forzar más el
		# coste de forzar; si aquí se puede lo segundo, lo primero no se explora.
		if outcomes[i]["forced"] and unforced.has(effect.get_slice("|", 0) + "|" + effect.get_slice("|", 2)):
			continue
		if not by_effect.has(effect):
			by_effect[effect] = true
			var command: Dictionary = action.duplicate()
			command["cards"] = outcomes[i]["cards"]
			commands.append({"actor": actor, "command": command})
	return commands


## Firma del efecto de un resultado en el estado actual: "" si no cambia nada
## más que las pistas; si no, las banderas nuevas ordenadas y si fue a la fuerza.
func _conversation_effect(sim: Simulation, conversation_id: String, actor: String, outcome: Dictionary) -> String:
	var flags: Array = []
	var rastro: int = 0
	if outcome["door"] != "":
		var effects: Dictionary = data.conversation_elements[outcome["door"]]["effects"]
		rastro = effects["rastro"]
		for flag: String in effects["set"]:
			if not sim.s["flags"].has(flag):
				flags.append(flag)
	var trust: Variant = data.conversations[conversation_id]["trust"]
	if trust != null and trust["actor"] == actor and outcome["confianza"] >= trust["min"]:
		for flag: String in trust["set"]:
			if not sim.s["flags"].has(flag) and not flags.has(flag):
				flags.append(flag)
	if flags.is_empty() and not outcome["forced"] and rastro == 0:
		return ""
	flags.sort()
	return "%s|%s|%d" % [",".join(flags), outcome["forced"], rastro]


## Horizonte de cada bandera: la condición que la lee más tarde. Un tramo de
## rutina normal deja de poder elegirse cuando empieza el siguiente tramo sin
## condición; un evento con hora solo se evalúa a esa hora; una interacción, en
## su ventana; un tema u observación con "time_to", antes de esa hora.
func _compute_horizons() -> Dictionary:
	var result: Dictionary = {}
	var end := data.day_end
	for person: String in data.person_ids:
		var routine: Array = data.people[person]["routine"]
		for segment: Dictionary in routine:
			var live := end
			if not segment["override"]:
				for other: Dictionary in routine:
					if not other["override"] and other["if"] == null and other["from"] > segment["from"]:
						live = mini(live, other["from"] - data.step_minutes)
			_note(result, segment["if"], live)
		_note(result, data.people[person]["disabled_if"], end)
		for variant: Dictionary in data.people[person]["observe"]:
			_note(result, variant["if"], _live_until(variant["if"], end))
	for location: String in data.location_ids:
		for variant: Dictionary in data.locations[location]["observe"]:
			_note(result, variant["if"], _live_until(variant["if"], end))
	for id: String in data.talks:
		_note(result, data.talks[id]["if"], _live_until(data.talks[id]["if"], end))
	for id: String in data.interactions:
		var interaction: Dictionary = data.interactions[id]
		var live: int = interaction["times"].max() if not interaction["times"].is_empty() else interaction["to"] - data.step_minutes
		_note(result, interaction["if"], live)
	for event: Dictionary in data.events:
		var live: int = event["time"] if event["time"] >= 0 else end
		_note(result, event["if"], live)
		for variant: Dictionary in event["variants"]:
			_note(result, variant["if"], live)
	for ending: Dictionary in data.endings:
		_note(result, ending["if"], end)
	for id: String in data.conversation_elements:
		var element: Dictionary = data.conversation_elements[id]
		if element["kind"] == "door":
			_note(result, element["if"], _live_until(element["if"], end))
	for id: String in data.conversations:
		for line: Dictionary in data.conversations[id]["silence"]:
			_note(result, line["if"], end)
	for id: String in data.npc_ids():
		var velo3: Variant = data.people[id]["velo3"]
		if velo3 != null:
			_note(result, velo3["saved_if"], end)
	return result


## Si la condición exige "time_to" en su nivel superior, deja de cumplirse a esa hora.
func _live_until(condition: Variant, fallback: int) -> int:
	var items: Array = []
	if condition is Dictionary and condition.has("ALL"):
		items = condition["ALL"]
	elif condition != null:
		items = [condition]
	for item: Variant in items:
		if item is Dictionary and item.has("time_to"):
			return GameData.parse_time(item["time_to"]) - data.step_minutes
	return fallback


func _note(result: Dictionary, condition: Variant, live: int) -> void:
	if condition == null:
		return
	if condition is String:
		result[condition] = maxi(result.get(condition, -1), live)
	elif condition is Array:
		for item: Variant in condition:
			_note(result, item, live)
	elif condition is Dictionary:
		var key: String = condition.keys()[0]
		var value: Variant = condition[key]
		match key:
			"ALL", "ANY", "NOT":
				_note(result, value, live)
			"flag_earlier":
				result[value] = maxi(result.get(value, -1), live)
			"was_at":
				var trail_key := "trail:%s@%s@%d" % [value["who"], value["place"], GameData.parse_time(value["time"])]
				result[trail_key] = maxi(result.get(trail_key, -1), live)


func _schedule_clue_in_window(clue: Dictionary) -> bool:
	for segment: Dictionary in data.relevant_schedule(clue["person"]):
		if "horario_" + segment["id"] == clue["id"]:
			return true
	return false


## Pistas y banderas que nombra una condición.
func _referenced(condition: Variant) -> PackedStringArray:
	var names: PackedStringArray = []
	if condition == null:
		return names
	if condition is String:
		names.append("[" + condition + "]")
	elif condition is Array:
		for item: Variant in condition:
			names.append_array(_referenced(item))
	elif condition is Dictionary:
		var key: String = condition.keys()[0]
		if key in ["ALL", "ANY", "NOT"]:
			names.append_array(_referenced(condition[key]))
		elif key == "clue":
			names.append(condition[key])
		elif key == "flag_earlier":
			names.append("[" + condition[key] + "]")
	return names


func _node(name: String, result: Dictionary) -> String:
	var id := name.replace("[", "flag_").replace("]", "").replace(":", "_")
	var label := name
	if result["clues"].has(name):
		label = "%s (%d)" % [name, result["clues"][name]]
	elif name.begins_with("FINAL:") and result["endings"].has(name.substr(6)):
		label = "%s (%d)" % [name, result["endings"][name.substr(6)]]
	if name.begins_with("["):
		return '%s(["%s"])' % [id, label]
	if name.begins_with("FINAL:"):
		return '%s{{"%s"}}' % [id, label]
	return '%s["%s"]' % [id, label]
