class_name LevelGenerator
extends RefCounted
## Deterministic, endless level generator. See DESIGN.md for the algorithm.

const PF := LevelData.PLAYFIELD
const MAX_ATTEMPTS := 16
const LANE_CLEARANCE := 0.55


## Smooth ramp + 5-level tension wave (peak every 5th level, breather after).
static func difficulty(level: int) -> float:
	var base := 1.0 - exp(-float(level - 1) / 22.0)
	var wave: float = [0.0, 0.04, 0.08, 0.12, 0.18][(level - 1) % 5]
	return clampf(base * 0.82 + wave, 0.0, 1.0)


static func is_peak(level: int) -> bool:
	return level >= 5 and level % 5 == 0


static func generate(level: int) -> LevelData:
	level = maxi(level, 1)
	for attempt in MAX_ATTEMPTS:
		var data := _try(level, attempt, false)
		if data:
			data.attempts = attempt + 1
			return data
	var fallback := _try(level, 0, true)
	fallback.attempts = -1
	return fallback


static func _try(level: int, attempt: int, fallback: bool) -> LevelData:
	var rng := RandomNumberGenerator.new()
	var d := LevelData.new()
	d.level = level
	d.rng_seed = hash(level * 7919 + attempt * 104729 + 1337)
	rng.seed = d.rng_seed
	d.difficulty = difficulty(level)
	_params(d, rng)
	_pool(d, rng)
	d.archetype = "island" if fallback else _pick_archetype(d, rng)
	_build_land(d, rng)
	d.grid = LandGrid.new()
	d.grid.build(d.islands)
	if not _place_gates(d, rng) or not _place_ports(d, rng, fallback):
		return null
	if not fallback and not _validate(d):
		return null
	return d


# --- 1-2. Difficulty parameters ------------------------------------------------

static func _params(d: LevelData, rng: RandomNumberGenerator) -> void:
	var L := d.level
	var dd := d.difficulty
	var endless := maxi(0, L - 50)
	d.target = mini(30, 5 + int((L - 1) * 0.6))
	d.max_active = mini(10, 2 + roundi(dd * 6.0) + endless / 25)
	d.spawn_interval = lerpf(6.5, 2.4, dd) * rng.randf_range(0.85, 1.15)
	d.speed_mult = minf(1.6, lerpf(0.9, 1.3, dd) + endless * 0.003)
	d.pair_chance = clampf((dd - 0.35) * 0.4, 0.0, 0.3)
	if is_peak(L):
		d.modifiers.append("RUSH")
		d.target = ceili(d.target * 1.15)
		d.spawn_interval *= 0.75
		d.pair_chance += 0.2
	if L >= 12 and rng.randf() < 0.3:
		d.modifiers.append("FOG")
		d.warn_time = 0.8
	if L >= 16 and rng.randf() < 0.3:
		d.modifiers.append("CURRENT")
		d.current = Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.25, 0.4)


static func _pool(d: LevelData, rng: RandomNumberGenerator) -> void:
	var unlocked := VesselData.unlocked_types(d.level)
	d.new_type = VesselData.type_unlocked_at(d.level) if d.level > 1 else -1
	var size := mini(unlocked.size(), 2 + int(d.difficulty * 4.0))
	var chosen: Array[int] = []
	if d.new_type >= 0:
		chosen.append(d.new_type)
	var rest: Array[int] = []
	rest.assign(unlocked.filter(func(t: int) -> bool: return not chosen.has(t)))
	while chosen.size() < size and not rest.is_empty():
		# Newer vessels are slightly favoured so the fleet keeps changing.
		var weights := PackedFloat32Array()
		for t in rest:
			weights.append(1.0 + float(VesselData.TYPES[t]["unlock"]) / float(d.level))
		var pick := rest[rng.rand_weighted(weights)]
		chosen.append(pick)
		rest.erase(pick)
	for t in chosen:
		var w: float = VesselData.TYPES[t]["weight"] * (2.5 if t == d.new_type else 1.0)
		d.pool.append({"type": t, "weight": w})


# --- 3. Map -----------------------------------------------------------------

static func _pick_archetype(d: LevelData, rng: RandomNumberGenerator) -> String:
	if d.level <= 2:
		return "island"
	var names := ["island", "archipelago", "coast", "strait"]
	var w := PackedFloat32Array([1.0, 1.5 + d.difficulty * 2.0, 1.4 if d.level >= 4 else 0.0,
		d.difficulty * 2.2 if d.level >= 10 else 0.0])
	return names[rng.rand_weighted(w)]


static func _build_land(d: LevelData, rng: RandomNumberGenerator) -> void:
	match d.archetype:
		"island":
			var big := rng.randf_range(3.0, 3.6)
			_add(d, _blob(rng, Vector2(rng.randf_range(-2.0, 2.0), rng.randf_range(-1.2, 1.2)), big, 48), "island")
		"archipelago":
			_scatter_islands(d, rng, 2 + mini(2, int(d.difficulty * 2.5)), 1.6, 2.7, PF)
		"coast":
			var edge: String = ["top", "bottom", "left", "right"][rng.rand_weighted(PackedFloat32Array([2, 2, 1, 1]))]
			var depth := rng.randf_range(2.0, 3.2)
			_add(d, _mainland(rng, edge, depth), "mainland")
			_scatter_islands(d, rng, rng.randi_range(0, 2), 1.3, 2.2, _shrink_edge(PF, edge, depth + 1.8))
		"strait":
			var d1 := rng.randf_range(1.8, 2.8)
			var d2 := rng.randf_range(1.8, 2.8)
			_add(d, _mainland(rng, "top", d1), "mainland")
			_add(d, _mainland(rng, "bottom", d2), "mainland")
			if rng.randf() < 0.6:
				var r := _shrink_edge(_shrink_edge(PF, "top", d1 + 1.8), "bottom", d2 + 1.8)
				_scatter_islands(d, rng, 1, 1.1, 1.7, r)
	_add_rocks(d, rng)


static func _add(d: LevelData, poly: PackedVector2Array, kind: String) -> void:
	d.islands.append(poly)
	d.island_kinds.append(kind)


static func _scatter_islands(d: LevelData, rng: RandomNumberGenerator, count: int, rmin: float, rmax: float, area: Rect2) -> void:
	var placed: Array[Vector3] = []   # x, z, radius
	for _i in count:
		for _try_i in 40:
			var r := rng.randf_range(rmin, rmax)
			var inner := area.grow(-(r * 1.3 + 1.6))
			if inner.size.x <= 0.0 or inner.size.y <= 0.0:
				break
			var c := Vector2(rng.randf_range(inner.position.x, inner.end.x), rng.randf_range(inner.position.y, inner.end.y))
			var ok := true
			for q in placed:
				if c.distance_to(Vector2(q.x, q.y)) < (r + q.z) * 1.3 + 2.8:
					ok = false
					break
			if ok:
				placed.append(Vector3(c.x, c.y, r))
				_add(d, _blob(rng, c, r, 40), "island")
				break


static func _add_rocks(d: LevelData, rng: RandomNumberGenerator) -> void:
	if d.level < 8:
		return
	var count := roundi(mini(6, (d.level - 4) / 4) * rng.randf_range(0.5, 1.0))
	var solid := d.islands.duplicate()
	for _i in count:
		for _t in 30:
			var r := rng.randf_range(0.3, 0.55)
			var c := Vector2(rng.randf_range(PF.position.x + 3.0, PF.end.x - 3.0), rng.randf_range(PF.position.y + 2.5, PF.end.y - 2.5))
			var ok := true
			for poly in solid:
				if _poly_distance(c, poly) < r + 2.4:
					ok = false
					break
			if ok:
				var rock := _blob(rng, c, r, 9, 1.6)
				solid.append(rock)
				_add(d, rock, "rock")
				break


## Organic blob: r(θ) = R·(1 + Σ a_k·sin(kθ + φ_k)), then stretched and rotated.
static func _blob(rng: RandomNumberGenerator, center: Vector2, radius: float, points: int, rough := 1.0) -> PackedVector2Array:
	var ph := [rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU]
	var amp := [rng.randf_range(0.08, 0.2) * rough, rng.randf_range(0.04, 0.12) * rough, rng.randf_range(0.02, 0.06) * rough]
	var stretch := Vector2(rng.randf_range(0.95, 1.3), rng.randf_range(0.75, 1.0))
	var rot := rng.randf() * TAU
	var poly := PackedVector2Array()
	for i in points:
		var a := TAU * i / points
		var r: float = radius * (1.0 + amp[0] * sin(2.0 * a + ph[0]) + amp[1] * sin(3.0 * a + ph[1]) + amp[2] * sin(5.0 * a + ph[2]))
		poly.append(center + (Vector2(cos(a) * stretch.x, sin(a) * stretch.y) * r).rotated(rot))
	return poly


## Wavy coastline along a playfield edge, closed far outside the view.
static func _mainland(rng: RandomNumberGenerator, edge: String, depth: float) -> PackedVector2Array:
	var ph := [rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU]
	var half := 27.0 if edge in ["top", "bottom"] else 17.0
	var pts := PackedVector2Array()
	var u := -half
	while u <= half + 0.01:
		var v := depth + 0.8 * sin(0.33 * u + ph[0]) + 0.45 * sin(0.77 * u + ph[1]) + 0.2 * sin(1.6 * u + ph[2])
		pts.append(_edge_point(edge, u, v))
		u += 0.75
	pts.append(_edge_point(edge, half, -9.0))
	pts.append(_edge_point(edge, -half, -9.0))
	return pts


static func _edge_point(edge: String, u: float, v: float) -> Vector2:
	match edge:
		"top": return Vector2(u, PF.position.y + v)
		"bottom": return Vector2(u, PF.end.y - v)
		"left": return Vector2(PF.position.x + v, u)
	return Vector2(PF.end.x - v, u)


static func _shrink_edge(r: Rect2, edge: String, amount: float) -> Rect2:
	match edge:
		"top": return r.grow_individual(0, -amount, 0, 0)
		"bottom": return r.grow_individual(0, 0, 0, -amount)
		"left": return r.grow_individual(-amount, 0, 0, 0)
	return r.grow_individual(0, 0, -amount, 0)


static func _poly_distance(p: Vector2, poly: PackedVector2Array) -> float:
	if Geometry2D.is_point_in_polygon(p, poly):
		return 0.0
	var best := INF
	var n := poly.size()
	for k in n:
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, poly[k], poly[(k + 1) % n])))
	return best


# --- Sea lanes (gates) ------------------------------------------------------

static func _place_gates(d: LevelData, rng: RandomNumberGenerator) -> bool:
	var count := 2 + int(d.difficulty * 4.0)
	var cands: Array[Dictionary] = []
	for edge in ["top", "bottom", "left", "right"]:
		var horizontal: bool = edge in ["top", "bottom"]
		var length := PF.size.x if horizontal else PF.size.y
		var u := 1.8
		while u <= length - 1.8:
			var p: Vector2
			var inward: Vector2
			match edge:
				"top":
					p = Vector2(PF.position.x + u, PF.position.y)
					inward = Vector2.DOWN
				"bottom":
					p = Vector2(PF.position.x + u, PF.end.y)
					inward = Vector2.UP
				"left":
					p = Vector2(PF.position.x, PF.position.y + u)
					inward = Vector2.RIGHT
				_:
					p = Vector2(PF.end.x, PF.position.y + u)
					inward = Vector2.LEFT
			if _lane_open(d.grid, p, inward):
				cands.append({"pos": p, "dir": inward})
			u += 1.0
	if cands.size() < 2:
		return false
	var chosen: Array[Dictionary] = [cands[rng.randi() % cands.size()]]
	while chosen.size() < count:
		var best := {}
		var best_d := 0.0
		for c in cands:
			var md := INF
			for g in chosen:
				md = minf(md, (c["pos"] as Vector2).distance_to(g["pos"]))
			md += rng.randf() * 1.5
			if md > best_d:
				best_d = md
				best = c
		if best_d < 7.0:
			break
		chosen.append(best)
	for g in chosen:
		var to_center: Vector2 = (PF.get_center() - g["pos"]).normalized()
		g["dir"] = ((g["dir"] as Vector2) * 0.75 + to_center * 0.25).normalized().rotated(rng.randf_range(-0.2, 0.2))
	d.gates = chosen
	return chosen.size() >= 2


static func _lane_open(grid: LandGrid, p: Vector2, inward: Vector2) -> bool:
	for t in [-6.0, -4.5, -3.0]:
		if grid.distance(p + inward * t) < 0.8:
			return false
	for t in [-1.5, -0.5, 0.5, 1.5, 2.5, 3.5, 4.5]:
		if grid.distance(p + inward * t) < 1.4:
			return false
	return true


# --- 4. Ports ---------------------------------------------------------------

static func _place_ports(d: LevelData, rng: RandomNumberGenerator, fallback: bool) -> bool:
	var classes: Array[int] = []
	for e in d.pool:
		var pc := VesselData.port_of(e["type"])
		if pc != VesselData.Port.ANY and not classes.has(pc):
			classes.append(pc)
	var want := maxi(classes.size(), mini(6, 2 + d.level / 6))
	var cands: Array[Dictionary] = []
	for i in d.islands.size():
		if d.island_kinds[i] == "rock":
			continue
		var poly := d.islands[i]
		var n := poly.size()
		for k in n:
			var coast := poly[k]
			var tangent := (poly[(k + 1) % n] - poly[(k - 1 + n) % n]).normalized()
			var normal := Vector2(-tangent.y, tangent.x)
			if d.grid.is_land(coast + normal * 0.6):
				normal = -normal
			if d.grid.is_land(coast + normal * 0.6):
				continue
			var dock := coast + normal * 1.0
			var approach := dock + normal * 1.6
			if not PF.grow(-1.2).has_point(coast) or not PF.grow(-1.6).has_point(approach):
				continue
			if d.grid.distance(dock) < 0.6 or d.grid.distance(approach) < 1.3:
				continue
			var near_gate := false
			for g in d.gates:
				if (g["pos"] as Vector2).distance_to(dock) < 5.0:
					near_gate = true
					break
			if not near_gate:
				cands.append({"pos": dock, "dir": normal, "coast": coast})
	var spacing := 3.0 if fallback else 4.0
	var chosen: Array[Dictionary] = []
	while chosen.size() < want:
		var best := {}
		var best_score := -1.0
		for c in cands:
			var md := 100.0
			for p in chosen:
				md = minf(md, (c["pos"] as Vector2).distance_to(p["pos"]))
			if md < spacing:
				continue
			var score := minf(md, 12.0) + rng.randf() * 3.0
			if score > best_score:
				best_score = score
				best = c
		if best.is_empty():
			break
		chosen.append(best)
	if chosen.size() < classes.size():
		if not fallback or chosen.is_empty():
			return false
		classes.resize(chosen.size())
		d.pool.assign(d.pool.filter(func(e: Dictionary) -> bool:
			var pc := VesselData.port_of(e["type"])
			return pc == VesselData.Port.ANY or classes.has(pc)))
	_shuffle(classes, rng)
	var class_w := PackedFloat32Array()
	for c in classes:
		var w := 0.0
		for e in d.pool:
			if VesselData.port_of(e["type"]) == c:
				w += e["weight"]
		class_w.append(w)
	for i in chosen.size():
		chosen[i]["port"] = classes[i] if i < classes.size() else classes[rng.rand_weighted(class_w)]
	d.ports = chosen
	return true


# --- 6. Fairness ------------------------------------------------------------

static func _validate(d: LevelData) -> bool:
	for g in d.gates:
		var mask := d.grid.flood((g["pos"] as Vector2) + (g["dir"] as Vector2) * 2.0, LANE_CLEARANCE)
		for p in d.ports:
			if not d.grid.reached(mask, (p["pos"] as Vector2) + (p["dir"] as Vector2) * 1.2):
				return false
	return true


static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = t
