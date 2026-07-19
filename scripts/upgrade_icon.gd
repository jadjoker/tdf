extends Control

# Procedurally drawn icon for an upgrade card. 56×56, accent-colored,
# anti-aliased line art — matches the game's vector language.

var icon_id: String = ""
var accent: Color = Color(0.55, 2.4, 1.3)

const W := 2.5


func _ready() -> void:
	custom_minimum_size = Vector2(56.0, 56.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := size * 0.5
	match icon_id:
		"damage":
			# spiked burst
			for i in range(8):
				var a: float = TAU * float(i) / 8.0
				var dir := Vector2(cos(a), sin(a))
				var r_out: float = 24.0 if i % 2 == 0 else 15.0
				draw_line(c + dir * 6.0, c + dir * r_out, accent, W, true)
			draw_circle(c, 5.0, accent, false, W, true)
		"speed":
			# triple chevrons
			for i in range(3):
				var x: float = c.x - 16.0 + float(i) * 12.0
				draw_polyline(PackedVector2Array([
					Vector2(x, c.y - 14.0), Vector2(x + 11.0, c.y), Vector2(x, c.y + 14.0),
				]), accent, W, true)
		"net":
			# reach ring with outward ticks
			draw_circle(c, 13.0, accent, false, W, true)
			for i in range(4):
				var a: float = TAU * float(i) / 4.0 + TAU / 8.0
				var dir := Vector2(cos(a), sin(a))
				draw_line(c + dir * 15.0, c + dir * 23.0, accent, W, true)
		"magnet":
			# horseshoe
			draw_arc(c + Vector2(0.0, -3.0), 14.0, PI, TAU, 24, accent, W + 1.0, true)
			draw_line(c + Vector2(-14.0, -3.0), c + Vector2(-14.0, 14.0), accent, W + 1.0, true)
			draw_line(c + Vector2(14.0, -3.0), c + Vector2(14.0, 14.0), accent, W + 1.0, true)
			draw_line(c + Vector2(-18.0, 14.0), c + Vector2(-10.0, 14.0), accent, W + 1.0, true)
			draw_line(c + Vector2(10.0, 14.0), c + Vector2(18.0, 14.0), accent, W + 1.0, true)
		"combo":
			# linked rings
			draw_circle(c + Vector2(-8.0, 0.0), 10.0, accent, false, W, true)
			draw_circle(c + Vector2(8.0, 0.0), 10.0, accent, false, W, true)
		"loot":
			# orb cluster
			draw_circle(c + Vector2(-9.0, 6.0), 7.0, accent, false, W, true)
			draw_circle(c + Vector2(9.0, 6.0), 7.0, accent, false, W, true)
			draw_circle(c + Vector2(0.0, -8.0), 7.0, accent, false, W, true)
		"wake":
			# burning ribbon behind a head
			var wave := PackedVector2Array()
			for i in range(9):
				var x: float = c.x - 22.0 + float(i) * 4.6
				wave.append(Vector2(x, c.y + sin(float(i) * 1.1) * 8.0))
			draw_polyline(wave, accent, W + 0.5, true)
			draw_circle(c + Vector2(20.0, sin(8.8) * 8.0), 5.5, accent, true, -1.0, true)
		"welcome":
			# concussive greeting: expanding arcs around a recruit
			draw_circle(c, 4.5, accent, true, -1.0, true)
			draw_arc(c, 11.0, 0.0, TAU, 24, accent, W, true)
			draw_arc(c, 18.0, -0.6, 1.8, 16, accent, W, true)
			draw_arc(c, 18.0, PI - 0.6, PI + 1.8, 16, accent, W, true)
		"comet":
			# the leader with speed lines
			draw_circle(c + Vector2(8.0, 0.0), 9.0, accent, false, W + 0.5, true)
			for i in range(3):
				var y: float = c.y - 7.0 + float(i) * 7.0
				draw_line(Vector2(c.x - 22.0, y), Vector2(c.x - 6.0, y), accent, W - 0.5, true)
		_:
			draw_circle(c, 14.0, accent, false, W, true)
