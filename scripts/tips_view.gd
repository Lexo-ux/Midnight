extends Control
## Los tres consejos de la primera partida (ui_text.json, consejo_1..3). Salen
## una vez; al terminarlos o saltarlos queda apuntado en los ajustes de la
## partida (tips_seen) y se pueden volver a ver desde Ajustes.

const UiMotion := preload("res://scripts/ui_motion.gd")
const COUNT: int = 3

signal closed

@onready var _page: Label = %Page
@onready var _tip_title: Label = %TipTitle
@onready var _tip_text: Label = %TipText
@onready var _skip: Button = %Skip
@onready var _next: Button = %Next

var index: int = 0


func _ready() -> void:
	_skip.pressed.connect(close)
	_next.pressed.connect(func() -> void:
		if index < COUNT - 1:
			index += 1
			_render()
		else:
			close())


func open() -> void:
	index = 0
	UiMotion.fade_in(self, GameState.settings["reduced_motion"])
	_render()


func close() -> void:
	hide()
	GameState.set_tips_seen(true)
	closed.emit()


func _render() -> void:
	var data := GameState.data
	var n := index + 1
	_page.text = "%d / %d" % [n, COUNT]
	_tip_title.text = data.text("consejo_%d_titulo" % n)
	_tip_text.text = data.text("consejo_%d" % n)
	_skip.text = data.text("consejo_saltar")
	_skip.visible = index < COUNT - 1
	_next.text = data.text("consejo_siguiente" if index < COUNT - 1 else "consejo_empezar")
