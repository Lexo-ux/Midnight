extends "res://scripts/dev/tests/test_suite.gd"
## Partidas aleatorias (con semilla, reproducibles) con cambios de protagonista,
## herramientas, conversaciones con cartas al azar, decisiones de quiebre al
## azar y cambios de ajustes. En cada paso comprueba que el jugador siempre
## tenga algo que hacer, que cada bucle termine en un número acotado de pasos y
## que el Velo y la Confianza no se salgan de su rango. Además, de vez en cuando
## mira alrededor, abre el mapa y mira otro lugar desde él, o cambia un ajuste:
## nada de eso puede cambiar la partida.
## Imprime la semilla de cualquier fallo: para reproducirlo, pon RUNS = 1 y
## BASE_SEED = esa semilla.

const RUNS: int = 300
const BASE_SEED: int = 20261012
const MAX_STEPS_PER_LOOP: int = 200
const MAX_LOOPS_PER_RUN: int = 3
const SWITCH_CHANCE: float = 0.25
const TOOL_CHANCE: float = 0.06
const VIEW_CHANCE: float = 0.12
const SETTINGS_CHANCE: float = 0.05


func test_random_runs_never_softlock() -> bool:
	var state := new_state()
	var view := new_place_view(state)
	var map := new_map_view(state)
	var stats: Dictionary = {"loops": 0, "steps": 0, "skips": 0, "replays": 0, "looks": 0, "endings": {},
			"conversations": 0, "cards": 0, "breakpoints": 0, "settings": 0}
	for run: int in RUNS:
		var seed_value: int = BASE_SEED + run
		var problem := _play_random_run(state, view, map, seed_value, stats)
		check(problem == "", "semilla %d: %s" % [seed_value, problem])
	print("        %d partidas, %d bucles, %d pasos, %d saltos, %d repeticiones, %d vistazos, finales %s" % [RUNS,
			stats["loops"], stats["steps"], stats["skips"], stats["replays"], stats["looks"], stats["endings"]])
	print("        %d conversaciones (%d cartas), %d quiebres decididos, %d cambios de ajustes" % [stats["conversations"],
			stats["cards"], stats["breakpoints"], stats["settings"]])
	check(stats["conversations"] > 0 and stats["breakpoints"] > 0, "el fuzz juega conversaciones y quiebres")
	return true


func _play_random_run(state: GameStateScript, view: Control, map: Control, seed_value: int, stats: Dictionary) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	state.new_game()
	for loop_index: int in rng.randi_range(1, MAX_LOOPS_PER_RUN):
		if state.can_replay() and rng.randf() < 0.5:
			var targets := state.replay_targets()
			if not state.replay_route(targets[rng.randi_range(0, targets.size() - 1)]):
				return "«Repetir mi ruta» falló en el bucle %d" % state.loop_number
			stats["replays"] += 1
		var steps := 0
		while not state.is_loop_over():
			steps += 1
			if steps > MAX_STEPS_PER_LOOP:
				return "el bucle %d no termina en %d pasos" % [state.loop_number, MAX_STEPS_PER_LOOP]
			var problem := _softlock_problem(state)
			if problem != "":
				return "bucle %d, %s: %s" % [state.loop_number, GameData.format_time(state.current_time()), problem]
			if rng.randf() < VIEW_CHANCE:
				problem = _look_around(state, view, map, rng)
				stats["looks"] += 1
				if problem != "":
					return "bucle %d, %s: %s" % [state.loop_number, GameData.format_time(state.current_time()), problem]
			if rng.randf() < SETTINGS_CHANCE:
				problem = _change_a_setting(state, rng)
				stats["settings"] += 1
				if problem != "":
					return "bucle %d, %s: %s" % [state.loop_number, GameData.format_time(state.current_time()), problem]
			_random_action(state, rng, stats)
			problem = _range_problem(state)
			if problem != "":
				return "bucle %d, %s: %s" % [state.loop_number, GameData.format_time(state.current_time()), problem]
		stats["loops"] += 1
		stats["steps"] += steps
		stats["endings"][state.ending_id()] = stats["endings"].get(state.ending_id(), 0) + 1
		if not state.start_next_loop():
			return "no se pudo empezar otro bucle tras el %d" % state.loop_number
	return ""


## Mira la escena, arrastra, abre el mapa y mira otro lugar. "" si la partida no cambió.
func _look_around(state: GameStateScript, view: Control, map: Control, rng: RandomNumberGenerator) -> String:
	var before := snapshot_text(state)
	var places := state.data.visible_location_ids()
	view.refresh(state.position_of(state.active_actor()), false, "")
	for i: int in rng.randi_range(1, 4):
		view.pan_by(rng.randf_range(-2500.0, 2500.0))
	map.open()
	map.hide()
	view.refresh(places[rng.randi_range(0, places.size() - 1)], true, "")
	view.pan_by(rng.randf_range(-2500.0, 2500.0))
	if snapshot_text(state) != before:
		return "mirar alrededor o abrir el mapa cambió la partida"
	if view.place != "" and view.look != state.active_actor():
		return "la mirada no es la del protagonista activo"
	return ""


## "" si el jugador puede hacer algo; si no, qué falla.
func _softlock_problem(state: GameStateScript) -> String:
	if state.current_time() < state.data.loop_start or state.current_time() >= state.data.day_end:
		return "hora fuera de la ventana"
	if not state.can_switch():
		return "no se puede cambiar de protagonista con el bucle en curso"
	for actor: String in state.data.protagonist_ids:
		if not state.sim.actions_for(actor).is_empty():
			return ""
	return "ningún protagonista tiene acciones"


func _random_action(state: GameStateScript, rng: RandomNumberGenerator, stats: Dictionary) -> void:
	var roll := rng.randf()
	if roll < SWITCH_CHANCE:
		state.switch_to(state.data.protagonist_ids[rng.randi_range(0, 1)])
		return
	if roll < SWITCH_CHANCE + TOOL_CHANCE:
		var targets := state.skip_targets()
		state.skip_to(targets[rng.randi_range(0, targets.size() - 1)])
		stats["skips"] += 1
		return
	var command := random_command(state, rng)
	if command.is_empty():
		# Akba atrapado: lo que queda es cambiar a Sazil.
		for actor: String in state.data.protagonist_ids:
			if not state.sim.actions_for(actor).is_empty():
				state.switch_to(actor)
				return
		return
	if command.has("cards"):
		if command["cards"].is_empty():
			return
		stats["conversations"] += 1
		stats["cards"] += command["cards"].size()
	if command.has("decision"):
		stats["breakpoints"] += 1
	state.perform(command)
	if rng.randf() < 0.5:
		state.dismiss_outcome()


## Un ajuste al azar (sonido, vibración, quiebres, texto): nunca toca el mundo.
func _change_a_setting(state: GameStateScript, rng: RandomNumberGenerator) -> String:
	var before := world_text(state)
	match rng.randi_range(0, 5):
		0:
			state.set_volume(SaveManager.VOLUME_KEYS[rng.randi_range(0, 3)], rng.randf())
		1:
			state.set_haptics(SaveManager.HAPTIC_LEVELS[rng.randi_range(0, 2)])
		2:
			state.set_breakpoint_mode(SaveManager.BREAKPOINT_MODES[rng.randi_range(0, 1)])
		3:
			state.set_breakpoint_time(SaveManager.BREAKPOINT_TIMES[rng.randi_range(0, 2)])
		4:
			state.set_mute(rng.randf() < 0.5)
		_:
			state.set_text_size(rng.randi_range(0, state.data.text_sizes.size() - 1))
	return "" if world_text(state) == before else "cambiar un ajuste cambió la partida"


## El Velo visible va de 0 a 3 y la Confianza de cada conversación de 0 al máximo.
func _range_problem(state: GameStateScript) -> String:
	for person: String in state.data.npc_ids():
		var level := state.velo_level(person)
		if level < 0 or level > 3:
			return "Velo de %s fuera de rango (%d)" % [person, level]
	for person: String in state.sim.s["conversations"]:
		var confianza: int = state.sim.s["conversations"][person]["confianza"]
		if confianza < 0 or confianza > state.data.card_rules["confianza_max"]:
			return "Confianza de %s fuera de rango (%d)" % [person, confianza]
	return ""
