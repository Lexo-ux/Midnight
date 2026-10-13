extends SceneTree
## Capturas de todas las pantallas, para revisar la interfaz (necesita ventana:
## en un servidor, con xvfb-run y el driver de Compatibilidad):
##   xvfb-run -a -s "-screen 0 1080x1920x24" godot --path . --rendering-driver opengl3 \
##       --resolution 1080x1920 --script res://scripts/dev/capture_screens.gd -- \
##       [--out build/screens] [--text 0|1|2] [--suffix _x] [--only nombre,nombre] [--reduced]
## Cada pantalla devuelve true (se captura tras asentarse), false (no se puede:
## se salta) o "now" (se captura ya, a mitad de una transición).
## Cada captura empieza en una partida nueva del autoload (sin guardar nada) y
## monta la escena principal desde cero. Escribe <out>/<nombre><suffix>.png.

## La escena principal se carga en tiempo de ejecución: sus scripts nombran el
## autoload GameState, que aún no existe cuando se compila este script.
const MAIN_SCENE_PATH: String = "res://scenes/main.tscn"
const SaveManager := preload("res://scripts/save_manager.gd")
const GameData := preload("res://scripts/game_data.gd")
const GameStateScript := preload("res://scripts/game_state.gd")
## Espera tras preparar cada pantalla (las transiciones duran menos).
const SETTLE_SECONDS: float = 0.9

var _has_run: bool = false
var _main_scene: PackedScene
## El autoload GameState (un script de SceneTree no lo ve por su nombre).
var _gs: GameStateScript
var _main: Control
var _out: String = "build/screens"
var _text_size: int = 0
var _suffix: String = ""
var _only: PackedStringArray = []
var _reduced: bool = false


func _process(_delta: float) -> bool:
	if not _has_run:
		_has_run = true
		_run()
	return false


func _run() -> void:
	_gs = root.get_node("GameState")
	_main_scene = load(MAIN_SCENE_PATH)
	var args := OS.get_cmdline_user_args()
	for i: int in args.size():
		match args[i]:
			"--out":
				_out = args[i + 1]
			"--text":
				_text_size = int(args[i + 1])
			"--suffix":
				_suffix = args[i + 1]
			"--only":
				_only = args[i + 1].split(",")
			"--reduced":
				_reduced = true
	DirAccess.make_dir_recursive_absolute(_absolute(_out))
	var shots: Array[Array] = [
		["01_first_run_tips", _shot_tips],
		["02_place_sazil_day", _shot_place_day],
		["03_place_person_selected", _shot_person_selected],
		["04_place_akba_night", _shot_place_night],
		["05_switch_hold", _shot_switch_hold],
		["06_map", _shot_map],
		["07_map_preview", _shot_map_preview],
		["08_dialogue", _shot_dialogue],
		["09_conversation_start", _shot_conversation],
		["10_conversation_forced", _shot_conversation_forced],
		["11_breakpoint_choice", _shot_breakpoint_choice],
		["12_breakpoint_holding", _shot_breakpoint_holding],
		["13_breakpoint_paused", _shot_breakpoint_paused],
		["14_cuaderno_personas", _shot_notebook.bind("personas", true)],
		["15_cuaderno_personas_empty", _shot_notebook.bind("personas", false)],
		["16_cuaderno_lugares", _shot_notebook.bind("lugares", true)],
		["17_cuaderno_linea", _shot_notebook.bind("linea", true)],
		["18_cuaderno_preguntas", _shot_notebook.bind("preguntas", true)],
		["19_settings", _shot_settings],
		["20_tools", _shot_tools],
		["21_ending_un_buen_dia", _shot_ending.bind("res://data/dev/walkthrough_un_buen_dia.json")],
		["22_ending_otra_vez", _shot_ending.bind("res://data/dev/walkthrough_otra_vez.json")],
		["23_loop_reset", _shot_loop_reset],
		["24_offstage", _shot_offstage],
	]
	for shot: Array in shots:
		var shot_name: String = shot[0]
		if not _only.is_empty() and not _only.has(shot_name):
			continue
		_fresh(true)
		var ok: Variant = await (shot[1] as Callable).call()
		if ok is bool and not ok:
			print("SKIP  %s" % shot_name)
			continue
		if not ok is String:
			await create_timer(SETTLE_SECONDS).timeout
		await process_frame
		var image := root.get_viewport().get_texture().get_image()
		var path := _out.path_join(shot_name + _suffix + ".png")
		image.save_png(_absolute(path))
		print("SHOT  %s (%dx%d)" % [path, image.get_width(), image.get_height()])
	if _main != null:
		_main.queue_free()
	quit(0)


func _absolute(path: String) -> String:
	return path if path.is_absolute_path() else ProjectSettings.globalize_path("res://").path_join(path)


## Partida nueva del autoload, ajustes por defecto y la escena principal desde cero.
func _fresh(tips_seen: bool) -> void:
	if _main != null:
		root.remove_child(_main)
		_main.free()
	_gs.autosave_enabled = false
	for key: String in SaveManager.DEFAULT_SETTINGS:
		_gs.settings[key] = SaveManager.DEFAULT_SETTINGS[key]
	_gs.settings["tips_seen"] = tips_seen
	_gs.settings["text_size"] = _text_size
	_gs.settings["reduced_motion"] = _reduced
	_gs.settings["mute"] = true
	_gs.new_game()
	_main = _main_scene.instantiate()
	root.add_child(_main)
	_gs.settings_changed.emit()


func _node(path: String) -> Node:
	return _main.get_node(path)


func _first_action(verb: String, target: String = "") -> Dictionary:
	for action: Dictionary in _gs.get_actions():
		if action["verb"] == verb and (target == "" or action["target"] == target):
			return action
	return {}


func _skip(time: String) -> void:
	_gs.skip_to(GameData.parse_time(time))


func _play(path: String, until_step: int = -1) -> void:
	var walkthrough: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var steps: Array = walkthrough["steps"]
	for i: int in steps.size():
		if until_step >= 0 and i >= until_step:
			break
		var step: Dictionary = steps[i]
		if step.has("act"):
			_gs.perform(step["act"])
		elif step.has("switch"):
			_gs.switch_to(step["switch"])
		elif step.has("skip"):
			_skip(step["skip"])
		elif step.has("next_loop"):
			_gs.start_next_loop()
		elif step.has("replay"):
			_gs.replay_route(GameData.parse_time(step["replay"]))


# --- Pantallas ----------------------------------------------------------------

func _shot_tips() -> bool:
	_fresh(false)
	return true


func _shot_place_day() -> bool:
	return true


func _shot_person_selected() -> bool:
	var people := _gs.people_at(_gs.position_of("sazil"))
	if people.is_empty():
		return false
	_main.call("_select_person", people[0])
	return true


func _shot_place_night() -> bool:
	_gs.switch_to("akba")
	_skip("22:00")
	return true


func _shot_switch_hold() -> bool:
	await process_frame
	var buttons := _node("%Switcher").get_children()
	if buttons.size() < 2:
		return false
	(buttons[1] as Button).button_down.emit()
	return true


func _shot_map() -> bool:
	_node("%MapView").call("open")
	return true


func _shot_map_preview() -> bool:
	var here := _gs.position_of("sazil")
	for node: Dictionary in _gs.map_nodes():
		if node["selectable"] and node["place"] != here:
			_main.call("_preview_place", node["place"])
			return true
	return false


func _shot_dialogue() -> bool:
	var action := _first_action("observar")
	if action.is_empty():
		return false
	_gs.perform(action)
	return true


func _shot_conversation() -> bool:
	_node("%ConversationView").call("open", "lina")
	return true


func _shot_conversation_forced() -> bool:
	_gs.cuaderno["hecho_fisura_patio"] = {"loop": 1, "by": "sazil", "time": _gs.data.loop_start}
	_gs.switch_to("akba")
	var view: Control = _node("%ConversationView")
	view.call("open", "lina")
	await process_frame
	_gs.play_card(view.get("conv"), "presion")
	view.call("_render")
	await create_timer(0.3).timeout
	view.call("_play", "revelar")
	return true


func _breakpoint_ready() -> Dictionary:
	_gs.perform({"verb": "esperar", "place": "relojeria", "target": "", "id": ""})
	_gs.perform({"verb": "hablar", "place": "mercado", "target": "lina", "id": "conv_lina", "cards": ["escuchar", "silencio", "escuchar"]})
	_gs.dismiss_outcome()
	for candidate: Dictionary in _gs.breakpoint_actions():
		if candidate["id"] == "tirar_de_lina":
			return candidate
	return {}


func _shot_breakpoint_choice() -> bool:
	var action := _breakpoint_ready()
	if action.is_empty():
		return false
	await process_frame
	var view: Control = _node("%BreakpointView")
	if not view.visible:
		view.call("open", action)
	return true


func _shot_breakpoint_holding() -> bool:
	_gs.settings["breakpoint_chosen"] = true
	_gs.settings["breakpoint_time"] = "20"
	var action := _breakpoint_ready()
	if action.is_empty():
		return false
	await process_frame
	var view: Control = _node("%BreakpointView")
	if not view.visible:
		view.call("open", action)
	(view.get_node("%Sustain") as Button).button_down.emit()
	await create_timer(4.0).timeout
	return true


func _shot_breakpoint_paused() -> bool:
	_gs.settings["breakpoint_chosen"] = true
	_gs.settings["breakpoint_time"] = "20"
	var action := _breakpoint_ready()
	if action.is_empty():
		return false
	await process_frame
	var view: Control = _node("%BreakpointView")
	if not view.visible:
		view.call("open", action)
	(view.get_node("%Sustain") as Button).button_down.emit()
	await create_timer(2.0).timeout
	view.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	return true


func _shot_notebook(page: String, with_clues: bool) -> bool:
	if with_clues:
		_play("res://data/dev/walkthrough_un_buen_dia.json", 3)
		_gs.dismiss_outcome()
		_gs.next_hint()
		_gs.velo["lina"] = 3
		_gs.velo["beto"] = 2
		_gs.velo["tun"] = 1
	var notebook: Control = _node("%NotebookView")
	notebook.call("open", page)
	notebook.call("show_page", page)
	return true


func _shot_settings() -> bool:
	_node("%SettingsView").call("open")
	return true


func _shot_tools() -> bool:
	_node("%ToolsView").call("open")
	return true


func _shot_ending(path: String) -> bool:
	_play(path)
	_gs.dismiss_outcome()
	return _gs.is_loop_over()


## La transición de un bucle a otro, a mitad (devuelve "now": se captura ya).
func _shot_loop_reset() -> Variant:
	_play("res://data/dev/walkthrough_otra_vez.json")
	_gs.dismiss_outcome()
	await create_timer(0.5).timeout
	var loop_end: Control = _node("%LoopEndView")
	var next: Button = loop_end.get_node_or_null("%NextLoop")
	if next == null:
		return false
	next.pressed.emit()
	await create_timer(0.45).timeout
	return "now"


## Un protagonista en un lugar sin escena.
func _shot_offstage() -> bool:
	for minute: int in range(_gs.data.loop_start, _gs.data.day_end, _gs.data.step_minutes):
		var place := _gs.position_of("akba")
		if place != "" and not _gs.data.has_scene(place):
			_gs.switch_to("akba")
			return true
		_gs.skip_to(minute + _gs.data.step_minutes)
	return false
