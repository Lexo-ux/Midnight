extends PanelContainer
## Ajustes: movimiento reducido, tamaño del texto, sonido (volumen por bus y
## silenciar todo), vibración, cómo sostener en los momentos de quiebre (modo y
## tiempo), volver a ver los consejos y reiniciar la partida (con confirmación).

const SaveManager := preload("res://scripts/save_manager.gd")
const UiMotion := preload("res://scripts/ui_motion.gd")
const UiStyle := preload("res://scripts/ui_style.gd")

signal tips_requested

@onready var _title: Label = %Title
@onready var _motion: CheckButton = %Motion
@onready var _motion_help: Label = %MotionHelp
@onready var _text_title: Label = %TextTitle
@onready var _sizes: HBoxContainer = %Sizes
@onready var _sound_title: Label = %SoundTitle
@onready var _volumes: VBoxContainer = %Volumes
@onready var _mute: CheckButton = %Mute
@onready var _haptics_title: Label = %HapticsTitle
@onready var _haptic_levels: HBoxContainer = %HapticLevels
@onready var _break_title: Label = %BreakTitle
@onready var _mode_title: Label = %ModeTitle
@onready var _modes: VBoxContainer = %Modes
@onready var _time_title: Label = %TimeTitle
@onready var _times: HBoxContainer = %Times
@onready var _tips_again: Button = %TipsAgain
@onready var _restart: Button = %Restart
@onready var _confirm: VBoxContainer = %Confirm
@onready var _confirm_text: Label = %ConfirmText
@onready var _confirm_yes: Button = %ConfirmYes
@onready var _confirm_no: Button = %ConfirmNo
@onready var _close: Button = %Close

## Deslizadores de volumen ya creados: clave del ajuste -> HSlider.
var _sliders: Dictionary = {}


func _ready() -> void:
	_close.pressed.connect(hide)
	_motion.toggled.connect(GameState.set_reduced_motion)
	_mute.toggled.connect(GameState.set_mute)
	_restart.pressed.connect(_confirm.show)
	_confirm_no.pressed.connect(_confirm.hide)
	_confirm_yes.pressed.connect(func() -> void:
		GameState.restart_game()
		hide())
	_tips_again.pressed.connect(func() -> void:
		hide()
		GameState.set_tips_seen(false)
		tips_requested.emit())
	GameState.settings_changed.connect(func() -> void:
		if visible:
			_render())


func open() -> void:
	_confirm.hide()
	UiMotion.fade_in(self, GameState.settings["reduced_motion"])
	_render()


func _render() -> void:
	var data := GameState.data
	var settings := GameState.settings
	_title.text = data.text("ajustes_titulo")
	_motion.text = data.text("ajustes_movimiento")
	_motion.set_pressed_no_signal(settings["reduced_motion"])
	_motion_help.text = data.text("ajustes_movimiento_ayuda")
	_text_title.text = data.text("ajustes_texto")
	_sound_title.text = data.text("ajustes_sonido")
	_mute.text = data.text("ajustes_silencio")
	_mute.set_pressed_no_signal(settings["mute"])
	_haptics_title.text = data.text("ajustes_vibracion")
	_break_title.text = data.text("ajustes_quiebres")
	_mode_title.text = data.text("ajustes_modo")
	_time_title.text = data.text("ajustes_tiempo")
	_tips_again.text = data.text("ajustes_consejos")
	_restart.text = data.text("ajustes_reiniciar")
	_confirm_text.text = data.text("confirmar_reinicio")
	_confirm_yes.text = data.text("confirmar_si")
	_confirm_no.text = data.text("confirmar_no")
	_close.text = data.text("cerrar")
	_render_volumes()
	var sizes: Array[Dictionary] = []
	for i: int in data.text_sizes.size():
		sizes.append({"text": data.text_sizes[i]["name"], "active": i == settings["text_size"],
				"action": GameState.set_text_size.bind(i)})
	_fill(_sizes, sizes)
	var haptics: Array[Dictionary] = []
	for level: String in SaveManager.HAPTIC_LEVELS:
		haptics.append({"text": data.text("vibracion_" + level), "active": settings["haptics"] == level,
				"action": GameState.set_haptics.bind(level)})
	_fill(_haptic_levels, haptics)
	var modes: Array[Dictionary] = []
	for mode: String in SaveManager.BREAKPOINT_MODES:
		modes.append({"text": data.text("modo_" + mode), "active": settings["breakpoint_mode"] == mode,
				"action": GameState.set_breakpoint_mode.bind(mode)})
	_fill(_modes, modes)
	var times: Array[Dictionary] = []
	for time: String in SaveManager.BREAKPOINT_TIMES:
		times.append({"text": data.text("tiempo_" + time), "active": settings["breakpoint_time"] == time,
				"action": GameState.set_breakpoint_time.bind(time)})
	_fill(_times, times)


## Un deslizador por bus; se crean una vez y luego solo se actualiza su valor.
func _render_volumes() -> void:
	var data := GameState.data
	if _sliders.is_empty():
		for key: String in SaveManager.VOLUME_KEYS:
			var label := Label.new()
			label.theme_type_variation = &"PaperLabel"
			label.text = data.text("volumen_" + key.trim_prefix("volume_"))
			_volumes.add_child(label)
			var slider := HSlider.new()
			slider.min_value = 0.0
			slider.max_value = 1.0
			slider.step = 0.05
			slider.custom_minimum_size = Vector2(UiStyle.MIN_TOUCH, UiStyle.MIN_TOUCH)
			slider.value_changed.connect(func(value: float) -> void: GameState.set_volume(key, value))
			_volumes.add_child(slider)
			_sliders[key] = slider
	for key: String in _sliders:
		(_sliders[key] as HSlider).set_value_no_signal(GameState.settings[key])


## Botones de opción (el elegido resaltado).
func _fill(box: Container, options: Array[Dictionary]) -> void:
	_clear(box)
	for option: Dictionary in options:
		var button := Button.new()
		button.text = option["text"]
		UiStyle.touch(button, &"Selected" if option["active"] else &"")
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(option["action"])
		box.add_child(button)


## Quita los hijos ya (no al final del fotograma), para redibujar sin restos.
func _clear(box: Node) -> void:
	for child: Node in box.get_children():
		box.remove_child(child)
		child.queue_free()
