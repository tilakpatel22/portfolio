extends SceneTree
## Headless check: godot --headless -s tests/test_generator.gd


func _init() -> void:
	var failures := 0
	var t_total := 0
	var t_max := 0
	var archetypes := {}
	for level in range(1, 151):
		var t0 := Time.get_ticks_msec()
		var d := LevelGenerator.generate(level)
		var dt := Time.get_ticks_msec() - t0
		t_total += dt
		t_max = maxi(t_max, dt)
		archetypes[d.archetype] = archetypes.get(d.archetype, 0) + 1
		var errs := _check(d)
		if level <= 12 or level % 10 == 0 or not errs.is_empty():
			print("%s  (%d ms)%s" % [d.summary(), dt, "" if errs.is_empty() else "  FAIL: " + ", ".join(errs)])
		if not errs.is_empty():
			failures += 1
	var a := LevelGenerator.generate(37)
	var b := LevelGenerator.generate(37)
	if a.rng_seed != b.rng_seed or a.islands.size() != b.islands.size() or a.ports[0]["pos"] != b.ports[0]["pos"]:
		print("FAIL: generator not deterministic")
		failures += 1
	print("archetypes: ", archetypes)
	print("avg %.0f ms, max %d ms" % [t_total / 150.0, t_max])
	print("RESULT: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(1 if failures else 0)


func _check(d: LevelData) -> Array[String]:
	var errs: Array[String] = []
	if d.pool.size() < 2: errs.append("pool<2")
	if d.gates.size() < 2: errs.append("gates<2")
	var have := {}
	for p in d.ports:
		have[p["port"]] = true
	for e in d.pool:
		var pc := VesselData.port_of(e["type"])
		if pc != VesselData.Port.ANY and not have.has(pc):
			errs.append("no port for " + VesselData.TYPES[e["type"]]["name"])
	if d.new_type >= 0 and not d.pool.any(func(e: Dictionary) -> bool: return e["type"] == d.new_type):
		errs.append("new type missing")
	return errs
