extends "res://scripts/heavy_tank.gd"

# The Sovereign — boss-tier tank that descends on a timer, giving every run
# a rhythm: survive → boss → payday. Massive, nearly unstoppable, pays out
# a fortune in strays and Embers.


func _ready() -> void:
	super()
	max_health = 1400.0
	health = max_health
	body_radius = 46.0
	move_speed = 70.0
	stray_drop = 8
	ember_bonus = 50
	plow_kick = 40.0
	knock_resist = 0.96
	knockback_scale = 0.005
