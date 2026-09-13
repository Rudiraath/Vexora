extends SceneTree
var failures := 0
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
func run() -> void:
	var arena = load("res://Scenes/TestArena.tscn").instantiate()
	var settings = arena.get_node("HUD/PausePanel")
	settings.settings_path = "user://view_test_%d.cfg" % OS.get_process_id()
	arena.bot_count = 0
	root.add_child(arena)
	current_scene = arena
	var player = arena.player
	var forward := Vector3(0, 0, -1)
	var retained: Vector3 = player.air_velocity(forward * 8, Vector3.ZERO, 0.2)
	check(retained.length() > 7.9, "air coast retains slide-jump momentum")
	var steer: Vector3 = player.air_velocity(forward * 8, Vector3.RIGHT, 0.2)
	check(steer.x > 0.5 and steer.z < -6 and steer.length() <= 8, "air steering redirects gradually without speed gain")
	var speed := forward * 4.5
	for i in 600:
		var wish := Vector3(cos(i * 0.03), 0, sin(i * 0.03))
		speed = player.air_velocity(speed, wish, 1.0 / 60)
	check(speed.length() <= 4.501, "repeated air strafing cannot stack speed")
	var straight := Vector3.ZERO
	var diagonal := Vector3.ZERO
	for i in 12:
		straight = player.air_velocity(straight, forward, 1.0 / 60)
		diagonal = player.air_velocity(diagonal, Vector3(1, 0, -1).normalized(), 1.0 / 60)
	check(is_equal_approx(straight.length(), diagonal.length()), "air acceleration has diagonal parity")
	player.position = Vector3(-17, 0.03, 16)
	player.rotation = Vector3.ZERO
	await frames(20)
	Input.action_press("move_forward")
	await frames(30)
	Input.action_press("jump")
	await frames(3)
	Input.action_release("jump")
	Input.action_release("move_forward")
	var takeoff: float = Vector2(player.velocity.x, player.velocity.z).length()
	await frames(8)
	check(not player.is_on_floor() and Vector2(player.velocity.x, player.velocity.z).length() > takeoff - 0.1, "live jump retains momentum with no keys held")
	Input.action_press("move_right")
	Input.action_press("fire")
	var before: int = player.weapon.shots_total
	await frames(8)
	check(player.velocity.x > 0.5 and player.velocity.z < -2, "live jump can redirect around a corner")
	check(player.weapon.shots_total > before, "shooting works while steering in air")
	Input.action_release("move_right")
	Input.action_release("fire")
	arena.set_mouse_released(true)
	var frozen: Vector3 = player.position
	settings.sensitivity.value = 1.75
	settings.fov.value = 105
	await frames(5)
	check(paused and player.position == frozen, "settings interaction leaves game paused")
	check(is_equal_approx(player.mouse_sensitivity, 0.0022 * 1.75) and player.base_fov == 105, "sliders apply sensitivity and FOV")
	settings.save_settings()
	settings.sensitivity.set_value_no_signal(0.5)
	settings.fov.set_value_no_signal(75)
	settings.load_settings()
	check(settings.sensitivity.value == 1.75 and settings.fov.value == 105, "preferences persist across reload")
	# Resume click must never become a shot.
	Input.action_press("fire")
	before = player.weapon.shots_total
	arena.set_mouse_released(false)
	await frames(3)
	check(player.weapon.shots_total == before, "held fire cannot leak out of settings resume")
	Input.action_release("fire")
	await frames(2)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(10, 0)
	var yaw: float = player.rotation.y
	player._unhandled_input(motion)
	if DisplayServer.get_name() != "headless":
		check(is_equal_approx(player.rotation.y - yaw, -10 * player.mouse_sensitivity), "mouse look uses chosen sensitivity")
	else:
		print("SKIP: captured mouse input requires graphical run (verified separately)")
	Input.action_press("aim")
	await frames(15)
	check(is_equal_approx(player.camera.fov, player.ads_fov()), "ADS uses selected FOV")
	Input.action_release("aim")
	await frames(15)
	check(is_equal_approx(player.camera.fov, 105), "leaving ADS restores selected FOV")
	player.respawn()
	check(is_equal_approx(player.camera.fov, 105), "respawn preserves FOV preference")
	arena.set_mouse_released(true)
	settings.reset_defaults()
	check(settings.sensitivity.value == 1 and settings.fov.value == 90, "reset restores defaults")
	# Invalid stored values are clamped or replaced, never applied to camera.
	var config := ConfigFile.new()
	config.set_value("view", "sensitivity", "invalid")
	config.set_value("view", "fov", 400)
	config.save(settings.settings_path)
	settings.load_settings()
	check(settings.sensitivity.value == 1 and settings.fov.value == 110, "invalid saved preferences handled safely")
	settings.reset_defaults()
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://Tests/settings_view.png")
	settings.dirty = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(settings.settings_path))
	print("AIR/SETTINGS TEST FAILURES: ", failures)
	quit(1 if failures else 0)
