extends "res://scripts/dev/tests/test_suite.gd"
## El arte: el manifiesto (ids únicos, rutas bien formadas, todas las ranuras
## que la UI pide), los provisionales con un solo aviso por ranura, la capa
## `mid` opcional sobre fondos de verdad y la herramienta de ingesta con
## imágenes sintéticas (magenta a transparente, tamaño, informe).

const ArtIngest := preload("res://scripts/dev/art_ingest.gd")
const TEST_ART_DIR: String = "user://test_art"
const MAGENTA := Color8(255, 0, 255)
## Fondo algo irregular, como el de las imágenes generadas.
const MAGENTA_DIRTY := Color8(224, 16, 200)
const PALE_PINK := Color8(242, 198, 180)
const MAUVE := Color8(160, 90, 170)
const OUTLINE := Color8(20, 8, 18)


func cleanup() -> void:
	super.cleanup()
	_remove_tree(ProjectSettings.globalize_path(TEST_ART_DIR))


func test_real_manifest_covers_every_slot() -> bool:
	var art := ArtLibrary.new()
	check(art.load_manifest(), "el manifiesto real es válido: %s" % [art.errors])
	var data := new_state().data
	for place: String in data.visible_location_ids():
		for layer: String in ArtLibrary.PLACE_LAYERS:
			check(art.slots.has(ArtLibrary.place_slot(place, layer)), "falta la ranura %s_%s" % [place, layer])
	for actor: String in data.protagonist_ids:
		for pose: String in ["idle", "hand_raised"]:
			check(art.slots.has(ArtLibrary.portrait_slot(actor, pose)), "falta el retrato %s %s" % [actor, pose])
		for state_name: String in data.hand_states:
			check(art.slots.has(ArtLibrary.hands_slot(actor, state_name)), "faltan las manos %s %s" % [actor, state_name])
	var paths: Dictionary = {}
	for id: String in art.slot_ids:
		check(not paths.has(art.slots[id]["path"]), "ruta repetida %s" % id)
		paths[art.slots[id]["path"]] = true
	return true


func test_broken_manifests_fail() -> bool:
	var good: Dictionary = read_json(ArtLibrary.MANIFEST_PATH)
	var breakers: Array[Callable] = [
		func(m: Dictionary) -> void: m["slots"].append(m["slots"][0].duplicate()),
		func(m: Dictionary) -> void: m["slots"][0]["path"] = "../fuera.jpg",
		func(m: Dictionary) -> void: m["slots"][0]["path"] = "places/Relojeria/BG_DAY.jpg",
		func(m: Dictionary) -> void: m["slots"][3]["path"] = "places/relojeria/mid.jpg",
		func(m: Dictionary) -> void: m["slots"][0]["kind"] = "brillante",
		func(m: Dictionary) -> void: m["slots"][18]["focus"] = [0.8, 0.0, 0.5, 0.5],
	]
	for i: int in breakers.size():
		var manifest: Dictionary = good.duplicate(true)
		breakers[i].call(manifest)
		var art := ArtLibrary.new()
		check(not art.load_source(manifest) and not art.errors.is_empty(), "el manifiesto roto #%d se rechaza" % i)
	return true


func test_missing_art_falls_back_with_one_warning() -> bool:
	var manifest: Dictionary = read_json(ArtLibrary.MANIFEST_PATH)
	manifest["root"] = "res://no_existe_arte/"
	var art := ArtLibrary.new()
	check(art.load_source(manifest), "un manifiesto sin archivos sigue siendo válido")
	var layers := art.enter_place("mercado")
	for layer: String in ArtLibrary.PLACE_LAYERS:
		check(layers[layer]["texture"] == null and layers[layer]["placeholder"], "sin archivo, %s usa el provisional" % layer)
	check(art.warned.size() == ArtLibrary.PLACE_LAYERS.size(), "un aviso por ranura: %d" % art.warned.size())
	art.enter_place("plaza")
	art.enter_place("mercado")
	art.enter_place("mercado")
	check(art.warned.size() == ArtLibrary.PLACE_LAYERS.size() * 2, "volver a un lugar no repite avisos: %d" % art.warned.size())
	check(art.current_place() == "mercado", "solo se tienen cargadas las capas del lugar actual")
	check(art.small_texture("hands_sazil_idle") == null and art.small_texture("hands_sazil_idle") == null, "las manos sin arte son provisionales")
	check(art.warned.size() == ArtLibrary.PLACE_LAYERS.size() * 2 + 1, "y avisan una sola vez")
	return true


func test_mid_is_optional_over_real_backgrounds() -> bool:
	var art := ArtLibrary.new()
	art.load_manifest()
	if not art.uses_real_bg("plaza"):
		# Sin fondos de verdad en este clon no hay nada que comprobar.
		return true
	var layers := art.enter_place("plaza")
	if not art.has_file("plaza_mid"):
		check(layers["mid"]["texture"] == null and not layers["mid"]["placeholder"], "sin `mid` sobre fondos de verdad no se dibuja nada")
		check(not art.warned.has("plaza_mid"), "y no se avisa")
	check(layers["bg_day"]["texture"] != null, "el fondo de verdad se carga")
	return true


func test_ingest_keys_magenta_resizes_and_reports() -> bool:
	var incoming := TEST_ART_DIR + "/incoming"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(incoming))
	_synthetic_cutout(60, 40).save_png(ProjectSettings.globalize_path(incoming + "/prueba_recorte.png"))
	_synthetic_cutout(50, 50).save_png(ProjectSettings.globalize_path(incoming + "/prueba_cuadrada.png"))
	var black := Image.create(30, 20, false, Image.FORMAT_RGB8)
	black.fill(Color.BLACK)
	black.fill_rect(Rect2i(10, 5, 4, 4), Color8(90, 255, 200))
	black.save_png(ProjectSettings.globalize_path(incoming + "/prueba_suma.png"))
	black.save_png(ProjectSettings.globalize_path(incoming + "/sin_ranura.png"))
	var art := ArtLibrary.new()
	check(art.load_source({"root": "res://test_art/", "incoming": "res://test_art_incoming/", "slots": [
		{"id": "prueba_recorte", "path": "recorte.png", "size": [90, 60], "kind": "cutout", "fallback": "placeholder"},
		{"id": "prueba_cuadrada", "path": "cuadrada.png", "size": [90, 60], "kind": "cutout", "fallback": "placeholder"},
		{"id": "prueba_suma", "path": "suma.png", "size": [60, 40], "kind": "additive", "fallback": "placeholder"},
		{"id": "prueba_falta", "path": "falta.png", "size": [90, 60], "kind": "cutout", "fallback": "placeholder"},
	]}), "el manifiesto de prueba es válido: %s" % [art.errors])
	var ingest := ArtIngest.new(art)
	var report := ingest.run(incoming, TEST_ART_DIR + "/out")
	check(report["ingested"] == ["prueba_recorte", "prueba_suma"], "se procesan las que encajan: %s" % [report["ingested"]])
	check(report["missing"] == ["prueba_falta"], "el informe lista la que falta: %s" % [report["missing"]])
	check(report["mismatched"].size() == 1 and report["mismatched"][0].begins_with("prueba_cuadrada"), "y la de proporción equivocada: %s" % [report["mismatched"]])
	check(report["unmatched"] == ["sin_ranura.png"], "y el archivo sin ranura: %s" % [report["unmatched"]])
	var cutout := Image.load_from_file(ProjectSettings.globalize_path(TEST_ART_DIR + "/out/recorte.png"))
	check(cutout.get_size() == Vector2i(90, 60), "se redimensiona al tamaño del manifiesto")
	check(cutout.get_pixel(1, 1).a == 0.0 and cutout.get_pixel(88, 58).a == 0.0, "el fondo magenta queda transparente")
	check(cutout.get_pixel(30, 30).a > 0.99 and _close(cutout.get_pixel(30, 30), PALE_PINK), "el rosa pálido de dentro no se toca")
	check(cutout.get_pixel(55, 30).a > 0.99 and _close(cutout.get_pixel(55, 30), MAUVE), "el malva de dentro no se toca")
	var additive := Image.load_from_file(ProjectSettings.globalize_path(TEST_ART_DIR + "/out/suma.png"))
	check(additive.get_size() == Vector2i(60, 40) and additive.get_pixel(1, 1) == Color.BLACK, "la capa aditiva solo se redimensiona: el negro sigue negro")
	var again := ingest.run(incoming, TEST_ART_DIR + "/out")
	check(again["ingested"].is_empty() and again["up_to_date"].size() == 2, "es idempotente: lo hecho no se rehace")
	return true


## Fondo magenta (algo irregular) con un dibujo de trazo negro: dentro, rosa
## pálido a la izquierda y malva a la derecha.
func _synthetic_cutout(width: int, height: int) -> Image:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(MAGENTA)
	image.fill_rect(Rect2i(0, height / 2, width, height - height / 2), MAGENTA_DIRTY)
	var body := Rect2i(width / 6, height / 5, width * 2 / 3, height * 3 / 5)
	image.fill_rect(body, OUTLINE)
	var inside := body.grow(-2)
	image.fill_rect(Rect2i(inside.position, Vector2i(inside.size.x / 2, inside.size.y)), PALE_PINK)
	image.fill_rect(Rect2i(inside.position + Vector2i(inside.size.x / 2, 0), Vector2i(inside.size.x - inside.size.x / 2, inside.size.y)), MAUVE)
	return image


func _close(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.08 and absf(a.g - b.g) < 0.08 and absf(a.b - b.b) < 0.08


func _remove_tree(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_remove_tree(path.path_join(sub))
	for file: String in dir.get_files():
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)
