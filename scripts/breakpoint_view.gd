extends PanelContainer
## Momento de quiebre (data/events.json, "breakpoints") a pantalla completa,
## sin cambiar de escena. Se sostiene con scripts/sustain_controller.gd:
## mantener pulsado o tocar para empezar y para soltar, con 20 o 40 segundos o
## sin tiempo. La primera vez se elige el modo y el tiempo (se cambian en
## Ajustes). Nada exige reflejos: si la app pierde el foco, el tiempo se para.
## La partida solo recibe la decisión final ("sostuvo" o "soltó") como la
## interacción del quiebre, que cuesta 30 minutos (GameState.resolve_breakpoint()).

const ArtLibrary := preload("res://scripts/art_library.gd")
const SaveManager := preload("res://scripts/save_manager.gd")
const SustainController := preload("res://scripts/sustain_controller.gd")
const UiMotion := preload("res://scripts/ui_motion.gd")
## A partir de aquí se dice la frase de «ya casi».
const NEAR_END: float = 0.75

signal closed

@onready var _title: Label = %Title
@onready var _intro: Label = %Intro
@onready var _option: Label = %Option
@onready var _ring: Control = %Ring
@onready var _hint: Label = %Hint
@onready var _hands: Control = %Hands
@onready var _controls: VBoxContainer = %Controls
@onready var _sustain: Button = %Sustain
@onready var _let_go: Button = %LetGo
@onready var _later: Button = %Later
@onready var _done: VBoxContainer = %Done
@onready var _done_text: Label = %DoneText
@onready var _done_continue: Button = %DoneContinue
@onready var _choice: VBoxContainer = %Choice
@onready var _choice_title: Label = %ChoiceTitle
@onready var _choice_help: Label = %ChoiceHelp
@onready var _mode_title: Label = %ModeTitle
@onready var _modes: VBoxContainer = %Modes
@onready var _time_title: Label = %TimeTitle
@onready var _times: HBoxContainer = %Times
@onready var _choice_ok: Button = %ChoiceOk

## La interacción del quiebre que se está decidiendo ({} si no hay).
var action: Dictionary = {}
var controller: SustainController
var _breakpoint: Dictionary = {}
var _hint_key: String = ""
var _next_pulse_ms: int = 0


func _ready() -> void:
	set_process(false)
	_sustain.button_down.connect(func() -> void: _input_press(true))
	_sustain.button_up.connect(func() -> void: _input_press(false))
	_sustain.pressed.connect(_on_sustain_pressed)
	_let_go.pressed.connect(func() -> void:
		if controller != null:
			controller.let_go()
			_after_input())
	_later.pressed.connect(_close)
	_done_continue.pressed.connect(_resolve)
	_choice_ok.pressed.connect(func() -> void:
		GameState.set_breakpoint_chosen(true)
		_begin())


func bind(art: ArtLibrary) -> void:
	_hands.bind(art)


## Abre el quiebre de la interacción `breakpoint_action` (de GameState.breakpoint_actions()).
func open(breakpoint_action: Dictionary) -> void:
	var data := GameState.data
	action = breakpoint_action
	_breakpoint = data.breakpoints[data.breakpoint_by_interaction[action["id"]]]
	_title.text = data.text("quiebre_titulo")
	_intro.text = _breakpoint["intro"]
	_option.text = data.interactions[action["id"]]["label"]
	_hands.show_hands(GameState.active_actor(), "grip", 0.0)
	UiMotion.fade_in(self, GameState.settings["reduced_motion"])
	if not GameState.settings["breakpoint_chosen"]:
		_show_choice()
	else:
		_begin()


func is_open() -> bool:
	return visible and not action.is_empty()


## Botón «atrás»: antes de empezar es «ahora no»; ya decidido, continuar; a
## mitad, solo para el tiempo (soltar es una decisión, se hace con su botón).
func back() -> void:
	if _choice.visible or controller == null or controller.state == "idle":
		_close()
	elif controller.state == "done":
		_resolve()
	else:
		controller.pause()
		controller.resume()
		_after_input()


## Tiempo del reloj, para el controlador (milisegundos).
static func now_ms() -> int:
	return Time.get_ticks_msec()


func _begin() -> void:
	var data := GameState.data
	_choice.hide()
	_done.hide()
	_controls.show()
	for part: Control in [_ring, _hint, _hands]:
		part.show()
	var time: String = GameState.settings["breakpoint_time"]
	var milliseconds: int = 0 if time == "none" else int(time) * 1000
	controller = SustainController.new(GameState.settings["breakpoint_mode"], milliseconds, now_ms)
	_let_go.text = data.text("quiebre_soltar")
	_later.text = data.text("quiebre_ahora_no")
	_hint_key = ""
	set_process(true)
	_after_input()


func _show_choice() -> void:
	var data := GameState.data
	_controls.hide()
	_done.hide()
	_choice.show()
	for part: Control in [_ring, _hint, _hands]:
		part.hide()
	_choice_title.text = data.text("quiebre_elegir_titulo")
	_choice_help.text = data.text("quiebre_elegir_ayuda")
	_mode_title.text = data.text("ajustes_modo")
	_time_title.text = data.text("ajustes_tiempo")
	_choice_ok.text = data.text("quiebre_elegir_ok")
	_fill_choices()


func _fill_choices() -> void:
	var data := GameState.data
	for child: Node in _modes.get_children() + _times.get_children():
		child.queue_free()
	for mode: String in SaveManager.BREAKPOINT_MODES:
		_modes.add_child(_choice_button(data.text("modo_" + mode), GameState.settings["breakpoint_mode"] == mode,
				func() -> void:
					GameState.set_breakpoint_mode(mode)
					_fill_choices()))
	for time: String in SaveManager.BREAKPOINT_TIMES:
		_times.add_child(_choice_button(data.text("tiempo_" + time), GameState.settings["breakpoint_time"] == time,
				func() -> void:
					GameState.set_breakpoint_time(time)
					_fill_choices()))


func _choice_button(text: String, active: bool, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 120)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.theme_type_variation = &"TabActive" if active else &""
	button.pressed.connect(on_pressed)
	return button


func _process(_delta: float) -> void:
	if controller == null:
		return
	controller.update()
	if controller.state == "holding":
		var now := now_ms()
		if now >= _next_pulse_ms:
			Haptics.play("sustain_pulse")
			_next_pulse_ms = now + Haptics.sustain_interval_ms(controller.progress())
	_ring.set_state(controller.progress(), controller.is_timed())
	_update_texts()
	if controller.state == "done":
		_finish()


func _input_press(down: bool) -> void:
	if controller == null or controller.mode != "hold" or not controller.is_timed():
		return
	if down:
		controller.press()
	else:
		controller.release()
	_after_input()


func _on_sustain_pressed() -> void:
	if controller == null:
		return
	if not controller.is_timed():
		controller.confirm()
	elif controller.mode == "toggle":
		controller.tap()
	_after_input()


func _after_input() -> void:
	if controller == null:
		return
	AudioDirector.set_sustaining(controller.state == "holding")
	if controller.state == "holding":
		_next_pulse_ms = 0
	_later.visible = controller.state == "idle"
	_ring.set_state(controller.progress(), controller.is_timed())
	_update_texts()
	if controller.state == "done":
		_finish()


## Textos de ayuda: solo se reescriben cuando cambian (nada nuevo por fotograma).
func _update_texts() -> void:
	var data := GameState.data
	var key: String
	match controller.state:
		"holding":
			key = "near_end" if controller.progress() >= NEAR_END else "holding"
		"paused", "resuming":
			key = "quiebre_pausa"
		_:
			if not controller.is_timed():
				key = "quiebre_sin_tiempo"
			else:
				key = "quiebre_mantener" if controller.mode == "hold" else "quiebre_tocar"
	if key == _hint_key:
		return
	_hint_key = key
	_hint.text = _breakpoint[key] if key in ["holding", "near_end"] else data.text(key)
	if not controller.is_timed():
		_sustain.text = data.text("quiebre_confirmar")
	else:
		_sustain.text = data.text("quiebre_sostener")


func _finish() -> void:
	var data := GameState.data
	set_process(false)
	AudioDirector.set_sustaining(false)
	var sustained := controller.result == SustainController.SUSTAINED
	AudioDirector.play_event("sustain_success" if sustained else "let_go")
	Haptics.play("success" if sustained else "let_go")
	_controls.hide()
	_done.show()
	_done_text.text = data.text("quiebre_sostuvo" if sustained else "quiebre_solto")
	_done_continue.text = data.text("quiebre_continuar")


func _resolve() -> void:
	if controller == null or controller.state != "done":
		return
	var decided := action
	var decision := controller.result
	_close()
	GameState.resolve_breakpoint(decided, decision)


func _close() -> void:
	set_process(false)
	AudioDirector.set_sustaining(false)
	controller = null
	action = {}
	hide()
	closed.emit()


## La app pierde el foco (o pasa a segundo plano): el tiempo se para y no cuenta como soltar.
func _notification(what: int) -> void:
	if controller == null:
		return
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			controller.pause()
			_after_input()
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED:
			controller.resume()
			_after_input()
