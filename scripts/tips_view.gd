extends Control
## Los tres consejos de la primera partida (ui_text.json, consejo_1..3), cada
## uno señalando lo que explica: el selector Sazil/Akba, el Cuaderno y Tiempo
## (los da main.gd con set_targets()). Se oscurece todo menos eso, que queda
## enmarcado en amarillo, y la hoja va a la otra mitad de la pantalla para no
## taparlo. Salen una vez; al terminarlos o saltarlos queda apuntado en los
## ajustes de la partida (tips_seen) y se pueden volver a ver desde Ajustes.

const UiMotion := preload("res://scripts/ui_motion.gd")
const UiStyle := preload("res://scripts/ui_style.gd")
const COUNT: int = 3
const DIM := Color(0, 0, 0, 0.62)
const SHEET_HEIGHT: float = 820.0
const MARGIN: float = 24.0
## Bajo la zona de la hora (la hoja de arriba no tapa el reloj).
const TOP_CLEARANCE: float = 160.0
const RING_GROW: float = 14.0

signal closed

@onready var _spotlight: Control = %Spotlight
@onready var _sheet: PanelContainer = %Sheet
@onready var _page: Label = %Page
@onready var _tip_title: Label = %TipTitle
@onready var _tip_text: Label = %TipText
@onready var _skip: Button = %Skip
@onready var _next: Button = %Next

var index: int = 0
var _targets: Array[Control] = []
## Rectángulo enmarcado (en coordenadas de esta vista; vacío = ninguno).
var _hole: Rect2 = Rect2()


func _ready() -> void:
	_skip.pressed.connect(close)
	_next.pressed.connect(func() -> void:
		if index < COUNT - 1:
			index += 1
			_render()
		else:
			close())
	_spotlight.draw.connect(_draw_spotlight)
	resized.connect(func() -> void:
		if visible:
			_render())


## Lo que señala cada consejo, en orden (puede faltar alguno).
func set_targets(targets: Array) -> void:
	_targets.clear()
	for target: Variant in targets:
		_targets.append(target as Control)


func open() -> void:
	index = 0
	UiMotion.fade_in(self, GameState.settings["reduced_motion"])
	_render()
	# Al abrir con la partida, la cabecera aún no tiene su tamaño final.
	_render.call_deferred()


func close() -> void:
	hide()
	GameState.set_tips_seen(true)
	closed.emit()


## El rectángulo que señala el consejo actual (para los tests).
func target_rect() -> Rect2:
	return _hole


func _render() -> void:
	var data := GameState.data
	var n := index + 1
	_page.text = "%d / %d" % [n, COUNT]
	_tip_title.text = data.text("consejo_%d_titulo" % n)
	_tip_text.text = data.text("consejo_%d" % n)
	_skip.text = data.text("consejo_saltar")
	_skip.visible = index < COUNT - 1
	_next.text = data.text("consejo_siguiente" if index < COUNT - 1 else "consejo_empezar")
	_hole = Rect2()
	var target: Control = _targets[index] if index < _targets.size() else null
	if target != null and target.is_visible_in_tree():
		_hole = Rect2(target.global_position - global_position, target.size * target.get_global_transform().get_scale()).grow(RING_GROW)
	# La hoja, en la mitad contraria a lo que señala.
	var at_top := _hole.has_area() and _hole.get_center().y > size.y * 0.5
	if at_top:
		_sheet.anchor_top = 0.0
		_sheet.anchor_bottom = 0.0
		_sheet.offset_top = TOP_CLEARANCE
		_sheet.offset_bottom = TOP_CLEARANCE + SHEET_HEIGHT
	else:
		_sheet.anchor_top = 1.0
		_sheet.anchor_bottom = 1.0
		_sheet.offset_top = -SHEET_HEIGHT - MARGIN
		_sheet.offset_bottom = -MARGIN
	_spotlight.queue_redraw()


## Todo oscuro menos el hueco, que lleva un marco amarillo con contorno negro.
func _draw_spotlight() -> void:
	var full := Rect2(Vector2.ZERO, size)
	if not _hole.has_area():
		_spotlight.draw_rect(full, DIM)
		return
	var hole := _hole.intersection(full)
	_spotlight.draw_rect(Rect2(0, 0, size.x, hole.position.y), DIM)
	_spotlight.draw_rect(Rect2(0, hole.end.y, size.x, size.y - hole.end.y), DIM)
	_spotlight.draw_rect(Rect2(0, hole.position.y, hole.position.x, hole.size.y), DIM)
	_spotlight.draw_rect(Rect2(hole.end.x, hole.position.y, size.x - hole.end.x, hole.size.y), DIM)
	_spotlight.draw_rect(hole, UiStyle.INK, false, UiStyle.OUTLINE * 4.0)
	_spotlight.draw_rect(hole, UiStyle.NEON_YELLOW, false, UiStyle.OUTLINE * 2.0)
