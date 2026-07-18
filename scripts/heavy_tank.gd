extends "res://scripts/enemy.gd"

# G4 — the wall. Slow, enormous, and nearly immovable: it PLOWS straight
# through the flock, scattering units like bowling pins. Whip-cracks barely
# shove it — kill it with sustained grind (park the ring on it and commit).
# Pays out triple strays on death.


func _ready() -> void:
	super()
	max_health = 500.0
	health = max_health
	body_radius = 30.0
	move_speed = 90.0

	# Physics personality: it absorbs almost none of the overlap (units flex
	# around it), hurls units aside, and shrugs off grind impulses
	push_share = 0.08
	plow_kick = 30.0
	knock_resist = 0.9
	knockback_scale = 0.01
	stray_drop = 3

	color_body = Color(1.1, 0.60, 0.25)   # dark molten bronze
	color_core = Color(0.20, 0.10, 0.04)
	color_rim = Color(1.8, 1.0, 0.4)
	color_health = Color(1.8, 1.1, 0.4, 0.8)
