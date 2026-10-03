class_name Effects
extends RefCounted
## One-shot visual effects (self-freeing).


static func explosion(at: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = at
	root.add_child(_burst(Color("ffb02e"), Color("ff3b1f"), 40, 0.9, 3.2, 0.35))
	root.add_child(_burst(Color(0.35, 0.35, 0.38, 0.9), Color(0.6, 0.6, 0.62, 0.0), 24, 1.8, 1.2, 0.5))
	root.add_child(_burst(Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.0), 30, 1.2, 2.0, 0.18))
	_free_later(root, 2.2)
	return root


static func popup(text: String, at: Vector3, color: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = load("res://assets/fonts/LilitaOne-Regular.ttf")
	l.font_size = 96
	l.outline_size = 24
	l.modulate = color.lightened(0.2)
	l.outline_modulate = Color(0.1, 0.15, 0.25)
	l.pixel_size = 0.006
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = at
	l.ready.connect(func() -> void:
		var t := l.create_tween().set_parallel()
		t.tween_property(l, "position:y", at.y + 1.4, 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		t.tween_property(l, "modulate:a", 0.0, 0.4).set_delay(0.5)
		t.chain().tween_callback(l.queue_free))
	return l


static func _burst(c0: Color, c1: Color, amount: int, lifetime: float, velocity: float, size: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = size * 0.5
	mesh.height = size
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mesh.material = mat
	p.mesh = mesh
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = true
	p.explosiveness = 0.95
	p.direction = Vector3.UP
	p.spread = 80.0
	p.gravity = Vector3(0, -2.5, 0)
	p.initial_velocity_min = velocity * 0.4
	p.initial_velocity_max = velocity
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var ramp := Gradient.new()
	ramp.set_color(0, c0)
	ramp.set_color(1, c1)
	p.color_ramp = ramp
	p.emitting = true
	return p


static func _free_later(node: Node, seconds: float) -> void:
	node.ready.connect(func() -> void:
		node.get_tree().create_timer(seconds).timeout.connect(node.queue_free))
