class_name Tutorial
extends Control
## First-level hint: a hand drags from the ship to its matching port.

const HAND := preload("res://assets/ui/hand.svg")

var _game: Game
var _vessel: Vessel
var _port: Port
var _t := 0.0
var _hint: Label


func setup(game: Game, vessel: Vessel, port: Port) -> void:
	_game = game
	_vessel = vessel
	_port = port
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_hint = UiKit.label("Drag from the ship to its matching port!", 50, Color.WHITE, 16)
	add_child(_hint)
	_hint.anchor_left = 0.5
	_hint.anchor_right = 0.5
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_top = -230
	_hint.offset_bottom = -230
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN


func _process(delta: float) -> void:
	if not is_instance_valid(_vessel) or _vessel.target != null or _vessel.state != Vessel.State.SAILING:
		queue_free()
		return
	_t = fmod(_t + delta / 1.8, 1.0)
	queue_redraw()


func _draw() -> void:
	var a := _game.screen_point(_vessel.pos)
	var b := _game.screen_point(_port.dock)
	var k := smoothstep(0.1, 0.85, _t)
	var p := a.lerp(b, k)
	var col := Color(VesselData.port_color(_vessel.port), 0.85)
	var steps := 24
	for i in steps:
		if i % 2 == 0 and float(i) / steps < k:
			draw_line(a.lerp(b, float(i) / steps), a.lerp(b, float(i + 1) / steps), col, 10.0, true)
	draw_texture_rect(HAND, Rect2(p + Vector2(-22, -8), Vector2(110, 110)), false, Color(1, 1, 1, 1.0 - smoothstep(0.85, 1.0, _t)))
