class_name PlayerInventory
extends Node
## Inventario del jugador (estilo STALKER 2): mochila en grilla con peso, ranuras
## de equipo (2 armas largas, pistola, casco, chaleco, mochila), 4 ranuras rápidas
## de consumibles (5–8) y plata en USD.
##
##  - La munición se cuenta por calibre en la mochila: las armas del mismo calibre
##    la comparten y la recarga la saca de ahí.
##  - Las armas equipadas son ítems con estado propio (cargador, desgaste, modo):
##    al desequiparlas vuelven a la mochila tal como estaban.
##  - Peso: hasta "carry_limit()" no pasa nada; de ahí hasta el máximo se camina más
##    lento y correr cansa más; pasado el máximo no se puede correr ni saltar.
##  - Usar un consumible lleva su tiempo (el arma baja mientras tanto).

## 8 columnas (las armas largas entran acostadas) y 15 filas, con desplazamiento.
const GRID := Vector2i(8, 15)
## kg sin penalidad (sin mochila ni chaleco) y margen hasta el máximo.
const BASE_CARRY := 40.0
const OVER_MARGIN := 20.0
const EQUIP_SLOTS := ["weapon1", "weapon2", "pistol", "melee", "helmet", "armor", "backpack"]
## Ranura de equipo → slot del WeaponController.
const WEAPON_SLOT := {"weapon1": 1, "weapon2": 2, "pistol": 3}
const START_MONEY := 1500
## Equipo inicial: armas (con munición = su start_reserve) y consumibles.
const START_WEAPONS := {"weapon1": "ak74u", "weapon2": "shotgun", "pistol": "pistol"}
const START_ITEMS := [["bandage", 3], ["medkit", 2], ["energy_drink", 1], ["water", 1], ["canned_meat", 1]]
const START_QUICK := ["bandage", "medkit", "energy_drink", "water"]

signal changed

var player: Player
var bag := Inventory.new(GRID.x, GRID.y)
var equipment: Dictionary = {}
var quick: Array[String] = ["", "", "", ""]
var money: int = 0
## Consumible en uso (null = nada) y segundos que faltan.
var using: ItemStack = null
var using_item: ItemData = null
var use_left: float = 0.0
var use_total: float = 0.0


func setup(p: Player) -> void:
	player = p
	for s: String in EQUIP_SLOTS:
		equipment[s] = null
	bag.title_key = "inv.backpack"
	bag.changed.connect(_on_changed)


func _on_changed() -> void:
	changed.emit()
	EventBus.inventory_changed.emit()


## Equipo y mochila del comienzo.
func give_start_kit() -> void:
	for slot: String in START_WEAPONS:
		var d := load("res://data/weapons/%s.tres" % START_WEAPONS[slot]) as WeaponData
		player.weapons.equip_weapon(d, WEAPON_SLOT[slot], {}, true, null, false)
	equipment["melee"] = ItemStack.make("knife")
	for e: Array in START_ITEMS:
		bag.add_item(e[0], e[1])
	for i in START_QUICK.size():
		quick[i] = START_QUICK[i]
	money = START_MONEY
	bag.sort()
	_on_changed()


# --- Peso ------------------------------------------------------------------------

func total_weight() -> float:
	var t := bag.total_weight()
	for s: String in equipment:
		var st := equipment[s] as ItemStack
		if st != null:
			t += st.weight()
	return t


func carry_limit() -> float:
	var lim := BASE_CARRY
	for s: String in ["backpack", "armor"]:
		var st := equipment.get(s) as ItemStack
		if st != null:
			lim += st.item.carry_bonus
	return lim


func carry_max() -> float:
	return carry_limit() + OVER_MARGIN


## 0 = sin sobrepeso, 1 = en el máximo, > 1 = pasado.
func overload() -> float:
	var w := total_weight()
	var lim := carry_limit()
	if w <= lim:
		return 0.0
	return (w - lim) / OVER_MARGIN


func speed_mult() -> float:
	var o := overload()
	if o <= 0.0:
		return 1.0
	if o > 1.0:
		return 0.45
	return lerpf(1.0, 0.7, o)


func stamina_cost_mult() -> float:
	return 1.0 + clampf(overload(), 0.0, 1.0)


func can_sprint() -> bool:
	return overload() <= 1.0


# --- Munición (por calibre, en la mochila) ---------------------------------------

func ammo_count(caliber: String) -> int:
	var id := ItemDB.ammo_id(caliber)
	return bag.count_of(id) if id != "" else 0


func take_ammo(caliber: String, n: int) -> int:
	var id := ItemDB.ammo_id(caliber)
	return bag.take(id, n) if id != "" else 0


## Deja exactamente n cartuchos de ese calibre (lo que no entre se pierde).
func set_ammo(caliber: String, n: int) -> void:
	var id := ItemDB.ammo_id(caliber)
	if id != "":
		bag.set_count(id, maxi(0, n))


## Asegura al menos n cartuchos (mesas del laboratorio).
func ensure_ammo(caliber: String, n: int) -> void:
	if ammo_count(caliber) < n:
		set_ammo(caliber, n)


# --- Equipo ----------------------------------------------------------------------

## Ranura libre (o la primera) donde iría esta pila.
func slot_for(s: ItemStack) -> String:
	var opts := s.item.equip_slots()
	if opts.is_empty():
		return ""
	for o in opts:
		if equipment.get(o) == null:
			return o
	# Arma larga: la que tenga en la mano, si es larga
	if s.item.kind == "weapon" and opts.size() > 1 and player != null and player.weapons.current_slot == 2:
		return "weapon2"
	return opts[0]


func can_equip(s: ItemStack, slot: String) -> bool:
	return s != null and s.item.equip_slots().has(slot)


## Lo llama el WeaponController al poner un arma en un slot (la pila es el ítem
## equipado; si no viene, se crea).
func on_weapon_installed(slot_index: int, data: WeaponData, stack: ItemStack) -> ItemStack:
	var name := _slot_name(slot_index)
	if name == "":
		return stack
	if stack == null:
		stack = ItemStack.make(ItemDB.weapon_item_id(data.id))
	equipment[name] = stack
	_on_changed()
	return stack


## Equipa una pila que está en "from" (la mochila o un contenedor). Lo que había en
## la ranura vuelve a "from" (o a la mochila). Devuelve true si se pudo.
func equip(s: ItemStack, slot: String, from: Inventory = null) -> bool:
	if not can_equip(s, slot):
		return false
	if from == null:
		from = bag
	var old := equipment.get(slot) as ItemStack
	if old != null:
		# Lo que se saca va adonde estaba lo nuevo (o a cualquier lugar libre)
		_sync_weapon(slot)
		var back := from if from.has_stack(s) else bag
		from.remove(s)
		var spot_ok := back.place(old, s.pos, s.rotated)
		if not spot_ok and back.add(old) > 0:
			# No entra: se vuelve a poner lo nuevo y no se cambia nada
			back.remove(old)
			from.add(s)
			return false
		_uninstall(slot)
	else:
		from.remove(s)
	equipment[slot] = s
	if WEAPON_SLOT.has(slot):
		player.weapons.equip_weapon(s.item.weapon(), WEAPON_SLOT[slot], s.state, false, s, false)
	_on_changed()
	return true


## Saca lo equipado en una ranura a "to" (en "at" si se da y entra). Devuelve la pila
## o null si no hay lugar.
func unequip(slot: String, to: Inventory = null, at := Vector2i(-1, -1), rotated := false) -> ItemStack:
	var s := equipment.get(slot) as ItemStack
	if s == null:
		return null
	if to == null:
		to = bag
	_sync_weapon(slot)
	var ok := false
	if at.x >= 0:
		ok = to.place(s, at, rotated)
	if not ok:
		ok = to.add(s) == 0
	if not ok:
		return null
	_uninstall(slot)
	equipment[slot] = null
	_on_changed()
	return s


## Saca lo equipado sin ponerlo en ningún lado (tirarlo).
func take_equipped(slot: String) -> ItemStack:
	var s := equipment.get(slot) as ItemStack
	if s == null:
		return null
	_sync_weapon(slot)
	_uninstall(slot)
	equipment[slot] = null
	_on_changed()
	return s


## Pasa el estado del arma en uso (cargador, desgaste...) a su ítem.
func sync_weapons() -> void:
	for slot: String in WEAPON_SLOT:
		_sync_weapon(slot)


func _sync_weapon(slot: String) -> void:
	if not WEAPON_SLOT.has(slot) or equipment.get(slot) == null or player == null:
		return
	var st := player.weapons.weapon_state(WEAPON_SLOT[slot])
	if not st.is_empty():
		(equipment[slot] as ItemStack).state = st


func _uninstall(slot: String) -> void:
	if WEAPON_SLOT.has(slot) and player != null:
		player.weapons.remove_weapon(WEAPON_SLOT[slot])


func _slot_name(idx: int) -> String:
	for k: String in WEAPON_SLOT:
		if WEAPON_SLOT[k] == idx:
			return k
	return ""


## Descarga el arma equipada o la de la pila: los cartuchos vuelven a la mochila.
func unload(s: ItemStack) -> void:
	if s == null or s.item.kind != "weapon":
		return
	var slot := ""
	for k: String in WEAPON_SLOT:
		if equipment.get(k) == s:
			slot = k
	var n := 0
	if slot != "":
		n = player.weapons.unload(WEAPON_SLOT[slot])
	else:
		n = int(s.state.get("mag", 0))
		s.state["mag"] = 0
	if n > 0:
		bag.add_item(ItemDB.ammo_id(s.item.caliber), n)
	_on_changed()


# --- Consumibles -----------------------------------------------------------------

func is_using() -> bool:
	return using_item != null


## Empieza a usar un consumible de la mochila. Devuelve false si no se puede ahora.
func use(s: ItemStack) -> bool:
	if s == null or not s.item.is_consumable() or is_using() or player == null:
		return false
	if not player.weapons.can_lower():
		return false
	using = s
	using_item = s.item
	use_total = maxf(s.item.use_time, 0.1)
	use_left = use_total
	player.weapons.lowered = true
	EventBus.item_use_started.emit(s.item.id, use_total)
	return true


## Ranura rápida (0–3): usa el primer consumible de ese tipo en la mochila.
func use_quick(i: int) -> bool:
	if i < 0 or i >= quick.size() or quick[i] == "":
		return false
	var s := first_stack(quick[i])
	if s == null:
		EventBus.toast.emit(tr("inv.quick_empty") % ItemDB.display_name(ItemDB.get_item(quick[i])))
		return false
	return use(s)


func set_quick(i: int, id: String) -> void:
	if i < 0 or i >= quick.size():
		return
	var it := ItemDB.get_item(id) if id != "" else null
	if id != "" and (it == null or not it.is_consumable()):
		return
	# La misma cosa no va en dos ranuras
	for k in quick.size():
		if quick[k] == id:
			quick[k] = ""
	quick[i] = id
	_on_changed()


func first_stack(id: String) -> ItemStack:
	var best: ItemStack = null
	for s in bag.stacks:
		if s.item.id == id and (best == null or s.count < best.count):
			best = s
	return best


func cancel_use() -> void:
	if not is_using():
		return
	using = null
	using_item = null
	player.weapons.lowered = false
	EventBus.item_use_finished.emit("", false)


func tick(delta: float) -> void:
	if not is_using():
		return
	use_left -= delta
	if use_left > 0.0:
		return
	var it := using_item
	var s := using if using != null and bag.has_stack(using) else first_stack(it.id)
	using = null
	using_item = null
	player.weapons.lowered = false
	if s == null:
		EventBus.item_use_finished.emit(it.id, false)
		return
	s.count -= 1
	if s.count <= 0:
		bag.remove(s)
	else:
		bag.changed.emit()
	player.apply_item_effects(it.effects)
	EventBus.item_use_finished.emit(it.id, true)


# --- Plata y suelo ---------------------------------------------------------------

## Agrega una pila venida de afuera (suelo, saqueo). La plata va al contador.
## Devuelve lo que no entró.
func receive(s: ItemStack) -> int:
	if s.item.kind == "money":
		money += s.count
		_on_changed()
		return 0
	return bag.add(s)


# --- Movimientos entre inventarios (los usa la pantalla de inventario) -----------

## Pasa una pila de un inventario a otro (a cualquier lugar libre, juntando con las
## iguales). La plata que entra a la mochila va al contador. Devuelve true si pasó algo.
func transfer(s: ItemStack, from: Inventory, to: Inventory) -> bool:
	if s == null or not from.has_stack(s) or from == to:
		return false
	var pos := s.pos
	var rot := s.rotated
	var before := s.count
	from.remove(s)
	var left := receive(s) if to == bag else to.add(s)
	if left > 0:
		# Lo que no entró vuelve a su lugar
		s.count = left
		if not from.place(s, pos, rot):
			from.add(s)
	return left < before


## Mueve una pila a una celda de otro (o del mismo) inventario. Si cae sobre una pila
## igual, se juntan. Devuelve true si se movió algo.
func move_to(s: ItemStack, from: Inventory, to: Inventory, at: Vector2i, rotated: bool) -> bool:
	if s == null or not from.has_stack(s):
		return false
	var cells := Vector2i(s.item.size.y, s.item.size.x) if rotated else s.item.size
	var target := to.stack_at(at)
	if target != null and target != s and s.can_merge(target):
		var left := to.merge(s, target) if from == to else _merge_across(s, from, target, to)
		return left < s.count or not from.has_stack(s)
	if from == to:
		return to.place(s, at, rotated)
	if not to.fits(cells, at):
		return false
	from.remove(s)
	if to == bag and s.item.kind == "money":
		receive(s)
		return true
	return to.place(s, at, rotated)


func _merge_across(s: ItemStack, from: Inventory, dst: ItemStack, to: Inventory) -> int:
	var mv := mini(dst.space_left(), s.count)
	dst.count += mv
	s.count -= mv
	if s.count <= 0:
		from.remove(s)
	else:
		from.changed.emit()
	to.changed.emit()
	return s.count


## Pasa todo un contenedor a la mochila (lo que entre).
func take_all(from: Inventory) -> int:
	var moved := 0
	for st in from.stacks.duplicate():
		if transfer(st, from, bag):
			moved += 1
	return moved


## Intercambia las dos armas largas (o mueve una a la ranura vacía).
func swap_weapon_slots() -> void:
	var a := take_equipped("weapon1")
	var b := take_equipped("weapon2")
	if b != null:
		place_equipped(b, "weapon1")
	if a != null:
		place_equipped(a, "weapon2")


## Pone una pila directamente en una ranura vacía (sin sacarla de ningún inventario).
func place_equipped(s: ItemStack, slot: String) -> bool:
	if not can_equip(s, slot) or equipment.get(slot) != null:
		return false
	equipment[slot] = s
	if WEAPON_SLOT.has(slot):
		player.weapons.equip_weapon(s.item.weapon(), WEAPON_SLOT[slot], s.state, false, s, false)
	_on_changed()
	return true


## Tira una pila al suelo delante del jugador (ya sacada del inventario).
func drop(s: ItemStack) -> WorldItem:
	if s == null or player == null or not player.is_inside_tree():
		return null
	var cam := player.camera
	var fwd := -cam.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var pos := player.global_position + fwd * 0.7 + Vector3(0, 1.1, 0)
	var parent := player.get_tree().current_scene if player.get_tree().current_scene != null else player.get_parent()
	return WorldItem.spawn(parent, s, pos, fwd * 1.6 + Vector3(0, 1.0, 0))


# --- Guardado --------------------------------------------------------------------

func to_dict() -> Dictionary:
	sync_weapons()
	var eq := {}
	for k: String in equipment:
		var s := equipment[k] as ItemStack
		eq[k] = s.to_dict() if s != null else null
	return {"bag": bag.to_dict(), "equipment": eq, "quick": quick.duplicate(), "money": money}
