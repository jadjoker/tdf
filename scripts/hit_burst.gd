extends Node2D

# One-shot expanding ring burst on enemy death. Self-frees.

const LIFETIME := 0.35

var color: Color = Color(2.6, 0.8, 0.5)   # HDR — blooms as it fades
var scale_mult: float = 1.0               # 1.0 = death burst, ~0.45 = whip-crack spark
var _t: float = 0.0


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFETIME:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var f: float = _t / LIFETIME
	var fade: float = 1.0 - f
	var c := Color(color.r, color.g, color.b, fade * 0.9)
	draw_arc(Vector2.ZERO, (12.0 + f * 46.0) * scale_mult, 0.0, TAU, 32, c, 1.0 + 3.0 * fade, true)
	draw_arc(Vector2.ZERO, (8.0 + f * 30.0) * scale_mult, 0.0, TAU, 24, Color(c.r, c.g, c.b, c.a * 0.5), 2.0, true)
