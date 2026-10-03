class_name ShipModels
extends RefCounted
## Procedural low-poly vessel meshes. Bow points to -Z, waterline at y = 0.

const T := VesselData.Type
const WHITE := Color("f7f7f2")
const WOOD := Color("c58b52")
const DARK := Color("2c3440")
const GLASS := Color("2d4a66")
const RED := Color("e0463c")
const SCALE := 1.15  # models are authored at base size, then scaled to the gameplay hull size

static var _cache := {}


static func mesh(type: int) -> ArrayMesh:
	if not _cache.has(type):
		_cache[type] = _build(type)
	return _cache[type]


static func _build(type: int) -> ArrayMesh:
	var info := VesselData.info(type)
	var L: float = info["length"] / SCALE
	var W: float = info["width"] / SCALE
	var accent := VesselData.port_color(info["port"])
	var m := MeshBuilder.new()
	m.xform = Transform3D(Basis.from_scale(Vector3.ONE * SCALE), Vector3.ZERO)
	match type:
		T.SAILBOAT:
			_hull(m, L, W, 0.14, WHITE, accent, Color("e9dcc4"), 0.4)
			m.box(Vector3(0, 0.2, 0.18), Vector3(W * 0.7, 0.12, L * 0.3), WHITE, Color("ffffff"))
			m.cylinder(Vector3(0, 0.75, -0.05), 0.025, 1.2, WOOD)
			m.panel(Vector3(0, 1.3, -0.07), Vector3(0, 0.22, -0.07), Vector3(0, 0.22, 0.42), Color("fffdf5"))
			m.panel(Vector3(0, 1.1, -0.1), Vector3(0, 0.22, -0.1), Vector3(0, 0.22, -0.48), accent.lightened(0.35))
		T.TRAWLER:
			_hull(m, L, W, 0.18, Color("2f7dd1"), accent, Color("d9d2c3"), 0.3)
			m.box(Vector3(0, 0.36, -0.12), Vector3(W * 0.75, 0.32, 0.42), WHITE, Color("e6e6e6"))
			m.box(Vector3(0, 0.38, -0.34), Vector3(W * 0.7, 0.08, 0.02), GLASS)
			m.cylinder(Vector3(0, 0.75, 0.25), 0.03, 0.9, DARK)
			m.box(Vector3(0, 0.95, 0.25), Vector3(0.9, 0.04, 0.04), DARK)
			m.box(Vector3(0, 0.24, 0.45), Vector3(W * 0.6, 0.1, 0.3), Color("3e8f4b"))
		T.FERRY:
			_hull(m, L, W, 0.2, WHITE, accent, Color("cfd6dd"), 0.28)
			m.box(Vector3(0, 0.38, 0.05), Vector3(W * 0.82, 0.3, L * 0.62), WHITE, Color("eef2f5"))
			m.box(Vector3(0, 0.4, 0.05), Vector3(W * 0.84, 0.08, L * 0.58), GLASS)
			m.box(Vector3(0, 0.62, -0.05), Vector3(W * 0.6, 0.2, L * 0.36), WHITE, accent)
			m.cylinder(Vector3(0, 0.82, 0.35), 0.09, 0.26, accent, 8, DARK)
		T.SPEEDBOAT:
			_hull(m, L, W, 0.14, Color("ff5a5f"), WHITE, Color("f2f2f2"), 0.45)
			m.box(Vector3(0, 0.22, 0.05), Vector3(W * 0.7, 0.08, 0.3), Color("e9e9e9"))
			m.quad(Vector3(-W * 0.38, 0.17, -0.12), Vector3(W * 0.38, 0.17, -0.12), Vector3(W * 0.32, 0.32, -0.02), Vector3(-W * 0.32, 0.32, -0.02), GLASS, Vector3(0, 1, -1))
			m.box(Vector3(0, 0.2, 0.42), Vector3(0.12, 0.14, 0.08), DARK)
		T.CONTAINER:
			_hull(m, L, W, 0.22, Color("1f4e8c"), accent, Color("8a2c2c"), 0.2)
			m.box(Vector3(0, 0.56, L * 0.36), Vector3(W * 0.9, 0.62, 0.36), WHITE, Color("e8e8e8"))
			m.box(Vector3(0, 0.78, L * 0.36 - 0.18), Vector3(W * 0.92, 0.08, 0.02), GLASS)
			m.cylinder(Vector3(0, 0.98, L * 0.42), 0.07, 0.22, RED, 6, DARK)
			var cols := [Color("e94f37"), Color("f6bd60"), Color("3fa7d6"), Color("59cd90"), Color("ee6c4d"), Color("8e7dbe")]
			var rows := 5
			for r in rows:
				for c in 2:
					var h := 1 + (r * 7 + c * 3) % 2
					var col: Color = cols[(r * 2 + c) % cols.size()]
					var z := -L * 0.28 + r * (L * 0.56 / rows)
					m.box(Vector3((c - 0.5) * W * 0.44, 0.22 + h * 0.09, z), Vector3(W * 0.42, h * 0.18, L * 0.1), col, col.lightened(0.15))
		T.TUG:
			_hull(m, L, W, 0.2, RED, WHITE, Color("6b4f3a"), 0.22)
			m.box(Vector3(0, 0.0 + 0.2, 0), Vector3(W * 1.12, 0.07, L * 0.92), DARK)
			m.box(Vector3(0, 0.45, -0.05), Vector3(W * 0.6, 0.4, 0.34), WHITE, Color("dddddd"))
			m.box(Vector3(0, 0.55, -0.22), Vector3(W * 0.62, 0.1, 0.02), GLASS)
			m.cylinder(Vector3(0, 0.75, 0.2), 0.07, 0.3, Color("ffd23f"), 8, DARK)
		T.CRUISE:
			_hull(m, L, W, 0.24, WHITE, accent, Color("1f3a5f"), 0.25)
			m.box(Vector3(0, 0.42, 0.1), Vector3(W * 0.86, 0.36, L * 0.7), WHITE, Color("f4f4f4"))
			m.box(Vector3(0, 0.46, 0.1), Vector3(W * 0.88, 0.07, L * 0.66), GLASS)
			m.box(Vector3(0, 0.68, 0.18), Vector3(W * 0.72, 0.18, L * 0.52), WHITE, Color("f4f4f4"))
			m.box(Vector3(0, 0.7, 0.18), Vector3(W * 0.74, 0.05, L * 0.48), GLASS)
			m.box(Vector3(0, 0.78, 0.0), Vector3(W * 0.36, 0.02, 0.4), Color("4fc3f7"))
			m.cylinder(Vector3(0, 1.0, 0.65), 0.13, 0.36, RED, 8, DARK)
			m.box(Vector3(0, 0.88, -0.55), Vector3(W * 0.6, 0.22, 0.3), WHITE)
		T.TANKER:
			_hull(m, L, W, 0.22, Color("2b2d42"), accent, Color("8d2b2b"), 0.18)
			m.tube(Vector3(-0.12, 0.3, -0.2), 0.04, L * 0.66, Color("c9c9c9"), 6)
			m.tube(Vector3(0.12, 0.3, -0.2), 0.04, L * 0.66, Color("c9c9c9"), 6)
			for i in 3:
				m.box(Vector3(0, 0.3, -L * 0.3 + i * L * 0.2), Vector3(W * 0.7, 0.08, 0.06), Color("9a9a9a"))
			m.box(Vector3(0, 0.58, L * 0.37), Vector3(W * 0.9, 0.6, 0.34), WHITE, Color("e8e8e8"))
			m.box(Vector3(0, 0.78, L * 0.37 - 0.17), Vector3(W * 0.92, 0.08, 0.02), GLASS)
			m.cylinder(Vector3(0, 1.0, L * 0.43), 0.07, 0.24, RED, 6, DARK)
		T.PATROL:
			_hull(m, L, W, 0.18, Color("7d8a96"), accent, Color("5f6b75"), 0.38)
			m.box(Vector3(0, 0.38, 0.05), Vector3(W * 0.7, 0.3, 0.5), Color("aab4bd"), Color("c1c9d0"))
			m.box(Vector3(0, 0.44, -0.21), Vector3(W * 0.72, 0.08, 0.02), GLASS)
			m.cylinder(Vector3(0, 0.75, 0.15), 0.025, 0.5, DARK)
			m.box(Vector3(0, 0.95, 0.15), Vector3(0.3, 0.03, 0.06), DARK)
			m.cylinder(Vector3(0, 0.26, -0.42), 0.09, 0.12, Color("5f6b75"))
			m.box(Vector3(0, 0.3, -0.55), Vector3(0.03, 0.03, 0.26), DARK)
		T.SUBMARINE:
			m.sphere(Vector3(0, 0.02, 0), Vector3(W * 0.5, 0.2, L * 0.5), Color("39424e"), 4, 10)
			m.box(Vector3(0, 0.3, -0.1), Vector3(0.16, 0.34, 0.42), Color("2b333d"), accent)
			m.box(Vector3(0, 0.32, -0.12), Vector3(0.5, 0.03, 0.12), Color("2b333d"))
			m.box(Vector3(0, 0.1, L * 0.44), Vector3(0.5, 0.03, 0.1), Color("2b333d"))
			m.cylinder(Vector3(0, 0.6, -0.15), 0.015, 0.3, DARK)
	return m.commit()


## Hull: pointed bow, tapered bottom, coloured sheer stripe and deck.
static func _hull(m: MeshBuilder, L: float, W: float, h: float, side: Color, stripe: Color, deck: Color, bow: float) -> void:
	var w := W * 0.5
	var z0 := L * 0.5
	var zb := -L * 0.5 + L * bow
	var outline := PackedVector2Array([
		Vector2(-w * 0.86, z0), Vector2(w * 0.86, z0), Vector2(w, z0 - L * 0.15),
		Vector2(w, zb), Vector2(w * 0.72, zb - (zb + L * 0.5) * 0.55), Vector2(0, -L * 0.5),
		Vector2(-w * 0.72, zb - (zb + L * 0.5) * 0.55), Vector2(-w, zb), Vector2(-w, z0 - L * 0.15),
	])
	m.prism(outline, -0.12, h - 0.05, side, side, 0.72)
	m.prism(outline, h - 0.05, h, stripe, deck)
