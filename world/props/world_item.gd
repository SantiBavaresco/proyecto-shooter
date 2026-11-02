class_name WorldItem
extends RigidBody3D
## Ítem suelto en el mundo (tirado desde el inventario o puesto en el nivel).
## [F] lo agarra: va a la mochila si entra (la plata, al contador).

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
	collision_layer = 1
	collision_mask = 1
	continuous_cd = true
	set_meta("surface", "metal" if stack.item.kind in ["weapon", "ammo"] else "wood")
	var model := ItemModels.build(stack.item)
	add_child(model)
	var box := ItemModels.local_aabb(model)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(maxf(box.size.x, 0.04), maxf(box.size.y, 0.03), maxf(box.size.z, 0.04))
	cs.shape = sh
	cs.position = box.get_center()
	add_child(cs)
	mass = clampf(stack.weight(), 0.2, 6.0)
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
	return tr("interact.pick_up") % ["%s", name]


func interact(player: Node) -> void:
	var p := player as Player
	if p == null or p.inventory == null:
		return
	var left := p.inventory.receive(stack)
	if left > 0:
		stack.count = left
		EventBus.toast.emit(tr("inv.no_room"))
		return
	EventBus.toast.emit(tr("inv.picked") % ItemDB.display_name(stack.item))
	queue_free()
