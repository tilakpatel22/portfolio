extends SceneTree
## Mechanics stress test (headless):
##   godot --headless --path . -s tests/mechanics_test.gd [-- quick]
## A) generator invariants  B) free-sailing ships  C) guided docking from every lane
## D) spawn fairness (no input)  E) game-state flows (lifebuoy, revive, calm, reloads)

const PF := LevelData.PLAYFIELD
const DT := 1.0 / 30.0

var main: Node
var game: Node
var gs: Node
var _fails: Array[String] = []
var _quick := false


func _initialize() -> void:
	_quick = OS.get_cmdline_user_args().has("quick")
	_run()


func _check(ok: bool, msg: String) -> void:
	if not ok:
		_fails.append(msg)
		print("  FAIL: ", msg)


func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.6).timeout
	game = main.game
	gs = root.get_node("GameState")
	gs.lifebuoys = 0
	gs.intro_seen = 99999
	_test_generator(60 if _quick else 300)
	var levels := [1, 4, 9, 14, 22, 37, 61] if _quick else [1, 2, 4, 6, 9, 12, 14, 17, 22, 26, 33, 41, 55, 70, 95]
	_test_free_sailing(levels)
	_test_guided(levels)
	await _test_spawn_fairness(levels)
	await _test_flows()
	print("\nMECHANICS RESULT: ", "PASS" if _fails.is_empty() else "FAIL (%d)" % _fails.size())
	quit(1 if not _fails.is_empty() else 0)


# --- A) Generator --------------------------------------------------------------

func _test_generator(count: int) -> void:
	print("[A] generator invariants, levels 1..%d" % count)
	var worst_ms := 0
	var fallbacks := 0
	var prev_d := 0.0
	for level in range(1, count + 1):
		var t0 := Time.get_ticks_msec()
		var d := LevelGenerator.generate(level)
		worst_ms = maxi(worst_ms, Time.get_ticks_msec() - t0)
		var tag := "L%d" % level
		if d.attempts < 0:
			fallbacks += 1
		var again := LevelGenerator.generate(level)
		_check(_signature(d) == _signature(again), tag + " not deterministic")
		_check(d.gates.size() >= 2, tag + " gates < 2")
		_check(d.pool.size() >= 2, tag + " pool < 2")
		_check(d.target >= 5 and d.max_active >= 2 and d.spawn_interval > 1.0, tag + " bad params")
		var classes := {}
		for p in d.ports:
			classes[p["port"]] = true
			var dock: Vector2 = p["pos"]
			var dir: Vector2 = p["dir"]
			_check(PF.has_point(dock), tag + " dock off-screen")
			_check(d.grid.distance(dock) >= 0.55, tag + " dock too close to land (%.2f)" % d.grid.distance(dock))
			_check(d.grid.distance(dock + dir * 1.4) >= 1.2, tag + " approach blocked")
			_check(absf(dir.length() - 1.0) < 0.01, tag + " port dir not normalized")
			for q in d.ports:
				if q != p:
					_check(dock.distance_to(q["pos"]) >= 2.9, tag + " ports overlap")
		for e in d.pool:
			var pc := VesselData.port_of(e["type"])
			_check(pc == VesselData.Port.ANY or classes.has(pc), tag + " no port for " + VesselData.TYPES[e["type"]]["name"])
		for g in d.gates:
			var gp: Vector2 = g["pos"]
			var gd: Vector2 = g["dir"]
			_check(d.grid.distance(gp + gd * 2.0) >= 1.0, tag + " gate lane blocked")
			_check(gd.dot((PF.get_center() - gp).normalized()) > 0.3, tag + " gate points outward")
			var mask := d.grid.flood(gp + gd * 2.0, 0.55)
			for p in d.ports:
				_check(d.grid.reached(mask, (p["pos"] as Vector2) + (p["dir"] as Vector2) * 1.2),
					tag + " port unreachable from a gate")
		if level > 1 and level % 5 == 1:
			_check(d.difficulty <= prev_d + 0.2, tag + " difficulty jump")
		prev_d = d.difficulty
	print("    worst generation time %d ms, fallback maps %d/%d" % [worst_ms, fallbacks, count])
	_check(worst_ms < 1500, "generation too slow (%d ms)" % worst_ms)
	_check(fallbacks * 20 < count, "too many fallback maps (%d)" % fallbacks)


func _signature(d: LevelData) -> String:
	return var_to_str([d.rng_seed, d.archetype, d.target, d.max_active, d.spawn_interval, d.pool, d.ports, d.gates, d.islands, d.modifiers])


# --- B) Free-sailing (unguided) ships -------------------------------------------

func _setup_level(level: int) -> void:
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.load_level(level)
	game.data.max_active = 0


func _bounds() -> Rect2:
	return game.visible_rect.intersection(PF.grow(1.0))


func _test_free_sailing(levels: Array) -> void:
	print("[B] free-sailing ships: aground / stuck / lost off-screen")
	var total := 0
	var bad := 0
	for level in levels:
		_setup_level(level)
		var d = game.data
		for gi in d.gates.size():
			for e in d.pool:
				var v = game._spawn(e["type"], d.gates[gi])
				v.gate = gi
				var res := _sail(v, 70.0)
				total += 1
				if res != "":
					bad += 1
					_check(false, "L%d gate %d %s: %s" % [level, gi, VesselData.TYPES[e["type"]]["name"], res])
				game.vessels.erase(v)
				v.free()
	print("    %d runs, %d problems" % [total, bad])


func _sail(v: Node, seconds: float) -> String:
	var grid: LandGrid = game.data.grid
	var t := 0.0
	var offscreen := 0.0
	var window: Array[Vector2] = []
	while t < seconds:
		v.tick(DT, grid, game.data.current, _bounds())
		t += DT
		if not v.entered:
			if t > 25.0:
				return "never entered the playfield"
			continue
		if grid.distance(v.pos) < v.half_w * 0.4:
			return "ran aground at %s" % v.pos
		offscreen = offscreen + DT if not game.visible_rect.has_point(v.pos) else 0.0
		if offscreen > 2.5:
			return "lost off-screen at %s" % v.pos
		window.append(v.pos)
		if window.size() > int(15.0 / DT):
			window.pop_front()
			var r := Rect2(window[0], Vector2.ZERO)
			for p in window:
				r = r.expand(p)
			if r.size.length() < 2.0:
				return "stuck near %s" % v.pos
	return ""


# --- C) Guided docking from every lane to every port -----------------------------

func _test_guided(levels: Array) -> void:
	print("[C] guided docking: every gate -> every port, real touch handlers")
	var total := 0
	var ok := 0
	for level in levels:
		_setup_level(level)
		var d = game.data
		for gi in d.gates.size():
			for port in game.world.ports:
				var type := _type_for(port.port_class, d)
				var v = game._spawn(type, d.gates[gi])
				var res := _guide(v, port)
				total += 1
				if res == "":
					ok += 1
				else:
					_check(false, "L%d gate %d -> %s with %s: %s" % [level, gi, VesselData.PORT_NAMES[port.port_class],
						VesselData.TYPES[type]["name"], res])
				game.vessels.erase(v)
				game._touches.clear()
				v.free()
	print("    %d/%d routes docked" % [ok, total])


func _type_for(port_class: int, d: LevelData) -> int:
	var best := VesselData.Type.TUG
	var best_w := -1.0
	for t: int in VesselData.TYPES:
		if VesselData.port_of(t) == port_class and VesselData.TYPES[t]["width"] > best_w:
			best_w = VesselData.TYPES[t]["width"]
			best = t   # widest ship of that class = hardest case
	return best


func _guide(v: Node, port: Node) -> String:
	var grid: LandGrid = game.data.grid
	var t := 0.0
	while not v.entered:
		v.tick(DT, grid, game.data.current, _bounds())
		t += DT
		if t > 25.0:
			return "never entered"
	var route := _route(v.pos, port.approach(), v.half_w + 0.2)
	if route.is_empty():
		return "no route found by test BFS"
	game._touch_start(0, v.pos)
	if game._touches.get(0) != v:
		return "could not pick the ship"
	var last: Vector2 = v.pos
	for p in route:
		var steps := maxi(1, int(last.distance_to(p) / 0.2))
		for k in range(1, steps + 1):
			game._touch_move(0, last.lerp(p, float(k) / steps))
		last = p
	game._touch_move(0, port.dock)
	game._touch_end(0)
	if v.target == null or not v.target.accepts(v.port):
		return "path did not snap to a matching port (path %d pts, ends %s)" % [v.path.size(), v.last_point()]
	var min_land := INF
	while v.state == 0 and t < 150.0:
		v.tick(DT, grid, game.data.current, _bounds())
		t += DT
		min_land = minf(min_land, grid.distance(v.pos))
	if v.state == 0:
		return "did not dock in time"
	if min_land < v.half_w * 0.5:
		return "hull scraped land (%.2f)" % min_land
	return ""


func _route(a: Vector2, b: Vector2, clearance: float) -> PackedVector2Array:
	var grid: LandGrid = game.data.grid
	var W := LandGrid.W
	var cell := func(p: Vector2) -> int:
		var c := Vector2i(((p - LandGrid.ORIGIN) / LandGrid.CELL).floor())
		return c.y * W + c.x
	var pos_of := func(c: int) -> Vector2:
		return LandGrid.ORIGIN + Vector2(c % W + 0.5, c / W + 0.5) * LandGrid.CELL
	var start: int = cell.call(a)
	var goal: int = cell.call(b)
	var inside := PF.grow(1.0)
	var prev := {start: -1}
	var queue: Array[int] = [start]
	var head := 0
	while head < queue.size():
		var c: int = queue[head]
		head += 1
		if c == goal:
			break
		for n in [c - 1, c + 1, c - W, c + W, c - W - 1, c - W + 1, c + W - 1, c + W + 1]:
			if n < 0 or n >= grid.dist.size() or prev.has(n):
				continue
			if grid.dist[n] < clearance or not inside.has_point(pos_of.call(n)):
				continue
			prev[n] = c
			queue.append(n)
	if not prev.has(goal):
		return PackedVector2Array()
	var pts: Array[Vector2] = []
	var c := goal
	while c != -1:
		pts.push_front(pos_of.call(c))
		c = prev[c]
	var out := PackedVector2Array()
	var anchor := a
	for i in range(1, pts.size()):
		if not grid.segment_clear(anchor, pts[i], clearance):
			anchor = pts[i - 1]
			out.append(anchor)
	out.append(b)
	return out


# --- D) Spawn fairness with no player input ----------------------------------------

func _test_spawn_fairness(levels: Array) -> void:
	print("[D] spawn fairness (no input): crashes within 2.5 s of a ship entering")
	game.process_mode = Node.PROCESS_MODE_INHERIT
	Engine.time_scale = 8.0
	var unfair := 0
	var runs := 0
	for level in levels:
		game.load_level(level)
		var entered_at := {}
		var crash := [null]
		var cb := func() -> void: crash[0] = game._crashed.duplicate()
		game.crashed.connect(cb)
		var t0: float = 0.0
		while game.mode == 1 and game._time < 90.0:
			for v in game.vessels:
				if v.entered and not entered_at.has(v):
					entered_at[v] = game._time
			await process_frame
		game.crashed.disconnect(cb)
		runs += 1
		var first_crash: float = game._time
		if crash[0] != null:
			for v in crash[0]:
				var since: float = first_crash - entered_at.get(v, first_crash)
				if since < 2.5:
					unfair += 1
					_check(false, "L%d spawn-kill: %s crashed %.1fs after entering" % [level, VesselData.TYPES[v.type]["name"], since])
					break
		print("    L%-3d no-input survival %.0fs %s" % [level, first_crash, "(crash)" if crash[0] != null else ""])
		await create_timer(0.3).timeout
	Engine.time_scale = 1.0
	print("    %d runs, %d unfair spawn crashes" % [runs, unfair])


# --- E) Flows --------------------------------------------------------------------

func _test_flows() -> void:
	print("[E] flows: lifebuoy, revive, calm, reload safety")
	main.start_level()
	await create_timer(0.8).timeout
	# Lifebuoy: crash consumes it and play continues.
	_force_two_ships()
	gs.lifebuoys = 1
	game._check_collisions()
	_check(game.mode == 1 and gs.lifebuoys == 0, "lifebuoy did not save the level")
	_check(game.vessels.is_empty(), "lifebuoy did not remove the crashed ships")
	# Revive: once per level.
	_force_two_ships()
	game._check_collisions()
	_check(game.mode == 2 and game.can_revive(), "crash should allow one revive")
	game.revive()
	_check(game.mode == 1 and not game.can_revive(), "revive did not resume play")
	_force_two_ships()
	game._check_collisions()
	_check(game.mode == 2 and not game.can_revive(), "second revive must not be allowed")
	# Calm resets on reload.
	main.start_level()
	await create_timer(0.8).timeout
	_check(game.activate_calm(), "calm could not be activated")
	_check(not game.activate_calm(), "calm activated twice")
	game.load_level(game.data.level)
	_check(game.calm_left == 0.0 and game.calm_cool == 0.0, "calm state leaked into new level")
	# A ship waiting to enter must not appear in a reloaded level.
	game._queue_spawn(0, game.data.pool[0]["type"])
	game.load_level(game.data.level)
	var before: int = game.vessels.size()
	await create_timer(game.data.warn_time + 0.5).timeout
	_check(game.vessels.size() <= before + 1, "stale spawn leaked into reloaded level")
	# Crash, then leave to menu before the result screen: no result screen over the menu.
	var lost := [false]
	game.level_lost.connect(func() -> void: lost[0] = true, CONNECT_ONE_SHOT)
	_force_two_ships()
	game._check_collisions()
	main.go_menu()
	await create_timer(2.0).timeout
	_check(not lost[0], "level_lost fired after returning to the menu")


func _force_two_ships() -> void:
	for v in game.vessels:
		v.queue_free()
	game.vessels.clear()
	var d = game.data
	for k in 2:
		var v = game._spawn(d.pool[0]["type"], d.gates[0])
		v.pos = Vector2(0.0, 0.2 * k)
		v.entered = true
