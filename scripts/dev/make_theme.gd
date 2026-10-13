extends SceneTree
## Genera el tema del juego (assets/ui/theme.tres) desde scripts/ui_style.gd:
##   godot --headless --path . --script res://scripts/dev/make_theme.gd
## Después de cambiar una ficha de diseño en ui_style.gd hay que volver a
## ejecutarlo; test_ui_style.gd falla si el archivo y el código no coinciden.
## La salida es siempre la misma (ids de los sub-recursos fijos), así que solo
## cambia en git lo que cambió de verdad.

const UiStyle := preload("res://scripts/ui_style.gd")


func _initialize() -> void:
	var theme := UiStyle.build_theme()
	var count := 0
	for type: StringName in theme.get_type_list():
		for data_type: int in [Theme.DATA_TYPE_STYLEBOX, Theme.DATA_TYPE_FONT]:
			for item: StringName in theme.get_theme_item_list(data_type, type):
				var resource: Resource = theme.get_theme_item(data_type, item, type)
				if resource != null and resource.resource_path == "" and resource.resource_scene_unique_id == "":
					count += 1
					resource.resource_scene_unique_id = "%s_%d" % [resource.get_class(), count]
	var error := ResourceSaver.save(theme, UiStyle.THEME_PATH)
	if error != OK:
		push_error("No se pudo guardar %s: %s" % [UiStyle.THEME_PATH, error_string(error)])
		quit(1)
		return
	print("Tema guardado en %s (%d tipos)." % [UiStyle.THEME_PATH, theme.get_type_list().size()])
	quit(0)
