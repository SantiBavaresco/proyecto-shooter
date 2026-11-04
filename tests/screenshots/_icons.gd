extends SceneTree
## Hoja de íconos del inventario (para revisar modelos de ítems).
## Uso: godot --path . -s res://tests/screenshots/_icons.gd -- --out=hoja.png --ids=rig_light,rig_medium
var out := "user://icons.png"
var ids: PackedStringArray = []

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.trim_prefix("--out=")
		if a.begins_with("--ids="): ids = a.trim_prefix("--ids=").split(",")
	_run.call_deferred()

func _run() -> void:
	var texs: Array = []
	for id in ids:
		texs.append(ItemIcons.icon(self, ItemDB.get_item(id)))
	for i in 10:
		await process_frame
	var cell := 260
	var cols := 4
	var sheet := Image.create(cell * cols, cell * ceili(ids.size() / float(cols)), false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.1, 0.11, 0.09))
	for i in texs.size():
		var img := (texs[i] as Texture2D).get_image()
		var k := minf(float(cell - 10) / img.get_width(), float(cell - 10) / img.get_height())
		img.resize(int(img.get_width() * k), int(img.get_height() * k))
		img.convert(Image.FORMAT_RGBA8)
		sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i((i % cols) * cell + 5, (i / cols) * cell + 5))
	sheet.save_png(out)
	quit()
