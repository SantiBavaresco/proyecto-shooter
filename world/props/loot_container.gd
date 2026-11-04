class_name LootContainer
extends StaticBody3D
## Contenedor que se revisa con [F]: abre el inventario en ventana doble (la mochila
## y el contenedor). Tipos:
##  - "crate": cajón de madera.
##  - "metal": caja metálica.
##  - "stash": alijo (bolso escondido), más grande.
##  - "ammo": caja de munición del laboratorio: al abrirla se repone de todo.
##
## El contenido sale de "contents" ([[id, cantidad], ...]) o, si está vacío, de una
## tabla al azar según el tipo.

const SIZES := {"crate": Vector2i(8, 6), "metal": Vector2i(6, 5), "stash": Vector2i(8, 10), "ammo": Vector2i(8, 8)}
## Tabla al azar: [id, mínimo, máximo, probabilidad].
const RANDOM_LOOT := [
	["bandage", 1, 3, 0.6], ["medkit", 1, 1, 0.35], ["canned_meat", 1, 2, 0.45], ["water", 1, 1, 0.4],
	["bread", 1, 1, 0.3], ["energy_drink", 1, 1, 0.25], ["cash", 80, 400, 0.5], ["scrap_electronics", 1, 2, 0.3],
	["ammo_9x19", 15, 45, 0.4], ["ammo_545x39", 20, 50, 0.35], ["ammo_12g", 6, 16, 0.35], ["ammo_762x39", 15, 40, 0.3],
]

@export var kind: String = "crate"
@export var contents: Array = []
## Semilla de la tabla al azar (0 = al azar de verdad).
@export var loot_seed: int = 0

var inventory: Inventory
var title_key: String = ""
var _looting: bool = false


func _ready() -> void:
	add_to_group("loot_containers")
	set_meta("surface", "metal" if kind in ["metal", "ammo"] else "wood")
	var sz: Vector2i = SIZES.get(kind, SIZES["crate"])
	inventory = Inventory.new(sz.x, sz.y)
	title_key = "loot." + kind
	inventory.title_key = title_key
	_fill()
	_build()


func get_interact_text() -> String:
	return tr("interact.search") % ["%s", tr(title_key)]


func interact(_player: Node) -> void:
	Foley.play(get_tree(), {"crate": "crate_open", "stash": "stash_open"}.get(kind, "box_open"), -4.0)
	if kind == "ammo":
		_restock_ammo()
	EventBus.loot_requested.emit(self)


func on_loot_opened() -> void:
	_looting = true


func on_loot_closed() -> void:
	_looting = false


func _fill() -> void:
	inventory.clear()
	if kind == "ammo":
		_restock_ammo()
		return
	if not contents.is_empty():
		for e: Array in contents:
			inventory.add_item(String(e[0]), int(e[1]))
		return
	var rng := RandomNumberGenerator.new()
	if loot_seed != 0:
		rng.seed = loot_seed
	else:
		rng.randomize()
	for e: Array in RANDOM_LOOT:
		if rng.randf() < float(e[3]):
			inventory.add_item(String(e[0]), rng.randi_range(int(e[1]), int(e[2])))


## Caja de munición: dos pilas llenas de cada calibre.
func _restock_ammo() -> void:
	for cal: String in ItemDB.AMMO:
		var id := ItemDB.ammo_id(cal)
		var it := ItemDB.get_item(id)
		inventory.set_count(id, it.stack_max * 2)


func _build() -> void:
	var size := Vector3(0.9, 0.55, 0.55)
	var col := Color(0.42, 0.31, 0.19)
	match kind:
		"metal":
			size = Vector3(0.7, 0.4, 0.45)
			col = Color(0.26, 0.3, 0.24)
		"stash":
			size = Vector3(0.7, 0.35, 0.45)
			col = Color(0.3, 0.28, 0.2)
		"ammo":
			size = Vector3(0.9, 0.5, 0.5)
			col = Color(0.3, 0.33, 0.2)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = Vector3(0, size.y * 0.5, 0)
	add_child(cs)
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.85
	m.metallic = 0.35 if kind in ["metal", "ammo"] else 0.0
	if kind == "stash":
		WeaponModelBuilder.rbox(self, "Bag", size, cs.position, m, 0.08)
		WeaponModelBuilder.rbox(self, "Flap", Vector3(size.x * 0.8, 0.06, size.z * 0.6), Vector3(0, size.y - 0.01, -0.03), m, 0.025)
		return
	WeaponModelBuilder.rbox(self, "Body", size, cs.position, m, 0.01)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = col.darkened(0.35)
	dark.roughness = 0.8
	dark.metallic = m.metallic
	# Tapa, refuerzos y manijas
	WeaponModelBuilder.rbox(self, "Lid", Vector3(size.x + 0.02, 0.05, size.z + 0.02), Vector3(0, size.y - 0.02, 0), dark, 0.008)
	if kind == "crate":
		for x: float in [-size.x * 0.35, size.x * 0.35]:
			WeaponModelBuilder.rbox(self, "Slat", Vector3(0.06, size.y, size.z + 0.015), Vector3(x, size.y * 0.5, 0), dark, 0.005)
	for s: float in [-1.0, 1.0]:
		WeaponModelBuilder.rbox(self, "Handle", Vector3(0.025, 0.03, 0.14), Vector3(s * (size.x * 0.5 + 0.015), size.y * 0.65, 0), dark, 0.006)
	if kind == "ammo":
		var stripe := StandardMaterial3D.new()
		stripe.albedo_color = Color(0.79, 0.64, 0.15)
		WeaponModelBuilder.rbox(self, "Stripe", Vector3(size.x + 0.006, 0.07, size.z + 0.006), Vector3(0, size.y * 0.45, 0), stripe, 0.004)
