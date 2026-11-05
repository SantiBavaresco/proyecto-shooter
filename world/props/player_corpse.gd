class_name PlayerCorpse
extends Node3D
## Cuerpo del jugador después de morir: queda tirado donde cayó con todo lo que
## llevaba (armas, chalecos, mochila con lo de adentro, bolsillos y plata). Se revisa
## con [F] como cualquier cuerpo. La brújula lo marca hasta vaciarlo.

const MODEL := "swat_remaster"

var inventory: Inventory
var title_key: String = "loot.your_body"
var _body: NpcBody


## Deja el cuerpo del jugador en su lugar con todo lo que tenía, y lo devuelve.
static func leave(player: Player) -> PlayerCorpse:
	var c := PlayerCorpse.new()
	c.name = "PlayerCorpse"
	var lvl := player.get_parent()
	lvl.add_child(c)
	c.global_position = player.global_position
	c.rotation = Vector3(0, player.yaw, 0)
	c.fill(player.inventory.strip_all())
	return c


func _ready() -> void:
	add_to_group("compass_marker")
	add_to_group("player_corpse")
	if inventory == null:
		inventory = Inventory.new(12, 16)
	inventory.title_key = title_key
	_body = NpcBody.new()
	_body.name = "Body"
	_body.scene_path = NpcLoadouts.model_path(MODEL)
	add_child(_body)
	_body.die(-global_basis.z.rotated(Vector3.UP, randf_range(-0.6, 0.6)), true)


func fill(stacks: Array[ItemStack]) -> void:
	if inventory == null:
		inventory = Inventory.new(12, 16)
	# Lo grande primero (entra mejor)
	stacks.sort_custom(func(a: ItemStack, b: ItemStack) -> bool:
		return a.item.size.x * a.item.size.y > b.item.size.x * b.item.size.y)
	for s in stacks:
		if inventory.add(s) > 0:
			# No entró: se agranda la grilla (el cuerpo no tiene límite)
			inventory.height += 6
			inventory.add(s)


func compass_label() -> String:
	return tr("compass.your_body") if inventory != null and not inventory.is_empty() else ""


func get_interact_text() -> String:
	return tr("interact.search") % ["%s", tr(title_key)]


func interact(_player: Node) -> void:
	Foley.play(get_tree(), "pickup_item", -6.0)
	EventBus.loot_requested.emit(self)


func on_loot_opened() -> void:
	pass


func on_loot_closed() -> void:
	pass
