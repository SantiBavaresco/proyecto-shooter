extends Node
## Capturas de la Isla Talavera (F3): campamento, ruta, bases, enemigos en combate.
## Uso: godot --path . --fixed-fps 60 --resolution 1600x900 res://tests/screenshots/zone_shots.tscn -- --out=<carpeta> [--only=X]

const Level := preload("res://world/zone_talavera/zone_talavera.tscn")

var out_dir := "user://screenshots_zone"
var only := ""
var level: Node3D
var player: Player


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_tree().create_timer(900.0).timeout.connect(func() -> void: get_tree().quit())
	GameState.difficulty = 1
	level = Level.instantiate()
	add_child(level)
	player = level.get_node("Player")
	var bot := BotInputProvider.new()
	player.set_input_provider(bot)
	GameState.state = GameState.State.PLAYING
	DebugTools.god_mode = true
	await _frames(60)
	var b := level as Node
	var views := [
		["Z0_campamento", Vector3(-146, 0, 146), Vector3(-150, 0.8, 150)],
		["Z1_ruta_reten", Vector3(-90, 0, 85), Vector3(-62, 1.0, 60)],
		["Z2_galpon_lejos", Vector3(-12, 0, 18), Vector3(35, 2.0, -25)],
		["Z3_galpon_porton", Vector3(-12, 0, 6), Vector3(10, 1.4, -5)],
		["Z4_galpon_adentro", Vector3(30, 0, -12), Vector3(45, 1.5, -18)],
		["Z5_bombas", Vector3(100, 0, 100), Vector3(128, 2.0, 112)],
		["Z6_chacra", Vector3(-85, 0, -95), Vector3(-105, 1.0, -115)],
	]
	for v: Array in views:
		if only != "" and not String(v[0]).contains(only):
			continue
		var at: Vector3 = v[1]
		var look: Vector3 = v[2]
		var g: Vector3 = b.call("ground", at)
		player.teleport(g + Vector3(0, 0.1, 0))
		await _frames(5)
		var lg: Vector3 = b.call("ground", look) + Vector3(0, look.y, 0)
		_aim_at(lg)
		await _frames(40)
		await _shot(v[0])
	# Vista aérea del galpón
	if only == "" or only.contains("aerea"):
		var cam := Camera3D.new()
		level.add_child(cam)
		cam.global_position = Vector3(-30, 60, 40)
		cam.look_at(Vector3(35, 0, -25))
		cam.current = true
		cam.far = 800
		await _frames(10)
		await _shot("Z7_aerea_galpon")
		cam.global_position = Vector3(-200, 140, 200)
		cam.look_at(Vector3(0, 0, 0))
		await _frames(10)
		await _shot("Z8_aerea_isla")
		cam.queue_free()
		await _frames(2)
	# Combate: el jugador a la vista del portón del galpón
	if only == "" or only.contains("combate"):
		player.teleport((b.call("ground", Vector3(-20, 0, 30)) as Vector3) + Vector3(0, 0.1, 0))
		_aim_at((b.call("ground", Vector3(14, 0, -6)) as Vector3) + Vector3(0, 1.4, 0))
		await _frames(60 * 6)
		await _shot("Z9_combate_1")
		await _frames(60 * 3)
		await _shot("Z9_combate_2")
	get_tree().quit()


func _aim_at(target: Vector3) -> void:
	var d := target - player.camera.global_position
	player.yaw = atan2(-d.x, -d.z)
	player.pitch_angle = atan2(d.y, Vector2(d.x, d.z).length())


func _frames(n: int) -> void:
	# Esperas largas sin dibujar (el render por software es lento)
	if n > 30:
		RenderingServer.render_loop_enabled = false
	for i in n:
		await get_tree().process_frame
	RenderingServer.render_loop_enabled = true
	if n > 30:
		await get_tree().process_frame


func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(n + ".png"))
