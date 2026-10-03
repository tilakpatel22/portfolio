extends Node
## Root: sets up the 2.5D camera/lighting and drives the menu -> play -> result flow.

const PITCH := 55.0
const CAM_DIST := 40.0

var camera := Camera3D.new()
var game := Game.new()
var ui: GameUI
var _playing := false


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	_setup_scene()
	ui = GameUI.new()
	add_child(ui)
	ui.game = game
	ui.play_pressed.connect(start_level)
	ui.next_pressed.connect(_on_next)
	ui.retry_pressed.connect(start_level)
	ui.home_pressed.connect(go_menu)
	ui.pause_pressed.connect(pause)
	ui.resume_pressed.connect(resume)
	ui.revive_pressed.connect(_on_revive)
	game.level_won.connect(_on_won)
	game.level_lost.connect(_on_lost)
	game.crashed.connect(shake)
	get_viewport().size_changed.connect(_fit_camera)
	_fit_camera()
	go_menu()


func _setup_scene() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0b5470")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("cfe9ff")
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, -38, 0)
	sun.light_color = Color("fff1d6")
	sun.light_energy = 0.82
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 80.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	add_child(sun)

	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.rotation_degrees.x = -PITCH
	camera.position = Vector3(0, sin(deg_to_rad(PITCH)) * CAM_DIST, cos(deg_to_rad(PITCH)) * CAM_DIST)
	camera.near = 1.0
	camera.far = 120.0
	add_child(camera)
	game.camera = camera
	add_child(game)


## Fit the 32x22 playfield on any aspect ratio (phones, tablets, foldables).
func _fit_camera() -> void:
	var vp := get_viewport().get_visible_rect().size
	var aspect := vp.x / maxf(vp.y, 1.0)
	var pf := LevelData.PLAYFIELD
	camera.size = maxf(pf.size.y * sin(deg_to_rad(PITCH)), pf.size.x / aspect) * 1.06
	await get_tree().process_frame
	var r := Rect2(game.ground_point(Vector2.ZERO), Vector2.ZERO)
	for c in [Vector2(vp.x, 0), Vector2(0, vp.y), vp]:
		r = r.expand(game.ground_point(c))
	game.visible_rect = r


func go_menu() -> void:
	get_tree().paused = false
	Audio.set_muffled(false)
	_playing = false
	ui.fade(func() -> void:
		game.load_level(GameState.level, true)
		ui.show_menu())
	Audio.play_music("menu")


func start_level() -> void:
	get_tree().paused = false
	Audio.set_muffled(false)
	ui.fade(func() -> void:
		game.load_level(GameState.level)
		_playing = true
		ui.show_hud(game.data))
	Audio.play_music(Audio.track_for_level(GameState.level, LevelGenerator.is_peak(GameState.level)))


func _on_won() -> void:
	_playing = false
	ui.show_complete(game.data.level, game.stars())


func _on_lost() -> void:
	_playing = false
	Audio.stinger("lose")
	ui.show_failed(game.docked, game.data.target, game.can_revive() and Ads.rewarded_ready())


func _on_revive() -> void:
	Ads.show_rewarded(func(earned: bool) -> void:
		if earned and game.can_revive():
			game.revive()
			_playing = true
			ui.hide_overlays()
			Audio.stinger("reward")
		else:
			ui.show_failed(game.docked, game.data.target, false))


func _on_next() -> void:
	var completed := GameState.level
	GameState.complete_level()
	if GameState.should_prompt_rate():
		ui.show_rate(start_level)
	elif Ads.is_reward_level(completed) and Ads.rewarded_ready():
		ui.show_reward_offer(_watch_reward, func() -> void: Ads.show_interstitial(start_level))
	else:
		Ads.show_interstitial(start_level)


func _watch_reward() -> void:
	Ads.show_rewarded(func(earned: bool) -> void:
		if earned:
			GameState.lifebuoys += 1
			GameState.save()
			Audio.stinger("reward")
		start_level())


func pause() -> void:
	if _playing and not get_tree().paused:
		get_tree().paused = true
		Audio.set_muffled(true)
		ui.show_pause()


func resume() -> void:
	get_tree().paused = false
	Audio.set_muffled(false)
	ui.hide_overlays()


func shake(strength := 0.35) -> void:
	var t := create_tween()
	for i in 6:
		t.tween_property(camera, "h_offset", randf_range(-strength, strength), 0.04)
		t.parallel().tween_property(camera, "v_offset", randf_range(-strength, strength), 0.04)
	t.tween_property(camera, "h_offset", 0.0, 0.05)
	t.parallel().tween_property(camera, "v_offset", 0.0, 0.05)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			pause()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			if not ui.back():
				if _playing:
					pause()
				else:
					get_tree().quit()
		NOTIFICATION_WM_CLOSE_REQUEST:
			GameState.save()
			get_tree().quit()
