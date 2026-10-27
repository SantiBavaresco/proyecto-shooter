extends Node
## Capturas del estrés y de las fallas: zonas, visión con estrés, recarga con estrés
## (intentos al brocal), olvido de montar y destrabado de cada falla.
## Uso: godot --path . --fixed-fps 60 --resolution 1600x900 res://tests/screenshots/stress_shots.tscn -- --out=<carpeta> [--solo=zonas,recarga,fallas]

const Level := preload("res://world/test_greybox/test_greybox.tscn")

var out_dir := "user://screenshots_stress"
var only: PackedStringArray = []
var level: Node3D
var player: Player
var bot: BotInputProvider


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		if arg.begins_with("--solo="):
			only = arg.trim_prefix("--solo=").split(",", false)
	DirAccess.make_dir_recursive_absolute(out_dir)
	level = Level.instantiate()
	add_child(level)
	player = level.get_node("Player")
	bot = BotInputProvider.new()
	player.set_input_provider(bot)
	GameState.state = GameState.State.PLAYING
	await _frames(10)
	CombatWorld.get_for(player).hitstop_enabled = false
	var dummy := (level.get_node("Geometry/Dummy15m") as Node3D).global_position + Vector3(0, 1.2, 0)

	if only.is_empty() or "zonas" in only:
		player.teleport(Vector3(31, 0.05, 32.5), 0.0)
		await _frames(3)
		_look(Vector3(28, 0.0, 27.8))
		await _frames(40)
		await _shot("S0_zonas")
		# Calma vs estrés alto, cadera y apuntando
		await _equip("akm")
		player.teleport(_zone("stress_high"), PI)
		await _frames(1)
		player.stress.value = 0.0
		player.stress.target = 0.0
		_look(dummy)
		await _frames(2)
		await _shot("S1_calma_cadera")
		player.teleport(_zone("stress_medium"), PI)
		await _frames(300)
		_look(dummy)
		await _frames(2)
		await _shot("S1b_estres_medio_cadera")
		player.teleport(_zone("stress_high"), PI)
		await _frames(240)
		_look(dummy)
		await _frames(2)
		await _shot("S2_estres_alto_cadera")
		bot.aim = true
		await _frames(40)
		_look(dummy)
		for i in 3:
			await _frames(20)
			await _shot("S3_estres_alto_apuntando_%d" % i)
		bot.aim = false
		await _frames(20)
		# Extremo: visión de túnel
		player.teleport(_zone("stress_extreme"), PI)
		await _frames(240)
		_look(dummy)
		await _frames(2)
		await _shot("S4_estres_extremo_cadera")
		bot.aim = true
		await _frames(40)
		_look(dummy)
		await _frames(10)
		await _shot("S5_estres_extremo_apuntando")
		bot.aim = false
		await _frames(20)

	if only.is_empty() or "recarga" in only:
		await _equip("akm")
		player.teleport(_zone("stress_extreme"), PI)
		await _frames(240)
		_look(dummy)
		var c := player.weapons.current()
		c.mag = 0
		player.weapons._rng.seed = 3
		bot.press_reload()
		await _frames(2)
		await _seq("R_akm_estres", [0.15, 0.3, 0.38, 0.44, 0.5, 0.56, 0.62, 0.7, 0.8, 0.9])
		player.weapons.current().malfunction = ""

	if only.is_empty() or "fallas" in only or "sks" in only:
		player.teleport(Vector3(30, 0.05, 31.5), PI)
		await _frames(200)  # se calma
		for spec: Array in ([["g3", "stovepipe"], ["g3", "double_feed"], ["akm", "misfire"], ["pistol", "unchambered"], ["mp5", "misfire"]] if not "sks" in only else [["sks", "misfire"], ["sks", "stovepipe"]]):
			await _equip(spec[0])
			_look(dummy)
			var c := player.weapons.current()
			c.malfunction = spec[1]
			c.case_stuck = spec[1] == "stovepipe"
			player.weapons._emit_state()
			await _frames(5)
			await _shot("F_%s_%s_0" % spec)
			bot.press_reload()
			await _frames(2)
			await _seq("F_%s_%s" % spec, [0.15, 0.3, 0.45, 0.6, 0.75, 0.9])
	if "escopeta" in only:
		await _equip("shotgun")
		player.teleport(_zone("stress_extreme"), PI)
		await _frames(240)
		_look(dummy)
		player.weapons.current().mag = 0
		player.weapons._rng.seed = 7
		bot.press_reload()
		await _frames(2)
		print("FUMBLES ", player.weapons.break_fumbles, " DUR ", player.weapons.state_duration)
		await _seq("E_escopeta_estres", [0.1, 0.2, 0.3, 0.42, 0.5, 0.58, 0.66, 0.74, 0.82, 0.92])

	if "penetracion" in only:
		# Estación de penetración: un tiro de fusil y uno de pistola a cada panel
		for id: String in ["akm", "pistol"]:
			await _equip(id)
			for i in 4:
				var px: float = [9.0, 10.4, 11.8, 13.2][i]
				# Desde atrás de cada panel, derecho: la bala sigue hacia su diana
				player.teleport(Vector3(px, 0.05, 31.0), PI)
				await _frames(3)
				_look(Vector3(px + (0.1 if id == "pistol" else -0.1), 1.5 + (0.08 if id == "pistol" else -0.05), 34.0))
				await _frames(3)
				bot.press_fire()
				await _frames(12)
		player.teleport(Vector3(11.1, 0.05, 32.2), PI)
		await _frames(3)
		_look(Vector3(11.1, 1.3, 36.5))
		await _frames(20)
		await _shot("P0_paneles")
		player.teleport(Vector3(11.1, 0.05, 34.9), PI)
		await _frames(3)
		_look(Vector3(11.1, 1.5, 36.5))
		await _frames(20)
		await _shot("P1_dianas_detras")
	print("CAPTURAS_OK -> ", ProjectSettings.globalize_path(out_dir))
	get_tree().quit()


func _equip(id: String) -> void:
	var d := load("res://data/weapons/%s.tres" % id) as WeaponData
	var slot := 3 if d.slot == 3 else 1
	bot.aim = false
	player.weapons.equip_weapon(d, slot)
	bot.select_slot(slot)
	await _frames(50)


func _zone(kind: String) -> Vector3:
	return (level.find_child("Zone_" + kind, true, false) as Node3D).global_position + Vector3(0, 0.05, 0.6)


## Fotos de la acción en curso en las fracciones dadas.
func _seq(prefix: String, fracs: Array) -> void:
	var dur := player.weapons.state_duration
	var prev := 0.0
	for f: float in fracs:
		await _frames(maxi(1, int(dur * 60.0 * (f - prev))))
		prev = f
		await _shot("%s_%02d" % [prefix, int(f * 100)])
	await _frames(int(dur * 60.0 * (1.0 - prev)) + 10)


func _look(target: Vector3) -> void:
	var d := target - player.camera.global_position
	player.yaw = atan2(-d.x, -d.z)
	player.pitch_angle = atan2(d.y, Vector2(d.x, d.z).length())


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(n + ".png"))
