extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var arena = load("res://Scenes/TestArena.tscn").instantiate()
	arena.bot_count = 0
	root.add_child(arena)
	current_scene = arena
	arena.player.set_process_unhandled_input(false)
	await create_timer(0.3).timeout
	arena.set_mouse_released(false)
	arena.player.position = Vector3(-17, 0.03, 16)
	arena.player.rotation = Vector3.ZERO
	Input.action_press("move_forward")
	await create_timer(0.35).timeout
	Input.action_press("slide")
	Input.action_press("fire")
	await create_timer(0.22).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://Tests/slide_view.png")
	Input.action_release("slide")
	Input.action_release("fire")
	Input.action_release("move_forward")
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://Tests/slide_recovered.png")
	quit()
