class_name SpawnMarker
extends Control
## Pulsing edge marker: a ship of this colour is about to enter from here.
## Pauses with the game and stays up until that ship has actually sailed in.

var color := Color.WHITE
var angle := 0.0
var game: Game
var gate := -1
var min_time := 2.0
var _t := 0.0
var _leaving := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _leaving or _t < min_time:
		return
	if is_instance_valid(game) and game.mode == Game.Mode.PLAY and game.gate_waiting(gate) and _t < 15.0:
		return
	_leaving = true
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.3)
	t.tween_callback(queue_free)


func _draw() -> void:
	var pulse := 1.0 + 0.15 * sin(_t * 12.0)
	var r := 44.0 * pulse
	draw_circle(Vector2.ZERO, r + 8.0, Color(0.04, 0.15, 0.27, 0.8))
	draw_circle(Vector2.ZERO, r, color)
	draw_arc(Vector2.ZERO, r + 22.0 + fmod(_t * 60.0, 30.0), 0.0, TAU, 40, Color(color, 0.6 - fmod(_t * 60.0, 30.0) / 50.0), 5.0, true)
	var d := Vector2.from_angle(angle)
	var n := d.orthogonal()
	var arrow := Color("0b2545") if color.get_luminance() > 0.8 else Color.WHITE   # visible on white (tug) markers
	draw_colored_polygon(PackedVector2Array([d * (r * 0.62), -d * r * 0.35 + n * r * 0.45, -d * r * 0.1, -d * r * 0.35 - n * r * 0.45]), arrow)
