class_name GroundPile
extends RefCounted
## "Contenedor" del piso: lo que hay tirado a menos de RADIUS del jugador, armado
## como una grilla para verlo con su tamaño y agarrarlo arrastrando (o tirar cosas
## ahí). Las pilas de la grilla son las mismas de los WorldItem: si una sale de la
## grilla, su objeto en el mundo desaparece; si entra una nueva, cae a los pies.

const RADIUS := 2.0
const WIDTH := 8
const MIN_ROWS := 6

var inventory: Inventory
var title_key := "loot.ground"
var _player: Player
## ItemStack -> WorldItem
var _items: Dictionary = {}
var _syncing := false


func _init(player: Player) -> void:
	_player = player
	var near := nearby(player)
	inventory = _layout(near)
	inventory.title_key = title_key
	inventory.changed.connect(_sync)


## Los ítems sueltos cerca del jugador (más cerca primero).
static func nearby(player: Player) -> Array[WorldItem]:
	var out: Array[WorldItem] = []
	if player == null or not player.is_inside_tree():
		return out
	var p := player.global_position
	for n in player.get_tree().get_nodes_in_group("world_items"):
		var w := n as WorldItem
		if w == null or w.is_queued_for_deletion() or w.stack == null or w.stack.count <= 0:
			continue
		var d := w.global_position - p
		if Vector2(d.x, d.z).length() <= RADIUS and d.y > -1.5 and d.y < 1.8:
			out.append(w)
	out.sort_custom(func(a: WorldItem, b: WorldItem) -> bool:
		return a.global_position.distance_squared_to(p) < b.global_position.distance_squared_to(p))
	return out


## Acomoda las pilas sin juntarlas (cada una sigue siendo su objeto en el mundo);
## la grilla crece hacia abajo lo que haga falta.
func _layout(near: Array[WorldItem]) -> Inventory:
	var rows := MIN_ROWS
	while true:
		var inv := Inventory.new(WIDTH, rows)
		var ok := true
		for w in near:
			var f := inv.find_free(w.stack.item.size)
			if f.is_empty():
				ok = false
				break
			inv.place(w.stack, f[0], f[1])
		if ok:
			for w in near:
				_items[w.stack] = w
			return inv
		rows += 2
	return null


## Algo entró o salió de la grilla: el mundo lo sigue.
func _sync() -> void:
	if _syncing:
		return
	_syncing = true
	for s: ItemStack in _items.keys():
		if not inventory.has_stack(s) or s.count <= 0:
			var w := _items[s] as WorldItem
			if is_instance_valid(w):
				w.queue_free()
			_items.erase(s)
	for s in inventory.stacks:
		if not _items.has(s):
			var w := _player.inventory.drop(s, true) if _player.inventory != null else null
			if w != null:
				_items[s] = w
	_syncing = false


func on_loot_closed() -> void:
	if inventory.changed.is_connected(_sync):
		inventory.changed.disconnect(_sync)
