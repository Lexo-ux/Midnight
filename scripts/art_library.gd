extends RefCounted
## Las ranuras de arte del juego (data/art_manifest.json): fondos, capas y
## superposición de Akba de cada lugar, retratos y manos de los protagonistas.
##
## El arte de verdad llega más tarde (scripts/dev/ingest_art.gd lo prepara en
## assets/art/). Mientras falte, por orden:
##   1. si la ranura es `"provisional": true` y existe su imagen provisional
##      (assets/art_provisional/<misma ruta>, la genera
##      scripts/dev/make_placeholder_art.gd), se usa esa;
##   2. si no, la UI dibuja un provisional y aquí se avisa UNA vez por ranura y
##      sesión. Excepción: la capa `mid` es opcional; si un lugar ya tiene
##      fondos de verdad y no tiene `mid` (ni provisional), no se dibuja nada y
##      no se avisa.
## El arte de verdad siempre gana: al ingerirlo, el provisional deja de usarse
## sin tocar código.
##
## Las texturas de los lugares se cargan solo al entrar en uno y se sueltan al
## cambiar de lugar (memoria de un Android de gama media).

const MANIFEST_PATH: String = "res://data/art_manifest.json"
const KINDS: PackedStringArray = ["opaque", "cutout", "additive"]
const FALLBACKS: PackedStringArray = ["placeholder", "placeholder_unless_real_bg", "silhouette"]
const PLACE_LAYERS: PackedStringArray = ["bg_day", "bg_dusk", "bg_night", "mid", "fg", "akba_overlay"]
const BG_LAYERS: PackedStringArray = ["bg_day", "bg_dusk", "bg_night"]
const EXTENSIONS: Dictionary = {"opaque": ["jpg", "png", "webp"], "cutout": ["png", "webp"], "additive": ["jpg", "png", "webp"]}

var errors: PackedStringArray = []
var root: String = ""
var incoming: String = ""
## Carpeta de los provisionales generados (misma ruta relativa que el arte de verdad).
var provisional_root: String = ""
var ratio_tolerance: float = 0.02
var jpg_quality: float = 0.9
var budget_mb: int = 60
## id -> {id, path, relative, size, kind, fallback, provisional, place, layer, actor, pose, hand_state, ending, focus}
var slots: Dictionary = {}
var slot_ids: Array[String] = []
## Ranuras de las que ya se avisó en esta sesión.
var warned: Dictionary = {}

var _place: String = ""
## capa -> {texture: Texture2D o null, placeholder: bool} del lugar actual.
var _place_layers: Dictionary = {}
## Retratos y manos (pocos y pequeños): se quedan cargados.
var _small: Dictionary = {}


func load_manifest(path: String = MANIFEST_PATH) -> bool:
	var json := JSON.new()
	if not FileAccess.file_exists(path) or json.parse(FileAccess.get_file_as_string(path)) != OK:
		errors = ["%s: no existe o no es JSON válido." % path]
		push_error("[ArtLibrary] " + errors[0])
		return false
	return load_source(json.data)


## Valida un manifiesto ya parseado. Los errores quedan en `errors`.
func load_source(source: Variant) -> bool:
	errors = []
	slots.clear()
	slot_ids.clear()
	release_place()
	_small.clear()
	if not source is Dictionary:
		errors.append("art_manifest.json: la raíz debe ser un objeto.")
		return _fail()
	root = str(source.get("root", ""))
	incoming = str(source.get("incoming", ""))
	provisional_root = str(source.get("provisional_root", ""))
	ratio_tolerance = float(source.get("ratio_tolerance", 0.02))
	jpg_quality = float(source.get("jpg_quality", 0.9))
	budget_mb = int(source.get("budget_mb", 60))
	if not root.begins_with("res://") or not root.ends_with("/") or not incoming.begins_with("res://"):
		errors.append("art_manifest.json: \"root\" e \"incoming\" deben ser carpetas res://.../")
	if provisional_root != "" and (not provisional_root.begins_with("res://") or not provisional_root.ends_with("/")):
		errors.append("art_manifest.json: \"provisional_root\" debe ser una carpeta res://.../")
	var paths: Dictionary = {}
	var list: Variant = source.get("slots")
	if not list is Array or list.is_empty():
		errors.append("art_manifest.json: \"slots\" debe ser una lista.")
		return _fail()
	for i: int in list.size():
		var slot := _parse_slot(list[i], "art_manifest.json, ranura #%d" % i)
		if slot.is_empty():
			continue
		if slots.has(slot["id"]):
			errors.append("art_manifest.json: la ranura \"%s\" está repetida." % slot["id"])
			continue
		if paths.has(slot["path"]):
			errors.append("art_manifest.json: la ruta \"%s\" está repetida." % slot["path"])
		paths[slot["path"]] = true
		slots[slot["id"]] = slot
		slot_ids.append(slot["id"])
	if not errors.is_empty():
		return _fail()
	return true


func is_loaded() -> bool:
	return not slots.is_empty()


## Ranura de una capa de un lugar ("relojeria", "bg_day" -> "relojeria_bg_day").
static func place_slot(place: String, layer: String) -> String:
	return "%s_%s" % [place, layer]


static func portrait_slot(actor: String, pose: String) -> String:
	return "portrait_%s_%s" % [actor, pose]


static func hands_slot(actor: String, state: String) -> String:
	return "hands_%s_%s" % [actor, state]


## Cara de un habitante con Velo 2 (rostro) o 3 (retrato).
static func face_slot(person: String, level: int) -> String:
	return "npc_%s_velo%d" % [person, level]


## Hay arte de verdad para la ranura.
func has_file(slot_id: String) -> bool:
	return slots.has(slot_id) and ResourceLoader.exists(slots[slot_id]["path"])


## Ruta del provisional generado de la ranura ("" si no es provisional).
func provisional_path(slot_id: String) -> String:
	if not slots.has(slot_id) or not slots[slot_id]["provisional"] or provisional_root == "":
		return ""
	return provisional_root + slots[slot_id]["relative"]


func has_provisional(slot_id: String) -> bool:
	var path := provisional_path(slot_id)
	return path != "" and ResourceLoader.exists(path)


## Lo que se usa para la ranura: el arte de verdad, si no su provisional, si no "".
func resolve_path(slot_id: String) -> String:
	if has_file(slot_id):
		return slots[slot_id]["path"]
	if has_provisional(slot_id):
		return provisional_path(slot_id)
	return ""


## "real", "provisional" (imagen generada) o "drawn" (se dibuja en código).
func source_of(slot_id: String) -> String:
	if has_file(slot_id):
		return "real"
	return "provisional" if has_provisional(slot_id) else "drawn"


## Textura de cualquier ranura (null si no hay ni arte ni provisional; sin aviso).
func texture_for(slot_id: String) -> Texture2D:
	var path := resolve_path(slot_id)
	return load(path) as Texture2D if path != "" else null


## Los tres fondos de `place` tienen arte de verdad.
func uses_real_bg(place: String) -> bool:
	for layer: String in BG_LAYERS:
		if not has_file(place_slot(place, layer)):
			return false
	return true


## Entra en `place`: carga sus capas y suelta las del lugar anterior.
## Devuelve {capa: {texture, placeholder}}. `texture` null + `placeholder`
## false significa «no dibujar nada» (solo pasa con `mid`).
func enter_place(place: String) -> Dictionary:
	if place == _place:
		return _place_layers
	release_place()
	_place = place
	var real_bg := uses_real_bg(place)
	for layer: String in PLACE_LAYERS:
		var slot_id := place_slot(place, layer)
		if not slots.has(slot_id):
			_place_layers[layer] = {"texture": null, "placeholder": true}
			continue
		var path := resolve_path(slot_id)
		if path != "":
			_place_layers[layer] = {"texture": load(path) as Texture2D, "placeholder": false}
		elif slots[slot_id]["fallback"] == "placeholder_unless_real_bg" and real_bg:
			_place_layers[layer] = {"texture": null, "placeholder": false}
		else:
			_warn_missing(slot_id)
			_place_layers[layer] = {"texture": null, "placeholder": true}
	return _place_layers


func release_place() -> void:
	_place = ""
	_place_layers = {}


func current_place() -> String:
	return _place


## Retrato o manos: la textura, o null (y un aviso la primera vez) si falta.
func small_texture(slot_id: String) -> Texture2D:
	if _small.has(slot_id):
		return _small[slot_id]
	var found: Texture2D = null
	var path := resolve_path(slot_id)
	if path != "":
		found = load(path) as Texture2D
	elif slots.has(slot_id):
		_warn_missing(slot_id)
	_small[slot_id] = found
	return found


## Recorte de la cara de un retrato, en píxeles de la textura.
func focus_region(slot_id: String, texture: Texture2D) -> Rect2:
	var focus: Rect2 = slots[slot_id]["focus"]
	var size := Vector2(texture.get_width(), texture.get_height())
	return Rect2(focus.position * size, focus.size * size)


func _warn_missing(slot_id: String) -> void:
	if warned.has(slot_id):
		return
	warned[slot_id] = true
	push_warning("[ArtLibrary] Falta el arte \"%s\" (%s): se usa el provisional." % [slot_id, slots[slot_id]["path"]])


func _parse_slot(raw: Variant, where: String) -> Dictionary:
	if not raw is Dictionary:
		errors.append(where + " debe ser un objeto.")
		return {}
	var id: Variant = raw.get("id")
	if not id is String or not id.is_valid_identifier() or id != id.to_lower():
		errors.append("%s: \"id\" debe ser un nombre en snake_case (\"%s\")." % [where, id])
		return {}
	where = "art_manifest.json, \"%s\"" % id
	var relative: Variant = raw.get("path")
	var kind: Variant = raw.get("kind")
	if not KINDS.has(kind):
		errors.append("%s: \"kind\" debe ser uno de %s." % [where, KINDS])
		return {}
	if not relative is String or not _path_ok(relative, kind):
		errors.append("%s: ruta mal formada \"%s\" (relativa, snake_case, sin \"..\", extensión %s)." % [where, relative, EXTENSIONS[kind]])
		return {}
	var size: Variant = raw.get("size")
	if not size is Array or size.size() != 2 or not size.all(func(v: Variant) -> bool: return (v is int or v is float) and v >= 1):
		errors.append(where + ": \"size\" debe ser [ancho, alto].")
		return {}
	if not FALLBACKS.has(raw.get("fallback")):
		errors.append("%s: \"fallback\" debe ser uno de %s." % [where, FALLBACKS])
		return {}
	if not raw.get("provisional", false) is bool:
		errors.append(where + ": \"provisional\" debe ser true o false.")
		return {}
	var focus := Rect2(0.275, 0.0, 0.45, 0.45)
	if raw.has("focus"):
		var values: Variant = raw["focus"]
		if not values is Array or values.size() != 4 or not values.all(func(v: Variant) -> bool: return (v is int or v is float) and v >= 0.0 and v <= 1.0) \
				or values[0] + values[2] > 1.0 or values[1] + values[3] > 1.0 or values[2] <= 0 or values[3] <= 0:
			errors.append(where + ": \"focus\" debe ser [x, y, ancho, alto] en fracciones de la imagen.")
			return {}
		focus = Rect2(values[0], values[1], values[2], values[3])
	return {"id": id, "path": root + relative, "relative": relative, "size": Vector2i(int(size[0]), int(size[1])), "kind": kind,
			"fallback": raw["fallback"], "provisional": raw.get("provisional", false), "place": raw.get("place", ""),
			"layer": raw.get("layer", ""), "actor": raw.get("actor", ""), "pose": raw.get("pose", ""),
			"hand_state": raw.get("hand_state", ""), "ending": raw.get("ending", ""), "focus": focus}


static func _path_ok(path: String, kind: String) -> bool:
	if path.begins_with("/") or path.contains("..") or path.contains("\\") or path.contains(" ") or path != path.to_lower():
		return false
	return EXTENSIONS[kind].has(path.get_extension())


func _fail() -> bool:
	for message: String in errors:
		push_error("[ArtLibrary] " + message)
	slots.clear()
	slot_ids.clear()
	return false
