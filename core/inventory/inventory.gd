class_name Inventory
extends RefCounted
## Grilla de inventario (mochila del jugador, cajón, cuerpo). Solo lógica: la
## pantalla de inventario la dibuja y la manipula por esta API.
##
## Cada pila ocupa un rectángulo de celdas (girable 90°). Las pilas iguales sin
## estado propio se juntan hasta su máximo.

signal changed

var width: int = 10
var height: int = 8
var stacks: Array[ItemStack] = []
## Nombre para mostrar (clave de traducción) cuando es un contenedor.
var title_key: String = ""


func _init(w := 10, h := 8) -> void:
	width = w
	height = h


# --- Consultas ------------------------------------------------------------------

func total_weight() -> float:
	var t := 0.0
	for s in stacks:
		t += s.weight()
	return t


func count_of(id: String) -> int:
	var n := 0
	for s in stacks:
		if s.item.id == id:
			n += s.count
	return n


func stack_at(cell: Vector2i) -> ItemStack:
	for s in stacks:
		if Rect2i(s.pos, s.cells()).has_point(cell):
			return s
	return null


func has_stack(s: ItemStack) -> bool:
	return stacks.has(s)


func is_empty() -> bool:
	return stacks.is_empty()


## ¿Entra un rectángulo de "cells" en "at"? (ignorando la pila "ignore").
func fits(cells: Vector2i, at: Vector2i, ignore: ItemStack = null) -> bool:
	if at.x < 0 or at.y < 0 or at.x + cells.x > width or at.y + cells.y > height:
		return false
	var r := Rect2i(at, cells)
	for s in stacks:
		if s != ignore and Rect2i(s.pos, s.cells()).intersects(r):
			return false
	return true


## Primer lugar libre (de arriba abajo, de izquierda a derecha). Devuelve
## [celda, girado] o [] si no entra de ninguna forma.
func find_free(size: Vector2i, allow_rotate := true) -> Array:
	for y in height:
		for x in width:
			if fits(size, Vector2i(x, y)):
				return [Vector2i(x, y), false]
	if allow_rotate and size.x != size.y:
		var r := Vector2i(size.y, size.x)
		for y in height:
			for x in width:
				if fits(r, Vector2i(x, y)):
					return [Vector2i(x, y), true]
	return []


# --- Cambios --------------------------------------------------------------------

## Pone la pila en una celda (si entra). No junta pilas.
func place(s: ItemStack, at: Vector2i, rotated := false) -> bool:
	var was := s.rotated
	s.rotated = rotated
	if not fits(s.cells(), at, s):
		s.rotated = was
		return false
	s.pos = at
	if not stacks.has(s):
		stacks.append(s)
	changed.emit()
	return true


## Agrega una pila: primero completa las pilas iguales y después busca lugar.
## Devuelve cuántas unidades quedaron afuera (0 = entró todo). La pila que se pasa
## puede terminar adentro tal cual (si entra entera en un lugar libre).
func add(s: ItemStack) -> int:
	if s == null or s.count <= 0:
		return 0
	if s.state.is_empty() and s.item.stackable():
		for o in stacks:
			if o.item == s.item and o.state.is_empty() and o.count < o.item.stack_max:
				var mv := mini(o.space_left(), s.count)
				o.count += mv
				s.count -= mv
				if s.count == 0:
					changed.emit()
					return 0
	while s.count > 0:
		var spot := find_free(s.item.size)
		if spot.is_empty():
			changed.emit()
			return s.count
		if s.count <= s.item.stack_max:
			s.rotated = spot[1]
			s.pos = spot[0]
			stacks.append(s)
			changed.emit()
			return 0
		# Pila más grande que el máximo: se parte
		var part := s.copy()
		part.count = s.item.stack_max
		part.rotated = spot[1]
		part.pos = spot[0]
		stacks.append(part)
		s.count -= s.item.stack_max
	changed.emit()
	return 0


## Atajo: agrega n unidades de un ítem. Devuelve las que no entraron.
func add_item(id: String, n := 1, state := {}) -> int:
	var it := ItemDB.get_item(id)
	if it == null:
		return n
	if not it.stackable() or not state.is_empty():
		var left := 0
		for i in n:
			left += add(ItemStack.make(id, 1, state))
		return left
	return add(ItemStack.make(id, n))


## ¿Entraría todo esto? (sin cambiar nada)
func can_add(s: ItemStack) -> bool:
	var tmp := Inventory.new(width, height)
	for o in stacks:
		tmp.stacks.append(o.copy())
	return tmp.add(s.copy()) == 0


func remove(s: ItemStack) -> void:
	if stacks.has(s):
		stacks.erase(s)
		changed.emit()


## Saca n unidades de un ítem (de las pilas más chicas primero). Devuelve cuántas sacó.
func take(id: String, n: int) -> int:
	if n <= 0:
		return 0
	var mine: Array[ItemStack] = []
	for s in stacks:
		if s.item.id == id:
			mine.append(s)
	mine.sort_custom(func(a: ItemStack, b: ItemStack) -> bool: return a.count < b.count)
	var got := 0
	for s in mine:
		var t := mini(s.count, n - got)
		s.count -= t
		got += t
		if s.count <= 0:
			stacks.erase(s)
		if got >= n:
			break
	if got > 0:
		changed.emit()
	return got


## Deja exactamente n unidades de un ítem (saca o agrega). Devuelve lo que no entró.
func set_count(id: String, n: int) -> int:
	var have := count_of(id)
	if n < have:
		take(id, have - n)
		return 0
	return add_item(id, n - have)


## Parte una pila: saca "n" a una pila nueva en un lugar libre. null si no hay lugar.
func split(s: ItemStack, n: int) -> ItemStack:
	if not stacks.has(s) or n <= 0 or n >= s.count:
		return null
	var spot := find_free(s.item.size)
	if spot.is_empty():
		return null
	var part := s.copy()
	part.count = n
	part.pos = spot[0]
	part.rotated = spot[1]
	s.count -= n
	stacks.append(part)
	changed.emit()
	return part


## Junta "src" en "dst" (mismo ítem). Devuelve lo que sobró en "src".
func merge(src: ItemStack, dst: ItemStack) -> int:
	if not src.can_merge(dst):
		return src.count
	var mv := mini(dst.space_left(), src.count)
	dst.count += mv
	src.count -= mv
	if src.count <= 0:
		stacks.erase(src)
	changed.emit()
	return src.count


## Reacomoda todo: por tipo, después los más grandes, juntando pilas iguales.
func sort() -> void:
	var all := stacks.duplicate()
	stacks.clear()
	all.sort_custom(func(a: ItemStack, b: ItemStack) -> bool:
		if a.item.kind_rank() != b.item.kind_rank():
			return a.item.kind_rank() < b.item.kind_rank()
		var aa := a.item.size.x * a.item.size.y
		var ba := b.item.size.x * b.item.size.y
		if aa != ba:
			return aa > ba
		if a.item.id != b.item.id:
			return a.item.id < b.item.id
		return a.count > b.count)
	var left: Array[ItemStack] = []
	for s: ItemStack in all:
		s.rotated = false
		if add(s) > 0:
			left.append(s)
	# Lo que no entró ordenado (raro: grilla muy llena) vuelve donde pueda
	for s in left:
		var spot := find_free(s.item.size)
		if not spot.is_empty():
			s.pos = spot[0]
			s.rotated = spot[1]
			stacks.append(s)
	changed.emit()


func clear() -> void:
	stacks.clear()
	changed.emit()


# --- Guardado -------------------------------------------------------------------

func to_dict() -> Dictionary:
	var arr: Array = []
	for s in stacks:
		arr.append(s.to_dict())
	return {"w": width, "h": height, "stacks": arr}


func load_dict(d: Dictionary) -> void:
	width = int(d.get("w", width))
	height = int(d.get("h", height))
	stacks.clear()
	for e: Dictionary in d.get("stacks", []):
		var s := ItemStack.from_dict(e)
		if s != null:
			stacks.append(s)
	changed.emit()
