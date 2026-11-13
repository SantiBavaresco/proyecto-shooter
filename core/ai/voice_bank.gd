class_name VoiceBank
extends RefCounted
## Frases grabadas (sintéticas por ahora, tools/audio/gen_voices.py) de los militares:
## cada voz tiene, por frase, varias variantes en dos registros: grito (lejos o en
## pleno tiroteo) y hablado (cerca).

const INDEX := "res://data/audio/voice_lines.json"
const PATH := "res://assets/audio/voice/%s/%s_%d_%s.wav"

static var _index: Dictionary = {}
static var _cache: Dictionary = {}


static func _load() -> void:
	if not _index.is_empty():
		return
	var f := FileAccess.open(INDEX, FileAccess.READ)
	if f == null:
		return
	var d: Variant = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		_index = d


static func voices() -> Array:
	_load()
	return _index.get("voices", [])


## Un audio de la frase `key` dicha por `voice` (variante al azar); null si no hay.
static func stream(voice: String, key: String, shout: bool, rng: RandomNumberGenerator) -> AudioStream:
	_load()
	var lines: Dictionary = _index.get("lines", {}).get(voice, {})
	var vars: Array = lines.get(key, [])
	if vars.is_empty():
		return null
	var n := int(vars[rng.randi() % vars.size()])
	var p := PATH % [voice, key, n, "shout" if shout else "talk"]
	if not _cache.has(p):
		_cache[p] = load(p) if ResourceLoader.exists(p) else null
	return _cache[p]


## Texto de la frase (para subtítulos o depuración).
static func text(key: String, n: int) -> String:
	_load()
	var t: Array = _index.get("text", {}).get(key, [])
	return String(t[n]) if n < t.size() else key
