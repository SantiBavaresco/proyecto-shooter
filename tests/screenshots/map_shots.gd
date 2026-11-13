extends Node
## Captura del mapa en tiempo real ([M]) en la Isla Talavera.

const Zone := preload("res://world/zone_talavera/zone_talavera.tscn")

var out_dir := "user://map_shots"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_tree().create_timer(200.0).timeout.connect(func() -> void: get_tree().quit())
	DebugTools.god_mode = true
	var zone := Zone.instantiate()
	add_child(zone)
	await _frames(150)
	var ms := get_tree().root.find_children("MapScreen", "MapScreen", true, false)
	if ms.is_empty():
		push_error("sin MapScreen")
		get_tree().quit()
		return
	var map := ms[0] as MapScreen
	await map.open()
	await _frames(20)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join("map_full.png"))
	# Zoom sobre el jugador
	var p := get_tree().get_first_node_in_group("player") as Player
	map._zoom = 3.5
	map._pan = Vector2.ZERO
	var s := map._w2s(p.global_position)
	map._pan = map._view.size * 0.5 - s
	await _frames(10)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join("map_zoom.png"))
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
