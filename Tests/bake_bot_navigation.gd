extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var arena = load("res://Scenes/TestArena.tscn").instantiate()
	arena.bot_count = 0
	root.add_child(arena)
	current_scene = arena
	arena.get_node("Map").add_to_group("bot_navigation_source")
	NavigationServer3D.map_set_cell_height(arena.get_world_3d().navigation_map, 0.1)
	var region := NavigationRegion3D.new()
	arena.add_child(region)
	var mesh := NavigationMesh.new()
	mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	mesh.geometry_source_group_name = "bot_navigation_source"
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.agent_radius = 0.5
	mesh.agent_height = 1.8
	mesh.agent_max_climb = 0.1
	mesh.agent_max_slope = 45
	mesh.cell_size = 0.25
	mesh.cell_height = 0.1
	region.navigation_mesh = mesh
	region.bake_navigation_mesh(false)
	var error := ResourceSaver.save(mesh, "res://Navigation/test_arena_nav.tres")
	print("NAV BAKE: ", mesh.get_polygon_count(), " polygons, save=", error)
	quit(0 if error == OK and mesh.get_polygon_count() > 0 else 1)
