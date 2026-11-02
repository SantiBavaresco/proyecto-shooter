class_name AmmoCrate
extends LootContainer
## Caja de munición del laboratorio: [F] la abre como contenedor con dos pilas de
## cada calibre (se repone cada vez que se abre).


func _init() -> void:
	kind = "ammo"
