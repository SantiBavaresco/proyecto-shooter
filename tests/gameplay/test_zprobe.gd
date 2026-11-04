extends TestCase
const LEVEL := preload("res://world/test_greybox/test_greybox.tscn")
func test_probe() -> void:
	var level: Node3D = LEVEL.instantiate()
	add_child(level)
	await physics_frames(10)
	var p: Player = level.get_node("Player")
	var pinv := p.inventory
	print("eq: ", pinv.equipment.keys().map(func(k): return [k, (pinv.equipment[k] as ItemStack).item.id if pinv.equipment[k] != null else null]))
	for inv in pinv.storages():
		print("inv ", inv.width, "x", inv.height, " ", inv.stacks.map(func(s: ItemStack): return "%s x%d" % [s.item.id, s.count]))
	print("bag ", pinv.bag.width, "x", pinv.bag.height)
	level.queue_free()
