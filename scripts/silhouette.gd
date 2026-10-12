extends Control
## Silueta de una persona sobre un disco claro (para que se lea de día y de
## noche). Velo 0: negra con su rasgo fijo. Velo 1: con los colores de npcs.json.
## Los niveles 2 y 3 (rostro y retrato) llegarán con las conversaciones: se
## leerán de `velo.face_path` / `velo.portrait_path` en los datos.

const BLACK := Color(0.07, 0.07, 0.08)

@onready var _texture: TextureRect = $Texture

var _person: String = ""
var _velo_level: int = 0


func _ready() -> void:
	if _person != "":
		_apply()


## Se puede llamar antes de añadirla al árbol: se aplica al entrar.
func show_person(person_id: String, velo_level: int) -> void:
	_person = person_id
	_velo_level = velo_level
	if is_node_ready():
		_apply()


func _apply() -> void:
	var person: Dictionary = GameState.data.people[_person]
	var path: String = person["silhouette_path"]
	_texture.texture = load(path) as Texture2D if ResourceLoader.exists(path) else null
	var tinted: bool = _velo_level >= 1 and not person["protagonist"]
	var material := _texture.material as ShaderMaterial
	material.set_shader_parameter("body_color", person["colors"]["body"] if tinted else BLACK)
	material.set_shader_parameter("trait_color", person["colors"]["trait"] if tinted else BLACK)
