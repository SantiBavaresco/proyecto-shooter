class_name MapScreen
extends CanvasLayer
## Mapa en tiempo real ([M]): una foto desde arriba del nivel (se saca una vez) con
## todo encima, moviéndose: vos, los enemigos (bandidos, militares, en combate o
## muertos), cajas, tu cuerpo, objetos sueltos y humo. Rueda: zoom; arrastrar: mover.
## Es una herramienta de prueba: el mapa "de verdad" (PDA, sin enemigos) llega en la F6.
## El juego sigue corriendo mientras está abierto.

const PHOTO_SIZE := 1024
const BG := Color(0.07, 0.08, 0.09, 0.94)
const C_BANDIT := Color(0.91, 0.2, 0.17)
const C_MIL := Color(0.27, 0.59, 1.0)
const C_PLAYER := Color(0.35, 0.9, 0.47)
const C_LOOT := Color(0.98, 0.84, 0.27)
const C_WEAPONS := Color(0.98, 0.59, 0.16)
const C_STASH := Color(0.31, 0.82, 0.94)

var is_open: bool = false
var show_enemies: bool = true
var show_loot: bool = true
var show_items: bool = true

var _view: Control
var _photo: Texture2D
var _rect: Rect2 = Rect2(-150, -150, 300, 300)
var _level: Node = null
var _zoom: float = 1.0
var _pan: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _toggles: HBoxContainer
var _title: Label


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_view = Control.new()
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.draw.connect(_draw_map)
	_view.gui_input.connect(_on_gui_input)
	add_child(_view)
	var top := HBoxContainer.new()
	top.position = Vector2(24, 16)
	top.add_theme_constant_override("separation", 18)
	add_child(top)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 26)
	top.add_child(_title)
	_toggles = HBoxContainer.new()
	_toggles.add_theme_constant_override("separation", 12)
	top.add_child(_toggles)
	for t: Array in [["map.enemies", "show_enemies"], ["map.loot", "show_loot"], ["map.items", "show_items"]]:
		var cb := CheckBox.new()
		cb.text = tr(String(t[0]))
		cb.button_pressed = bool(get(String(t[1])))
		cb.focus_mode = Control.FOCUS_NONE
		var prop := String(t[1])
		cb.toggled.connect(func(on: bool) -> void:
			set(prop, on)
			_view.queue_redraw())
		_toggles.add_child(cb)
	var hint := Label.new()
	hint.text = tr("map.hint")
	hint.add_theme_font_size_override("font_size", 16)
	hint.modulate = Color(1, 1, 1, 0.6)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position = Vector2(24, -36)
	add_child(hint)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pda") and not event.is_echo():
		if is_open:
			close()
		elif GameState.state == GameState.State.PLAYING and not GameState.ui_open:
			open()
		get_viewport().set_input_as_handled()
	elif is_open and event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	var p := _player()
	if p == null:
		return
	var lvl := _find_level(p)
	if lvl != _level or _photo == null:
		_level = lvl
		_rect = _level_rect(lvl, p)
		_zoom = 1.0
		_pan = Vector2.ZERO
		await _take_photo(p)
	is_open = true
	visible = true
	GameState.set_ui_open(true)
	_title.text = tr("map.title")
	_view.queue_redraw()


func close() -> void:
	is_open = false
	visible = false
	_dragging = false
	GameState.set_ui_open(false)


func _process(_delta: float) -> void:
	if is_open:
		_view.queue_redraw()


func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


## El nivel: el primer ancestro del jugador que sabe su rectángulo (map_rect), o su padre.
func _find_level(p: Player) -> Node:
	var n: Node = p.get_parent()
	while n != null and n != get_tree().root:
		if n.has_method("map_rect"):
			return n
		n = n.get_parent()
	return p.get_parent()


## Rectángulo (x, z) del nivel: el que diga el nivel, o el que ocupan sus construcciones.
func _level_rect(lvl: Node, p: Player) -> Rect2:
	if lvl != null and lvl.has_method("map_rect"):
		return lvl.call("map_rect")
	var box := AABB()
	var first := true
	for n in lvl.find_children("*", "StaticBody3D", true, false):
		for c in n.get_children():
			var cs := c as CollisionShape3D
			if cs == null or cs.shape == null:
				continue
			var r := cs.shape.get_debug_mesh().get_aabb() if cs.shape.get_debug_mesh() != null else AABB()
			var g := cs.global_transform * r
			if g.size.x > 600.0 or g.size.z > 600.0:
				continue
			box = g if first else box.merge(g)
			first = false
	if first:
		return Rect2(p.global_position.x - 150, p.global_position.z - 150, 300, 300)
	var m := 10.0
	var side := maxf(box.size.x, box.size.z) + m * 2.0
	var cx := box.position.x + box.size.x * 0.5
	var cz := box.position.z + box.size.z * 0.5
	return Rect2(cx - side * 0.5, cz - side * 0.5, side, side)


## Foto desde arriba del nivel (cámara ortográfica, sin niebla), una sola vez.
func _take_photo(p: Player) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(PHOTO_SIZE, PHOTO_SIZE)
	vp.world_3d = p.get_world_3d()
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.own_world_3d = false
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = maxf(_rect.size.x, _rect.size.y)
	cam.far = 1200.0
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	var env_node := get_tree().root.find_children("*", "WorldEnvironment", true, false)
	if not env_node.is_empty() and (env_node[0] as WorldEnvironment).environment != null:
		var env := (env_node[0] as WorldEnvironment).environment.duplicate() as Environment
		env.fog_enabled = false
		env.volumetric_fog_enabled = false
		cam.environment = env
	vp.add_child(cam)
	add_child(vp)
	var c := _rect.get_center()
	cam.global_transform = Transform3D(Basis.looking_at(Vector3.DOWN, Vector3.FORWARD), Vector3(c.x, 400.0, c.y))
	cam.current = true
	for i in 3:
		await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	_photo = ImageTexture.create_from_image(img) if img != null else null
	vp.queue_free()


# --- Dibujo ---------------------------------------------------------------------------

## Área del mapa en pantalla (cuadrada, centrada) con zoom y desplazamiento.
func _screen_rect() -> Rect2:
	var s := _view.size
	var side := minf(s.x - 48.0, s.y - 120.0) * _zoom
	var c := s * 0.5 + Vector2(0, 20) + _pan
	return Rect2(c - Vector2(side, side) * 0.5, Vector2(side, side))


func _w2s(p: Vector3) -> Vector2:
	var r := _screen_rect()
	return r.position + Vector2((p.x - _rect.position.x) / _rect.size.x, (p.z - _rect.position.y) / _rect.size.y) * r.size.x


func _draw_map() -> void:
	var r := _screen_rect()
	if _photo != null:
		_view.draw_texture_rect(_photo, r, false, Color(0.75, 0.75, 0.75))
	else:
		_view.draw_rect(r, Color(0.2, 0.22, 0.2))
	_view.draw_rect(r, Color(1, 1, 1, 0.35), false, 2.0)
	var font := ThemeDB.fallback_font
	var px_per_m := r.size.x / _rect.size.x
	# Humo
	for n in get_tree().get_nodes_in_group("smoke_cloud"):
		var sc := n as SmokeCloud
		var rad := sc.radius()
		if rad < 0.3:
			continue
		var ax: Array = sc.axis()
		var a := _w2s(ax[0])
		var b := _w2s(ax[1])
		var steps := 6
		for i in steps + 1:
			_view.draw_circle(a.lerp(b, float(i) / steps), rad * px_per_m, Color(0.85, 0.85, 0.85, 0.12))
	# Cajas
	if show_loot:
		for n in get_tree().get_nodes_in_group("loot_containers"):
			var lc := n as LootContainer
			var col := {"weapons": C_WEAPONS, "stash": C_STASH}.get(lc.kind, C_LOOT) as Color
			if lc.filled and lc.inventory.is_empty():
				col.a = 0.4
			var s := _w2s(lc.global_position)
			_view.draw_rect(Rect2(s - Vector2(5, 5), Vector2(10, 10)), col)
			_view.draw_rect(Rect2(s - Vector2(5, 5), Vector2(10, 10)), Color.BLACK, false, 1.5)
	# Objetos sueltos
	if show_items:
		for n in get_tree().get_nodes_in_group("world_items"):
			_view.draw_circle(_w2s((n as Node3D).global_position), 2.5, Color(1, 1, 1, 0.8))
	# Tu cuerpo
	for n in get_tree().get_nodes_in_group("player_corpse"):
		var s := _w2s((n as Node3D).global_position)
		_x(s, 8.0, Color(0.75, 0.45, 0.95), 3.0)
	# Enemigos
	if show_enemies:
		for n in get_tree().get_nodes_in_group("ai_npc"):
			var h := n as HumanNpc
			if h == null:
				continue
			var mil := h.tactics == "military"
			var col := C_MIL if mil else C_BANDIT
			var pos := h.body.ragdoll.center() if h.dead and h.body != null and h.body.ragdoll != null else h.global_position
			var s := _w2s(pos)
			if h.dead:
				_x(s, 5.0, Color(col, 0.55), 2.0)
				continue
			# Hacia dónde mira
			var f := Vector2(-sin(h._yaw), -cos(h._yaw))
			_view.draw_line(s, s + f * 14.0, Color(col, 0.8), 2.0)
			if mil:
				_view.draw_colored_polygon(PackedVector2Array([s + Vector2(0, -7), s + Vector2(7, 0), s + Vector2(0, 7), s + Vector2(-7, 0)]), col)
			else:
				_view.draw_circle(s, 6.0, col)
			var st := h.brain.state if h.brain != null else NpcBrain.State.IDLE
			if st == NpcBrain.State.COMBAT:
				_view.draw_arc(s, 10.0, 0, TAU, 20, Color(1, 0.3, 0.2), 2.0)
			elif st in [NpcBrain.State.INVESTIGATE, NpcBrain.State.SEARCH]:
				_view.draw_arc(s, 10.0, 0, TAU, 20, Color(1, 0.85, 0.2), 1.5)
	# Vos
	var p := _player()
	if p != null:
		var s := _w2s(p.global_position)
		var f := Vector2(-sin(p.yaw), -cos(p.yaw))
		var side := Vector2(-f.y, f.x)
		_view.draw_colored_polygon(PackedVector2Array([s + f * 13.0, s - f * 8.0 + side * 8.0, s - f * 8.0 - side * 8.0]), C_PLAYER)
		_view.draw_polyline(PackedVector2Array([s + f * 13.0, s - f * 8.0 + side * 8.0, s - f * 8.0 - side * 8.0, s + f * 13.0]), Color.BLACK, 1.5)
		_view.draw_string(font, s + Vector2(14, -8), "%d, %d" % [roundi(p.global_position.x), roundi(p.global_position.z)],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.8))
	# Norte y escala
	var nr := r.position + Vector2(r.size.x - 30, 34)
	_view.draw_colored_polygon(PackedVector2Array([nr + Vector2(0, -20), nr + Vector2(-10, 8), nr + Vector2(10, 8)]), Color(0.95, 0.95, 0.95))
	_view.draw_string(font, nr + Vector2(-6, 28), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	var m := 100.0
	for c: float in [5.0, 10.0, 25.0, 50.0, 100.0]:
		if c * px_per_m >= 70.0:
			m = c
			break
	var sb := r.position + Vector2(16, r.size.y - 20)
	_view.draw_rect(Rect2(sb, Vector2(m * px_per_m, 6)), Color(0.95, 0.95, 0.95))
	_view.draw_string(font, sb + Vector2(0, -6), "%d m" % int(m), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)


func _x(s: Vector2, k: float, col: Color, w: float) -> void:
	_view.draw_line(s + Vector2(-k, -k), s + Vector2(k, k), col, w)
	_view.draw_line(s + Vector2(-k, k), s + Vector2(k, -k), col, w)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var before := _screen_rect()
			var k := 1.2 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.2
			var nz := clampf(_zoom * k, 1.0, 8.0)
			# Zoom alrededor del mouse
			var rel := (mb.position - before.position) / before.size
			_zoom = nz
			var after := _screen_rect()
			_pan += mb.position - (after.position + rel * after.size)
			if _zoom <= 1.0:
				_pan = Vector2.ZERO
		elif mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			_dragging = mb.pressed
	elif event is InputEventMouseMotion and _dragging:
		_pan += (event as InputEventMouseMotion).relative
