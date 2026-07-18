extends Node2D

# Draws EVERY swarm unit's motion trail in a single canvas item.
# Replaces 100 individual Line2D nodes (each of which re-tessellated its own
# geometry every update) with one _draw() pass — perf pass B.

const TP = preload("res://scripts/theme_palette.gd")

const TRAIL_LENGTH := 8      # points per trail, recorded at 30 Hz (~0.27s)
const TRAIL_WIDTH := 9.0
const TRAIL_ALPHA := 0.30

var _units: Array = []                 # registered swarm units (never unregistered — sandbox units don't die)
var _trails: Array = []                # PackedVector2Array per unit
var _known: Dictionary = {}            # instance_id -> true
var _tick: int = 0
var _color_ramps: Dictionary = {}      # point count -> PackedColorArray (cached fade gradients)


func _ready() -> void:
	z_index = -1
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	rebuild_ramps()


func rebuild_ramps() -> void:
	# Called on theme switch too — trails follow the active swarm color
	var c: Color = TP.P["swarm_body"]
	for count in range(2, TRAIL_LENGTH + 1):
		var ramp := PackedColorArray()
		ramp.resize(count)
		for j in range(count):
			ramp[j] = Color(c.r, c.g, c.b, TRAIL_ALPHA * float(j) / float(count - 1))
		_color_ramps[count] = ramp


func _process(_delta: float) -> void:
	# Self-syncs with the swarm: any unit in the group gets a trail
	var swarm: Array = get_tree().get_nodes_in_group("swarm_unit")
	for u in swarm:
		var id: int = u.get_instance_id()
		if not _known.has(id):
			_known[id] = true
			_units.append(u)
			_trails.append(PackedVector2Array())

	# Record points at 30 Hz, staggered by index so writes spread across frames
	_tick += 1
	for i in range(_units.size()):
		var u = _units[i]
		if not is_instance_valid(u):
			# Unit was eaten — retract its trail instead of freezing it in place
			if _trails[i].size() > 0:
				var dead: PackedVector2Array = _trails[i]
				dead.remove_at(0)
			continue
		if (i + _tick) % 2 != 0:
			continue
		var t: PackedVector2Array = _trails[i]
		t.append(u.global_position)
		if t.size() > TRAIL_LENGTH:
			t.remove_at(0)

	queue_redraw()


func _draw() -> void:
	for t in _trails:
		var m: int = t.size()
		if m < 2:
			continue
		draw_polyline_colors(t, _color_ramps[m], TRAIL_WIDTH)
