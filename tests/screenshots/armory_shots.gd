extends Node
## Capturas de la armería y de cada arma (cadera y apuntando).
## Uso: godot --path . --fixed-fps 60 --resolution 1600x900 res://tests/screenshots/armory_shots.tscn -- --out=<carpeta> [--ids=ak74,svd]

const Level := preload("res://world/test_greybox/test_greybox.tscn")

var out_dir := "user://screenshots_armory"
var ids: PackedStringArray = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		if arg.begins_with("--ids="):
			ids = arg.trim_prefix("--ids=").split(",")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var level := Level.instantiate()
	add_child(level)
	var player: Player = level.get_node("Player")
	var bot := BotInputProvider.new()
	player.set_input_provider(bot)
	GameState.state = GameState.State.PLAYING
	await _frames(10)
	CombatWorld.get_for(player).hitstop_enabled = false

	# Vista general de la armería
	player.teleport(Vector3(30, 0.05, 28.5), 0.0)
	player.pitch_angle = -0.32
	await _frames(40)
	await _shot("A0_armeria")
	player.teleport(Vector3(22.5, 0.05, 22.5), 0.0)
	player.pitch_angle = -0.55
	await _frames(30)
	await _shot("A1_mesas_cerca")

	if ids.is_empty():
		ids = PackedStringArray(JSON.parse_string(FileAccess.get_file_as_string("res://data/weapons/catalog.json")))
	var dummy := level.get_node("Geometry/Dummy15m") as Node3D
	player.teleport(Vector3(30, 0.05, 30), PI)
	await _frames(20)
	for id in ids:
		var d := load("res://data/weapons/%s.tres" % id) as WeaponData
		var slot := 3 if d.slot == 3 else 1
		bot.aim = false
		player.weapons.equip_weapon(d, slot)
		bot.select_slot(slot)
		await _frames(50)
		_aim_at(player, dummy.global_position + Vector3(0, 1.2, 0))
		await _frames(10)
		await _shot("W_%s_cadera" % id)
		bot.aim = true
		await _frames(40)
		_aim_at(player, dummy.global_position + Vector3(0, 1.2, 0))
		await _frames(15)
		await _shot("W_%s_apuntando" % id)
		# Escopetas: a mitad de la recarga (caños abiertos)
		if d.reload_type == "break":
			bot.aim = false
			await _frames(30)
			player.weapons.current().mag = 0
			bot.press_reload()
			var prev := 0.0
			for f: float in [0.08, 0.3, 0.42, 0.53, 0.66, 0.9]:
				await _frames(maxi(1, int(d.reload_time_empty * 60.0 * (f - prev))))
				prev = f
				await _shot("W_%s_recarga_%02d" % [id, int(f * 100)])
			await _frames(int(d.reload_time_empty * 60.0 * 0.3))
	# Visor variable del R-700: 5× y 25× sobre la diana de 200 m
	if "rem700" in ids:
		var d := load("res://data/weapons/rem700.tres") as WeaponData
		bot.aim = false
		player.weapons.equip_weapon(d, 1)
		bot.select_slot(1)
		await _frames(50)
		var target := level.get_node("Geometry/Target200m") as Node3D
		bot.aim = true
		await _frames(40)
		_aim_at(player, target.global_position + Vector3(0, 1.0, 0))
		await _frames(15)
		await _shot("Z_rem700_5x")
		bot.press_zoom(30)
		await _frames(10)
		_aim_at(player, target.global_position + Vector3(0, 1.0, 0))
		await _frames(10)
		await _shot("Z_rem700_25x")
		# Disparo con el gatillo apretado: el cerrojo se acciona sin salir del visor
		bot.fire = true
		await _frames(int(d.cycle_time * 30.0))
		await _shot("Z_rem700_cerrojo_en_visor")
		bot.fire = false
		bot.aim = false
	print("CAPTURAS_OK -> ", ProjectSettings.globalize_path(out_dir))
	get_tree().quit()


func _aim_at(player: Player, target: Vector3) -> void:
	var d := target - player.camera.global_position
	player.yaw = atan2(-d.x, -d.z)
	player.pitch_angle = atan2(d.y, Vector2(d.x, d.z).length())


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(n + ".png"))
