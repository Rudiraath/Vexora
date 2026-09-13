extends SceneTree
var failures := 0
var arena: Node
var player: CharacterBody3D
func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: ", label)
	else:
		push_error("FAIL: " + label)
		failures += 1
func frames(count: int) -> void:
	for i in count:
		await physics_frame
func _initialize() -> void:
	call_deferred("run")
func reset_player() -> void:
	for action in ["move_forward", "slide", "jump", "fire"]:
		Input.action_release(action)
	player.respawn()
	player.position = Vector3(-17, 0.03, 16)
	player.rotation = Vector3.ZERO
	await frames(15)
func begin_slide() -> void:
	Input.action_press("move_forward")
	await frames(20)
	Input.action_press("slide")
	await frames(3)
func run() -> void:
	arena = load("res://Scenes/TestArena.tscn").instantiate()
	arena.bot_count = 0
	root.add_child(arena)
	current_scene = arena
	player = arena.player
	player.set_process_unhandled_input(false)
	await reset_player()
	check(InputMap.action_get_events("slide")[0].physical_keycode == KEY_SHIFT, "Shift binds slide")
	check(not player.start_slide(), "standing still cannot slide")
	await begin_slide()
	check(player.is_sliding and Vector2(player.velocity.x, player.velocity.z).length() > 8.0, "moving Shift starts boosted slide")
	check(player.head.position.y < 1.62 and player.head.position.y > player.slide_camera_height, "camera lowers smoothly")
	check(is_equal_approx(player.body_shape.shape.height, player.slide_height), "collision capsule lowers with feet anchored")
	Input.action_press("fire")
	var shots: int = player.weapon.shots_total
	await frames(12)
	check(player.weapon.shots_total > shots and player.is_sliding, "automatic shooting works during slide")
	Input.action_release("fire")
	var frozen: float = player.slide_left
	var height: float = player.head.position.y
	arena.set_mouse_released(true)
	await frames(20)
	check(player.slide_left == frozen and player.head.position.y == height, "pause freezes slide and camera")
	arena.set_mouse_released(false)
	await frames(35)
	check(not player.is_sliding and player.slide_cooldown_left == 0, "slide ends without cooldown")
	Input.action_release("slide")
	await frames(1)
	Input.action_press("slide")
	await frames(2)
	check(player.is_sliding and Vector2(player.velocity.x, player.velocity.z).length() > 8.0, "next Shift tap immediately starts another boosted slide")
	await frames(90)
	check(not player.is_sliding and player.slide_cooldown_left == 0, "held Shift does not repeatedly slide")
	check(absf(player.head.position.y - 1.62) < 0.01, "camera returns to standing")
	await reset_player()
	await begin_slide()
	Input.action_release("slide")
	await frames(2)
	check(player.is_sliding, "tap slide carries momentum after release")
	Input.action_press("jump")
	await frames(3)
	Input.action_release("jump")
	check(not player.is_sliding and player.velocity.y > 0, "jump exits slide")
	player.slide_cooldown_left = 0
	check(not player.start_slide(), "airborne slide is rejected")
	await reset_player()
	await begin_slide()
	player.set_physics_process(false)
	var roof := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3, 0.2, 3)
	collision.shape = shape
	roof.add_child(collision)
	arena.add_child(roof)
	roof.position = player.position + Vector3(0, 1.35, 0)
	await frames(3)
	player.end_slide()
	player.update_slide_posture(0.2)
	check(player.is_crouched and not player.can_stand(), "low roof prevents capsule expanding into cover")
	roof.queue_free()
	await frames(3)
	player.update_slide_posture(0.2)
	check(not player.is_crouched and is_equal_approx(player.body_shape.shape.height, 1.8), "standing capsule restores when ceiling clears")
	player.set_physics_process(true)
	await reset_player()
	await begin_slide()
	var ammo: int = player.weapon.ammo
	player.respawn()
	check(not player.is_sliding and not player.is_crouched and player.slide_cooldown_left == 0 and is_equal_approx(player.head.position.y, 1.62) and player.weapon.ammo == ammo, "respawn resets slide and posture without changing ammo")
	# Existing centre ramp: launch toward its slope from the open south approach.
	Input.action_release("slide")
	player.position = Vector3(0, 0.03, 9.5)
	player.rotation = Vector3.ZERO
	await frames(10)
	await begin_slide()
	await frames(20)
	check(player.position.y > 0.15 and player.is_on_floor(), "slide follows existing ramp collision")
	await reset_player()
	player.position = Vector3(-17, 0.03, 18.7)
	player.rotation.y = PI
	await frames(5)
	await begin_slide()
	await frames(30)
	check(player.position.z < 19.6 and not player.is_sliding, "wall stops slide without tunneling")
	print("SLIDE TEST FAILURES: ", failures)
	quit(1 if failures else 0)
