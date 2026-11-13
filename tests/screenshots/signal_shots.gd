extends Node
## Capturas de las señas (alto, avanzar, flanquear, agacharse) y de un militar de cerca.

const Level := preload("res://world/test_greybox/test_greybox.tscn")

var out_dir := "user://signals"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_tree().create_timer(300.0).timeout.connect(func() -> void: get_tree().quit())
	DebugTools.god_mode = true
	var level := Level.instantiate()
	add_child(level)
	var player: Player = level.get_node("Player")
	player.set_input_provider(BotInputProvider.new())
	await _frames(60)
	player.teleport(Vector3(20, 0.05, 40), 0.0)
	var n := HumanNpc.new()
	n.loadout_id = "mil_leader"
	n.weapon_id = "hk416"
	n.seed_value = 77
	n.ai_enabled = false
	n.position = Vector3(-10, 0.05, 20)
	n.rotation = Vector3(0, PI * 0.15, 0)
	level.add_child(n)
	await _frames(30)
	n.raised = false
	for c in level.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	var cam := Camera3D.new()
	level.add_child(cam)
	cam.global_position = n.global_position + Vector3(-0.9, 1.55, -2.1)
	cam.look_at(n.global_position + Vector3(0, 1.25, 0))
	cam.fov = 55
	cam.current = true
	await _frames(20)
	for k in ["hold", "advance", "flank", "down"]:
		n.body.play_signal(k, 3.0)
		await _frames(35)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("SG_%s.png" % k))
		await _frames(60)
	get_tree().quit()


func _frames(c: int) -> void:
	for i in c:
		await get_tree().process_frame
