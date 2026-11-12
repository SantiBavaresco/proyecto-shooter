class_name InventoryScreen
extends CanvasLayer
## Pantalla de inventario (Tab):
##  - izquierda: equipo (2 armas largas, pistola, arma blanca, casco, chaleco, chaleco
##    táctico, mochila), las 4 ranuras rápidas (5–8) y la ficha del ítem (con
##    comparación contra lo equipado);
##  - centro: lo que lleva el jugador: bolsillos, las grillas del chaleco táctico (con
##    su forma) y la de la mochila, con el peso y la plata;
##  - derecha (al revisar algo): el contenedor o el cuerpo, con "Tomar todo" (las tres
##    secciones a la vez, con las grillas del mismo tamaño que solo con la mochila).
##
## Mouse: arrastrar para mover (R gira mientras se arrastra), soltar afuera para
## tirar, clic derecho para acciones, doble clic para usar / equipar / pasar,
## Mayús+clic para pasar entre mochila y contenedor. El mundo no se pausa.

const UiTheme := preload("res://ui/theme/ui_theme.gd")
## Celda de la grilla (px, en la resolución base 1920×1080) y unidad de las casillas
## de equipo.
const CELL := 66.0
const EQ := 48.0
## Filas de la grilla que se ven a la vez (el resto, con la rueda): la mochila y el
## contenedor.
const VISIBLE_ROWS := 9.0
const BAG_ROWS := 6.0
## Separación entre las grillas del chaleco y los bolsillos.
const GAP := 6.0
const DRAG_START_PX := 5.0

enum Act { USE, EQUIP, UNEQUIP, UNLOAD, SPLIT, DROP, TAKE, STORE, CLEAR_QUICK, FILL_MAG, EMPTY_MAG, DETACH_SIGHT,
	DETACH_MUZZLE, SEARCH, QUICK_1 = 20, ATTACH_1 = 40 }

var player: Player
var pinv: PlayerInventory
## Contenedor abierto (LootContainer o NpcDummy: tienen "inventory" y "title_key").
var container: Object = null
var is_open: bool = false

var _root: Control
var _bag_grid: InvGrid
var _bag_scroll: ScrollContainer
var _bag_title: Label
var _pocket_grids: Array[InvGrid] = []
var _rig_grids: Array[InvGrid] = []
var _rig_box: Control
var _rig_title: Label
## Chaleco y mochila que se están mostrando (para rearmar las grillas si cambian).
var _shown_rig: ItemStack = null
var _shown_bag: Object = null
var _loot_grid: InvGrid
## Grillas del contenedor que se muestra: la única (_loot_grid) o las de un chaleco
## tirado (varias, acomodadas como en el chaleco).
var _loot_grids: Array[InvGrid] = []
var _loot_box: Control
var _loot_scroll: ScrollContainer
var _back_btn: Button
var _loot_panel: Control
var _loot_title: Label
var _slots: Dictionary = {}
var _quick: Array[InvSlot] = []
var _weight_bar: ProgressBar
var _weight_label: Label
var _weight_warn: Label
var _money_label: Label
var _vitals_label: Label
var _info: RichTextLabel
var _menu: PopupMenu
var _drag_ctl: Control
var _equip_panel: Control
var _hint: Label
var _take_btn: Button

# Arrastre
var _press_stack: ItemStack = null
var _press_from: Variant = null  # InvGrid o InvSlot
var _press_pos := Vector2.ZERO
var _dragging := false
var _drag_rot := false
var _grab := Vector2.ZERO  # punto agarrado relativo a la esquina del ítem (px, sin girar)
var _menu_stack: ItemStack = null
var _menu_from: Variant = null
var _info_stack: ItemStack = null
var _selected: ItemStack = null


func _ready() -> void:
	layer = 20
	_build()
	visible = false
	EventBus.loot_requested.connect(func(c: Object) -> void: open(c))
	EventBus.bag_search_requested.connect(func(st: ItemStack) -> void: open(BagView.new(st, GroundPile)))
	EventBus.inventory_changed.connect(_refresh)
	EventBus.player_died.connect(func() -> void: close())


func _find_player() -> bool:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player
		pinv = player.inventory if player != null else null
	return pinv != null


# --- Abrir / cerrar --------------------------------------------------------------

func open(c: Object = null) -> void:
	if not _find_player() or player.is_dead:
		return
	if is_open and c == container:
		return
	if is_open:
		_close_container()
	pinv.sync_weapons()
	if c == null:
		# Sin contenedor: lo que hay en el piso alrededor
		c = GroundPile.new(player)
	container = c
	is_open = true
	visible = true
	GameState.set_ui_open(true)
	_shown_rig = null
	_shown_bag = null
	_sync_storage_grids()
	for k: String in _slots:
		(_slots[k] as InvSlot).pinv = pinv
	for q in _quick:
		q.pinv = pinv
	if container != null:
		_setup_loot_grids()
		_loot_title.text = tr(String(container.get("title_key"))).to_upper()
		_loot_panel.visible = true
		# Revisando algo: equipo, mochila y contenedor, con las grillas del mismo tamaño
		(_loot_grid.get_parent() as ScrollContainer).scroll_vertical = 0
		if container.has_method("on_loot_opened"):
			container.call("on_loot_opened")
	else:
		_loot_panel.visible = false
	_selected = null
	_info_stack = null
	_refresh()


func close() -> void:
	if not is_open:
		return
	_cancel_drag()
	_menu.hide()
	_close_container()
	is_open = false
	visible = false
	GameState.set_ui_open(false)


func _close_container() -> void:
	if container != null and is_instance_valid(container) and container.has_method("on_loot_closed"):
		container.call("on_loot_closed")
	container = null


## Arma las grillas del contenedor: una sola, o las de un chaleco con su forma.
func _setup_loot_grids() -> void:
	for g in _loot_grids:
		if g != _loot_grid:
			g.queue_free()
	_loot_grids.clear()
	var invs: Array = container.get("inventories") if "inventories" in container else []
	if invs.size() > 1:
		var lay: Array = container.get("layout")
		var size := Vector2.ZERO
		for i in invs.size():
			var g := InvGrid.new()
			g.setup(invs[i], CELL)
			var l: Array = lay[i] if i < lay.size() else [0, i * 2]
			g.position = Vector2(float(l[0]), float(l[1])) * (CELL + GAP)
			_loot_box.add_child(g)
			_loot_grids.append(g)
			size = size.max(g.position + g.size)
		_loot_box.custom_minimum_size = size
		_loot_box.visible = true
		_loot_scroll.visible = false
	else:
		_loot_grid.setup(container.get("inventory") as Inventory, CELL)
		_loot_grids.append(_loot_grid)
		_loot_box.visible = false
		_loot_scroll.visible = true
	_back_btn.visible = "back" in container and container.get("back") != null


func _is_loot(g: Variant) -> bool:
	return g is InvGrid and _loot_grids.has(g)


## Dónde guardar algo en el contenedor: la primera grilla en la que entra.
func _loot_dest(s: ItemStack) -> Inventory:
	for g in _loot_grids:
		if g.inv.can_add(s):
			return g.inv
	return _loot_grids[0].inv if not _loot_grids.is_empty() else null


## Revisar una mochila o chaleco (tirado o en un contenedor) sin agarrarlo.
func open_bag(s: ItemStack) -> void:
	var from := container
	if from is GroundPile:
		from = GroundPile
	open(BagView.new(s, from))


func _go_back() -> void:
	if container == null or not ("back" in container):
		return
	var b: Variant = container.get("back")
	open(null if (b == GroundPile or b == null) else b)


func _unhandled_input(event: InputEvent) -> void:
	if is_open or GameState.state != GameState.State.PLAYING:
		return
	if event.is_action_pressed("inventory") and not event.is_echo():
		open(null)
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if _menu.visible:
		return
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.is_action("inventory") or event.is_action("pause"):
			close()
			get_viewport().set_input_as_handled()
			return
		if event.is_action("inv_rotate") and _dragging:
			_drag_rot = not _drag_rot
			_update_drag(_mouse())
			get_viewport().set_input_as_handled()
			return
		if event.is_action("inv_take_all") and _loot_panel.visible:
			take_all()
			get_viewport().set_input_as_handled()
			return
		if event.is_action("inv_sort"):
			pinv.bag.sort()
			get_viewport().set_input_as_handled()
			return
		if event.is_action("inv_use") and not _dragging:
			var hu := _hit(_mouse())
			if hu[0] != null:
				_quick_action(hu[0], hu[1])
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseMotion:
		var m := _mouse()
		if _press_stack != null and not _dragging and m.distance_to(_press_pos) > DRAG_START_PX:
			_start_drag()
		if _dragging:
			_autoscroll(m)
			_update_drag(m)
		else:
			_update_hover(m)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		var m := _mouse()
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if mb.double_click:
					_cancel_drag()
					var hit := _hit(m)
					if hit[0] != null:
						_quick_action(hit[0], hit[1])
				else:
					_press(m, Input.is_action_pressed("inv_quick_move"))
			else:
				if _dragging:
					_drop(m)
				_press_stack = null
				_dragging = false
				_drag_ctl.queue_redraw()
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_cancel_drag()
			var hit2 := _hit(m)
			if hit2[0] != null:
				_open_menu(hit2[0], hit2[1], mb.global_position)
			get_viewport().set_input_as_handled()


func _mouse() -> Vector2:
	return _root.get_global_mouse_position()


# --- Qué hay bajo el mouse ---------------------------------------------------------

## [pila, origen (InvGrid o InvSlot)] bajo el punto.
func _hit(m: Vector2) -> Array:
	for g: InvGrid in _grids():
		if _grid_rect(g).has_point(m):
			return [g.stack_at_local(m - g.global_position), g]
	for sl: InvSlot in _all_slots():
		if sl.get_global_rect().has_point(m):
			return [sl.stack(), sl]
	return [null, null]


## Parte visible de una grilla (las grillas van dentro de un panel con desplazamiento).
func _grid_rect(g: InvGrid) -> Rect2:
	var r := g.get_global_rect()
	var sc := g.get_parent() as ScrollContainer
	if sc != null:
		r = r.intersection(sc.get_global_rect())
	return r


## Las grillas del jugador (bolsillos, chaleco, mochila) según lo que tenga puesto.
func _sync_storage_grids() -> void:
	if pinv == null:
		return
	for i in _pocket_grids.size():
		if _pocket_grids[i].inv != pinv.pockets[i]:
			_pocket_grids[i].setup(pinv.pockets[i], CELL)
	var rig := pinv.equipment.get("rig") as ItemStack
	if rig != _shown_rig:
		_shown_rig = rig
		for g in _rig_grids:
			g.queue_free()
		_rig_grids.clear()
		var size := Vector2.ZERO
		if rig != null:
			for i in rig.contents.size():
				var lay: Array = rig.item.grids[i]
				var g := InvGrid.new()
				g.setup(rig.contents[i], CELL)
				g.position = Vector2(float(lay[0]), float(lay[1])) * (CELL + GAP)
				_rig_box.add_child(g)
				_rig_grids.append(g)
				size = size.max(g.position + g.size)
		_rig_box.custom_minimum_size = size
		_rig_title.text = tr("inv.rig") + (" · " + tr(rig.item.name_key) if rig != null else "  —  " + tr("inv.no_rig"))
	var bag_stack := pinv.equipment.get("backpack") as ItemStack
	if bag_stack != _shown_bag or _bag_grid.inv != pinv.bag:
		_shown_bag = bag_stack
		_bag_grid.setup(pinv.bag, CELL)
		_bag_scroll.visible = bag_stack != null
		_bag_scroll.custom_minimum_size = Vector2(maxi(pinv.bag.width, 4) * CELL + 16,
			CELL * minf(BAG_ROWS, float(maxi(pinv.bag.height, 1))))
		_bag_scroll.scroll_vertical = 0
		_bag_title.text = tr("inv.backpack") + (" · " + tr(bag_stack.item.name_key) if bag_stack != null else "  —  " + tr("inv.no_backpack"))


## Grilla del jugador (no la del contenedor).
func _is_player_grid(g: Variant) -> bool:
	return g is InvGrid and not _loot_grids.has(g) and g != _loot_grid


## Arrastrando cerca del borde de arriba o de abajo de una grilla: se desplaza sola.
func _autoscroll(m: Vector2) -> void:
	for g: InvGrid in _grids():
		var sc := g.get_parent() as ScrollContainer
		if sc == null:
			continue
		var r := sc.get_global_rect()
		if m.x < r.position.x or m.x > r.end.x:
			continue
		if m.y < r.position.y + 40.0 and m.y > r.position.y - 30.0:
			sc.scroll_vertical -= 18
		elif m.y > r.end.y - 40.0 and m.y < r.end.y + 30.0:
			sc.scroll_vertical += 18


func _grids() -> Array[InvGrid]:
	var out: Array[InvGrid] = []
	out.append_array(_pocket_grids)
	out.append_array(_rig_grids)
	if _bag_scroll.visible:
		out.append(_bag_grid)
	if _loot_panel.visible:
		out.append_array(_loot_grids)
	return out


func _all_slots() -> Array[InvSlot]:
	var out: Array[InvSlot] = []
	for k: String in _slots:
		out.append(_slots[k])
	out.append_array(_quick)
	return out


func _update_hover(m: Vector2) -> void:
	var hit := _hit(m)
	var s := hit[0] as ItemStack
	for g: InvGrid in _grids():
		var hv: ItemStack = s if hit[1] == g else null
		if g.hovered != hv:
			g.hovered = hv
			g.queue_redraw()
	for sl: InvSlot in _all_slots():
		var hv2: bool = hit[1] == sl
		if sl.hovered != hv2:
			sl.hovered = hv2
			sl.queue_redraw()
	_mark_compat(s)
	_show_info(s if s != null else _selected)


## ¿Van juntos? Accesorio ↔ arma donde se monta, cargador ↔ arma que lo usa,
## munición ↔ arma y cargador de su calibre.
static func fits_together(a: ItemStack, b: ItemStack) -> bool:
	if a == null or b == null or a == b:
		return false
	for pair: Array in [[a, b], [b, a]]:
		var x := pair[0] as ItemStack
		var y := pair[1] as ItemStack
		if y.item.kind == "weapon":
			var w := y.item.weapon()
			if x.item.is_attachment() and ItemDB.fits_weapon(x.item, w):
				return true
			if x.item.kind == "mag" and ItemDB.mag_family(w.id) == x.item.mag_family:
				return true
			if x.item.kind == "ammo" and ItemDB.ammo_caliber(x.item.caliber) == ItemDB.ammo_caliber(w.caliber):
				return true
		if x.item.kind == "ammo" and y.item.kind == "mag" \
				and ItemDB.ammo_caliber(x.item.caliber) == ItemDB.ammo_caliber(y.item.caliber):
			return true
	return false


## Resalta en verde lo que va con el ítem señalado (en todas las grillas y el equipo).
func _mark_compat(s: ItemStack) -> void:
	var on := s != null and (s.item.is_attachment() or s.item.kind in ["mag", "ammo", "weapon"])
	for g: InvGrid in _grids():
		var list: Array = []
		if on:
			for o in g.inv.stacks:
				if fits_together(s, o):
					list.append(o)
		if list != g.compat:
			g.compat = list
			g.queue_redraw()
	for sl: InvSlot in _all_slots():
		var c := on and sl.slot != "quick" and fits_together(s, sl.stack())
		if c != sl.compat:
			sl.compat = c
			sl.queue_redraw()


# --- Arrastrar y soltar ------------------------------------------------------------

func _press(m: Vector2, shift: bool) -> void:
	var hit := _hit(m)
	var s := hit[0] as ItemStack
	if s == null:
		_selected = null
		_redraw_all()
		return
	if shift and hit[1] is InvGrid and _loot_panel.visible:
		# Mayús+clic: pasa entre la mochila y el contenedor
		_shift_transfer(s, hit[1])
		return
	_selected = s
	_press_stack = s
	_press_from = hit[1]
	_press_pos = m
	_drag_rot = s.rotated if hit[1] is InvGrid else false
	if hit[1] is InvGrid:
		var g := hit[1] as InvGrid
		_grab = m - (g.global_position + Vector2(s.pos) * g.cell)
	else:
		_grab = Vector2(CELL, CELL) * 0.5
	_show_info(s)
	_redraw_all()


func _start_drag() -> void:
	_dragging = true
	if _press_from is InvGrid:
		(_press_from as InvGrid).dragging = _press_stack
		(_press_from as InvGrid).queue_redraw()
	_drag_ctl.queue_redraw()


func _drag_cells() -> Vector2i:
	var sz := _press_stack.item.size
	return Vector2i(sz.y, sz.x) if _drag_rot else sz


## Celda de destino en una grilla para el ítem arrastrado (esquina superior izquierda).
func _drop_cell(g: InvGrid, m: Vector2) -> Vector2i:
	var grab := _grab
	if _drag_rot != (_press_stack.rotated if _press_from is InvGrid else false):
		grab = Vector2(grab.y, grab.x)
	var corner := m - g.global_position - grab + Vector2(g.cell, g.cell) * 0.5
	return g.cell_at(corner)


func _update_drag(m: Vector2) -> void:
	for g: InvGrid in _grids():
		g.ghost_at = Vector2i(-1, -1)
		if _grid_rect(g).has_point(m):
			var at := _drop_cell(g, m)
			g.ghost_at = at
			g.ghost_size = _drag_cells()
			var target := g.inv.stack_at(g.cell_at(m - g.global_position))
			var ok := g.inv.fits(_drag_cells(), at, _press_stack if _press_from == g else null)
			if target != null and _press_stack.can_merge(target):
				ok = true
			g.ghost_ok = ok
		g.queue_redraw()
	for sl: InvSlot in _all_slots():
		var hl := 0
		if sl.get_global_rect().has_point(m):
			if sl.slot == "quick":
				hl = 1 if _press_stack.item.is_consumable() else -1
			else:
				hl = 1 if pinv.can_equip(_press_stack, sl.slot) or (sl == _press_from) \
					or fits_together(_press_stack, sl.stack()) else -1
		if sl.highlight != hl:
			sl.highlight = hl
			sl.queue_redraw()
	_drag_ctl.queue_redraw()


func _drop(m: Vector2) -> void:
	var s := _press_stack
	var from: Variant = _press_from
	_clear_drag_marks()
	if s == null:
		return
	var src_inv: Inventory = (from as InvGrid).inv if from is InvGrid else null
	# Un accesorio sobre un arma (en una grilla o equipada) o munición sobre un cargador
	if src_inv != null and (s.item.is_attachment() or s.item.kind == "ammo"):
		var tgt := _hit(m)
		var ts := tgt[0] as ItemStack
		if ts != null and ts != s:
			if s.item.is_attachment() and ts.item.kind == "weapon":
				pinv.attach(ts, s, src_inv)
				_refresh()
				return
			if s.item.kind == "ammo" and ts.item.kind == "mag":
				pinv.load_mag_from(ts, s, src_inv)
				_refresh()
				return
	# Sobre una casilla de equipo o rápida
	for sl: InvSlot in _all_slots():
		if sl.get_global_rect().has_point(m):
			_drop_on_slot(s, from, sl)
			return
	# Sobre una grilla
	for g: InvGrid in _grids():
		if _grid_rect(g).has_point(m):
			var at := _drop_cell(g, m)
			var target := g.inv.stack_at(g.cell_at(m - g.global_position))
			if target != null and target != s and s.can_merge(target):
				at = target.pos
			if from is InvGrid:
				pinv.move_to(s, (from as InvGrid).inv, g.inv, at, _drag_rot)
			elif from is InvSlot and (from as InvSlot).slot != "quick":
				pinv.unequip((from as InvSlot).slot, g.inv, at, _drag_rot)
			_refresh()
			return
	# Afuera de los paneles: se tira al suelo
	if not _over_panel(m):
		_drop_to_ground(s, from)
	_refresh()


func _drop_on_slot(s: ItemStack, from: Variant, sl: InvSlot) -> void:
	if sl.slot == "quick":
		if s.item.is_consumable():
			pinv.set_quick(sl.quick_index, s.item.id)
		return
	if from is InvSlot:
		var fs := from as InvSlot
		if fs.slot in ["weapon1", "weapon2"] and sl.slot in ["weapon1", "weapon2"] and fs != sl:
			pinv.swap_weapon_slots()
		return
	if from is InvGrid and pinv.can_equip(s, sl.slot):
		if not pinv.equip(s, sl.slot, (from as InvGrid).inv):
			EventBus.toast.emit(tr("inv.no_room"))
	_refresh()


func _drop_to_ground(s: ItemStack, from: Variant) -> void:
	if from is InvGrid:
		(from as InvGrid).inv.remove(s)
		pinv.drop(s)
	elif from is InvSlot and (from as InvSlot).slot != "quick":
		var t := pinv.take_equipped((from as InvSlot).slot)
		if t != null:
			pinv.drop(t)
	elif from is InvSlot:
		pinv.set_quick((from as InvSlot).quick_index, "")
	if _selected == s:
		_selected = null


func _over_panel(m: Vector2) -> bool:
	for p: Control in _root.get_meta("panels", []):
		if p.visible and p.get_global_rect().has_point(m):
			return true
	return false


func _cancel_drag() -> void:
	_press_stack = null
	_dragging = false
	_clear_drag_marks()


func _clear_drag_marks() -> void:
	if _bag_grid == null:
		return
	for g: InvGrid in _all_grids():
		g.dragging = null
		g.ghost_at = Vector2i(-1, -1)
		g.queue_redraw()
	for sl: InvSlot in _all_slots():
		sl.highlight = 0
		sl.queue_redraw()
	if _drag_ctl != null:
		_drag_ctl.queue_redraw()


func _draw_drag() -> void:
	if not _dragging or _press_stack == null:
		return
	var m := _drag_ctl.get_local_mouse_position()
	var grab := _grab
	if _drag_rot != (_press_stack.rotated if _press_from is InvGrid else false):
		grab = Vector2(grab.y, grab.x)
	var r := Rect2(m - grab, Vector2(_drag_cells()) * CELL)
	_drag_ctl.draw_rect(r, Color(0.2, 0.22, 0.16, 0.75))
	_drag_ctl.draw_rect(r, UiTheme.ACCENT, false, 1.5)
	InvGrid.draw_icon(_drag_ctl, _press_stack, r, false, 1 if _drag_rot else 0)


# --- Acciones ------------------------------------------------------------------------

## Doble clic: consumible → usar; equipo → equipar; en el contenedor → tomar;
## equipado → desequipar.
func _quick_action(s: ItemStack, from: Variant) -> void:
	if from is InvSlot:
		var sl := from as InvSlot
		if sl.slot == "quick":
			pinv.use(s)
		elif pinv.unequip(sl.slot) == null:
			EventBus.toast.emit(tr("inv.no_room"))
	elif _is_loot(from):
		if s.item.is_container() and s.has_contents() and not _can_pick(s):
			open_bag(s)
		else:
			_take_from_loot(s, (from as InvGrid).inv)
	elif s.item.is_consumable():
		if not pinv.use(s):
			EventBus.toast.emit(tr("inv.cant_now"))
	elif s.item.is_equipment():
		pinv.equip(s, pinv.slot_for(s), (from as InvGrid).inv)
	elif s.item.kind == "mag":
		pinv.fill_mag(s)
	elif s.item.is_attachment():
		var ws := _attach_targets(s)
		if not ws.is_empty():
			pinv.attach(ws[0], s, (from as InvGrid).inv)
	_refresh()


## Armas equipadas donde va este accesorio.
func _attach_targets(att: ItemStack) -> Array[ItemStack]:
	var out: Array[ItemStack] = []
	for k: String in ["weapon1", "weapon2", "pistol"]:
		var w := pinv.equipment.get(k) as ItemStack
		if w != null and ItemDB.fits_weapon(att.item, w.item.weapon()):
			out.append(w)
	return out


func _shift_transfer(s: ItemStack, g: InvGrid) -> void:
	if _is_loot(g):
		_take_from_loot(s, g.inv)
	else:
		var dst := _loot_dest(s)
		if dst != null:
			pinv.transfer(s, g.inv, dst)
	_refresh()


## Agarrar algo del contenedor: a los bolsillos/chaleco/mochila; una mochila o un
## chaleco con cosas adentro (no entra en otra mochila) se equipa si esa ranura está libre.
func _take_from_loot(s: ItemStack, src: Inventory) -> void:
	if s.item.is_container() and s.has_contents():
		var slot := pinv.slot_for(s)
		if pinv.equipment.get(slot) == null:
			src.remove(s)
			pinv.place_equipped(s, slot)
		else:
			EventBus.toast.emit(tr("inv.no_room"))
		return
	pinv.transfer(s, src, null)


## Se puede agarrar (equipar en su ranura libre o guardar en algún lado).
func _can_pick(s: ItemStack) -> bool:
	return WorldItem.can_pick(pinv, s)


func _open_menu(s: ItemStack, from: Variant, at: Vector2) -> void:
	_menu.clear()
	_menu_stack = s
	_menu_from = from
	var in_bag: bool = _is_player_grid(from)
	var in_loot: bool = _is_loot(from)
	var equipped: bool = from is InvSlot and (from as InvSlot).slot != "quick"
	var quick_slot: bool = from is InvSlot and (from as InvSlot).slot == "quick"
	if s.item.is_consumable() and (in_bag or quick_slot):
		_menu.add_item(tr("inv.use"), Act.USE)
	if s.item.is_equipment() and (in_bag or in_loot):
		_menu.add_item(tr("inv.equip"), Act.EQUIP)
	if equipped:
		_menu.add_item(tr("inv.unequip"), Act.UNEQUIP)
	if s.item.kind == "weapon" and int(s.state.get("mag", 0)) > 0 and not in_loot:
		_menu.add_item(tr("inv.unload"), Act.UNLOAD)
	if s.item.kind == "weapon" and not in_loot:
		for k: String in ["sight", "muzzle"]:
			var cur := pinv.attachment_of(s, k)
			if cur != "":
				_menu.add_item(tr("inv.detach") % ItemDB.display_name(ItemDB.get_item(cur)),
					Act.DETACH_SIGHT if k == "sight" else Act.DETACH_MUZZLE)
	if s.item.kind == "mag" and not in_loot:
		if s.rounds() < s.item.capacity:
			_menu.add_item(tr("inv.fill_mag"), Act.FILL_MAG)
		if s.rounds() > 0:
			_menu.add_item(tr("inv.empty_mag"), Act.EMPTY_MAG)
	if s.item.is_attachment() and (in_bag or in_loot):
		var targets := _attach_targets(s)
		for i in targets.size():
			_menu.add_item(tr("inv.attach") % ItemDB.display_name(targets[i].item), Act.ATTACH_1 + i)
	if s.item.is_container() and (in_loot or in_bag) and not s.contents.is_empty():
		_menu.add_item(tr("inv.search"), Act.SEARCH)
	if in_loot:
		_menu.add_item(tr("inv.take"), Act.TAKE)
	if in_bag and _loot_panel.visible:
		_menu.add_item(tr("inv.store"), Act.STORE)
	if (in_bag or in_loot) and s.count > 1:
		_menu.add_item(tr("inv.split"), Act.SPLIT)
	if s.item.is_consumable() and in_bag:
		for i in 4:
			_menu.add_item(tr("inv.assign_quick") % (i + 5), Act.QUICK_1 + i)
	if quick_slot:
		_menu.add_item(tr("inv.clear_quick"), Act.CLEAR_QUICK)
	if not quick_slot:
		_menu.add_item(tr("inv.drop"), Act.DROP)
	_menu.reset_size()
	_menu.position = Vector2i(at)
	_menu.popup()


func _on_menu(id: int) -> void:
	var s := _menu_stack
	var from: Variant = _menu_from
	if s == null:
		return
	match id:
		Act.USE:
			if not pinv.use(s):
				EventBus.toast.emit(tr("inv.cant_now"))
		Act.EQUIP:
			var src: Inventory = (from as InvGrid).inv
			if not pinv.equip(s, pinv.slot_for(s), src):
				EventBus.toast.emit(tr("inv.no_room"))
		Act.FILL_MAG:
			pinv.fill_mag(s)
		Act.EMPTY_MAG:
			pinv.empty_mag(s)
		Act.DETACH_SIGHT:
			pinv.detach(s, "sight")
		Act.DETACH_MUZZLE:
			pinv.detach(s, "muzzle")
		Act.UNEQUIP:
			if pinv.unequip((from as InvSlot).slot) == null:
				EventBus.toast.emit(tr("inv.no_room"))
		Act.UNLOAD:
			pinv.unload(s)
		Act.SPLIT:
			(from as InvGrid).inv.split(s, s.count / 2)
		Act.DROP:
			_drop_to_ground(s, from)
		Act.TAKE:
			_take_from_loot(s, (from as InvGrid).inv)
		Act.STORE:
			var dst := _loot_dest(s)
			if dst != null:
				pinv.transfer(s, (from as InvGrid).inv, dst)
		Act.SEARCH:
			_menu_stack = null
			open_bag(s)
			return
		Act.CLEAR_QUICK:
			pinv.set_quick((from as InvSlot).quick_index, "")
		_:
			if id >= Act.QUICK_1 and id < Act.QUICK_1 + 4:
				pinv.set_quick(id - Act.QUICK_1, s.item.id)
			elif id >= Act.ATTACH_1 and id < Act.ATTACH_1 + 3:
				var targets := _attach_targets(s)
				var k := id - Act.ATTACH_1
				if k < targets.size():
					pinv.attach(targets[k], s, (from as InvGrid).inv)
	_menu_stack = null
	_refresh()


func take_all() -> void:
	if container != null and _find_player():
		for g in _loot_grids.duplicate():
			for st in g.inv.stacks.duplicate():
				if st.item.is_container() and st.has_contents():
					continue
				pinv.transfer(st, g.inv, null)
		_refresh()


# --- Ficha del ítem ------------------------------------------------------------------

func _show_info(s: ItemStack) -> void:
	if s == _info_stack and s != null:
		return
	_info_stack = s
	if s == null:
		_info.text = ""
		return
	_info.text = item_sheet(s, pinv)


## Texto de la ficha (BBCode): nombre, descripción y datos; las armas, comparadas con
## la equipada en la ranura que ocuparían.
static func item_sheet(s: ItemStack, p: PlayerInventory) -> String:
	var it := s.item
	var dim := UiTheme.TEXT_DIM.to_html(false)
	var acc := UiTheme.ACCENT.to_html(false)
	var t := "[font_size=26][color=#%s]%s[/color][/font_size]\n" % [acc, ItemDB.display_name(it)]
	t += "[color=#%s]%s[/color]\n" % [dim, TranslationServer.translate(it.desc_key)]
	var rows: Array = []
	if it.kind == "weapon":
		var w := it.weapon()
		var cmp: WeaponData = null
		var cmp_name := ""
		if p != null:
			var slot := p.slot_for(s)
			var eq := p.equipment.get(slot) as ItemStack
			if eq != null and eq != s:
				cmp = eq.item.weapon()
				cmp_name = TranslationServer.translate(eq.item.name_key)
		rows.append([tr_s("inv.stat.caliber"), w.caliber, ""])
		rows.append([tr_s("inv.stat.damage"), "%d" % roundi(w.damage * w.pellets), _delta(w.damage * w.pellets, cmp.damage * cmp.pellets if cmp else NAN, 0)])
		rows.append([tr_s("inv.stat.rpm"), "%d" % roundi(w.rpm), _delta(w.rpm, cmp.rpm if cmp else NAN, 0)])
		rows.append([tr_s("inv.stat.mag"), "%d / %d" % [int(s.state.get("mag", 0)), InvGrid.weapon_cap(s)], _delta(w.mag_size, cmp.mag_size if cmp else NAN, 0)])
		if not ItemDB.mount(w.id).is_empty():
			var sg := WeaponAttach.sight_of(w, s.state)
			rows.append([tr_s("inv.stat.sight"), ItemDB.display_name(ItemDB.get_item(sg)) if sg != "" else "—", ""])
		if ItemDB.thread_of(w) != "":
			var mz := WeaponAttach.muzzle_of(s.state)
			rows.append([tr_s("inv.stat.muzzle"), ItemDB.display_name(ItemDB.get_item(mz)) if mz != "" else "—", ""])
		rows.append([tr_s("inv.stat.accuracy"), "%d" % accuracy(w), _delta(accuracy(w), accuracy(cmp) if cmp else NAN, 0)])
		rows.append([tr_s("inv.stat.condition"), "%d %%" % roundi(float(s.state.get("condition", 1.0)) * 100.0), ""])
		if cmp != null:
			t += "[color=#%s]%s[/color]\n" % [dim, TranslationServer.translate("inv.compare") % cmp_name]
	elif it.kind == "ammo":
		rows.append([tr_s("inv.stat.caliber"), it.caliber, ""])
		rows.append([tr_s("inv.stat.count"), "%d" % s.count, ""])
	elif it.kind == "mag":
		rows.append([tr_s("inv.stat.caliber"), it.caliber, ""])
		rows.append([tr_s("inv.stat.rounds"), "%d / %d" % [s.rounds(), it.capacity], ""])
		rows.append([tr_s("inv.stat.fits"), _fits_text(it), ""])
	elif it.is_attachment():
		rows.append([tr_s("inv.stat.fits"), _fits_text(it), ""])
	elif it.is_container():
		var dims: PackedStringArray = []
		for g: Array in it.grids:
			dims.append("%d×%d" % [int(g[2]), int(g[3])])
		rows.append([tr_s("inv.stat.slots"), ", ".join(dims), ""])
		if it.carry_bonus > 0.0:
			rows.append([tr_s("inv.stat.carry"), "+%d kg" % int(it.carry_bonus), ""])
	elif it.is_consumable():
		var fx := it.effects
		if fx.has("heal"):
			rows.append([tr_s("inv.stat.heal"), "+%d" % int(fx["heal"]), ""])
		if fx.has("bleed"):
			rows.append([tr_s("inv.stat.bleed"), "%d" % int(fx["bleed"]), ""])
		if fx.has("stamina"):
			rows.append([tr_s("inv.stat.stamina"), "+%d" % int(fx["stamina"]), ""])
		if fx.has("regen"):
			rows.append([tr_s("inv.stat.regen"), "%.1f/s · %d s" % [float(fx["regen"]), int(fx.get("duration", 0))], ""])
		rows.append([tr_s("inv.stat.use_time"), "%.1f s" % it.use_time, ""])
	else:
		if it.armor_class > 0:
			rows.append([tr_s("inv.stat.armor_class"), tr_s("inv.stat.class_n") % it.armor_class, ""])
			rows.append([tr_s("inv.stat.stops"), tr_s("armor.stops.%d" % it.armor_class), ""])
		if it.carry_bonus > 0.0:
			rows.append([tr_s("inv.stat.carry"), "+%d kg" % int(it.carry_bonus), ""])
		if s.state.has("condition"):
			rows.append([tr_s("inv.stat.condition"), "%d %%" % roundi(float(s.state["condition"]) * 100.0), ""])
	rows.append([tr_s("inv.stat.weight"), "%.2f kg" % s.weight(), ""])
	if it.kind != "money":
		rows.append([tr_s("inv.stat.price"), "$ %d" % s.price(), ""])
	for r: Array in rows:
		t += "[color=#%s]%s:[/color] %s %s\n" % [dim, r[0], r[1], r[2]]
	return t


static func tr_s(k: String) -> String:
	return TranslationServer.translate(k)


## Armas donde va un cargador o un accesorio (nombres cortos).
static func _fits_text(it: ItemData) -> String:
	var names: PackedStringArray = []
	for wid: String in ItemDB.weapon_item_ids():
		var w := ItemDB.get_item(wid).weapon()
		if w == null:
			continue
		var ok := ItemDB.mag_family(w.id) == it.mag_family if it.kind == "mag" else ItemDB.fits_weapon(it, w)
		if ok:
			names.append(TranslationServer.translate(w.name_key))
	if names.size() > 6:
		return ", ".join(names.slice(0, 6)) + "…"
	return ", ".join(names)


## Precisión 0–100 a partir de la dispersión apuntando (más chica, mejor).
static func accuracy(w: WeaponData) -> float:
	if w == null:
		return 0.0
	return roundf(100.0 / (1.0 + w.spread_ads * 4.0 + w.pellet_spread * 0.5))


static func _delta(v: float, other: float, decimals: int) -> String:
	if is_nan(other) or is_equal_approx(v, other):
		return ""
	var d := v - other
	var col := "7fbf5f" if d > 0 else "c4553a"
	var txt := ("%+." + str(decimals) + "f") % d
	return "[color=#%s](%s)[/color]" % [col, txt]


# --- Refresco ------------------------------------------------------------------------

func _refresh() -> void:
	if not is_open or pinv == null:
		return
	var w := pinv.total_weight()
	var lim := pinv.carry_limit()
	_weight_label.text = tr("inv.weight") % [w, lim]
	_weight_bar.max_value = pinv.carry_max()
	_weight_bar.value = w
	var fill := _weight_bar.get_theme_stylebox("fill") as StyleBoxFlat
	var o := pinv.overload()
	fill.bg_color = UiTheme.ALERT if o > 1.0 else (UiTheme.ACCENT if o > 0.0 else UiTheme.TEXT.darkened(0.3))
	_weight_warn.text = tr("inv.too_heavy") if o > 1.0 else (tr("inv.overloaded") if o > 0.0 else "")
	_weight_warn.visible = _weight_warn.text != ""
	_money_label.text = tr("inv.money") % _thousands(pinv.money)
	_hint.text = _hint_text()
	_take_btn.text = "%s  [%s]" % [tr("inv.take_all"), InputActions.event_label(InputActions.get_kbm_event("inv_take_all"))]
	var v := player.vitals
	_vitals_label.text = "%s %d   %s" % [tr("inv.stat.heal"), roundi(v.health), tr("hud.bleeding") if v.bleeding > 0 else ""]
	_sync_storage_grids()
	if _selected != null and not _stack_exists(_selected):
		_selected = null
	_info_stack = null
	_show_info(_selected)
	_redraw_all()


func _stack_exists(s: ItemStack) -> bool:
	if pinv.storage_of(s) != null:
		return true
	if _loot_panel.visible:
		for g in _loot_grids:
			if g.inv != null and g.inv.has_stack(s):
				return true
	return pinv.equipment.values().has(s)


func _redraw_all() -> void:
	for g: InvGrid in _all_grids():
		g.selected = _selected
		g.queue_redraw()
	for sl: InvSlot in _all_slots():
		sl.queue_redraw()


func _all_grids() -> Array[InvGrid]:
	var out: Array[InvGrid] = []
	out.append_array(_pocket_grids)
	out.append_array(_rig_grids)
	out.append(_bag_grid)
	out.append(_loot_grid)
	for g in _loot_grids:
		if g != _loot_grid:
			out.append(g)
	return out


static func _thousands(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


# --- Armado --------------------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.025, 0.02, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	var main := HBoxContainer.new()
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main.offset_left = 48
	main.offset_right = -48
	main.offset_top = 40
	main.offset_bottom = -40
	main.add_theme_constant_override("separation", 22)
	main.alignment = BoxContainer.ALIGNMENT_CENTER
	main.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(main)
	var panels: Array[Control] = []

	# Equipo (y abajo, la ficha del ítem)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 14)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main.add_child(left)
	var eq := _panel(tr("inv.equipment"))
	_equip_panel = eq[0]
	left.add_child(eq[0])
	panels.append(eq[0])
	var ev := eq[1] as VBoxContainer
	# Tres columnas: Arma 2 y pistola a la izquierda, casco / chaleco / mochila al
	# centro, Arma 1 y arma blanca a la derecha (las armas largas, paradas)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 8)
	cols.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ev.add_child(cols)
	var side := Vector2(EQ * 2.6, EQ * 6.9)
	var small := Vector2(EQ * 2.6, EQ * 2.5)
	var mid := Vector2(EQ * 3.0, EQ * 2.2)
	var layout := [[["weapon2", side], ["pistol", small]],
		[["helmet", mid], ["armor", mid], ["rig", mid], ["backpack", mid]],
		[["weapon1", side], ["melee", small]]]
	for col: Array in layout:
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 8)
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cols.add_child(cv)
		for e: Array in col:
			cv.add_child(_slot(e[0], e[1]))
	var ql := _small_label(tr("inv.quick"), UiTheme.TEXT_DIM, 18)
	ev.add_child(ql)
	var qrow := HBoxContainer.new()
	qrow.add_theme_constant_override("separation", 8)
	ev.add_child(qrow)
	for i in 4:
		var q := InvSlot.new()
		q.setup(null, "quick", Vector2(EQ * 1.5, EQ * 1.5), i)
		qrow.add_child(q)
		_quick.append(q)
	_vitals_label = _small_label("", UiTheme.TEXT, 20)
	ev.add_child(_vitals_label)
	var info_panel := PanelContainer.new()
	info_panel.custom_minimum_size = Vector2(EQ * 9.0, 250)
	left.add_child(info_panel)
	panels.append(info_panel)
	_info = RichTextLabel.new()
	_info.bbcode_enabled = true
	_info.fit_content = false
	_info.scroll_active = false
	_info.add_theme_font_size_override("normal_font_size", 18)
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_panel.add_child(_info)

	# Lo que lleva: bolsillos, chaleco táctico y mochila
	var bag := _panel(tr("inv.title"))
	(bag[0] as Control).custom_minimum_size = Vector2(8.0 * (CELL + GAP) + 40.0, 0)
	main.add_child(bag[0])
	panels.append(bag[0])
	var bv := bag[1] as VBoxContainer
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	bv.add_child(top)
	_weight_bar = ProgressBar.new()
	_weight_bar.show_percentage = false
	_weight_bar.custom_minimum_size = Vector2(120, 12)
	_weight_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var wfill := StyleBoxFlat.new()
	wfill.bg_color = UiTheme.TEXT.darkened(0.3)
	_weight_bar.add_theme_stylebox_override("fill", wfill)
	top.add_child(_weight_bar)
	_weight_label = _small_label("", UiTheme.TEXT, 20)
	top.add_child(_weight_label)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	_money_label = _small_label("", UiTheme.ACCENT, 23)
	top.add_child(_money_label)
	var sort := Button.new()
	sort.text = tr("inv.sort")
	sort.add_theme_font_size_override("font_size", 19)
	sort.focus_mode = Control.FOCUS_NONE
	sort.pressed.connect(func() -> void:
		if pinv != null:
			pinv.bag.sort())
	top.add_child(sort)
	var fill := Button.new()
	fill.text = tr("inv.fill_mags")
	fill.add_theme_font_size_override("font_size", 19)
	fill.focus_mode = Control.FOCUS_NONE
	fill.pressed.connect(func() -> void:
		if pinv != null:
			pinv.fill_all_mags()
			_refresh())
	top.add_child(fill)
	_weight_warn = _small_label("", UiTheme.ALERT, 18)
	bv.add_child(_weight_warn)
	bv.add_child(_small_label(tr("inv.pockets"), UiTheme.TEXT_DIM, 18))
	var pocket_box := Control.new()
	pocket_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bv.add_child(pocket_box)
	for g: Array in PlayerInventory.POCKETS:
		var pg := InvGrid.new()
		pg.setup(Inventory.new(int(g[2]), int(g[3])), CELL)
		pg.position = Vector2(float(g[0]), float(g[1])) * (CELL + GAP)
		pocket_box.add_child(pg)
		_pocket_grids.append(pg)
	pocket_box.custom_minimum_size = Vector2(PlayerInventory.POCKETS.size() * (CELL + GAP), CELL)
	_rig_title = _small_label(tr("inv.rig"), UiTheme.TEXT_DIM, 18)
	bv.add_child(_rig_title)
	_rig_box = Control.new()
	_rig_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bv.add_child(_rig_box)
	_bag_title = _small_label(tr("inv.backpack"), UiTheme.TEXT_DIM, 18)
	bv.add_child(_bag_title)
	_bag_grid = InvGrid.new()
	_bag_grid.setup(Inventory.new(5, 6), CELL)
	_bag_scroll = _scroller(_bag_grid, 6)
	bv.add_child(_bag_scroll)

	# Contenedor
	var loot := _panel("")
	_loot_panel = loot[0]
	main.add_child(_loot_panel)
	panels.append(_loot_panel)
	var lv := loot[1] as VBoxContainer
	_loot_title = lv.get_child(0) as Label
	var take := Button.new()
	take.text = tr("inv.take_all")
	take.add_theme_font_size_override("font_size", 19)
	take.focus_mode = Control.FOCUS_NONE
	take.pressed.connect(take_all)
	take.set_meta("take_button", true)
	_take_btn = take
	lv.add_child(take)
	_back_btn = Button.new()
	_back_btn.text = tr("inv.back")
	_back_btn.add_theme_font_size_override("font_size", 17)
	_back_btn.focus_mode = Control.FOCUS_NONE
	_back_btn.pressed.connect(_go_back)
	_back_btn.visible = false
	lv.add_child(_back_btn)
	_loot_grid = InvGrid.new()
	_loot_grid.setup(Inventory.new(8, 6), CELL)
	_loot_scroll = _scroller(_loot_grid, 8)
	lv.add_child(_loot_scroll)
	_loot_box = Control.new()
	_loot_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loot_box.visible = false
	lv.add_child(_loot_box)
	_loot_panel.visible = false
	_root.set_meta("panels", panels)
	# Ayuda de teclas abajo de todo
	_hint = _small_label("", UiTheme.TEXT_DIM, 16)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_left = -900
	_hint.offset_right = 900
	_hint.offset_top = -34
	_hint.offset_bottom = -8
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_hint)

	_menu = PopupMenu.new()
	_menu.add_theme_font_size_override("font_size", 21)
	_menu.id_pressed.connect(_on_menu)
	add_child(_menu)

	_drag_ctl = Control.new()
	_drag_ctl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_drag_ctl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_ctl.draw.connect(_draw_drag)
	_root.add_child(_drag_ctl)


## Grilla dentro de un panel con desplazamiento vertical (rueda del mouse).
func _scroller(g: InvGrid, cols: int) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	sc.custom_minimum_size = Vector2(cols * CELL + 16, CELL * VISIBLE_ROWS)
	sc.mouse_filter = Control.MOUSE_FILTER_PASS
	sc.add_child(g)
	return sc


## Texto de ayuda con las teclas configuradas.
func _hint_text() -> String:
	var k := func(a: String) -> String: return InputActions.event_label(InputActions.get_kbm_event(a))
	return tr("inv.hint") % [k.call("inv_rotate"), k.call("inv_quick_move"), k.call("inv_use"), k.call("inv_take_all"),
		k.call("inv_sort")]


func _panel(title: String) -> Array:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	p.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	v.add_child(_small_label(title, UiTheme.ACCENT, 24))
	return [p, v]


func _slot(name: String, px: Vector2) -> InvSlot:
	var s := InvSlot.new()
	s.setup(null, name, px)
	_slots[name] = s
	return s


func _small_label(t: String, c: Color, fs: int) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", c)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
