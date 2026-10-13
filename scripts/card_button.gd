extends Button
## Una carta de una conversación: icono de su tipo (dibujado, ver conv_icon.gd)
## y título en negrita arriba, el texto debajo. Es un botón entero (≥ 48 dp) y
## crece en alto con su texto, así caben dos por fila sin cortar nada.

const ConvIcon := preload("res://scripts/conv_icon.gd")
const UiStyle := preload("res://scripts/ui_style.gd")
const ICON_SIZE: float = 56.0

var card_type: String = ""
var _box: VBoxContainer
var _title: Label
var _text: Label
var _icon: TextureRect


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	_box = VBoxContainer.new()
	_box.theme_type_variation = &"VBoxTight"
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	var row := HBoxContainer.new()
	row.theme_type_variation = &"HBoxTight"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(row)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_icon)
	_title = Label.new()
	_title.theme_type_variation = &"CardTitle"
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_title)
	_text = Label.new()
	_text.theme_type_variation = &"CardText"
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_text)
	_box.minimum_size_changed.connect(_fit)
	resized.connect(_fit)


func setup(type: String, title: String, text: String) -> void:
	card_type = type
	_icon.texture = ConvIcon.make(type, ICON_SIZE)
	_title.text = title
	_text.text = text
	_text.visible = text != ""
	_fit()


## El contenido ocupa el botón menos sus márgenes, y el botón mide en alto lo
## que pida el contenido con ese ancho (un Button no mide a sus hijos solo).
func _fit() -> void:
	var box := get_theme_stylebox("normal")
	_box.position = Vector2(box.get_margin(SIDE_LEFT), box.get_margin(SIDE_TOP))
	_box.size = Vector2(maxf(0.0, size.x - box.get_margin(SIDE_LEFT) - box.get_margin(SIDE_RIGHT)), 0)
	var height := _box.get_combined_minimum_size().y + box.get_margin(SIDE_TOP) + box.get_margin(SIDE_BOTTOM)
	var wanted := Vector2(UiStyle.MIN_TOUCH, maxf(UiStyle.MIN_TOUCH, ceilf(height)))
	if not wanted.is_equal_approx(custom_minimum_size):
		custom_minimum_size = wanted
