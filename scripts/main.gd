extends Control
## Pantalla principal: la escena del lugar donde está el protagonista
## controlado, en primera persona (solo sus manos). Lee GameState, llama a sus
## acciones y se redibuja cuando cambia. Solo guarda estado visual: qué lugar se
## mira desde el mapa, a quién se ha elegido y la animación del relevo.
##
## Arriba: hora (con un pequeño tic al avanzar), bucle, «¿Qué hago?» (siempre a
## mano), Ajustes, y Mapa, Cuaderno y Tiempo. En medio: la escena (mirando otro
## lugar desde el mapa, un aviso cian con «Volver»). Abajo, al alcance del
## pulgar: lo que se puede hacer allí (una flecha avisa si hay más abajo) y el
## selector Sazil/Akba con sus retratos.
##
## Encima, sin cambiar de escena: conversaciones con cartas, momentos de
## quiebre (se abren solos al llegar el momento si el protagonista está allí),
## consejos de la primera partida y los paneles de siempre. El botón «atrás» de
## Android cierra el de más arriba (y en una conversación con cartas jugadas
## pregunta antes); sin nada abierto abre Ajustes: nunca sale del juego.
## También manda sonido (AudioDirector) y vibración (Haptics), el relevo de
## mirada (look_wipe.gd), la transición de bucle (loop_reset_view.gd) y el
## pequeño aplastamiento de cualquier botón al pulsarlo. Nada de esto se mueve
## con movimiento reducido.

const GameData := preload("res://scripts/game_data.gd")
const ArtLibrary := preload("res://scripts/art_library.gd")
const UiStyle := preload("res://scripts/ui_style.gd")
const UiMotion := preload("res://scripts/ui_motion.gd")
const SWITCH_BUTTON_SCENE := preload("res://scenes/switch_button.tscn")
## Acciones que no dependen del lugar (la bolsa de Sazil).
const BAG_VERBS: PackedStringArray = ["leer", "retener"]
const SWEEP_SECONDS: float = 0.22
## Margen de los paneles de arriba y abajo sin zona segura (el del tema).
const TOP_MARGIN: float = 48.0
const BOTTOM_MARGIN: float = 24.0

@onready var _place_view: Control = %PlaceView
@onready var _hands: Control = %Hands
@onready var _time_label: Label = %TimeLabel
@onready var _loop_label: Label = %LoopLabel
@onready var _caption: Label = %Caption
@onready var _status: Label = %Status
@onready var _back_button: Button = %BackButton
@onready var _caption_panel: PanelContainer = %CaptionPanel
@onready var _map_button: Button = %MapButton
@onready var _notebook_button: Button = %NotebookButton
@onready var _tools_button: Button = %ToolsButton
@onready var _settings_button: Button = %SettingsButton
@onready var _what_now_button: Button = %WhatNowButton
@onready var _top: PanelContainer = $Top
@onready var _bottom: PanelContainer = $Bottom
@onready var _description: Label = %Description
@onready var _people: HBoxContainer = %People
@onready var _people_scroll: ScrollContainer = %PeopleScroll
@onready var _actions: VBoxContainer = %Actions
@onready var _actions_scroll: ScrollContainer = %ActionsScroll
@onready var _more_hint: TextureRect = %MoreHint
@onready var _switcher: HBoxContainer = %Switcher
@onready var _sweep: Control = %Sweep
@onready var _map: Control = %MapView
@onready var _dialogue: Control = %DialogueView
@onready var _notebook: Control = %NotebookView
@onready var _tools: Control = %ToolsView
@onready var _settings: Control = %SettingsView
@onready var _loop_end: Control = %LoopEndView
@onready var _conversation: Control = %ConversationView
@onready var _breakpoint: Control = %BreakpointView
@onready var _tips: Control = %TipsView
@onready var _loop_reset: Control = %LoopResetView

var _art: ArtLibrary = ArtLibrary.new()
var _switch_buttons: Dictionary[String, Button] = {}
## Lugar que se mira desde el mapa sin estar allí ("" = donde está el protagonista).
var _view_place: String = ""
## Persona elegida en la escena ("" = acciones del lugar).
var _selected: String = ""
## Cambia con cada acción o relevo: entonces se olvidan la vista previa y la persona elegida.
var _route_key: String = ""
var _refresh_queued: bool = false
## Quiebres que ya se abrieron solos ("bucle|hora|interacción"): no se insiste.
var _breakpoints_offered: Dictionary = {}
## Hora que se enseñaba (para el tic del reloj).
var _shown_time: String = ""


func _ready() -> void:
	var data := GameState.data
	if not data.is_loaded():
		_caption.text = data.text("error_carga") if not data.ui_text.is_empty() else "Error"
		return
	_art.load_manifest()
	_place_view.bind(GameState, _art)
	_place_view.hotspot_tapped.connect(func(id: String) -> void: GameState.perform_hotspot(id))
	_place_view.person_tapped.connect(_select_person)
	_hands.bind(_art)
	_conversation.bind(_art)
	_breakpoint.bind(_art)
	_notebook.bind(_art)
	_dialogue.bind(_art)
	_loop_end.bind(_art)
	_map.bind(GameState, _art)
	_map.place_chosen.connect(_preview_place)
	for actor: String in data.protagonist_ids:
		var button: Button = SWITCH_BUTTON_SCENE.instantiate()
		_switcher.add_child(button)
		button.setup(GameState, _art, actor)
		button.chosen.connect(func(id: String) -> void: GameState.switch_to(id))
		_switch_buttons[actor] = button
	_map_button.text = data.text("boton_mapa")
	_notebook_button.text = data.text("boton_cuaderno")
	_tools_button.text = data.text("boton_herramientas")
	_settings_button.tooltip_text = data.text("boton_ajustes")
	_back_button.text = data.text("escena_volver")
	_what_now_button.text = data.text("que_hago")
	_what_now_button.pressed.connect(func() -> void: _notebook.what_now())
	_settings.tips_requested.connect(func() -> void: _tips.open())
	_conversation.closed.connect(_queue_refresh)
	_breakpoint.closed.connect(_queue_refresh)
	_map_button.pressed.connect(func() -> void: _map.open())
	_notebook_button.pressed.connect(func() -> void: _notebook.open())
	_tools_button.pressed.connect(func() -> void: _tools.open())
	_settings_button.pressed.connect(func() -> void: _settings.open())
	_back_button.pressed.connect(func() -> void: _preview_place(""))
	_loop_end.notebook_requested.connect(func() -> void: _notebook.open())
	_loop_end.next_loop_started.connect(_play_loop_reset)
	_tips.set_targets([_switcher, _notebook_button, _tools_button])
	_actions_scroll.get_v_scroll_bar().value_changed.connect(func(_value: float) -> void: _update_more_hint())
	_actions_scroll.get_v_scroll_bar().changed.connect(_update_more_hint)
	# Bajo una pantalla opaca a pantalla completa no se dibuja la escena (móviles modestos).
	for overlay: Control in _opaque_overlays():
		overlay.visibility_changed.connect(_update_scene_visibility)
	get_tree().node_added.connect(_attach_press)
	for button: Node in find_children("*", "BaseButton", true, false):
		_attach_press(button)
	GameState.changed.connect(_queue_refresh)
	GameState.switched.connect(_play_sweep)
	GameState.settings_changed.connect(_on_settings_changed)
	resized.connect(_apply_safe_area)
	_apply_text_size()
	_apply_feedback_settings()
	_apply_safe_area()
	_refresh()
	if not GameState.settings["tips_seen"]:
		_tips.open()


func _queue_refresh() -> void:
	if not _refresh_queued:
		_refresh_queued = true
		_refresh.call_deferred()


func _refresh() -> void:
	_refresh_queued = false
	var data := GameState.data
	var actor := GameState.active_actor()
	var route_key := "%d|%d|%s" % [GameState.loop_number, GameState.sim.s["route"].size(), actor]
	if route_key != _route_key:
		_route_key = route_key
		_view_place = ""
		_selected = ""
	var here := GameState.position_of(actor)
	var place := _view_place if _view_place != "" else here
	var preview := place != here
	if not GameState.people_at(place).has(_selected):
		_selected = ""
	var time_text := GameData.format_time(GameState.current_time())
	if time_text != _shown_time and _shown_time != "" and not GameState.settings["reduced_motion"]:
		UiMotion.tick(_time_label)
	_shown_time = time_text
	_time_label.text = time_text
	_loop_label.text = data.text("bucle").format({"n": GameState.loop_number})
	_place_view.refresh(place, preview, _selected)
	var reduced: bool = GameState.settings["reduced_motion"]
	_hands.show_hands(actor, GameState.hands_state(actor), 0.0 if reduced else data.scene_camera["hands_ms"] / 1000.0)
	# Sin escena (el protagonista está en otro sitio), no hay manos que enseñar.
	_hands.visible = data.has_scene(place) and _place_view.visible
	_refresh_caption(place, preview)
	_refresh_status()
	_refresh_switcher()
	var actions := GameState.get_actions()
	_refresh_people(place, actions)
	_refresh_actions(place, here, actions)
	_update_more_hint.call_deferred()
	_dialogue.sync()
	_loop_end.sync(_dialogue.has_pending())
	AudioDirector.set_scene_sound(data.is_night(GameState.current_time()), _near_fissure(here))
	_offer_breakpoint.call_deferred()


func _refresh_caption(place: String, preview: bool) -> void:
	var data := GameState.data
	var actor := GameState.active_actor()
	_back_button.visible = preview and data.has_scene(place)
	# Mirando otro lugar desde el mapa: aviso cian (forma y color) con «Volver».
	_caption_panel.theme_type_variation = &"Banner" if _back_button.visible else &""
	_caption.theme_type_variation = &"BannerLabel" if _back_button.visible else &"Caption"
	if _back_button.visible:
		_caption.text = data.text("escena_lejos").format({"lugar": data.locations[place]["name"]})
		return
	if not data.has_scene(place):
		_caption.text = data.locations[place]["name"]
		return
	var station := GameState.station_of(actor, place)
	if station == "":
		station = data.scenes[place]["entry"]
	var station_name: String = data.scenes[place]["stations"][data.scenes[place]["station_index"][station]]["name"]
	var values: Dictionary = {"lugar": data.locations[place]["name"], "estacion": station_name}
	if data.locations[place]["open"] < 0:
		_caption.text = data.text("escena_lugar").format(values)
		return
	values["estado"] = data.text("lugar_abierto" if data.is_open(place, GameState.current_time()) else "lugar_cerrado")
	_caption.text = data.text("escena_lugar_horario").format(values)


func _refresh_status() -> void:
	var data := GameState.data
	var actor := GameState.active_actor()
	var lines: PackedStringArray = []
	if GameState.is_disabled(actor):
		lines.append(data.text("atrapado_aviso"))
	elif GameState.is_exhausted(actor):
		lines.append(data.text("acciones_akba_agotado"))
	if actor == "akba" or GameState.rastro() > 0:
		lines.append(data.text("rastro_desgaste").format({"rastro": GameState.rastro(), "rastro_max": data.rastro_max,
				"desgaste": GameState.desgaste(), "desgaste_max": data.desgaste_max}))
	_status.text = "\n".join(lines)
	_status.visible = not lines.is_empty()


func _refresh_switcher() -> void:
	var data := GameState.data
	for actor: String in _switch_buttons:
		var status: String
		if GameState.is_disabled(actor):
			status = data.text("estado_atrapado")
		elif GameState.is_exhausted(actor):
			status = data.text("estado_agotado")
		else:
			status = data.text("estado_en").format({"lugar": data.locations[GameState.position_of(actor)]["short"]})
		_switch_buttons[actor].refresh(actor == GameState.active_actor(), status, GameState.can_switch())


## Una ficha por persona del lugar (o la elegida y «Todas las acciones»).
func _refresh_people(place: String, actions: Array[Dictionary]) -> void:
	var data := GameState.data
	for child: Node in _people.get_children():
		_people.remove_child(child)
		child.queue_free()
	var present := GameState.people_at(place)
	_people_scroll.visible = not present.is_empty() and data.has_scene(place)
	if _selected != "":
		_people.add_child(_chip(data.text("escena_todas"), false, _select_person.bind(_selected)))
	for person: String in present:
		var has_actions := actions.any(func(action: Dictionary) -> bool: return action["place"] == place and action["target"] == person)
		var chip := _chip(data.people[person]["name"], person == _selected, _select_person.bind(person))
		chip.disabled = not has_actions
		_people.add_child(chip)
	var description := ""
	if data.has_scene(place):
		for variant: Dictionary in data.locations[place]["card"]:
			if variant["actor"] in [GameState.active_actor(), "any"] and GameState.sim.check(variant["if"], {"place": place}):
				description = variant["text"]
				break
	_description.text = description
	_description.visible = description != ""


## Las acciones de la persona elegida o, si no hay, las del lugar y la bolsa.
func _refresh_actions(place: String, here: String, actions: Array[Dictionary]) -> void:
	for child: Node in _actions.get_children():
		_actions.remove_child(child)
		child.queue_free()
	for action: Dictionary in actions:
		var bag := BAG_VERBS.has(action["verb"])
		var shown: bool = bag if place != action["place"] else (bag or action["target"] == _selected)
		if not shown:
			continue
		var button := Button.new()
		button.text = _action_label(action, here)
		UiStyle.touch(button)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(_do_action.bind(action))
		_actions.add_child(button)


## Una acción: las conversaciones con cartas y los quiebres abren su pantalla;
## el resto se hace ya.
func _do_action(action: Dictionary) -> void:
	var data := GameState.data
	if action["verb"] == "hablar" and data.conversations.has(action["id"]):
		_conversation.open(action["target"])
	elif action["verb"] == "interactuar" and data.breakpoint_by_interaction.has(action["id"]):
		_breakpoint.open(action)
	else:
		GameState.perform(action)


func _chip(text: String, active: bool, on_pressed: Callable) -> Button:
	var chip := Button.new()
	chip.text = text
	UiStyle.touch(chip, &"ChipSelected" if active else &"Chip")
	chip.pressed.connect(on_pressed)
	return chip


## Texto del botón de una acción, con los formatos de ui_text.json.
func _action_label(action: Dictionary, here: String) -> String:
	var data := GameState.data
	var values: Dictionary = {}
	if action["target"] != "":
		values["nombre"] = data.people[action["target"]]["name"]
	match action["verb"]:
		"esperar":
			return data.text("accion_esperar" if action["place"] == here else "accion_ir")
		"observar":
			return data.text("accion_observar" if action["target"] != "" else "accion_observar_lugar").format(values)
		"seguir":
			return data.text("accion_seguir").format(values)
		"hablar":
			var talk: Dictionary = data.conversations[action["id"]] if data.conversations.has(action["id"]) else data.talks[action["id"]]
			values["tema"] = talk["label"]
			return data.text("accion_hablar").format(values)
		"interactuar":
			var interaction: Dictionary = data.interactions[action["id"]]
			if data.breakpoint_by_interaction.has(action["id"]):
				return data.text("accion_quiebre").format({"texto": interaction["label"]})
			return data.text("accion_" + interaction["verb"]).format({"texto": interaction["label"]})
		_:
			values["carta"] = data.letters[action["id"]]["label"]
			return data.text("accion_" + action["verb"]).format(values)


func _select_person(person: String) -> void:
	_selected = "" if _selected == person else person
	_queue_refresh()


## Desde el mapa: mirar un lugar sin gastar tiempo ("" = volver a donde se está).
func _preview_place(place: String) -> void:
	_view_place = "" if place == GameState.position_of(GameState.active_actor()) else place
	_selected = ""
	_queue_refresh()


## El relevo: una franja de rotulador desde el lado de quien entra (Sazil por
## la izquierda, Akba por la derecha) mientras cambia la mirada de la escena. Si
## se cambia muy rápido, la anterior se corta y empieza otra. Con movimiento
## reducido no hay franja.
func _play_sweep(actor: String) -> void:
	AudioDirector.play_event("switch_" + actor)
	Haptics.play("switch")
	if GameState.settings["reduced_motion"]:
		_sweep.stop()
		return
	var data := GameState.data
	var from_left := data.protagonist_ids.find(actor) == 0
	_sweep.play(from_left, UiStyle.SAZIL_FILL_ACTIVE if from_left else UiStyle.AKBA_FILL_ACTIVE, SWEEP_SECONDS)


## Bucle nuevo: el reloj vuelve atrás (o corte con movimiento reducido).
func _play_loop_reset() -> void:
	var data := GameState.data
	_loop_reset.play(_art, data.text("bucle").format({"n": GameState.loop_number}), data.day_end, data.loop_start,
			GameState.settings["reduced_motion"])


## La flecha de «hay más acciones abajo»: solo si no caben y no se ha bajado del todo.
func _update_more_hint() -> void:
	var bar := _actions_scroll.get_v_scroll_bar()
	_more_hint.visible = bar.max_value - bar.page > 1.0 and bar.value < bar.max_value - bar.page - 1.0


## Cualquier botón de la pantalla se aplasta un poco al pulsarlo (salvo con
## movimiento reducido).
func _attach_press(node: Node) -> void:
	if node is BaseButton and is_ancestor_of(node) and not node.has_meta(&"press_motion"):
		node.set_meta(&"press_motion", true)
		var button := node as BaseButton
		button.button_down.connect(_on_button_down.bind(button))
		button.button_up.connect(_on_button_up.bind(button))


func _on_button_down(button: BaseButton) -> void:
	UiMotion.press(button, GameState.settings["reduced_motion"])


func _on_button_up(button: BaseButton) -> void:
	UiMotion.release(button, GameState.settings["reduced_motion"])


func _on_settings_changed() -> void:
	_apply_text_size()
	_apply_feedback_settings()
	_queue_refresh()


func _apply_feedback_settings() -> void:
	AudioDirector.apply_settings(GameState.settings)
	Haptics.set_level(GameState.settings["haptics"])


## Un quiebre se abre solo cuando llega su momento y el protagonista activo está
## allí (y nada más está abierto). Una vez por bucle, hora e interacción; si se
## cierra con «Ahora no», sigue en la lista de acciones.
func _offer_breakpoint() -> void:
	if _overlay_open() or GameState.is_loop_over():
		return
	var data := GameState.data
	var here := GameState.position_of(GameState.active_actor())
	for action: Dictionary in GameState.breakpoint_actions():
		if data.breakpoints[data.breakpoint_by_interaction[action["id"]]]["place"] != here:
			continue
		var key := "%d|%d|%s" % [GameState.loop_number, GameState.current_time(), action["id"]]
		if _breakpoints_offered.has(key):
			continue
		_breakpoints_offered[key] = true
		_breakpoint.open(action)
		return


## Hay una fisura en este lugar a esta hora (el tic-tac del Reloj se desajusta).
func _near_fissure(place: String) -> bool:
	var data := GameState.data
	var t := GameState.current_time()
	for id: String in data.hotspots:
		var hotspot: Dictionary = data.hotspots[id]
		if hotspot["fissure"] and hotspot["place"] == place and t >= hotspot["from"] and t < hotspot["to"]:
			return true
	return false


## Pantallas que tapan la escena entera (opacas o casi).
func _opaque_overlays() -> Array[Control]:
	return [_conversation, _breakpoint, _settings, _tools, _notebook, _map, _loop_end, _loop_reset]


func _update_scene_visibility() -> void:
	var covered := _opaque_overlays().any(func(overlay: Control) -> bool: return overlay.visible)
	_place_view.visible = not covered
	_hands.visible = not covered and GameState.data.has_scene(_place_view.place)


func _overlay_open() -> bool:
	for overlay: Control in [_conversation, _breakpoint, _tips, _settings, _tools, _notebook, _map, _dialogue, _loop_end, _loop_reset]:
		if overlay.visible:
			return true
	return false


## Botón «atrás» de Android (y Escape en escritorio): cierra lo de más arriba.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		go_back()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		go_back()
		get_viewport().set_input_as_handled()


func go_back() -> void:
	if _loop_reset.visible:
		_loop_reset.skip()
	elif _tips.visible:
		_tips.close()
	elif _conversation.visible:
		_conversation.back()
	elif _breakpoint.visible:
		_breakpoint.back()
	elif _settings.visible:
		_settings.hide()
	elif _tools.visible:
		_tools.hide()
	elif _notebook.visible:
		_notebook.hide()
	elif _map.visible:
		_map.hide()
	elif _view_place != "":
		_preview_place("")
	elif not _dialogue.visible and not _loop_end.visible:
		_settings.open()


## Zona segura (muescas, barra de gestos): los paneles de arriba y abajo se apartan.
func _apply_safe_area() -> void:
	var window := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if window.x <= 0 or window.y <= 0 or safe.size.x <= 0 or safe.size.y <= 0:
		return
	var scale_y := size.y / float(window.y)
	var top_inset := maxf(0.0, safe.position.y * scale_y)
	var bottom_inset := maxf(0.0, (window.y - safe.end.y) * scale_y)
	_top.add_theme_stylebox_override("panel", _panel_with_margin(_top, "content_margin_top", TOP_MARGIN + top_inset))
	_bottom.add_theme_stylebox_override("panel", _panel_with_margin(_bottom, "content_margin_bottom", BOTTOM_MARGIN + bottom_inset))


func _panel_with_margin(panel: PanelContainer, property: String, value: float) -> StyleBox:
	var style: StyleBox = panel.get_theme_stylebox("panel").duplicate()
	style.set(property, value)
	return style


## El tamaño de letra elegido, en el tema del proyecto (assets/ui/theme.tres).
func _apply_text_size() -> void:
	var project_theme := ThemeDB.get_project_theme()
	if project_theme != null:
		UiStyle.apply_text_size(project_theme, GameState.data.text_sizes[GameState.settings["text_size"]])
