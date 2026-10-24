class_name SynthSfx
extends RefCounted
## Sonidos de prueba generados por código (hasta tener audio real).
## TODO-ASSET: sfx_weapons, sfx_impacts — reemplazar por grabaciones/librerías.
##
## Se generan una vez y quedan en caché.

const RATE := 22050

static var _cache: Dictionary = {}


## Disparo: golpe grave + ruido con caída exponencial y una cola.
static func gunshot(key: String, body_hz: float, tail: float) -> AudioStreamWAV:
	var ck := "shot_%s" % key
	if _cache.has(ck):
		return _cache[ck]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(ck)
	var n := int(RATE * (tail + 0.15))
	var data := PackedFloat32Array()
	data.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		# Filtro pasa bajos simple para dar cuerpo a la cola
		lp += (noise - lp) * 0.35
		lp2 += (lp - lp2) * 0.12
		var crack := noise * exp(-t * 90.0)
		var body := sin(TAU * body_hz * t * (1.0 - t * 1.5)) * exp(-t * 18.0)
		var rumble := lp2 * 2.2 * exp(-t * (3.0 / tail))
		data[i] = crack * 0.9 + body * 0.8 + rumble * 0.7
	var s := _to_wav(data, 0.95)
	_cache[ck] = s
	return s


## Click mecánico (gatillo en seco, cargador, corredera).
static func click(key: String, pitch: float = 1.0, length: float = 0.05) -> AudioStreamWAV:
	var ck := "click_%s" % key
	if _cache.has(ck):
		return _cache[ck]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(ck)
	var n := int(RATE * length)
	var data := PackedFloat32Array()
	data.resize(n)
	var hp := 0.0
	var prev := 0.0
	for i in n:
		var t := float(i) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		hp = 0.7 * (hp + noise - prev)
		prev = noise
		var ring := sin(TAU * 2400.0 * pitch * t) * 0.4
		data[i] = (hp * 0.8 + ring) * exp(-t * 120.0 / pitch)
	var s := _to_wav(data, 0.6)
	_cache[ck] = s
	return s


## Impacto según superficie.
static func impact(surface: String) -> AudioStreamWAV:
	var ck := "impact_%s" % surface
	if _cache.has(ck):
		return _cache[ck]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(ck)
	var n := int(RATE * 0.25)
	var data := PackedFloat32Array()
	data.resize(n)
	var lp := 0.0
	var ring_hz := 0.0
	var decay := 40.0
	var smooth := 0.5
	match surface:
		"metal":
			ring_hz = 1850.0
			decay = 14.0
			smooth = 0.9
		"wood":
			ring_hz = 340.0
			decay = 45.0
			smooth = 0.3
		"dirt", "flesh":
			decay = 60.0
			smooth = 0.12
		"water":
			decay = 20.0
			smooth = 0.2
		"paper":
			decay = 90.0
			smooth = 0.6
	for i in n:
		var t := float(i) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		lp += (noise - lp) * smooth
		var ring := sin(TAU * ring_hz * t) * 0.6 if ring_hz > 0.0 else 0.0
		data[i] = (lp + ring) * exp(-t * decay)
	var s := _to_wav(data, 0.7)
	_cache[ck] = s
	return s


## Zumbido de rebote: tono que baja.
static func ricochet() -> AudioStreamWAV:
	var ck := "ricochet"
	if _cache.has(ck):
		return _cache[ck]
	var n := int(RATE * 0.45)
	var data := PackedFloat32Array()
	data.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := lerpf(3200.0, 900.0, t / 0.45)
		phase += TAU * f / RATE
		data[i] = sin(phase) * exp(-t * 6.0) * 0.5 * minf(1.0, t * 80.0)
	var s := _to_wav(data, 0.5)
	_cache[ck] = s
	return s


static func _to_wav(samples: PackedFloat32Array, gain: float) -> AudioStreamWAV:
	var peak := 0.0001
	for v in samples:
		peak = maxf(peak, absf(v))
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v := clampf(samples[i] / peak * gain, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(v * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w
