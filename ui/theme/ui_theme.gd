extends RefCounted
## Tema visual de la interfaz, armado por código para no depender del editor.
## Paleta sobria: grises verdosos, acento ocre, alerta óxido.

const BG := Color("1b1e17")
const PANEL := Color(0.09, 0.10, 0.08, 0.92)
const PANEL_BORDER := Color("3a3f30")
const TEXT := Color("e4e2d6")
const TEXT_DIM := Color("9a9a88")
const ACCENT := Color("c9a227")
const ALERT := Color("b4462c")
const BUTTON := Color("2a2e23")
const BUTTON_HOVER := Color("3a3f2e")
const BUTTON_PRESSED := Color("4a4f38")


static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = 24

	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", ACCENT)
	t.set_color("font_disabled_color", "Button", TEXT_DIM.darkened(0.3))
	t.set_color("font_color", "CheckBox", TEXT)
	t.set_color("font_hover_color", "CheckBox", Color.WHITE)
	t.set_color("font_color", "OptionButton", TEXT)

	t.set_stylebox("normal", "Button", _box(BUTTON, PANEL_BORDER))
	t.set_stylebox("hover", "Button", _box(BUTTON_HOVER, ACCENT.darkened(0.3)))
	t.set_stylebox("pressed", "Button", _box(BUTTON_PRESSED, ACCENT))
	t.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), ACCENT, 2))
	t.set_stylebox("disabled", "Button", _box(BUTTON.darkened(0.3), PANEL_BORDER.darkened(0.3)))
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		t.set_stylebox(state, "OptionButton", t.get_stylebox(state, "Button"))

	t.set_stylebox("panel", "PanelContainer", _box(PANEL, PANEL_BORDER, 1, 18))
	t.set_stylebox("panel", "Panel", _box(PANEL, PANEL_BORDER, 1, 18))

	var tab_sel := _box(BUTTON_HOVER, ACCENT, 0, 10)
	tab_sel.border_width_bottom = 3
	t.set_stylebox("tab_selected", "TabContainer", tab_sel)
	t.set_stylebox("tab_unselected", "TabContainer", _box(BUTTON, PANEL_BORDER, 0, 10))
	t.set_stylebox("tab_hovered", "TabContainer", _box(BUTTON_HOVER, PANEL_BORDER, 0, 10))
	t.set_stylebox("panel", "TabContainer", _box(PANEL, PANEL_BORDER, 1, 18))
	t.set_color("font_selected_color", "TabContainer", ACCENT)
	t.set_color("font_unselected_color", "TabContainer", TEXT_DIM)
	t.set_color("font_hovered_color", "TabContainer", TEXT)

	var slider_bg := StyleBoxFlat.new()
	slider_bg.bg_color = BUTTON
	slider_bg.content_margin_top = 3
	slider_bg.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", slider_bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = ACCENT.darkened(0.2)
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)

	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0, 0, 0, 0.5)
	bar_bg.set_corner_radius_all(2)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = ACCENT
	bar_fill.set_corner_radius_all(2)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fill)
	t.set_color("font_color", "ProgressBar", TEXT)
	return t


static func _box(bg: Color, border: Color, border_w := 1, margin := 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = margin + 6
	sb.content_margin_right = margin + 6
	sb.content_margin_top = margin * 0.6
	sb.content_margin_bottom = margin * 0.6
	return sb
