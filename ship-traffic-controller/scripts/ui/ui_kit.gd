class_name UiKit
extends RefCounted
## Cartoon UI theme + widget factories (chunky 3D buttons, outlined text, cards).

const FONT := preload("res://assets/fonts/LilitaOne-Regular.ttf")
# Nautical palette: navy ink, sea-teal, coral, sand.
const OUTLINE := Color("0b2545")
const GREEN := Color("2ec4b6")
const BLUE := Color("3d7dd8")
const ORANGE := Color("ff7a59")
const RED := Color("ef476f")
const GREY := Color("9aa8b8")
const CARD := Color("fff3d9")
const INK := Color("0b2545")

static var _theme: Theme


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = FONT
	t.default_font_size = 44
	t.set_color("font_color", "Label", Color.WHITE)
	t.set_color("font_outline_color", "Label", OUTLINE)
	t.set_constant("outline_size", "Label", 14)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.6))
	t.set_color("font_outline_color", "Button", OUTLINE)
	t.set_constant("outline_size", "Button", 12)
	t.set_constant("h_separation", "Button", 16)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	var bar_bg := _box(Color(0, 0.12, 0.25, 0.45), 22)
	var bar_fill := _box(ORANGE, 22)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fill)
	_theme = t
	return t


static func _box(color: Color, radius: int, bottom := 0, border := Color.TRANSPARENT) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.border_width_bottom = bottom
	s.border_color = border
	s.anti_aliasing = true
	return s


static func style_button(b: Button, color: Color, radius := 34) -> void:
	var depth := 10
	var dark := color.darkened(0.3)
	var normal := _box(color, radius, depth, dark)
	normal.content_margin_left = 28
	normal.content_margin_right = 28
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10 + depth
	normal.shadow_color = Color(0, 0.1, 0.2, 0.25)
	normal.shadow_size = 6
	normal.shadow_offset = Vector2(0, 6)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = color.lightened(0.08)
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.border_width_bottom = 3
	pressed.content_margin_top = 10 + depth - 3
	pressed.content_margin_bottom = 13
	pressed.expand_margin_top = -(depth - 3)
	pressed.shadow_size = 2
	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = GREY
	disabled.border_color = GREY.darkened(0.3)
	for st in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
		b.add_theme_stylebox_override(st, {"normal": normal, "hover": hover, "pressed": pressed, "disabled": disabled, "hover_pressed": pressed}[st])


static func button(text: String, color := GREEN, min_size := Vector2(420, 130), font_size := 56, icon_path := "") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font_size)
	if icon_path != "":
		b.icon = load(icon_path)
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", int(font_size * 1.1))
	style_button(b, color)
	_juice(b)
	return b


static func icon_button(icon_path: String, color := BLUE, size := 124) -> Button:
	var b := Button.new()
	b.icon = load(icon_path)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.expand_icon = true
	b.custom_minimum_size = Vector2(size, size)
	style_button(b, color, size / 2)
	for st in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
		var sb: StyleBoxFlat = b.get_theme_stylebox(st)
		sb.content_margin_left = size * 0.22
		sb.content_margin_right = size * 0.22
		sb.content_margin_top = size * 0.16
	_juice(b)
	return b


static func _juice(b: Button) -> void:
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.button_down.connect(func() -> void:
		Audio.play("click")
		GameState.vibrate(12))
	b.resized.connect(func() -> void: b.pivot_offset = b.size * 0.5)
	b.pressed.connect(func() -> void:
		var t := b.create_tween()
		t.tween_property(b, "scale", Vector2(1.08, 1.08), 0.06)
		t.tween_property(b, "scale", Vector2.ONE, 0.12))


static func label(text: String, size := 48, color := Color.WHITE, outline := 14) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", outline)
	return l


static func card(color := CARD, radius := 48) -> PanelContainer:
	var p := PanelContainer.new()
	var s := _box(color, radius, 14, color.darkened(0.18))
	s.content_margin_left = 56
	s.content_margin_right = 56
	s.content_margin_top = 44
	s.content_margin_bottom = 56
	s.shadow_color = Color(0, 0.08, 0.2, 0.35)
	s.shadow_size = 24
	s.shadow_offset = Vector2(0, 12)
	p.add_theme_stylebox_override("panel", s)
	return p


static func pill(color: Color, radius := 30) -> PanelContainer:
	var p := PanelContainer.new()
	var s := _box(color, radius)
	s.content_margin_left = 26
	s.content_margin_right = 26
	s.content_margin_top = 8
	s.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", s)
	return p


static func vbox(sep := 24) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep := 24) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", sep)
	return h


static func icon(path: String, size := 96) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(path)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(size, size)
	t.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return t


## Full-rect dimmer that blocks input to the game below.
static func dimmer(alpha := 0.45) -> ColorRect:
	var c := ColorRect.new()
	c.color = Color(0.02, 0.1, 0.2, alpha)
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	return c


static func pop_in(c: Control) -> void:
	c.pivot_offset = c.size * 0.5
	c.resized.connect(func() -> void: c.pivot_offset = c.size * 0.5)
	c.scale = Vector2(0.6, 0.6)
	c.modulate.a = 0.0
	var t := c.create_tween().set_parallel()
	t.tween_property(c, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(c, "modulate:a", 1.0, 0.2)
