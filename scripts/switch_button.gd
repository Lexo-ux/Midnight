extends Button
## Botón del selector de protagonista: retrato (recorte de la cara), nombre,
## estado e icono (sol o luna). Sazil y Akba se distinguen por icono y por forma
## (esquinas redondas o en chaflán), no solo por color.
##
## Mientras se mantiene pulsado, el retrato pasa a `portrait_hand_raised` (la
## persona levanta la mano). El cambio se hace al soltar DENTRO del botón; si
## el dedo sale, se cancela. Sin arte, el retrato es la silueta sobre su placa.

signal chosen(actor: String)

const GameStateScript := preload("res://scripts/game_state.gd")
const ArtLibrary := preload("res://scripts/art_library.gd")

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
	var ink: Color = data.ink_dark if person["icon"] == "sol" else data.ink_light
	for label: Label in [_name, _status]:
		label.add_theme_color_override("font_color", ink)
	_name.text = person["name"]
	_status.text = status
	var background: Color = get_theme_stylebox("normal").get("bg_color")
	_icon.set_icon(person["icon"], person["colors"]["body"] if person["icon"] == "sol" else person["colors"]["body"].lightened(0.45), background)
	var plate := StyleBoxFlat.new()
	plate.bg_color = person["colors"]["body"].lightened(0.55)
	plate.border_color = person["colors"]["body"].darkened(0.3)
	plate.set_border_width_all(4)
	plate.set_corner_radius_all(999 if person["icon"] == "sol" else 34)
	plate.corner_detail = 16 if person["icon"] == "sol" else 1
	_frame.add_theme_stylebox_override("panel", plate)
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
