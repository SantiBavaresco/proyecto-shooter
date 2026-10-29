extends SceneTree
## Vistas ortográficas de un .glb (lado +X, lado -X, arriba, frente) para calibrar.
## -- --out=<dir> <res://...glb> ...
var out := "user://glbviews"
var paths: Array[String] = []

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.trim_prefix("--out=")
		else: paths.append(a)
	DirAccess.make_dir_recursive_absolute(out)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.75, 0.78, 0.8)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.8, 0.8)
	root.add_child(env)
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-45, 30, 0); root.add_child(l)
	_run.call_deferred()

func _run() -> void:
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	root.add_child(cam); cam.current = true
	for p in paths:
		var inst := (load(p) as PackedScene).instantiate() as Node3D
		root.add_child(inst)
		await process_frame
		var ab := AABB(); var f := true
		for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
			var b := mi.global_transform * mi.get_aabb()
			if f: ab = b; f = false
			else: ab = ab.merge(b)
		var c := ab.get_center()
		var big := maxf(ab.size.x, maxf(ab.size.y, ab.size.z))
		cam.size = big * 1.1
		cam.near = 0.001 * big; cam.far = big * 10
		var nm := p.get_file().get_basename()
		for v in [["xpos", Vector3.RIGHT, Vector3.UP], ["zpos", Vector3.BACK, Vector3.UP], ["ypos", Vector3.UP, Vector3.BACK]]:
			cam.global_transform = Transform3D.IDENTITY.translated(c + v[1] * big * 2.0).looking_at(c, v[2])
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(out.path_join("%s_%s.png" % [nm, v[0]]))
		print(nm, " aabb pos=", ab.position, " size=", ab.size)
		inst.queue_free()
		await process_frame
	quit()
