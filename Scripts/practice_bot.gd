extends CharacterBody3D
signal eliminated(bot: Node, source: Node)
@export var max_health: float = 150.0
@export var move_speed: float = 3.6
@export var damage: float = 12.0
@export var fire_interval: float = 0.3
@export var reaction_time: float = 0.65
@export var spread_degrees: float = 3.0
@export var detection_range: float = 26.0
@export var respawn_delay: float = 3.0
@export var magazine_size: int = 20
@export var reload_duration: float = 1.8
var manager: Node
var player: CharacterBody3D
var bot_name := "BOT"
var health := 150.0
var is_dead := false
var respawn_left := 0.0
var protection_left := 0.0
var cooldown := 0.0
var reload_left := 0.0
var ammo := 20
var seen_time := 0.0
var memory_left := 0.0
var last_seen := Vector3.ZERO
var think_left := 0.0
var patrol_goal := Vector3.ZERO
var hit_left := 0.0
var shots_total := 0
var deaths_total := 0
var ai_enabled := true
var can_see_player := false
var rng := RandomNumberGenerator.new()
@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var visual: Node3D = $Visual
func _ready() -> void:
	add_to_group("bots")
	health = max_health
	ammo = magazine_size
	rng.seed = hash(bot_name)
	patrol_goal = global_position
func _physics_process(delta: float) -> void:
	if is_dead:
		respawn_left = maxf(0, respawn_left - delta)
		if respawn_left == 0:
			respawn_at(manager.choose_spawn(self))
		return
	protection_left = maxf(0, protection_left - delta)
	hit_left = maxf(0, hit_left - delta)
	cooldown = maxf(0, cooldown - delta)
	if reload_left > 0:
		reload_left = maxf(0, reload_left - delta)
		if reload_left == 0:
			ammo = magazine_size
	$Label3D.text = "%s  %d" % [bot_name, health] + (" / RELOAD" if reload_left > 0 else "")
	if not ai_enabled:
		visual.update_pose(delta, false, false, hit_left > 0)
		return
	if not is_on_floor():
		velocity.y -= 18 * delta
	var eye := global_position + Vector3(0, 1.45, 0)
	can_see_player = has_player_sight()
	if can_see_player:
		last_seen = player.global_position
		memory_left = 4.0
		seen_time += delta
	else:
		memory_left = maxf(0, memory_left - delta)
		seen_time = 0
	think_left -= delta
	if think_left <= 0:
		think_left = 0.35
		if memory_left > 0:
			agent.target_position = last_seen
		else:
			if global_position.distance_to(patrol_goal) < 1.0 or agent.is_navigation_finished():
				patrol_goal = manager.patrol_position(self)
			agent.target_position = patrol_goal
	var direction := Vector3.ZERO
	if not agent.is_navigation_finished():
		direction = agent.get_next_path_position() - global_position
		direction.y = 0
		direction = direction.normalized()
	if can_see_player and global_position.distance_to(player.global_position) < 8:
		direction = Vector3.ZERO
	var facing := player.global_position - global_position if can_see_player else direction
	if facing.length_squared() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-facing.x, -facing.z), minf(1, delta * 9))
	velocity.x = move_toward(velocity.x, direction.x * move_speed, 16 * delta)
	velocity.z = move_toward(velocity.z, direction.z * move_speed, 16 * delta)
	move_and_slide()
	visual.update_pose(delta, Vector2(velocity.x, velocity.z).length() > 0.2, not is_on_floor(), hit_left > 0)
	if can_see_player and seen_time >= reaction_time:
		try_fire()
	if global_position.y < -10:
		take_damage(max_health, eye, null)
func ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, [get_rid()])
	query.hit_from_inside = true
	return get_world_3d().direct_space_state.intersect_ray(query)
func has_player_sight() -> bool:
	if not is_instance_valid(player) or player.is_dead or player.protection_left > 0:
		return false
	var eye := global_position + Vector3(0, 1.45, 0)
	var target: Vector3 = player.camera.global_position - Vector3(0, 0.12, 0)
	if eye.distance_to(target) > detection_range:
		return false
	var hit := ray(eye, target)
	return not hit.is_empty() and hit.collider == player
func try_fire() -> bool:
	if is_dead or get_tree().paused or cooldown > 0 or reload_left > 0 or not has_player_sight():
		return false
	if ammo <= 0:
		reload_left = reload_duration
		return false
	ammo -= 1
	cooldown = fire_interval
	shots_total += 1
	var eye := global_position + Vector3(0, 1.45, 0)
	var target: Vector3 = player.camera.global_position - Vector3(0, 0.12, 0)
	var direction := (target - eye).normalized()
	direction = direction.rotated(Vector3.UP, deg_to_rad(rng.randf_range(-spread_degrees, spread_degrees)))
	direction = direction.rotated(Vector3.RIGHT, deg_to_rad(rng.randf_range(-spread_degrees, spread_degrees)))
	var hit := ray(eye, eye + direction * detection_range)
	var end: Vector3 = hit.position if not hit.is_empty() else eye + direction * detection_range
	var muzzle: Vector3 = visual.muzzle.global_position
	var cover := ray(eye, muzzle)
	if cover.is_empty():
		cover = ray(muzzle, end)
	if not cover.is_empty():
		hit = cover
		end = cover.position
	if not hit.is_empty() and hit.collider == player:
		player.take_damage(damage, hit.position, self)
	visual.shot()
	manager.tracer(muzzle, end)
	return true
func take_damage(amount: float, _point: Vector3, source: Node) -> bool:
	if is_dead or get_tree().paused or protection_left > 0 or not is_finite(amount) or amount <= 0:
		return false
	health = maxf(0, health - amount)
	hit_left = 0.16
	if source == player:
		last_seen = player.global_position
		memory_left = 4
	if health == 0:
		is_dead = true
		deaths_total += 1
		respawn_left = respawn_delay
		velocity = Vector3.ZERO
		visual.stop()
		hide()
		$CollisionShape3D.set_deferred("disabled", true)
		eliminated.emit(self, source)
	return true
func respawn_at(point: Vector3) -> void:
	global_position = point + Vector3(0, 0.08, 0)
	velocity = Vector3.ZERO
	health = max_health
	ammo = magazine_size
	is_dead = false
	respawn_left = 0
	protection_left = 0.8
	cooldown = reaction_time
	reload_left = 0
	seen_time = 0
	memory_left = 0
	think_left = 0
	patrol_goal = global_position
	$CollisionShape3D.set_deferred("disabled", false)
	show()
	reset_physics_interpolation()
