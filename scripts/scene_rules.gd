extends RefCounted
## Reglas puras de la presentación de los lugares (data/scenes.json). No tocan
## la escena ni la simulación: reciben datos y devuelven valores, así que se
## pueden probar sin pantalla.
##
## - Cámara: dónde puede estar el centro de la vista.
## - Estaciones: a qué punto del lugar lleva cada acción.
## - Manos: qué hacen las manos del protagonista según su última acción.
## - Luz: pesos de los tres fondos y gradación por hora y por mirada.
## - Puntos interactivos: cuándo y con qué mirada existen.

const GameData := preload("res://scripts/game_data.gd")


## Centro de la cámara (px de escena) dentro del lienzo: la vista nunca enseña
## lo que hay fuera. Si la vista es más ancha que el lienzo, se centra.
static func clamp_camera(x: float, view_width: float, canvas_width: float) -> float:
	if view_width >= canvas_width:
		return canvas_width * 0.5
	return clampf(x, view_width * 0.5, canvas_width - view_width * 0.5)


## Estación de `place` después de hacer `command`. `from_place` es dónde estaba
## el protagonista antes y `current` su estación guardada en ese lugar ("" si
## no tiene). Devuelve "" si el lugar no tiene escena.
static func station_after(data: GameData, command: Dictionary, from_place: String, current: String) -> String:
	var place: String = command.get("place", "")
	if not data.has_scene(place):
		return ""
	var scene: Dictionary = data.scenes[place]
	var arrived: bool = from_place != place or current == ""
	match command.get("verb", ""):
		"esperar":
			if arrived:
				return scene["entry"]
			var index: int = scene["station_index"][current]
			return scene["stations"][(index + 1) % scene["stations"].size()]["id"]
		"observar":
			if command.get("target", "") != "":
				return person_station(data, place, command["target"])
			var chosen: String = command.get("station", "")
			return chosen if scene["station_index"].has(chosen) else scene["observe"]
		"seguir", "hablar", "entregar", "desviar":
			return person_station(data, place, command["target"])
		"interactuar":
			return scene["interactions"].get(command["id"], scene["observe"])
	# Leer o retener una carta: se queda donde estaba.
	return scene["entry"] if arrived else current


## Dónde se coloca una persona en la escena de `place`.
static func person_station(data: GameData, place: String, person: String) -> String:
	var scene: Dictionary = data.scenes[place]
	return scene["people"].get(person, scene["default_person"])


## La estación más cercana a `x` (px de escena).
static func nearest_station(data: GameData, place: String, x: float) -> String:
	var best := ""
	var best_distance := INF
	for station: Dictionary in data.scenes[place]["stations"]:
		var distance: float = absf(station["x"] - x)
		if distance < best_distance:
			best_distance = distance
			best = station["id"]
	return best


## Estado de las manos de `actor`: el de su última orden en la ruta del bucle
## (la ruta empieza con `start_active` al mando). "idle" si aún no ha hecho nada.
static func hands_state(data: GameData, route: Array, actor: String) -> String:
	var active: String = data.start_active
	var state := "idle"
	for entry: Dictionary in route:
		if entry.has("switch"):
			active = entry["switch"]
		elif active == actor:
			state = data.hands_by_verb[actor][entry["command"]["verb"]]
	return state


## Pesos (día, atardecer, noche) de los tres fondos a la hora `minute`.
static func bg_weights(data: GameData, minute: float) -> Vector3:
	var bands := data.bg_bands
	var i := _segment(bands, minute)
	var a: Dictionary = bands[i]
	var b: Dictionary = bands[mini(i + 1, bands.size() - 1)]
	var t := _weight(a["time"], b["time"], minute)
	return Vector3(lerpf(a["day"], b["day"], t), lerpf(a["dusk"], b["dusk"], t), lerpf(a["night"], b["night"], t))


## Gradación a la hora `minute` con la mirada de `look`:
## {tint, light, light_strength, vignette, grain, overlay}.
static func grading_at(data: GameData, minute: float, look: String) -> Dictionary:
	var frames := data.grading
	var i := _segment(frames, minute)
	var a: Dictionary = frames[i]
	var b: Dictionary = frames[mini(i + 1, frames.size() - 1)]
	var t := _weight(a["time"], b["time"], minute)
	var style: Dictionary = data.looks[look]
	var base_tint: Color = a["tint"].lerp(b["tint"], t)
	return {
		"tint": base_tint * style["tint"],
		"light": a["light"].lerp(b["light"], t),
		"light_strength": lerpf(a["light_strength"], b["light_strength"], t),
		"vignette": clampf(lerpf(a["vignette"], b["vignette"], t) + style["vignette"], 0.0, 1.0),
		"grain": lerpf(a["grain"], b["grain"], t),
		"overlay": style["overlay"],
	}


## Un punto interactivo existe con esta mirada y a esta hora.
static func hotspot_visible(hotspot: Dictionary, look: String, minute: int) -> bool:
	return (hotspot["look"] == "both" or hotspot["look"] == look) and minute >= hotspot["from"] and minute < hotspot["to"]


## La orden que manda tocar un punto interactivo: «observar» el lugar desde su estación.
static func hotspot_command(hotspot: Dictionary) -> Dictionary:
	return {"verb": "observar", "place": hotspot["place"], "target": "", "id": "", "station": hotspot["station"]}


## Índice del fotograma clave que empieza el tramo de `minute`.
static func _segment(frames: Array[Dictionary], minute: float) -> int:
	var i := 0
	while i + 1 < frames.size() and minute >= frames[i + 1]["time"]:
		i += 1
	return i


static func _weight(from: int, to: int, minute: float) -> float:
	if to <= from:
		return 0.0
	return clampf((minute - from) / float(to - from), 0.0, 1.0)
