extends Node
## Capturas de los animales en la Isla Talavera (perros y jabalíes), de cerca.

const Zone := preload("res://world/zone_talavera/zone_talavera.tscn")

var out_dir := "user://animal_shots"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_tree().create_timer(300.0).timeout.connect(func() -> void: get_tree().quit())
	DebugTools.god_mode = true
	var zone := Zone.instantiate()
	add_child(zone)
	await _frames(150)
	var player := get_tree().get_first_node_in_group("player") as Player
	player.teleport(Vector3(-150, 30, 150), 0.0)
	player.set_physics_process(false)
	for c in zone.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	var cam := Camera3D.new()
	zone.add_child(cam)
	cam.far = 800.0
	cam.fov = 55.0
	cam.current = true
	var k := 0
	for pk in zone.find_children("Pack_*", "AnimalPack", true, false):
		var pack := pk as AnimalPack
		if pack.species == "dog" and k > 0 and k != 2:
			pass
		var c := Vector3.ZERO
		var n := 0
		for m in pack.members:
			c += m.global_position
			n += 1
		c /= maxf(n, 1)
		var dir := Vector3(1, 0, 0.6).normalized()
		cam.global_position = c + dir * 6.5 + Vector3(0, 1.4, 0)
		cam.look_at(c + Vector3(0, 0.4, 0))
		await _frames(30)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("%s_%d.png" % [pack.species, k]))
		k += 1
		if k >= 4:
			break
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
