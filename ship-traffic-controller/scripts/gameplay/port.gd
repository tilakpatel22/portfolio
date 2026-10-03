class_name Port
extends Node3D
## A dock on the coastline: pier, landmark building, target pad and icon badge.

const RING_SHADER := preload("res://assets/shaders/ring.gdshader")
const P := VesselData.Port
const SNAP_RADIUS := 1.6

var port_class := 0
var dock := Vector2.ZERO        # pier tip (XZ), where vessels berth
var dir := Vector2.UP           # outward normal, towards open water
var coast := Vector2.ZERO
var color := Color.WHITE
var _pad: MeshInstance3D
var _pad_mat := ShaderMaterial.new()
var _badge: Sprite3D


func setup(info: Dictionary) -> void:
	port_class = info["port"]
	dock = info["pos"]
	dir = info["dir"]
	coast = info["coast"]
	color = VesselData.port_color(port_class)
	_build_model()
	_build_pad()


## Point the vessel heads for before sliding into the berth.
func approach() -> Vector2:
	return dock + dir * 1.4


func accepts(vessel_port: int) -> bool:
	return VesselData.accepts(port_class, vessel_port)


func highlight(on: bool) -> void:
	_pad_mat.set_shader_parameter("pulse_speed", 9.0 if on else 3.0)
	_pad_mat.set_shader_parameter("fill", 0.4 if on else 0.18)


func celebrate() -> void:
	var t := create_tween()
	t.tween_property(_pad, "scale", Vector3.ONE * 1.5, 0.12)
	t.tween_property(_pad, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK)
	var b := create_tween()
	b.tween_property(_badge, "scale", Vector3.ONE * 1.35, 0.12)
	b.tween_property(_badge, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK)


func _build_pad() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * SNAP_RADIUS * 1.6
	quad.orientation = PlaneMesh.FACE_Y
	_pad_mat.shader = RING_SHADER
	_pad_mat.set_shader_parameter("color", color)
	_pad_mat.set_shader_parameter("thickness", 0.13)
	highlight(false)
	_pad = MeshInstance3D.new()
	_pad.mesh = quad
	_pad.material_override = _pad_mat
	_pad.position = Vector3(dock.x + dir.x * 0.35, 0.03, dock.y + dir.y * 0.35)
	_pad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_pad)

	_badge = Sprite3D.new()
	_badge.texture = load(VesselData.PORT_ICONS[port_class])
	_badge.pixel_size = 0.0075
	_badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_badge.no_depth_test = true
	_badge.render_priority = 2
	_badge.position = Vector3(coast.x - dir.x * 0.6, 1.5, coast.y - dir.y * 0.6)
	add_child(_badge)


func _build_model() -> void:
	var m := MeshBuilder.new()
	var yaw := atan2(-dir.x, -dir.y)
	# Pier from inland to the dock tip, built in local space where -Z faces the sea.
	m.xform = Transform3D(Basis(Vector3.UP, yaw), Vector3(coast.x, 0, coast.y))
	var tip := -(dock - coast).length()
	m.box(Vector3(0, 0.17, tip * 0.5 + 0.2), Vector3(0.5, 0.08, -tip + 0.6), Color("b07a48"), Color("c99360"))
	for z in [tip + 0.1, tip * 0.5]:
		for x in [-0.22, 0.22]:
			m.cylinder(Vector3(x, 0.05, z), 0.04, 0.3, Color("6e4a2c"), 5)
	var accent := color
	match port_class:
		P.MARINA:
			m.box(Vector3(0, 0.4, 0.9), Vector3(0.7, 0.3, 0.55), Color("fff3d6"), accent)
			m.box(Vector3(0.5, 0.17, tip * 0.4), Vector3(0.6, 0.06, 0.18), Color("c99360"))
			m.box(Vector3(-0.5, 0.17, tip * 0.7), Vector3(0.6, 0.06, 0.18), Color("c99360"))
		P.FISHING:
			m.box(Vector3(0, 0.42, 0.9), Vector3(0.75, 0.32, 0.6), Color("a0663c"), accent)
			m.cylinder(Vector3(0.55, 0.36, 0.7), 0.16, 0.18, Color("e6d3a3"), 7)
		P.PASSENGER:
			m.box(Vector3(0, 0.46, 1.0), Vector3(1.1, 0.38, 0.7), Color("f7f7f2"), accent)
			m.box(Vector3(0, 0.47, 0.64), Vector3(1.0, 0.1, 0.02), Color("2d4a66"))
		P.CARGO:
			m.box(Vector3(0, 1.0, 0.3), Vector3(0.12, 1.4, 0.12), accent)
			m.box(Vector3(0, 1.65, -0.1), Vector3(0.14, 0.12, 1.3), accent)
			m.box(Vector3(0.6, 0.38, 0.9), Vector3(0.36, 0.22, 0.6), Color("3fa7d6"))
			m.box(Vector3(-0.55, 0.38, 0.95), Vector3(0.36, 0.22, 0.6), Color("e94f37"))
			m.box(Vector3(0.6, 0.6, 0.9), Vector3(0.36, 0.22, 0.6), Color("59cd90"))
		P.FUEL:
			m.cylinder(Vector3(-0.35, 0.5, 0.9), 0.3, 0.45, Color("f2f2f2"), 10, accent)
			m.cylinder(Vector3(0.4, 0.45, 1.05), 0.24, 0.35, Color("f2f2f2"), 10, accent)
		P.NAVAL:
			m.box(Vector3(0, 0.42, 0.95), Vector3(1.0, 0.3, 0.6), Color("8794a1"), Color("a3aeb9"))
			m.cylinder(Vector3(0.6, 0.9, 0.5), 0.025, 1.2, Color("444444"))
			m.panel(Vector3(0.6, 1.45, 0.5), Vector3(0.6, 1.2, 0.5), Vector3(0.6, 1.32, 0.95), accent)
	var mi := MeshInstance3D.new()
	mi.mesh = m.commit()
	add_child(mi)
