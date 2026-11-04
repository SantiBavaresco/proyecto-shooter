extends TestCase
## Inventario en el juego: equipo inicial, munición compartida, equipar y
## desequipar armas, peso, consumibles, contenedores, ítems sueltos y cuerpos.

const LEVEL := preload("res://world/test_greybox/test_greybox.tscn")

var level: Node3D
var player: Player
var bot: BotInputProvider
var pinv: PlayerInventory
var weapons: WeaponController


func before_each() -> void:
	DebugTools.infinite_ammo = false
	level = LEVEL.instantiate()
	add_child(level)
	player = level.get_node("Player")
	bot = BotInputProvider.new()
	player.set_input_provider(bot)
	pinv = player.inventory
	weapons = player.weapons
	await physics_frames(30)


func after_each() -> void:
	var scr := _screen()
	if scr != null:
		scr.close()
	GameState.ui_open = false
	level.queue_free()
	await process_frames(1)


func _screen() -> InventoryScreen:
	return level.find_child("InventoryScreen", true, false) as InventoryScreen if is_instance_valid(level) else null


func _look_at(target: Vector3) -> void:
	var eye := player.camera.global_position
	var d := target - eye
	player.yaw = atan2(-d.x, -d.z)
	player.pitch_angle = atan2(d.y, Vector2(d.x, d.z).length())
	await process_frames(2)


func test_start_kit() -> void:
	assert_true(pinv.equipment["weapon1"] != null and pinv.equipment["weapon2"] != null and pinv.equipment["pistol"] != null,
		"tres armas equipadas")
	assert_eq(weapons.current_slot, 1, "en la mano el arma 1")
	assert_eq(weapons.current().reserve, weapons.current_data().start_reserve, "munición en la mochila")
	assert_eq((pinv.equipment["melee"] as ItemStack).item.id, "knife", "cuchillo en arma blanca")
	assert_eq(pinv.bag.count_of("bandage"), 3)
	assert_eq(pinv.quick[0], "bandage")
	assert_eq(pinv.money, PlayerInventory.START_MONEY)
	assert_lt(pinv.overload(), 0.001, "sin sobrecarga al empezar")


func test_ammo_is_shared_by_caliber() -> void:
	# Dos armas de 9×19: la pistola inicial y un subfusil en el slot 1
	weapons.equip_weapon(load("res://data/weapons/mp5.tres") as WeaponData, 1, {}, false)
	await physics_frames(30)
	pinv.set_ammo("9×19", 40)
	var smg := weapons.current()
	var pistol := weapons.slots[3] as WeaponController.WeaponSlot
	assert_eq(smg.reserve, 40)
	assert_eq(pistol.reserve, 40, "la pistola ve la misma munición")
	smg.mag = 0
	bot.press_reload()
	await physics_frames(int(weapons.reload_duration(smg) * 60.0) + 90)
	assert_eq(smg.mag, 30)
	assert_eq(pistol.reserve, 10, "la recarga la sacó de la mochila")
	assert_eq(pinv.bag.count_of(ItemDB.ammo_id("9×19")), 10)


func test_unequip_and_equip_keep_weapon_state() -> void:
	var c := weapons.current()
	c.mag = 7
	c.condition = 0.62
	var s := pinv.unequip("weapon1")
	assert_true(s != null and pinv.bag.has_stack(s), "va a la mochila")
	assert_eq(int(s.state["mag"]), 7)
	assert_near(float(s.state["condition"]), 0.62, 0.001)
	assert_eq(weapons.current(), null, "manos vacías")
	bot.press_fire()
	await physics_frames(5)
	assert_true(pinv.equip(s, "weapon1"), "se vuelve a equipar")
	await physics_frames(40)
	assert_eq(weapons.current().mag, 7, "con el mismo cargador")
	assert_near(weapons.current().condition, 0.62, 0.001)
	assert_false(pinv.bag.has_stack(s))


func test_equip_swaps_old_weapon_into_bag() -> void:
	pinv.bag.add_item("w_akm")
	var akm := pinv.first_stack("w_akm")
	var old := pinv.equipment["weapon1"] as ItemStack
	assert_true(pinv.equip(akm, "weapon1"))
	await physics_frames(40)
	assert_eq(weapons.current_data().id, "akm")
	assert_true(pinv.bag.has_stack(old), "la anterior vuelve a la mochila")
	assert_false(pinv.can_equip(akm, "pistol"), "un fusil no va en la pistola")


func test_swap_long_weapons() -> void:
	var a := (pinv.equipment["weapon1"] as ItemStack).item.id
	var b := (pinv.equipment["weapon2"] as ItemStack).item.id
	pinv.swap_weapon_slots()
	await physics_frames(40)
	assert_eq((pinv.equipment["weapon1"] as ItemStack).item.id, b)
	assert_eq((pinv.equipment["weapon2"] as ItemStack).item.id, a)
	assert_eq(weapons.current_data().id, (pinv.equipment["weapon1"] as ItemStack).item.weapon().id)


func test_overload_slows_and_blocks_sprint() -> void:
	player.teleport(Vector3(-2.5, 0.05, -2), 0.0)
	await physics_frames(10)
	bot.move = Vector2(0, 1)
	await physics_frames(60)
	var normal := Vector2(player.velocity.x, player.velocity.z).length()
	pinv.bag.add_item("tools_basic", 1)
	for i in 14:
		pinv.bag.add_item("vest_plate")
	assert_gt(pinv.overload(), 1.0, "pasado el máximo")
	await physics_frames(60)
	var heavy := Vector2(player.velocity.x, player.velocity.z).length()
	assert_lt(heavy, normal * 0.6, "camina mucho más lento")
	bot.sprint = true
	await physics_frames(20)
	assert_false(player.is_sprinting, "no puede correr")
	bot.release_all()
	# Mochila grande: sube el límite
	pinv.bag.clear()
	pinv.bag.add_item("backpack_large")
	var lim := pinv.carry_limit()
	pinv.equip(pinv.first_stack("backpack_large"), "backpack")
	assert_near(pinv.carry_limit(), lim + 20.0, 0.001)


func test_bandage_from_quick_slot_stops_bleeding() -> void:
	player.take_damage(10.0, 2)
	assert_eq(player.vitals.bleeding, 2)
	var before := pinv.bag.count_of("bandage")
	bot.press_quick(0)
	await physics_frames(3)
	assert_true(pinv.is_using(), "empieza a vendarse")
	assert_true(weapons.lowered, "baja el arma")
	bot.press_fire()
	await physics_frames(3)
	assert_eq(weapons.current().mag, weapons.current_data().mag_size, "no dispara usando un ítem")
	await physics_frames(int(ItemDB.get_item("bandage").use_time * 60.0) + 5)
	assert_false(pinv.is_using())
	assert_eq(player.vitals.bleeding, 0, "dejó de sangrar")
	assert_eq(pinv.bag.count_of("bandage"), before - 1, "gastó una venda")
	assert_false(weapons.lowered)


func test_hurt_zone_and_medkit() -> void:
	var z := level.find_child("Zone_hurt", true, false) as Node3D
	player.teleport(z.global_position + Vector3(0, 0.05, 0), 0.0)
	await physics_frames(60)
	assert_lt(player.vitals.health, 95.0, "el alambre lastima")
	assert_gt(float(player.vitals.bleeding), 0.0, "y hace sangrar")
	player.teleport(z.global_position + Vector3(0, 0.05, -4.0), 0.0)
	await physics_frames(5)
	var h := player.vitals.health
	assert_true(pinv.use(pinv.first_stack("medkit")))
	await physics_frames(int(ItemDB.get_item("medkit").use_time * 60.0) + 5)
	assert_gt(player.vitals.health, minf(h + 30.0, 99.9), "el botiquín cura")


func test_energy_drink_restores_stamina() -> void:
	player.stamina.drain(90.0, 1.0)
	assert_true(pinv.use(pinv.first_stack("energy_drink")))
	await physics_frames(int(ItemDB.get_item("energy_drink").use_time * 60.0) + 5)
	assert_gt(player.stamina.current, 95.0)
	assert_gt(player.vitals.stamina_boost, 0.5, "regenera más rápido un rato")


func test_crate_loot_with_inventory_screen() -> void:
	var crate := level.find_child("LootMetal", true, false) as LootContainer
	player.teleport(crate.global_position + Vector3(0, 0.05, -1.6), PI)
	await physics_frames(5)
	await _look_at(crate.global_position + Vector3(0, 0.3, 0))
	bot.press_interact()
	await physics_frames(3)
	var scr := _screen()
	assert_true(scr.is_open, "abre el inventario")
	assert_eq(scr.container, crate, "con la caja al lado")
	assert_true(GameState.ui_open)
	assert_true(crate.inventory.count_of("vest_light") == 1)
	scr.take_all()
	assert_true(crate.inventory.is_empty(), "tomó todo")
	assert_eq(pinv.bag.count_of("vest_light"), 1)
	assert_eq(pinv.bag.count_of("helmet_steel"), 1)
	scr.close()
	assert_false(GameState.ui_open)


func test_ammo_crate_restocks() -> void:
	var crate := level.get_node("Geometry/AmmoCrate") as LootContainer
	var id := ItemDB.ammo_id("12/70")
	crate.inventory.take(id, 1000)
	crate.interact(player)
	await physics_frames(2)
	assert_eq(crate.inventory.count_of(id), ItemDB.get_item(id).stack_max * 2, "se repone al abrir")
	var before := pinv.bag.count_of(id)
	pinv.transfer(crate.inventory.stacks.filter(func(s: ItemStack) -> bool: return s.item.id == id)[0], crate.inventory, pinv.bag)
	assert_gt(float(pinv.bag.count_of(id)), float(before))


func test_pick_up_and_drop_world_items() -> void:
	var cash := level.find_child("Item_cash", true, false) as WorldItem
	assert_true(cash != null, "hay plata suelta")
	var cs := cash.get_children().filter(func(n: Node) -> bool: return n is CollisionShape3D)[0] as CollisionShape3D
	assert_gt(((cs.shape as BoxShape3D).size.x), 0.25, "en el piso se ven al doble (fajo de 15,6 cm → 31 cm)")
	var money := pinv.money
	cash.interact(player)
	await physics_frames(2)
	assert_eq(pinv.money, money + 500, "la plata va al contador")
	var med := level.find_child("Item_medkit", true, false) as WorldItem
	var n := pinv.bag.count_of("medkit")
	med.interact(player)
	await physics_frames(2)
	assert_eq(pinv.bag.count_of("medkit"), n + 1)
	# Tirar: sale del inventario y aparece en el suelo
	var s := pinv.first_stack("bandage")
	pinv.bag.remove(s)
	var w := pinv.drop(s)
	assert_true(w != null and is_instance_valid(w))
	await physics_frames(90)
	assert_lt(w.global_position.y, 0.5, "cayó al piso")
	var count := pinv.bag.count_of("bandage")
	w.interact(player)
	assert_eq(pinv.bag.count_of("bandage"), count + s.count, "se vuelve a agarrar")


func test_loot_dead_npc() -> void:
	var npc := level.find_child("Npc_fsb", true, false) as NpcDummy
	assert_eq(npc.get_interact_text(), "", "vivo no se revisa")
	var info := HitInfo.new()
	info.damage = 200.0
	info.zone = "torso"
	info.direction = Vector3(0, 0, 1)
	info.position = npc.global_position + Vector3(0, 1.3, 0)
	npc.apply_hit(info)
	await process_frames(60)
	assert_true(npc.get_interact_text() != "", "muerto se revisa")
	assert_eq(npc.inventory.count_of("w_ak74"), 1, "lleva su fusil")
	npc.interact(player)
	await physics_frames(2)
	var scr := _screen()
	assert_true(scr.is_open and scr.container == npc)
	assert_true(pinv.transfer(npc.inventory.stacks[0], npc.inventory, pinv.bag))
	scr.close()


func test_unload_weapon_returns_rounds() -> void:
	await physics_frames(40)
	var c := weapons.current()
	var mag := c.mag
	var before := c.reserve
	pinv.unload(pinv.equipment["weapon1"])
	assert_eq(c.mag, 0)
	assert_eq(c.reserve, before + mag)


func test_inventory_blocks_player_input() -> void:
	var scr := _screen()
	scr.open(null)
	assert_true(scr.is_open)
	var h := HumanInputProvider.new()
	var cmd := h.poll_command(0.016)
	assert_eq(cmd.move, Vector2.ZERO, "con el inventario abierto no se mueve")
	h.free()
	scr.close()
	assert_false(scr.is_open)


func test_item_sheet_compares_weapons() -> void:
	var s := ItemStack.make("w_akm")
	var t := InventoryScreen.item_sheet(s, pinv)
	assert_true(t.contains(TranslationServer.translate("inv.stat.damage")), "muestra el daño")
	assert_true(t.contains("(+") or t.contains("(-"), "compara con la equipada")
