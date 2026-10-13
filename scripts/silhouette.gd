extends Control
## Silueta de una persona, opcionalmente sobre un disco claro (para que se lea
## de día y de noche en la UI; en la escena va sin disco). Velo 0: negra con su
## rasgo fijo. Velo 1: con los colores de npcs.json. Los niveles 2 y 3 (rostro
## y retrato) los dibuja scripts/portrait_view.gd.

const GameData := preload("res://scripts/game_data.gd")
const BLACK := Color(0.07, 0.07, 0.08)

@onready var _plate: Panel = $Plate
@onready var _texture: TextureRect = $Texture

var _data: GameData
var _person: String = ""
var _velo_level: int = 0
var _plate_visible: bool = true


func _ready() -> void:
	if _person != "":
		_apply()


## Se puede llamar antes de añadirla al árbol: se aplica al entrar.
func show_person(data: GameData, person_id: String, velo_level: int, with_plate: bool = true) -> void:
	_data = data
	_person = person_id
	_velo_level = velo_level
	_plate_visible = with_plate
	if is_node_ready():
		_apply()


func _apply() -> void:
	var person: Dictionary = _data.people[_person]
	var path: String = person["silhouette_path"]
	_texture.texture = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_plate.visible = _plate_visible
	var inset := 6.0 if _plate_visible else 0.0
	_texture.offset_left = inset
	_texture.offset_top = inset
	_texture.offset_right = -inset
	_texture.offset_bottom = -inset
	var tinted: bool = _velo_level >= 1 and not person["protagonist"]
	var material := _texture.material as ShaderMaterial
	material.set_shader_parameter("body_color", person["colors"]["body"] if tinted else BLACK)
	material.set_shader_parameter("trait_color", person["colors"]["trait"] if tinted else BLACK)
