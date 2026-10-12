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

const GameData := preload("res://scripts/game_data.gd")
const Simulation := preload("res://scripts/simulation.gd")

const MAX_PASSES: int = 8

var data: GameData
## Bandera (o "trail:...") -> último minuto en que alguna condición puede leerla.
var horizons: Dictionary = {}


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
	var clues: Dictionary = {}
	var endings: Dictionary = {}
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
			elif not clues.has(key):
				clues[key] = pass_number
				cuaderno[key] = {"loop": pass_number, "by": data.start_active, "time": data.loop_start}
				changes_next_loop = changes_next_loop or data.referenced_clues.has(key)
		if not changes_next_loop:
			break
	return {"clues": clues, "endings": endings, "passes": passes, "states": total_states}


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
	return {"problems": problems, "result": result}


## Grafo de pistas en Mermaid: qué pistas habilitan qué, y qué lleva a cada final.
func clue_graph_markdown(result: Dictionary) -> String:
	var lines: PackedStringArray = [
		"# Grafo de pistas de Medianoche en Much",
		"",
		"Generado por `scripts/dev/validate_loops.gd`. Una flecha A --> B significa que una",
		"acción o evento que exige A puede dar B. Las banderas van entre corchetes; el número",
		"tras cada pista es la primera pasada (bucle) en que el validador la alcanzó.",
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
			if not sim.is_pure_action(action):
				commands.append({"actor": actor, "command": action})
				continue
			for id: String in sim.preview_clues(actor, action):
				sim.found[id] = true
			if not waited.has(action["place"]):
				waited[action["place"]] = true
				commands.append({"actor": actor, "command": {"verb": "esperar", "place": action["place"], "target": "", "id": ""}})
	sim.s["active"] = state["active"]
	return commands


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
