class_name MeshBuilder
extends RefCounted
## Flat-shaded, vertex-coloured low-poly mesh builder (one draw call per model).

var st := SurfaceTool.new()
var xform := Transform3D.IDENTITY

static var _material: StandardMaterial3D


func _init() -> void:
	st.begin(Mesh.PRIMITIVE_TRIANGLES)


static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.vertex_color_is_srgb = true
		_material.roughness = 0.85
	return _material


func commit() -> ArrayMesh:
	var mesh := st.commit()
	if mesh.get_surface_count() > 0:
		mesh.surface_set_material(0, material())
	return mesh


## Triangle with flat normal oriented along `hint` (Godot front faces are clockwise).
func tri(a: Vector3, b: Vector3, c: Vector3, color: Color, hint: Vector3) -> void:
	a = xform * a
	b = xform * b
	c = xform * c
	hint = xform.basis * hint
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return
	if n.dot(hint) > 0.0:
		var t := b
		b = c
		c = t
		n = -n
	n = -n.normalized()
	st.set_color(color)
	st.set_normal(n)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color, hint: Vector3) -> void:
	tri(a, b, c, color, hint)
	tri(a, c, d, color, hint)


func box(center: Vector3, size: Vector3, color: Color, top_color := Color(0, 0, 0, 0)) -> void:
	var h := size * 0.5
	var top := color if top_color.a == 0.0 else top_color
	var p := func(x: float, y: float, z: float) -> Vector3: return center + Vector3(x * h.x, y * h.y, z * h.z)
	quad(p.call(-1, 1, -1), p.call(1, 1, -1), p.call(1, 1, 1), p.call(-1, 1, 1), top, Vector3.UP)
	quad(p.call(-1, -1, 1), p.call(1, -1, 1), p.call(1, 1, 1), p.call(-1, 1, 1), color, Vector3.BACK)
	quad(p.call(-1, -1, -1), p.call(1, -1, -1), p.call(1, 1, -1), p.call(-1, 1, -1), color, Vector3.FORWARD)
	quad(p.call(1, -1, -1), p.call(1, -1, 1), p.call(1, 1, 1), p.call(1, 1, -1), color, Vector3.RIGHT)
	quad(p.call(-1, -1, -1), p.call(-1, -1, 1), p.call(-1, 1, 1), p.call(-1, 1, -1), color, Vector3.LEFT)


## Vertical prism from a convex-or-not XZ outline (y0..y1), with optional top color.
func prism(outline: PackedVector2Array, y0: float, y1: float, side: Color, top: Color, bottom_scale := 1.0) -> void:
	var n := outline.size()
	var c := Vector2.ZERO
	for p in outline:
		c += p
	c /= n
	var idx := Geometry2D.triangulate_polygon(outline)
	for i in range(0, idx.size(), 3):
		var a := outline[idx[i]]
		var b := outline[idx[i + 1]]
		var d := outline[idx[i + 2]]
		tri(Vector3(a.x, y1, a.y), Vector3(b.x, y1, b.y), Vector3(d.x, y1, d.y), top, Vector3.UP)
	var ccw := _signed_area(outline) > 0.0
	for k in n:
		var a := outline[k]
		var b := outline[(k + 1) % n]
		var e := b - a
		var out2 := Vector2(e.y, -e.x) if ccw else Vector2(-e.y, e.x)
		var a0 := c + (a - c) * bottom_scale
		var b0 := c + (b - c) * bottom_scale
		quad(Vector3(a0.x, y0, a0.y), Vector3(b0.x, y0, b0.y), Vector3(b.x, y1, b.y), Vector3(a.x, y1, a.y),
			side, Vector3(out2.x, 0.0, out2.y))


func cylinder(center: Vector3, radius: float, height: float, color: Color, segments := 8, top_color := Color(0, 0, 0, 0), radius_top := -1.0) -> void:
	var rt := radius if radius_top < 0.0 else radius_top
	var top := color if top_color.a == 0.0 else top_color
	var y0 := center.y - height * 0.5
	var y1 := center.y + height * 0.5
	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var c0 := Vector3(center.x, y0, center.z)
		var c1 := Vector3(center.x, y1, center.z)
		quad(c0 + d0 * radius, c0 + d1 * radius, c1 + d1 * rt, c1 + d0 * rt, color, (d0 + d1).normalized())
		if rt > 0.001:
			tri(c1, c1 + d0 * rt, c1 + d1 * rt, top, Vector3.UP)


## Horizontal cylinder along local Z (pipes, hull of submarine).
func tube(center: Vector3, radius: float, length: float, color: Color, segments := 8) -> void:
	var saved := xform
	xform = xform * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), center) * Transform3D(Basis.IDENTITY, -center)
	cylinder(center, radius, length, color, segments)
	xform = saved


func sphere(center: Vector3, radius: Vector3, color: Color, rings := 4, segments := 8) -> void:
	for r in rings:
		var t0 := PI * r / rings
		var t1 := PI * (r + 1) / rings
		for s in segments:
			var p0 := TAU * s / segments
			var p1 := TAU * (s + 1) / segments
			var v := func(t: float, p: float) -> Vector3:
				return center + Vector3(sin(t) * cos(p) * radius.x, cos(t) * radius.y, sin(t) * sin(p) * radius.z)
			var a: Vector3 = v.call(t0, p0)
			var b: Vector3 = v.call(t0, p1)
			var c: Vector3 = v.call(t1, p1)
			var d: Vector3 = v.call(t1, p0)
			var hint := ((a + b + c + d) * 0.25 - center)
			if r > 0:
				tri(a, b, c, color, hint)
			if r < rings - 1:
				tri(a, c, d, color, hint)


## Thin double-sided triangle (sails, flags).
func panel(a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var n := (b - a).cross(c - a).normalized()
	tri(a, b, c, color, n)
	tri(a, b, c, color, -n)


static func _signed_area(poly: PackedVector2Array) -> float:
	var s := 0.0
	var n := poly.size()
	for i in n:
		var a := poly[i]
		var b := poly[(i + 1) % n]
		s += a.x * b.y - b.x * a.y
	return s * 0.5
