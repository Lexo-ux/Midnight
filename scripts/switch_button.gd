extends Button
## Botón del selector de protagonista: retrato (recorte de la cara), nombre,
## estado e icono (sol o luna). Sazil y Akba se distinguen por icono y por forma
## (esquinas redondas o en chaflán), no solo por color.
##
## Mientras se mantiene pulsado, el retrato pasa a `portrait_hand_raised` (la
## persona levanta la mano) y la placa sube y crece un poco (≤ 250 ms; sin
## animación con movimiento reducido). El cambio se hace al soltar DENTRO del
## botón; si el dedo sale, se cancela. Sin arte, el retrato es la silueta sobre
## su placa.

signal chosen(actor: String)

const GameStateScript := preload("res://scripts/game_state.gd")
const ArtLibrary := preload("res://scripts/art_library.gd")
const UiStyle := preload("res://scripts/ui_style.gd")
const RAISE_SCALE: float = 1.12
const RAISE_PIXELS: float = 14.0
const RAISE_SECONDS: float = 0.15

@onready var _frame: Panel = %Frame
@onready var _portrait: TextureRect = %Portrait
@onready var _silhouette: Control = %Silhouette
@onready var _icon: Control = %Icon
@onready var _name: Label = %NameLabel
@onready var _status: Label = %StatusLabel

var actor: String = ""
var _state: GameStateScript
var _art: ArtLibrary
var _raised: bool = false
var _raise_tween: Tween


func _ready() -> void:
	pressed.connect(func() -> void: chosen.emit(actor))
	button_down.connect(_set_raised.bind(true))
	button_up.connect(_set_raised.bind(false))
	mouse_exited.connect(_set_raised.bind(false))


func setup(state: GameStateScript, art: ArtLibrary, actor_id: String) -> void:
	_state = state
	_art = art
	actor = actor_id


## `active`: está controlado ahora. `enabled`: se puede cambiar a él.
func refresh(active: bool, status: String, enabled: bool) -> void:
	var data := _state.data
	var person: Dictionary = data.people[actor]
	var base := "Sazil" if person["icon"] == "sol" else "Akba"
	theme_type_variation = StringName(base + ("ButtonActive" if active else "Button"))
	disabled = not enabled
	var sun: bool = person["icon"] == "sol"
	_name.theme_type_variation = &"SwitchNameDark" if sun else &"SwitchName"
	_status.theme_type_variation = &"SwitchStatusDark" if sun else &"SwitchStatus"
	_frame.theme_type_variation = &"PlateRound" if sun else &"PlateChamfer"
	_name.text = person["name"]
	_status.text = status
	var background: Color = get_theme_stylebox("normal").get("bg_color")
	_icon.set_icon(person["icon"], UiStyle.INK if sun else UiStyle.NEON_GREEN, background)
	_show_portrait()


## Qué retrato se ve ahora ("idle" o "hand_raised"; para los tests).
func pose() -> String:
	return "hand_raised" if _raised else "idle"


func _set_raised(raised: bool) -> void:
	if raised and disabled:
		return
	if raised == _raised:
		return
	_raised = raised
	_show_portrait()
	_animate_raise()


## La placa del retrato sube al levantar la mano y vuelve al soltar.
func _animate_raise() -> void:
	if _raise_tween != null and _raise_tween.is_valid():
		_raise_tween.kill()
	_frame.pivot_offset = Vector2(_frame.size.x * 0.5, _frame.size.y)
	var target_scale := Vector2.ONE * (RAISE_SCALE if _raised else 1.0)
	var target_y := -RAISE_PIXELS if _raised else 0.0
	var reduced: bool = _state != null and _state.settings["reduced_motion"]
	if reduced or not is_inside_tree():
		_frame.scale = target_scale
		_frame.position.y = _frame_rest_y() + target_y
		return
	_raise_tween = create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_raise_tween.tween_property(_frame, "scale", target_scale, RAISE_SECONDS)
	_raise_tween.tween_property(_frame, "position:y", _frame_rest_y() + target_y, RAISE_SECONDS)


## Dónde queda la placa en reposo (centrada en la fila).
func _frame_rest_y() -> float:
	return (_frame.get_parent_control().size.y - _frame.size.y) * 0.5


func _show_portrait() -> void:
	if _state == null:
		return
	var slot := ArtLibrary.portrait_slot(actor, pose())
	var texture := _art.small_texture(slot) if _art != null else null
	if texture != null:
		var face := AtlasTexture.new()
		face.atlas = texture
		face.region = _art.focus_region(slot, texture)
		_portrait.texture = face
		_portrait.show()
		_silhouette.hide()
	else:
		_portrait.hide()
		_silhouette.show()
		_silhouette.show_person(_state.data, actor, 0, false)
		_silhouette.position.y = -12.0 if _raised else 0.0
