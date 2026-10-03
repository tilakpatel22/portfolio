class_name LandGrid
extends RefCounted
## Rasterized land mask + distance-to-land field on the XZ plane (Vector2(x, z)).

const CELL := 0.25
const ORIGIN := Vector2(-24.0, -15.0)
const W := 192
const H := 120
const MAX_DIST := 8.0

var land := PackedByteArray()
var dist := PackedFloat32Array()


func _init() -> void:
	land.resize(W * H)
	dist.resize(W * H)


func build(polygons: Array[PackedVector2Array]) -> void:
	land.fill(0)
	for poly in polygons:
		_raster(poly)
	_distance_field(polygons)


func _raster(poly: PackedVector2Array) -> void:
	var r := _bounds(poly)
	var c0 := _cell(r.position)
	var c1 := _cell(r.end)
	for y in range(maxi(c0.y, 0), mini(c1.y + 1, H)):
		for x in range(maxi(c0.x, 0), mini(c1.x + 1, W)):
			if Geometry2D.is_point_in_polygon(_center(x, y), poly):
				land[y * W + x] = 1


func _distance_field(polygons: Array[PackedVector2Array]) -> void:
	var inf := 1e9
	for i in W * H:
		dist[i] = 0.0 if land[i] else inf
	# Exact distances in a band around the coast, chamfer propagation elsewhere.
	for y in H:
		for x in W:
			var i := y * W + x
			if land[i] or not _near_land(x, y, 3):
				continue
			var p := _center(x, y)
			var best := inf
			for poly in polygons:
				if not _bounds(poly).grow(1.0).has_point(p):
					continue
				var n := poly.size()
				for k in n:
					var q := Geometry2D.get_closest_point_to_segment(p, poly[k], poly[(k + 1) % n])
					best = minf(best, p.distance_to(q))
			dist[i] = best
	var d1 := CELL
	var d2 := CELL * 1.41421
	for y in H:
		for x in W:
			var i := y * W + x
			var v := dist[i]
			if x > 0: v = minf(v, dist[i - 1] + d1)
			if y > 0:
				v = minf(v, dist[i - W] + d1)
				if x > 0: v = minf(v, dist[i - W - 1] + d2)
				if x < W - 1: v = minf(v, dist[i - W + 1] + d2)
			dist[i] = v
	for y in range(H - 1, -1, -1):
		for x in range(W - 1, -1, -1):
			var i := y * W + x
			var v := dist[i]
			if x < W - 1: v = minf(v, dist[i + 1] + d1)
			if y < H - 1:
				v = minf(v, dist[i + W] + d1)
				if x < W - 1: v = minf(v, dist[i + W + 1] + d2)
				if x > 0: v = minf(v, dist[i + W - 1] + d2)
			dist[i] = v


func _near_land(x: int, y: int, r: int) -> bool:
	for dy in range(-r, r + 1):
		var yy := y + dy
		if yy < 0 or yy >= H:
			continue
		for dx in range(-r, r + 1):
			var xx := x + dx
			if xx >= 0 and xx < W and land[yy * W + xx]:
				return true
	return false


func is_land(p: Vector2) -> bool:
	var c := _cell(p)
	if c.x < 0 or c.y < 0 or c.x >= W or c.y >= H:
		return false
	return land[c.y * W + c.x] == 1


## Distance to nearest land (0 on land, MAX_DIST outside the grid).
func distance(p: Vector2) -> float:
	var c := _cell(p)
	if c.x < 0 or c.y < 0 or c.x >= W or c.y >= H:
		return MAX_DIST
	return dist[c.y * W + c.x]


func segment_clear(a: Vector2, b: Vector2, clearance: float) -> bool:
	var steps := maxi(1, ceili(a.distance_to(b) / (CELL * 0.5)))
	for i in steps + 1:
		if distance(a.lerp(b, float(i) / steps)) < clearance:
			return false
	return true


## Flood fill over water cells with the given clearance. Returns visited mask.
func flood(from: Vector2, clearance: float) -> PackedByteArray:
	var seen := PackedByteArray()
	seen.resize(W * H)
	var s := _cell(from)
	if s.x < 0 or s.y < 0 or s.x >= W or s.y >= H or dist[s.y * W + s.x] < clearance:
		return seen
	var queue := PackedInt32Array([s.y * W + s.x])
	seen[s.y * W + s.x] = 1
	var head := 0
	while head < queue.size():
		var i := queue[head]
		head += 1
		var x := i % W
		var y := i / W
		for n in [i - 1 if x > 0 else -1, i + 1 if x < W - 1 else -1, i - W if y > 0 else -1, i + W if y < H - 1 else -1]:
			if n >= 0 and not seen[n] and dist[n] >= clearance:
				seen[n] = 1
				queue.append(n)
	return seen


func reached(mask: PackedByteArray, p: Vector2) -> bool:
	var c := _cell(p)
	if c.x < 0 or c.y < 0 or c.x >= W or c.y >= H:
		return false
	return mask[c.y * W + c.x] == 1


## L8 texture of distance-to-land for the water shader (normalized by MAX_DIST).
func to_image() -> Image:
	var bytes := PackedByteArray()
	bytes.resize(W * H)
	for i in W * H:
		bytes[i] = int(clampf(dist[i] / MAX_DIST, 0.0, 1.0) * 255.0)
	return Image.create_from_data(W, H, false, Image.FORMAT_L8, bytes)


static func world_rect() -> Rect2:
	return Rect2(ORIGIN, Vector2(W, H) * CELL)


func _cell(p: Vector2) -> Vector2i:
	return Vector2i(floori((p.x - ORIGIN.x) / CELL), floori((p.y - ORIGIN.y) / CELL))


func _center(x: int, y: int) -> Vector2:
	return ORIGIN + Vector2(x + 0.5, y + 0.5) * CELL


static func _bounds(poly: PackedVector2Array) -> Rect2:
	var r := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		r = r.expand(p)
	return r
