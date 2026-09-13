extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var arena = load("res://Scenes/TestArena.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	for i in 8:
		await physics_frame
	var manager = arena.get_node("Bots")
	manager.rng.seed = 123
	var player = arena.player
	player.max_health = 100000
	player.health = 100000
	var starts: Array[Vector3] = []
	for bot in manager.bots:
		starts.append(bot.position)
	var travelled := [0.0, 0.0, 0.0]
	for i in 3600:
		await physics_frame
		for j in manager.bots.size():
			var bot = manager.bots[j]
			travelled[j] += bot.position.distance_to(starts[j])
			starts[j] = bot.position
	var ok := true
	for i in manager.bots.size():
		var bot = manager.bots[i]
		print("SOAK ", bot.bot_name, " travelled=", travelled[i], " shots=", bot.shots_total, " position=", bot.position)
		ok = ok and travelled[i] > 3 and bot.position.y > -1
	ok = ok and player.health < 100000
	# Force a fresh life near multiple opponents: choose a distant spawn.
	player.respawn(true)
	var closest := 1000.0
	for bot in manager.bots:
		closest = minf(closest, player.position.distance_to(bot.position))
	print("PLAYER RESPAWN MIN BOT DISTANCE: ", closest)
	ok = ok and closest > 8
	print("BOT SOAK PASS: ", ok)
	quit(0 if ok else 1)
