class_name WorldItem
extends RigidBody3D

## Capa 13: objetos sueltos en el piso.
const LAYER := 13
## Ítem suelto en el mundo (tirado desde el inventario o puesto en el nivel).
## [F] lo agarra: va a la mochila si entra (la plata, al contador).

## Escala de los ítems sueltos (no armas) en el mundo.
const GROUND_SCALE := 2.0

var stack: ItemStack
var _ready_done: bool = false


## Crea un ítem suelto en "parent" (tirado: con un empujón).
static func spawn(parent: Node, s: ItemStack, pos: Vector3, impulse := Vector3.ZERO) -> WorldItem:
	var w := WorldItem.new()
	w.stack = s
	w.name = "Item_%s" % s.item.id
	parent.add_child(w)
	w.global_position = pos
	if impulse != Vector3.ZERO:
		w.apply_central_impulse(impulse * w.mass)
	return w


## Para ponerlo desde el nivel: id y cantidad.
static func make(id: String, n := 1) -> WorldItem:
	var w := WorldItem.new()
	w.stack = ItemStack.make(id, n)
	w.name = "Item_%s" % id
	return w


func _ready() -> void:
	add_to_group("world_items")
	# Capa propia: se apoya en el piso y en otros objetos, pero no frena al jugador
	# ni a los enemigos (pasan por encima) y no tapa la vista de la IA
	collision_layer = 1 << (LAYER - 1)
	collision_mask = 1 | (1 << (LAYER - 1))
	continuous_cd = true
	set_meta("surface", "metal" if stack.item.kind in ["weapon", "ammo"] else "wood")
	var model := ItemModels.build(stack.item, stack.state)
	add_child(model)
	var box := ItemModels.local_aabb(model)
	# En el piso se ven al doble (a escala real son muy chicos para encontrarlos y
	# agarrarlos); las armas quedan a escala real
	if stack.item.kind != "weapon":
		model.scale = Vector3.ONE * GROUND_SCALE
		box = AABB(box.position * GROUND_SCALE, box.size * GROUND_SCALE)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(maxf(box.size.x, 0.04), maxf(box.size.y, 0.03), maxf(box.size.z, 0.04))
	cs.shape = sh
	cs.position = box.get_center()
	add_child(cs)
	mass = clampf(stack.weight() * 2.0, 0.3, 8.0)
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.9
	physics_material_override.bounce = 0.05
	angular_damp = 2.0
	linear_damp = 0.2
	_ready_done = true


func get_interact_text() -> String:
	var name := ItemDB.display_name(stack.item)
	if stack.count > 1:
		name += " ×%d" % stack.count
	if _searchable():
		var p := _local_player()
		if p != null and not can_pick(p.inventory, stack):
			# No entra (o ya tenés una puesta y esta tiene cosas): solo revisarla
			return tr("interact.search") % ["%s", name]
		return (tr("interact.pick_up") % ["%s", name]) + "    " + tr("interact.hold_search")
	return tr("interact.pick_up") % ["%s", name]


## Mochila o chaleco táctico: se puede revisar sin agarrarlo.
func _searchable() -> bool:
	return stack.item.is_container() and not stack.contents.is_empty()


func _local_player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


## ¿Se puede agarrar? Se equipa si su ranura está libre; si no, tiene que estar vacía
## (una mochila con cosas no entra en otra) y caber en algún lado.
static func can_pick(pinv: PlayerInventory, s: ItemStack) -> bool:
	if pinv == null:
		return false
	if s.item.kind == "money":
		return true
	if s.item.is_container():
		var slot := pinv.slot_for(s)
		if slot != "" and pinv.equipment.get(slot) == null:
			return true
		if s.has_contents():
			return false
	for inv in pinv.storages():
		if pinv.accepts(inv, s) and (inv.can_add(s) or not inv.find_free(s.item.size).is_empty()):
			return true
	return false


func interact(player: Node) -> void:
	var p := player as Player
	if p == null or p.inventory == null:
		return
	if _searchable() and not can_pick(p.inventory, stack):
		interact_alt(player)
		return
	if stack.item.is_container():
		var slot := p.inventory.slot_for(stack)
		if slot != "" and p.inventory.equipment.get(slot) == null:
			# Mochila o chaleco con la ranura libre: te lo ponés con lo que tenga adentro
			p.inventory.place_equipped(stack, slot)
			_picked(stack)
			return
	var left := p.inventory.receive(stack)
	if left > 0:
		stack.count = left
		EventBus.toast.emit(tr("inv.no_room"))
		return
	_picked(stack)


## Mantener [F]: revisarla sin agarrarla (mochilas y chalecos).
func interact_alt(player: Node) -> void:
	if not _searchable():
		interact(player)
		return
	Foley.play(get_tree(), "pickup_item", -10.0)
	EventBus.bag_search_requested.emit(stack)


func _picked(s: ItemStack) -> void:
	EventBus.toast.emit(tr("inv.picked") % ItemDB.display_name(s.item))
	Foley.play(get_tree(), "pickup_weapon" if s.item.kind == "weapon" else "pickup_item", -4.0)
	queue_free()
