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
func capture(path: String) -> void:
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(path)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var arena = load("res://Scenes/TestArena.tscn").instantiate()
	arena.bot_count = 3
	root.add_child(arena)
	current_scene = arena
	var player = arena.player
	player.set_process_unhandled_input(false)
	await frames(8)
	arena.set_mouse_released(false)
	var manager = arena.get_node("Bots")
	check(manager.bots.size() == 3, "three configured bots spawn")
	var bot = manager.bots[0]
	for enemy in manager.bots:
		enemy.ai_enabled = false
		check(enemy.get_node("Visual/Character").scale == Vector3.ONE, "original character scale preserved")
	player.protection_left = 60
	bot.ai_enabled = true
	bot.patrol_goal = Vector3(-17, 0, 14)
	bot.think_left = 0
	var start: Vector3 = bot.position
	await frames(80)
	check(bot.position.distance_to(start) > 2, "bot follows navigation patrol path")
	var map: RID = arena.get_world_3d().navigation_map
	var path := NavigationServer3D.map_get_path(map, Vector3(-14, 0, -4), Vector3(-8, 0, -4), true)
	var path_length := 0.0
	for i in range(1, path.size()):
		path_length += path[i].distance_to(path[i - 1])
	check(path.size() > 2 and path_length > 7, "navigation routes around map baffle")
	# Controlled clear shooting lane, outside damage pad and map obstacles.
	bot.ai_enabled = false
	bot.position = Vector3(-17, 0.03, 8)
	bot.rotation.y = PI
	player.position = Vector3(-17, 0.03, 16)
	player.rotation = Vector3.ZERO
	player.head.rotation = Vector3.ZERO
	player.camera.rotation = Vector3.ZERO
	player.protection_left = 0
	bot.protection_left = 0
	bot.spread_degrees = 0
	bot.cooldown = 0
	await frames(3)
	check(bot.has_player_sight(), "bot detects visible player")
	var hp: float = player.health
	check(bot.try_fire() and player.health < hp, "bot hitscan damages player")
	check(not bot.try_fire(), "fire cooldown enforced")
	await capture("res://Tests/bot_combat.png")
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3, 3, 0.2)
	collision.shape = shape
	wall.add_child(collision)
	arena.add_child(wall)
	wall.position = Vector3(-17, 1.5, 12)
	await frames(3)
	bot.cooldown = 0
	check(not bot.has_player_sight() and not bot.try_fire(), "cover blocks detection and shots")
	wall.queue_free()
	await frames(3)
	bot.ammo = 0
	check(not bot.try_fire() and bot.reload_left > 0, "empty bot magazine begins reload")
	await frames(115)
	check(bot.ammo == bot.magazine_size, "bot reload restores magazine")
	# Player's actual center/muzzle rifle ray must hit the bot receiver.
	player.weapon.cooldown = 0
	player.weapon.ammo = 30
	player.weapon.reset_handling()
	check(player.weapon.try_fire() and bot.health == 125, "player rifle hits damageable bot for 25")
	check(player.weapon.hit_left > 0, "bot damage produces hit marker")
	bot.take_damage(1000, bot.position, player)
	check(bot.is_dead and not bot.visible and manager.kills == 1, "bot elimination updates practice count")
	check(not bot.take_damage(25, bot.position, player), "dead bot rejects duplicate damage")
	arena.set_mouse_released(true)
	var frozen: float = bot.respawn_left
	await frames(15)
	check(bot.respawn_left == frozen, "pause freezes bot respawn")
	arena.set_mouse_released(false)
	await frames(185)
	check(not bot.is_dead and bot.health == 150 and bot.visible and bot.ammo == 20, "bot respawns at full health and ammo")
	check(bot.position.distance_to(player.position) > 8, "bot respawn selects distant location")
	check(not bot.take_damage(25, bot.position, player), "bot has brief respawn protection")
	bot.position = Vector3(-17, 0.03, 8)
	bot.protection_left = 0
	bot.ai_enabled = true
	bot.seen_time = 0
	bot.cooldown = 0
	bot.reaction_time = 0.65
	var shots: int = bot.shots_total
	await frames(20)
	check(bot.shots_total == shots, "reaction delay prevents instant shots")
	await frames(30)
	check(bot.shots_total > shots, "autonomous bot acquires and fires")
	arena.set_mouse_released(true)
	var frozen_position: Vector3 = bot.position
	shots = bot.shots_total
	await frames(20)
	check(bot.position == frozen_position and bot.shots_total == shots, "pause freezes AI and firing")
	arena.set_mouse_released(false)
	player.eliminate(bot)
	shots = bot.shots_total
	await frames(30)
	check(bot.shots_total == shots, "bot stops attacking eliminated player")
	print("BOT TEST FAILURES: ", failures)
	quit(1 if failures else 0)
