extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var arena = load("res://Scenes/TestArena.tscn").instantiate()
	arena.bot_count = 0
	root.add_child(arena)
	current_scene = arena
	await create_timer(1.0).timeout
	arena.set_mouse_released(false)
	arena.player.set_process_unhandled_input(false)
	var weapon = arena.player.weapon
	weapon.set_physics_process(false)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://Tests/rifle_hip.png")
	weapon.aiming = true
	weapon.animate_weapon(0.3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://Tests/rifle_ads.png")
	weapon.aiming = false
	weapon.ammo = 15
	weapon.start_reload()
	weapon.reload_left = weapon.reload_duration * 0.5
	weapon.animate_weapon(0.3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://Tests/rifle_reload.png")
	quit()
