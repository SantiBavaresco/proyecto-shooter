class_name PlayerInventory
extends Node
## Inventario del jugador: el lugar lo da el equipo (estilo Tarkov), con peso:
##  - bolsillos (4 de 1×1, siempre);
##  - chaleco táctico: varias grillas chicas (porta-cargadores, bolsillos);
##  - mochila: una grilla según el modelo (sin mochila, no hay).
## Ranuras de equipo (2 armas largas, pistola, arma blanca, casco, chaleco antibalas,
## chaleco táctico, mochila), 4 ranuras rápidas de consumibles (5–8) y plata en USD.
##
##  - Armas con cargador: recargan con el cargador más lleno de su familia (del chaleco
##    o los bolsillos; de la mochila tarda más). La munición suelta llena cargadores.
##  - Armas sin cargador (escopetas, revólver, cerrojos): usan la munición suelta de su
##    calibre, de cualquier contenedor.
##  - Las armas equipadas son ítems con estado propio (cargador, desgaste, modo):
##    al desequiparlas vuelven a la mochila tal como estaban.
##  - Peso: hasta "carry_limit()" no pasa nada; de ahí hasta el máximo se camina más
##    lento y correr cansa más; pasado el máximo no se puede correr ni saltar.
##  - Usar un consumible lleva su tiempo (el arma baja mientras tanto).

## Bolsillos: [x, y, ancho, alto] como las grillas de los chalecos.
const POCKETS := [[0, 0, 1, 1], [1, 0, 1, 1], [2, 0, 1, 1], [3, 0, 1, 1]]
## kg sin penalidad (sin mochila ni chaleco) y margen hasta el máximo.
const BASE_CARRY := 40.0
const OVER_MARGIN := 20.0
const EQUIP_SLOTS := ["weapon1", "weapon2", "pistol", "melee", "helmet", "armor", "rig", "backpack"]
## Ranura de equipo → slot del WeaponController.
const WEAPON_SLOT := {"weapon1": 1, "weapon2": 2, "pistol": 3}
const START_MONEY := 1500
## Equipo inicial: armas (con munición = su start_reserve) y consumibles.
const START_WEAPONS := {"weapon1": "ak74u", "weapon2": "shotgun", "pistol": "pistol"}
const START_ITEMS := [["bandage", 3], ["medkit", 2], ["energy_drink", 1], ["water", 1], ["canned_meat", 1],
	["ammo_545x39", 60]]
const START_GEAR := {"rig": "rig_medium", "backpack": "backpack_medium"}
const START_QUICK := ["bandage", "medkit", "energy_drink", "water"]

signal changed

var player: Player
## Grilla de la mochila puesta (sin mochila: una vacía de 0×0, donde no entra nada).
var bag: Inventory:
	get:
		var b := equipment.get("backpack") as ItemStack
		return b.contents[0] if b != null and not b.contents.is_empty() else _no_bag
var pockets: Array[Inventory] = []
var equipment: Dictionary = {}
var _no_bag := Inventory.new(0, 0)
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
	pockets.clear()
	for g: Array in POCKETS:
		var inv := Inventory.new(int(g[2]), int(g[3]))
		inv.changed.connect(_on_changed)
		pockets.append(inv)


## Todos los lugares donde guarda cosas el jugador: bolsillos, chaleco y mochila.
func storages() -> Array[Inventory]:
	var out: Array[Inventory] = []
	out.append_array(pockets)
	out.append_array(rig_grids())
	var b := equipment.get("backpack") as ItemStack
	if b != null:
		out.append_array(b.contents)
	return out


## Lo de acceso rápido (bolsillos y chaleco): de ahí sale la recarga normal.
func quick_storages() -> Array[Inventory]:
	var out: Array[Inventory] = []
	out.append_array(pockets)
	out.append_array(rig_grids())
	return out


func rig_grids() -> Array[Inventory]:
	var r := equipment.get("rig") as ItemStack
	return r.contents if r != null else ([] as Array[Inventory])


func is_storage(inv: Inventory) -> bool:
	return inv != null and storages().has(inv)


## Inventario del jugador que tiene esta pila (null si no está en ninguno).
func storage_of(s: ItemStack) -> Inventory:
	for inv in storages():
		if inv.has_stack(s):
			return inv
	return null


## Pone algo en una ranura de equipo y escucha los cambios de sus grillas.
func _set_equipped(slot: String, s: ItemStack) -> void:
	var old := equipment.get(slot) as ItemStack
	if old != null:
		for inv in old.contents:
			if inv.changed.is_connected(_on_changed):
				inv.changed.disconnect(_on_changed)
	equipment[slot] = s
	if s != null:
		for inv in s.contents:
			if not inv.changed.is_connected(_on_changed):
				inv.changed.connect(_on_changed)


func _on_changed() -> void:
	changed.emit()
	EventBus.inventory_changed.emit()


## Equipo y mochila del comienzo.
func give_start_kit() -> void:
	for slot: String in START_GEAR:
		_set_equipped(slot, ItemStack.make(START_GEAR[slot]))
	for slot: String in START_WEAPONS:
		var d := load("res://data/weapons/%s.tres" % START_WEAPONS[slot]) as WeaponData
		player.weapons.equip_weapon(d, WEAPON_SLOT[slot], {}, true, null, false)
	_set_equipped("melee", ItemStack.make("knife"))
	for e: Array in START_ITEMS:
		receive(ItemStack.make(e[0], e[1]))
	for i in START_QUICK.size():
		quick[i] = START_QUICK[i]
	money = START_MONEY
	bag.sort()
	_on_changed()


# --- Peso ------------------------------------------------------------------------

func total_weight() -> float:
	var t := 0.0
	for p in pockets:
		t += p.total_weight()
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


# --- Munición suelta (por calibre, en cualquier contenedor) -----------------------

func count_of(id: String) -> int:
	var n := 0
	for inv in storages():
		n += inv.count_of(id)
	return n


## Saca n unidades de un ítem de los contenedores (mochila primero). Devuelve cuántas.
func take(id: String, n: int) -> int:
	var got := 0
	var order := storages()
	order.reverse()
	for inv in order:
		if got >= n:
			break
		got += inv.take(id, n - got)
	return got


func ammo_count(caliber: String) -> int:
	var id := ItemDB.ammo_id(caliber)
	return count_of(id) if id != "" else 0


func take_ammo(caliber: String, n: int) -> int:
	var id := ItemDB.ammo_id(caliber)
	return take(id, n) if id != "" else 0


## Deja exactamente n cartuchos sueltos de ese calibre (lo que no entre se pierde).
func set_ammo(caliber: String, n: int) -> void:
	var id := ItemDB.ammo_id(caliber)
	if id == "":
		return
	var have := ammo_count(caliber)
	if n < have:
		take(id, have - n)
	elif n > have:
		receive(ItemStack.make(id, n - have))


## Asegura al menos n cartuchos sueltos (mesas del laboratorio).
func ensure_ammo(caliber: String, n: int) -> void:
	if ammo_count(caliber) < n:
		set_ammo(caliber, n)


# --- Cargadores --------------------------------------------------------------------

## Cargadores de una familia en los contenedores: [[pila, inventario], ...].
func mags_of(family: String, quick_only := false) -> Array:
	var out: Array = []
	for inv in (quick_storages() if quick_only else storages()):
		for st in inv.stacks:
			if st.item.kind == "mag" and st.item.mag_family == family:
				out.append([st, inv])
	return out


## Cartuchos en los cargadores (con balas) de una familia.
func mag_rounds(family: String) -> int:
	var n := 0
	for e: Array in mags_of(family):
		n += (e[0] as ItemStack).rounds()
	return n


## El cargador más lleno para recargar: primero chaleco y bolsillos; si no hay, la
## mochila. Devuelve [pila, inventario, de_la_mochila] o [].
func best_mag(family: String) -> Array:
	for quick_only: bool in [true, false]:
		var best: Array = []
		for e: Array in mags_of(family, quick_only):
			var st := e[0] as ItemStack
			if st.rounds() > 0 and (best.is_empty() or st.rounds() > (best[0] as ItemStack).rounds()):
				best = e
		if not best.is_empty():
			return [best[0], best[1], not quick_storages().has(best[1])]
	return []


## Deja exactamente n cartuchos en los cargadores de una familia: vacía los menos
## llenos o agrega cargadores estándar llenos (pruebas y mesas del laboratorio).
func set_mag_rounds(family: String, n: int) -> void:
	var have := mag_rounds(family)
	if n < have:
		var list := mags_of(family)
		list.sort_custom(func(a: Array, b: Array) -> bool: return (a[0] as ItemStack).rounds() < (b[0] as ItemStack).rounds())
		var drop := have - n
		for e: Array in list:
			var st := e[0] as ItemStack
			var t := mini(st.rounds(), drop)
			st.state["rounds"] = st.rounds() - t
			drop -= t
			if drop <= 0:
				break
		_on_changed()
	elif n > have:
		# Primero se completan los que ya hay, después cargadores nuevos
		var left := n - have
		for e: Array in mags_of(family):
			var st := e[0] as ItemStack
			var t := mini(st.item.capacity - st.rounds(), left)
			st.state["rounds"] = st.rounds() + t
			left -= t
		var std := String(ItemDB.family_mags(family)[0]) if not ItemDB.family_mags(family).is_empty() else ""
		while left > 0 and std != "":
			var m := ItemStack.make(std)
			var t2 := mini(m.item.capacity, left)
			m.state["rounds"] = t2
			if receive(m) > 0:
				break
			left -= t2
		_on_changed()


## Llena un cargador con munición suelta. Devuelve cuántos cartuchos entraron.
func fill_mag(m: ItemStack) -> int:
	if m == null or m.item.kind != "mag":
		return 0
	var need := m.item.capacity - m.rounds()
	var got := take_ammo(m.item.caliber, need) if need > 0 else 0
	if got > 0:
		m.state["rounds"] = m.rounds() + got
		_on_changed()
	return got


## Llena todos los cargadores (los del chaleco y bolsillos primero).
func fill_all_mags() -> int:
	var total := 0
	for inv in quick_storages() + storages():
		for st in inv.stacks:
			if st.item.kind == "mag":
				total += fill_mag(st)
	return total


## Vacía un cargador: los cartuchos van sueltos a los contenedores.
func empty_mag(m: ItemStack) -> void:
	if m == null or m.item.kind != "mag" or m.rounds() <= 0:
		return
	var n := m.rounds()
	m.state["rounds"] = 0
	var left := receive(ItemStack.make(ItemDB.ammo_id(m.item.caliber), n))
	m.state["rounds"] = left  # lo que no entró queda en el cargador
	_on_changed()


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
	_set_equipped(name, stack)
	_on_changed()
	return stack


## Equipa una pila que está en "from" (un contenedor del jugador o de afuera). Lo que
## había en la ranura vuelve a "from" (o a donde entre). Devuelve true si se pudo.
func equip(s: ItemStack, slot: String, from: Inventory = null) -> bool:
	if not can_equip(s, slot):
		return false
	if from == null:
		from = storage_of(s)
	if from == null:
		return false
	var old := equipment.get(slot) as ItemStack
	if old != null:
		# Lo que se saca va adonde estaba lo nuevo (o a cualquier lugar libre). Un chaleco
		# o mochila con cosas no se guarda adentro de otro: se cambia el contenido de lugar
		_sync_weapon(slot)
		var at := s.pos
		var rot := s.rotated
		from.remove(s)
		_set_equipped(slot, null)
		if old.has_contents():
			# Lo de adentro pasa al nuevo (lo que no entre queda en el viejo)
			_move_contents(old, s)
		# Si lo nuevo estaba adentro de lo viejo (una mochila sacada de la misma mochila),
		# lo viejo no puede volver ahí: va a otro lado o al piso
		var inside_old := old.contents.has(from)
		var ok := not inside_old and (not old.has_contents() or not is_storage(from)) and \
			(from.place(old, at, rot) or from.add(old) == 0)
		if not ok and not old.has_contents():
			ok = receive(old) == 0
		if not ok:
			if old.has_contents() or not is_storage(from) or inside_old:
				drop(old)
			else:
				# No entra: se deja todo como estaba
				_set_equipped(slot, old)
				from.place(s, at, rot)
				return false
		_uninstall(slot)
	else:
		from.remove(s)
	_set_equipped(slot, s)
	if WEAPON_SLOT.has(slot):
		player.weapons.equip_weapon(s.item.weapon(), WEAPON_SLOT[slot], s.state, false, s, false)
	_foley("equip")
	_on_changed()
	return true


## Pasa las cosas de un chaleco o mochila a otro (lo que entre).
func _move_contents(src: ItemStack, dst: ItemStack) -> void:
	for inv in src.contents:
		for st in inv.stacks.duplicate():
			for d in dst.contents:
				if d.can_add(st):
					inv.remove(st)
					d.add(st)
					break


func _foley(sound: String) -> void:
	if player != null and player.is_inside_tree():
		Foley.play(player.get_tree(), sound, -6.0)


## Saca lo equipado en una ranura a "to" (en "at" si se da y entra). Devuelve la pila
## o null si no hay lugar.
func unequip(slot: String, to: Inventory = null, at := Vector2i(-1, -1), rotated := false) -> ItemStack:
	var s := equipment.get(slot) as ItemStack
	if s == null:
		return null
	_sync_weapon(slot)
	if s.item.is_container() and s.has_contents() and (to == null or is_storage(to)):
		EventBus.toast.emit(tr("inv.full_container"))
		return null
	# Una mochila no se guarda adentro de sí misma
	if to != null and s.contents.has(to):
		return null
	_set_equipped(slot, null)
	var ok := false
	if to != null and at.x >= 0:
		ok = to.place(s, at, rotated)
	if not ok:
		ok = (to.add(s) == 0) if to != null else (receive(s) == 0)
	if not ok:
		_set_equipped(slot, s)
		return null
	_uninstall(slot)
	_foley("equip")
	_on_changed()
	return s


## Desocupa una ranura: lo equipado va a los contenedores o, si no hay lugar, al piso.
func stow_or_drop(slot: String) -> void:
	if equipment.get(slot) == null:
		return
	if unequip(slot) == null:
		var t := take_equipped(slot)
		if t != null:
			drop(t, true)
			EventBus.toast.emit(tr("inv.dropped_no_room") % ItemDB.display_name(t.item))


## Saca lo equipado sin ponerlo en ningún lado (tirarlo).
func take_equipped(slot: String) -> ItemStack:
	var s := equipment.get(slot) as ItemStack
	if s == null:
		return null
	_sync_weapon(slot)
	_uninstall(slot)
	_set_equipped(slot, null)
	_on_changed()
	return s


## Saca todo lo que lleva (equipo, bolsillos y plata) para dejarlo en su cuerpo al
## morir. Devuelve las pilas (las mochilas y chalecos se llevan su contenido).
func strip_all() -> Array[ItemStack]:
	cancel_use()
	var out: Array[ItemStack] = []
	for slot: String in EQUIP_SLOTS:
		var st := take_equipped(slot)
		if st != null:
			out.append(st)
	for p in pockets:
		for st in p.stacks.duplicate():
			out.append(st)
		p.clear()
	if money > 0:
		out.append(ItemStack.make("cash", money))
		money = 0
	for i in quick.size():
		quick[i] = ""
	_on_changed()
	return out


## Lo que tiene al reaparecer en el campamento: cuchillo, una pistola con dos
## cargadores y una venda (el resto se busca en el alijo).
func give_respawn_kit() -> void:
	_set_equipped("melee", ItemStack.make("knife"))
	var d := load("res://data/weapons/pistol.tres") as WeaponData
	var mag := ItemDB.standard_mag("pistol")
	if mag != "":
		receive(ItemStack.make(mag, 1, {"rounds": ItemDB.get_item(mag).capacity}))
	player.weapons.equip_weapon(d, WEAPON_SLOT["pistol"], {}, false, null, true)
	receive(ItemStack.make("bandage", 2))
	quick[0] = "bandage"
	_on_changed()


## Casco o chaleco que cubre la zona (null si no lleva).
func armor_for_zone(zone: String) -> ItemStack:
	var slot := Armor.slot_for_zone(zone)
	return equipment.get(slot) as ItemStack if slot != "" else null


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
		var mid := String(s.state.get("mag_id", ""))
		if mid != "" and ItemDB.has(mid):
			# El cargador sale con sus balas; queda suelta la de la recámara
			var chamber := mini(n, 1)
			var m := ItemStack.make(mid, 1, {"rounds": n - chamber})
			if receive(m) > 0:
				drop(m)
			s.state["mag_id"] = ""
			n = chamber
		s.state["mag"] = 0
	if n > 0:
		receive(ItemStack.make(ItemDB.ammo_id(s.item.caliber), n))
	_on_changed()


# --- Accesorios -------------------------------------------------------------------

## Ranura donde está equipada esta pila ("" si no está equipada).
func equipped_slot_of(s: ItemStack) -> String:
	for k: String in equipment:
		if equipment[k] == s:
			return k
	return ""


## Mira o silenciador puesto en un arma ("" = nada).
func attachment_of(weapon: ItemStack, key: String) -> String:
	var slot := equipped_slot_of(weapon)
	if slot != "":
		_sync_weapon(slot)
	var w := weapon.item.weapon()
	if key == "sight":
		return WeaponAttach.sight_of(w, weapon.state) if not ItemDB.mount(w.id).is_empty() else ""
	return WeaponAttach.muzzle_of(weapon.state)


## Pone una mira o un silenciador (que está en "from") en un arma. El que tenía vuelve
## al lugar del nuevo (o donde entre). Devuelve true si se pudo.
func attach(weapon: ItemStack, att: ItemStack, from: Inventory) -> bool:
	if weapon == null or att == null or weapon.item.kind != "weapon" or not att.item.is_attachment():
		return false
	if not ItemDB.fits_weapon(att.item, weapon.item.weapon()):
		EventBus.toast.emit(tr("inv.no_fit"))
		return false
	var key := "sight" if att.item.kind == "sight" else "muzzle"
	var old := attachment_of(weapon, key)
	var at := att.pos
	if from != null:
		from.remove(att)
	weapon.state[key] = att.item.id
	if old != "":
		var o := ItemStack.make(old)
		if from == null or not from.place(o, at, false):
			if receive(o) > 0:
				drop(o)
	_reinstall(weapon)
	_foley("equip")
	_on_changed()
	return true


## Saca la mira o el silenciador de un arma (va a los contenedores del jugador).
func detach(weapon: ItemStack, key: String) -> bool:
	var cur := attachment_of(weapon, key)
	if cur == "":
		return false
	var o := ItemStack.make(cur)
	if receive(o) > 0:
		EventBus.toast.emit(tr("inv.no_room"))
		return false
	weapon.state[key] = ""
	_reinstall(weapon)
	_foley("equip")
	_on_changed()
	return true


## Vuelve a poner un arma equipada (con su estado nuevo: accesorios).
func _reinstall(weapon: ItemStack) -> void:
	var slot := equipped_slot_of(weapon)
	if WEAPON_SLOT.has(slot) and player != null:
		player.weapons.equip_weapon(weapon.item.weapon(), WEAPON_SLOT[slot], weapon.state, false, weapon, false)


## Arrastrar munición sobre un cargador: lo llena con esa pila. Devuelve cuántos entraron.
func load_mag_from(mag: ItemStack, ammo: ItemStack, from: Inventory) -> int:
	if mag == null or ammo == null or mag.item.kind != "mag" or ammo.item.kind != "ammo" \
			or ItemDB.ammo_caliber(ammo.item.caliber) != ItemDB.ammo_caliber(mag.item.caliber):
		return 0
	var n := mini(mag.item.capacity - mag.rounds(), ammo.count)
	if n <= 0:
		return 0
	mag.state["rounds"] = mag.rounds() + n
	ammo.count -= n
	if ammo.count <= 0 and from != null:
		from.remove(ammo)
	_foley("pickup_item")
	_on_changed()
	return n


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


## La pila más chica de un ítem (primero en bolsillos y chaleco).
func first_stack(id: String) -> ItemStack:
	for quick_only: bool in [true, false]:
		var best: ItemStack = null
		for inv in (quick_storages() if quick_only else storages()):
			for s in inv.stacks:
				if s.item.id == id and (best == null or s.count < best.count):
					best = s
		if best != null:
			return best
	return null


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
	var s := using if using != null and storage_of(using) != null else first_stack(it.id)
	using = null
	using_item = null
	player.weapons.lowered = false
	if s == null:
		EventBus.item_use_finished.emit(it.id, false)
		return
	var inv := storage_of(s)
	s.count -= 1
	if s.count <= 0:
		inv.remove(s)
	else:
		inv.changed.emit()
	player.apply_item_effects(it.effects)
	EventBus.item_use_finished.emit(it.id, true)


# --- Plata y suelo ---------------------------------------------------------------

## Agrega una pila venida de afuera (suelo, saqueo). La plata va al contador. Los
## cargadores van primero al chaleco y los bolsillos; lo demás, primero a la mochila.
## Un chaleco o mochila con cosas adentro no se guarda en otro. Devuelve lo que no entró.
func receive(s: ItemStack) -> int:
	if s.item.kind == "money":
		money += s.count
		_on_changed()
		return 0
	if s.has_contents():
		return s.count
	var order: Array[Inventory] = []
	if s.item.kind in ["mag"]:
		order.append_array(rig_grids())
		order.append_array(pockets)
		order.append_array(bag_grids())
	else:
		order.append_array(bag_grids())
		order.append_array(rig_grids())
		order.append_array(pockets)
	# Primero se completan pilas iguales en cualquier lado; después, lugar libre
	if s.item.stackable() and s.state.is_empty():
		for inv in order:
			for o in inv.stacks:
				if s.count > 0 and o.item == s.item and o.state.is_empty() and o.count < o.item.stack_max:
					var mv := mini(o.space_left(), s.count)
					o.count += mv
					s.count -= mv
					inv.changed.emit()
	for inv in order:
		if s.count <= 0 or inv.add(s) == 0:
			return 0
	return s.count


func bag_grids() -> Array[Inventory]:
	var b := equipment.get("backpack") as ItemStack
	return b.contents if b != null else ([] as Array[Inventory])


## ¿Se puede poner esta pila en este inventario? (un chaleco o mochila con cosas no
## va adentro de los contenedores del jugador, ni una mochila adentro de sí misma)
func accepts(inv: Inventory, s: ItemStack) -> bool:
	if s.contents.has(inv):
		return false
	if s.has_contents() and is_storage(inv):
		return false
	return true


# --- Movimientos entre inventarios (los usa la pantalla de inventario) -----------

## Pasa una pila de un inventario a otro (a cualquier lugar libre, juntando con las
## iguales). La plata que entra a la mochila va al contador. Devuelve true si pasó algo.
func transfer(s: ItemStack, from: Inventory, to: Inventory) -> bool:
	if s == null or not from.has_stack(s) or from == to:
		return false
	if not accepts(to, s):
		EventBus.toast.emit(tr("inv.full_container"))
		return false
	var pos := s.pos
	var rot := s.rotated
	var before := s.count
	from.remove(s)
	var left := receive(s) if to == null else to.add(s)
	if left > 0:
		# Lo que no entró vuelve a su lugar
		s.count = left
		if not from.place(s, pos, rot):
			from.add(s)
	if left < before:
		_foley("pickup_item")
	return left < before


## Mueve una pila a una celda de otro (o del mismo) inventario. Si cae sobre una pila
## igual, se juntan. Devuelve true si se movió algo.
func move_to(s: ItemStack, from: Inventory, to: Inventory, at: Vector2i, rotated: bool) -> bool:
	if s == null or not from.has_stack(s):
		return false
	if not accepts(to, s):
		EventBus.toast.emit(tr("inv.full_container"))
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
	if is_storage(to) and s.item.kind == "money":
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


## Pasa todo un contenedor al jugador (lo que entre, donde entre).
func take_all(from: Inventory) -> int:
	var moved := 0
	for st in from.stacks.duplicate():
		if transfer(st, from, null):
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
	_set_equipped(slot, s)
	if WEAPON_SLOT.has(slot):
		player.weapons.equip_weapon(s.item.weapon(), WEAPON_SLOT[slot], s.state, false, s, false)
	_on_changed()
	return true


## Tira una pila al suelo delante del jugador (ya sacada del inventario).
## Con "at_feet" cae a los pies (sin sonido): lo que no entró al agarrar otra cosa.
func drop(s: ItemStack, at_feet := false) -> WorldItem:
	if s == null or player == null or not player.is_inside_tree():
		return null
	var cam := player.camera
	var fwd := -cam.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var parent := player.get_tree().current_scene if player.get_tree().current_scene != null else player.get_parent()
	if at_feet:
		var side := fwd.cross(Vector3.UP)
		var w := WorldItem.spawn(parent, s, player.global_position + fwd * 0.25 + side * 0.25 + Vector3(0, 0.35, 0))
		w.add_collision_exception_with(player)
		return w
	var pos := player.global_position + fwd * 0.7 + Vector3(0, 1.1, 0)
	_foley("drop_item")
	return WorldItem.spawn(parent, s, pos, fwd * 1.6 + Vector3(0, 1.0, 0))


# --- Guardado --------------------------------------------------------------------

func to_dict() -> Dictionary:
	sync_weapons()
	var eq := {}
	for k: String in equipment:
		var s := equipment[k] as ItemStack
		eq[k] = s.to_dict() if s != null else null
	var pk: Array = []
	for p in pockets:
		pk.append(p.to_dict())
	return {"pockets": pk, "equipment": eq, "quick": quick.duplicate(), "money": money}
