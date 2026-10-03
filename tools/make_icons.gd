extends SceneTree
## Rasterizes app icons: godot --headless --path . -s tools/make_icons.gd


func _initialize() -> void:
	_render("res://icon.svg", "res://assets/icons/icon_192.png", 192)
	# Play Store icon: full-bleed square (Play applies its own mask).
	var bg := _render("res://assets/icons/icon_bg.svg", "", 512)
	var fg := _render("res://assets/icons/icon_fg.svg", "", 512)
	bg.blend_rect(fg, Rect2i(0, 0, 512, 512), Vector2i.ZERO)
	bg.convert(Image.FORMAT_RGB8)
	bg.save_png("res://store/icon_512.png")
	_render("res://assets/icons/icon_fg.svg", "res://assets/icons/icon_fg_432.png", 432)
	_render("res://assets/icons/icon_bg.svg", "res://assets/icons/icon_bg_432.png", 432)
	quit()


func _render(src: String, dst: String, size: int) -> Image:
	var svg := FileAccess.get_file_as_string(src)
	var img := Image.new()
	var native := 512.0 if src.ends_with("icon.svg") else 432.0
	img.load_svg_from_string(svg, size / native)
	if dst != "":
		img.save_png(dst)
		print("wrote ", dst, " ", img.get_size())
	return img
