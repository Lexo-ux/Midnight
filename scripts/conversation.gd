extends RefCounted
## Conversaciones con cartas (data/cards.json): reglas puras y deterministas.
## La UI las juega carta a carta para enseñarlas; la simulación las vuelve a
## jugar con la lista de cartas de la orden «hablar» (así la ruta grabada las
## repite igual); el validador busca qué puertas se pueden abrir.
##
## Reglas:
## - 4 turnos. Cada carta gasta uno, salvo Silencio. Confianza de 0 a 5.
## - Mano: las 4 primeras cartas del mazo (orden fijo en los datos) más una de
##   Conocimiento por cada pista del Cuaderno marcada `opens_door` para una
##   puerta de esta persona. Tras jugar una carta del mazo se roba la siguiente.
## - Una puerta se abre si sus muros están descubiertos o rotos y se cumple su
##   condición. Abrir una puerta gana la conversación.
## - Escuchar descubre el siguiente muro o puerta. Verdad abre la puerta que
##   nombra o, si no puede, cuesta 1 de Confianza. Silencio da otra frase.
##   Presión rompe el siguiente muro y cuesta 1 de Confianza (2 si la persona
##   es frágil). Revelar abre, convence o aterra según la persona.
##   Conocimiento abre su puerta aunque haya muros.
## - Confianza 0: la persona se cierra hasta el próximo bucle. Sin turnos ni
##   cartas: «otro rato» (neutral).
## - Lo ya apuntado en el Cuaderno (muros y puertas) empieza descubierto.
##
## Contexto que necesita: {knows: Callable(pista) -> bool, check: Callable(condición) -> bool,
## confianza: int, frightened: bool, won: Array (puertas ya abiertas en este bucle)}.

const GameData := preload("res://scripts/game_data.gd")
const KNOWLEDGE_PREFIX: String = "conocimiento:"

## Resultados de solve() por firma (lo que de verdad cambia el resultado).
static var _solve_cache: Dictionary = {}


static func start(data: GameData, conversation_id: String, actor: String, context: Dictionary) -> Dictionary:
	var conversation: Dictionary = data.conversations[conversation_id]
	var deck: Array = Array(conversation["decks"][actor])
	var hand: Array = []
	while hand.size() < data.card_rules["hand_size"] and not deck.is_empty():
		hand.append(deck.pop_front())
	var revealed: Dictionary = {}
	var knows: Callable = context["knows"]
	for element: Dictionary in conversation["elements"]:
		if knows.call(element["clue"]):
			revealed[element["id"]] = true
		if element["kind"] == "door":
			for clue: String in data.door_sources.get(element["id"], []):
				if knows.call(clue):
					hand.append("%s%s:%s" % [KNOWLEDGE_PREFIX, clue, element["id"]])
	var opening: String = conversation["fear"] if context["frightened"] else conversation["opening"][actor]
	return {
		"conversation": conversation_id, "person": conversation["person"], "actor": actor, "context": context,
		"confianza": clampi(context["confianza"], 0, data.card_rules["confianza_max"]),
		"turns": data.card_rules["turns"], "deck": deck, "hand": hand, "revealed": revealed, "broken": {},
		"silence": 0, "played": [], "lines": [opening], "clues": [],
		"result": "", "door": "", "forced": false, "used_force": false,
	}


## Tipo de una carta (de la mano o del mazo).
static func card_type(data: GameData, card: String) -> String:
	if card.begins_with(KNOWLEDGE_PREFIX):
		return "conocimiento"
	return data.cards[card]["type"]


## Puerta que abre una carta de Conocimiento ("" si no lo es).
static func knowledge_door(card: String) -> String:
	return card.get_slice(":", 2) if card.begins_with(KNOWLEDGE_PREFIX) else ""


## Pista del Cuaderno de una carta de Conocimiento.
static func knowledge_clue(card: String) -> String:
	return card.get_slice(":", 1) if card.begins_with(KNOWLEDGE_PREFIX) else ""


## Juega `card` de la mano. Devuelve false si no está en la mano o ya terminó.
static func play(data: GameData, conv: Dictionary, card: String) -> bool:
	if conv["result"] != "" or not conv["hand"].has(card):
		return false
	var conversation: Dictionary = data.conversations[conv["conversation"]]
	var type := card_type(data, card)
	conv["hand"].erase(card)
	conv["played"].append(card)
	if type != "silencio":
		conv["turns"] -= 1
	match type:
		"escuchar":
			_reveal_next(conv, conversation)
		"verdad":
			var door: String = data.cards[card]["door"]
			if door != "" and _can_open(data, conv, door, true):
				_open(data, conv, door)
			else:
				_hurt(data, conv, 1, conversation["wrong"])
		"silencio":
			_speak(conv, conversation)
		"presion":
			conv["used_force"] = true
			for element: Dictionary in conversation["elements"]:
				if element["kind"] == "wall" and not conv["broken"].has(element["id"]):
					conv["broken"][element["id"]] = true
					_discover(conv, element)
					break
			_hurt(data, conv, 2 if data.people[conv["person"]]["fragile"] else 1, conversation["presion"])
		"revelar":
			conv["used_force"] = true
			var revelar: Dictionary = conversation["revelar"]
			match revelar["effect"]:
				"open":
					if _can_open(data, conv, revelar["door"], true):
						conv["lines"].append(revelar["text"])
						_open(data, conv, revelar["door"])
					else:
						_hurt(data, conv, 1, conversation["wrong"])
				"confianza":
					conv["confianza"] = mini(conv["confianza"] + revelar["amount"], data.card_rules["confianza_max"])
					conv["lines"].append(revelar["text"])
				_:
					_hurt(data, conv, -revelar["amount"], revelar["text"])
		"conocimiento":
			var door := knowledge_door(card)
			if _can_open(data, conv, door, false):
				_open(data, conv, door)
			else:
				_hurt(data, conv, 1, conversation["wrong"])
	if type != "conocimiento" and not conv["deck"].is_empty():
		conv["hand"].append(conv["deck"].pop_front())
	if conv["result"] == "":
		if conv["confianza"] <= 0:
			conv["result"] = "closed"
			conv["lines"].append(conversation["closed"])
		elif conv["turns"] <= 0 or conv["hand"].is_empty():
			_end_neutral(conv, conversation)
	return true


## Terminar a mitad: «otro rato».
static func finish(data: GameData, conv: Dictionary) -> void:
	if conv["result"] == "":
		_end_neutral(conv, data.conversations[conv["conversation"]])


## Juega una lista de cartas desde el principio y termina. {} si alguna carta no vale.
static func replay(data: GameData, conversation_id: String, actor: String, context: Dictionary, played: Array) -> Dictionary:
	if played.is_empty():
		return {}
	var conv := start(data, conversation_id, actor, context)
	for card: Variant in played:
		if not card is String or not play(data, conv, card):
			return {}
	finish(data, conv)
	return conv


## La conversación que solo escucha: Silencios y Escuchar hasta agotar la mano
## o los turnos. Nunca abre ni cierra nada; descubre todo lo que se pueda.
## Devuelve {cards, clues, confianza}.
static func listen(data: GameData, conversation_id: String, actor: String, context: Dictionary) -> Dictionary:
	var key := "listen|" + _signature(data, conversation_id, actor, context)
	if _solve_cache.has(key):
		return _solve_cache[key]
	var conv := start(data, conversation_id, actor, context)
	var progressed := true
	while conv["result"] == "" and progressed:
		progressed = false
		for wanted: String in ["silencio", "escuchar"]:
			for card: String in conv["hand"]:
				if card_type(data, card) == wanted:
					play(data, conv, card)
					progressed = true
					break
			if progressed:
				break
	var result: Dictionary = {"cards": conv["played"], "clues": conv["clues"], "confianza": conv["confianza"]}
	_solve_cache[key] = result
	return result


## Todas las formas distintas de ganar ahora: [{door, cards, forced}], la más
## corta para cada puerta y cada manera (a la fuerza o no). Determinista.
static func solve(data: GameData, conversation_id: String, actor: String, context: Dictionary) -> Array:
	var key := _signature(data, conversation_id, actor, context)
	if _solve_cache.has(key):
		return _solve_cache[key]
	var found: Dictionary = {}
	var frontier: Array = [start(data, conversation_id, actor, context)]
	var seen: Dictionary = {}
	while not frontier.is_empty():
		var next: Array = []
		for conv: Dictionary in frontier:
			var tried: Dictionary = {}
			for card: String in conv["hand"]:
				if tried.has(card):
					continue
				tried[card] = true
				var child: Dictionary = conv.duplicate(true)
				play(data, child, card)
				if child["result"] == "win":
					var outcome := "%s|%s" % [child["door"], child["forced"]]
					if not found.has(outcome):
						found[outcome] = {"door": child["door"], "cards": child["played"].duplicate(), "forced": child["forced"]}
				elif child["result"] == "":
					var state := "%s|%d|%d|%s|%s|%d" % [child["hand"], child["turns"], child["confianza"], child["revealed"].keys(),
							child["broken"].keys(), child["silence"]]
					if not seen.has(state):
						seen[state] = true
						next.append(child)
		frontier = next
	var results: Array = found.values()
	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return "%s|%s" % [a["door"], a["forced"]] < "%s|%s" % [b["door"], b["forced"]])
	_solve_cache[key] = results
	return results


# --- Interno --------------------------------------------------------------

static func _reveal_next(conv: Dictionary, conversation: Dictionary) -> void:
	for element: Dictionary in conversation["elements"]:
		if not conv["revealed"].has(element["id"]):
			_discover(conv, element)
			conv["lines"].append(element["reveal"])
			return
	conv["lines"].append(conversation["nothing"])


static func _discover(conv: Dictionary, element: Dictionary) -> void:
	conv["revealed"][element["id"]] = true
	if not conv["clues"].has(element["clue"]):
		conv["clues"].append(element["clue"])


static func _speak(conv: Dictionary, conversation: Dictionary) -> void:
	var check: Callable = conv["context"]["check"]
	while conv["silence"] < conversation["silence"].size():
		var line: Dictionary = conversation["silence"][conv["silence"]]
		conv["silence"] += 1
		if check.call(line["if"]):
			conv["lines"].append(line["text"])
			for clue: String in line["clues"]:
				if not conv["clues"].has(clue):
					conv["clues"].append(clue)
			return
	conv["lines"].append(conversation["silence_end"])


## La puerta es de esta persona, no se abrió ya en este bucle, se cumple su
## condición y (si `needs_walls`) sus muros están descubiertos o rotos.
static func _can_open(data: GameData, conv: Dictionary, door: String, needs_walls: bool) -> bool:
	var element: Dictionary = data.conversation_elements.get(door, {})
	if element.is_empty() or element["kind"] != "door" or element["conversation"] != conv["conversation"]:
		return false
	if conv["context"]["won"].has(door) or not (conv["context"]["check"] as Callable).call(element["if"]):
		return false
	if needs_walls:
		for wall: String in element["walls"]:
			if not conv["revealed"].has(wall) and not conv["broken"].has(wall):
				return false
	return true


static func _open(data: GameData, conv: Dictionary, door: String) -> void:
	var element: Dictionary = data.conversation_elements[door]
	_discover(conv, element)
	conv["lines"].append(element["open"])
	conv["result"] = "win"
	conv["door"] = door
	conv["forced"] = conv["actor"] == "akba" and conv["used_force"]


static func _hurt(data: GameData, conv: Dictionary, amount: int, line: String) -> void:
	conv["confianza"] = clampi(conv["confianza"] - amount, 0, data.card_rules["confianza_max"])
	conv["lines"].append(line)


static func _end_neutral(conv: Dictionary, conversation: Dictionary) -> void:
	conv["result"] = "neutral"
	conv["lines"].append(conversation["neutral"])


## Lo único que cambia lo que se puede ganar: conversación, protagonista,
## Confianza, puertas ya abiertas, qué sabe el Cuaderno y qué condiciones se cumplen.
static func _signature(data: GameData, conversation_id: String, actor: String, context: Dictionary) -> String:
	var conversation: Dictionary = data.conversations[conversation_id]
	var knows: Callable = context["knows"]
	var check: Callable = context["check"]
	var bits := PackedStringArray()
	for element: Dictionary in conversation["elements"]:
		bits.append("1" if knows.call(element["clue"]) else "0")
		if element["kind"] == "door":
			bits.append("1" if check.call(element["if"]) else "0")
			for clue: String in data.door_sources.get(element["id"], []):
				bits.append("1" if knows.call(clue) else "0")
	for line: Dictionary in conversation["silence"]:
		bits.append("1" if check.call(line["if"]) else "0")
	return "%s|%s|%d|%s|%s" % [conversation_id, actor, context["confianza"], context["won"], "".join(bits)]
