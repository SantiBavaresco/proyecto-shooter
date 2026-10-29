extends SceneTree
## Vista de frente de los personajes de prueba (con y sin animación).
var out := "user://npc"
var names: PackedStringArray = ["fsb"]
var anim_too := false
func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.trim_prefix("--out=")
		if a.begins_with("--names="): names = a.trim_prefix("--names=").split(",")
		if a == "--anim": anim_too = true
	DirAccess.make_dir_recursive_absolute(out)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.75, 0.78, 0.8)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	root.add_child(env)
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-35, 20, 0); root.add_child(l)
	_run.call_deferred()

func _run() -> void:
	get_root().get_tree().create_timer(200.0).timeout.connect(quit)
	var cam := Camera3D.new(); root.add_child(cam); cam.current = true
	cam.fov = 35
	var x := 0.0
	var dummies := []
	for n in names:
		for anim in ([false, true] if anim_too else [false]):
			var d := NpcDummy.new()
			d.scene_path = "res://assets/models/npc/%s/%s.glb" % [n, n]
			if anim:
				d.idle_anim = "Animation" if n != "pmc" else "Take 001"
			d.remove_nvg = not anim
			d.position = Vector3(x, 0, 0)
			root.add_child(d)
			dummies.append(d)
			x += 1.0
	await process_frame
	await process_frame
	cam.global_position = Vector3(x * 0.5 - 0.5, 1.0, 9.0)
	cam.look_at(Vector3(x * 0.5 - 0.5, 0.9, 0))
	for k in 4: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("npcs.png"))
	# Uno caído (tiro de frente)
	var info := HitInfo.new(); info.damage = 200; info.direction = Vector3(0, 0, -1); info.zone = "torso"; info.position = Vector3(0, 1.3, 0)
	dummies[0].apply_hit(info)
	if dummies.size() > 1:
		var info2 := HitInfo.new(); info2.damage = 120; info2.direction = Vector3(1, 0, 0); info2.zone = "head"; info2.position = Vector3(1, 1.6, 0)
		dummies[1].apply_hit(info2)
	for k in 90: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("npcs_down.png"))
	quit()
