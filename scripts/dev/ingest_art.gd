extends SceneTree
## Ingesta del arte sin pantalla (ver docs/art_pipeline.md):
##   godot --headless --path . --script res://scripts/dev/ingest_art.gd
##   godot --headless --path . --script res://scripts/dev/ingest_art.gd -- --force
## Lee assets/art_incoming/<ranura>.png|jpg|webp, deja el resultado en
## assets/art/ e imprime qué ranuras están, cuáles faltan y qué no encaja.
## Después, abre el editor (o `godot --headless --path . --import`) para importar.
## Sale con código 1 si algo falló o no tiene la proporción esperada.

const ArtLibrary := preload("res://scripts/art_library.gd")
const ArtIngest := preload("res://scripts/dev/art_ingest.gd")

var _has_run: bool = false


func _process(_delta: float) -> bool:
	if not _has_run:
		_has_run = true
		_run()
	return false


func _run() -> void:
	var library := ArtLibrary.new()
	if not library.load_manifest():
		quit(1)
		return
	var ingest := ArtIngest.new(library)
	ingest.force = OS.get_cmdline_user_args().has("--force")
	var started := Time.get_ticks_msec()
	var report := ingest.run(library.incoming, library.root)
	var lines: PackedStringArray = []
	for key: String in ["ingested", "up_to_date", "present", "missing", "mismatched", "unmatched", "failed"]:
		var items: Array = report[key]
		lines.append("%-11s %2d  %s" % [key, items.size(), ", ".join(PackedStringArray(items))])
	print("Ingesta de arte (%.0f s)" % ((Time.get_ticks_msec() - started) / 1000.0))
	print("\n".join(lines))
	var megabytes: float = report["bytes"] / 1048576.0
	print("Arte en %s: %.1f MB (límite %d MB)%s" % [library.root, megabytes, library.budget_mb,
			"  ¡SE PASA!" if megabytes > library.budget_mb else ""])
	quit(1 if not report["failed"].is_empty() or not report["mismatched"].is_empty() or megabytes > library.budget_mb else 0)
