extends Button
## Botón del selector de protagonista: icono (sol o luna), nombre y estado.
## Sazil y Akba se distinguen por icono y por forma (esquinas redondas o en
## chaflán), no solo por color.

signal chosen(actor: String)

@onready var _icon: Control = %Icon
@onready var _name: Label = %NameLabel
@onready var _status: Label = %StatusLabel

var actor: String = ""


func _ready() -> void:
	pressed.connect(func() -> void: chosen.emit(actor))


func setup(actor_id: String) -> void:
	actor = actor_id


## `active`: está controlado ahora. `enabled`: se puede cambiar a él.
func refresh(active: bool, status: String, enabled: bool) -> void:
	var person: Dictionary = GameState.data.people[actor]
	var base := "Sazil" if person["icon"] == "sol" else "Akba"
	theme_type_variation = StringName(base + ("ButtonActive" if active else "Button"))
	disabled = not enabled
	var ink: Color = GameState.data.ink_dark if person["icon"] == "sol" else GameState.data.ink_light
	for label: Label in [_name, _status]:
		label.add_theme_color_override("font_color", ink)
	_name.text = person["name"]
	_status.text = status
	var background: Color = get_theme_stylebox("normal").get("bg_color")
	_icon.set_icon(person["icon"], person["colors"]["body"] if person["icon"] == "sol" else person["colors"]["body"].lightened(0.45), background)
