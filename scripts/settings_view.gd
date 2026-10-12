extends PanelContainer
## Ajustes mínimos: movimiento reducido, tres tamaños de texto y reiniciar la
## partida (con confirmación).

@onready var _title: Label = %Title
@onready var _motion: CheckButton = %Motion
@onready var _motion_help: Label = %MotionHelp
@onready var _text_title: Label = %TextTitle
@onready var _sizes: HBoxContainer = %Sizes
@onready var _restart: Button = %Restart
@onready var _confirm: VBoxContainer = %Confirm
@onready var _confirm_text: Label = %ConfirmText
@onready var _confirm_yes: Button = %ConfirmYes
@onready var _confirm_no: Button = %ConfirmNo
@onready var _close: Button = %Close


func _ready() -> void:
	_close.pressed.connect(hide)
	_motion.toggled.connect(GameState.set_reduced_motion)
	_restart.pressed.connect(_confirm.show)
	_confirm_no.pressed.connect(_confirm.hide)
	_confirm_yes.pressed.connect(func() -> void:
		GameState.restart_game()
		hide())
	GameState.settings_changed.connect(func() -> void:
		if visible:
			_render())


func open() -> void:
	_confirm.hide()
	show()
	_render()


func _render() -> void:
	var data := GameState.data
	_title.text = data.text("ajustes_titulo")
	_motion.text = data.text("ajustes_movimiento")
	_motion.set_pressed_no_signal(GameState.settings["reduced_motion"])
	_motion_help.text = data.text("ajustes_movimiento_ayuda")
	_text_title.text = data.text("ajustes_texto")
	_restart.text = data.text("ajustes_reiniciar")
	_confirm_text.text = data.text("confirmar_reinicio")
	_confirm_yes.text = data.text("confirmar_si")
	_confirm_no.text = data.text("confirmar_no")
	_close.text = data.text("cerrar")
	for child: Node in _sizes.get_children():
		child.queue_free()
	for i: int in data.text_sizes.size():
		var button := Button.new()
		button.text = data.text_sizes[i]["name"]
		button.custom_minimum_size = Vector2(0, 120)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.theme_type_variation = &"TabActive" if i == GameState.settings["text_size"] else &""
		button.pressed.connect(GameState.set_text_size.bind(i))
		_sizes.add_child(button)
