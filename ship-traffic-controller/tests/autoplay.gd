extends SceneTree
## End-to-end test: an autopilot plays levels through real touch input.
## godot --headless --path . -s tests/autoplay.gd -- <first_level> <levels>

var main: Node
var game: Node
var gs: Node
var _result := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_run(int(args[0]) if args.size() > 0 else 1, int(args[1]) if args.size() > 1 else 3)


func _run(first: int, count: int) -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.8).timeout
	game = main.game
	gs = root.get_node("GameState")
	gs.level = first
	gs.intro_seen = 9999
	gs.total_docked = 1
	gs.rate_prompted = true
	game.level_won.connect(func() -> void: _result = "WON")
	game.level_lost.connect(func() -> void: _result = "LOST")
	game.crashed.connect(func() -> void:
		if OS.get_environment("AUTOPLAY_DEBUG") == "":
			return
		print("  crash t=%.1f" % game._time)
		for v in game.vessels:
			print("    %s pos=%s head=%s entered=%s target=%s path=%d warn=%s" % [VesselData.TYPES[v.type]["name"], v.pos, v.heading, v.entered, v.target != null, v.path.size(), v.warning]))
	Engine.time_scale = 3.0
	var fails := 0
	for i in count:
		var lvl: int = gs.level
		_result = ""
		if i == 0:
			main.start_level()
		await create_timer(1.2).timeout
		var t0 := Time.get_ticks_msec()
		while _result == "" and Time.get_ticks_msec() - t0 < 120000:
			_pilot()
			await create_timer(0.2).timeout
		print("Level %d: %s  docked=%d/%d close_calls=%d stars=%d (%s)" % [lvl, _result if _result else "TIMEOUT",
			game.docked, game.data.target, game.close_calls, game.stars(), game.data.archetype])
		if _result != "WON":
			fails += 1
			# Move on so one run covers many levels (retry flow is exercised separately).
			gs.complete_level()
			main.start_level()
			continue
		await create_timer(1.0).timeout
		main.ui.next_pressed.emit()   # -> complete_level -> interstitial (no-op on desktop) -> next level
	Engine.time_scale = 1.0
	print("AUTOPLAY RESULT: ", "PASS" if fails == 0 else "FAILURES=%d" % fails)
	quit(1 if fails else 0)


## Route every unrouted ship to its nearest matching port with a BFS path, via touch events.
func _pilot() -> void:
	for v in game.vessels:
		if v.target != null or not v.entered or v.state != 0:
			continue
		var best = null
		var best_d := INF
		for p in game.world.ports:
			if p.accepts(v.port) and v.pos.distance_to(p.dock) < best_d:
				best_d = v.pos.distance_to(p.dock)
				best = p
		if best == null:
			continue
		var route := _route(v.pos + v.heading * 0.6, best.approach())
		if route.is_empty():
			continue
		_touch(true, v.pos)
		var last: Vector2 = v.pos
		for p in route:
			var steps := maxi(1, int(last.distance_to(p) / 0.5))
			for k in range(1, steps + 1):
				_drag(last.lerp(p, float(k) / steps))
			last = p
		_drag(best.dock)
		_touch(false, best.dock)
		return


func _route(a: Vector2, b: Vector2) -> PackedVector2Array:
	var grid = game.data.grid
	if grid.segment_clear(a, b, 0.5):
		return PackedVector2Array([b])
	var W: int = grid.W
	var start := _cell(a)
	var goal := _cell(b)
	var inside := LevelData.PLAYFIELD.grow(-0.5)
	var prev := {start: -1}
	var queue := [start]
	while not queue.is_empty():
		var c: int = queue.pop_front()
		if c == goal:
			break
		for n in [c - 1, c + 1, c - W, c + W, c - W - 1, c - W + 1, c + W - 1, c + W + 1]:
			if n < 0 or n >= grid.dist.size() or prev.has(n) or grid.dist[n] < 0.7:
				continue
			if n != goal and not inside.has_point(_pos(n)):
				continue
			prev[n] = c
			queue.append(n)
	if not prev.has(goal):
		return PackedVector2Array()
	var pts := []
	var c := goal
	while c != -1:
		pts.push_front(_pos(c))
		c = prev[c]
	# String-pull: keep only the waypoints needed for clear straight segments.
	var out := PackedVector2Array()
	var anchor: Vector2 = a
	var i := 1
	while i < pts.size():
		if not grid.segment_clear(anchor, pts[i], 0.45):
			anchor = pts[i - 1]
			out.append(anchor)
		i += 1
	out.append(b)
	return out


func _pos(c: int) -> Vector2:
	var g = game.data.grid
	return g.ORIGIN + Vector2(c % g.W + 0.5, c / g.W + 0.5) * g.CELL


func _cell(p: Vector2) -> int:
	var g = game.data.grid
	var c := Vector2i(((p - g.ORIGIN) / g.CELL).floor())
	return c.y * g.W + c.x


func _touch(pressed: bool, p: Vector2) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.pressed = pressed
	e.position = game.screen_point(p)
	root.push_input(e, true)


func _drag(p: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = 0
	e.position = game.screen_point(p)
	root.push_input(e, true)
