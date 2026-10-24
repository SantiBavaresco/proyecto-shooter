extends Node
## Saca capturas de las pantallas principales para revisar a ojo.
## Necesita pantalla (no --headless). Uso:
##   godot --path . --fixed-fps 60 --resolution 1600x900 res://tests/screenshots/screenshot_runner.tscn -- --out=<carpeta>

const TitleScreen := preload("res://ui/title/title_screen.tscn")
const Level := preload("res://world/test_greybox/test_greybox.tscn")
const OptionsMenu := preload("res://ui/options/options_menu.gd")

var out_dir: String = "user://screenshots"
var only_weapons: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		if arg == "--solo-armas":
			only_weapons = true
	DirAccess.make_dir_recursive_absolute(out_dir)
	await _frames(3)

	# 1. Título
	var title := TitleScreen.instantiate()
	add_child(title)
	await _frames(4)
	await _shot("01_titulo")
	title.queue_free()
	await _frames(2)

	# Nivel con bot
	var level := Level.instantiate()
	add_child(level)
	var player: Player = level.get_node("Player")
	var bot := BotInputProvider.new()
	player.set_input_provider(bot)
	GameState.state = GameState.State.PLAYING
	await _frames(10)

	# Con --solo-armas se saltean las capturas de F0
	if not only_weapons:
		# 2. Vista general desde el spawn
		await _place(player, Vector3(0, 0.05, 6), 0.35, -0.12)
		await _shot("02_pista_general")

		# 3. Saltos y rampas
		await _place(player, Vector3(6, 0.05, 2), -0.55, -0.05)
		await _shot("03_saltos_y_rampas")

		# 4. Dentro del túnel, agachado
		bot.crouch = true
		await _place(player, Vector3(-10, 0.05, -2.5), 0.0, -0.05)
		bot.move = Vector2(0, 1)
		await _frames(70)
		bot.move = Vector2.ZERO
		await _frames(20)
		await _shot("04_tunel_agachado")
		bot.crouch = false

		# 5. Esquina: inclinado a la derecha mirando los postes
		await _place(player, Vector3(2.7, 0.05, -43.4), -0.25, 0.0)
		bot.lean = 1.0
		await _frames(40)
		await _shot("05_inclinacion_esquina")
		bot.lean = 0.0
		await _frames(30)

		# 6. Contenedores
		await _place(player, Vector3(-12, 0.05, -30), 0.75, 0.05)
		await _shot("06_contenedores")

		# 7. Datos de rendimiento (F1)
		await _place(player, Vector3(0, 0.05, 6), 0.35, -0.12)
		DebugTools.toggle_overlay()
		await _frames(20)
		await _shot("07_debug_f1")
		DebugTools.toggle_overlay()

		# 8. Pausa
		GameState.set_paused(true)
		await _frames(6)
		await _shot("08_pausa")
		GameState.set_paused(false)
		await _frames(4)

		# 9. Opciones → Controles
		var opts := Control.new()
		opts.set_script(OptionsMenu)
		var layer := CanvasLayer.new()
		layer.layer = 60
		add_child(layer)
		layer.add_child(opts)
		await _frames(4)
		(opts.find_children("*", "TabContainer", true, false)[0] as TabContainer).current_tab = 1
		await _frames(4)
		await _shot("09_opciones_controles")

		layer.queue_free()
		await _frames(3)


	# --- F1: armas en el polígono ---
	var w := player.weapons
	CombatWorld.get_for(player).hitstop_enabled = false
	var cx := 30.0
	# 10. Fusil desde la cadera mirando el polígono
	await _place(player, Vector3(cx - 1.0, 0.05, 29.0), PI, -0.02)
	await _shot("10_fusil_cadera")
	# 11. Apuntando con la red dot al maniquí de 10 m
	var dummy := level.get_node("Geometry/Dummy10m") as Node3D
	bot.aim = true
	await _frames(40)
	await _aim_at(player, dummy.global_position + Vector3(0, 1.2, 0))
	await _frames(20)
	await _shot("11_fusil_red_dot")
	# 12. Disparo: fogonazo y trazadora (modo automático)
	bot.press_fire_mode()
	await _frames(3)
	bot.fire = true
	await _frames(9)
	await _shot("12_fusil_disparando")
	bot.fire = false
	await _frames(40)
	await _shot("13_impactos_y_dano")
	bot.aim = false
	await _frames(20)
	# 14. Recargando (a mitad de la animación)
	bot.press_reload()
	await _frames(int(w.current_data().reload_time * 60.0 * 0.4))
	await _shot("14_recarga_fusil")
	await _frames(120)
	# 15. Escopeta apuntando (guion de la banda)
	bot.select_slot(2)
	await _frames(60)
	bot.aim = true
	await _frames(40)
	await _aim_at(player, dummy.global_position + Vector3(0, 1.2, 0))
	await _frames(15)
	await _shot("15_escopeta_apuntando")
	bot.press_fire()
	await _frames(4)
	await _shot("16_escopeta_disparo")
	bot.aim = false
	bot.press_reload()
	await _frames(int(w.current_data().reload_time_empty * 60.0 * 0.4))
	await _shot("17_escopeta_quebrada")
	await _frames(150)
	# 18. Pistola apuntando
	bot.select_slot(3)
	await _frames(50)
	bot.aim = true
	await _frames(30)
	await _aim_at(player, dummy.global_position + Vector3(0, 1.2, 0))
	await _frames(15)
	await _shot("18_pistola_apuntando")
	bot.aim = false
	# 19. Trayectorias (F3) hacia la diana de 200 m
	DebugTools.show_trajectories = true
	bot.select_slot(1)
	await _frames(50)
	var far := level.get_node("Geometry/Target200m") as Node3D
	await _place(player, Vector3(far.global_position.x - 6.0, 0.05, 29.0), PI, 0.0)
	await _aim_at(player, far.global_position + Vector3(0, 2.1, 0))
	bot.aim = true
	await _frames(30)
	for i in 4:
		bot.press_fire()
		await _frames(12)
	bot.aim = false
	await _frames(25)
	await _place_keep(player, Vector3(far.global_position.x - 9.0, 0.05, 26.0), PI - 0.25, -0.05)
	await _shot("19_trayectorias_200m")
	DebugTools.show_trajectories = false

	print("CAPTURAS_OK -> ", ProjectSettings.globalize_path(out_dir))
	get_tree().quit()


func _aim_at(player: Player, target: Vector3) -> void:
	var eye := player.camera.global_position
	var d := target - eye
	player.yaw = atan2(-d.x, -d.z)
	player.pitch_angle = atan2(d.y, Vector2(d.x, d.z).length())
	await _frames(2)


func _place_keep(player: Player, pos: Vector3, yaw: float, pitch: float) -> void:
	player.teleport(pos, yaw)
	player.pitch_angle = pitch
	await _frames(10)


func _place(player: Player, pos: Vector3, yaw: float, pitch: float) -> void:
	player.teleport(pos, yaw)
	player.pitch_angle = pitch
	await _frames(40)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := out_dir.path_join(shot_name + ".png")
	img.save_png(path)
	print("captura: ", path)
