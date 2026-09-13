extends SceneTree
var failures := 0
func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: ", label)
	else:
		push_error("FAIL: " + label)
		failures += 1
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var arena = load("res://Scenes/TestArena.tscn").instantiate()
	arena.bot_count = 0
	root.add_child(arena)
	current_scene = arena
	var player = arena.player
	player.set_physics_process(false)
	var forward := Vector3(0, 0, -1)
	var straight := Vector3.ZERO
	var diagonal := Vector3.ZERO
	for i in 6:
		straight = player.ground_velocity(straight, forward, 4.5, 1.0 / 60)
		diagonal = player.ground_velocity(diagonal, Vector3(1, 0, -1).normalized(), 4.5, 1.0 / 60)
	check(straight.length() > 1.0 and straight.length() < 2.0, "progressive acceleration over first 100 ms")
	check(is_equal_approx(straight.length(), diagonal.length()), "diagonal acceleration matches straight movement")
	for i in 60:
		straight = player.ground_velocity(straight, forward, 4.5, 1.0 / 60)
	check(is_equal_approx(straight.length(), 4.5), "normal movement reaches speed without overshoot")
	var braking: Vector3 = player.ground_velocity(straight, Vector3.ZERO, 4.5, 0.1)
	check(braking.length() > 3.0 and braking.length() < straight.length(), "release carries a short controlled coast")
	for i in 60:
		braking = player.ground_velocity(braking, Vector3.ZERO, 4.5, 1.0 / 60)
	check(braking == Vector3.ZERO, "release reaches exact rest without endless drift")
	var turning: Vector3 = player.ground_velocity(straight, Vector3.RIGHT, 4.5, 0.1)
	check(turning.x > 0 and turning.z < -1 and turning.length() <= 4.5, "turn retains momentum without speed gain")
	var reversing: Vector3 = player.ground_velocity(straight, -forward, 4.5, 0.1)
	check(reversing.z < 0 and reversing.length() < straight.length(), "reverse brakes before changing direction")
	var exit_speed: Vector3 = player.ground_velocity(forward * 6.0, forward, 4.5, 1.0 / 60)
	check(exit_speed.length() > 5.8 and exit_speed.length() < 6.0, "slide exit retains excess speed and eases down")
	var at_30 := Vector3.ZERO
	var at_120 := Vector3.ZERO
	for i in 6:
		at_30 = player.ground_velocity(at_30, forward, 4.5, 1.0 / 30)
	for i in 24:
		at_120 = player.ground_velocity(at_120, forward, 4.5, 1.0 / 120)
	check(at_30.distance_to(at_120) < 0.001, "acceleration agrees at 30 and 120 physics ticks")
	# Live motion verifies the solver, pause and respawn integration.
	player.position = Vector3(-17, 0.03, 16)
	player.rotation = Vector3.ZERO
	player.set_physics_process(true)
	for i in 20:
		await physics_frame
	Input.action_press("move_forward")
	for i in 35:
		await physics_frame
	Input.action_release("move_forward")
	var released_at: Vector3 = player.position
	for i in 8:
		await physics_frame
	check(player.position.distance_to(released_at) > 0.2 and player.velocity.length() > 0.5, "real player coasts after key release")
	arena.set_mouse_released(true)
	var frozen_position: Vector3 = player.position
	var frozen_velocity: Vector3 = player.velocity
	for i in 10:
		await physics_frame
	check(player.position == frozen_position and player.velocity == frozen_velocity, "pause freezes momentum")
	arena.set_mouse_released(false)
	for i in 40:
		await physics_frame
	check(Vector2(player.velocity.x, player.velocity.z).length() < 0.01, "real player settles after releasing movement")
	player.respawn()
	check(player.velocity == Vector3.ZERO, "respawn clears momentum")
	print("MOMENTUM TEST FAILURES: ", failures)
	quit(1 if failures else 0)
