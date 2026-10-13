extends RefCounted
## Transiciones de la interfaz: cortas (nunca más de 250 ms) y ninguna con
## movimiento reducido.

const FADE_SECONDS: float = 0.18


## Muestra `node` con un fundido corto (o de golpe con movimiento reducido).
static func fade_in(node: CanvasItem, reduced_motion: bool) -> void:
	node.show()
	if reduced_motion or not node.is_inside_tree():
		node.modulate.a = 1.0
		return
	node.modulate.a = 0.0
	node.create_tween().tween_property(node, "modulate:a", 1.0, FADE_SECONDS)
