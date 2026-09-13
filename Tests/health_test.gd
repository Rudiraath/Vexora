extends SceneTree
var failures := 0
var deaths := 0
var respawns := 0
func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: ", label)
	else:
		push_error("FAIL: " + label)
		failures += 1
func frames(count: int) -> void:
	for i in count:
		await physics_frame
func capture(path: String) -> void:
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(path)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var arena = load("res://Scenes/TestArena.tscn").instantiate()
	arena.bot_count = 0
	root.add_child(arena)
	current_scene = arena
	var player = arena.player
	var weapon = player.weapon
	player.eliminated.connect(func(_source): deaths += 1)
	player.respawned.connect(func(): respawns += 1)
	await frames(30)
	arena.set_mouse_released(false)
	player.set_process_unhandled_input(false)
	check(player.health == 150 and not player.is_dead, "initial health is 150")
	check(not player.take_damage(-25) and not player.take_damage(NAN), "invalid damage rejected")
	check(player.take_damage(25) and player.health == 125, "damage contract reduces HP")
	check(player.damage_flash_left > 0, "damage triggers screen feedback")
	await capture("res://Tests/health_damage.png")
	arena.set_mouse_released(true)
	check(not player.take_damage(25) and player.health == 125, "pause blocks damage")
	arena.set_mouse_released(false)
	weapon.ammo = 10
	weapon.start_reload()
	player.is_sliding = true
	player.take_damage(1000)
	check(player.is_dead and player.health == 0 and deaths == 1, "lethal hit eliminates exactly once")
	check(not weapon.reloading and not player.is_sliding and not weapon.visible, "death cancels reload/slide and hides rifle")
	check(not weapon.try_fire() and not weapon.start_reload() and not player.start_slide(), "dead player cannot fire reload or slide")
	check(not player.take_damage(10) and deaths == 1, "dead player rejects repeated damage")
	var position: Vector3 = player.position
	Input.action_press("move_forward")
	await frames(5)
	check(player.position == position, "dead player cannot move")
	Input.action_release("move_forward")
	await capture("res://Tests/health_eliminated.png")
	arena.set_mouse_released(true)
	var remaining: float = player.respawn_left
	await frames(20)
	check(player.respawn_left == remaining, "pause freezes respawn countdown")
	arena.set_mouse_released(false)
	check(not player.controls_enabled and player.is_dead, "resume cannot revive or enable dead controls")
	Input.action_press("fire")
	var shots: int = weapon.shots_total
	await frames(125)
	check(not player.is_dead and player.health == 150 and respawns == 1, "automatic respawn occurs once at full HP")
	check(player.position.distance_to(player.spawn_transform.origin) < 0.2 and player.controls_enabled, "respawn returns to safe spawn with controls")
	check(weapon.ammo == 30 and weapon.reserve == 120 and weapon.visible, "new life restores rifle and fresh ammo")
	check(weapon.shots_total == shots, "held trigger cannot fire on respawn")
	Input.action_release("fire")
	check(player.protection_left > 0 and not player.take_damage(25), "spawn protection rejects damage briefly")
	await capture("res://Tests/health_respawn.png")
	await frames(65)
	check(player.take_damage(25), "damage resumes after protection expires")
	player.respawn()
	await frames(3)
	# Real overlap with the visible damage pad, including leaving the pad.
	player.position = arena.get_node("DamageZone").position + Vector3(0, 0.05, 0)
	await frames(5)
	check(player.health == 125, "damage pad applies its first 25 HP tick")
	player.position = player.spawn_transform.origin
	await frames(40)
	check(player.health == 125, "leaving pad stops damage")
	player.respawn()
	player.position = arena.get_node("DamageZone").position + Vector3(0, 0.05, 0)
	await frames(160)
	check(player.is_dead, "standing on pad eliminates player after six ticks")
	await frames(130)
	check(not player.is_dead and player.health == 150, "pad death automatically respawns safely")
	await frames(70)
	check(player.health == 150, "spawn is outside damage pad")
	player.position.y = -12
	await frames(3)
	check(player.is_dead, "falling out of arena eliminates")
	print("HEALTH TEST FAILURES: ", failures)
	quit(1 if failures else 0)
