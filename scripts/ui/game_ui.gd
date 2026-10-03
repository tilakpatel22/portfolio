class_name GameUI
extends CanvasLayer
## All screens: menu, HUD, intro, tutorial, pause, results, settings, rate prompt.

signal play_pressed
signal next_pressed
signal retry_pressed
signal home_pressed
signal pause_pressed
signal resume_pressed
signal revive_pressed

const K = preload("res://scripts/ui/ui_kit.gd")
const FOG_SHADER := preload("res://assets/shaders/fog.gdshader")

var game: Game:
	set(g):
		game = g
		game.progress_changed.connect(_on_progress)
		game.spawn_warning.connect(_on_spawn_warning)
		game.first_vessel.connect(_on_first_vessel)
		game.calm_changed.connect(_on_calm)
		game.lifebuoy_used.connect(_refresh_lifebuoys)

var _root := Control.new()
var _hud := Control.new()
var _markers := Control.new()
var _overlay := Control.new()
var _fade := ColorRect.new()
var _fog := ColorRect.new()
var _calm_tint := ColorRect.new()
var _progress: ProgressBar
var _progress_label: Label
var _level_label: Label
var _mods_box: HBoxContainer
var _calm_btn: Button
var _calm_bar: ProgressBar
var _calm_active := false
var _buoy_box: HBoxContainer
var _buoy_label: Label
var _screen := ""
var _preview: MeshInstance3D
var _tutorial: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.theme = K.theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	for c: Control in [_fog, _calm_tint, _markers, _hud, _overlay]:
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(c)
	var fog_mat := ShaderMaterial.new()
	fog_mat.shader = FOG_SHADER
	_fog.material = fog_mat
	_fog.visible = false
	_calm_tint.color = Color(0.55, 0.95, 1.0, 0.0)
	_fade.color = Color("0b2545")
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fade)
	_build_hud()


func _process(delta: float) -> void:
	if _preview:
		_preview.rotate_y(delta * 0.9)


# --- Transitions -----------------------------------------------------------------

func fade(mid: Callable) -> void:
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, 0.25)
	t.tween_callback(mid)
	t.tween_property(_fade, "color:a", 0.0, 0.35)
	t.tween_callback(func() -> void: _fade.mouse_filter = Control.MOUSE_FILTER_IGNORE)


func hide_overlays() -> void:
	for c in _overlay.get_children():
		c.queue_free()
	_screen = ""
	_preview = null


func _show(screen: String, node: Control) -> void:
	hide_overlays()
	_screen = screen
	_overlay.add_child(node)


## Android back button. Returns true when the UI consumed it.
func back() -> bool:
	match _screen:
		"settings":
			show_menu()
			return true
		"pause":
			resume_pressed.emit()
			return true
		"intro_card", "rate", "complete", "failed", "reward":
			return true
	return false


# --- Menu ------------------------------------------------------------------------

func show_menu() -> void:
	_hud.visible = false
	_fog.visible = false
	_clear_markers()
	var m := Control.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var title := K.vbox(-18)
	title.add_child(K.label("SHIP TRAFFIC", 132, Color.WHITE, 30))
	title.add_child(K.label("CONTROL SIM", 104, K.ORANGE, 28))
	_corner(m, title, Control.PRESET_CENTER_TOP, Vector2(0, 70))

	var play := K.button("PLAY", K.ORANGE, Vector2(560, 170), 84, "res://assets/ui/play.svg")
	play.pressed.connect(play_pressed.emit)
	var col := K.vbox(18)
	col.add_child(play)
	col.add_child(K.label("LEVEL %d" % GameState.level, 56))
	col.add_child(K.label("Best: Level %d   •   Ships docked: %d" % [GameState.best_level, GameState.total_docked], 34, Color("e6f4ff"), 10))
	_corner(m, col, Control.PRESET_CENTER_BOTTOM, Vector2(0, -50))

	var gear := K.icon_button("res://assets/ui/gear.svg", K.BLUE, 120)
	gear.pressed.connect(show_settings)
	_corner(m, gear, Control.PRESET_TOP_RIGHT, Vector2(-40, 40))
	_show("menu", m)
	K.pop_in(play)


func _bob(c: Control) -> void:
	var t := c.create_tween().set_loops()
	t.tween_property(c, "position:y", c.position.y + 12, 1.4).set_trans(Tween.TRANS_SINE)
	t.tween_property(c, "position:y", c.position.y, 1.4).set_trans(Tween.TRANS_SINE)


## Pin a control to a corner/edge: it sizes from its min size and grows away from the edge.
func _corner(parent: Control, c: Control, preset: int, offset: Vector2) -> void:
	parent.add_child(c)
	var anchor := {Control.PRESET_TOP_LEFT: Vector2(0, 0), Control.PRESET_TOP_RIGHT: Vector2(1, 0),
		Control.PRESET_BOTTOM_LEFT: Vector2(0, 1), Control.PRESET_BOTTOM_RIGHT: Vector2(1, 1),
		Control.PRESET_CENTER_TOP: Vector2(0.5, 0), Control.PRESET_CENTER_BOTTOM: Vector2(0.5, 1),
		Control.PRESET_CENTER: Vector2(0.5, 0.5)}[preset] as Vector2
	c.anchor_left = anchor.x
	c.anchor_right = anchor.x
	c.anchor_top = anchor.y
	c.anchor_bottom = anchor.y
	c.offset_left = offset.x
	c.offset_right = offset.x
	c.offset_top = offset.y
	c.offset_bottom = offset.y
	var grow := [Control.GROW_DIRECTION_END, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BEGIN]
	c.grow_horizontal = grow[int(anchor.x * 2.0)]
	c.grow_vertical = grow[int(anchor.y * 2.0)]


# --- HUD -------------------------------------------------------------------------

func _build_hud() -> void:
	_hud.visible = false
	var bar := K.pill(Color(0.04, 0.15, 0.27, 0.78), 36)
	var row := K.hbox(22)
	bar.add_child(row)
	_level_label = K.label("LEVEL 1", 46)
	row.add_child(_level_label)
	var stack := Control.new()
	stack.custom_minimum_size = Vector2(380, 50)
	_progress = ProgressBar.new()
	_progress.show_percentage = false
	_progress.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.add_child(_progress)
	_progress_label = K.label("0 / 5", 36, Color.WHITE, 10)
	_progress_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.add_child(_progress_label)
	row.add_child(stack)
	row.add_child(K.icon("res://assets/ui/ship.svg", 54))
	_corner(_hud, bar, Control.PRESET_CENTER_TOP, Vector2(0, 26))

	_mods_box = K.hbox(12)
	_hud.add_child(_mods_box)
	_mods_box.position = Vector2(36, 34)

	var pause := K.icon_button("res://assets/ui/pause.svg", K.BLUE, 112)
	pause.pressed.connect(pause_pressed.emit)
	_corner(_hud, pause, Control.PRESET_TOP_RIGHT, Vector2(-36, 26))

	var calm := K.vbox(8)
	_calm_btn = K.icon_button("res://assets/ui/calm.svg", K.GREEN, 132)
	_calm_btn.pressed.connect(func() -> void:
		if game.activate_calm():
			GameState.vibrate(25))
	calm.add_child(_calm_btn)
	_calm_bar = ProgressBar.new()
	_calm_bar.show_percentage = false
	_calm_bar.custom_minimum_size = Vector2(132, 16)
	_calm_bar.max_value = 1.0
	_calm_bar.value = 1.0
	calm.add_child(_calm_bar)
	calm.add_child(K.label("CALM", 30, Color.WHITE, 8))
	_corner(_hud, calm, Control.PRESET_BOTTOM_LEFT, Vector2(36, -28))

	_buoy_box = K.hbox(6)
	_buoy_box.add_child(K.icon("res://assets/ui/lifebuoy.svg", 72))
	_buoy_label = K.label("x0", 40)
	_buoy_box.add_child(_buoy_label)
	_corner(_hud, _buoy_box, Control.PRESET_BOTTOM_RIGHT, Vector2(-40, -36))
	_passthrough(_hud)


## Only real buttons may catch touches on the HUD; everything else lets drags reach the sea.
func _passthrough(node: Node) -> void:
	for c in node.get_children():
		if c is Control and not c is Button:
			(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_passthrough(c)


func _refresh_lifebuoys() -> void:
	_buoy_box.visible = GameState.lifebuoys > 0
	_buoy_label.text = "x%d" % GameState.lifebuoys
	_buoy_box.pivot_offset = _buoy_box.size * 0.5
	var t := create_tween()
	t.tween_property(_buoy_box, "scale", Vector2(1.3, 1.3), 0.1)
	t.tween_property(_buoy_box, "scale", Vector2.ONE, 0.25)


func show_hud(data: LevelData) -> void:
	hide_overlays()
	_clear_markers()
	_hud.visible = true
	_level_label.text = "LEVEL %d" % data.level
	_on_progress(0, data.target)
	for c in _mods_box.get_children():
		c.queue_free()
	var names := {"RUSH": ["RUSH HOUR", K.ORANGE], "FOG": ["SEA FOG", K.GREY], "CURRENT": ["STRONG CURRENT", K.GREEN]}
	for mod in data.modifiers:
		var p := K.pill(names[mod][1], 24)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(K.label(names[mod][0], 30, Color.WHITE, 8))
		_mods_box.add_child(p)
	_fog.visible = data.has_mod("FOG")
	_refresh_lifebuoys()
	_intro_banner(data)
	Audio.stinger("start")
	if data.new_type >= 0 and GameState.intro_seen < data.level:
		GameState.intro_seen = data.level
		GameState.save()
		_new_vessel_card(data.new_type)


func _on_progress(docked: int, target: int) -> void:
	_progress.max_value = target
	var t := create_tween()
	t.tween_property(_progress, "value", float(docked), 0.25)
	_progress_label.text = "%d / %d" % [docked, target]
	if docked > 0:
		_progress_label.pivot_offset = _progress_label.size * 0.5
		var p := create_tween()
		p.tween_property(_progress_label, "scale", Vector2(1.3, 1.3), 0.08)
		p.tween_property(_progress_label, "scale", Vector2.ONE, 0.2)


func _on_calm(active: bool, charge: float) -> void:
	_calm_bar.value = charge
	_calm_btn.disabled = active or charge < 1.0
	if active != _calm_active:
		_calm_active = active
		create_tween().tween_property(_calm_tint, "color:a", 0.16 if active else 0.0, 0.3)


func _intro_banner(data: LevelData) -> void:
	var v := K.vbox(4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(K.label("LEVEL %d" % data.level, 120, Color.WHITE, 28))
	v.add_child(K.label("Dock %d ships safely" % data.target, 52, Color("ffe8b6"), 14))
	var tips := {"RUSH": "Rush hour! Ships arrive in waves.", "FOG": "Sea fog: ships appear with little warning.", "CURRENT": "Strong current pushes free-sailing ships."}
	for mod in data.modifiers:
		v.add_child(K.label(tips[mod], 38, Color.WHITE, 10))
	_corner(_hud, v, Control.PRESET_CENTER, Vector2.ZERO)
	v.modulate.a = 0.0
	var t := v.create_tween()
	t.tween_property(v, "modulate:a", 1.0, 0.3)
	t.tween_interval(1.8)
	t.tween_property(v, "modulate:a", 0.0, 0.5)
	t.tween_callback(v.queue_free)


func _new_vessel_card(type: int) -> void:
	get_tree().paused = true
	Audio.stinger("newship")
	var info := VesselData.info(type)
	var port: int = info["port"]
	var dim := K.dimmer()
	var card := K.card()
	var v := K.vbox(14)
	card.add_child(v)
	v.add_child(K.label("NEW VESSEL!", 72, K.ORANGE, 20))
	v.add_child(_vessel_preview(type))
	v.add_child(K.label(info["name"], 60, Color.WHITE, 16))
	var row := K.hbox(14)
	row.add_child(K.icon(VesselData.PORT_ICONS[port], 64))
	row.add_child(K.label("Docks at: " + VesselData.PORT_NAMES[port], 40, K.INK, 0))
	v.add_child(row)
	if VesselData.TRAITS.has(type):
		v.add_child(K.label(VesselData.TRAITS[type], 38, Color("5a6b7d"), 0))
	var ok := K.button("GOT IT!", K.GREEN, Vector2(380, 120), 52)
	ok.pressed.connect(func() -> void:
		get_tree().paused = false
		hide_overlays())
	v.add_child(ok)
	_corner(dim, card, Control.PRESET_CENTER, Vector2.ZERO)
	_show("intro_card", dim)
	K.pop_in(card)


func _vessel_preview(type: int) -> SubViewportContainer:
	var box := SubViewportContainer.new()
	box.stretch = true
	box.custom_minimum_size = Vector2(460, 240)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	box.add_child(vp)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.3 + VesselData.info(type)["length"] * 0.42
	cam.position = Vector3(0, 3.2, 3.4)
	cam.rotation_degrees.x = -42
	vp.add_child(cam)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	vp.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("cfe9ff")
	env.environment.ambient_light_energy = 0.8
	vp.add_child(env)
	_preview = MeshInstance3D.new()
	_preview.mesh = ShipModels.mesh(type)
	_preview.rotation_degrees.y = 30
	vp.add_child(_preview)
	return box


# --- Spawn warnings & tutorial ---------------------------------------------------

func _on_spawn_warning(gate_pos: Vector2, gate_dir: Vector2, color: Color, duration: float) -> void:
	var m := SpawnMarker.new()
	m.color = color
	var vp := _root.get_viewport_rect().size
	var p := game.screen_point(gate_pos)
	var into := game.screen_point(gate_pos + gate_dir) - p
	m.angle = into.angle()
	m.position = p.clamp(Vector2(70, 160), vp - Vector2(70, 80))
	if m.position.x < 280 and m.position.y > vp.y - 300:
		m.position.x = 280.0
	_markers.add_child(m)
	var t := m.create_tween()
	t.tween_interval(duration)
	t.tween_property(m, "modulate:a", 0.0, 0.3)
	t.tween_callback(m.queue_free)


func _clear_markers() -> void:
	for c in _markers.get_children():
		c.queue_free()
	if _tutorial:
		_tutorial.queue_free()
		_tutorial = null


func _on_first_vessel(v: Vessel, port: Port) -> void:
	if GameState.best_level > 1 and GameState.total_docked > 0:
		return
	_tutorial = Tutorial.new()
	_tutorial.setup(game, v, port)
	_markers.add_child(_tutorial)


# --- Pause / results ---------------------------------------------------------------

func show_pause() -> void:
	var dim := K.dimmer()
	var card := K.card()
	var v := K.vbox(26)
	card.add_child(v)
	v.add_child(K.label("PAUSED", 84, Color.WHITE, 22))
	v.add_child(_toggles())
	var resume := K.button("RESUME", K.GREEN, Vector2(460, 130), 58, "res://assets/ui/play.svg")
	resume.pressed.connect(resume_pressed.emit)
	v.add_child(resume)
	var row := K.hbox(24)
	var restart := K.icon_button("res://assets/ui/restart.svg", K.ORANGE, 120)
	restart.pressed.connect(retry_pressed.emit)
	var home := K.icon_button("res://assets/ui/home.svg", K.BLUE, 120)
	home.pressed.connect(home_pressed.emit)
	row.add_child(restart)
	row.add_child(home)
	v.add_child(row)
	_corner(dim, card, Control.PRESET_CENTER, Vector2.ZERO)
	_show("pause", dim)
	K.pop_in(card)


func show_complete(level: int, stars: int) -> void:
	_clear_markers()
	var dim := K.dimmer(0.35)
	var card := K.card()
	var v := K.vbox(18)
	card.add_child(v)
	v.add_child(K.label("LEVEL %d" % level, 64, Color.WHITE, 18))
	v.add_child(K.label("HARBOR CLEAR!", 88, K.ORANGE, 24))
	var row := K.hbox(10)
	for i in 3:
		var s := K.icon("res://assets/ui/star.svg" if i < stars else "res://assets/ui/star_empty.svg", 120 if i == 1 else 100)
		s.modulate.a = 0.0
		row.add_child(s)
		var t := s.create_tween()
		t.tween_interval(0.35 + i * 0.22)
		t.tween_property(s, "modulate:a", 1.0, 0.12)
		if i < stars:
			t.tween_callback(func() -> void: Audio.play("star", 0.0, 1.0 + i * 0.12))
	v.add_child(row)
	var next := K.button("NEXT", K.GREEN, Vector2(480, 140), 64, "res://assets/ui/next.svg")
	next.pressed.connect(func() -> void:
		next.disabled = true
		next_pressed.emit())
	v.add_child(next)
	_corner(dim, card, Control.PRESET_CENTER, Vector2.ZERO)
	_show("complete", dim)
	K.pop_in(card)


func show_failed(docked: int, target: int, can_revive: bool) -> void:
	_clear_markers()
	var dim := K.dimmer()
	var card := K.card()
	var v := K.vbox(22)
	card.add_child(v)
	v.add_child(K.label("COLLISION!", 96, K.RED, 26))
	v.add_child(K.label("Docked %d of %d ships" % [docked, target], 46, K.INK, 0))
	if can_revive:
		var revive := K.button("CONTINUE", K.GREEN, Vector2(560, 150), 64, "res://assets/ui/play.svg")
		revive.pressed.connect(func() -> void:
			revive.disabled = true
			revive_pressed.emit())
		v.add_child(revive)
		v.add_child(K.label("Watch a short video for one more chance", 34, Color("5a6b7d"), 0))
		revive.resized.connect(func() -> void: revive.pivot_offset = revive.size * 0.5, CONNECT_ONE_SHOT)
		var pulse := revive.create_tween().set_loops()
		pulse.tween_property(revive, "scale", Vector2(1.05, 1.05), 0.6).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(revive, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_SINE)
	var retry := K.button("TRY AGAIN", K.ORANGE, Vector2(500, 140), 60, "res://assets/ui/restart.svg")
	retry.pressed.connect(retry_pressed.emit)
	v.add_child(retry)
	var home := K.button("HOME", K.BLUE, Vector2(320, 110), 46, "res://assets/ui/home.svg")
	home.pressed.connect(home_pressed.emit)
	v.add_child(home)
	_corner(dim, card, Control.PRESET_CENTER, Vector2.ZERO)
	_show("failed", dim)
	K.pop_in(card)


# --- Settings & rating -------------------------------------------------------------

func _toggles() -> HBoxContainer:
	var row := K.hbox(28)
	for item in [["music_on", "music.svg"], ["sfx_on", "sound.svg"], ["vibration_on", "vibrate.svg"]]:
		var key: String = item[0]
		var b := K.icon_button("res://assets/ui/" + item[1], K.GREEN if GameState.get(key) else K.GREY, 120)
		b.pressed.connect(func() -> void:
			GameState.set_setting(key, not GameState.get(key))
			K.style_button(b, K.GREEN if GameState.get(key) else K.GREY, 60)
			for st in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
				var sb: StyleBoxFlat = b.get_theme_stylebox(st)
				sb.content_margin_left = 26
				sb.content_margin_right = 26
				sb.content_margin_top = 19)
		row.add_child(b)
	return row


func show_settings() -> void:
	var dim := K.dimmer()
	var card := K.card()
	var v := K.vbox(24)
	card.add_child(v)
	var header := K.hbox(20)
	var title := K.label("SETTINGS", 80, Color.WHITE, 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	v.add_child(header)
	v.add_child(_toggles())
	var rate := K.button("RATE US", K.ORANGE, Vector2(520, 116), 48, "res://assets/ui/star.svg")
	rate.pressed.connect(GameState.open_store)
	v.add_child(rate)
	var privacy := K.button("PRIVACY POLICY", K.BLUE, Vector2(520, 104), 40, "res://assets/ui/doc.svg")
	privacy.pressed.connect(func() -> void: OS.shell_open(GameState.PRIVACY_URL))
	v.add_child(privacy)
	if Ads.privacy_options_required():
		var consent := K.button("AD PRIVACY OPTIONS", K.BLUE, Vector2(520, 104), 38, "res://assets/ui/shield.svg")
		consent.pressed.connect(Ads.show_privacy_options)
		v.add_child(consent)
	v.add_child(K.label("Version " + str(ProjectSettings.get_setting("application/config/version")), 30, Color("7b8ea3"), 0))
	var close := K.icon_button("res://assets/ui/close.svg", K.RED, 96)
	close.pressed.connect(show_menu)
	header.add_child(close)
	_corner(dim, card, Control.PRESET_CENTER, Vector2.ZERO)
	_show("settings", dim)
	K.pop_in(card)


## Opt-in rewarded ad offer (AdMob policy: rewarded ads must be user-initiated).
func show_reward_offer(watch: Callable, skip: Callable) -> void:
	var dim := K.dimmer()
	var card := K.card()
	var v := K.vbox(20)
	card.add_child(v)
	v.add_child(K.label("BONUS LIFEBUOY!", 72, K.ORANGE, 20))
	var buoy := K.icon("res://assets/ui/lifebuoy.svg", 170)
	v.add_child(buoy)
	var spin := buoy.create_tween().set_loops()
	buoy.pivot_offset = Vector2(85, 85)
	spin.tween_property(buoy, "rotation", TAU, 4.0).from(0.0)
	v.add_child(K.label("Watch a short video to get a lifebuoy.", 40, K.INK, 0))
	v.add_child(K.label("It saves you from one collision!", 40, K.INK, 0))
	var row := K.hbox(24)
	var no := K.button("NO THANKS", K.GREY, Vector2(330, 116), 42)
	var yes := K.button("WATCH", K.GREEN, Vector2(380, 116), 52, "res://assets/ui/play.svg")
	no.pressed.connect(func() -> void:
		hide_overlays()
		skip.call())
	yes.pressed.connect(func() -> void:
		hide_overlays()
		watch.call())
	row.add_child(no)
	row.add_child(yes)
	v.add_child(row)
	_corner(dim, card, Control.PRESET_CENTER, Vector2.ZERO)
	_show("reward", dim)
	K.pop_in(card)


func show_rate(then: Callable) -> void:
	var dim := K.dimmer()
	var card := K.card()
	var v := K.vbox(22)
	card.add_child(v)
	v.add_child(K.label("ENJOYING THE VOYAGE?", 64, Color.WHITE, 18))
	var stars := K.hbox(8)
	for i in 5:
		stars.add_child(K.icon("res://assets/ui/star.svg", 84))
	v.add_child(stars)
	v.add_child(K.label("Rate us on Google Play - it really helps!", 38, K.INK, 0))
	var row := K.hbox(24)
	var later := K.button("LATER", K.GREY, Vector2(300, 116), 46)
	var rate := K.button("RATE NOW", K.ORANGE, Vector2(380, 116), 50)
	later.pressed.connect(func() -> void:
		GameState.rate_prompted = true
		GameState.save()
		then.call())
	rate.pressed.connect(func() -> void:
		GameState.open_store()
		then.call())
	row.add_child(later)
	row.add_child(rate)
	v.add_child(row)
	_corner(dim, card, Control.PRESET_CENTER, Vector2.ZERO)
	_show("rate", dim)
	K.pop_in(card)
