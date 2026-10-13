extends Control
## La cara de alguien según lo que se sabe de él (el Velo):
## - Velo 0 y 1: su silueta (negra, o con sus colores en el 1).
## - Velo 2, Rostro: `npc_<id>_velo2` (cara neutra).
## - Velo 3, Retrato: `npc_<id>_velo3` (retrato completo, con crédito en el Cuaderno).
## Mientras no haya arte (lo dibujará la comunidad), se dibuja una cara plana en
## los colores de la persona, con su rasgo fijo y la etiqueta «PROVISIONAL».
## Sazil y Akba enseñan su retrato de verdad (el del selector), recortado a la cara.

const GameData := preload("res://scripts/game_data.gd")
const ArtLibrary := preload("res://scripts/art_library.gd")
const SILHOUETTE_SCENE := preload("res://scenes/silhouette.tscn")

const SKIN := Color("e8c7ad")
const INK := Color("2b2418")
const LABEL_SIZE: int = 18

## Qué se está enseñando: "portrait", "art", "placeholder" o "silhouette" (para los tests).
var mode: String = ""

var _picture: TextureRect
var _silhouette: Control
var _drawn_level: int = 0
var _colors: Dictionary = {}
var _label: String = ""
## show_person() antes de entrar en el árbol: se aplica en _ready().
var _pending: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_picture = TextureRect.new()
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_picture.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_picture)
	_silhouette = SILHOUETTE_SCENE.instantiate()
	_silhouette.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_silhouette)
	resized.connect(queue_redraw)
	if not _pending.is_empty():
		callv("show_person", _pending)
		_pending = []


func show_person(data: GameData, art: ArtLibrary, person: String, level: int) -> void:
	if _picture == null:
		_pending = [data, art, person, level]
		return
	_drawn_level = 0
	_picture.hide()
	_silhouette.hide()
	var info: Dictionary = data.people[person]
	if info["protagonist"]:
		var slot := ArtLibrary.portrait_slot(person, "idle")
		var texture := art.small_texture(slot) if art != null else null
		if texture != null:
			var face := AtlasTexture.new()
			face.atlas = texture
			face.region = art.focus_region(slot, texture)
			_picture.texture = face
			_picture.show()
			mode = "portrait"
		else:
			_show_silhouette(data, person, level)
	elif level >= 2:
		var texture := art.small_texture(ArtLibrary.face_slot(person, mini(level, 3))) if art != null else null
		if texture != null:
			_picture.texture = texture
			_picture.show()
			mode = "art"
		else:
			_drawn_level = mini(level, 3)
			_colors = info["colors"]
			_label = data.text("arte_provisional")
			mode = "placeholder"
	else:
		_show_silhouette(data, person, level)
	queue_redraw()


func _show_silhouette(data: GameData, person: String, level: int) -> void:
	_silhouette.show()
	_silhouette.show_person(data, person, level)
	mode = "silhouette"


## Cara provisional: plana, en sus colores, con su rasgo fijo como acento.
func _draw() -> void:
	if _drawn_level < 2:
		return
	var body: Color = _colors["body"]
	var accent: Color = _colors["trait"]
	var side := minf(size.x, size.y)
	var center := Vector2(size.x * 0.5, size.y * 0.45)
	draw_circle(size * 0.5, side * 0.5, body.lightened(0.6))
	if _drawn_level >= 3:
		# Retrato: hombros, y un marco con el color de su rasgo.
		draw_circle(Vector2(size.x * 0.5, size.y * 1.05), side * 0.42, body)
		draw_arc(size * 0.5, side * 0.48, 0.0, TAU, 64, accent, side * 0.04, true)
	draw_circle(center + Vector2(0, -side * 0.05), side * 0.27, body.darkened(0.35))
	draw_circle(center, side * 0.22, SKIN)
	draw_circle(center + Vector2(-side * 0.08, -side * 0.02), side * 0.022, INK)
	draw_circle(center + Vector2(side * 0.08, -side * 0.02), side * 0.022, INK)
	draw_line(center + Vector2(-side * 0.06, side * 0.1), center + Vector2(side * 0.06, side * 0.1), INK, maxf(side * 0.012, 1.5))
	draw_circle(center + Vector2(side * 0.2, -side * 0.18), side * 0.07, accent)
	var font := get_theme_default_font()
	var width := font.get_string_size(_label, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE).x
	draw_string(font, Vector2((size.x - width) * 0.5, size.y - 6), _label, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, Color(INK, 0.55))
