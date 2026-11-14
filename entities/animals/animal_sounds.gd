class_name AnimalSounds
extends RefCounted
## Sonidos de animales (assets/audio/animals/<especie>_<sonido>_<n>.wav, hechos con
## tools/audio/gen_animals.py). Se cargan una vez y se elige uno al azar.

static var _cache: Dictionary = {}


static func pick(species_id: String, kind: String, r: RandomNumberGenerator) -> AudioStream:
	var key := species_id + "_" + kind
	if not _cache.has(key):
		var list: Array = []
		for i in 8:
			var path := "res://assets/audio/animals/%s_%d.wav" % [key, i]
			if ResourceLoader.exists(path):
				list.append(load(path))
		_cache[key] = list
	var l: Array = _cache[key]
	return null if l.is_empty() else l[r.randi() % l.size()]


## Qué sonido hace cada especie en cada situación.
const VOICE := {
	"hurt": {"dog": "yelp", "boar": "squeal", "capy": "squeal"},
	"bite": {"dog": "growl", "boar": "grunt", "capy": "bark"},
	"flee": {"dog": "whine", "boar": "squeal", "capy": "squeal"},
	"idle": {"dog": "pant", "boar": "grunt", "capy": "click"},
	"dying": {"dog": "whine", "boar": "grunt", "capy": "squeal"},
	"alert": {"dog": "bark", "boar": "snort", "capy": "bark"},
}


static func kind_for(situation: String, species_id: String) -> String:
	return String((VOICE.get(situation, {}) as Dictionary).get(species_id, situation))
