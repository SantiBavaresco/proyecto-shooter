class_name ItemStack
extends RefCounted
## Una pila de ítems en un inventario (o un ítem suelto con estado propio, como un
## arma con su cargador y su desgaste).

var item: ItemData
var count: int = 1
## Celda superior izquierda en la grilla.
var pos: Vector2i = Vector2i.ZERO
## Girado 90° (ancho y alto intercambiados).
var rotated: bool = false
## Estado propio. Armas: mag, mag_id (cargador puesto), sight y muzzle (accesorios),
## condition, mode_index, zoom, malfunction. Cargadores: rounds. Equipo: condition.
var state: Dictionary = {}
## Chalecos tácticos y mochilas: sus grillas (una Inventory por cada una).
var contents: Array[Inventory] = []


static func make(id: String, n := 1, st := {}) -> ItemStack:
	var it := ItemDB.get_item(id)
	if it == null:
		push_error("Ítem desconocido: %s" % id)
		return null
	var s := ItemStack.new()
	s.item = it
	s.count = n
	s.state = st.duplicate(true)
	if it.kind == "weapon" and not s.state.has("condition"):
		var w := it.weapon()
		s.state["condition"] = 1.0
		var std := ItemDB.standard_mag(w.id) if w != null else ""
		if std != "":
			s.state["mag_id"] = std
			s.state["mag"] = ItemDB.get_item(std).capacity
		else:
			s.state["mag"] = w.mag_size if w != null else 0
		var mt := ItemDB.mount(w.id) if w != null else {}
		if mt.has("default") and not s.state.has("sight"):
			s.state["sight"] = String(mt["default"])
	elif it.kind in ["armor", "helmet"] and not s.state.has("condition"):
		s.state["condition"] = 1.0
	elif it.kind == "mag" and not s.state.has("rounds"):
		s.state["rounds"] = 0
	if it.is_container():
		s.contents = make_grids(it)
	return s


## Grillas vacías de un chaleco o mochila.
static func make_grids(it: ItemData) -> Array[Inventory]:
	var out: Array[Inventory] = []
	for g: Array in it.grids:
		out.append(Inventory.new(int(g[2]), int(g[3])))
	return out


## Cargador: cartuchos que tiene.
func rounds() -> int:
	return int(state.get("rounds", 0))


func has_contents() -> bool:
	for inv in contents:
		if not inv.is_empty():
			return true
	return false


func cells() -> Vector2i:
	return Vector2i(item.size.y, item.size.x) if rotated else item.size


func weight() -> float:
	var w := item.weight * count
	if item.kind == "mag":
		var a := ItemDB.get_item(ItemDB.ammo_id(item.caliber))
		if a != null:
			w += a.weight * rounds()
	elif item.kind == "weapon":
		for k: String in ["sight", "muzzle"]:
			var at := ItemDB.get_item(String(state.get(k, ""))) if String(state.get(k, "")) != "" else null
			if at != null:
				w += at.weight
	for inv in contents:
		w += inv.total_weight()
	return w


func price() -> int:
	var cond := float(state.get("condition", 1.0))
	return int(round(item.price * count * lerpf(0.25, 1.0, cond)))


## Se puede juntar con otra pila (mismo ítem apilable y sin estado propio).
func can_merge(other: ItemStack) -> bool:
	return other != null and other != self and other.item == item and item.stackable() \
		and state.is_empty() and other.state.is_empty()


func space_left() -> int:
	return item.stack_max - count


func copy() -> ItemStack:
	var s := ItemStack.new()
	s.item = item
	s.count = count
	s.pos = pos
	s.rotated = rotated
	s.state = state.duplicate(true)
	for inv in contents:
		var c := Inventory.new(inv.width, inv.height)
		for o in inv.stacks:
			c.stacks.append(o.copy())
		s.contents.append(c)
	return s


func to_dict() -> Dictionary:
	var d := {"id": item.id, "n": count, "x": pos.x, "y": pos.y, "r": rotated, "s": state.duplicate(true)}
	if not contents.is_empty():
		var cs: Array = []
		for inv in contents:
			cs.append(inv.to_dict())
		d["c"] = cs
	return d


static func from_dict(d: Dictionary) -> ItemStack:
	var s := make(String(d["id"]), int(d.get("n", 1)), d.get("s", {}))
	if s == null:
		return null
	s.pos = Vector2i(int(d.get("x", 0)), int(d.get("y", 0)))
	s.rotated = bool(d.get("r", false))
	var cs: Array = d.get("c", [])
	for i in mini(cs.size(), s.contents.size()):
		s.contents[i].load_dict(cs[i])
	return s
