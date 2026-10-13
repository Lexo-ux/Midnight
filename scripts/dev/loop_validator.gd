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
## Conversaciones con cartas: cada una se explora como «solo escuchar» (no abre
## ni cierra nada, descubre lo que pueda) y como cada forma de ganar que
## encuentre Conversation.solve() con las cartas y el Cuaderno de ese momento.
## Los quiebres: «sostuvo» es la interacción; «soltó» deja el mismo estado que
## esperar allí, que ya se explora.

const GameData := preload("res://scripts/game_data.gd")
const Simulation := preload("res://scripts/simulation.gd")
const Conversation := preload("res://scripts/conversation.gd")

const MAX_PASSES: int = 8

var data: GameData
## Bandera (o "trail:...") -> último minuto en que alguna condición puede leerla.
var horizons: Dictionary = {}
## "lugar|protagonista|minuto|pista" -> true: observar el lugar dio esa pista.
var observed: Dictionary = {}


func _init(game_data: GameData) -> void:
	data = game_data
	horizons = _compute_horizons()


## Un bucle completo desde `cuaderno`. `banned` son ids de temas, interacciones
## o cartas (o "verbo:carta", p. ej. "retener:orden_lina") que no se pueden usar.
## Devuelve {found: {pista|ending:id: true}, states: int}.
func explore_loop(cuaderno: Dictionary, banned: Dictionary = {}) -> Dictionary:
	var sim := Simulation.new(data)
	sim.exploring = true
	sim.cuaderno = cuaderno
	sim.key_horizons = horizons
	sim.begin_loop()
	var frontier: Array[Dictionary] = [sim.clone_state()]
	var seen: Dictionary = {sim.exploration_key(): true}
	var states: int = 1
	while not frontier.is_empty():
		var next_frontier: Array[Dictionary] = []
		for state: Dictionary in frontier:
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
	return {"found": sim.found, "states": states}


## Pasadas sucesivas hasta que no se descubre nada más.
## Devuelve {clues: {id: pasada}, endings: {id: pasada}, passes, states}.
func explore_all(banned: Dictionary = {}, start_cuaderno: Dictionary = {}) -> Dictionary:
	var cuaderno: Dictionary = start_cuaderno.duplicate()
	observed.clear()
	var clues: Dictionary = {}
	var endings: Dictionary = {}
	var doors: Dictionary = {}
	var total_states: int = 0
	var passes: int = 0
	for pass_number: int in range(1, MAX_PASSES + 1):
		passes = pass_number
		var result := explore_loop(cuaderno, banned)
		total_states += result["states"]
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
	return {"clues": clues, "endings": endings, "doors": doors, "passes": passes, "states": total_states}


## Comprueba todo y devuelve {problems, result}. Con `start_cuaderno` se parte de
## ese Cuaderno (los tests usan uno completo para comprobar solo lo que impone la hora).
func validate(start_cuaderno: Dictionary = {}) -> Dictionary:
	var problems: PackedStringArray = []
	var result := explore_all({}, start_cuaderno)
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


## Una conversación como órdenes: solo escuchar y cada forma de ganar que no
## esté prohibida. Solo escuchar es una acción pura (pistas y nada más) salvo
## que deje una bandera de confianza nueva; entonces se simula.
func _conversation_commands(sim: Simulation, actor: String, action: Dictionary, banned: Dictionary,
		waited: Dictionary) -> Array[Dictionary]:
	var commands: Array[Dictionary] = []
	var context := sim.conversation_context(actor, action["target"])
	var listening := Conversation.listen(data, action["id"], actor, context)
	if not listening["cards"].is_empty():
		if _sets_new_trust(sim, action["id"], actor, listening["confianza"]):
			var command: Dictionary = action.duplicate()
			command["cards"] = listening["cards"]
			commands.append({"actor": actor, "command": command})
		else:
			for clue: String in listening["clues"]:
				sim.found[clue] = true
			if not waited.has(action["place"]):
				waited[action["place"]] = true
				commands.append({"actor": actor, "command": {"verb": "esperar", "place": action["place"], "target": "", "id": ""}})
	for outcome: Dictionary in Conversation.solve(data, action["id"], actor, context):
		if banned.has("door:" + outcome["door"]):
			continue
		var command: Dictionary = action.duplicate()
		command["cards"] = outcome["cards"]
		commands.append({"actor": actor, "command": command})
	return commands


func _sets_new_trust(sim: Simulation, conversation_id: String, actor: String, confianza: int) -> bool:
	var trust: Variant = data.conversations[conversation_id]["trust"]
	if trust == null or trust["actor"] != actor or confianza < trust["min"]:
		return false
	for flag: String in trust["set"]:
		if not sim.s["flags"].has(flag):
			return true
	return false


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
