extends Node2D

# Static world-space grid so player/swarm speed is readable against the dark background.

const TP = preload("res://scripts/theme_palette.gd")

@export var cell_size: float = 120.0
@export var extent: float = 3000.0    # grid covers ±extent from world origin

var line_color: Color = Color(0.10, 0.14, 0.22, 1.0)
var axis_color: Color = Color(0.16, 0.22, 0.34, 1.0)  # brighter lines through origin


func _ready() -> void:
	z_index = -10
	refresh_theme()


func refresh_theme() -> void:
	line_color = TP.P["grid_line"]
	axis_color = TP.P["grid_axis"]
	queue_redraw()


func _draw() -> void:
	var n: int = int(extent / cell_size)
	for i in range(-n, n + 1):
		var p: float = i * cell_size
		var c: Color = axis_color if i == 0 else line_color
		draw_line(Vector2(p, -extent), Vector2(p, extent), c, 1.0)
		draw_line(Vector2(-extent, p), Vector2(extent, p), c, 1.0)
