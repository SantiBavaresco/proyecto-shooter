extends Node3D
## Los modelos de enemigos uno al lado del otro, con una regla de 1,8 m.

func _ready() -> void:
	var out := "user://lineup.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.6, 0.65, 0.7)
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.8
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 0.5, 0)
	add_child(sun)
	var i := 0
	for m in ["fsb", "swat", "swat_special", "swat_remaster"]:
		var b := NpcBody.new()
		b.scene_path = NpcLoadouts.model_path(m)
		b.position = Vector3(i * 1.2 - 1.8, 0, 0)
		add_child(b)
		i += 1
	var ruler := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.05, 1.8, 0.05)
	ruler.mesh = bm
	ruler.position = Vector3(3.0, 0.9, 0)
	add_child(ruler)
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0.6, 1.0, 5.5)
	cam.look_at(Vector3(0.6, 0.9, 0))
	cam.current = true
	for k in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit()
