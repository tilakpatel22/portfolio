class_name SpawnMarker
extends Control
## Pulsing edge marker: a ship of this colour is about to enter from here.

var color := Color.WHITE
var angle := 0.0
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Audio.play("warning", 0.0)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var pulse := 1.0 + 0.15 * sin(_t * 12.0)
	var r := 44.0 * pulse
	draw_circle(Vector2.ZERO, r + 8.0, Color(0.04, 0.15, 0.27, 0.8))
	draw_circle(Vector2.ZERO, r, color)
	draw_arc(Vector2.ZERO, r + 22.0 + fmod(_t * 60.0, 30.0), 0.0, TAU, 40, Color(color, 0.6 - fmod(_t * 60.0, 30.0) / 50.0), 5.0, true)
	var d := Vector2.from_angle(angle)
	var n := d.orthogonal()
	var tip := d * (r * 0.62)
	draw_colored_polygon(PackedVector2Array([tip, -d * r * 0.35 + n * r * 0.45, -d * r * 0.1, -d * r * 0.35 - n * r * 0.45]), Color.WHITE)
