class_name World
extends Node3D
## Builds the visual map (water, islands, trees, rocks, ports) for a LevelData.

const WATER_SHADER := preload("res://assets/shaders/water.gdshader")

const SAND := Color("f5d9a0")
const SAND_SIDE := Color("dcb276")
const GRASS := Color("6fbf4c")
const GRASS_SIDE := Color("5aa543")
const HILL := Color("86cf5e")
const ROCK := Color("4f5963")
const ROCK_TOP := Color("6d7883")

var water_mat := ShaderMaterial.new()
var ports: Array[Port] = []
var _level_root: Node3D


func _ready() -> void:
	water_mat.shader = WATER_SHADER
	var r := LandGrid.world_rect()
	water_mat.set_shader_parameter("grid_rect", Vector4(r.position.x, r.position.y, r.size.x, r.size.y))
	water_mat.set_shader_parameter("max_dist", LandGrid.MAX_DIST)
	var plane := PlaneMesh.new()
	plane.size = Vector2(90, 70)
	var water := MeshInstance3D.new()
	water.mesh = plane
	water.material_override = water_mat
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)


func build(data: LevelData) -> void:
	if _level_root:
		_level_root.queue_free()
	ports.clear()
	_level_root = Node3D.new()
	add_child(_level_root)
	water_mat.set_shader_parameter("dist_tex", ImageTexture.create_from_image(data.grid.to_image()))
	water_mat.set_shader_parameter("current", data.current)
	water_mat.set_shader_parameter("fog", 1.0 if data.has_mod("FOG") else 0.0)

	var rng := RandomNumberGenerator.new()
	rng.seed = data.rng_seed
	var m := MeshBuilder.new()
	var tree_spots: Array[Vector3] = []
	var keep_clear: Array[Vector2] = []
	for p in data.ports:
		keep_clear.append(p["coast"])
	for i in data.islands.size():
		var poly := data.islands[i]
		if data.island_kinds[i] == "rock":
			_rock(m, poly)
		else:
			_island(m, poly)
			_collect_trees(poly, rng, keep_clear, tree_spots)
	var land := MeshInstance3D.new()
	land.mesh = m.commit()
	_level_root.add_child(land)
	_plant_trees(tree_spots, rng)
	for info in data.ports:
		var port := Port.new()
		_level_root.add_child(port)
		port.setup(info)
		ports.append(port)


func _island(m: MeshBuilder, poly: PackedVector2Array) -> void:
	m.prism(poly, -0.25, 0.12, SAND_SIDE, SAND, 1.06)
	# Shrinking a simple polygon never creates holes, so every result is solid.
	for g in Geometry2D.offset_polygon(poly, -0.5):
		m.prism(g, 0.1, 0.28, GRASS_SIDE, GRASS)
		for h in Geometry2D.offset_polygon(g, -1.4):
			if absf(MeshBuilder._signed_area(h)) > 3.0:
				m.prism(h, 0.26, 0.44, GRASS_SIDE, HILL)


func _rock(m: MeshBuilder, poly: PackedVector2Array) -> void:
	m.prism(poly, -0.2, 0.22, ROCK, ROCK_TOP, 1.1)
	for g in Geometry2D.offset_polygon(poly, -0.12):
		m.prism(g, 0.2, 0.34, ROCK, ROCK_TOP)


func _collect_trees(poly: PackedVector2Array, rng: RandomNumberGenerator, keep_clear: Array[Vector2], out: Array[Vector3]) -> void:
	var view := LevelData.PLAYFIELD.grow(5.0)
	for inner in Geometry2D.offset_polygon(poly, -0.95):
		var bounds := Rect2(inner[0], Vector2.ZERO)
		for p in inner:
			bounds = bounds.expand(p)
		bounds = bounds.intersection(view)
		if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
			continue
		var count := mini(60, int(bounds.get_area() * 0.9))
		for _i in count:
			var p := Vector2(rng.randf_range(bounds.position.x, bounds.end.x), rng.randf_range(bounds.position.y, bounds.end.y))
			if not Geometry2D.is_point_in_polygon(p, inner):
				continue
			var ok := true
			for c in keep_clear:
				if c.distance_to(p) < 1.9:
					ok = false
					break
			for t in out:
				if Vector2(t.x, t.z).distance_to(p) < 0.55:
					ok = false
					break
			if ok:
				out.append(Vector3(p.x, 0.28, p.y))


func _plant_trees(spots: Array[Vector3], rng: RandomNumberGenerator) -> void:
	if spots.is_empty():
		return
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.05
	trunk.bottom_radius = 0.07
	trunk.height = 0.35
	trunk.radial_segments = 5
	trunk.rings = 1
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color("8a5a35")
	trunk.material = trunk_mat
	var crown := SphereMesh.new()
	crown.radius = 0.36
	crown.height = 0.62
	crown.radial_segments = 8
	crown.rings = 4
	var crown_mat := StandardMaterial3D.new()
	crown_mat.vertex_color_use_as_albedo = true
	crown_mat.vertex_color_is_srgb = true
	crown_mat.roughness = 0.9
	crown.material = crown_mat
	var greens := [Color("3f9d4b"), Color("4fb05a"), Color("368a43"), Color("5cbf62")]
	var mm_trunk := _multimesh(trunk, spots.size(), false)
	var mm_crown := _multimesh(crown, spots.size(), true)
	for i in spots.size():
		var s := rng.randf_range(0.75, 1.25)
		var b := Basis.from_scale(Vector3.ONE * s).rotated(Vector3.UP, rng.randf() * TAU)
		mm_trunk.multimesh.set_instance_transform(i, Transform3D(b, spots[i] + Vector3(0, 0.17 * s, 0)))
		mm_crown.multimesh.set_instance_transform(i, Transform3D(b, spots[i] + Vector3(0, 0.55 * s, 0)))
		mm_crown.multimesh.set_instance_color(i, greens[rng.randi() % greens.size()])


func _multimesh(mesh: Mesh, count: int, colors: bool) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors
	mm.mesh = mesh
	mm.instance_count = count
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	_level_root.add_child(inst)
	return inst
