extends SceneTree
var failures := 0
var arena: Node
var player: CharacterBody3D
var weapon: Node
func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		push_error("FAIL: " + description)
		failures += 1

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	arena = load("res://Scenes/TestArena.tscn").instantiate()
	arena.bot_count = 0
	root.add_child(arena)
	current_scene = arena
	player = arena.get_node("Player")
	weapon = player.weapon
	await frames(40)
	check(player.is_on_floor(), "spawn rests on existing map collision")
	check(InputMap.action_get_events("respawn")[0].physical_keycode == KEY_F6, "F6 respawn binding")
	var start := player.position
	Input.action_press("move_forward")
	await frames(20)
	Input.action_release("move_forward")
	check(player.position.distance_to(start) > 0.5, "movement works")
	Input.action_press("jump")
	await frames(3)
	Input.action_release("jump")
	check(player.velocity.y > 0, "jump works")
	player.respawn()
	await frames(35)
	Input.action_press("move_forward")
	await frames(20)
	Input.action_press("slide")
	Input.action_press("fire")
	var running_shots: int = weapon.shots_total
	await frames(30)
	check(player.is_sliding and Vector2(player.velocity.x, player.velocity.z).length() > 6.0 and weapon.shots_total > running_shots, "player keeps slide speed while shooting")
	Input.action_release("move_forward")
	Input.action_release("slide")
	Input.action_release("fire")
	player.respawn()
	weapon.ammo = weapon.magazine_size
	var near_target = arena.get_node("Targets/NearTarget")
	near_target.health = near_target.max_health
	near_target.reset_left = 0.0
	near_target.update_display()
	await frames(35)
	player.set_physics_process(false)
	weapon.set_physics_process(false)
	check(weapon.ammo == 30 and weapon.reserve == 120, "initial ammo")
	check(weapon.try_fire(), "single shot")
	check(weapon.ammo == 29 and not weapon.try_fire(), "cooldown prevents duplicate shot")
	check(not weapon.last_hit.is_empty() and weapon.last_hit.collider == arena.get_node("Targets/NearTarget"), "screen-center ray hits near target and excludes player")
	check(arena.get_node("Targets/NearTarget").health == 75 and weapon.hit_left > 0, "25 damage and hit marker")
	weapon.ammo = 30
	weapon.cooldown = 0
	var before: int = weapon.shots_total
	Input.action_press("fire")
	for i in 120:
		weapon._physics_process(1.0 / 60.0)
	Input.action_release("fire")
	check(weapon.shots_total - before == 20, "600 RPM: 20 shots over 2 seconds at 60 Hz")
	Input.action_press("fire")
	for i in 90:
		weapon._physics_process(1.0 / 60.0)
	Input.action_release("fire")
	check(weapon.ammo == 0 and weapon.shots_total - before == 30, "sustained fire empties exactly 30 rounds")
	for i in 120:
		weapon._physics_process(1.0 / 60.0)
	check(weapon.kick == 0 and weapon.camera_kick == 0, "recoil recovers without drift")
	weapon.ammo = 0
	weapon.cooldown = 0
	check(not weapon.try_fire() and weapon.ammo == 0, "empty magazine rejects shots")
	check(weapon.start_reload() and not weapon.start_reload(), "reload starts once")
	check(not weapon.try_fire(), "reload blocks firing")
	var total: int = weapon.ammo + weapon.reserve
	weapon._physics_process(1.0)
	player.respawn()
	check(not weapon.reloading and weapon.ammo + weapon.reserve == total and weapon.ammo == 0, "respawn cancels reload with unchanged ammo")
	weapon.start_reload()
	weapon._physics_process(2.2)
	check(weapon.ammo == 30 and weapon.reserve == 90, "reload transfers exact magazine")
	check(not weapon.start_reload(), "full reload rejected")
	weapon.ammo = 20
	weapon.reserve = 4
	weapon.start_reload()
	weapon._physics_process(2.2)
	check(weapon.ammo == 24 and weapon.reserve == 0 and not weapon.start_reload(), "partial reserve and zero reserve")
	Input.action_press("aim")
	weapon._physics_process(0.3)
	check(weapon.aiming and is_equal_approx(player.camera.fov, player.ads_fov()), "smooth ADS reaches sight FOV")
	player.is_sliding = true
	weapon._physics_process(0.3)
	check(not weapon.aiming and weapon.try_fire(), "slide allows hip fire and keeps sights lowered")
	var sprint_shots: int = weapon.shots_total
	Input.action_press("fire")
	for i in 60:
		weapon._physics_process(1.0 / 60.0)
	Input.action_release("fire")
	check(weapon.shots_total - sprint_shots == 10 and weapon.slide_blend == 0.0, "slide supports sustained 600 RPM fire with rifle raised")
	Input.action_release("aim")
	player.is_sliding = false
	weapon.start_reload() # No reserve: intentionally invalid.
	weapon.reserve = 30
	weapon.start_reload()
	weapon.set_physics_process(true)
	var frozen: float = weapon.reload_left
	arena.set_mouse_released(true)
	await frames(20)
	check(weapon.reload_left == frozen and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "pause freezes reload and releases mouse")
	Input.action_press("fire")
	arena.set_mouse_released(false)
	await frames(3)
	check(not weapon.trigger_armed, "resume while held requires trigger release")
	Input.action_release("fire")
	await frames(2)
	check(weapon.trigger_armed, "release rearms trigger")
	weapon.set_physics_process(false)
	weapon.reset_handling()
	# Place a thin slab between the camera and muzzle: muzzle beyond cover.
	player.global_position = Vector3(-16, 0.02, 16)
	player.rotation = Vector3.ZERO
	player.head.rotation = Vector3.ZERO
	weapon.animate_weapon(0)
	var cover := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2, 2, 0.04)
	shape.shape = box
	cover.add_child(shape)
	arena.add_child(cover)
	cover.global_position = player.camera.global_position + Vector3(0, 0, -0.45)
	await frames(2)
	var hit: Dictionary = weapon.trace_shot()
	check(not hit.is_empty() and hit.collider == cover, "cover blocks barrel projecting through wall")
	weapon.animate_weapon(0.1)
	check(weapon.position.z > -0.55, "rifle retracts near wall")
	cover.queue_free()
	await frames(2)
	# Offset cover blocks muzzle while leaving the screen center clear.
	cover = StaticBody3D.new()
	shape = CollisionShape3D.new()
	box = BoxShape3D.new()
	box.size = Vector3(0.2, 0.4, 0.1)
	shape.shape = box
	cover.add_child(shape)
	arena.add_child(cover)
	weapon.animate_weapon(0)
	cover.global_position = weapon.muzzle.global_position + Vector3(0, 0, -0.2)
	await frames(2)
	hit = weapon.trace_shot()
	check(not hit.is_empty() and hit.collider == cover, "offset cover blocks muzzle-to-aim path")
	cover.queue_free()
	var target := arena.get_node("Targets/NearTarget")
	target.health = 100
	for i in 4:
		target.take_damage(25, Vector3.ZERO, player)
	check(target.health == 0 and not target.take_damage(25, Vector3.ZERO, player), "four hits destroy; dead target rejects damage")
	target._physics_process(3.1)
	check(target.health == 100, "target resets after destruction")
	player.set_physics_process(true)
	player.respawn()
	# Walk into the arena's west wall; collision must contain the player.
	player.position = Vector3(-19, 0.05, 16)
	player.rotation = Vector3.ZERO
	Input.action_press("move_left")
	await frames(90)
	Input.action_release("move_left")
	check(player.position.x > -19.6 and player.is_on_wall(), "existing wall collision contains movement")
	player.position.y = -12
	await frames(2)
	check(player.is_dead, "fall eliminates player")
	await frames(130)
	check(not player.is_dead and player.position.distance_to(player.spawn_transform.origin) < 0.2, "fall auto-respawn works")
	print("RIFLE TEST FAILURES: ", failures)
	quit(1 if failures else 0)
