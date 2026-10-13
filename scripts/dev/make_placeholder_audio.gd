extends SceneTree
## Sonidos PROVISIONALES, sintetizados (sin archivos de fuera):
##   godot --headless --path . --script res://scripts/dev/make_placeholder_audio.gd
## Escribe un WAV por sonido de data/audio_manifest.json en
## assets/audio/placeholder/. Son bajitos y suaves a propósito; los de verdad se
## dejan en assets/audio/<id>.ogg (o .wav/.mp3) y los sustituyen sin tocar código.
## Siempre salen iguales (ruido con semilla fija).

const OUT_DIR: String = "res://assets/audio/placeholder/"
const RATE: int = 22050
const SEED: int = 5252

var _has_run: bool = false
var _rng := RandomNumberGenerator.new()


func _process(_delta: float) -> bool:
	if not _has_run:
		_has_run = true
		_run()
	return false


func _run() -> void:
	_rng.seed = SEED
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var made: Dictionary = {
		"clock_tick": _clock(),
		"motif_low": _note(110.0, 1.1, 0.3),
		"motif_high": _note(880.0, 0.8, 0.16),
		"shimmer": _shimmer(),
		"card_tick": _click(2600.0, 0.05, 0.16),
		"card_flip": _flip(),
		"sustain_hum": _hum(),
		"ambience_day": _day(),
		"ambience_night": _night(),
	}
	for id: String in made:
		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = RATE
		wav.stereo = false
		wav.data = _pcm(made[id])
		var error := wav.save_to_wav(ProjectSettings.globalize_path(OUT_DIR + id + ".wav"))
		print("%s %s" % [id, "OK" if error == OK else error_string(error)])
	quit(0)


func _clock() -> PackedFloat32Array:
	var samples := _silence(1.0)
	_add(samples, _click(2100.0, 0.06, 0.22), 0.0)
	_add(samples, _click(1500.0, 0.06, 0.18), 0.5)
	return samples


## Una nota con armónico suave, ataque corto y caída lenta.
func _note(frequency: float, seconds: float, amplitude: float) -> PackedFloat32Array:
	var samples := _silence(seconds)
	for i: int in samples.size():
		var t := float(i) / RATE
		var envelope := minf(t / 0.02, 1.0) * exp(-3.0 * t / seconds)
		samples[i] = amplitude * envelope * (sin(TAU * frequency * t) + 0.25 * sin(TAU * frequency * 2.0 * t))
	return samples


## Cristal tensado: notas agudas con trémolo lento, siempre bajo.
func _shimmer() -> PackedFloat32Array:
	var samples := _silence(1.8)
	var partials: PackedFloat32Array = [1760.0, 2217.5, 2637.0, 3520.0]
	for i: int in samples.size():
		var t := float(i) / RATE
		var envelope := minf(t / 0.3, 1.0) * minf((1.8 - t) / 0.6, 1.0)
		var value := 0.0
		for k: int in partials.size():
			value += sin(TAU * partials[k] * t + k) * (0.6 + 0.4 * sin(TAU * (0.7 + k * 0.3) * t))
		samples[i] = 0.035 * envelope * value
	return samples


func _click(frequency: float, seconds: float, amplitude: float) -> PackedFloat32Array:
	var samples := _silence(seconds)
	for i: int in samples.size():
		var t := float(i) / RATE
		samples[i] = amplitude * exp(-t / 0.008) * sin(TAU * frequency * t)
	return samples


## Una carta que gira: un soplo de ruido suave.
func _flip() -> PackedFloat32Array:
	var samples := _silence(0.14)
	var low := 0.0
	for i: int in samples.size():
		var t := float(i) / RATE
		low += 0.25 * (_rng.randf_range(-1.0, 1.0) - low)
		samples[i] = 0.5 * low * sin(PI * t / 0.14)
	return samples


## Zumbido grave para sostener: ciclos enteros, así el bucle no se nota.
func _hum() -> PackedFloat32Array:
	var samples := _silence(2.0)
	for i: int in samples.size():
		var t := float(i) / RATE
		samples[i] = 0.1 * (0.75 + 0.25 * sin(TAU * 0.5 * t)) * (sin(TAU * 110.0 * t) + 0.5 * sin(TAU * 165.0 * t))
	return samples


## Día: un murmullo de mercado (ruido muy filtrado) y dos campanas lejanas.
func _day() -> PackedFloat32Array:
	var samples := _filtered_noise(6.0, 0.05, 0.03)
	_add(samples, _note(660.0, 2.0, 0.05), 1.3)
	_add(samples, _note(990.0, 1.6, 0.035), 4.0)
	return samples


## Noche: grillos, el zumbido del Observatorio y una fiesta muy lejos.
func _night() -> PackedFloat32Array:
	var samples := _filtered_noise(6.0, 0.02, 0.015)
	for i: int in samples.size():
		var t := float(i) / RATE
		samples[i] += 0.025 * sin(TAU * 55.0 * t)
	for chirp: int in 7:
		for pulse: int in 3:
			_add(samples, _click(4400.0, 0.04, 0.05), chirp * 0.85 + pulse * 0.07)
	return samples


func _filtered_noise(seconds: float, smoothing: float, amplitude: float) -> PackedFloat32Array:
	var samples := _silence(seconds)
	var low := 0.0
	for i: int in samples.size():
		low += smoothing * (_rng.randf_range(-1.0, 1.0) - low)
		samples[i] = amplitude * low / maxf(smoothing, 0.001) * 0.1
	# Unión suave del final con el principio.
	var fade := int(0.2 * RATE)
	for i: int in fade:
		var w := float(i) / fade
		samples[samples.size() - fade + i] = lerpf(samples[samples.size() - fade + i], samples[i], w)
	return samples


func _silence(seconds: float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(int(seconds * RATE))
	return samples


func _add(into: PackedFloat32Array, sound: PackedFloat32Array, at_seconds: float) -> void:
	var start := int(at_seconds * RATE)
	for i: int in sound.size():
		if start + i < into.size():
			into[start + i] += sound[i]


func _pcm(samples: PackedFloat32Array) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i: int in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	return bytes
