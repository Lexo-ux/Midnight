extends SceneTree
## Mide el coste de la escena principal (Task 06): tiempo de fotograma y
## llamadas de dibujo, en tres momentos (escena de día con Sazil,
## Akba de noche con sus fisuras latiendo y una conversación abierta).
##   godot --headless --path . --script res://scripts/dev/measure_perf.gd
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1080x1920 --script res://scripts/dev/measure_perf.gd
## Sin pantalla solo cuenta el proceso (el dibujo es de mentira); con xvfb el
## dibujo es por software (llvmpipe): mucho más lento que la GPU de un móvil.

const SaveManager := preload("res://scripts/save_manager.gd")
const GameStateScript := preload("res://scripts/game_state.gd")
const SAMPLE_FRAMES: int = 120
const WARMUP_FRAMES: int = 20

var _has_run: bool = false


func _process(_delta: float) -> bool:
	if not _has_run:
		_has_run = true
		_run()
	return false


func _run() -> void:
	var state: GameStateScript = root.get_node("GameState")
	state.autosave_enabled = false
	for key: String in SaveManager.DEFAULT_SETTINGS:
		state.settings[key] = SaveManager.DEFAULT_SETTINGS[key]
	state.settings["tips_seen"] = true
	state.settings["mute"] = true
	state.new_game()
	var main: Control = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	print("Renderizador: %s · %s" % [RenderingServer.get_current_rendering_driver_name(), RenderingServer.get_video_adapter_name()])
	await _sample("escena de día (Sazil)")
	state.switch_to("akba")
	state.skip_to(21 * 60 + 30)
	state.perform({"verb": "esperar", "place": "plaza", "target": "", "id": ""})
	state.dismiss_outcome()
	await _sample("noche (Akba, fisuras)")
	(main.get_node("%ConversationView") as Control).call("open", "tun")
	await _sample("conversación abierta")
	quit(0)


func _sample(label: String) -> void:
	for i: int in WARMUP_FRAMES:
		await process_frame
	var frame_ms := 0.0
	var worst_ms := 0.0
	var draw_calls := 0.0
	var objects := 0.0
	var last := Time.get_ticks_usec()
	for i: int in SAMPLE_FRAMES:
		await process_frame
		var now := Time.get_ticks_usec()
		var frame := (now - last) / 1000.0
		last = now
		frame_ms += frame
		worst_ms = maxf(worst_ms, frame)
		draw_calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		objects += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	print("%-24s fotograma %.1f ms (peor %.1f) · %d llamadas de dibujo · %d objetos · %.0f MB estáticos" % [label,
			frame_ms / SAMPLE_FRAMES, worst_ms, roundi(draw_calls / SAMPLE_FRAMES),
			roundi(objects / SAMPLE_FRAMES), Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0])
