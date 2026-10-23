extends Node
## Guardado de partidas. En F0 solo define la estructura; se implementa en F7.
##
## Formato previsto: un archivo por slot en user://saves/, con versión de
## formato para poder migrar partidas viejas cuando cambie el juego.

const SAVE_DIR := "user://saves/"
const FORMAT_VERSION := 1


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)


## Slots existentes (vacío hasta F7).
func list_slots() -> Array[String]:
	return []
