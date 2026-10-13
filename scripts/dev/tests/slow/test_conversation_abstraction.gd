extends "res://scripts/dev/tests/test_suite.gd"
## PRUEBA LENTA (solo con `run_tests.gd -- --slow`): el validador de bucles no
## busca secuencias de cartas; usa los resultados de Conversation.solve(). Aquí
## se comprueba que esa abstracción es fiel: para cada conversación, cada
## protagonista y una muestra de situaciones previas (qué sabe el Cuaderno, qué
## condiciones se cumplen, Confianza, puertas ya abiertas, miedo), el conjunto
## de resultados ganadores (puerta, a la fuerza o no, Confianza final) de
## solve() es el mismo que el de probar TODAS las secuencias de cartas.

const Conversation := preload("res://scripts/conversation.gd")
const SAMPLES_PER_CASE: int = 40
const SEED: int = 404


func test_solve_matches_brute_force_on_sampled_pre_states() -> bool:
	var data := new_state().data
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var compared: int = 0
	for conversation_id: String in data.conversations:
		var conversation: Dictionary = data.conversations[conversation_id]
		var clues: Array[String] = []
		var conditions: Array = []
		var doors: Array[String] = []
		for element: Dictionary in conversation["elements"]:
			clues.append(element["clue"])
			if element["kind"] == "door":
				doors.append(element["id"])
				conditions.append(element["if"])
				for clue: String in data.door_sources.get(element["id"], []):
					clues.append(clue)
		for line: Dictionary in conversation["silence"]:
			conditions.append(line["if"])
		for actor: String in data.protagonist_ids:
			for sample: int in SAMPLES_PER_CASE + 2:
				var context := _context(rng, sample, clues, conditions, doors)
				var expected := Conversation.brute_force_outcomes(data, conversation_id, actor, context)
				var got: Dictionary = {}
				for outcome: Dictionary in Conversation.solve(data, conversation_id, actor, context):
					got[Conversation.outcome_key(outcome)] = true
				var a: Array = expected.keys()
				var b: Array = got.keys()
				a.sort()
				b.sort()
				check(a == b, "%s con %s (muestra %d): solve() da %s y todas las secuencias dan %s" % [
						conversation_id, actor, sample, b, a])
				compared += 1
	print("        %d situaciones comparadas" % compared)
	return true


## Muestra 0: no sabe nada y todo se cumple; muestra 1: lo sabe todo y todo se
## cumple; el resto, al azar (semilla fija).
func _context(rng: RandomNumberGenerator, sample: int, clues: Array[String], conditions: Array,
		doors: Array[String]) -> Dictionary:
	var known: Dictionary = {}
	var holds: Dictionary = {}
	for clue: String in clues:
		known[clue] = sample == 1 or (sample > 1 and rng.randf() < 0.5)
	for condition: Variant in conditions:
		holds[str(condition)] = sample <= 1 or rng.randf() < 0.7
	var won: Array = []
	if sample > 1:
		for door: String in doors:
			if rng.randf() < 0.2:
				won.append(door)
	return {
		"knows": func(clue: String) -> bool: return known.get(clue, false),
		"check": func(condition: Variant) -> bool: return condition == null or holds.get(str(condition), true),
		"confianza": 3 if sample <= 1 else rng.randi_range(1, 5),
		"frightened": sample > 1 and rng.randf() < 0.3,
		"won": won,
	}
