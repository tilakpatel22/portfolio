class_name Game
extends Node3D
## Runs a level: spawning director, touch path drawing, collisions, docking, win/lose.

signal progress_changed(docked: int, target: int)
signal level_won
signal level_lost
signal spawn_warning(gate_pos: Vector2, gate_dir: Vector2, color: Color, duration: float)
signal first_vessel(vessel: Vessel, port: Port)
signal calm_changed(active: bool, charge: float)
signal crashed
signal lifebuoy_used

enum Mode { ATTRACT, PLAY, OVER }

const PICK_RADIUS := 1.0
const POINT_STEP := 0.3
const PATH_CLEARANCE := 0.3
const MAX_PATH_POINTS := 500
const CALM_DURATION := 4.0
const CALM_COOLDOWN := 18.0
const CALM_FACTOR := 0.35

var camera: Camera3D
var world: World
var data: LevelData
var mode := Mode.ATTRACT
var docked := 0
var visible_rect := LevelData.PLAYFIELD
var vessels: Array[Vessel] = []
var close_calls := 0
var calm_left := 0.0
var calm_cool := 0.0
var revive_used := false
var _crashed: Array[Vessel] = []

var _rng := RandomNumberGenerator.new()
var _spawn_timer := 0.0
var _time := 0.0
var _gate_used := {}
var _last_gate := -1
var _pending := 0
var _touches := {}
var _tutorial_sent := false


func _ready() -> void:
	world = World.new()
	add_child(world)


func load_level(level: int, attract := false) -> void:
	for v in vessels:
		v.queue_free()
	vessels.clear()
	_touches.clear()
	data = LevelGenerator.generate(level)
	world.build(data)
	_rng.seed = data.rng_seed
	docked = 0
	_time = 0.0
	_pending = 0
	_gate_used.clear()
	_last_gate = -1
	_tutorial_sent = false
	close_calls = 0
	revive_used = false
	_crashed.clear()
	calm_left = 0.0
	calm_cool = 0.0
	calm_changed.emit(false, 1.0)
	Audio.set_calm(false)
	Audio.set_tension(0.0)
	mode = Mode.ATTRACT if attract else Mode.PLAY
	_spawn_timer = 0.5 if attract else 1.2
	progress_changed.emit(docked, data.target)


func max_active() -> int:
	return 4 if mode == Mode.ATTRACT else data.max_active


func _process(dt: float) -> void:
	if data == null or mode == Mode.OVER:
		return
	var sim := _calm_step(dt)
	_time += sim
	_director(sim)
	for v in vessels:
		v.tick(sim, data.grid, data.current, visible_rect.intersection(LevelData.PLAYFIELD.grow(1.0)))
	if mode == Mode.PLAY:
		_check_collisions()
		_tutorial()
	else:
		_cull_attract()


# --- Calm Waters: tap to slow every ship for a few seconds, then it recharges ---

func activate_calm() -> bool:
	if mode != Mode.PLAY or calm_left > 0.0 or calm_cool > 0.0:
		return false
	calm_left = CALM_DURATION
	Audio.play("whoosh")
	Audio.set_calm(true)
	calm_changed.emit(true, 0.0)
	return true


func _calm_step(dt: float) -> float:
	if calm_left > 0.0:
		calm_left -= dt
		if calm_left <= 0.0:
			calm_cool = CALM_COOLDOWN
			Audio.set_calm(false)
			calm_changed.emit(false, 0.0)
		return dt * CALM_FACTOR
	if calm_cool > 0.0:
		calm_cool = maxf(calm_cool - dt, 0.0)
		calm_changed.emit(false, 1.0 - calm_cool / CALM_COOLDOWN)
	return dt


func stars() -> int:
	return 3 if close_calls <= 4 else (2 if close_calls <= 10 else 1)


# --- Spawning director --------------------------------------------------------

func _director(dt: float) -> void:
	_spawn_timer -= dt
	if _spawn_timer > 0.0:
		return
	var interval := 2.8 if mode == Mode.ATTRACT else data.spawn_interval
	_spawn_timer = interval * _rng.randf_range(0.85, 1.15)
	var free_slots := max_active() - vessels.size() - _pending
	if free_slots <= 0:
		_spawn_timer = 0.6
		return
	var count := 2 if free_slots >= 2 and _rng.randf() < data.pair_chance and mode == Mode.PLAY else 1
	var used: Array[int] = []
	for _i in count:
		var gate := _pick_gate(used)
		if gate < 0:
			_spawn_timer = 0.6
			return
		used.append(gate)
		_queue_spawn(gate, _pick_type())


func _pick_type() -> int:
	var w := PackedFloat32Array()
	for e in data.pool:
		w.append(e["weight"])
	return data.pool[_rng.rand_weighted(w)]["type"]


func _pick_gate(exclude: Array[int]) -> int:
	var best := -1
	var best_score := -INF
	for i in data.gates.size():
		if exclude.has(i):
			continue
		var g: Vector2 = data.gates[i]["pos"]
		var blocked := false
		for v in vessels:
			if v.pos.distance_to(g) < 4.5:
				blocked = true
				break
		if blocked:
			continue
		var score := minf(_time - _gate_used.get(i, -30.0), 30.0) + _rng.randf() * 6.0
		if i == _last_gate:
			score -= 12.0
		if score > best_score:
			best_score = score
			best = i
	return best


func _queue_spawn(gate: int, type: int) -> void:
	_gate_used[gate] = _time + 99.0
	_last_gate = gate
	_pending += 1
	var g: Dictionary = data.gates[gate]
	var warn := 0.0 if mode == Mode.ATTRACT else data.warn_time
	if warn > 0.0:
		spawn_warning.emit(g["pos"], g["dir"], VesselData.port_color(VesselData.port_of(type)), warn)
		Audio.play("warning")
	await get_tree().create_timer(warn, false).timeout
	_pending -= 1
	_gate_used[gate] = _time
	if mode == Mode.OVER or data == null:
		return
	_spawn(type, g)


func _spawn(type: int, g: Dictionary) -> Vessel:
	var v := Vessel.new()
	var dir: Vector2 = g["dir"]
	var info := VesselData.info(type)
	var start: Vector2 = g["pos"]
	var view := visible_rect.grow(info["length"] * 0.5 + 0.4)
	var k := 0.0
	while view.has_point(start - dir * k) and k < 14.0:
		k += 0.5
	add_child(v)
	v.setup(type, start - dir * k, dir, data.speed_mult if mode == Mode.PLAY else 1.0)
	v.docked.connect(_on_docked)
	vessels.append(v)
	if mode == Mode.PLAY:
		var big := type in [VesselData.Type.CRUISE, VesselData.Type.TANKER, VesselData.Type.CONTAINER, VesselData.Type.FERRY]
		Audio.play("horn_big" if big else "horn_small", 0.05)
	return v


func _cull_attract() -> void:
	for v in vessels.duplicate():
		if v.entered and not visible_rect.grow(3.0).has_point(v.pos):
			vessels.erase(v)
			v.queue_free()


# --- Collisions & docking ------------------------------------------------------

func _check_collisions() -> void:
	var warned := {}
	for i in vessels.size():
		var a := vessels[i]
		if a.state != Vessel.State.SAILING or a.submerged:
			continue
		var ca := a.capsule()
		for j in range(i + 1, vessels.size()):
			var b := vessels[j]
			if b.state != Vessel.State.SAILING or b.submerged:
				continue
			var cb := b.capsule()
			var pts := Geometry2D.get_closest_points_between_segments(ca[0], ca[1], cb[0], cb[1])
			var gap: float = pts[0].distance_to(pts[1]) - ca[2] - cb[2]
			if gap < 0.0 and a.entered and b.entered:
				_crash(a, b, (pts[0] + pts[1]) * 0.5)
				return
			if gap < 0.9:
				warned[a] = true
				warned[b] = true
	for v in vessels:
		if warned.has(v) and not v.warning:
			close_calls += 1
		v.set_warning(warned.has(v))
	Audio.set_tension(1.0 if not warned.is_empty() else 0.0)


func _crash(a: Vessel, b: Vessel, at: Vector2) -> void:
	if GameState.lifebuoys > 0:
		_rescue(a, b, at)
		return
	mode = Mode.OVER
	_crashed = [a, b]
	Audio.set_tension(0.0)
	a.set_warning(true)
	b.set_warning(true)
	add_child(Effects.explosion(Vector3(at.x, 0.2, at.y)))
	Audio.play("crash")
	GameState.vibrate(300)
	crashed.emit()
	await get_tree().create_timer(1.3).timeout
	level_lost.emit()


func can_revive() -> bool:
	return not revive_used and mode == Mode.OVER and not _crashed.is_empty()


## Rewarded continue (once per level): wreckage is cleared and play resumes.
func revive() -> void:
	revive_used = true
	for v in _crashed:
		vessels.erase(v)
		if is_instance_valid(v):
			v.queue_free()
	_crashed.clear()
	_touches.clear()
	_refresh_port_highlights()
	for v in vessels:
		v.set_warning(false)
	_spawn_timer = maxf(_spawn_timer, 2.0)
	mode = Mode.PLAY


## Lifebuoy: both ships are towed away and the level continues.
func _rescue(a: Vessel, b: Vessel, at: Vector2) -> void:
	GameState.lifebuoys -= 1
	GameState.save()
	add_child(Effects.explosion(Vector3(at.x, 0.2, at.y)))
	add_child(Effects.popup("SAVED!", Vector3(at.x, 1.0, at.y), Color("ffd23f")))
	Audio.play("splash")
	GameState.vibrate(120)
	crashed.emit()
	lifebuoy_used.emit()
	for v in [a, b]:
		vessels.erase(v)
		for i in _touches.keys():
			if _touches[i] == v:
				_touches.erase(i)
		v.queue_free()
	_refresh_port_highlights()


func _on_docked(v: Vessel) -> void:
	vessels.erase(v)
	if v.target:
		v.target.celebrate()
		add_child(Effects.popup("+1", Vector3(v.target.dock.x, 0.8, v.target.dock.y), v.target.color))
	v.queue_free()
	if mode != Mode.PLAY:
		return
	docked += 1
	GameState.add_docked()
	Audio.play("dock", 0.0, [1.0, 1.12, 0.89, 1.26, 0.79, 1.19, 1.5][v.target.port_class if v.target else 6])
	GameState.vibrate(30)
	progress_changed.emit(docked, data.target)
	if docked >= data.target:
		mode = Mode.OVER
		Audio.set_tension(0.0)
		Audio.stinger("win")
		await get_tree().create_timer(0.8).timeout
		level_won.emit()


func _tutorial() -> void:
	if _tutorial_sent or data.level != 1:
		return
	for v in vessels:
		if v.entered and v.path.is_empty():
			for p in world.ports:
				if p.accepts(v.port):
					_tutorial_sent = true
					first_vessel.emit(v, p)
					return


# --- Input: draw paths with one or more fingers --------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if mode != Mode.PLAY or camera == null:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_start(event.index, ground_point(event.position))
		else:
			_touch_end(event.index)
	elif event is InputEventScreenDrag:
		_touch_move(event.index, ground_point(event.position))


func _touch_start(index: int, p: Vector2) -> void:
	var best: Vessel
	var best_d := INF
	for v in vessels:
		if v.state != Vessel.State.SAILING or _touches.values().has(v):
			continue
		var d := v.hit_distance(p)
		if d < maxf(PICK_RADIUS, v.half_w + 0.5) and d < best_d:
			best_d = d
			best = v
	if best == null:
		return
	best.start_path()
	best.set_selected(true)
	_touches[index] = best
	Audio.play("select")
	_refresh_port_highlights()
	get_viewport().set_input_as_handled()


func _touch_move(index: int, p: Vector2) -> void:
	var v: Vessel = _touches.get(index)
	if v == null or v.state != Vessel.State.SAILING or v.target != null:
		return
	var last := v.last_point()
	if last.distance_to(p) < POINT_STEP or v.path.size() >= MAX_PATH_POINTS:
		return
	if _try_snap(v, p):
		return
	if not data.grid.segment_clear(last, p, PATH_CLEARANCE):
		return
	var steps := int(last.distance_to(p) / POINT_STEP)
	for s in range(1, steps + 1):
		v.add_point(last.lerp(p, float(s) / steps))
		_smooth_tail(v)


## Snap generously: near the pad, the pier, or the port's landmark on the island.
func _try_snap(v: Vessel, p: Vector2) -> bool:
	for port in world.ports:
		if not port.accepts(v.port):
			continue
		var near := p.distance_to(port.dock + port.dir * 0.35) < Port.SNAP_RADIUS \
			or p.distance_to(port.coast - port.dir * 0.5) < 1.1
		if near and data.grid.segment_clear(v.last_point(), port.approach(), PATH_CLEARANCE):
			v.snap_to(port)
			Audio.play("link")
			GameState.vibrate(15)
			_refresh_port_highlights()
			return true
	return false


## Light low-pass on the newest points so finger jitter never shows up as zig-zags.
func _smooth_tail(v: Vessel) -> void:
	var n := v.path.size()
	if n >= 3:
		v.path[n - 2] = (v.path[n - 3] + v.path[n - 2] * 2.0 + v.path[n - 1]) * 0.25


func _touch_end(index: int) -> void:
	var v: Vessel = _touches.get(index)
	_touches.erase(index)
	if v == null:
		return
	v.set_selected(false)
	if v.target == null and not v.path.is_empty() and v.state == Vessel.State.SAILING:
		var end := v.last_point()
		if not _try_snap(v, end):
			for port in world.ports:
				if not port.accepts(v.port) and end.distance_to(port.dock) < Port.SNAP_RADIUS:
					Audio.play("error")
					break
	_refresh_port_highlights()


func _refresh_port_highlights() -> void:
	var wanted := {}
	for v: Vessel in _touches.values():
		if v.target == null:
			wanted[v.port] = true
	for port in world.ports:
		var on := false
		for vp: int in wanted:
			if port.accepts(vp):
				on = true
		port.highlight(on)


func ground_point(screen: Vector2) -> Vector2:
	var from := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	if absf(dir.y) < 0.0001:
		return Vector2.ZERO
	var hit := from + dir * (-from.y / dir.y)
	return Vector2(hit.x, hit.z)


func screen_point(p: Vector2, height := 0.0) -> Vector2:
	return camera.unproject_position(Vector3(p.x, height, p.y))
