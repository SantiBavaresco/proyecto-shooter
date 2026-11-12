extends Node
## Capturas de la 3.0.1: inventario del piso, mochila y chaleco tirados revisados,
## cartel de mochila, cuchillo en la mano y armas de cadera más arriba.

const Level := preload("res://world/test_greybox/test_greybox.tscn")

var out_dir := "user://screenshots_301"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_tree().create_timer(600.0).timeout.connect(func() -> void: get_tree().quit())
	var level := Level.instantiate()
	add_child(level)
	var player: Player = level.get_node("Player")
	var bot := BotInputProvider.new()
	player.set_input_provider(bot)
	GameState.state = GameState.State.PLAYING
	await _frames(20)
	var scr := level.find_child("InventoryScreen", true, false) as InventoryScreen
	var pinv := player.inventory

	# Armas de cadera
	player.teleport(Vector3(30, 0.05, 31.5), 0.0)
	player.pitch_angle = -0.05
	await _frames(60)
	await _shot("H1_cadera_fusil")
	bot.select_slot(3)
	await _frames(70)
	await _shot("H2_cadera_pistola")
	bot.select_slot(4)
	await _frames(40)
	await _shot("H3_cuchillo")
	bot.select_slot(1)
	await _frames(60)

	# Cosas tiradas alrededor: botiquín, munición, una mochila con cosas y un chaleco
	var p := player.global_position
	var fwd := -player.global_basis.z
	WorldItem.spawn(level, ItemStack.make("medkit", 1), p + fwd * 0.9 + Vector3(0.4, 0.3, 0))
	WorldItem.spawn(level, ItemStack.make(ItemDB.ammo_id("5.45x39"), 60), p + fwd * 1.1 + Vector3(-0.4, 0.3, 0))
	var bag := ItemStack.make("backpack_medium")
	bag.contents[0].add_item("bandage", 4)
	bag.contents[0].add_item("w_ak74u", 1)
	bag.contents[0].add_item("grenade_rg5", 2)
	var wb := WorldItem.spawn(level, bag, p + fwd * 1.3 + Vector3(0, 0.3, 0))
	var rig := ItemStack.make("rig_medium")
	rig.contents[0].add_item("mag_ak545", 1)
	rig.contents[1].add_item("mag_ak545", 1)
	rig.contents[4].add_item("medkit", 1)
	WorldItem.spawn(level, rig, p + fwd * 0.8 + Vector3(-0.8, 0.3, 0.2))
	await _frames(90)
	_aim_at(player, wb.global_position)
	await _frames(15)
	await _shot("G1_mochila_cartel")
	scr.open(null)
	await _frames(30)
	await _shot("G2_inventario_piso")
	scr.open_bag(bag)
	await _frames(30)
	await _shot("G3_revisando_mochila")
	scr.open_bag(rig)
	await _frames(30)
	await _shot("G4_revisando_chaleco")
	scr.close()
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
