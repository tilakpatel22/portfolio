extends Node
## Marketing capture: plays a high-rush level automatically through real touch input,
## with a visible hand cursor. Records video (Movie Maker) and saves stills.
##
## Video:  godot --path . --write-movie build/media/raw.avi --fixed-fps 30 res://tools/showcase.tscn -- --level=45
## Stills: godot --path . --fixed-fps 30 res://tools/showcase.tscn -- --level=35 --length=14 --shots=12 --prefix=l35
## Options: --level --length --shots=a,b,c --prefix --menu (s on menu) --calm_at --win_at --out
##          --ships (ships on screen at peak) --spawn (s between arrivals) --pace (s between routes)

const HAND := preload("res://assets/ui/hand.svg")
const PF := LevelData.PLAYFIELD
const FINGERTIP := Vector2(0.46, 0.12)   # fingertip position inside the hand image (0..1)

var cfg := {"level": 45, "length": 30.0, "shots": [], "prefix": "shot", "menu": 2.5,
	"calm_at": 14.0, "win_at": 26.0, "out": "res://build/media", "ships": 10.0, "spawn": 1.7, "pace": 0.7}
var main: Node
var game: Node
var _hand: TextureRect
var _clock := 0.0
var _started := false
var _populated := false
var _calm_done := false
var _won := false
var _busy := false
var _shots_taken := {}
var _entered_at := {}


func _ready() -> void:
	_parse_args()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(cfg.out))
	var gs := get_node("/root/GameState")
	gs.level = int(cfg.level)
	gs.best_level = int(cfg.level)
	gs.intro_seen = 99999
	gs.total_docked = 1
	gs.lifebuoys = 0
	gs.rate_prompted = true
	gs.music_on = true
	gs.sfx_on = true
	gs.vibration_on = false
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	game = main.game
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_hand = TextureRect.new()
	_hand.texture = HAND
	_hand.size = Vector2(130, 130)
	_hand.pivot_offset = _hand.size * FINGERTIP
	_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hand.modulate.a = 0.0
	layer.add_child(_hand)


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--") or not "=" in a:
			continue
		var kv := a.substr(2).split("=", true, 1)
		match kv[0]:
			"shots":
				cfg.shots = Array(kv[1].split(",")).map(func(x: String) -> float: return float(x))
			"prefix", "out":
				cfg[kv[0]] = kv[1]
			_:
				cfg[kv[0]] = float(kv[1])


func _process(delta: float) -> void:
	_clock += delta
	if OS.get_environment("SHOWCASE_DEBUG") != "" and Engine.get_process_frames() % 30 == 0:
		print("t=%.1f started=%s mode=%s paused=%s ships=%d fps=%.1f" % [_clock, _started, game.mode, get_tree().paused, game.vessels.size(), Engine.get_frames_per_second()])
	if not _started:
		_menu_phase()
		return
	if game.data and game.data.level == int(cfg.level) and game.mode == 1:
		if not _populated:
			_populate()
		game.grace = 1e9   # showcase: no game over, warnings still show the rush
		for v in game.vessels:
			if v.entered and not _entered_at.has(v):
				_entered_at[v] = _clock
		if not _calm_done and _clock >= cfg.calm_at and not _busy:
			_calm_done = true
			_tap_calm()
		elif not _busy:
			_pilot()
		if not _won and _clock >= cfg.win_at:
			_won = true
			game._win()
	for t in cfg.shots:
		if _clock >= t and not _shots_taken.has(t):
			_shots_taken[t] = true
			_shot("%s_%02d.png" % [cfg.prefix, int(t)])
	if _clock >= cfg.length:
		get_tree().quit()


# --- Menu: the hand taps PLAY ----------------------------------------------------

func _menu_phase() -> void:
	for b in main.ui.find_children("*", "Label", true, false):
		if (b as Label).text.begins_with("Best:"):
			b.visible = false   # demo save data is not interesting on camera
	if _clock >= cfg.menu - 1.0 and _hand.modulate.a == 0.0 and cfg.menu > 1.2:
		var play := _find_button("PLAY")
		if play:
			_move_hand(play.get_global_rect().get_center(), 0.6)
	if _clock >= cfg.menu:
		_started = true
		var play := _find_button("PLAY")
		if play and cfg.menu > 1.2:
			_press_hand()
		_hide_hand()
		main.start_level()


func _find_button(text: String) -> Button:
	for b in main.ui.find_children("*", "Button", true, false):
		if (b as Button).text == text and b.is_visible_in_tree():
			return b
	return null


# --- Peak traffic from the first second --------------------------------------------

func _populate() -> void:
	_populated = true
	var d = game.data
	d.max_active = int(cfg.ships)          # peak traffic for the camera
	d.spawn_interval = float(cfg.spawn)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var placed: Array[Vector2] = []
	for v in game.vessels:
		placed.append(v.pos)
	var want: int = d.max_active - 1 - game.vessels.size()
	var tries := 0
	while want > 0 and tries < 400:
		tries += 1
		var p := Vector2(rng.randf_range(PF.position.x + 3.0, PF.end.x - 3.0), rng.randf_range(PF.position.y + 2.5, PF.end.y - 2.5))
		if d.grid.distance(p) < 1.6:
			continue
		var ok := true
		for q in placed:
			if q.distance_to(p) < 4.0:
				ok = false
		for port in game.world.ports:
			if port.dock.distance_to(p) < 3.0:
				ok = false
		if not ok:
			continue
		var heading := (PF.get_center() - p).normalized().rotated(rng.randf_range(-1.0, 1.0))
		var v = game._spawn(game._pick_type(), {"pos": p, "dir": heading})
		v.pos = p
		v.entered = true
		v._stuck_from = p
		v.update_visuals(1.0)
		placed.append(p)
		want -= 1


# --- Autopilot: one finger, real touch events ------------------------------------------

func _pilot() -> void:
	var best = null
	var best_score := INF
	for v in game.vessels:
		if not v.entered or v.state != 0 or v.target != null or not v.path.is_empty():
			continue
		var score: float = _entered_at.get(v, _clock) - (100.0 if v.warning else 0.0)
		if score < best_score:
			best_score = score
			best = v
	if best == null:
		return
	var ports: Array = game.world.ports.filter(func(p) -> bool: return p.accepts(best.port))
	ports.sort_custom(func(a, b) -> bool: return a.dock.distance_to(best.pos) < b.dock.distance_to(best.pos))
	for port in ports:
		var route := _route(best.pos + best.heading * 0.6, port.approach(), best.half_w + 0.25)
		if not route.is_empty():
			_draw_route(best, port, route)
			return


func _draw_route(v: Node, port: Node, route: PackedVector2Array) -> void:
	_busy = true
	var pts := PackedVector2Array()
	var last: Vector2 = v.pos
	for p in route:
		var steps := maxi(1, int(last.distance_to(p) / 0.45))
		for k in range(1, steps + 1):
			pts.append(last.lerp(p, float(k) / steps))
		last = p
	pts.append(port.dock)
	_show_hand(game.screen_point(v.pos))
	_touch(true, v.pos)
	for i in pts.size():
		if not is_instance_valid(v):
			break
		_drag(pts[i])
		_place_hand(game.screen_point(pts[i]))
		if i % 2 == 1:
			await get_tree().process_frame
	_touch(false, port.dock)
	_hide_hand()
	for _i in int(float(cfg.pace) * 30.0):   # let traffic build up between routes
		await get_tree().process_frame
	_busy = false


func _tap_calm() -> void:
	_busy = true
	var btn: Button = main.ui._calm_btn
	_move_hand(btn.get_global_rect().get_center(), 0.5)
	for _i in 18:
		await get_tree().process_frame
	_press_hand()
	btn.pressed.emit()
	for _i in 12:
		await get_tree().process_frame
	_hide_hand()
	_busy = false


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
	var inside := PF.grow(0.5)
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
	var cells: Array[Vector2] = []
	var c := goal
	while c != -1:
		cells.push_front(pos_of.call(c))
		c = prev[c]
	var out := PackedVector2Array()
	var anchor := a
	for i in range(1, cells.size()):
		if not grid.segment_clear(anchor, cells[i], clearance):
			anchor = cells[i - 1]
			out.append(anchor)
	out.append(b)
	return out


func _touch(pressed: bool, p: Vector2) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.pressed = pressed
	e.position = game.screen_point(p)
	get_viewport().push_input(e, true)


func _drag(p: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = 0
	e.position = game.screen_point(p)
	get_viewport().push_input(e, true)


# --- Hand cursor ------------------------------------------------------------------

func _place_hand(screen: Vector2) -> void:
	_hand.position = screen - _hand.size * FINGERTIP


func _show_hand(screen: Vector2) -> void:
	_place_hand(screen)
	_hand.modulate.a = 1.0
	_hand.scale = Vector2.ONE * 0.9


func _move_hand(screen: Vector2, seconds: float) -> void:
	if _hand.modulate.a == 0.0:
		_place_hand(screen + Vector2(140, 160))
	var t := create_tween().set_parallel()
	t.tween_property(_hand, "modulate:a", 1.0, 0.2)
	t.tween_property(_hand, "position", screen - _hand.size * FINGERTIP, seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _press_hand() -> void:
	var t := create_tween()
	t.tween_property(_hand, "scale", Vector2.ONE * 0.8, 0.08)
	t.tween_property(_hand, "scale", Vector2.ONE, 0.12)


func _hide_hand() -> void:
	create_tween().tween_property(_hand, "modulate:a", 0.0, 0.2)


func _shot(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(cfg.out).path_join(name))
	print("shot ", name)
