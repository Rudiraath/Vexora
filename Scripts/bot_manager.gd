extends Node3D
const BOT = preload("res://Scenes/PracticeBot.tscn")
var bots: Array[Node] = []
var player: CharacterBody3D
var spawn_points: Array[Vector3] = []
var region: NavigationRegion3D
var kills := 0
var feedback_left := 0.0
var feedback: Label
var count_label: Label
var rng := RandomNumberGenerator.new()
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	call_deferred("setup")
func setup() -> void:
	var arena = get_parent()
	player = arena.player
	if arena.bot_count <= 0:
		return
	rng.randomize()
	NavigationServer3D.map_set_cell_height(get_world_3d().navigation_map, 0.1)
	region = NavigationRegion3D.new()
	region.navigation_mesh = load("res://Navigation/test_arena_nav.tres")
	add_child(region)
	for marker in arena.get_node("Map").find_children("Spawn_*", "Node3D", true, false):
		spawn_points.append(marker.global_position)
	# Additional open starting position brings the first fight close to spawn.
	spawn_points.append(Vector3(-17, 0, 4))
	await get_tree().physics_frame
	await get_tree().physics_frame
	for i in arena.bot_count:
		var bot = BOT.instantiate()
		bot.manager = self
		bot.player = player
		bot.bot_name = "BOT %02d" % (i + 1)
		bot.position = Vector3(-17, 0.08, 4) if i == 0 else spawn_points[(i + 1) % spawn_points.size()] + Vector3(0, 0.08, 0)
		add_child(bot)
		bots.append(bot)
		bot.eliminated.connect(_bot_eliminated)
	var hud := CanvasLayer.new()
	add_child(hud)
	count_label = Label.new()
	count_label.position = Vector2(30, 92)
	count_label.add_theme_font_size_override("font_size", 16)
	hud.add_child(count_label)
	feedback = Label.new()
	feedback.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	feedback.offset_left = -220
	feedback.offset_right = 220
	feedback.offset_top = 98
	feedback.offset_bottom = 135
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback.add_theme_font_size_override("font_size", 23)
	feedback.add_theme_color_override("font_color", Color("ffba78"))
	hud.add_child(feedback)
func _process(delta: float) -> void:
	feedback_left = maxf(0, feedback_left - delta)
	if feedback:
		feedback.visible = feedback_left > 0
		count_label.text = "BOT PRACTICE  /  %d OPPONENTS  /  %d ELIMINATIONS" % [bots.size(), kills]
func _bot_eliminated(bot: Node, source: Node) -> void:
	if source == player:
		kills += 1
		feedback.text = "ELIMINATED  " + bot.bot_name
		feedback_left = 1.7
func choose_spawn(excluded: Node) -> Vector3:
	var best := spawn_points[0]
	var best_score := -INF
	for point in spawn_points:
		var score: float = 100.0 if excluded == player else point.distance_to(player.global_position)
		for bot in bots:
			if bot != excluded and not bot.is_dead:
				score = minf(score, point.distance_to(bot.global_position))
		var query := PhysicsRayQueryParameters3D.create(point + Vector3(0, 1.4, 0), player.camera.global_position, 1)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if excluded != player and not hit.is_empty() and hit.collider != player:
			score += 5.0
		if score > best_score:
			best_score = score
			best = point
	return best
func patrol_position(bot: Node) -> Vector3:
	var point := spawn_points[rng.randi_range(0, spawn_points.size() - 1)]
	if point.distance_to(bot.global_position) < 3:
		point = Vector3(0, 1.2, 0)
	return point
func tracer(from: Vector3, to: Vector3) -> void:
	var effect := MeshInstance3D.new()
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1, 0.55, 0.18)
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	mesh.surface_add_vertex(from)
	mesh.surface_add_vertex(to)
	mesh.surface_end()
	effect.mesh = mesh
	add_child(effect)
	var tween := effect.create_tween()
	tween.tween_interval(0.065)
	tween.tween_callback(effect.queue_free)
