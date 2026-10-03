class_name LevelData
extends RefCounted
## Output of LevelGenerator: everything needed to build and run a level.

const PLAYFIELD := Rect2(-16.0, -11.0, 32.0, 22.0)

var level := 1
var rng_seed := 0
var attempts := 0                        # generation attempts used; -1 = fallback map
var difficulty := 0.0
var archetype := "island"
var target := 5
var max_active := 2
var spawn_interval := 6.5
var speed_mult := 1.0
var pair_chance := 0.0
var warn_time := 2.0
var current := Vector2.ZERO
var modifiers: Array[String] = []
var pool: Array[Dictionary] = []          # {type, weight}
var new_type := -1
var islands: Array[PackedVector2Array] = []
var island_kinds: Array[String] = []      # "island" | "mainland" | "rock"
var ports: Array[Dictionary] = []         # {pos, dir, coast, port}
var gates: Array[Dictionary] = []         # {pos, dir}
var grid: LandGrid


func has_mod(m: String) -> bool:
	return modifiers.has(m)


func summary() -> String:
	return "L%d d=%.2f %s target=%d active=%d every=%.1fs speed=%.2f ports=%d gates=%d pool=%d mods=%s" % [
		level, difficulty, archetype, target, max_active, spawn_interval, speed_mult,
		ports.size(), gates.size(), pool.size(), modifiers]
