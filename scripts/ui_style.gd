extends RefCounted
## Fichas de diseño de la interfaz y el tema único del juego
## (assets/ui/theme.tres, `gui/theme/custom`). Aspecto «rotulador», como el arte:
## trazo negro grueso, rellenos planos, esquinas apenas redondeadas, base violeta
## e índigo con los neones del arte (rosa, verde, cian, amarillo).
##
## - Todo color, grosor, radio y separación de la interfaz sale de aquí. Las
##   escenas no llevan estilos propios (lo comprueba test_ui_style.gd).
## - El tema se genera con `scripts/dev/make_theme.gd` a partir de build_theme();
##   un test comprueba que el archivo guardado coincide.
## - Los tamaños de letra vienen de data/settings.json (`text_sizes`, tres
##   niveles); apply_text_size() los aplica al tema en marcha.
## - Ningún estado se distingue solo por color: lo elegido lleva borde grueso y
##   base gruesa; lo desactivado pierde el contorno y la sombra.

const THEME_PATH: String = "res://assets/ui/theme.tres"
const UI_DIR: String = "res://assets/ui/"

# --- Paleta ---------------------------------------------------------------------
## Tinta de rotulador (contornos y sombras duras).
const INK := Color("0e0a18")
const NIGHT := Color("171233")
const NIGHT_RAISED := Color("241b4a")
const VIOLET := Color("3d2d78")
const VIOLET_PRESSED := Color("2c2058")
const VIOLET_LIGHT := Color("5a43a8")
const PAPER := Color("f6ecd8")
const PAPER_CARD := Color("eadcc0")
const PAPER_LINE := Color("c9b48f")
const TEXT_LIGHT := Color("f7f3ff")
const TEXT_LIGHT_MUTED := Color("c9c0ea")
const TEXT_DARK := Color("22180f")
const TEXT_DARK_MUTED := Color("5a4a38")
## Neones del arte (letreros de Much y el Umbral).
const NEON_PINK := Color("ff3f8e")
const NEON_GREEN := Color("6dff9c")
const NEON_CYAN := Color("39dcff")
const NEON_YELLOW := Color("ffd23f")
## Fisura del Umbral: verde ácido con el carmesí del colgante de Akba.
const UMBRAL := Color("6dff9c")
const UMBRAL_EDGE := Color("ff3f6a")
## Sazil (ocre, sol) y Akba (índigo, luna) en la interfaz.
const SAZIL_FILL := Color("f3c98b")
const SAZIL_FILL_ACTIVE := Color("ffb44f")
const AKBA_FILL := Color("2c2a6e")
const AKBA_FILL_ACTIVE := Color("4b48b8")
## Carta de Conocimiento (sale del Cuaderno): verde azulado oscuro.
const KNOWLEDGE := Color("1a4f4b")

# --- Medidas --------------------------------------------------------------------
## Píxeles lógicos por dp en el teléfono más estrecho habitual (360 dp de ancho:
## el lienzo siempre mide 1080 px de ancho).
const PX_PER_DP: float = 3.0
## Área táctil mínima: 48 dp.
const MIN_TOUCH: int = 144
## Contorno de rotulador.
const OUTLINE: int = 4
const OUTLINE_HEAVY: int = 7
## Base gruesa de lo elegido (forma, no solo color).
const SELECTED_BASE: int = 14
const RADIUS: int = 16
const RADIUS_LARGE: int = 28
const RADIUS_PILL: int = 72
## Sombra dura bajo botones y hojas.
const SHADOW: int = 6
## Escala de espacios.
const SPACE_XS: int = 8
const SPACE_S: int = 16
const SPACE_M: int = 24
const SPACE_L: int = 32
const SPACE_XL: int = 48
## Contorno del texto que va sobre la escena.
const CAPTION_OUTLINE: int = 12
## Contraste mínimo del texto de cuerpo (WCAG AA).
const MIN_CONTRAST: float = 4.5
## Duración máxima de una transición de la interfaz.
const MOTION_MAX_SECONDS: float = 0.25

## Pares texto/fondo de cuerpo que deben pasar MIN_CONTRAST (los comprueban los tests).
const TEXT_PAIRS: Array[Array] = [
	["NightLabel sobre Night", TEXT_LIGHT, NIGHT],
	["NightMuted sobre Night", TEXT_LIGHT_MUTED, NIGHT],
	["NightMuted sobre NightRaised", TEXT_LIGHT_MUTED, NIGHT_RAISED],
	["PaperLabel sobre Paper", TEXT_DARK, PAPER],
	["PaperMuted sobre Paper", TEXT_DARK_MUTED, PAPER],
	["PaperMuted sobre PaperCard", TEXT_DARK_MUTED, PAPER_CARD],
	["CardText sobre Card", TEXT_LIGHT_MUTED, VIOLET],
	["CardText sobre CardKnowledge", TEXT_LIGHT_MUTED, KNOWLEDGE],
	["Button", TEXT_LIGHT, VIOLET],
	["Button pulsado", TEXT_LIGHT, VIOLET_PRESSED],
	["Primary", INK, NEON_YELLOW],
	["Selected", INK, PAPER],
	["Danger", INK, NEON_PINK],
	["Hint", INK, NEON_CYAN],
	["Banner", INK, NEON_CYAN],
	["Mapa: nodo", INK, PAPER],
	["Mapa: aquí", INK, NEON_YELLOW],
	["Sazil", TEXT_DARK, SAZIL_FILL],
	["Sazil activa", TEXT_DARK, SAZIL_FILL_ACTIVE],
	["Akba", TEXT_LIGHT, AKBA_FILL],
	["Akba activo", TEXT_LIGHT, AKBA_FILL_ACTIVE],
]


# --- Contraste ------------------------------------------------------------------

## Luminancia relativa (WCAG 2.1) de un color sRGB.
static func relative_luminance(color: Color) -> float:
	var channels: Array[float] = [color.r, color.g, color.b]
	for i: int in 3:
		var c: float = channels[i]
		channels[i] = c / 12.92 if c <= 0.04045 else pow((c + 0.055) / 1.055, 2.4)
	return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]


## Relación de contraste entre dos colores opacos (de 1 a 21).
static func contrast_ratio(a: Color, b: Color) -> float:
	var la := relative_luminance(a)
	var lb := relative_luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


## Un color translúcido sobre otro opaco.
static func over(top: Color, bottom: Color) -> Color:
	return Color(lerpf(bottom.r, top.r, top.a), lerpf(bottom.g, top.g, top.a), lerpf(bottom.b, top.b, top.a), 1.0)


# --- Piezas ---------------------------------------------------------------------

## Caja de rotulador: relleno plano, contorno negro, sombra dura opcional.
static func marker_box(fill: Color, border: int = OUTLINE, radius: int = RADIUS, shadow: int = 0,
		margin_x: float = SPACE_L, margin_y: float = SPACE_S) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = INK
	box.set_border_width_all(border)
	box.set_corner_radius_all(radius)
	box.corner_detail = 6
	box.anti_aliasing = true
	box.content_margin_left = margin_x
	box.content_margin_right = margin_x
	box.content_margin_top = margin_y
	box.content_margin_bottom = margin_y
	if shadow > 0:
		box.shadow_color = INK
		box.shadow_size = 1
		box.shadow_offset = Vector2(0, shadow)
	return box


## Las cinco cajas de un botón a partir de su relleno. Pulsado: baja (sombra
## más corta y contenido más abajo). Desactivado: sin contorno ni sombra.
static func button_boxes(fill: Color, pressed_fill: Color, radius: int = RADIUS, margin_x: float = SPACE_L,
		margin_y: float = SPACE_S, base: int = OUTLINE) -> Dictionary:
	var normal := marker_box(fill, OUTLINE, radius, SHADOW, margin_x, margin_y)
	normal.border_width_bottom = base
	var pressed := marker_box(pressed_fill, OUTLINE, radius, 2, margin_x, margin_y)
	pressed.border_width_bottom = base
	pressed.content_margin_top = margin_y + SHADOW - 2
	pressed.content_margin_bottom = maxf(0.0, margin_y - SHADOW + 2)
	var disabled := marker_box(Color(fill, 0.4), 0, radius, 0, margin_x, margin_y)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = NEON_CYAN
	focus.set_border_width_all(OUTLINE)
	focus.set_corner_radius_all(radius + OUTLINE)
	focus.expand_margin_left = OUTLINE * 2
	focus.expand_margin_right = OUTLINE * 2
	focus.expand_margin_top = OUTLINE * 2
	focus.expand_margin_bottom = OUTLINE * 2
	return {"normal": normal, "hover": normal, "pressed": pressed, "hover_pressed": pressed, "disabled": disabled, "focus": focus}


static func _set_button(theme: Theme, type: String, boxes: Dictionary, font: Color, base_type: String = "") -> void:
	if base_type != "":
		theme.set_type_variation(type, base_type)
	for state: String in boxes:
		theme.set_stylebox(state, type, boxes[state])
	for item: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		theme.set_color(item, type, font)
	theme.set_color("font_disabled_color", type, Color(font, 0.55))


static func _set_label(theme: Theme, type: String, color: Color, base_type: String = "Label") -> void:
	theme.set_type_variation(type, base_type)
	theme.set_color("font_color", type, color)


static func _set_panel(theme: Theme, type: String, box: StyleBox) -> void:
	theme.set_type_variation(type, "PanelContainer")
	theme.set_stylebox("panel", type, box)


static func _icon(file: String) -> Texture2D:
	return load(UI_DIR + file) as Texture2D


## Letra gruesa (títulos, botones): la de siempre, engrosada.
static func bold_font() -> FontVariation:
	var font := FontVariation.new()
	font.variation_embolden = 0.6
	return font


# --- El tema --------------------------------------------------------------------

## Construye el tema del juego. Los tamaños de letra son los del nivel Normal
## (40/52); apply_text_size() los cambia en marcha.
static func build_theme() -> Theme:
	var theme := Theme.new()
	var bold := bold_font()
	theme.default_font_size = 40

	# Botones.
	_set_button(theme, "Button", button_boxes(VIOLET, VIOLET_PRESSED), TEXT_LIGHT)
	theme.set_font("font", "Button", bold)
	theme.set_constant("h_separation", "Button", SPACE_S)
	_set_button(theme, "Primary", button_boxes(NEON_YELLOW, NEON_YELLOW.darkened(0.12)), INK, "Button")
	_set_button(theme, "Danger", button_boxes(NEON_PINK, NEON_PINK.darkened(0.12)), INK, "Button")
	var selected := button_boxes(PAPER, PAPER.darkened(0.08), RADIUS, SPACE_L, SPACE_S, SELECTED_BASE)
	for state: String in ["normal", "hover", "pressed", "hover_pressed"]:
		(selected[state] as StyleBoxFlat).set_border_width_all(OUTLINE_HEAVY)
		(selected[state] as StyleBoxFlat).border_width_bottom = SELECTED_BASE
	_set_button(theme, "Selected", selected, INK, "Button")
	# Pestañas: como Button/Selected, con menos margen a los lados (caben cuatro).
	_set_button(theme, "Tab", button_boxes(VIOLET, VIOLET_PRESSED, RADIUS, SPACE_XS, SPACE_S), TEXT_LIGHT, "Button")
	var tab_on := button_boxes(PAPER, PAPER.darkened(0.08), RADIUS, SPACE_XS, SPACE_S, SELECTED_BASE)
	for state: String in ["normal", "hover", "pressed", "hover_pressed"]:
		(tab_on[state] as StyleBoxFlat).set_border_width_all(OUTLINE_HEAVY)
		(tab_on[state] as StyleBoxFlat).border_width_bottom = SELECTED_BASE
	_set_button(theme, "TabSelected", tab_on, INK, "Button")
	_set_button(theme, "Chip", button_boxes(NIGHT_RAISED, VIOLET_PRESSED, RADIUS_PILL, SPACE_M, SPACE_XS), TEXT_LIGHT, "Button")
	var chip_on := button_boxes(PAPER, PAPER.darkened(0.08), RADIUS_PILL, SPACE_M, SPACE_XS, SELECTED_BASE)
	for state: String in ["normal", "hover", "pressed", "hover_pressed"]:
		(chip_on[state] as StyleBoxFlat).set_border_width_all(OUTLINE_HEAVY)
		(chip_on[state] as StyleBoxFlat).border_width_bottom = SELECTED_BASE
	_set_button(theme, "ChipSelected", chip_on, INK, "Button")
	_set_button(theme, "Hint", button_boxes(NEON_CYAN, NEON_CYAN.darkened(0.15), RADIUS, SPACE_M, SPACE_S), INK, "Button")
	_set_button(theme, "IconButton", button_boxes(VIOLET, VIOLET_PRESSED, RADIUS, SPACE_S, SPACE_S), TEXT_LIGHT, "Button")
	# Navegación (Mapa, Cuaderno, Tiempo): icono encima del texto, márgenes cortos.
	_set_button(theme, "NavButton", button_boxes(VIOLET, VIOLET_PRESSED, RADIUS, SPACE_XS, SPACE_XS), TEXT_LIGHT, "Button")
	theme.set_constant("h_separation", "NavButton", 2)
	_set_button(theme, "Card", button_boxes(VIOLET, VIOLET_PRESSED, RADIUS_LARGE, SPACE_S, SPACE_S), TEXT_LIGHT, "Button")
	_set_button(theme, "CardKnowledge", button_boxes(KNOWLEDGE, KNOWLEDGE.darkened(0.2), RADIUS_LARGE, SPACE_S, SPACE_S), TEXT_LIGHT, "Button")
	# Selector de protagonista: Sazil redondeada (sol), Akba en chaflán (luna).
	var sazil := button_boxes(SAZIL_FILL, SAZIL_FILL_ACTIVE, RADIUS_LARGE * 2, SPACE_S, SPACE_S)
	var sazil_active := button_boxes(SAZIL_FILL_ACTIVE, SAZIL_FILL_ACTIVE, RADIUS_LARGE * 2, SPACE_S, SPACE_S, SELECTED_BASE)
	var akba := button_boxes(AKBA_FILL, AKBA_FILL_ACTIVE, RADIUS_LARGE, SPACE_S, SPACE_S)
	var akba_active := button_boxes(AKBA_FILL_ACTIVE, AKBA_FILL_ACTIVE, RADIUS_LARGE, SPACE_S, SPACE_S, SELECTED_BASE)
	for boxes: Dictionary in [akba, akba_active]:
		for state: String in boxes:
			(boxes[state] as StyleBoxFlat).corner_detail = 1
	# Activo: contorno grueso y base gruesa, también cuando no se puede cambiar.
	for pair: Array in [[sazil_active, SAZIL_FILL_ACTIVE], [akba_active, AKBA_FILL_ACTIVE]]:
		var boxes: Dictionary = pair[0]
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			var box := boxes[state] as StyleBoxFlat
			box.set_border_width_all(OUTLINE_HEAVY)
			box.border_width_bottom = SELECTED_BASE
			box.border_color = INK
			box.bg_color = pair[1]
	_set_button(theme, "SazilButton", sazil, TEXT_DARK, "Button")
	_set_button(theme, "SazilButtonActive", sazil_active, TEXT_DARK, "Button")
	_set_button(theme, "AkbaButton", akba, TEXT_LIGHT, "Button")
	_set_button(theme, "AkbaButtonActive", akba_active, TEXT_LIGHT, "Button")

	# Nodos del mapa (redondos): se puede ir, estás aquí (aro grueso amarillo) o sin explorar (sin contorno).
	_set_button(theme, "MapNode", button_boxes(PAPER, PAPER.darkened(0.1), 999, 0, 0), INK, "Button")
	var here := button_boxes(NEON_YELLOW, NEON_YELLOW, 999, 0, 0, OUTLINE_HEAVY)
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		(here[state] as StyleBoxFlat).set_border_width_all(OUTLINE_HEAVY + 3)
		(here[state] as StyleBoxFlat).bg_color = NEON_YELLOW
	_set_button(theme, "MapNodeHere", here, INK, "Button")
	var locked := button_boxes(Color("4b4566"), Color("4b4566"), 999, 0, 0)
	for state: String in locked:
		if state != "focus":
			var box := locked[state] as StyleBoxFlat
			box.set_border_width_all(0)
			box.shadow_size = 0
			box.bg_color = Color("4b4566", 0.7)
	_set_button(theme, "MapNodeLocked", locked, TEXT_LIGHT_MUTED, "Button")
	for type: String in ["MapNode", "MapNodeHere", "MapNodeLocked"]:
		theme.set_stylebox("disabled", type, theme.get_stylebox("normal", type))

	# Interruptores: el botón entero es el área táctil; el icono dice encendido
	# (bola a la derecha con ✓) o apagado (bola a la izquierda, hueca).
	var flat := StyleBoxEmpty.new()
	flat.content_margin_top = SPACE_S
	flat.content_margin_bottom = SPACE_S
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		theme.set_stylebox(state, "CheckButton", flat)
	theme.set_stylebox("focus", "CheckButton", (button_boxes(VIOLET, VIOLET)["focus"] as StyleBox))
	for item: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		theme.set_color(item, "CheckButton", TEXT_DARK)
	theme.set_color("font_disabled_color", "CheckButton", Color(TEXT_DARK, 0.55))
	for suffix: String in ["", "_mirrored"]:
		theme.set_icon("checked" + suffix, "CheckButton", _icon("toggle_on.svg"))
		theme.set_icon("unchecked" + suffix, "CheckButton", _icon("toggle_off.svg"))
		theme.set_icon("checked_disabled" + suffix, "CheckButton", _icon("toggle_on_disabled.svg"))
		theme.set_icon("unchecked_disabled" + suffix, "CheckButton", _icon("toggle_off_disabled.svg"))
	theme.set_constant("h_separation", "CheckButton", SPACE_M)

	# Deslizadores: pista gruesa con contorno y agarrador grande.
	var track := marker_box(PAPER_CARD, OUTLINE, RADIUS_PILL, 0, 0, 12)
	var filled := marker_box(VIOLET, OUTLINE, RADIUS_PILL, 0, 0, 12)
	theme.set_stylebox("slider", "HSlider", track)
	theme.set_stylebox("grabber_area", "HSlider", filled)
	theme.set_stylebox("grabber_area_highlight", "HSlider", filled)
	theme.set_icon("grabber", "HSlider", _icon("slider_grabber.svg"))
	theme.set_icon("grabber_highlight", "HSlider", _icon("slider_grabber_active.svg"))
	theme.set_icon("grabber_disabled", "HSlider", _icon("slider_grabber_disabled.svg"))
	theme.set_constant("center_grabber", "HSlider", 1)

	# Barras de desplazamiento: se ven (hay más abajo) y se pueden arrastrar.
	var bar_track := marker_box(Color(INK, 0.18), 0, RADIUS_PILL, 0, 6, 6)
	var bar_grab := marker_box(VIOLET_LIGHT, 3, RADIUS_PILL, 0, 6, 6)
	for type: String in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("scroll", type, bar_track)
		theme.set_stylebox("scroll_focus", type, bar_track)
		for state: String in ["grabber", "grabber_highlight", "grabber_pressed"]:
			theme.set_stylebox(state, type, bar_grab)

	# Separadores y contenedores.
	var line := StyleBoxLine.new()
	line.color = Color(INK, 0.25)
	line.thickness = 3
	theme.set_stylebox("separator", "HSeparator", line)
	theme.set_constant("separation", "HSeparator", SPACE_M)
	for type: String in ["VBoxContainer", "HBoxContainer"]:
		theme.set_constant("separation", type, SPACE_S)
	theme.set_type_variation("VBoxTight", "VBoxContainer")
	theme.set_constant("separation", "VBoxTight", SPACE_XS)
	theme.set_type_variation("HBoxTight", "HBoxContainer")
	theme.set_constant("separation", "HBoxTight", SPACE_XS)
	theme.set_type_variation("VBoxLoose", "VBoxContainer")
	theme.set_constant("separation", "VBoxLoose", SPACE_L)
	theme.set_constant("h_separation", "GridContainer", SPACE_S)
	theme.set_constant("v_separation", "GridContainer", SPACE_S)
	theme.set_constant("h_separation", "HFlowContainer", SPACE_XS)
	theme.set_constant("v_separation", "HFlowContainer", SPACE_XS)

	# Textos.
	theme.set_color("font_color", "Label", TEXT_LIGHT)
	theme.set_constant("line_spacing", "Label", 2)
	_set_label(theme, "NightLabel", TEXT_LIGHT)
	_set_label(theme, "NightMuted", TEXT_LIGHT_MUTED)
	_set_label(theme, "NightTitle", NEON_YELLOW)
	theme.set_font("font", "NightTitle", bold)
	_set_label(theme, "PaperLabel", TEXT_DARK)
	_set_label(theme, "PaperMuted", TEXT_DARK_MUTED)
	_set_label(theme, "PaperTitle", Color("4a1f5c"))
	theme.set_font("font", "PaperTitle", bold)
	_set_label(theme, "TitleLabel", TEXT_LIGHT)
	theme.set_font("font", "TitleLabel", bold)
	_set_label(theme, "SwitchName", TEXT_LIGHT)
	theme.set_font("font", "SwitchName", bold)
	_set_label(theme, "SwitchStatus", TEXT_LIGHT)
	_set_label(theme, "SwitchNameDark", TEXT_DARK)
	theme.set_font("font", "SwitchNameDark", bold)
	_set_label(theme, "SwitchStatusDark", TEXT_DARK)
	# Texto sobre la escena: claro con contorno de rotulador.
	_set_label(theme, "Caption", TEXT_LIGHT)
	theme.set_color("font_outline_color", "Caption", INK)
	theme.set_constant("outline_size", "Caption", CAPTION_OUTLINE)
	_set_label(theme, "Clock", NEON_YELLOW)
	theme.set_font("font", "Clock", bold)
	theme.set_color("font_outline_color", "Clock", INK)
	theme.set_constant("outline_size", "Clock", CAPTION_OUTLINE)
	_set_label(theme, "Badge", INK)
	theme.set_font("font", "Badge", bold)
	# Cartas de conversación: título en negrita y texto claro sobre violeta.
	_set_label(theme, "CardTitle", TEXT_LIGHT)
	theme.set_font("font", "CardTitle", bold)
	_set_label(theme, "CardText", TEXT_LIGHT_MUTED)
	# Texto oscuro sobre el aviso cian (vista previa desde el mapa).
	_set_label(theme, "BannerLabel", INK)
	theme.set_font("font", "BannerLabel", bold)
	# Texto que va sobre la escena (mapa, etiquetas de puntos): claro y con contorno.
	_set_label(theme, "MapLabel", TEXT_LIGHT)
	theme.set_font("font", "MapLabel", bold)
	theme.set_color("font_outline_color", "MapLabel", INK)
	theme.set_constant("outline_size", "MapLabel", CAPTION_OUTLINE)

	# Paneles (un PanelContainer sin variación no dibuja nada).
	theme.set_stylebox("panel", "PanelContainer", StyleBoxEmpty.new())
	_set_panel(theme, "Paper", marker_box(PAPER, OUTLINE, RADIUS_LARGE, SHADOW, SPACE_XL, SPACE_XL))
	(theme.get_stylebox("panel", "Paper") as StyleBoxFlat).content_margin_top = 64
	_set_panel(theme, "Sheet", marker_box(PAPER, OUTLINE, RADIUS_LARGE, SHADOW, SPACE_L, SPACE_L))
	var night := marker_box(NIGHT, 0, 0, 0, SPACE_XL, SPACE_XL)
	night.content_margin_top = 120
	_set_panel(theme, "Night", night)
	var top := marker_box(Color(NIGHT, 0.9), 0, 0, 0, SPACE_M, SPACE_S)
	top.border_width_bottom = OUTLINE
	top.corner_radius_bottom_left = RADIUS_LARGE
	top.corner_radius_bottom_right = RADIUS_LARGE
	top.content_margin_top = SPACE_XL
	_set_panel(theme, "TopPanel", top)
	var bottom := marker_box(Color(NIGHT, 0.97), 0, 0, 0, SPACE_M, SPACE_M)
	bottom.border_width_top = OUTLINE
	bottom.corner_radius_top_left = RADIUS_LARGE + 8
	bottom.corner_radius_top_right = RADIUS_LARGE + 8
	bottom.content_margin_top = SPACE_M
	_set_panel(theme, "BottomPanel", bottom)
	_set_panel(theme, "Card", marker_box(PAPER_CARD, 3, RADIUS, 0, SPACE_M, SPACE_S))
	_set_panel(theme, "CardNight", marker_box(NIGHT_RAISED, 3, RADIUS, 0, SPACE_M, SPACE_S))
	_set_panel(theme, "Banner", marker_box(NEON_CYAN, OUTLINE, RADIUS, SHADOW, SPACE_M, SPACE_S))
	_set_panel(theme, "DangerBanner", marker_box(NEON_PINK, OUTLINE, RADIUS, SHADOW, SPACE_M, SPACE_S))
	# Fichas de muros y puertas: descubiertas (contorno) o por descubrir (sin contorno, apagadas).
	_set_panel(theme, "ChipKnown", marker_box(PAPER_CARD, 3, RADIUS_PILL, 0, SPACE_S, 4))
	_set_panel(theme, "ChipUnknown", marker_box(Color(PAPER_CARD, 0.5), 0, RADIUS_PILL, 0, SPACE_S + 3, 7))
	_set_panel(theme, "BadgePanel", marker_box(NEON_YELLOW, 3, RADIUS_PILL, 0, SPACE_S, 2))
	var plate := marker_box(PAPER, 3, 999, 0, 0, 0)
	plate.corner_detail = 16
	_set_panel(theme, "Plate", plate)
	theme.set_type_variation("PlatePanel", "Panel")
	theme.set_stylebox("panel", "PlatePanel", plate)
	# Placa del retrato en el selector: redonda (Sazil, sol) o en chaflán (Akba, luna).
	var round := marker_box(PAPER, OUTLINE, 999, 0, 0, 0)
	round.corner_detail = 16
	theme.set_type_variation("PlateRound", "Panel")
	theme.set_stylebox("panel", "PlateRound", round)
	var chamfer := marker_box(Color("c9c6f0"), OUTLINE, 40, 0, 0, 0)
	chamfer.corner_detail = 1
	theme.set_type_variation("PlateChamfer", "Panel")
	theme.set_stylebox("panel", "PlateChamfer", chamfer)
	return theme


## Tamaños de letra del nivel elegido ({body, title} de data/settings.json).
static func apply_text_size(theme: Theme, sizes: Dictionary) -> void:
	var body: int = sizes["body"]
	var title: int = sizes["title"]
	theme.default_font_size = body
	for type: String in ["Label", "Button", "CheckButton", "NightLabel", "NightMuted", "PaperLabel", "PaperMuted",
			"SwitchStatus", "SwitchStatusDark", "Caption", "Badge", "BannerLabel", "MapLabel", "CardTitle", "CardText"]:
		theme.set_font_size("font_size", type, body)
	for type: String in ["TitleLabel", "PaperTitle", "SwitchName", "SwitchNameDark", "Clock"]:
		theme.set_font_size("font_size", type, title)
	theme.set_font_size("font_size", "NightTitle", title + 12)


## Un botón creado en código, ya con su área táctil mínima.
static func touch(button: BaseButton, variation: StringName = &"") -> BaseButton:
	button.custom_minimum_size = Vector2(maxf(button.custom_minimum_size.x, MIN_TOUCH), maxf(button.custom_minimum_size.y, MIN_TOUCH))
	button.theme_type_variation = variation
	return button
