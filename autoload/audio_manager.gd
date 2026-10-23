extends Node
## Buses de audio y reglas globales de sonido.
##
## Buses: Master > Music, Ambience, SFX_World, UI, Voice
##  - Pausa: se silencian Music, Ambience, SFX_World y Voice. UI sigue sonando.
##  - Game over (a futuro): corte inmediato de todo salvo UI y el sting final.

const BUSES: Array[String] = ["Music", "Ambience", "SFX_World", "UI", "Voice"]
const WORLD_BUSES: Array[String] = ["Music", "Ambience", "SFX_World", "Voice"]

var world_paused: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	apply_volumes()


func set_world_paused(paused: bool) -> void:
	world_paused = paused
	for bus_name: String in WORLD_BUSES:
		AudioServer.set_bus_mute(AudioServer.get_bus_index(bus_name), paused)


func apply_volumes() -> void:
	_set_linear("Master", Settings.get_value("audio", "master"))
	_set_linear("Music", Settings.get_value("audio", "music"))
	_set_linear("SFX_World", Settings.get_value("audio", "sfx"))
	_set_linear("Ambience", Settings.get_value("audio", "sfx"))
	_set_linear("Voice", Settings.get_value("audio", "sfx"))
	_set_linear("UI", Settings.get_value("audio", "ui"))


func _set_linear(bus_name: String, value: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(value, 0.0001)))


func _ensure_buses() -> void:
	for bus_name: String in BUSES:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
