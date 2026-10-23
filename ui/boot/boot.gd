extends Node
## Escena inicial: espera un frame (autoloads listos) y va al título.


func _ready() -> void:
	await get_tree().process_frame
	GameState.goto_title()
