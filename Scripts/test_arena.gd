extends Node3D

@export_range(0, 8) var bot_count: int = 3

@onready var player: CharacterBody3D = $Player
@onready var pause_panel: Control = $HUD/PausePanel
@onready var status: Label = $HUD/Status
var mouse_released := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	$Map.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	$Targets.process_mode = Node.PROCESS_MODE_PAUSABLE
	# Generate static collision from the existing map geometry, including its ramps.
	for node in $Map.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.name == "Cube":
			mesh.hide()
		elif mesh.mesh:
			mesh.create_trimesh_collision()
	var spawn := $Map.find_child("Spawn_01", true, false) as Node3D
	if spawn:
		player.global_position = spawn.global_position + Vector3(0, 0.08, 0)
	else:
		player.global_position = Vector3(-16, 0.08, 16)
	# The imported spawn marker faces +Z; point the FPS camera into the arena.
	player.look_at(Vector3(0, player.global_position.y, 0))
	player.spawn_transform = player.global_transform
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_window().focus_exited.connect(_release_mouse)

func _process(_delta: float) -> void:
	var weapon = player.weapon
	$HUD/Ammo.text = "%02d / %03d" % [weapon.ammo, weapon.reserve]
	$HUD/Reload.text = "RELOADING  %.1fs" % weapon.reload_left if weapon.reloading else ("EMPTY — R TO RELOAD" if weapon.ammo == 0 else "ASSAULT RIFLE / AUTO")
	$HUD/HitMarker.visible = weapon.hit_left > 0 and not player.is_dead
	$HUD/Crosshair.visible = not weapon.aiming and not player.is_dead
	if mouse_released:
		status.text = "PAUSED"
	elif player.is_dead:
		status.text = "ELIMINATED"
	elif not player.is_on_floor():
		status.text = "AIRBORNE"
	elif player.is_sliding:
		status.text = "SLIDING"
	elif player.is_crouched:
		status.text = "LOW COVER"
	elif player.slide_cooldown_left > 0.0:
		status.text = "SLIDE  %.1fs" % player.slide_cooldown_left
	else:
		status.text = "FREE ROAM"

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		set_mouse_released(not mouse_released)
		get_viewport().set_input_as_handled()

func _release_mouse() -> void:
	set_mouse_released(true)

func set_mouse_released(released: bool) -> void:
	if mouse_released and not released:
		pause_panel.save_settings()
	player.weapon.block_trigger()
	player.slide_armed = false
	get_tree().paused = released
	mouse_released = released
	player.controls_enabled = not released and not player.is_dead
	pause_panel.visible = released
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if released else Input.MOUSE_MODE_CAPTURED
