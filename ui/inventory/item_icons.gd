class_name ItemIcons
extends Node
## Íconos del inventario: cada ítem se dibuja una vez desde su modelo 3D (el mismo
## que se ve en el suelo) en un SubViewport propio, con fondo transparente. Las armas
## se ven de costado; el resto, en tres cuartos desde arriba.

const PX_PER_CELL := 96

static var _inst: ItemIcons

var _cache: Dictionary = {}


static func icon(tree: SceneTree, item: ItemData) -> Texture2D:
	if item == null or tree == null:
		return null
	if _inst == null or not is_instance_valid(_inst):
		_inst = ItemIcons.new()
		_inst.name = "ItemIcons"
		tree.root.add_child(_inst)
	return _inst._icon_for(item)


func _icon_for(item: ItemData) -> Texture2D:
	if _cache.has(item.id):
		return _cache[item.id]
	var vp := SubViewport.new()
	vp.size = Vector2i(item.size.x, item.size.y) * PX_PER_CELL
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	var model := ItemModels.build(item)
	vp.add_child(model)
	# Luz de estudio: principal desde arriba a la izquierda y relleno
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(deg_to_rad(-60), deg_to_rad(-35), 0)
	key.light_energy = 1.3
	vp.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(deg_to_rad(-25), deg_to_rad(140), 0)
	fill.light_energy = 0.45
	vp.add_child(fill)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.75, 0.72)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	cam.environment = env
	if item.kind == "weapon" or item.kind == "melee":
		# De costado (el modelo está acostado con el caño hacia +X): desde arriba
		cam.basis = Basis.looking_at(Vector3.DOWN, Vector3.FORWARD)
	else:
		cam.basis = Basis.from_euler(Vector3(deg_to_rad(-52), deg_to_rad(28), 0))
	_frame(cam, model, Vector2(vp.size))
	vp.add_child(cam)
	cam.current = true
	var tex := vp.get_texture()
	_cache[item.id] = tex
	return tex


## Encuadra el modelo: tamaño ortográfico y posición según su caja vista desde la cámara.
func _frame(cam: Camera3D, model: Node3D, px: Vector2) -> void:
	var box := ItemModels.local_aabb(model)
	var inv := cam.basis.inverse()
	var mn := Vector3(INF, INF, INF)
	var mx := -mn
	for i in 8:
		var p := inv * box.get_endpoint(i)
		mn = mn.min(p)
		mx = mx.max(p)
	var ext := mx - mn
	var aspect := px.x / maxf(px.y, 1.0)
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = maxf(ext.y, ext.x / aspect) * 1.12
	var center_cam := (mn + mx) * 0.5
	cam.position = cam.basis * Vector3(center_cam.x, center_cam.y, mx.z + 2.0)
	cam.near = 0.05
	cam.far = ext.z + 4.0
