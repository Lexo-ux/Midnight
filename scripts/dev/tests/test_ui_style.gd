extends "res://scripts/dev/tests/test_suite.gd"
## Accesibilidad y sistema visual (Task 06): el tema único se aplica a todas las
## escenas (sin estilos sueltos), coincide con scripts/ui_style.gd, ningún
## control táctil mide menos de 48 dp, el texto de cuerpo contrasta 4,5:1 o
## más, ninguna pantalla desborda con los tres tamaños de texto, el movimiento
## reducido se respeta en lo nuevo, toda ranura de arte se resuelve y todo
## texto que pide la interfaz existe en ui_text.json.

const UiStyle := preload("res://scripts/ui_style.gd")
const MAIN_SCENE_PATH: String = "res://scenes/main.tscn"
## Únicos estilos puestos a mano: los márgenes de la zona segura (muescas).
const ALLOWED_OVERRIDES: Dictionary = {"res://scripts/main.gd": 2}


func test_project_theme_matches_ui_style() -> bool:
	check(ProjectSettings.get_setting("gui/theme/custom") == UiStyle.THEME_PATH, "gui/theme/custom es el tema del juego")
	var saved: Theme = load(UiStyle.THEME_PATH)
	var built := UiStyle.build_theme()
	if not check(saved != null, "el tema guardado se carga"):
		return true
	for type: StringName in built.get_type_list():
		check(saved.get_type_variation_base(type) == built.get_type_variation_base(type), "%s: misma base" % type)
		for item: StringName in built.get_color_list(type):
			check(saved.get_color(item, type).is_equal_approx(built.get_color(item, type)), "%s/%s: el color coincide (regenera con make_theme.gd)" % [type, item])
		for item: StringName in built.get_constant_list(type):
			check(saved.get_constant(item, type) == built.get_constant(item, type), "%s/%s: la constante coincide" % [type, item])
		for item: StringName in built.get_stylebox_list(type):
			var a := saved.get_stylebox(item, type)
			var b := built.get_stylebox(item, type)
			check(a.get_class() == b.get_class(), "%s/%s: mismo tipo de caja" % [type, item])
			if a is StyleBoxFlat and b is StyleBoxFlat:
				var fa := a as StyleBoxFlat
				var fb := b as StyleBoxFlat
				check(fa.bg_color.is_equal_approx(fb.bg_color) and fa.border_color.is_equal_approx(fb.border_color)
						and fa.border_width_bottom == fb.border_width_bottom and fa.border_width_left == fb.border_width_left
						and fa.corner_radius_top_left == fb.corner_radius_top_left and is_equal_approx(fa.content_margin_top, fb.content_margin_top),
						"%s/%s: la caja coincide (regenera con make_theme.gd)" % [type, item])
	check(saved.get_type_list().size() == built.get_type_list().size(), "los mismos tipos: %d y %d" % [saved.get_type_list().size(), built.get_type_list().size()])
	return true


func test_scenes_use_the_theme_without_ad_hoc_styles() -> bool:
	var theme: Theme = load(UiStyle.THEME_PATH)
	var variation := RegEx.create_from_string("&\"([A-Za-z]+)\"")
	for path: String in _files("res://scenes", "tscn"):
		var text := FileAccess.get_file_as_string(path)
		check(not text.contains("theme_override_"), "%s no lleva estilos propios (theme_override_)" % path)
		check(not text.contains("type=\"Theme\""), "%s no incrusta un tema" % path)
		check(not text.contains("type=\"StyleBox"), "%s no lleva cajas de estilo propias" % path)
		for line: String in text.split("\n"):
			if line.begins_with("theme_type_variation"):
				for found: RegExMatch in variation.search_all(line):
					check(theme.get_type_list().has(found.get_string(1)), "%s usa la variación %s, que no está en el tema" % [path, found.get_string(1)])
	var override := RegEx.create_from_string("add_theme_(color|stylebox|constant|font_size|font|icon)_override")
	for path: String in _files("res://scripts", "gd"):
		var text := FileAccess.get_file_as_string(path)
		var count := override.search_all(text).size()
		check(count == ALLOWED_OVERRIDES.get(path, 0), "%s: %d estilos puestos a mano (se esperaban %d)" % [path, count, ALLOWED_OVERRIDES.get(path, 0)])
		for line: String in text.split("\n"):
			if line.contains("theme_type_variation") or line.contains("UiStyle.touch("):
				for found: RegExMatch in variation.search_all(line):
					check(theme.get_type_list().has(found.get_string(1)), "%s usa la variación %s, que no está en el tema" % [path, found.get_string(1)])
	return true


func test_contrast_of_body_text() -> bool:
	check(is_equal_approx(UiStyle.contrast_ratio(Color.BLACK, Color.WHITE), 21.0), "negro sobre blanco: 21:1")
	check(is_equal_approx(UiStyle.contrast_ratio(UiStyle.VIOLET, UiStyle.VIOLET), 1.0), "un color sobre sí mismo: 1:1")
	var lines: PackedStringArray = []
	var pairs: Array[Array] = UiStyle.TEXT_PAIRS.duplicate()
	# El panel de arriba es translúcido: el peor caso es sobre un cielo blanco.
	var top := UiStyle.over(Color(UiStyle.NIGHT, 0.9), Color.WHITE)
	pairs.append(["Caption sobre el panel de arriba (cielo blanco)", UiStyle.TEXT_LIGHT, top])
	pairs.append(["NightMuted sobre el panel de arriba (cielo blanco)", UiStyle.TEXT_LIGHT_MUTED, top])
	for pair: Array in pairs:
		var ratio := UiStyle.contrast_ratio(pair[1], pair[2])
		lines.append("%s %.1f:1" % [pair[0], ratio])
		check(ratio >= UiStyle.MIN_CONTRAST, "%s: contraste %.2f:1 (mínimo %.1f)" % [pair[0], ratio, UiStyle.MIN_CONTRAST])
	print("        contraste · " + " · ".join(lines))
	return true


## Todo lo que se toca mide 48 dp o más, en todas las pantallas y tamaños de texto.
func test_no_touch_target_below_48dp() -> bool:
	check(UiStyle.MIN_TOUCH >= roundi(48.0 * UiStyle.PX_PER_DP), "48 dp son %d px" % roundi(48.0 * UiStyle.PX_PER_DP))
	check((load("res://scripts/place_view.gd") as Script).get_script_constant_map()["TOUCH_MIN"] >= UiStyle.MIN_TOUCH,
			"personas y puntos de la escena se tocan desde 48 dp")
	for text_size: int in 3:
		var main := _main(text_size)
		_scan_targets(main, "principal")
		for screen: Control in _open_every_screen(main):
			_scan_targets(screen, screen.name)
		# Medianoche.
		routine_until(GameState, GameState.data.day_end)
		GameState.dismiss_outcome()
		main.call("_refresh")
		_scan_targets(main.get_node("%LoopEndView"), "LoopEndView")
		cleanup()
	return true


## Con los tres tamaños de texto, ninguna pantalla pide más ancho que el de la pantalla.
func test_no_horizontal_overflow_at_any_text_size() -> bool:
	for text_size: int in 3:
		var main := _main(text_size)
		check(main.get_node("Top").get_combined_minimum_size().x <= main.size.x, "texto %d: la cabecera cabe" % text_size)
		check(main.get_node("Bottom").get_combined_minimum_size().x <= main.size.x, "texto %d: el panel de abajo cabe" % text_size)
		var notebook: Control = main.get_node("%NotebookView")
		for page_id: String in ["personas", "lugares", "linea", "preguntas"]:
			notebook.open(page_id)
			check(notebook.get_combined_minimum_size().x <= main.size.x, "texto %d: el Cuaderno (%s) cabe: %d px" % [text_size, page_id,
					notebook.get_combined_minimum_size().x])
		for screen: Control in _open_every_screen(main):
			var panel := _panel_of(screen)
			check(panel.get_combined_minimum_size().x <= main.size.x, "texto %d: %s cabe: %d px" % [text_size, screen.name,
					panel.get_combined_minimum_size().x])
		cleanup()
	return true


## Con movimiento reducido no se mueve nada nuevo: ni el aplastar de los
## botones, ni la franja del relevo, ni el temblor al forzar, ni la transición
## de bucle (corte).
func test_reduced_motion_is_respected() -> bool:
	var main := _main(0)
	GameState.settings["reduced_motion"] = true
	var map_button: Button = main.get_node("%MapButton")
	map_button.button_down.emit()
	check(map_button.scale == Vector2.ONE, "el botón no se aplasta")
	map_button.button_up.emit()
	GameState.switch_to("akba")
	check(not main.get_node("%Sweep").visible, "no hay franja de relevo")
	GameState.cuaderno["hecho_fisura_patio"] = {"loop": 1, "by": "sazil", "time": GameState.data.loop_start}
	var conv: Control = main.get_node("%ConversationView")
	conv.open("lina")
	var sheet: Control = conv.get_node("%Sheet")
	var home := sheet.position
	conv.call("_play", "presion")
	conv.call("_play", "revelar")
	check(conv.conv["result"] == "win" and conv.conv["forced"], "se gana a la fuerza")
	check(sheet.position == home, "la hoja no tiembla")
	conv.get_node("%Continue").pressed.emit()
	routine_until(GameState, GameState.data.day_end)
	GameState.dismiss_outcome()
	main.call("_refresh")
	var loop_end: Control = main.get_node("%LoopEndView")
	check(loop_end.visible, "a medianoche sale el final")
	loop_end.get_node("%NextLoop").pressed.emit()
	check(GameState.loop_number == 2 and not main.get_node("%LoopResetView").visible, "el bucle nuevo empieza sin transición")
	return true


## La transición de bucle existe sin movimiento reducido, dura ≤ 1,2 s y un toque o «atrás» la salta.
func test_loop_reset_transition_is_short_and_skippable() -> bool:
	var main := _main(0)
	var reset: Control = main.get_node("%LoopResetView")
	var script_constants: Dictionary = reset.get_script().get_script_constant_map()
	check(script_constants["REWIND_SECONDS"] + script_constants["FADE_SECONDS"] <= 1.2, "dura 1,2 s o menos")
	routine_until(GameState, GameState.data.day_end)
	GameState.dismiss_outcome()
	main.call("_refresh")
	main.get_node("%LoopEndView").get_node("%NextLoop").pressed.emit()
	check(reset.visible, "al empezar otro bucle, el reloj vuelve atrás")
	main.go_back()
	check(not reset.visible and GameState.loop_number == 2, "«atrás» la salta y el bucle ya empezó")
	return true


## Cada ranura del manifiesto tiene arte de verdad o su provisional generado,
## salvo las caras de la comunidad (se dibujan en código mientras no lleguen).
func test_every_art_slot_resolves() -> bool:
	var art := ArtLibrary.new()
	check(art.load_manifest(), "el manifiesto es válido")
	for id: String in art.slot_ids:
		if id.begins_with("npc_"):
			continue
		check(art.source_of(id) != "drawn", "%s: hay arte de verdad o provisional (%s)" % [id, art.slots[id]["path"]])
	return true


## Todo `text("clave")` que pide un script existe en data/ui_text.json.
func test_every_ui_text_key_exists() -> bool:
	var data := new_state().data
	var key := RegEx.create_from_string("text\\(\"([a-z0-9_]+)\"\\)")
	for path: String in _files("res://scripts", "gd"):
		if path.begins_with("res://scripts/dev/"):
			continue
		for found: RegExMatch in key.search_all(FileAccess.get_file_as_string(path)):
			check(data.ui_text.has(found.get_string(1)), "%s pide el texto \"%s\", que no está en ui_text.json" % [path, found.get_string(1)])
	return true


# --- Ayudas -------------------------------------------------------------------

func _main(text_size: int) -> Control:
	GameState.autosave_enabled = false
	GameState.new_game()
	for setting: String in SaveManager.DEFAULT_SETTINGS:
		GameState.settings[setting] = SaveManager.DEFAULT_SETTINGS[setting]
	GameState.settings["tips_seen"] = true
	GameState.settings["text_size"] = text_size
	var main: Control = add_node(load(MAIN_SCENE_PATH).instantiate())
	main.size = Vector2(1080, 1920)
	GameState.settings_changed.emit()
	return main


## Abre una a una las pantallas superpuestas (y deja abiertas las que caben
## juntas); devuelve las que hay que revisar.
func _open_every_screen(main: Control) -> Array[Control]:
	var screens: Array[Control] = []
	for path: String in ["%MapView", "%SettingsView", "%ToolsView", "%NotebookView"]:
		var screen: Control = main.get_node(path)
		screen.open()
		screens.append(screen)
	var tips: Control = main.get_node("%TipsView")
	tips.open()
	screens.append(tips)
	var conv: Control = main.get_node("%ConversationView")
	conv.open("lina")
	screens.append(conv)
	# Un diálogo (observar) y el quiebre de Lina a las 15:00.
	var observe: Array[Dictionary] = GameState.get_actions().filter(func(a: Dictionary) -> bool: return a["verb"] == "observar")
	if not observe.is_empty():
		GameState.perform(observe[0])
		main.call("_refresh")
		screens.append(main.get_node("%DialogueView"))
	var breakpoint_view: Control = main.get_node("%BreakpointView")
	GameState.perform({"verb": "hablar", "place": "mercado", "target": "lina", "id": "conv_lina", "cards": ["escuchar", "silencio", "escuchar"]})
	for action: Dictionary in GameState.breakpoint_actions():
		breakpoint_view.open(action)
		break
	screens.append(breakpoint_view)
	return screens


## La hoja que hay que medir de una pantalla (su «Sheet» si la tiene).
func _panel_of(screen: Control) -> Control:
	for path: String in ["%Sheet", "Sheet"]:
		var sheet := screen.get_node_or_null(path) as Control
		if sheet != null:
			return sheet
	return screen


func _scan_targets(node: Node, where: String) -> void:
	if node is Control and not (node as Control).visible:
		return
	if node is BaseButton or node is Slider:
		var control := node as Control
		var minimum := control.get_combined_minimum_size()
		check(minimum.x >= UiStyle.MIN_TOUCH and minimum.y >= UiStyle.MIN_TOUCH,
				"%s: %s «%s» mide %s (mínimo %d px = 48 dp)" % [where, control.name, control.get("text") if control is Button else "",
				minimum, UiStyle.MIN_TOUCH])
	for child: Node in node.get_children():
		_scan_targets(child, where)


static func _files(directory: String, extension: String) -> PackedStringArray:
	var found: PackedStringArray = []
	var dir := DirAccess.open(directory)
	if dir == null:
		return found
	for file: String in dir.get_files():
		if file.get_extension() == extension:
			found.append(directory.path_join(file))
	for sub: String in dir.get_directories():
		found.append_array(_files(directory.path_join(sub), extension))
	return found
