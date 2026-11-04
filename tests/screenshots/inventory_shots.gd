extends Node
## Capturas de la F2: zona de saqueo, inventario solo, revisando un cajón y un cuerpo,
## HUD con salud / sangrado / ranuras rápidas y usando una venda.
## Uso: godot --path . --fixed-fps 60 --resolution 1600x900 res://tests/screenshots/inventory_shots.tscn -- --out=<carpeta>

const Level := preload("res://world/test_greybox/test_greybox.tscn")

var out_dir := "user://screenshots_inventory"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_tree().create_timer(900.0).timeout.connect(func() -> void: get_tree().quit())
	var level := Level.instantiate()
	add_child(level)
	var player: Player = level.get_node("Player")
	var bot := BotInputProvider.new()
	player.set_input_provider(bot)
	GameState.state = GameState.State.PLAYING
	await _frames(20)
	var scr := level.find_child("InventoryScreen", true, false) as InventoryScreen
	var pinv := player.inventory

	# Zona de saqueo
	player.teleport(Vector3(9.5, 0.05, 4.5), PI)
	player.pitch_angle = -0.38
	await _frames(60)
	await _shot("I0_zona_saqueo")

	# Inventario solo (con algo de daño para que se vea la salud)
	player.take_damage(28.0, 1)
	scr.open(null)
	await _frames(40)
	await _shot("I1_inventario")
	# Señalando un silenciador: se marcan en verde las armas donde va
	pinv.receive(ItemStack.make("supp_545"))
	pinv.receive(ItemStack.make("mag_pist_9x19", 1, {"rounds": 15}))
	scr._refresh()
	var sup := pinv.first_stack("supp_545")
	scr._selected = sup
	scr._mark_compat(sup)
	scr._show_info(sup)
	await _frames(20)
	await _shot("I1b_compatibles")
	# Ficha de un arma comparada: se agrega un AR-M a la mochila y se selecciona
	pinv.bag.add_item("w_akm")
	scr._selected = pinv.first_stack("w_akm")
	scr._refresh()
	await _frames(20)
	await _shot("I2_ficha_comparada")
	scr.close()

	# Revisando el alijo (ventana doble)
	var stash := level.find_child("LootStash", true, false) as LootContainer
	player.teleport(stash.global_position + Vector3(0, 0.05, -1.6), PI)
	await _frames(10)
	scr.open(stash)
	await _frames(40)
	await _shot("I3_revisando_alijo")
	scr.close()
	# Caja de armas y caja con chalecos y mochilas
	for nm: String in ["LootWeapons", "LootGear"]:
		var box := level.find_child(nm, true, false) as LootContainer
		if box != null:
			box.ensure_filled()
			scr.open(box)
			await _frames(30)
			await _shot("I3b_%s" % nm)
			scr.close()
	scr.open(stash)
	await _frames(20)
	scr.take_all()
	await _frames(20)
	await _shot("I4_sobrecarga")
	scr.close()
	await _frames(10)
	await _shot("I5_hud_sobrecarga")
	pinv.bag.take("vest_plate", 5)
	pinv.bag.take("tools_basic", 10)
	pinv.bag.take("w_svd", 5)

	# Cuerpo revisado
	var npc := level.find_child("Npc_swat", true, false) as NpcDummy
	var hi := HitInfo.new()
	hi.damage = 200.0
	hi.zone = "torso"
	hi.direction = Vector3(0, 0, 1)
	hi.position = npc.global_position + Vector3(0, 1.3, 0)
	npc.apply_hit(hi)
	player.teleport(npc.global_position + Vector3(0, 0.05, -3.2), PI)
	await _frames(80)
	_aim_at(player, npc.global_position + Vector3(0, 0.2, 1.0))
	await _frames(10)
	await _shot("I6_cuerpo")
	npc.interact(player)
	await _frames(40)
	await _shot("I7_revisando_cuerpo")
	scr.close()

	# Usando una venda (HUD)
	player.teleport(Vector3(30, 0.05, 31.5), 0.0)
	player.pitch_angle = -0.1
	await _frames(40)
	bot.press_quick(0)
	await _frames(50)
	await _shot("I8_usando_venda")

	# Mesas de armas nuevas con el dron
	var drone := level.find_child("Item_drone", true, false) as Node3D
	if drone != null:
		player.teleport(drone.global_position + Vector3(-2.0, 0.05, 4.5), 0.0)
		await _frames(10)
		_aim_at(player, drone.global_position + Vector3(-2.0, 0.0, 0.0))
		await _frames(40)
		await _shot("I9_mesas_nuevas")

	# Sombra del jugador vista desde afuera (el cuerpo solo da sombra)
	player.teleport(Vector3(30, 0.05, 31.5), 0.0)
	player.pitch_angle = 0.0
	await _frames(20)
	var cam := Camera3D.new()
	level.add_child(cam)
	cam.global_position = player.global_position + Vector3(3.5, 3.2, 3.5)
	cam.look_at(player.global_position + Vector3(0, 0.2, 0))
	cam.current = true
	await _frames(20)
	await _shot("I10_sombra_parado")
	bot.move = Vector2(0, 1)
	await _frames(25)
	cam.global_position = player.global_position + Vector3(3.5, 3.2, 3.5)
	cam.look_at(player.global_position + Vector3(0, 0.2, 0))
	await _frames(1)
	await _shot("I11_sombra_caminando")
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
