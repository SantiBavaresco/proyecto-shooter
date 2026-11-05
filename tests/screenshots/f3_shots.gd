extends Node
## Capturas varias de la F3: menú de la incursión, zona de combate de la pista de
## pruebas, granada y cuchillo en la mano, ficha de un chaleco, cuerpo del jugador.
## Uso: godot --path . --fixed-fps 60 --resolution 1600x900 res://tests/screenshots/f3_shots.tscn -- --out=<carpeta>

const Title := preload("res://ui/title/title_screen.tscn")
const Level := preload("res://world/test_greybox/test_greybox.tscn")

var out_dir := "user://screenshots_f3"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_tree().create_timer(900.0).timeout.connect(func() -> void: get_tree().quit())
	# Menú
	var t := Title.instantiate()
	add_child(t)
	await _frames(10)
	await _shot("F0_menu")
	t.call("_open_raid")
	await _frames(10)
	await _shot("F1_menu_incursion")
	t.queue_free()
	await _frames(2)
	# Pista de pruebas: zona de combate
	GameState.difficulty = 2
	var level := Level.instantiate()
	add_child(level)
	var player: Player = level.get_node("Player")
	var bot := BotInputProvider.new()
	player.set_input_provider(bot)
	GameState.state = GameState.State.PLAYING
	DebugTools.god_mode = true
	await _frames(30)
	player.teleport(Vector3(-49, 0.05, -44), 0.0)
	_aim(player, Vector3(-49, 1.5, -52))
	await _frames(20)
	await _shot("F2_zona_combate_entrada")
	# Adentro: los 5 te ven
	player.teleport(Vector3(-47, 0.05, -56), 0.0)
	_aim(player, Vector3(-48, 1.2, -85))
	bot.select_slot(1)
	await _frames(60 * 5)
	await _shot("F3_zona_combate")
	await _frames(60 * 3)
	await _shot("F3b_zona_combate")
	# Granada y cuchillo en la mano (de vuelta afuera)
	DebugTools.god_mode = true
	player.teleport(Vector3(-40, 0.05, -40), 0.0)
	player.pitch_angle = 0.0
	player.inventory.receive(ItemStack.make("grenade_f1"))
	await _frames(30)
	bot.press_grenade()
	for i in 22:
		await get_tree().process_frame
	await _shot("F4_granada")
	await _frames(60 * 4)
	await _shot("F4b_explosion")
	bot.press_melee()
	for i in 10:
		await get_tree().process_frame
	await _shot("F5_cuchillo")
	await _frames(40)
	# Ficha del chaleco de placas en el inventario
	var scr := level.find_child("InventoryScreen", true, false) as InventoryScreen
	player.inventory.receive(ItemStack.make("vest_plate", 1, {"condition": 0.72}))
	scr.open(null)
	await _frames(20)
	var v := player.inventory.first_stack("vest_plate")
	if v != null:
		scr._selected = v
		scr._show_info(v)
	await _frames(20)
	await _shot("F6_ficha_chaleco")
	scr.close()
	# Muerte: el cuerpo queda y la brújula lo marca
	DebugTools.god_mode = false
	player.teleport(Vector3(10, 0.05, -20), 0.0)
	await _frames(10)
	player.take_damage(500.0)
	await _frames(30)
	await _shot("F7_muerte")
	await _frames(int(60 * (Player.RESTART_AFTER_DEATH + 0.5)))
	_aim(player, Vector3(10, 1.0, -20))
	await _frames(20)
	await _shot("F8_reaparece_cuerpo_marcado")
	get_tree().quit()


func _aim(player: Player, target: Vector3) -> void:
	var d := target - player.camera.global_position
	player.yaw = atan2(-d.x, -d.z)
	player.pitch_angle = atan2(d.y, Vector2(d.x, d.z).length())


func _frames(n: int) -> void:
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
