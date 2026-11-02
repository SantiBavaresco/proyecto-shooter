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
## Estado propio. Armas: mag, condition, mode_index, zoom, malfunction.
## Equipo: condition.
var state: Dictionary = {}


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
		s.state["mag"] = w.mag_size if w != null else 0
	elif it.kind in ["armor", "helmet"] and not s.state.has("condition"):
		s.state["condition"] = 1.0
	return s


func cells() -> Vector2i:
	return Vector2i(item.size.y, item.size.x) if rotated else item.size


func weight() -> float:
	return item.weight * count


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
	return s


func to_dict() -> Dictionary:
	return {"id": item.id, "n": count, "x": pos.x, "y": pos.y, "r": rotated, "s": state.duplicate(true)}


static func from_dict(d: Dictionary) -> ItemStack:
	var s := make(String(d["id"]), int(d.get("n", 1)), d.get("s", {}))
	if s == null:
		return null
	s.pos = Vector2i(int(d.get("x", 0)), int(d.get("y", 0)))
	s.rotated = bool(d.get("r", false))
	return s
