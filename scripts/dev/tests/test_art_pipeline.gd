extends "res://scripts/dev/tests/test_suite.gd"
## El arte: el manifiesto (ids únicos, rutas bien formadas, todas las ranuras
## que la UI pide), los provisionales generados (assets/art_provisional/) que el
## arte de verdad sustituye sin tocar código, los dibujados con un solo aviso
## por ranura, la capa `mid` opcional sobre fondos de verdad y la herramienta de
## ingesta con imágenes sintéticas (magenta a transparente, tamaño, informe,
## modo de solo comprobar y sugerencias para archivos mal nombrados).

const ArtIngest := preload("res://scripts/dev/art_ingest.gd")
const HandsView := preload("res://scripts/hands_view.gd")
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
	manifest["provisional_root"] = "res://no_existe_provisional/"
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
	var manifest: Dictionary = read_json(ArtLibrary.MANIFEST_PATH)
	manifest["provisional_root"] = "res://no_existe_provisional/"
	var art := ArtLibrary.new()
	art.load_source(manifest)
	if not art.uses_real_bg("plaza"):
		# Sin fondos de verdad en este clon no hay nada que comprobar.
		return true
	var layers := art.enter_place("plaza")
	if not art.has_file("plaza_mid"):
		check(layers["mid"]["texture"] == null and not layers["mid"]["placeholder"], "sin `mid` (ni provisional) sobre fondos de verdad no se dibuja nada")
		check(not art.warned.has("plaza_mid"), "y no se avisa")
	check(layers["bg_day"]["texture"] != null, "el fondo de verdad se carga")
	return true


## Cada ranura `provisional` sin arte de verdad tiene su imagen generada, con el
## tamaño del manifiesto; el arte de verdad la sustituye sin tocar código.
func test_provisional_art_until_real_art_arrives() -> bool:
	var art := ArtLibrary.new()
	check(art.load_manifest(), "el manifiesto real es válido")
	check(art.provisional_root.begins_with("res://"), "hay carpeta de provisionales")
	var provisional := 0
	for id: String in art.slot_ids:
		var slot: Dictionary = art.slots[id]
		if not slot["provisional"] or art.has_file(id):
			continue
		provisional += 1
		check(art.source_of(id) == "provisional", "%s usa su provisional generado" % id)
		var texture := art.texture_for(id)
		if check(texture != null, "%s: el provisional se carga" % id):
			check(Vector2i(texture.get_size()) == slot["size"], "%s: %s, se esperaba %s" % [id, texture.get_size(), slot["size"]])
	check(provisional >= 20, "manos, capas, mapa, finales, icono y arranque son provisionales: %d" % provisional)
	var layers := art.enter_place("mercado")
	check(layers["fg"]["texture"] != null and not layers["fg"]["placeholder"], "el primer plano provisional se usa")
	check(not art.warned.has("mercado_fg"), "y no avisa como arte que falta")
	check(art.small_texture("hands_akba_light") != null and not art.warned.has("hands_akba_light"), "las manos provisionales se usan sin aviso")
	# Llega el arte de verdad: misma ranura, otra ruta en assets/art/.
	art.slots["hands_akba_light"]["path"] = "res://icon.svg"
	art.slots["mercado_fg"]["path"] = "res://icon.svg"
	check(art.source_of("hands_akba_light") == "real" and art.resolve_path("hands_akba_light") == "res://icon.svg",
			"el arte de verdad gana al provisional")
	art.release_place()
	check(art.enter_place("mercado")["fg"]["texture"].resource_path == "res://icon.svg", "también en las capas del lugar")
	# Las caras de Velo 2-3 son de la comunidad: el estudio no genera nada.
	for id: String in art.slot_ids:
		if id.begins_with("npc_"):
			check(not art.slots[id]["provisional"], "%s no es provisional del estudio" % id)
	return true


func test_hands_are_four_by_three() -> bool:
	var art := ArtLibrary.new()
	art.load_manifest()
	for id: String in art.slot_ids:
		if id.begins_with("hands_"):
			var size: Vector2i = art.slots[id]["size"]
			check(size.x * 3 == size.y * 4, "%s es 4:3 (%s)" % [id, size])
	check(is_equal_approx(HandsView.DESIGN.x / HandsView.DESIGN.y, 4.0 / 3.0), "las manos dibujadas también")
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
	# Solo comprobar: dice lo mismo y no escribe nada.
	var dry := ArtIngest.new(art)
	dry.dry_run = true
	var preview := dry.run(incoming, TEST_ART_DIR + "/dry")
	check(preview["ingested"] == ["prueba_recorte", "prueba_suma"] and preview["mismatched"].size() == 1, "--check dice lo que haría: %s" % [preview])
	check(not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(TEST_ART_DIR + "/dry")), "y no escribe nada")
	return true


## Un archivo mal nombrado se informa con la ranura que parece (no se renombra).
func test_unmatched_files_get_a_suggestion() -> bool:
	var art := ArtLibrary.new()
	art.load_manifest()
	check(ArtIngest.suggest_slot(art, "objects_plaza") == "plaza_fg", "«objects» en la plaza es plaza_fg: %s" % ArtIngest.suggest_slot(art, "objects_plaza"))
	check(ArtIngest.suggest_slot(art, "objects").contains("plaza_fg"), "sin lugar, las de primer plano: %s" % ArtIngest.suggest_slot(art, "objects"))
	check(ArtIngest.suggest_slot(art, "hands_sazil_iddle") == "hands_sazil_idle", "una errata: la más parecida")
	check(ArtIngest.suggest_slot(art, "zzz") == "", "y nada si no se parece a ninguna")
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
