extends SceneTree
## Render-only check of the actual playable arena from several viewpoints.
func _initialize() -> void:
	call_deferred("run")

func capture(path: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func run() -> void:
	var arena = load("res://Scenes/TestArena.tscn").instantiate()
	arena.bot_count = 0
	root.add_child(arena)
	current_scene = arena
	arena.player.set_process_unhandled_input(false)
	await create_timer(0.5).timeout
	arena.set_mouse_released(false)
	arena.player.set_physics_process(false)
	arena.player.weapon.set_physics_process(false)
	await capture("res://Tests/arena_textures_spawn.png")
	var camera: Camera3D = arena.player.camera
	camera.global_position = Vector3(4, 3.8, 9)
	camera.look_at(Vector3(0, 0.8, 2))
	await capture("res://Tests/arena_textures_ramp.png")
	camera.global_position = Vector3(-9, 2.1, 8)
	camera.look_at(Vector3(-13, 1, 5))
	await capture("res://Tests/arena_textures_crates.png")
	quit()
