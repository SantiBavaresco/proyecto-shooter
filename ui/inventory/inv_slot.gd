class_name InvSlot
extends Control
## Casilla de equipo (arma, casco, chaleco, mochila) o ranura rápida (5–8).

const UiTheme := preload("res://ui/theme/ui_theme.gd")

## "weapon1", "weapon2", "pistol", "melee", "helmet", "armor", "rig", "backpack" o "quick".
var slot: String = ""
var quick_index: int = -1
var pinv: PlayerInventory
## Resaltar como destino posible mientras se arrastra (1 entra, -1 no entra, 0 nada).
var highlight: int = 0
var hovered: bool = false
var _font: Font


func setup(p: PlayerInventory, slot_name: String, px: Vector2, qi := -1) -> void:
	pinv = p
	slot = slot_name
	quick_index = qi
	custom_minimum_size = px
	size = px
	mouse_filter = Control.MOUSE_FILTER_PASS
	_font = get_theme_default_font()


## Pila equipada (para las rápidas: la primera de ese consumible en la mochila).
func stack() -> ItemStack:
	if pinv == null:
		return null
	if slot == "quick":
		var id := pinv.quick[quick_index]
		return pinv.first_stack(id) if id != "" else null
	return pinv.equipment.get(slot) as ItemStack


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var bg := Color(0.07, 0.08, 0.06, 0.9)
	if highlight > 0:
		bg = Color(0.18, 0.3, 0.14, 0.9)
	elif highlight < 0:
		bg = Color(0.3, 0.12, 0.1, 0.9)
	elif hovered:
		bg = Color(0.13, 0.14, 0.11, 0.9)
	draw_rect(r, bg)
	draw_rect(r, UiTheme.PANEL_BORDER, false, 1.0)
	var label := ""
	if slot == "quick":
		label = "%d" % (quick_index + 5)
		var id := pinv.quick[quick_index] if pinv != null else ""
		if id != "":
			var it := ItemDB.get_item(id)
			var tmp := ItemStack.new()
			tmp.item = it
			var n := pinv.count_of(id)
			InvGrid.draw_icon(self, tmp, r.grow(-4), n == 0, 0)
			var t := "%d" % n
			var tw := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
			draw_string(_font, Vector2(r.end.x - tw - 4, r.end.y - 4), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 17,
				UiTheme.TEXT if n > 0 else UiTheme.ALERT)
		draw_string(_font, Vector2(5, 17), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UiTheme.ACCENT)
		return
	label = tr("inv.slot." + slot)
	var s := stack()
	if s != null:
		# Casilla parada (armas largas a los costados): el arma se dibuja con el caño arriba
		var upright := size.y > size.x * 1.3 and s.item.size.x > s.item.size.y
		InvGrid.draw_icon(self, s, Rect2(Vector2(6, 22), size - Vector2(12, 34)), false, 2 if upright else 0)
		if s.state.has("condition"):
			var c := float(s.state["condition"])
			var bar := Rect2(Vector2(6, size.y - 8), Vector2(minf(60.0, size.x * 0.4), 3))
			draw_rect(bar, Color(0, 0, 0, 0.6))
			draw_rect(Rect2(bar.position, Vector2(bar.size.x * c, 3)), InvGrid.cond_color(c))
		if s.item.kind == "weapon":
			var mag := int(s.state.get("mag", 0))
			if pinv != null and pinv.player != null and PlayerInventory.WEAPON_SLOT.has(slot):
				var ws := pinv.player.weapons.weapon_state(PlayerInventory.WEAPON_SLOT[slot])
				mag = int(ws.get("mag", mag))
			var cap := InvGrid.weapon_cap(s)
			if pinv != null and pinv.player != null and PlayerInventory.WEAPON_SLOT.has(slot):
				var wsl := pinv.player.weapons.slots.get(PlayerInventory.WEAPON_SLOT[slot]) as WeaponController.WeaponSlot
				if wsl != null:
					cap = wsl.capacity()
			var t2 := "%d/%d" % [mag, cap]
			var tw2 := _font.get_string_size(t2, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			draw_string(_font, Vector2(size.x - tw2 - 6, size.y - 6), t2, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiTheme.TEXT_DIM)
	draw_string(_font, Vector2(6, 18), label.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
		UiTheme.TEXT_DIM if s != null else UiTheme.TEXT_DIM.darkened(0.2))
