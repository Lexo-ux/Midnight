extends Node
## Estado único de la partida (autoload `GameState`). La UI solo lee de aquí,
## llama a sus acciones y reacciona a sus señales; nunca guarda estado de juego.
##
## Dos niveles de estado:
## - Del bucle (se reinicia a medianoche): todo lo de `sim.s` (hora, a quién
##   controlas, posiciones, banderas, cartas, Rastro, Desgaste, ruta grabada y
##   la estación de cada protagonista en cada lugar).
## - Permanente: el Cuaderno del Umbral, el Velo de cada persona (y las marcas
##   de Akba), los finales vistos, las pistas pedidas, los ajustes y la ruta
##   del bucle anterior.

## Cualquier cambio: la UI se redibuja.
signal changed
## Cambio de protagonista (para el barrido de luz).
signal switched(actor: String)
signal settings_changed

const GameData := preload("res://scripts/game_data.gd")
const Simulation := preload("res://scripts/simulation.gd")
const SaveManager := preload("res://scripts/save_manager.gd")
const SceneRules := preload("res://scripts/scene_rules.gd")
const Conversation := preload("res://scripts/conversation.gd")

const DEFAULT_SAVE_PATH: String = "user://savegame.json"

var data: GameData = GameData.new()
var sim: Simulation
var save_path: String = DEFAULT_SAVE_PATH
var autosave_enabled: bool = true
var load_save_on_ready: bool = true

var loop_number: int = 1
## id de pista -> {loop, by, time}. Compartido con la simulación.
var cuaderno: Dictionary = {}
## id de persona -> nivel de Velo ganado (0 silueta, 1 rasgos, 2 rostro, 3 retrato).
var velo: Dictionary = {}
## id de persona -> {count, loop}: veces que Akba la forzó. Cada marca baja un
## nivel de Velo para siempre; en el bucle siguiente recibe con miedo.
var marks: Dictionary = {}
## id de final -> bucle en que se vio por primera vez.
var endings_seen: Dictionary = {}
## id de pregunta -> cuántos niveles de pista se han pedido (0-3).
var hints: Dictionary = {}
var settings: Dictionary = SaveManager.DEFAULT_SETTINGS.duplicate()
## Acciones del bucle anterior, para «Repetir mi ruta».
var last_route: Array = []


func _ready() -> void:
	if not data.load_all():
		return
	sim = Simulation.new(data)
	sim.cuaderno = cuaderno
	sim.velo = velo
	sim.marks = marks
	if load_save_on_ready:
		var snapshot := SaveManager.read(save_path, data)
		if not snapshot.is_empty():
			import_snapshot(snapshot)
			return
	new_game()


# --- Acciones de partida --------------------------------------------------

func new_game() -> void:
	loop_number = 1
	cuaderno.clear()
	velo.clear()
	marks.clear()
	endings_seen.clear()
	hints.clear()
	last_route = []
	for id: String in data.npc_ids():
		velo[id] = 0
	sim.loop_number = loop_number
	sim.begin_loop()
	changed.emit()


## Borra la partida guardada y empieza de cero. Los ajustes se conservan.
func restart_game() -> void:
	SaveManager.delete(save_path)
	new_game()
	_autosave()


## Medianoche pasada: otro bucle. Se pierde lo del bucle; el Cuaderno se queda.
func start_next_loop() -> bool:
	if not is_loop_over():
		push_error("GameState.start_next_loop: todavía no es medianoche.")
		return false
	last_route = sim.s["route"].duplicate(true)
	loop_number += 1
	sim.loop_number = loop_number
	sim.begin_loop()
	_after_change()
	return true


# --- Acciones del bucle ---------------------------------------------------

func switch_to(actor: String) -> bool:
	if not can_switch():
		return false
	var previous := active_actor()
	if not sim.switch_to(actor):
		return false
	if actor != previous:
		switched.emit(actor)
		_after_change()
	return true


func can_switch() -> bool:
	return sim != null and not is_loop_over()


## Hace una acción de get_actions() con el protagonista activo (30 minutos).
func perform(command: Dictionary) -> bool:
	if not sim.step(command):
		return false
	_after_change()
	return true


## Toca un punto interactivo: es «observar» el lugar desde su estación (30 minutos).
func perform_hotspot(hotspot_id: String) -> bool:
	if not hotspot_available(hotspot_id):
		return false
	return perform(SceneRules.hotspot_command(data.hotspots[hotspot_id]))


## Cierra el diálogo del último paso. No cuesta tiempo.
func dismiss_outcome() -> void:
	if not outcome_lines().is_empty() or not outcome_clues().is_empty():
		sim.s["outcome"] = {"lines": [], "clues": []}
		_after_change()


## «Saltar a la hora»: los dos siguen su rutina hasta `minute` (o medianoche).
func skip_to(minute: int) -> bool:
	if is_loop_over() or minute <= current_time() or minute > data.day_end:
		return false
	while current_time() < minute and not is_loop_over():
		sim.step({"verb": Simulation.ROUTINE_VERB})
	sim.s["outcome"] = {"lines": [], "clues": []}
	_after_change()
	return true


## «Repetir mi ruta» solo al empezar un bucle y si hay ruta del anterior.
func can_replay() -> bool:
	return not last_route.is_empty() and current_time() == data.loop_start and sim.s["route"].is_empty() and not is_loop_over()


## Repite las acciones del bucle anterior anteriores a `minute`. La simulación
## es determinista, así que reproduce el mismo bucle, salvo en lo que cambie lo
## aprendido: en una conversación, el Cuaderno puede descubrir muros o dar
## cartas de Conocimiento, y entonces se juegan las cartas grabadas mientras
## valgan (ver _replayable()).
func replay_route(minute: int) -> bool:
	if not can_replay() or minute <= data.loop_start:
		return false
	for entry: Dictionary in last_route:
		if entry["t"] >= minute or is_loop_over():
			break
		var ok: bool = sim.switch_to(entry["switch"]) if entry.has("switch") else sim.step(_replayable(entry["command"]))
		if not ok:
			push_warning("GameState.replay_route: la ruta se separó en %s." % GameData.format_time(entry["t"]))
			break
	sim.s["outcome"] = {"lines": [], "clues": []}
	_after_change()
	return true


## Una orden grabada, lista para repetirla ahora. Una conversación juega sus
## cartas mientras valgan (hasta que termine o una ya no esté en la mano); si no
## vale ninguna, se queda en esperar allí: mismo tiempo y mismo lugar.
func _replayable(command: Dictionary) -> Dictionary:
	if command.get("verb", "") != "hablar" or not data.conversations.has(command.get("id", "")):
		return command
	var actor := active_actor()
	var conv := Conversation.start(data, command["id"], actor, sim.conversation_context(actor, command["target"]))
	for card: Variant in command.get("cards", []):
		if conv["result"] != "" or not card is String or not Conversation.play(data, conv, card):
			break
	if conv["played"].is_empty():
		return {"verb": "esperar", "place": command["place"], "target": "", "id": ""}
	var replay: Dictionary = command.duplicate()
	replay["cards"] = conv["played"].duplicate()
	return replay


## Pide el siguiente nivel de pista de una pregunta. No toca la simulación.
func reveal_hint(question_id: String) -> int:
	var level: int = mini(hints.get(question_id, 0) + 1, 3)
	hints[question_id] = level
	_after_change()
	return level


func set_reduced_motion(enabled: bool) -> void:
	_set_setting("reduced_motion", enabled)


func set_text_size(index: int) -> void:
	_set_setting("text_size", clampi(index, 0, data.text_sizes.size() - 1))


## `key`: uno de SaveManager.VOLUME_KEYS. `value` de 0 a 1.
func set_volume(key: String, value: float) -> void:
	if SaveManager.VOLUME_KEYS.has(key):
		_set_setting(key, clampf(value, 0.0, 1.0))


func set_mute(muted: bool) -> void:
	_set_setting("mute", muted)


func set_haptics(level: String) -> void:
	if SaveManager.HAPTIC_LEVELS.has(level):
		_set_setting("haptics", level)


## Modo de los quiebres: "hold" (mantener pulsado) o "toggle" (tocar para empezar y para soltar).
func set_breakpoint_mode(mode: String) -> void:
	if SaveManager.BREAKPOINT_MODES.has(mode):
		_set_setting("breakpoint_mode", mode)


## Tiempo de los quiebres: "20", "40" (segundos) o "none" (sin tiempo).
func set_breakpoint_time(time: String) -> void:
	if SaveManager.BREAKPOINT_TIMES.has(time):
		_set_setting("breakpoint_time", time)


func set_breakpoint_chosen(chosen: bool) -> void:
	_set_setting("breakpoint_chosen", chosen)


func set_tips_seen(seen: bool) -> void:
	_set_setting("tips_seen", seen)


## «¿Qué hago?»: pide el siguiente nivel de pista de la primera pregunta
## abierta que aún tenga pistas. Devuelve su id ("" si no queda ninguna).
func next_hint() -> String:
	for item: Dictionary in get_questions():
		if not item["resolved"] and item["hint_level"] < 3:
			reveal_hint(item["question"]["id"])
			return item["question"]["id"]
	return ""


# --- Conversaciones y quiebres --------------------------------------------

## Empieza (solo en la UI, sin tocar la partida) una conversación con `person`
## para el protagonista activo. La partida cambia al confirmarla con commit_conversation().
func start_conversation(person: String) -> Dictionary:
	var actor := active_actor()
	return Conversation.start(data, data.conversation_by_person[person], actor, sim.conversation_context(actor, person))


## Juega una carta en una conversación empezada con start_conversation().
func play_card(conv: Dictionary, card: String) -> bool:
	return Conversation.play(data, conv, card)


## Terminar a mitad («otro rato»), antes de confirmarla.
func finish_conversation(conv: Dictionary) -> void:
	Conversation.finish(data, conv)


## La conversación cuenta como una acción «hablar» (30 minutos) con sus cartas.
## Sin cartas jugadas no hay acción: se abandona gratis.
func commit_conversation(conv: Dictionary) -> bool:
	if conv["played"].is_empty():
		return false
	var person: String = conv["person"]
	return perform({"verb": "hablar", "place": position_of(person), "target": person, "id": conv["conversation"],
			"cards": conv["played"].duplicate()})


## Las acciones de quiebre del protagonista activo ahora ([] si no hay).
func breakpoint_actions() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for action: Dictionary in get_actions():
		if action["verb"] == "interactuar" and data.breakpoint_by_interaction.has(action["id"]):
			found.append(action)
	return found


## El quiebre se decide: "sostuvo" hace la interacción; "soltó" deja que pase lo de siempre.
func resolve_breakpoint(action: Dictionary, decision: String) -> bool:
	var command: Dictionary = action.duplicate()
	command["decision"] = decision
	return perform(command)


# --- Consultas ------------------------------------------------------------

func current_time() -> int:
	return sim.s["time"]


func active_actor() -> String:
	return sim.s["active"]


func is_loop_over() -> bool:
	return sim.is_over()


func ending_id() -> String:
	return sim.s["ending"]


func get_actions() -> Array[Dictionary]:
	return sim.actions_for(active_actor())


func position_of(id: String) -> String:
	return sim.s["positions"].get(id, "")


func people_at(place: String) -> Array[String]:
	return sim.people_at(place)


func is_disabled(actor: String) -> bool:
	return sim.is_disabled(actor)


func is_exhausted(actor: String) -> bool:
	return actor == "akba" and current_time() < sim.s["exhausted_until"]


func rastro() -> int:
	return sim.s["rastro"]


func desgaste() -> int:
	return sim.s["desgaste"]


func letter_state(id: String) -> Dictionary:
	return sim.s["letters"][id]


func outcome_lines() -> Array:
	return sim.s["outcome"]["lines"]


func outcome_clues() -> Array:
	return sim.s["outcome"]["clues"]


func has_clue(id: String) -> bool:
	return cuaderno.has(id)


## Nivel de Velo que se ve: el ganado menos una marca por cada vez que Akba la forzó.
func velo_level(person: String) -> int:
	return maxi(0, velo.get(person, 0) - marks.get(person, {}).get("count", 0))


## Estación de `actor` en `place` ("" si aún no ha hecho nada allí en este bucle).
func station_of(actor: String, place: String) -> String:
	return sim.s["stations"][actor].get(place, "")


## Qué hacen las manos de `actor` (sale de su última acción del bucle).
func hands_state(actor: String) -> String:
	return SceneRules.hands_state(data, sim.s["route"], actor)


## El punto existe con la mirada del protagonista activo, a esta hora, y se puede observar el lugar.
func hotspot_available(hotspot_id: String) -> bool:
	if not data.hotspots.has(hotspot_id) or is_loop_over():
		return false
	var hotspot: Dictionary = data.hotspots[hotspot_id]
	if not SceneRules.hotspot_visible(hotspot, active_actor(), current_time()):
		return false
	return sim.is_available(active_actor(), SceneRules.hotspot_command(hotspot))


## Lo que el punto enlaza ya se sabe: la pista está en el Cuaderno, la carta se
## leyó o el evento ya pasó en este bucle.
func hotspot_discovered(hotspot_id: String) -> bool:
	var hotspot: Dictionary = data.hotspots[hotspot_id]
	match hotspot["link_kind"]:
		"clue":
			return cuaderno.has(hotspot["link_id"])
		"letter":
			return sim.s["letters"][hotspot["link_id"]]["read"]
	return sim.s["events_done"].has(hotspot["link_id"])


## El mapa de Much: [{place, x, y, selectable, label, protagonists, people}].
## Solo los lugares con escena se pueden elegir; los demás van sin nombre
## (sin explorar) salvo que esté allí un protagonista. De los habitantes solo
## se ve dónde están los que tienen la rutina entera en el Cuaderno (Velo 1).
func map_nodes() -> Array[Dictionary]:
	var nodes: Array[Dictionary] = []
	for node: Dictionary in data.map_nodes:
		var place: String = node["place"]
		var protagonists: Array[String] = []
		for actor: String in data.protagonist_ids:
			if position_of(actor) == place:
				protagonists.append(actor)
		var known: Array[String] = []
		for person: String in data.npc_ids():
			if position_of(person) == place and velo_level(person) >= 1:
				known.append(person)
		var selectable := data.has_scene(place)
		nodes.append({"place": place, "x": node["x"], "y": node["y"], "selectable": selectable,
				"label": data.locations[place]["short"] if selectable or not protagonists.is_empty() else "",
				"protagonists": protagonists, "people": known})
	return nodes


## Preguntas abiertas visibles: [{question, resolved, hint_level}].
func get_questions() -> Array[Dictionary]:
	var visible: Array[Dictionary] = []
	for question: Dictionary in data.questions:
		if _check_permanent(question["appears_if"]):
			visible.append({"question": question, "resolved": question["resolved_if"] != null and _check_permanent(question["resolved_if"]),
					"hint_level": hints.get(question["id"], 0)})
	return visible


## Horas a las que se puede saltar desde ahora.
func skip_targets() -> Array[int]:
	var targets: Array[int] = []
	var next_hour: int = (floori(current_time() / 60.0) + 1) * 60
	for minute: int in range(next_hour, data.day_end + 1, 60):
		targets.append(minute)
	return targets


func replay_targets() -> Array[int]:
	var targets: Array[int] = []
	if not can_replay():
		return targets
	var last_t: int = last_route[-1]["t"]
	for minute: int in range(data.loop_start + 60, data.day_end + 1, 60):
		targets.append(minute)
		if minute > last_t:
			break
	return targets


# --- Guardado -------------------------------------------------------------

func export_snapshot() -> Dictionary:
	return {
		"loop_number": loop_number,
		"cuaderno": cuaderno.duplicate(true),
		"velo": velo.duplicate(),
		"marks": marks.duplicate(true),
		"endings_seen": endings_seen.duplicate(),
		"hints": hints.duplicate(),
		"settings": settings.duplicate(),
		"last_route": last_route.duplicate(true),
		"loop": sim.clone_state(),
	}


## `snapshot` debe venir validado por SaveManager.
func import_snapshot(snapshot: Dictionary) -> void:
	loop_number = snapshot["loop_number"]
	cuaderno.clear()
	cuaderno.merge(snapshot["cuaderno"].duplicate(true))
	velo.clear()
	velo.merge(snapshot["velo"])
	marks.clear()
	marks.merge(snapshot["marks"].duplicate(true))
	endings_seen = snapshot["endings_seen"].duplicate()
	hints = snapshot["hints"].duplicate()
	settings = snapshot["settings"].duplicate()
	last_route = snapshot["last_route"].duplicate(true)
	sim.loop_number = loop_number
	sim.s = snapshot["loop"].duplicate(true)
	settings_changed.emit()
	changed.emit()


# --- Interno --------------------------------------------------------------

func _after_change() -> void:
	_update_velo()
	if is_loop_over() and not endings_seen.has(ending_id()):
		endings_seen[ending_id()] = loop_number
	_autosave()
	changed.emit()


## Velo 1 en cuanto se conoce todo su horario dentro de la ventana del bucle.
func _update_velo() -> void:
	for id: String in data.npc_ids():
		if velo.get(id, 0) >= 1:
			continue
		var complete := true
		for segment: Dictionary in data.relevant_schedule(id):
			if not cuaderno.has("horario_" + segment["id"]):
				complete = false
				break
		if complete:
			velo[id] = 1


func _set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	settings_changed.emit()
	_autosave()


## Condiciones que solo miran el Cuaderno (preguntas abiertas).
func _check_permanent(condition: Variant) -> bool:
	if condition == null:
		return true
	if condition is Array:
		return condition.all(_check_permanent)
	var key: String = condition.keys()[0]
	match key:
		"ALL":
			return _check_permanent(condition[key])
		"ANY":
			return condition[key].any(_check_permanent)
		"NOT":
			var negated: Variant = condition[key]
			return not negated.any(_check_permanent) if negated is Array else not _check_permanent(negated)
		"clue":
			return cuaderno.has(condition[key])
	return false


func _autosave() -> void:
	if autosave_enabled and sim != null:
		SaveManager.write(save_path, export_snapshot())
