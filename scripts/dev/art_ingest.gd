extends RefCounted
## Prepara el arte que deja el dueño en assets/art_incoming/ (ver
## docs/art_pipeline.md). Cada archivo se llama como su ranura del manifiesto
## (`<id>.png`, también .jpg/.jpeg/.webp). Por ranura:
##   - comprueba la proporción (dentro de la tolerancia se estira al tamaño exacto;
##     si no, se informa y no se toca);
##   - redimensiona al tamaño del manifiesto (Lanczos);
##   - `cutout`: convierte el fondo magenta en transparencia (ver key_magenta());
##   - `additive`: solo redimensiona (el negro suma cero);
##   - escribe en assets/art/ y, la primera vez, sus ajustes de importación.
## Es idempotente: si la salida es más nueva que la entrada, no la rehace.
## Con `dry_run` no escribe nada: dice qué haría (para comprobar el canal antes
## de dejar el arte de verdad), qué ranuras usan aún su provisional y, de los
## archivos sin ranura, a cuál se parecen (no los renombra).

const ArtLibrary := preload("res://scripts/art_library.gd")
const INCOMING_EXTENSIONS: PackedStringArray = ["png", "jpg", "jpeg", "webp"]

## Fondo «seguro»: min(R, B) - G por encima de esto (0-255), con R y B altos.
## Cubre de #E010C8 a #FF00FF; el pelo rosa pálido, la piel o las flores malva
## no llegan (tienen G alto o R y B bajos).
const STRICT_MAGENTA: int = 90
const STRICT_RED: int = 150
const STRICT_BLUE: int = 140
## Bolsas de fondo encerradas (entre un brazo y el cuerpo, o huecos del trazo
## del abrigo): solo magenta casi puro, como el fondo, desde unos pocos píxeles.
## Un pétalo malva claro (G alto) nunca lo es, aunque el JPEG lo ensucie.
const POCKET_MAGENTA: int = 180
const POCKET_MAX_GREEN: int = 40
const POCKET_MIN_PIXELS: int = 4
## Borde mezclado: píxeles con algo de magenta junto al fondo.
const SOFT_MAGENTA: int = 8
## Ancho de la franja de bordes mezclados, en fracción del ancho de la imagen.
const SOFT_BAND_FRACTION: float = 1.0 / 128.0
## Mezcla fondo + oscuro: rojo y azul en la misma proporción que el fondo y el
## verde sin subir más que esto (0-255).
const MIX_BALANCE: float = 0.12
const MIX_GREEN: float = 24.0
## Halo de luz sobre el fondo (el brillo del colgante): casi todo es fondo.
const HALO_SHARE: float = 0.85
## Alfa por debajo del cual el borde es fondo, y por encima del cual ya es dibujo.
const EDGE_CLEAR: float = 0.02
const EDGE_SOLID: float = 0.9
## Recortes más grandes que esto (en píxeles) se importan con compresión VRAM.
const LARGE_CUTOUT_PIXELS: int = 2_000_000
## Palabras con que suele llegar un archivo mal nombrado -> capa de un lugar.
const LAYER_ALIASES: Dictionary = {
	"objects": "fg", "objetos": "fg", "props": "fg", "foreground": "fg", "primer_plano": "fg", "front": "fg",
	"middle": "mid", "medio": "mid", "midground": "mid", "overlay": "akba_overlay", "cracks": "akba_overlay",
	"grietas": "akba_overlay", "dia": "bg_day", "day": "bg_day", "dusk": "bg_dusk", "atardecer": "bg_dusk",
	"night": "bg_night", "noche": "bg_night",
}

var library: ArtLibrary
## Rehacer aunque la salida sea más nueva que la entrada.
var force: bool = false
## Solo comprobar: no escribe nada.
var dry_run: bool = false


func _init(art_library: ArtLibrary) -> void:
	library = art_library


## Procesa todo `incoming_dir` hacia `output_root` (res:// o ruta absoluta).
## Devuelve {ingested, up_to_date, present, missing, provisional, mismatched,
## unmatched, failed, bytes} (con `dry_run`, «ingested» es lo que se ingeriría).
## `provisional`: ranuras sin arte de verdad que hoy enseñan su provisional.
## `unmatched`: «archivo» o «archivo → ¿ranura?».
func run(incoming_dir: String, output_root: String) -> Dictionary:
	var report: Dictionary = {"ingested": [], "up_to_date": [], "present": [], "missing": [], "provisional": [],
			"mismatched": [], "unmatched": [], "failed": [], "bytes": 0}
	var files := _incoming_files(ProjectSettings.globalize_path(incoming_dir))
	for name: String in files:
		if not library.slots.has(name):
			var hint := suggest_slot(library, name)
			report["unmatched"].append(files[name].get_file() + (" → ¿%s?" % hint if hint != "" else ""))
	var output_abs := ProjectSettings.globalize_path(output_root)
	for slot_id: String in library.slot_ids:
		var slot: Dictionary = library.slots[slot_id]
		var out_path := output_abs.path_join(slot["relative"])
		if files.has(slot_id):
			var source: String = files[slot_id]
			if not force and FileAccess.file_exists(out_path) \
					and FileAccess.get_modified_time(out_path) >= FileAccess.get_modified_time(source):
				report["up_to_date"].append(slot_id)
			else:
				var problem := check_file(source, slot) if dry_run else ingest_file(source, slot, out_path)
				if problem == "":
					report["ingested"].append(slot_id)
					if output_root.begins_with("res://") and not dry_run:
						write_import_settings(output_root + slot["relative"], slot)
				elif problem.begins_with("proporción"):
					report["mismatched"].append("%s: %s" % [slot_id, problem])
				else:
					report["failed"].append("%s: %s" % [slot_id, problem])
		elif FileAccess.file_exists(out_path):
			report["present"].append(slot_id)
		else:
			report["missing"].append(slot_id)
			if library.has_provisional(slot_id):
				report["provisional"].append(slot_id)
		if FileAccess.file_exists(out_path):
			var file := FileAccess.open(out_path, FileAccess.READ)
			report["bytes"] += file.get_length()
	return report


## Lo que diría ingest_file() sin escribir nada: "" o el problema.
func check_file(source_path: String, slot: Dictionary) -> String:
	var image := Image.load_from_file(source_path)
	if image == null or image.is_empty():
		return "no se pudo leer %s" % source_path.get_file()
	var target: Vector2i = slot["size"]
	var mismatch := ratio_mismatch(image.get_size(), target)
	if mismatch > library.ratio_tolerance:
		return "proporción %dx%d, se esperaba %dx%d (se desvía un %.1f %%)" % [image.get_width(), image.get_height(),
				target.x, target.y, mismatch * 100.0]
	return ""


## Ranura que probablemente quería ser el archivo `name` ("" si no se sabe):
## por el lugar y la capa que nombra (p. ej. «objects» con «plaza» → plaza_fg;
## sin lugar, las de esa capa que aún no tienen arte), o la de nombre más parecido.
static func suggest_slot(art: ArtLibrary, name: String) -> String:
	var lower := name.to_lower().replace("-", "_").replace(" ", "_")
	var layer := ""
	for word: String in LAYER_ALIASES:
		if lower.contains(word):
			layer = LAYER_ALIASES[word]
	if layer != "":
		var named: PackedStringArray = []
		var free: PackedStringArray = []
		for slot_id: String in art.slot_ids:
			var slot: Dictionary = art.slots[slot_id]
			if slot["layer"] != layer:
				continue
			if slot["place"] != "" and lower.contains(slot["place"]):
				named.append(slot_id)
			elif not art.has_file(slot_id):
				free.append(slot_id)
		if not named.is_empty():
			return " / ".join(named)
		if not free.is_empty():
			return " / ".join(free)
	var best := ""
	var best_score := 0.5
	for slot_id: String in art.slot_ids:
		var score := lower.similarity(slot_id)
		if score > best_score:
			best_score = score
			best = slot_id
	return best


## Una imagen hacia una ranura. Devuelve "" o el problema.
func ingest_file(source_path: String, slot: Dictionary, out_path: String) -> String:
	var image := Image.load_from_file(source_path)
	if image == null or image.is_empty():
		return "no se pudo leer %s" % source_path.get_file()
	var target: Vector2i = slot["size"]
	var mismatch := ratio_mismatch(image.get_size(), target)
	if mismatch > library.ratio_tolerance:
		return "proporción %dx%d, se esperaba %dx%d (se desvía un %.1f %%)" % [image.get_width(), image.get_height(),
				target.x, target.y, mismatch * 100.0]
	var cutout: bool = slot["kind"] == "cutout"
	image.convert(Image.FORMAT_RGBA8 if cutout else Image.FORMAT_RGB8)
	if image.get_size() != target:
		image.resize(target.x, target.y, Image.INTERPOLATE_LANCZOS)
	if cutout:
		key_magenta(image)
	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	var error: Error
	match out_path.get_extension():
		"png":
			error = image.save_png(out_path)
		"webp":
			error = image.save_webp(out_path, false)
		_:
			error = image.save_jpg(out_path, library.jpg_quality)
	return "" if error == OK else "no se pudo escribir (%s)" % error_string(error)


## Cuánto se desvía la proporción de `size` de la de `target` (0.01 = 1 %).
static func ratio_mismatch(size: Vector2i, target: Vector2i) -> float:
	var ratio := float(size.x) / float(size.y)
	var expected := float(target.x) / float(target.y)
	return absf(ratio / expected - 1.0)


## Fondo magenta -> transparente, en tres pasos:
##   1. Relleno desde el borde de la imagen por el magenta «seguro» (así lo rosa
##      o malva DENTRO del dibujo nunca se toca, aunque se parezca).
##   2. Bolsas de magenta muy puro encerradas (entre brazo y cuerpo).
##   3. Franja de bordes mezclados pegada al fondo: donde el píxel es fondo más
##      trazo oscuro, o casi solo fondo con un halo de luz (el brillo verde del
##      colgante de Akba), se resta el magenta del fondo vecino y queda el color
##      del dibujo con su alfa. Los rellenos malva o morados no se tocan.
static func key_magenta(image: Image) -> void:
	var w := image.get_width()
	var h := image.get_height()
	var pixels := image.get_data()
	var count := w * h
	# 0 dibujo, 1 fondo, 2 borde de trazo, 3 halo de luz.
	var state := PackedByteArray()
	state.resize(count)
	var queue := PackedInt32Array()
	for x: int in w:
		_seed_strict(pixels, state, queue, x)
		_seed_strict(pixels, state, queue, (h - 1) * w + x)
	for y: int in h:
		_seed_strict(pixels, state, queue, y * w)
		_seed_strict(pixels, state, queue, y * w + w - 1)
	_flood(pixels, state, queue, w, h, STRICT_MAGENTA)
	_key_pockets(pixels, state, w, h)
	_soften_edges(pixels, state, w, h, maxi(3, int(w * SOFT_BAND_FRACTION)))
	for i: int in count:
		if state[i] == 1:
			pixels[i * 4 + 3] = 0
	image.set_data(w, h, false, Image.FORMAT_RGBA8, pixels)


static func _magenta(pixels: PackedByteArray, i: int) -> int:
	var p := i * 4
	return mini(pixels[p], pixels[p + 2]) - pixels[p + 1]


static func _strict(pixels: PackedByteArray, i: int, threshold: int) -> bool:
	var p := i * 4
	return pixels[p] >= STRICT_RED and pixels[p + 2] >= STRICT_BLUE and _magenta(pixels, i) > threshold


static func _pocket(pixels: PackedByteArray, i: int) -> bool:
	return pixels[i * 4 + 1] <= POCKET_MAX_GREEN and _strict(pixels, i, POCKET_MAGENTA)


static func _seed_strict(pixels: PackedByteArray, state: PackedByteArray, queue: PackedInt32Array, i: int) -> void:
	if state[i] == 0 and _strict(pixels, i, STRICT_MAGENTA):
		state[i] = 1
		queue.append(i)


## Relleno 4-conexo desde `queue` por el magenta que pase de `threshold`.
static func _flood(pixels: PackedByteArray, state: PackedByteArray, queue: PackedInt32Array, w: int, h: int, threshold: int) -> void:
	var head := 0
	while head < queue.size():
		var i := queue[head]
		head += 1
		var x := i % w
		var neighbours: PackedInt32Array = [i - w if i >= w else -1, i + w if i + w < w * h else -1,
				i - 1 if x > 0 else -1, i + 1 if x + 1 < w else -1]
		for j: int in neighbours:
			if j >= 0 and state[j] == 0 and _strict(pixels, j, threshold):
				state[j] = 1
				queue.append(j)


static func _key_pockets(pixels: PackedByteArray, state: PackedByteArray, w: int, h: int) -> void:
	var visited := PackedByteArray()
	visited.resize(w * h)
	for start: int in w * h:
		if state[start] != 0 or visited[start] == 1 or not _pocket(pixels, start):
			continue
		var component := PackedInt32Array([start])
		visited[start] = 1
		var head := 0
		while head < component.size():
			var i := component[head]
			head += 1
			var x := i % w
			var neighbours: PackedInt32Array = [i - w if i >= w else -1, i + w if i + w < w * h else -1,
					i - 1 if x > 0 else -1, i + 1 if x + 1 < w else -1]
			for j: int in neighbours:
				if j >= 0 and state[j] == 0 and visited[j] == 0 and _pocket(pixels, j):
					visited[j] = 1
					component.append(j)
		if component.size() >= POCKET_MIN_PIXELS:
			for i: int in component:
				state[i] = 1


static func _soften_edges(pixels: PackedByteArray, state: PackedByteArray, w: int, h: int, band: int) -> void:
	var count := w * h
	# Cada píxel del borde recuerda de qué píxel de fondo toma el color a restar.
	var source := PackedInt32Array()
	source.resize(count)
	var distance := PackedByteArray()
	distance.resize(count)
	var queue := PackedInt32Array()
	for i: int in count:
		if state[i] != 1:
			continue
		var x := i % w
		if (i >= w and state[i - w] == 0) or (i + w < count and state[i + w] == 0) \
				or (x > 0 and state[i - 1] == 0) or (x + 1 < w and state[i + 1] == 0):
			source[i] = i
			queue.append(i)
	var head := 0
	while head < queue.size():
		var i := queue[head]
		head += 1
		if distance[i] >= band:
			continue
		var x := i % w
		var neighbours: PackedInt32Array = [i - w if i >= w else -1, i + w if i + w < count else -1,
				i - 1 if x > 0 else -1, i + 1 if x + 1 < w else -1]
		# Un halo solo sigue desde el fondo u otro halo, nunca a través de un trazo.
		var halo_allowed: bool = state[i] == 1 or state[i] == 3
		for j: int in neighbours:
			if j < 0 or state[j] != 0 or _magenta(pixels, j) <= SOFT_MAGENTA:
				continue
			var kind := _edge_kind(pixels, j, source[i], halo_allowed)
			if kind == 0:
				continue
			var alpha := _unmix(pixels, j, source[i])
			source[j] = source[i]
			distance[j] = distance[i] + 1
			if alpha <= EDGE_CLEAR:
				state[j] = 1
				queue.append(j)
			else:
				state[j] = 3 if kind == 2 else 2
				# Ya es casi dibujo: el borde termina aquí.
				if alpha < EDGE_SOLID:
					queue.append(j)


## 1 si el píxel `i` es una mezcla del fondo `bg` con algo oscuro (el borde
## suavizado del trazo); 2 si es casi solo fondo con un halo de luz encima;
## 0 si no lo parece (un relleno malva o morado del propio dibujo).
static func _edge_kind(pixels: PackedByteArray, i: int, bg: int, halo_allowed: bool) -> int:
	var p := i * 4
	var b := bg * 4
	var red_share := float(pixels[p]) / maxf(pixels[b], 1.0)
	var blue_share := float(pixels[p + 2]) / maxf(pixels[b + 2], 1.0)
	var share := clampf(minf(red_share, blue_share), 0.0, 1.0)
	if absf(red_share - blue_share) <= MIX_BALANCE and pixels[p + 1] <= share * pixels[b + 1] + MIX_GREEN:
		return 1
	return 2 if halo_allowed and share >= HALO_SHARE else 0


## Quita del píxel `i` el magenta del fondo `bg` y devuelve el alfa que queda.
static func _unmix(pixels: PackedByteArray, i: int, bg: int) -> float:
	var p := i * 4
	var b := bg * 4
	var share := clampf(minf(float(pixels[p]) / maxf(pixels[b], 1.0), float(pixels[p + 2]) / maxf(pixels[b + 2], 1.0)), 0.0, 1.0)
	var alpha := 1.0 - share
	if alpha <= EDGE_CLEAR:
		return alpha
	for c: int in 3:
		pixels[p + c] = clampi(roundi((pixels[p + c] - share * pixels[b + c]) / alpha), 0, 255)
	pixels[p + 3] = roundi(alpha * 255.0)
	return alpha


## Ajustes de importación de Godot para la primera vez (luego manda el editor):
## compresión VRAM sin mipmaps para los fondos, la superposición y los recortes
## grandes (`mid` y `fg`: sin comprimir ocuparían 22 MB de memoria cada uno);
## retratos y manos, sin pérdida. Si la compresión deja marcas en un recorte,
## se cambia a «Lossless» en el editor.
static func write_import_settings(resource_path: String, slot: Dictionary) -> void:
	var import_path := ProjectSettings.globalize_path(resource_path + ".import")
	if FileAccess.file_exists(import_path):
		return
	var size: Vector2i = slot["size"]
	var vram: bool = slot["kind"] != "cutout" or size.x * size.y > LARGE_CUTOUT_PIXELS
	var lines: PackedStringArray = [
		"[remap]", "", "importer=\"texture\"", "type=\"CompressedTexture2D\"", "",
		"[deps]", "", "source_file=\"%s\"" % resource_path, "",
		"[params]", "",
		"compress/mode=%d" % (2 if vram else 0),
		"compress/high_quality=false",
		"mipmaps/generate=false",
		"process/fix_alpha_border=true",
		"process/size_limit=0",
		"detect_3d/compress_to=0",
	]
	var file := FileAccess.open(import_path, FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")


func _incoming_files(directory: String) -> Dictionary:
	var files: Dictionary = {}
	var dir := DirAccess.open(directory)
	if dir == null:
		return files
	for name: String in dir.get_files():
		if INCOMING_EXTENSIONS.has(name.get_extension().to_lower()):
			files[name.get_basename()] = directory.path_join(name)
	return files
