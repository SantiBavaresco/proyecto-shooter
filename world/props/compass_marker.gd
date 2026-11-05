class_name CompassMarker
extends Node3D
## Lugar que la brújula marca siempre (por ejemplo, el campamento).

@export var label_key: String = ""


func _ready() -> void:
	add_to_group("compass_marker")


func compass_label() -> String:
	return tr(label_key)
