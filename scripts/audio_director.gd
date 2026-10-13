extends Node
## El sonido del juego (autoload `AudioDirector`). Los sucesos del juego
## («relevo a Akba», «carta», «sostener»...) se traducen a sonidos en
## data/audio.json, y cada sonido sale de data/audio_manifest.json: el archivo
## de verdad en assets/audio/<id>.ogg|wav|mp3 si existe; si no, el provisional
## de assets/audio/placeholder/<id>.wav (scripts/dev/make_placeholder_audio.gd);
## si tampoco, silencio y un solo aviso por sonido.
##
## Buses: Master, Music, Ambience y SFX, con volumen y silencio en los ajustes.
## Sin salida de audio (o sin pantalla, con el driver «Dummy») no falla nada.

const AUDIO_PATH: String = "res://data/audio.json"
const MANIFEST_PATH: String = "res://data/audio_manifest.json"
const BUSES: PackedStringArray = ["Music", "Ambience", "SFX"]
const SFX_VOICES: int = 4
## Ajuste de volumen -> bus.
const VOLUME_BUSES: Dictionary = {"volume_master": "Master", "volume_music": "Music", "volume_ambience": "Ambience", "volume_sfx": "SFX"}

var errors: PackedStringArray = []
## suceso -> id de sonido ("" = gancho sin sonido todavía, como el acorde de la Unión).
var events: Dictionary = {}
var ambience: Dictionary = {}
var clock_sound: String = ""
var drift_pitch: float = 1.0
var sustain_sound: String = ""
## id -> {id, bus, loop, volume_db}
var sounds: Dictionary = {}
var root: String = ""
var placeholder_root: String = ""
var extensions: PackedStringArray = []
## Sonidos de los que ya se avisó.
var warned: Dictionary = {}

var _streams: Dictionary = {}
var _sfx: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _ambience_player: AudioStreamPlayer
var _clock_player: AudioStreamPlayer
var _sustain_player: AudioStreamPlayer
var _ambience_id: String = ""


func _ready() -> void:
	ensure_buses()
	load_data()
	for i: int in SFX_VOICES:
		_sfx.append(_player("SFX"))
	_ambience_player = _player("Ambience")
	_clock_player = _player("Ambience")
	_sustain_player = _player("SFX")


## Crea los buses que falten, colgados de Master.
static func ensure_buses() -> void:
	for bus: String in BUSES:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, "Master")


func load_data() -> bool:
	errors = []
	var audio: Variant = _read(AUDIO_PATH)
	var manifest: Variant = _read(MANIFEST_PATH)
	if not audio is Dictionary or not manifest is Dictionary:
		errors.append("audio.json o audio_manifest.json no son objetos JSON.")
		return _fail()
	root = str(manifest.get("root", ""))
	placeholder_root = str(manifest.get("placeholder_root", ""))
	extensions = PackedStringArray(manifest.get("extensions", []))
	for raw: Variant in manifest.get("sounds", []):
		if not raw is Dictionary or not raw.get("id") is String or not BUSES.has(raw.get("bus", "")):
			errors.append("audio_manifest.json: sonido mal formado %s." % [raw])
			continue
		sounds[raw["id"]] = {"id": raw["id"], "bus": raw["bus"], "loop": raw.get("loop", false) == true,
				"volume_db": float(raw.get("volume_db", 0.0))}
	var raw_events: Variant = audio.get("events", {})
	for event: Variant in raw_events:
		var sound: Variant = raw_events[event]
		if sound != null and not sounds.has(sound):
			errors.append("audio.json: el suceso \"%s\" usa un sonido desconocido \"%s\"." % [event, sound])
		events[event] = sound if sound != null else ""
	ambience = audio.get("ambience", {})
	clock_sound = str(audio.get("clock", {}).get("sound", ""))
	drift_pitch = float(audio.get("clock", {}).get("drift_pitch", 1.0))
	sustain_sound = str(audio.get("sustain", ""))
	for id: Variant in ambience.values() + [clock_sound, sustain_sound]:
		if not sounds.has(id):
			errors.append("audio.json: sonido desconocido \"%s\"." % id)
	if not errors.is_empty():
		return _fail()
	return true


## Suena el sonido de un suceso. false si no hay sonido (gancho o archivo que falta).
func play_event(event: String) -> bool:
	var id: String = events.get(event, "")
	if id == "":
		return false
	var stream := stream_for(id)
	if stream == null or _sfx.is_empty():
		return false
	var player: AudioStreamPlayer = _sfx[_next_voice]
	_next_voice = (_next_voice + 1) % _sfx.size()
	_start(player, id, stream)
	return true


## Fondo de día o de noche y el tic-tac del Reloj (que se desajusta cerca de una fisura).
func set_scene_sound(night: bool, near_fissure: bool) -> void:
	var id: String = ambience.get("night" if night else "day", "")
	if id != _ambience_id:
		_ambience_id = id
		var stream := stream_for(id)
		if stream != null:
			_start(_ambience_player, id, stream)
		else:
			_ambience_player.stop()
	if not _clock_player.playing:
		var clock := stream_for(clock_sound)
		if clock != null:
			_start(_clock_player, clock_sound, clock)
	_clock_player.pitch_scale = drift_pitch if near_fissure else 1.0


func set_sustaining(on: bool) -> void:
	if not on:
		_sustain_player.stop()
		return
	var stream := stream_for(sustain_sound)
	if stream != null and not _sustain_player.playing:
		_start(_sustain_player, sustain_sound, stream)


## Volúmenes (0-1) y silencio desde los ajustes de la partida.
func apply_settings(settings: Dictionary) -> void:
	for key: String in VOLUME_BUSES:
		var index := AudioServer.get_bus_index(VOLUME_BUSES[key])
		if index >= 0:
			AudioServer.set_bus_volume_db(index, linear_to_db(maxf(settings.get(key, 1.0), 0.0001)))
	AudioServer.set_bus_mute(0, settings.get("mute", false))


## El sonido de `id`: el de verdad, el provisional o null (con un aviso la primera vez).
func stream_for(id: String) -> AudioStream:
	if _streams.has(id):
		return _streams[id]
	var stream: AudioStream = null
	var path := _path_for(id)
	if path != "":
		stream = load(path) as AudioStream
		if stream != null and sounds[id]["loop"]:
			stream = _looping(stream)
	elif not warned.has(id):
		warned[id] = true
		push_warning("[AudioDirector] Falta el sonido \"%s\": silencio." % id)
	_streams[id] = stream
	return stream


func _path_for(id: String) -> String:
	if not sounds.has(id):
		return ""
	for extension: String in extensions:
		if ResourceLoader.exists(root + id + "." + extension):
			return root + id + "." + extension
	if ResourceLoader.exists(placeholder_root + id + ".wav"):
		return placeholder_root + id + ".wav"
	return ""


static func _looping(stream: AudioStream) -> AudioStream:
	var copy: AudioStream = stream.duplicate()
	if copy is AudioStreamWAV:
		var wav := copy as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = wav.data.size() / (2 * (2 if wav.stereo else 1))
	elif copy is AudioStreamOggVorbis:
		(copy as AudioStreamOggVorbis).loop = true
	elif copy is AudioStreamMP3:
		(copy as AudioStreamMP3).loop = true
	return copy


func _start(player: AudioStreamPlayer, id: String, stream: AudioStream) -> void:
	player.stream = stream
	player.bus = sounds[id]["bus"]
	player.volume_db = sounds[id]["volume_db"]
	player.play()


func _player(bus: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus
	add_child(player)
	return player


func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _fail() -> bool:
	for message: String in errors:
		push_error("[AudioDirector] " + message)
	return false
