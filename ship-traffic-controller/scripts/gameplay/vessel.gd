class_name Vessel
extends Node3D
## A ship on the map: follows a drawn path or sails freely, avoiding land and edges.

signal docked(vessel: Vessel)

enum State { SAILING, DOCKING, GONE }

const RING_SHADER := preload("res://assets/shaders/ring.gdshader")
const PATH_SHADER := preload("res://assets/shaders/path.gdshader")
const TURN_RATE := 1.8
const PATH_Y := 0.06
const PATH_WIDTH := 0.36

var type := 0
var port := 0
var pos := Vector2.ZERO
var heading := Vector2.UP
var speed := 1.0
var half_len := 0.5
var half_w := 0.2
var state := State.SAILING
var path := PackedVector2Array()
var target: Port
var entered := false
var submerged := false
var warning := false

var _model: MeshInstance3D
var _ring_mat := ShaderMaterial.new()
var _path_mat := ShaderMaterial.new()
var _path_mesh := ImmediateMesh.new()
var _sub_timer := 0.0
var _selected := false


static func _shadow_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(0, 0.1, 0.25, 0.35))
	g.set_color(1, Color(0, 0.1, 0.25, 0.0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 64
	t.height = 64
	return t


func setup(p_type: int, p_pos: Vector2, p_heading: Vector2, speed_mult: float) -> void:
	type = p_type
	var info := VesselData.info(type)
	port = info["port"]
	speed = info["speed"] * speed_mult
	half_len = info["length"] * 0.5
	half_w = info["width"] * 0.5
	pos = p_pos
	heading = p_heading.normalized()
	_sub_timer = randf_range(4.0, 6.0)
	_build()
	_sync(1.0)


func _build() -> void:
	var shadow := MeshInstance3D.new()
	var sq := QuadMesh.new()
	sq.orientation = PlaneMesh.FACE_Y
	sq.size = Vector2(half_w * 2.0 + 0.6, half_len * 2.0 + 0.5)
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.albedo_texture = _shadow_texture()
	smat.no_depth_test = false
	sq.material = smat
	shadow.mesh = sq
	shadow.position = Vector3(0.12, 0.015, 0.12)
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shadow)

	var ring := MeshInstance3D.new()
	var rq := QuadMesh.new()
	rq.orientation = PlaneMesh.FACE_Y
	rq.size = Vector2(half_w * 2.0 + 0.55, half_len * 2.0 + 0.55)
	_ring_mat.shader = RING_SHADER
	_ring_mat.set_shader_parameter("thickness", 0.12)
	_ring_mat.set_shader_parameter("fill", 0.1)
	ring.mesh = rq
	ring.material_override = _ring_mat
	ring.position.y = 0.03
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	_update_ring()

	_model = MeshInstance3D.new()
	_model.mesh = ShipModels.mesh(type)
	add_child(_model)
	add_child(_wake())

	var path_node := MeshInstance3D.new()
	path_node.top_level = true
	path_node.mesh = _path_mesh
	_path_mat.shader = PATH_SHADER
	path_node.material_override = _path_mat
	path_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(path_node)


func _wake() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.orientation = PlaneMesh.FACE_Y
	q.size = Vector2(0.22, 0.22)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _shadow_texture()
	mat.albedo_color = Color(1, 1, 1, 1)
	q.material = mat
	p.mesh = q
	p.amount = 22
	p.lifetime = 1.3
	p.local_coords = false
	p.position = Vector3(0, 0.02, half_len * 0.9)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = half_w * 0.5
	p.direction = Vector3(0, 0, 1)
	p.spread = 20.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.3
	p.scale_amount_min = 1.0 + half_w * 2.0
	p.scale_amount_max = 1.8 + half_w * 3.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(1, 1.6))
	p.scale_amount_curve = curve
	var ramp := Gradient.new()
	ramp.set_color(0, Color(30, 30, 30, 1.0))
	ramp.set_color(1, Color(30, 30, 30, 0.0))
	p.color_ramp = ramp
	return p


# --- Simulation --------------------------------------------------------------

func tick(dt: float, grid: LandGrid, current: Vector2, bounds: Rect2) -> void:
	if state != State.SAILING:
		return
	if type == VesselData.Type.SUBMARINE:
		_sub_timer -= dt
		if _sub_timer <= 0.0:
			set_submerged(not submerged)
			_sub_timer = randf_range(2.8, 3.6) if submerged else randf_range(4.5, 6.5)
	if not path.is_empty():
		_follow(speed * dt)
		if path.is_empty() and target:
			_dock()
			return
	else:
		_steer(dt, grid, bounds)
		pos += (heading * speed + (current if entered else Vector2.ZERO)) * dt
		if entered:
			_push_off_land(grid)
	if not entered and bounds.grow(-0.4).has_point(pos):
		entered = true
	_sync(dt)
	_draw_path()


func _follow(step: float) -> void:
	while step > 0.0 and not path.is_empty():
		var to := path[0] - pos
		var d := to.length()
		if d > 0.0001:
			heading = to / d
		if d <= step:
			pos = path[0]
			path.remove_at(0)
			step -= d
		else:
			pos += heading * step
			step = 0.0


func _steer(dt: float, grid: LandGrid, bounds: Rect2) -> void:
	if not entered:
		return
	var turn := 0.0
	var look := 1.0 + half_len
	var clear := half_w + 0.45
	if grid.distance(pos + heading * look) < clear or grid.distance(pos + heading * look * 0.5) < clear:
		var l := grid.distance(pos + heading.rotated(-0.7) * look)
		var r := grid.distance(pos + heading.rotated(0.7) * look)
		turn = -1.0 if l > r else 1.0
	var inner := bounds.grow(-half_len)
	var desired := heading
	if pos.x < inner.position.x and heading.x < 0.0 or pos.x > inner.end.x and heading.x > 0.0:
		desired.x = -desired.x
	if pos.y < inner.position.y and heading.y < 0.0 or pos.y > inner.end.y and heading.y > 0.0:
		desired.y = -desired.y
	if turn == 0.0 and desired != heading:
		turn = signf(heading.angle_to(desired))
	if turn != 0.0:
		heading = heading.rotated(turn * TURN_RATE * dt).normalized()


func _push_off_land(grid: LandGrid) -> void:
	var d := grid.distance(pos)
	if d >= half_w + 0.15:
		return
	var e := 0.25
	var g := Vector2(grid.distance(pos + Vector2(e, 0)) - grid.distance(pos - Vector2(e, 0)),
		grid.distance(pos + Vector2(0, e)) - grid.distance(pos - Vector2(0, e)))
	if g.length_squared() > 0.0:
		pos += g.normalized() * (half_w + 0.15 - d) * 0.5


func _sync(dt: float) -> void:
	position = Vector3(pos.x, 0.0, pos.y)
	var yaw := atan2(-heading.x, -heading.y)
	rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-dt * 10.0))
	if _model:
		var bob := sin(Time.get_ticks_msec() * 0.003 + pos.x) * 0.02
		_model.position.y = (-0.32 if submerged else 0.0) + bob


func _dock() -> void:
	state = State.DOCKING
	_clear_path_mesh()
	var t := create_tween().set_parallel()
	var inward := Vector3(-target.dir.x, 0, -target.dir.y) * 0.25
	t.tween_property(self, "position", position + inward, 0.5)
	t.tween_property(self, "scale", Vector3.ONE * 0.75, 0.5).set_delay(0.2)
	t.tween_property(_model, "position:y", -0.6, 0.5).set_delay(0.2)
	t.chain().tween_callback(func() -> void:
		state = State.GONE
		docked.emit(self))


# --- Paths & visuals ---------------------------------------------------------

func start_path() -> void:
	path.clear()
	target = null
	_update_path_color()


func add_point(p: Vector2) -> void:
	path.append(p)


func last_point() -> Vector2:
	return path[path.size() - 1] if not path.is_empty() else pos


func snap_to(p: Port) -> void:
	target = p
	path.append(p.approach())
	path.append(p.dock)
	_update_path_color()


func set_selected(on: bool) -> void:
	_selected = on
	_update_ring()


func set_warning(on: bool) -> void:
	if on != warning:
		warning = on
		_update_ring()


func set_submerged(on: bool) -> void:
	submerged = on
	_update_ring()


## Capsule (segment + radius) for collision tests.
func capsule() -> Array:
	var axis := heading * maxf(half_len - half_w, 0.0)
	return [pos - axis, pos + axis, half_w * 0.92]


func hit_distance(p: Vector2) -> float:
	var c := capsule()
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, c[0], c[1]))


func _update_ring() -> void:
	var c := VesselData.port_color(port)
	if warning:
		c = Color("ff2d2d")
	c.a = 0.35 if submerged else (1.0 if _selected or warning else 0.85)
	_ring_mat.set_shader_parameter("color", c)
	_ring_mat.set_shader_parameter("pulse_speed", 14.0 if warning else 0.0)
	_ring_mat.set_shader_parameter("fill", 0.35 if _selected else 0.1)


func _update_path_color() -> void:
	var c := VesselData.port_color(port)
	c.a = 1.0 if target else 0.7
	_path_mat.set_shader_parameter("color", c)


func _draw_path() -> void:
	_clear_path_mesh()
	if path.is_empty():
		return
	var pts := PackedVector2Array([pos])
	pts.append_array(path)
	_path_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var dist := 0.0
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var seg := b - a
		var l := seg.length()
		if l < 0.0001:
			continue
		var n := Vector2(-seg.y, seg.x) / l * PATH_WIDTH * 0.5
		var v := [Vector3(a.x + n.x, PATH_Y, a.y + n.y), Vector3(a.x - n.x, PATH_Y, a.y - n.y),
			Vector3(b.x - n.x, PATH_Y, b.y - n.y), Vector3(b.x + n.x, PATH_Y, b.y + n.y)]
		var u := [Vector2(dist, 0), Vector2(dist, 1), Vector2(dist + l, 1), Vector2(dist + l, 0)]
		for k in [0, 1, 2, 0, 2, 3]:
			_path_mesh.surface_set_uv(u[k])
			_path_mesh.surface_add_vertex(v[k])
		dist += l
	_path_mesh.surface_end()


func _clear_path_mesh() -> void:
	_path_mesh.clear_surfaces()
