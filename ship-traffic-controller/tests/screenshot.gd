extends SceneTree
## Renders screenshots: godot --path . -s tests/screenshot.gd -- <menu|play> <level> <seconds> <out.png>


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := args[0] if args.size() > 0 else "menu"
	var level := int(args[1]) if args.size() > 1 else 1
	var secs := float(args[2]) if args.size() > 2 else 3.0
	var out := args[3] if args.size() > 3 else "user://shot.png"
	_run(mode, level, secs, out)


func _run(mode: String, level: int, secs: float, out: String) -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(1.0).timeout
	var gs := root.get_node("GameState")
	gs.level = level
	gs.intro_seen = 999
	if mode == "play":
		main.start_level()
		await create_timer(1.0).timeout
		if level > 1:
			gs.total_docked = 5
	else:
		main.go_menu()
	await create_timer(secs).timeout
	if mode == "play":
		# Draw a course for every ship so the path rendering shows up.
		var game = main.game
		for v in game.vessels:
			for port in game.world.ports:
				if port.accepts(v.port):
					v.start_path()
					var steps := 12
					for i in range(1, steps):
						var p: Vector2 = v.pos.lerp(port.approach(), float(i) / steps)
						if game.data.grid.distance(p) > 0.4:
							v.add_point(p)
					v.snap_to(port)
					break
		await create_timer(0.3).timeout
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out)
	print("saved ", out)
	quit()
