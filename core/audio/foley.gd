class_name Foley
extends Node
## Sonidos de "foley" (pasos, abrir cajas, equipar, agarrar y tirar cosas). Los WAV
## salen de tools/audio/gen_foley.py. Se reproducen por un pequeño grupo de
## reproductores en el bus del mundo (se silencian con la pausa).

const DIR := "res://assets/audio/foley/"
const SURFACES := ["concrete", "dirt", "wood", "metal"]
const VOICES := 6

static var _inst: Foley
static var _cache: Dictionary = {}

var _players: Array[AudioStreamPlayer] = []
var _next: int = 0


static func _get_inst(tree: SceneTree) -> Foley:
	if _inst == null or not is_instance_valid(_inst):
		_inst = Foley.new()
		_inst.name = "Foley"
		tree.root.add_child(_inst)
	return _inst


func _ready() -> void:
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX_World"
		add_child(p)
		_players.append(p)


## Sonido por nombre (crate_open, box_open, stash_open, equip, pickup_item,
## pickup_weapon, drop_item).
static func play(tree: SceneTree, sound: String, volume_db := -6.0, pitch_jitter := 0.05) -> void:
	if tree == null:
		return
	var s := stream(sound)
	if s == null:
		return
	var f := _get_inst(tree)
	var p := f._players[f._next]
	f._next = (f._next + 1) % f._players.size()
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
	p.play()


static func stream(sound: String) -> AudioStream:
	if not _cache.has(sound):
		var path := DIR + sound + ".wav"
		_cache[sound] = load(path) if ResourceLoader.exists(path) else null
	return _cache[sound]


## Paso sobre una superficie (variantes al azar y tono apenas distinto).
static func step(surface: String) -> AudioStream:
	var key := "step:" + surface
	if not _cache.has(key):
		var r := AudioStreamRandomizer.new()
		r.random_pitch = 1.08
		r.random_volume_offset_db = 1.5
		var surf := surface if SURFACES.has(surface) else "concrete"
		for i in 4:
			var s := stream("step_%s_%d" % [surf, i + 1])
			if s != null:
				r.add_stream(-1, s)
		_cache[key] = r if r.streams_count > 0 else null
	return _cache[key]


## Superficie de pasos según la del material del piso.
static func step_surface(surface_meta: String) -> String:
	match surface_meta:
		"dirt", "grass", "sand", "mud":
			return "dirt"
		"wood":
			return "wood"
		"metal", "steel", "sheet_metal":
			return "metal"
	return "concrete"
