extends SceneTree
## Genera el arte PROVISIONAL de las ranuras que aún no tienen arte de verdad
## (ver docs/art_pipeline.md y docs/art_todo.md):
##   godot --headless --path . --script res://scripts/dev/make_placeholder_art.gd [-- --check] [--force] [--only id,id]
##
## - Solo las ranuras con `"provisional": true` en data/art_manifest.json y sin
##   arte de verdad en assets/art/. Nunca escribe en assets/art/: deja cada
##   imagen en assets/art_provisional/<misma ruta>. El arte de verdad, en cuanto
##   se ingiere, gana solo (scripts/art_library.gd), sin tocar código.
## - Estilo rotulador, como el arte: trazo negro grueso, colores planos
##   saturados, violeta e índigo con neones. Cada dibujo es un SVG escrito aquí y
##   rasterizado por Godot (ThorVG): sin azar, siempre sale igual.
## - Es idempotente: lo que ya existe no se rehace (salvo `--force`).
## - `--check` no escribe nada: dice qué ranuras tienen arte de verdad, cuáles
##   provisional y cuáles se dibujan en código, y lista los archivos de
##   assets/art_incoming/ que no se llaman como ninguna ranura (con una
##   sugerencia, p. ej. «objects.png → ¿plaza_fg?»).
## Sale con 1 si algo falla.

const ArtLibrary := preload("res://scripts/art_library.gd")
const ArtIngest := preload("res://scripts/dev/art_ingest.gd")

# Colores del rotulador (los de la interfaz, scripts/ui_style.gd, más los del arte).
const INK: String = "#0e0a18"
const CREAM: String = "#f6ecd8"
const VIOLET: String = "#3d2d78"
const VIOLET_WALL: String = "#6b4fb0"
const VIOLET_WALL_2: String = "#8a63c9"
const ROOF: String = "#2e2560"
const NIGHT: String = "#171233"
const NIGHT_2: String = "#241b4a"
const YELLOW: String = "#ffd23f"
const PINK: String = "#ff3f8e"
const CYAN: String = "#39dcff"
const GREEN: String = "#6dff9c"
const CRIMSON: String = "#ff3f6a"
const BRASS: String = "#c9973a"
const BRASS_DARK: String = "#8a5f22"
const WOOD: String = "#8a5a3a"
const WOOD_LIGHT: String = "#b07a45"
const IRON: String = "#2b2450"
const LEAF: String = "#3fae6a"
const TERRACOTTA: String = "#c8642e"
const ORANGE: String = "#ff9a2e"
## Trazo de rotulador en un dibujo de ~1000 px.
const STROKE: float = 11.0
## Manos (1080×810).
const SKIN := {"sazil": "#f7d0b5", "akba": "#c9dcc6"}
const SLEEVE := {"sazil": TERRACOTTA, "akba": "#262356"}
const CUFF := {"sazil": "#e8a33d", "akba": "#36317a"}
const GLOVE: String = "#6b4630"
const STRAP: String = "#7a4b23"

var _library: ArtLibrary
var _report: Dictionary = {"generated": [], "up_to_date": [], "real": [], "drawn": [], "no_drawing": [], "failed": []}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var check := args.has("--check")
	var force := args.has("--force")
	var only: PackedStringArray = []
	var at := args.find("--only")
	if at >= 0 and at + 1 < args.size():
		only = args[at + 1].split(",")
	_library = ArtLibrary.new()
	if not _library.load_manifest():
		quit(1)
		return
	for slot_id: String in _library.slot_ids:
		if not only.is_empty() and not only.has(slot_id):
			continue
		_process_slot(slot_id, check, force)
	_print_report(check)
	_print_incoming()
	quit(1 if not _report["failed"].is_empty() else 0)


func _process_slot(slot_id: String, check: bool, force: bool) -> void:
	var slot: Dictionary = _library.slots[slot_id]
	if _library.has_file(slot_id):
		_report["real"].append(slot_id)
		return
	if not slot["provisional"]:
		_report["drawn"].append(slot_id)
		return
	var path := _library.provisional_path(slot_id)
	var absolute := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute) and not force:
		_report["up_to_date"].append(slot_id)
		return
	if check:
		_report["no_drawing" if _svg_for(slot) == "" else "failed"].append(slot_id + " (falta el provisional)")
		return
	var svg := _svg_for(slot)
	if svg == "":
		_report["no_drawing"].append(slot_id)
		return
	var image := Image.new()
	if image.load_svg_from_string(svg, 1.0) != OK or image.get_size() != slot["size"]:
		_report["failed"].append("%s: el SVG no da %s" % [slot_id, slot["size"]])
		return
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var error: Error
	if slot["kind"] == "cutout":
		image.convert(Image.FORMAT_RGBA8)
		error = image.save_png(absolute)
	else:
		image.convert(Image.FORMAT_RGB8)
		error = image.save_png(absolute) if path.get_extension() == "png" else image.save_jpg(absolute, _library.jpg_quality)
	if error != OK:
		_report["failed"].append("%s: %s" % [slot_id, error_string(error)])
		return
	if slot_id.begins_with("app_"):
		_write_lossless_import(path)
	ArtIngest.write_import_settings(path, slot)
	_report["generated"].append(slot_id)


## Icono y arranque: sin pérdida (los lee la exportación y el arranque).
func _write_lossless_import(resource_path: String) -> void:
	var import_path := ProjectSettings.globalize_path(resource_path + ".import")
	if FileAccess.file_exists(import_path):
		return
	var lines: PackedStringArray = ["[remap]", "", "importer=\"texture\"", "type=\"CompressedTexture2D\"", "",
		"[deps]", "", "source_file=\"%s\"" % resource_path, "", "[params]", "", "compress/mode=0",
		"mipmaps/generate=false", "process/fix_alpha_border=true", "process/size_limit=0", "detect_3d/compress_to=0"]
	FileAccess.open(import_path, FileAccess.WRITE).store_string("\n".join(lines) + "\n")


func _print_report(check: bool) -> void:
	print("Arte provisional%s" % (" (solo comprobar)" if check else ""))
	for key: String in ["generated", "up_to_date", "real", "drawn", "no_drawing", "failed"]:
		var items: Array = _report[key]
		print("%-11s %2d  %s" % [key, items.size(), ", ".join(PackedStringArray(items))])


## Archivos que llegan sin el nombre de ninguna ranura: se informa, no se arregla.
func _print_incoming() -> void:
	var ingest := ArtIngest.new(_library)
	var files: Dictionary = ingest.call("_incoming_files", ProjectSettings.globalize_path(_library.incoming))
	var lines: PackedStringArray = []
	for name: String in files:
		if not _library.slots.has(name):
			var hint := ArtIngest.suggest_slot(_library, name)
			lines.append("  %s%s" % [String(files[name]).get_file(), "  → ¿%s?" % hint if hint != "" else ""])
	if lines.is_empty():
		print("assets/art_incoming/: ningún archivo sin ranura.")
	else:
		print("assets/art_incoming/: archivos sin ranura (renómbralos; no se tocan):\n" + "\n".join(lines))


# --- Qué se dibuja ----------------------------------------------------------------

func _svg_for(slot: Dictionary) -> String:
	var id: String = slot["id"]
	var size: Vector2i = slot["size"]
	if id.begins_with("hands_"):
		return _svg(size, _hands(slot["actor"], slot["hand_state"]))
	match slot["layer"]:
		"fg":
			return _svg(size, _foreground(slot["place"]))
		"mid":
			return _svg(size, _mid(slot["place"]))
	match id:
		"map_relojeria":
			return _svg(size, _map_relojeria())
		"map_mercado":
			return _svg(size, _map_mercado())
		"map_plaza":
			return _svg(size, _map_plaza())
		"map_unexplored":
			return _svg(size, _map_unexplored())
		"hotspot_look":
			return _svg(size, _hotspot_look())
		"hotspot_fissure":
			return _svg(size, _hotspot_fissure())
		"loop_reset_clock":
			return _svg(size, _clock_face(Vector2(512, 512), 470.0, false))
		"ending_un_buen_dia":
			return _svg(size, _ending_good_day())
		"ending_otra_vez":
			return _svg(size, _ending_again())
		"app_icon":
			return _svg(size, _app_icon())
		"app_splash":
			return _svg(size, _splash())
	return ""


# --- SVG ---------------------------------------------------------------------------

static func _svg(size: Vector2i, body: String) -> String:
	return "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%d\" height=\"%d\" viewBox=\"0 0 %d %d\">%s</svg>" % [
			size.x, size.y, size.x, size.y, body]


static func _n(value: float) -> String:
	return String.num(value, 1)


static func _pt(p: Vector2) -> String:
	return "%s,%s" % [_n(p.x), _n(p.y)]


static func _line(a: Vector2, b: Vector2, width: float, color: String, extra: String = "") -> String:
	return "<line x1=\"%s\" y1=\"%s\" x2=\"%s\" y2=\"%s\" stroke=\"%s\" stroke-width=\"%s\" stroke-linecap=\"round\" %s/>" % [
			_n(a.x), _n(a.y), _n(b.x), _n(b.y), color, _n(width), extra]


static func _poly(points: PackedVector2Array, fill: String, stroke: float = STROKE, extra: String = "") -> String:
	var parts: PackedStringArray = []
	for p: Vector2 in points:
		parts.append(_pt(p))
	return "<polygon points=\"%s\" fill=\"%s\" stroke=\"%s\" stroke-width=\"%s\" stroke-linejoin=\"round\" %s/>" % [
			" ".join(parts), fill, INK, _n(stroke), extra]


static func _polyline(points: PackedVector2Array, color: String, width: float, extra: String = "") -> String:
	var parts: PackedStringArray = []
	for p: Vector2 in points:
		parts.append(_pt(p))
	return "<polyline points=\"%s\" fill=\"none\" stroke=\"%s\" stroke-width=\"%s\" stroke-linecap=\"round\" stroke-linejoin=\"round\" %s/>" % [
			" ".join(parts), color, _n(width), extra]


static func _circle(c: Vector2, r: float, fill: String, stroke: float = STROKE, extra: String = "") -> String:
	return "<circle cx=\"%s\" cy=\"%s\" r=\"%s\" fill=\"%s\" stroke=\"%s\" stroke-width=\"%s\" %s/>" % [
			_n(c.x), _n(c.y), _n(r), fill, INK, _n(stroke), extra]


static func _rect(r: Rect2, fill: String, radius: float = 10.0, stroke: float = STROKE) -> String:
	return "<rect x=\"%s\" y=\"%s\" width=\"%s\" height=\"%s\" rx=\"%s\" fill=\"%s\" stroke=\"%s\" stroke-width=\"%s\" stroke-linejoin=\"round\"/>" % [
			_n(r.position.x), _n(r.position.y), _n(r.size.x), _n(r.size.y), _n(radius), fill, INK, _n(stroke)]


static func _path(d: String, fill: String, stroke: float = STROKE, extra: String = "") -> String:
	return "<path d=\"%s\" fill=\"%s\" stroke=\"%s\" stroke-width=\"%s\" stroke-linejoin=\"round\" stroke-linecap=\"round\" %s/>" % [
			d, fill, INK, _n(stroke), extra]


## Resplandor radial (de `color` opaco a transparente).
static func _glow(id: String, c: Vector2, r: float, color: String, opacity: float) -> String:
	return ("<defs><radialGradient id=\"%s\"><stop offset=\"0\" stop-color=\"%s\" stop-opacity=\"%s\"/>" +
			"<stop offset=\"1\" stop-color=\"%s\" stop-opacity=\"0\"/></radialGradient></defs>" +
			"<circle cx=\"%s\" cy=\"%s\" r=\"%s\" fill=\"url(#%s)\"/>") % [id, color, _n(opacity), color, _n(c.x), _n(c.y), _n(r), id]


## Fondo con degradado vertical.
static func _sky(size: Vector2, top: String, bottom: String) -> String:
	return ("<defs><linearGradient id=\"sky\" x1=\"0\" y1=\"0\" x2=\"0\" y2=\"1\"><stop offset=\"0\" stop-color=\"%s\"/>" +
			"<stop offset=\"1\" stop-color=\"%s\"/></linearGradient></defs><rect x=\"0\" y=\"0\" width=\"%s\" height=\"%s\" fill=\"url(#sky)\"/>") % [
			top, bottom, _n(size.x), _n(size.y)]


## Cápsula con contorno: primero todas las de contorno y luego todas las de
## relleno, para que varias piezas formen una sola silueta con trazo exterior.
static func _capsules(parts: Array[Array], fill: String, stroke: float = STROKE) -> String:
	var out := ""
	for part: Array in parts:
		out += _line(part[0], part[1], part[2] + stroke * 2.0, INK)
	for part: Array in parts:
		out += _line(part[0], part[1], part[2], fill)
	return out


# --- Manos (primera persona, desde el borde de abajo, 1080×810) ---------------------

## Piezas de una mano vista por detrás: [desde, hasta, grosor]. `thumb_side`: -1
## si el pulgar queda a la izquierda (mano derecha), 1 si a la derecha (izquierda).
## `pose`: rest, open, point, fist o pinch. Devuelve {palm, fingers, thumb, tips}.
static func _hand_parts(wrist: Vector2, angle: float, thumb_side: float, pose: String) -> Dictionary:
	var up := Vector2.UP.rotated(angle)
	var side := Vector2.RIGHT.rotated(angle)
	var lengths: Array = [92.0, 104.0, 96.0, 76.0]
	var spread := 1.0
	var thumb_turn := 0.95
	var thumb_length := 70.0
	match pose:
		"open":
			lengths = [120.0, 134.0, 124.0, 100.0]
			spread = 2.2
			thumb_turn = 1.25
			thumb_length = 92.0
		"point":
			lengths = [150.0, 40.0, 38.0, 34.0]
			spread = 0.3
			thumb_turn = 0.55
			thumb_length = 62.0
		"fist":
			lengths = [40.0, 42.0, 40.0, 36.0]
			spread = 0.4
			thumb_turn = -0.9
			thumb_length = 64.0
		"pinch":
			lengths = [78.0, 84.0, 80.0, 66.0]
			spread = 0.6
			thumb_turn = 0.5
			thumb_length = 80.0
	var widths: Array = [40.0, 42.0, 40.0, 34.0]
	var tilts: Array = [0.12, 0.04, -0.04, -0.14]
	var fingers: Array[Array] = []
	var tips: Array[Array] = []
	for k: int in 4:
		var base: Vector2 = wrist + up * 100.0 + side * thumb_side * (54.0 - 36.0 * k)
		var direction := up.rotated(thumb_side * float(tilts[k]) * spread)
		var tip: Vector2 = base + direction * float(lengths[k])
		fingers.append([base, tip, widths[k]])
		tips.append([tip, direction, float(lengths[k])])
	var thumb_base := wrist + up * 40.0 + side * thumb_side * 58.0
	var thumb_tip := thumb_base + up.rotated(thumb_side * thumb_turn) * thumb_length
	return {"palm": [wrist + up * 12.0, wrist + up * 86.0, 150.0], "fingers": fingers,
			"thumb": [thumb_base, thumb_tip, 46.0], "tips": tips, "up": up}


## Una mano entera: silueta con contorno, uñas, y el mitón de Sazil si `glove`.
static func _hand(wrist: Vector2, angle: float, thumb_side: float, pose: String, skin: String, glove: bool) -> String:
	var parts := _hand_parts(wrist, angle, thumb_side, pose)
	var pieces: Array[Array] = [parts["palm"], parts["thumb"]]
	pieces.append_array(parts["fingers"])
	var out := _capsules(pieces, skin)
	if glove:
		# Guante sin dedos: palma, nudillos y base del pulgar; las yemas al aire.
		var palm: Array = parts["palm"]
		out += _line(palm[0], palm[1], palm[2], GLOVE)
		for finger: Array in parts["fingers"]:
			var base: Vector2 = finger[0]
			var tip: Vector2 = finger[1]
			out += _line(base, base.lerp(tip, minf(0.5, 38.0 / maxf(base.distance_to(tip), 1.0))), finger[2], GLOVE)
		var thumb: Array = parts["thumb"]
		out += _line(thumb[0], (thumb[0] as Vector2).lerp(thumb[1], 0.45), thumb[2], GLOVE)
		var up: Vector2 = parts["up"]
		out += _line(wrist + up * 4.0, wrist + up * 26.0, 168.0, "#4a2c20")
	for tip: Array in parts["tips"]:
		if float(tip[2]) > 60.0:
			var at: Vector2 = tip[0]
			var direction: Vector2 = tip[1]
			out += _line(at - direction * 24.0, at - direction * 8.0, 18.0, "#ffffff", "stroke-opacity=\"0.45\"")
		else:
			# Dedo doblado: el pliegue del nudillo.
			var knuckle: Vector2 = tip[0]
			var across := Vector2(tip[1]).orthogonal() * 12.0
			out += _line(knuckle - across, knuckle + across, 5.0, INK)
	return out


## Manga desde fuera de la imagen hasta la muñeca, con su puño.
static func _sleeve(from: Vector2, wrist: Vector2, actor: String) -> String:
	var direction := from.direction_to(wrist)
	var width := 190.0 if actor == "akba" else 176.0
	var out := _capsules([[from, wrist - direction * 6.0, width]], SLEEVE[actor])
	out += _capsules([[wrist - direction * 58.0, wrist - direction * 14.0, width + 18.0]], CUFF[actor])
	if actor == "akba":
		out += _circle(wrist - direction * 36.0 + direction.orthogonal() * 60.0, 14.0, BRASS, 6.0)
	return out


## La correa de la bolsa de correo de Sazil cruzando por abajo a la izquierda.
static func _strap() -> String:
	var a := Vector2(-40.0, 520.0)
	var b := Vector2(330.0, 880.0)
	return _capsules([[a, b, 84.0]], STRAP) + _line(a, b, 6.0, "#c99a62", "stroke-dasharray=\"18 16\"")


## Farol de latón colgado de `top` (el asa). Dentro, la gema del colgante de Akba
## (verde ácido con una cara carmesí) o, en el de Sazil, una llama.
static func _lantern(top: Vector2, scale: float, akba: bool, glow: float) -> String:
	var out := ""
	if glow > 0.0:
		var center := top + Vector2(0, 150) * scale
		out += _glow("lg%d" % int(top.x), center, 330.0 * scale, GREEN if akba else YELLOW, glow)
		if akba:
			out += _glow("lc%d" % int(top.x), center, 140.0 * scale, CRIMSON, glow * 0.6)
	var t := "translate(%s %s) scale(%s)" % [_n(top.x), _n(top.y), _n(scale)]
	out += "<g transform=\"%s\">" % t
	out += _path("M -42 46 Q 0 -34 42 46", "none", 22.0)
	out += _path("M -42 46 Q 0 -34 42 46", "none", 9.0, "stroke=\"%s\"" % BRASS)
	out += _poly(PackedVector2Array([Vector2(-42, 40), Vector2(42, 40), Vector2(68, 82), Vector2(-68, 82)]), BRASS)
	out += _rect(Rect2(-58, 82, 116, 140), "#e4ffe9" if akba else "#fff3c4", 12.0)
	if akba:
		var gem := PackedVector2Array()
		for i: int in 6:
			gem.append(Vector2(0, 152) + Vector2(0, -34).rotated(TAU * i / 6.0))
		out += _poly(gem, GREEN, 8.0)
		out += _poly(PackedVector2Array([gem[0], gem[1], Vector2(0, 152)]), CRIMSON, 6.0)
		out += _line(gem[2], gem[5], 5.0, INK)
	else:
		out += _path("M 0 112 Q 30 150 0 186 Q -30 150 0 112 Z", ORANGE, 8.0)
		out += _path("M 0 140 Q 12 160 0 178 Q -12 160 0 140 Z", YELLOW, 0.0)
	out += _line(Vector2(-20, 86), Vector2(-20, 218), 7.0, INK)
	out += _line(Vector2(20, 86), Vector2(20, 218), 7.0, INK)
	out += _poly(PackedVector2Array([Vector2(-68, 222), Vector2(68, 222), Vector2(48, 256), Vector2(-48, 256)]), BRASS)
	out += "</g>"
	return out


static func _letter(center: Vector2, akba: bool) -> String:
	var rect := Rect2(center - Vector2(190, 125), Vector2(380, 250))
	var out := "<g transform=\"rotate(-4 %s %s)\">" % [_n(center.x), _n(center.y)]
	out += _rect(rect, CREAM if not akba else "#e9e2f7", 8.0)
	out += _polyline(PackedVector2Array([rect.position + Vector2(8, 8), center + Vector2(0, 10), Vector2(rect.end.x - 8, rect.position.y + 8)]), INK, 7.0)
	out += _circle(center + Vector2(0, 14), 30.0, PINK, 8.0)
	out += _circle(center + Vector2(0, 14), 14.0, "#c22a68", 0.0)
	out += "</g>"
	return out


## Cuerda (Sazil) o hilo del Umbral (Akba) que se agarra en un quiebre.
static func _hold_line(a: Vector2, b: Vector2, akba: bool) -> String:
	if akba:
		return (_line(a, b, 70.0, GREEN, "stroke-opacity=\"0.3\"") + _line(a, b, 26.0, GREEN) +
				_line(a, b, 8.0, CRIMSON))
	return _capsules([[a, b, 46.0]], "#b98a4e") + _line(a, b, 28.0, "#8a5f2e", "stroke-dasharray=\"16 22\"")


## Las manos de `actor` en `state` (los de data/scenes.json, hands.states).
func _hands(actor: String, state: String) -> String:
	var akba := actor == "akba"
	var skin: String = SKIN[actor]
	var out := ""
	if not akba:
		out += _strap()
	# Akba lleva el farol en la izquierda salvo que necesite las dos manos.
	var lantern_left := akba and state in ["idle", "point", "wait"]
	match state:
		"hold_letter":
			out += _sleeve(Vector2(140, 900), Vector2(380, 560), actor) + _sleeve(Vector2(940, 900), Vector2(700, 560), actor)
			out += _letter(Vector2(540, 330), akba)
			out += _hand(Vector2(380, 560), 0.45, 1.0, "pinch", skin, not akba)
			out += _hand(Vector2(700, 560), -0.45, -1.0, "pinch", skin, false)
		"point":
			out += _left_low(actor, skin, lantern_left)
			out += _sleeve(Vector2(900, 900), Vector2(700, 440), actor)
			out += _hand(Vector2(700, 440), -0.32, -1.0, "point", skin, false)
		"light":
			out += _sleeve(Vector2(180, 900), Vector2(270, 660), actor)
			out += _hand(Vector2(270, 660), 0.2, 1.0, "rest", skin, not akba)
			# En alto: el farol (o el candil de Sazil) se sostiene por la base, sobre el puño.
			var wrist := Vector2(640, 560)
			var fist := wrist + Vector2.UP.rotated(-0.2) * 70.0
			var lamp_scale := 1.0 if akba else 0.8
			out += _sleeve(Vector2(860, 900), wrist, actor)
			out += _lantern(fist + Vector2(0, -40 - 256.0 * lamp_scale), lamp_scale, akba, 0.75 if akba else 0.6)
			out += _hand(wrist, -0.2, -1.0, "fist", skin, false)
		"reach":
			out += _sleeve(Vector2(200, 900), Vector2(390, 420), actor) + _sleeve(Vector2(880, 900), Vector2(690, 420), actor)
			out += _hand(Vector2(390, 420), 0.3, 1.0, "open", skin, not akba)
			out += _hand(Vector2(690, 420), -0.3, -1.0, "open", skin, false)
		"wait":
			if lantern_left:
				out += _left_low(actor, skin, true)
				out += _sleeve(Vector2(860, 900), Vector2(650, 700), actor)
				out += _hand(Vector2(650, 700), -0.95, -1.0, "rest", skin, false)
			else:
				out += _sleeve(Vector2(240, 900), Vector2(470, 710), actor) + _sleeve(Vector2(840, 900), Vector2(610, 700), actor)
				out += _hand(Vector2(470, 710), 1.0, 1.0, "rest", skin, not akba)
				out += _hand(Vector2(610, 700), -1.0, -1.0, "rest", skin, false)
		"grip":
			out += _hold_line(Vector2(80, 400), Vector2(1000, 370), akba)
			out += _sleeve(Vector2(220, 900), Vector2(440, 500), actor) + _sleeve(Vector2(860, 900), Vector2(640, 500), actor)
			out += _hand(Vector2(440, 500), 0.25, 1.0, "fist", skin, not akba)
			out += _hand(Vector2(640, 500), -0.25, -1.0, "fist", skin, false)
		_:
			out += _left_low(actor, skin, lantern_left)
			out += _sleeve(Vector2(900, 900), Vector2(790, 620), actor)
			out += _hand(Vector2(790, 620), -0.18, -1.0, "rest", skin, false)
	return out


## La mano izquierda abajo: en reposo (con el guante de Sazil) o con el farol de Akba.
func _left_low(actor: String, skin: String, lantern: bool) -> String:
	if not lantern:
		return _sleeve(Vector2(180, 900), Vector2(290, 630), actor) + _hand(Vector2(290, 630), 0.18, 1.0, "rest", skin, actor == "sazil")
	# El farol cuelga del asa hacia el centro, fuera del brazo (que entra en diagonal).
	var wrist := Vector2(250, 540)
	var fist := wrist + Vector2.UP.rotated(0.6) * 70.0
	return (_sleeve(Vector2(-80, 900), wrist, actor) + _lantern(fist + Vector2(70, -30), 0.85, true, 0.4) +
			_hand(wrist, 0.6, 1.0, "fist", skin, false))


# --- Capas de los lugares (2880×1920, recorte) ----------------------------------

## Primer plano: marco bajo en los bordes, nada que tape a la gente (pies en
## ground_y) ni los puntos interactivos.
func _foreground(place: String) -> String:
	var out := ""
	match place:
		"relojeria":
			out += _fence(0.0, 420.0, 1920.0, 1440.0)
			out += _gear(Vector2(2640, 1830), 250.0)
			out += _barrel(Vector2(2330, 1920), 180.0, 240.0)
			out += _cobbles(1860.0, 0.0, 2880.0)
		"mercado":
			out += _crate(Vector2(60, 1920), 320.0, 220.0, true)
			out += _basket(Vector2(420, 1920))
			out += _sack(Vector2(2520, 1920), 260.0) + _sack(Vector2(2730, 1920), 220.0)
			out += _bunting(Vector2(2200, 760), Vector2(2900, 700), 150.0)
			out += _cobbles(1870.0, 0.0, 2880.0)
		"plaza":
			out += _farolillos(Vector2(-20, 760), Vector2(760, 820), 120.0)
			out += _planter(Vector2(230, 1920), 300.0)
			out += _lamp_post(Vector2(2740, 1920), 1060.0)
			out += _bench(Vector2(2380, 1920))
			out += _cobbles(1880.0, 0.0, 2880.0)
	return out


## Capa media: objetos sobre el suelo entre estaciones (nunca encima de una).
func _mid(place: String) -> String:
	var out := ""
	match place:
		"relojeria":
			out += _lamp_post(Vector2(1060, 1560), 760.0)
			out += _sign_board(Vector2(1800, 1560))
			out += _bollard(Vector2(260, 1560)) + _bollard(Vector2(2800, 1560))
		"mercado":
			out += _barrel(Vector2(730, 1600), 150.0, 200.0)
			out += _crate(Vector2(1300, 1600), 200.0, 150.0, false) + _crate(Vector2(1320, 1450), 160.0, 120.0, true)
			out += _lamp_post(Vector2(1950, 1600), 720.0)
			out += _sack(Vector2(2650, 1600), 200.0)
		"plaza":
			out += _bench(Vector2(700, 1620))
			out += _lamp_post(Vector2(2060, 1620), 760.0)
			out += _planter(Vector2(2770, 1620), 220.0)
	return out


func _fence(x0: float, x1: float, ground: float, top: float) -> String:
	var out := _capsules([[Vector2(x0, top + 70), Vector2(x1, top + 70), 22.0], [Vector2(x0, ground - 60), Vector2(x1, ground - 60), 22.0]], IRON)
	var x := x0 + 30.0
	while x < x1:
		out += _poly(PackedVector2Array([Vector2(x - 12, ground), Vector2(x - 12, top + 40), Vector2(x, top), Vector2(x + 12, top + 40), Vector2(x + 12, ground)]), IRON, 9.0)
		x += 70.0
	return out


func _gear(c: Vector2, r: float) -> String:
	var teeth := PackedVector2Array()
	for i: int in 24:
		var a := TAU * i / 24.0
		teeth.append(c + Vector2.RIGHT.rotated(a) * (r if i % 2 == 0 else r * 0.84))
	return _poly(teeth, BRASS) + _circle(c, r * 0.62, BRASS_DARK) + _circle(c, r * 0.22, NIGHT_2)


func _barrel(bottom: Vector2, w: float, h: float) -> String:
	var r := Rect2(bottom - Vector2(w * 0.5, h), Vector2(w, h))
	var out := _rect(r, WOOD, w * 0.25)
	for f: float in [0.22, 0.78]:
		out += _line(Vector2(r.position.x + 6, r.position.y + h * f), Vector2(r.end.x - 6, r.position.y + h * f), 14.0, INK)
	out += _line(Vector2(bottom.x, r.position.y + 10), Vector2(bottom.x, bottom.y - 10), 5.0, INK)
	return out


func _crate(bottom_left: Vector2, w: float, h: float, fruit: bool) -> String:
	var r := Rect2(bottom_left - Vector2(0, h), Vector2(w, h))
	var out := ""
	if fruit:
		for i: int in 5:
			out += _circle(Vector2(r.position.x + 40 + i * (w - 80) / 4.0, r.position.y - 4), 38.0, ORANGE, 9.0)
	out += _rect(r, WOOD_LIGHT, 6.0)
	out += _line(r.position + Vector2(8, h * 0.5), Vector2(r.end.x - 8, r.position.y + h * 0.5), 7.0, INK)
	out += _line(r.position + Vector2(14, 14), r.end - Vector2(14, 14), 8.0, INK)
	return out


func _basket(bottom: Vector2) -> String:
	var out := ""
	for i: int in 3:
		out += _path("M %s %s q 70 -90 140 0 z" % [_n(bottom.x - 150 + i * 90), _n(bottom.y - 130)], "#d9a05b", 9.0)
	out += _path("M %s %s L %s %s L %s %s L %s %s Z" % [_n(bottom.x - 170), _n(bottom.y - 140), _n(bottom.x + 170), _n(bottom.y - 140),
			_n(bottom.x + 130), _n(bottom.y), _n(bottom.x - 130), _n(bottom.y)], "#c98a3e")
	out += _line(Vector2(bottom.x - 150, bottom.y - 80), Vector2(bottom.x + 150, bottom.y - 80), 6.0, INK)
	return out


func _sack(bottom: Vector2, w: float) -> String:
	var h := w * 1.1
	var d := "M %s %s C %s %s %s %s %s %s C %s %s %s %s %s %s Z" % [
		_n(bottom.x - w * 0.5), _n(bottom.y),
		_n(bottom.x - w * 0.62), _n(bottom.y - h * 0.6), _n(bottom.x - w * 0.2), _n(bottom.y - h), _n(bottom.x), _n(bottom.y - h),
		_n(bottom.x + w * 0.2), _n(bottom.y - h), _n(bottom.x + w * 0.62), _n(bottom.y - h * 0.6), _n(bottom.x + w * 0.5), _n(bottom.y)]
	return _path(d, "#c9b07a") + _line(Vector2(bottom.x - w * 0.18, bottom.y - h * 0.8), Vector2(bottom.x + w * 0.18, bottom.y - h * 0.8), 12.0, INK)


func _cobbles(top: float, x0: float, x1: float) -> String:
	var out := _rect(Rect2(x0 - 20, top, x1 - x0 + 40, 200), "#4b4566", 0.0)
	var x := x0
	var row := 0
	while x < x1:
		out += _rect(Rect2(x + (row % 2) * 30, top + 14, 120, 44), "#6e6890", 14.0, 7.0)
		x += 150.0
		row += 1
	return out


func _bunting(a: Vector2, b: Vector2, sag: float) -> String:
	var mid := (a + b) * 0.5 + Vector2(0, sag)
	var out := _path("M %s %s Q %s %s %s %s" % [_n(a.x), _n(a.y), _n(mid.x), _n(mid.y), _n(b.x), _n(b.y)], "none", 9.0)
	var colors: PackedStringArray = [PINK, CYAN, YELLOW, GREEN]
	for i: int in 9:
		var t := (i + 0.5) / 9.0
		var p := a.lerp(mid, t).lerp(mid.lerp(b, t), t)
		out += _poly(PackedVector2Array([p + Vector2(-34, 0), p + Vector2(34, 0), p + Vector2(0, 80)]), colors[i % colors.size()], 8.0)
	return out


func _farolillos(a: Vector2, b: Vector2, sag: float) -> String:
	var mid := (a + b) * 0.5 + Vector2(0, sag)
	var out := _path("M %s %s Q %s %s %s %s" % [_n(a.x), _n(a.y), _n(mid.x), _n(mid.y), _n(b.x), _n(b.y)], "none", 9.0)
	var colors: PackedStringArray = [PINK, YELLOW, CYAN, ORANGE]
	for i: int in 6:
		var t := (i + 0.5) / 6.0
		var p := a.lerp(mid, t).lerp(mid.lerp(b, t), t) + Vector2(0, 50)
		out += _glow("f%d" % i, p, 110.0, colors[i % colors.size()], 0.35)
		out += _rect(Rect2(p - Vector2(40, 52), Vector2(80, 104)), colors[i % colors.size()], 34.0, 9.0)
		out += _line(p + Vector2(-40, -10), p + Vector2(40, -10), 5.0, INK) + _line(p + Vector2(-40, 18), p + Vector2(40, 18), 5.0, INK)
	return out


func _planter(bottom: Vector2, w: float) -> String:
	var out := ""
	for i: int in 5:
		var c := Vector2(bottom.x - w * 0.36 + i * w * 0.18, bottom.y - w * 0.62 - (i % 2) * 40)
		out += _circle(c, w * 0.17, LEAF, 9.0)
	for i: int in 4:
		out += _circle(Vector2(bottom.x - w * 0.3 + i * w * 0.2, bottom.y - w * 0.78 + (i % 2) * 50), w * 0.06, PINK, 7.0)
	out += _poly(PackedVector2Array([Vector2(bottom.x - w * 0.5, bottom.y - w * 0.5), Vector2(bottom.x + w * 0.5, bottom.y - w * 0.5),
			Vector2(bottom.x + w * 0.38, bottom.y), Vector2(bottom.x - w * 0.38, bottom.y)]), TERRACOTTA)
	return out


func _lamp_post(bottom: Vector2, h: float) -> String:
	var top := bottom - Vector2(0, h)
	var out := _glow("lamp%d" % int(bottom.x), top + Vector2(0, 40), 220.0, YELLOW, 0.4)
	out += _capsules([[bottom, top + Vector2(0, 80), 34.0]], IRON)
	out += _poly(PackedVector2Array([Vector2(bottom.x - 60, bottom.y), Vector2(bottom.x + 60, bottom.y), Vector2(bottom.x + 30, bottom.y - 70), Vector2(bottom.x - 30, bottom.y - 70)]), IRON)
	out += _poly(PackedVector2Array([top + Vector2(-50, 90), top + Vector2(50, 90), top + Vector2(66, -10), top + Vector2(-66, -10)]), "#fff0b0")
	out += _poly(PackedVector2Array([top + Vector2(-80, -10), top + Vector2(80, -10), top + Vector2(0, -80)]), IRON)
	return out


func _bench(bottom: Vector2) -> String:
	var out := _rect(Rect2(bottom + Vector2(-260, -150), Vector2(520, 40)), WOOD_LIGHT, 8.0)
	out += _rect(Rect2(bottom + Vector2(-260, -270), Vector2(520, 36)), WOOD_LIGHT, 8.0)
	for x: float in [-220.0, 200.0]:
		out += _rect(Rect2(bottom + Vector2(x, -110), Vector2(26, 110)), IRON, 4.0, 8.0)
		out += _rect(Rect2(bottom + Vector2(x, -280), Vector2(26, 140)), IRON, 4.0, 8.0)
	return out


func _bollard(bottom: Vector2) -> String:
	return _rect(Rect2(bottom + Vector2(-34, -170), Vector2(68, 170)), IRON, 30.0) + _line(bottom + Vector2(-30, -120), bottom + Vector2(30, -120), 10.0, BRASS)


## Caballete con una esfera de reloj (la relojería anuncia «arreglos»: sin letras).
func _sign_board(bottom: Vector2) -> String:
	var out := _poly(PackedVector2Array([bottom + Vector2(-120, 0), bottom + Vector2(-40, -360), bottom + Vector2(40, -360), bottom + Vector2(120, 0)]), WOOD)
	out += _clock_face(bottom + Vector2(0, -210), 80.0, true)
	return out


# --- Mapa, puntos interactivos y reloj ---------------------------------------------

func _map_relojeria() -> String:
	var out := _rect(Rect2(96, 210, 320, 260), VIOLET_WALL, 8.0, 14.0)
	out += _poly(PackedVector2Array([Vector2(64, 214), Vector2(256, 70), Vector2(448, 214)]), ROOF, 14.0)
	out += _clock_face(Vector2(256, 300), 84.0, true)
	out += _rect(Rect2(216, 390, 80, 80), WOOD, 6.0, 12.0)
	return out


func _map_mercado() -> String:
	var out := _rect(Rect2(90, 300, 332, 160), WOOD_LIGHT, 8.0, 14.0)
	for i: int in 6:
		out += _poly(PackedVector2Array([Vector2(70 + i * 62, 180), Vector2(132 + i * 62, 180), Vector2(132 + i * 62, 270), Vector2(70 + i * 62, 270)]),
				PINK if i % 2 == 0 else CREAM, 12.0)
	for x: float in [100.0, 412.0]:
		out += _line(Vector2(x, 270), Vector2(x, 300), 16.0, INK)
	for i: int in 4:
		out += _circle(Vector2(150 + i * 70, 290), 30.0, ORANGE, 10.0)
	out += _line(Vector2(120, 380), Vector2(392, 380), 10.0, INK)
	return out


func _map_plaza() -> String:
	var out := ""
	# Banderines de la fiesta colgando de la torre a los dos lados.
	for side: float in [-1.0, 1.0]:
		var a := Vector2(256 + side * 40, 170)
		var b := Vector2(256 + side * 220, 250)
		out += _line(a, b, 8.0, INK)
		for i: int in 3:
			var p := a.lerp(b, (i + 0.6) / 3.4)
			out += _poly(PackedVector2Array([p + Vector2(-20, 0), p + Vector2(20, 0), p + Vector2(0, 44)]), [PINK, YELLOW, CYAN][i], 6.0)
	out += _rect(Rect2(206, 140, 100, 300), VIOLET_WALL_2, 6.0, 14.0)
	out += _poly(PackedVector2Array([Vector2(186, 144), Vector2(256, 40), Vector2(326, 144)]), ROOF, 14.0)
	out += _clock_face(Vector2(256, 220), 40.0, true)
	out += _rect(Rect2(110, 440, 292, 40), "#6e6890", 6.0, 14.0)
	out += _rect(Rect2(150, 400, 212, 40), "#8a84ad", 6.0, 14.0)
	return out


func _map_unexplored() -> String:
	var out := _glow("fog", Vector2(256, 300), 220.0, "#c9c0ea", 0.35)
	out += _path("M 120 440 L 120 250 L 256 140 L 392 250 L 392 440 Z", "#5d5878", 14.0, "stroke-dasharray=\"30 22\"")
	out += _rect(Rect2(226, 350, 60, 90), "#45405e", 6.0, 10.0)
	return out


## Mirada de Sazil: un ojo (ve a la gente).
func _hotspot_look() -> String:
	var out := _path("M 28 128 Q 128 28 228 128 Q 128 228 28 128 Z", CREAM, 14.0)
	out += _circle(Vector2(128, 128), 46.0, CYAN, 10.0)
	out += _circle(Vector2(128, 128), 18.0, INK, 0.0)
	out += _circle(Vector2(142, 112), 9.0, "#ffffff", 0.0)
	return out


## Fisura de Akba: una grieta en rombo, verde con el filo carmesí.
func _hotspot_fissure() -> String:
	var out := _glow("fg", Vector2(128, 128), 128.0, GREEN, 0.45)
	out += _poly(PackedVector2Array([Vector2(128, 18), Vector2(162, 92), Vector2(232, 128), Vector2(162, 164), Vector2(128, 238),
			Vector2(94, 164), Vector2(24, 128), Vector2(94, 92)]), GREEN, 14.0)
	out += _polyline(PackedVector2Array([Vector2(128, 50), Vector2(112, 100), Vector2(144, 132), Vector2(116, 170), Vector2(128, 206)]), CRIMSON, 12.0)
	return out


## Esfera de reloj sin agujas (las agujas, si hacen falta, las dibuja el código).
## `small`: con agujas fijas a las 10:10 para iconos.
func _clock_face(c: Vector2, r: float, small: bool) -> String:
	var out := ""
	if not small:
		out += _circle(c, r, VIOLET, r * 0.035)
		# Flechas de rebobinar (sentido contrario a las agujas) en el aro.
		for i: int in 4:
			var a := TAU * i / 4.0 + 0.4
			var p := c + Vector2.RIGHT.rotated(a) * r * 0.92
			var back := Vector2.RIGHT.rotated(a).orthogonal()
			out += _poly(PackedVector2Array([p + back * r * 0.07, p - back * r * 0.05 + Vector2.RIGHT.rotated(a) * r * 0.06,
					p - back * r * 0.05 - Vector2.RIGHT.rotated(a) * r * 0.06]), YELLOW, r * 0.012)
	var face := r * (0.84 if not small else 1.0)
	out += _circle(c, face, CREAM, maxf(r * 0.03, 8.0))
	for i: int in 12:
		var d := Vector2.UP.rotated(TAU * i / 12.0)
		var long := i % 3 == 0
		out += _line(c + d * face * (0.72 if long else 0.8), c + d * face * 0.9, face * (0.07 if long else 0.035), INK)
	if small:
		out += _line(c, c + Vector2.UP.rotated(-PI / 3.0) * face * 0.5, face * 0.1, INK)
		out += _line(c, c + Vector2.UP.rotated(PI / 3.0) * face * 0.7, face * 0.07, INK)
	out += _circle(c, maxf(face * 0.07, 6.0), INK, 0.0)
	return out


# --- Finales, icono y arranque ----------------------------------------------------

func _skyline(base: float, width: float, color: String, seed_offset: int) -> String:
	var out := ""
	var x := -20.0
	var i := seed_offset
	while x < width:
		var w := 110.0 + (i * 37 % 70)
		var h := 120.0 + (i * 53 % 140)
		out += _poly(PackedVector2Array([Vector2(x, base), Vector2(x, base - h), Vector2(x + w * 0.5, base - h - 50), Vector2(x + w, base - h), Vector2(x + w, base)]), color, 8.0)
		if i % 2 == 0:
			out += _rect(Rect2(x + w * 0.35, base - h + 40, w * 0.3, 40), YELLOW, 4.0, 6.0)
		x += w - 6.0
		i += 1
	return out


func _stars(area: Rect2, count: int) -> String:
	var out := ""
	for i: int in count:
		var p := area.position + Vector2(fmod(i * 197.3, area.size.x), fmod(i * 83.7 + (i % 7) * 41.0, area.size.y))
		out += _circle(p, 4.0 + (i % 3) * 2.0, "#fff7d6", 0.0)
	return out


func _figure(bottom: Vector2, h: float, accent: String) -> String:
	var out := _path("M %s %s Q %s %s %s %s Q %s %s %s %s Z" % [_n(bottom.x - h * 0.22), _n(bottom.y), _n(bottom.x - h * 0.2), _n(bottom.y - h * 0.7),
			_n(bottom.x), _n(bottom.y - h * 0.72), _n(bottom.x + h * 0.2), _n(bottom.y - h * 0.7), _n(bottom.x + h * 0.22), _n(bottom.y)], "#1b1530", 8.0)
	out += _circle(bottom - Vector2(0, h * 0.84), h * 0.15, "#1b1530", 8.0)
	out += _circle(bottom - Vector2(-h * 0.2, h * 0.45), h * 0.08, accent, 7.0)
	return out


## «Un buen día»: la fiesta de la Unión, farolillos y fuegos sobre la plaza.
func _ending_good_day() -> String:
	var out := _sky(Vector2(1080, 720), "#241b4a", "#5a3a8c")
	out += _stars(Rect2(0, 0, 1080, 300), 40)
	for burst: Array in [[Vector2(250, 170), PINK], [Vector2(640, 120), YELLOW], [Vector2(900, 220), CYAN]]:
		var c: Vector2 = burst[0]
		for i: int in 14:
			var d := Vector2.RIGHT.rotated(TAU * i / 14.0)
			out += _line(c + d * 30.0, c + d * 95.0, 9.0, burst[1])
	out += _skyline(560.0, 1080.0, "#2b2150", 3)
	out += _farolillos(Vector2(-20, 330), Vector2(1100, 330), 90.0)
	out += _rect(Rect2(-20, 560, 1120, 180), "#3a2f5e", 0.0, 10.0)
	out += _figure(Vector2(400, 650), 230.0, ORANGE)
	out += _figure(Vector2(540, 660), 250.0, CYAN)
	out += _figure(Vector2(690, 650), 220.0, YELLOW)
	return out


## «Otra vez»: la ciudad se dobla como un papel bajo el reloj que vuelve atrás.
func _ending_again() -> String:
	var out := _sky(Vector2(1080, 720), "#0f0b24", "#2c2058")
	out += _stars(Rect2(0, 0, 1080, 420), 50)
	out += _clock_face(Vector2(540, 250), 200.0, false)
	out += _line(Vector2(540, 250), Vector2(540, 250) + Vector2.UP.rotated(PI / 3.0) * 90.0, 16.0, INK)
	out += _line(Vector2(540, 250), Vector2(540, 120), 11.0, INK)
	out += "<g transform=\"rotate(-9 540 720)\">" + _skyline(720.0, 560.0, "#2b2150", 1) + "</g>"
	out += "<g transform=\"rotate(9 540 720) translate(540 0)\">" + _skyline(720.0, 560.0, "#3d2d78", 5) + "</g>"
	out += _line(Vector2(540, 470), Vector2(540, 720), 10.0, GREEN, "stroke-dasharray=\"24 18\"")
	return out


## Icono: el reloj a medianoche partido por una fisura del Umbral.
func _app_icon() -> String:
	var out := _sky(Vector2(1024, 1024), "#2c2058", "#120d2a")
	out += _glow("halo", Vector2(512, 540), 470.0, GREEN, 0.35)
	out += _circle(Vector2(512, 540), 330.0, CREAM, 26.0)
	for i: int in 12:
		var d := Vector2.UP.rotated(TAU * i / 12.0)
		out += _line(Vector2(512, 540) + d * 250.0, Vector2(512, 540) + d * 296.0, 26.0 if i % 3 == 0 else 14.0, INK)
	out += _line(Vector2(512, 540), Vector2(512, 300), 34.0, INK)
	out += _line(Vector2(512, 540), Vector2(512, 380), 46.0, INK)
	out += _polyline(PackedVector2Array([Vector2(330, 250), Vector2(450, 430), Vector2(400, 560), Vector2(560, 700), Vector2(520, 860)]), GREEN, 34.0)
	out += _polyline(PackedVector2Array([Vector2(330, 250), Vector2(450, 430), Vector2(400, 560), Vector2(560, 700), Vector2(520, 860)]), CRIMSON, 10.0)
	out += _circle(Vector2(512, 540), 30.0, INK, 0.0)
	out += _path("M 760 180 A 90 90 0 1 0 840 300 A 70 70 0 1 1 760 180 Z", YELLOW, 14.0)
	return out


## Pantalla de arranque: la noche de Much y el reloj de medianoche, sin letras.
func _splash() -> String:
	var out := _sky(Vector2(1080, 1920), "#0f0b24", "#3d2d78")
	out += _stars(Rect2(0, 0, 1080, 1200), 90)
	out += _glow("halo", Vector2(540, 820), 520.0, GREEN, 0.3)
	out += _circle(Vector2(540, 820), 300.0, CREAM, 24.0)
	for i: int in 12:
		var d := Vector2.UP.rotated(TAU * i / 12.0)
		out += _line(Vector2(540, 820) + d * 226.0, Vector2(540, 820) + d * 268.0, 24.0 if i % 3 == 0 else 12.0, INK)
	out += _line(Vector2(540, 820), Vector2(540, 600), 30.0, INK)
	out += _line(Vector2(540, 820), Vector2(540, 670), 42.0, INK)
	out += _polyline(PackedVector2Array([Vector2(380, 560), Vector2(480, 720), Vector2(440, 840), Vector2(580, 970), Vector2(540, 1110)]), GREEN, 30.0)
	out += _polyline(PackedVector2Array([Vector2(380, 560), Vector2(480, 720), Vector2(440, 840), Vector2(580, 970), Vector2(540, 1110)]), CRIMSON, 9.0)
	out += _circle(Vector2(540, 820), 28.0, INK, 0.0)
	out += _skyline(1920.0, 1080.0, "#1b1530", 2)
	out += _skyline(1990.0, 1080.0, "#2b2150", 7)
	return out
