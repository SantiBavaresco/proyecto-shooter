extends Node
## Vista desde arriba de la Isla Talavera (cámara ortográfica) y un JSON con las
## posiciones de enemigos, cajas y el puesto, para dibujar el esquema encima.

const Zone := preload("res://world/zone_talavera/zone_talavera.tscn")
const SIZE := 420.0

var out_dir := "user://map"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_tree().create_timer(300.0).timeout.connect(func() -> void: get_tree().quit())
	DebugTools.god_mode = true
	var zone := Zone.instantiate()
	add_child(zone)
	await _frames(120)
	var player := get_tree().get_first_node_in_group("player") as Player
	var data := {"npcs": [], "loot": [], "player": []}
	for n in zone.find_children("*", "HumanNpc", true, false):
		var h := n as HumanNpc
		h.ai_enabled = false
		var pts := []
		for p in h.patrol:
			pts.append([p.x, p.z])
		data["npcs"].append({"name": String(h.name), "squad": h.squad, "loadout": h.loadout_id,
			"x": h.global_position.x, "y": h.global_position.y, "z": h.global_position.z, "patrol": pts})
	for n in zone.find_children("*", "LootContainer", true, false):
		var c := n as LootContainer
		data["loot"].append({"name": String(c.name), "kind": c.kind, "x": c.global_position.x, "z": c.global_position.z})
	if player != null:
		data["player"] = [player.global_position.x, player.global_position.z]
	var f := FileAccess.open(out_dir.path_join("map.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "  "))
	f.close()
	for c in zone.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	var we := zone.find_children("*", "WorldEnvironment", true, false)
	for w in we:
		var env := (w as WorldEnvironment).environment
		if env != null:
			env.fog_enabled = false
			env.volumetric_fog_enabled = false
	var cam := Camera3D.new()
	zone.add_child(cam)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = SIZE
	cam.far = 900.0
	cam.global_transform = Transform3D(Basis.looking_at(Vector3.DOWN, Vector3.FORWARD), Vector3(0, 300, 0))
	cam.current = true
	await _frames(30)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join("top.png"))
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
