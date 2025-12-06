extends Node2D

@export var follower_count: int = 10
@export var spawn_area_size: Vector2 = Vector2(800, 600)

@export var friction: float = 0.90          # 0–1; lower = more slide, higher = more damped
@export var collision_push: float = 1.5     # how strongly units push apart when overlapping

var follower_scene: PackedScene = preload("res://scenes/FollowerUnit.tscn")

var collected_count: int = 0

@onready var player: Node2D = $Player   # adjust this path if your Player node is elsewhere


func _ready() -> void:
	randomize()
	spawn_followers()


func spawn_followers() -> void:
	for i in range(follower_count):
		var follower: Node2D = follower_scene.instantiate()
		add_child(follower)

		# Random position within a box centered on Phase1
		var offset := Vector2(
			randf_range(-spawn_area_size.x * 0.5, spawn_area_size.x * 0.5),
			randf_range(-spawn_area_size.y * 0.5, spawn_area_size.y * 0.5)
		)
		follower.global_position = global_position + offset


func _physics_process(delta: float) -> void:
	if player == null:
		return

	var swarm_units: Array = get_tree().get_nodes_in_group("swarm_unit")
	if swarm_units.is_empty():
		return

	var target_pos: Vector2 = player.global_position

	# 1) Attraction + velocity integration (soft swarm movement)
	for u in swarm_units:
		var pos: Vector2 = u.global_position
		var to_target: Vector2 = target_pos - pos
		var dist: float = to_target.length()

		if dist > 0.01:
			var dir: Vector2 = to_target / dist
			u.vel += dir * u.strength * delta

		# Apply friction
		u.vel *= friction

		# Limit speed
		if u.vel.length() > u.max_speed:
			u.vel = u.vel.normalized() * u.max_speed

		# Move
		pos += u.vel * delta
		u.global_position = pos

	# 2) Soft collision resolution (spread the blob out)
	resolve_collisions(swarm_units)

	# 3) Update count (for debugging / future UI)
	var new_count: int = swarm_units.size()
	if new_count != collected_count:
		collected_count = new_count
		print("Collected units:", collected_count)


func resolve_collisions(particles: Array) -> void:
	var n: int = particles.size()
	for i in range(n):
		for j in range(i + 1, n):
			var a = particles[i]
			var b = particles[j]

			var pa: Vector2 = a.global_position
			var pb: Vector2 = b.global_position

			var dx: float = pb.x - pa.x
			var dy: float = pb.y - pa.y
			var dist_sq: float = dx * dx + dy * dy

			var min_dist: float = a.radius + b.radius

			if dist_sq == 0.0:
				# Prevent NaNs by giving a tiny random offset
				dx = randf_range(-0.01, 0.01)
				dy = randf_range(-0.01, 0.01)
				dist_sq = dx * dx + dy * dy

			if dist_sq < min_dist * min_dist:
				var dist: float = sqrt(dist_sq)
				var nx: float = dx / dist
				var ny: float = dy / dist
				var overlap: float = (min_dist - dist) * collision_push

				# Push each unit half the overlap apart
				pa.x -= nx * (overlap * 0.5)
				pa.y -= ny * (overlap * 0.5)
				pb.x += nx * (overlap * 0.5)
				pb.y += ny * (overlap * 0.5)

				a.global_position = pa
				b.global_position = pb
