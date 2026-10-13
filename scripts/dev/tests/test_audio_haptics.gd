extends "res://scripts/dev/tests/test_suite.gd"
## Sonido y vibración: cada suceso de data/audio.json tiene sonido (el de verdad
## o el provisional) o es un gancho vacío; un sonido que falta da silencio y un
## solo aviso; los ajustes no rompen nada sin pantalla. La vibración respeta su
## nivel y tiene todos los patrones que usa el juego.

const AudioDirectorScript := preload("res://scripts/audio_director.gd")
const HapticsScript := preload("res://scripts/haptics.gd")
## Sucesos que dispara la interfaz (main, conversación, quiebre).
const USED_EVENTS: PackedStringArray = ["switch_sazil", "switch_akba", "card_play", "card_flip", "door_open",
		"sustain_success", "let_go"]
const USED_PATTERNS: PackedStringArray = ["switch", "card", "sustain_pulse", "success", "let_go"]


func test_every_audio_event_resolves() -> bool:
	var audio: Node = add_node(AudioDirectorScript.new())
	check(audio.errors.is_empty(), "audio.json y audio_manifest.json son válidos: %s" % [audio.errors])
	for event: String in USED_EVENTS:
		check(audio.events.has(event), "audio.json tiene el suceso «%s»" % event)
	for event: String in audio.events:
		var id: String = audio.events[event]
		if id == "":
			check(not audio.play_event(event), "«%s» es un gancho: no suena" % event)
			continue
		check(audio.stream_for(id) != null, "«%s» suena (%s, de verdad o provisional)" % [event, id])
		check(audio.play_event(event), "«%s» se puede tocar sin pantalla" % event)
	for id: String in audio.sounds:
		check(ResourceLoader.exists(audio.placeholder_root + id + ".wav"), "hay sonido provisional para «%s»" % id)
	audio.set_scene_sound(true, true)
	audio.set_scene_sound(false, false)
	audio.set_sustaining(true)
	audio.set_sustaining(false)
	check(audio.events.has("union_chord") and audio.events["union_chord"] == "", "el acorde de la Unión es un gancho")
	return true


func test_missing_sound_is_silent_and_warns_once() -> bool:
	var audio: Node = add_node(AudioDirectorScript.new())
	audio.sounds["sonido_fantasma"] = {"id": "sonido_fantasma", "bus": "SFX", "loop": false, "volume_db": 0.0}
	audio.events["suceso_fantasma"] = "sonido_fantasma"
	check(not audio.play_event("suceso_fantasma"), "sin archivo no suena")
	check(audio.warned.has("sonido_fantasma"), "avisa de que falta")
	var warnings: int = audio.warned.size()
	audio.play_event("suceso_fantasma")
	check(audio.warned.size() == warnings, "solo avisa una vez")
	return true


func test_volume_and_mute_settings() -> bool:
	var audio: Node = add_node(AudioDirectorScript.new())
	for bus: String in ["Master", "Music", "Ambience", "SFX"]:
		check(AudioServer.get_bus_index(bus) >= 0, "existe el bus %s" % bus)
	var settings: Dictionary = SaveManager.DEFAULT_SETTINGS.duplicate()
	settings["volume_music"] = 0.5
	settings["mute"] = true
	audio.apply_settings(settings)
	check(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")), linear_to_db(0.5)), "el volumen de la música se aplica")
	check(AudioServer.is_bus_mute(0), "silenciar todo silencia Master")
	audio.apply_settings(SaveManager.DEFAULT_SETTINGS)
	check(not AudioServer.is_bus_mute(0), "y se puede quitar")
	var state := new_state()
	state.set_volume("volume_sfx", 3.0)
	state.set_volume("volumen_raro", 0.1)
	check(state.settings["volume_sfx"] == 1.0 and not state.settings.has("volumen_raro"), "los volúmenes se acotan y las claves raras se ignoran")
	return true


func test_haptics_levels_and_patterns() -> bool:
	var haptics: Node = add_node(HapticsScript.new())
	check(haptics.errors.is_empty(), "haptics.json es válido: %s" % [haptics.errors])
	for pattern: String in USED_PATTERNS:
		check(haptics.patterns.has(pattern), "existe el patrón «%s»" % pattern)
	haptics.set_level("off")
	haptics.history.clear()
	check(not haptics.play("card") and haptics.history.is_empty(), "apagada no vibra")
	haptics.set_level("low")
	check(haptics.play("card"), "baja vibra")
	var first_step: Array = haptics.patterns["card"][0]
	check(not haptics.history.is_empty() and is_equal_approx(haptics.history[-1]["amplitude"], float(first_step[2]) * 0.5),
			"en «suave» la intensidad es la mitad")
	haptics.set_level("fuerte")
	check(haptics.level == "low", "un nivel desconocido se ignora")
	check(not haptics.play("patron_fantasma"), "un patrón que no existe no vibra")
	check(haptics.sustain_interval_ms(0.0) > haptics.sustain_interval_ms(0.5) and haptics.sustain_interval_ms(0.5) > haptics.sustain_interval_ms(1.0),
			"al sostener, los pulsos se aceleran")
	var state := new_state()
	state.set_haptics("off")
	state.set_haptics("muy_fuerte")
	check(state.settings["haptics"] == "off", "el ajuste de vibración solo acepta off/low/normal")
	return true
