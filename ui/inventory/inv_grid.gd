class_name InvGrid
extends Control
## Grilla de un inventario dibujada: celdas, ítems (ícono, cantidad, estado) y la
## sombra de dónde caería lo que se arrastra. La pantalla de inventario maneja el
## mouse y las acciones; esta clase solo dibuja y convierte coordenadas.

const UiTheme := preload("res://ui/theme/ui_theme.gd")

var inv: Inventory
var cell: float = 44.0
## Pila que se está arrastrando desde esta grilla (se dibuja tenue).
var dragging: ItemStack = null
## Sombra de colocación: celda, tamaño y si entra.
var ghost_at := Vector2i(-1, -1)
var ghost_size := Vector2i.ONE
var ghost_ok := true
var hovered: ItemStack = null
## Pilas que van con lo señalado (se marcan en verde).
var compat: Array = []
var selected: ItemStack = null
var _font: Font


func setup(i: Inventory, cell_px: float) -> void:
	if inv != null and inv.changed.is_connected(queue_redraw):
		inv.changed.disconnect(queue_redraw)
	inv = i
	cell = cell_px
	custom_minimum_size = Vector2(inv.width, inv.height) * cell
	size = custom_minimum_size
	inv.changed.connect(queue_redraw)
	mouse_filter = Control.MOUSE_FILTER_PASS
	queue_redraw()


func cell_at(local: Vector2) -> Vector2i:
	return Vector2i(floori(local.x / cell), floori(local.y / cell))


func stack_at_local(local: Vector2) -> ItemStack:
	if inv == null or not Rect2(Vector2.ZERO, size).has_point(local):
		return null
	return inv.stack_at(cell_at(local))


func stack_rect(s: ItemStack) -> Rect2:
	return Rect2(Vector2(s.pos) * cell, Vector2(s.cells()) * cell)


func _ready() -> void:
	_font = get_theme_default_font()


func _draw() -> void:
	if inv == null:
		return
	var w := inv.width
	var h := inv.height
	draw_rect(Rect2(Vector2.ZERO, Vector2(w, h) * cell), Color(0.05, 0.06, 0.05, 0.85))
	var line := Color(0.32, 0.35, 0.28, 0.55)
	for x in w + 1:
		draw_line(Vector2(x * cell, 0), Vector2(x * cell, h * cell), line, 1.0)
	for y in h + 1:
		draw_line(Vector2(0, y * cell), Vector2(w * cell, y * cell), line, 1.0)
	# Sombra de colocación
	if ghost_at.x >= 0:
		var gc := Color(0.4, 0.75, 0.35, 0.28) if ghost_ok else Color(0.8, 0.25, 0.2, 0.3)
		draw_rect(Rect2(Vector2(ghost_at) * cell, Vector2(ghost_size) * cell), gc)
	for s in inv.stacks:
		_draw_stack(s)


func _draw_stack(s: ItemStack) -> void:
	var r := stack_rect(s).grow(-2.0)
	var faded := s == dragging
	var bg := Color(0.16, 0.18, 0.14, 0.95)
	if s == selected:
		bg = Color(0.26, 0.27, 0.18, 0.95)
	elif s == hovered:
		bg = Color(0.21, 0.23, 0.17, 0.95)
	if faded:
		bg.a = 0.35
	draw_rect(r, bg)
	draw_rect(r, UiTheme.ACCENT.darkened(0.2) if s == selected else UiTheme.PANEL_BORDER, false, 1.0)
	if compat.has(s):
		draw_rect(r, Color(0.3, 0.75, 0.3, 0.16))
		draw_rect(r.grow(-1.0), Color(0.45, 0.9, 0.4), false, 2.0)
	draw_icon(self, s, r, faded)
	# Cantidad abajo a la derecha; estado (barra) abajo a la izquierda
	var fs := int(clampf(cell * 0.22, 14.0, 22.0))
	if s.count > 1 or s.item.kind in ["ammo", "mag"]:
		var t := "%d" % s.count if s.item.kind != "mag" else "%d/%d" % [s.rounds(), s.item.capacity]
		var tw := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(_font, Vector2(r.end.x - tw - 4, r.end.y - 4), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
			UiTheme.TEXT if not faded else UiTheme.TEXT_DIM)
	if s.state.has("condition"):
		var c := float(s.state["condition"])
		var bw := minf(r.size.x * 0.4, cell * 0.9)
		var bar := Rect2(Vector2(r.position.x + 5, r.end.y - 9), Vector2(bw, 4))
		draw_rect(bar, Color(0, 0, 0, 0.6))
		draw_rect(Rect2(bar.position, Vector2(bw * c, 4)), cond_color(c))
	if s.item.kind == "weapon":
		var w := s.item.weapon()
		if w != null:
			var t2 := "%d/%d" % [int(s.state.get("mag", 0)), weapon_cap(s)]
			draw_string(_font, Vector2(r.position.x + 5, r.position.y + fs + 2), t2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 2, UiTheme.TEXT_DIM)


## Capacidad del arma de una pila (la del cargador que tiene puesto).
static func weapon_cap(s: ItemStack) -> int:
	var mid := String(s.state.get("mag_id", ""))
	if mid != "" and ItemDB.has(mid):
		return ItemDB.get_item(mid).capacity
	var w := s.item.weapon()
	return w.mag_size if w != null else 0


static func cond_color(c: float) -> Color:
	if c > 0.7:
		return Color(0.55, 0.75, 0.4)
	if c > 0.4:
		return Color(0.85, 0.7, 0.25)
	return Color(0.8, 0.3, 0.2)


## Ícono de una pila dentro de un rectángulo (girado si la pila está girada).
static func draw_icon(ci: CanvasItem, s: ItemStack, r: Rect2, faded := false, force_rot := -1) -> void:
	var tex := ItemIcons.icon(ci.get_tree(), s.item)
	if tex == null:
		return
	var rot := s.rotated if force_rot < 0 else force_rot >= 1
	var mod := Color(1, 1, 1, 0.35 if faded else 1.0)
	var inner := r.grow(-3.0)
	if not rot:
		ci.draw_texture_rect(tex, _fit(tex.get_size(), inner), false, mod)
	else:
		# Girado 90°: se dibuja con una transformación
		var tsz := tex.get_size()
		var target := Rect2(Vector2.ZERO, Vector2(inner.size.y, inner.size.x))
		var fit := _fit(tsz, target)
		# 1: girado a la derecha (como en la grilla); 2: a la izquierda (caño arriba)
		if force_rot == 2:
			ci.draw_set_transform(inner.position + Vector2(0, inner.size.y), -PI * 0.5, Vector2.ONE)
		else:
			ci.draw_set_transform(inner.position + Vector2(inner.size.x, 0), PI * 0.5, Vector2.ONE)
		ci.draw_texture_rect(tex, fit, false, mod)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _fit(tex_size: Vector2, into: Rect2) -> Rect2:
	if tex_size.x <= 0 or tex_size.y <= 0:
		return into
	var k := minf(into.size.x / tex_size.x, into.size.y / tex_size.y)
	var sz := tex_size * k
	return Rect2(into.position + (into.size - sz) * 0.5, sz)
