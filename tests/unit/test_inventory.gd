extends TestCase
## Grilla de inventario, catálogo de ítems y salud (sin escena).

var inv: Inventory


func before_each() -> void:
	inv = Inventory.new(6, 4)


func test_catalog_has_weapons_ammo_and_items() -> void:
	var catalog: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/weapons/catalog.json"))
	assert_eq(ItemDB.weapon_item_ids().size(), catalog.size(), "un ítem por arma")
	for wid: String in catalog:
		var it := ItemDB.get_item(ItemDB.weapon_item_id(wid))
		assert_true(it != null and it.weapon() != null, "%s: ítem de arma" % wid)
		assert_true(ItemDB.ammo_id(it.caliber) != "", "%s: hay munición para %s" % [wid, it.caliber])
		assert_gt(float(it.size.x * it.size.y), 3.0, "%s: ocupa lugar" % wid)
	for id: String in ["bandage", "medkit", "medkit_army", "energy_drink", "water", "canned_meat", "bread",
			"helmet_steel", "vest_light", "vest_plate", "backpack_small", "backpack_large", "cash"]:
		assert_true(ItemDB.has(id), "existe " + id)
	assert_eq(ItemDB.ammo_id(".308"), ItemDB.ammo_id("7.62×51"), ".308 y 7.62×51 comparten munición")


func test_items_have_translations() -> void:
	for id: String in ItemDB.all_ids():
		var it := ItemDB.get_item(id)
		assert_true(TranslationServer.translate(it.name_key) != it.name_key, "nombre de " + id)
		assert_true(TranslationServer.translate(it.desc_key) != it.desc_key, "descripción de " + id)


func test_place_and_overlap() -> void:
	var a := ItemStack.make("w_ak74")  # 5×2
	assert_true(inv.place(a, Vector2i(0, 0)))
	var b := ItemStack.make("medkit")  # 1×2
	assert_false(inv.place(b, Vector2i(4, 1)), "pisa al fusil")
	assert_false(inv.place(b, Vector2i(5, 3)), "se sale de la grilla")
	assert_true(inv.place(b, Vector2i(5, 0)))
	assert_eq(inv.stack_at(Vector2i(3, 1)), a)
	assert_eq(inv.stack_at(Vector2i(5, 1)), b)
	assert_eq(inv.stack_at(Vector2i(0, 3)), null)


func test_rotation_swaps_size() -> void:
	var a := ItemStack.make("w_ak74")
	assert_false(inv.place(a, Vector2i(0, 0), true), "girado (2×5) no entra en 4 de alto")
	var tall := Inventory.new(4, 6)
	assert_true(tall.place(a, Vector2i(0, 0), true), "girado entra en una grilla alta")
	assert_eq(a.cells(), Vector2i(2, 5))


func test_add_stacks_and_splits_big_amounts() -> void:
	var cap := ItemDB.get_item("ammo_9x19").stack_max
	assert_eq(inv.add_item("ammo_9x19", cap + 10), 0)
	assert_eq(inv.count_of("ammo_9x19"), cap + 10)
	assert_eq(inv.stacks.size(), 2, "dos pilas")
	assert_eq(inv.add_item("ammo_9x19", 5), 0)
	assert_eq(inv.stacks.size(), 2, "completa la pila incompleta")
	assert_eq(inv.count_of("ammo_9x19"), cap + 15)


func test_add_reports_leftover_when_full() -> void:
	var small := Inventory.new(2, 2)
	assert_eq(small.add_item("helmet_steel", 2), 1, "solo entra uno de 2×2")
	assert_eq(small.count_of("helmet_steel"), 1)
	assert_false(small.can_add(ItemStack.make("bandage")))


func test_take_and_set_count() -> void:
	inv.add_item("bandage", 7)
	assert_eq(inv.take("bandage", 3), 3)
	assert_eq(inv.count_of("bandage"), 4)
	assert_eq(inv.take("bandage", 10), 4, "saca lo que hay")
	assert_true(inv.is_empty())
	inv.set_count("ammo_12g", 30)
	assert_eq(inv.count_of("ammo_12g"), 30)
	inv.set_count("ammo_12g", 12)
	assert_eq(inv.count_of("ammo_12g"), 12)


func test_split_and_merge() -> void:
	inv.add_item("bandage", 8)
	var s := inv.stacks[0]
	var part := inv.split(s, 3)
	assert_true(part != null)
	assert_eq(s.count, 5)
	assert_eq(part.count, 3)
	assert_eq(inv.merge(part, s), 0)
	assert_eq(s.count, 8)
	assert_eq(inv.stacks.size(), 1)


func test_weapons_keep_their_state_and_do_not_stack() -> void:
	var a := ItemStack.make("w_pistol", 1, {"mag": 4, "condition": 0.5})
	var b := ItemStack.make("w_pistol")
	assert_false(a.can_merge(b))
	assert_eq(int(a.state["mag"]), 4)
	assert_eq(int(b.state["mag"]), (load("res://data/weapons/pistol.tres") as WeaponData).mag_size, "nueva viene cargada")
	assert_lt(float(a.price()), float(b.price()), "gastada vale menos")


func test_sort_groups_by_kind() -> void:
	var big := Inventory.new(10, 6)
	big.add_item("bandage", 2)
	big.add_item("ammo_545x39", 30)
	big.add_item("w_ak74")
	big.add_item("bread")
	big.sort()
	assert_eq(big.stack_at(Vector2i(0, 0)).item.kind, "weapon", "las armas primero")
	assert_eq(big.count_of("bandage"), 2)
	assert_eq(big.count_of("ammo_545x39"), 30)


func test_weight_and_serialization() -> void:
	inv.add_item("medkit", 2)
	inv.add_item("ammo_12g", 10)
	assert_near(inv.total_weight(), 0.35 * 2 + 0.04 * 10, 0.0001)
	var d := inv.to_dict()
	var other := Inventory.new()
	other.load_dict(d)
	assert_eq(other.count_of("medkit"), 2)
	assert_eq(other.count_of("ammo_12g"), 10)
	assert_eq(other.width, 6)


func test_vitals_bleeding_and_healing() -> void:
	var v := Vitals.new()
	v.damage(20.0, 2)
	assert_eq(v.bleeding, 2)
	for i in 60:
		v.tick(1.0 / 60.0)
	assert_lt(v.health, 80.0, "el sangrado saca vida")
	v.apply_effects(ItemDB.get_item("bandage").effects)
	assert_eq(v.bleeding, 0, "la venda para dos niveles")
	var h := v.health
	v.apply_effects(ItemDB.get_item("canned_meat").effects)
	for i in 120:
		v.tick(1.0 / 60.0)
	assert_gt(v.health, h + 10.5, "la comida cura de golpe y después de a poco")
	assert_true(v.damage(500.0), "muere")
	assert_true(v.dead)
