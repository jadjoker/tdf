extends Node2D

# Burning Wake upgrade: the player's flight path lingers as a damaging
# ribbon of light. This node tracks and draws it; Phase1 applies the damage.

const LIFE := 1.3           # seconds a wake point burns
const SPACING := 35.0       # px of player travel between points
const WIDTH := 14.0
const COLOR := Color(2.4, 1.2, 0.3)   # HDR fire — blooms

var points: Array = []      # [{pos: Vector2, age: float}]
var _last_pos: Vector2 = Vector2.INF


func _ready() -> void:
	z_index = -2
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat


# Called by Phase1 every physics frame while the upgrade is owned
func track(player_pos: Vector2, delta: float) -> void:
	for p in points:
		p.age += delta
	while points.size() > 0 and points[0].age > LIFE:
		points.pop_front()

	if _last_pos == Vector2.INF or player_pos.distance_to(_last_pos) >= SPACING:
		points.append({"pos": player_pos, "age": 0.0})
		_last_pos = player_pos

	queue_redraw()


func _draw() -> void:
	var n: int = points.size()
	if n < 2:
		return
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	pts.resize(n)
	cols.resize(n)
	for i in range(n):
		pts[i] = points[i].pos
		var fade: float = 1.0 - points[i].age / LIFE
		cols[i] = Color(COLOR.r, COLOR.g, COLOR.b, 0.5 * fade)
	draw_polyline_colors(pts, cols, WIDTH)
