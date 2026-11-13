extends Node
## Comparación del campo de visión: la misma escena (enemigos a 10, 25 y 50 m) con el
## FOV tomado como vertical (como estaba) y como horizontal (como en los shooters).

const Level := preload("res://world/test_greybox/test_greybox.tscn")

var out_dir := "user://fov"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_tree().create_timer(400.0).timeout.connect(func() -> void: get_tree().quit())
	DebugTools.god_mode = true
	var level := Level.instantiate()
	add_child(level)
	var player: Player = level.get_node("Player")
	player.set_input_provider(BotInputProvider.new())
	GameState.state = GameState.State.PLAYING
	await _frames(60)
	var base := Vector3(30, 0.05, 20)
	player.teleport(base, 0.0)
	var dists := [10.0, 25.0, 50.0]
	var xs := [-1.5, 1.8, -0.5]
	for i in 3:
		var n := HumanNpc.new()
		n.loadout_id = "mil_rifle"
		n.weapon_id = "hk416"
		n.seed_value = 10 + i
		n.ai_enabled = false
		n.position = base + Vector3(xs[i], 0, -dists[i])
		n.rotation = Vector3(0, PI, 0)
		level.add_child(n)
	await _frames(40)
	player.set_physics_process(false)
	var cases := [["A_actual_vertical80", 80.0, Camera3D.KEEP_HEIGHT], ["B_horizontal90", 90.0, Camera3D.KEEP_WIDTH],
		["C_horizontal80", 80.0, Camera3D.KEEP_WIDTH]]
	for c: Array in cases:
		player.camera.keep_aspect = c[2]
		player.camera.fov = c[1]
		Settings.set_value("video", "fov", c[1])
		await _frames(20)
		player.camera.fov = c[1]
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir.path_join(String(c[0]) + ".png"))
	get_tree().quit()


func _frames(k: int) -> void:
	for i in k:
		await get_tree().process_frame
