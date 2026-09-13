extends Node3D
## Camera-mounted rifle. Animation offsets are rebuilt each frame to avoid drift.
signal shot_fired
signal target_hit

@export_range(60, 1200) var rounds_per_minute: float = 600.0
@export var magazine_size: int = 30
@export var starting_reserve: int = 120
@export var damage: float = 25.0
@export var shot_range: float = 100.0
@export var reload_duration: float = 2.1
@export var fire_sound: AudioStream
@export var empty_sound: AudioStream
@onready var model: Node3D = $Model
@onready var camera: Camera3D = get_parent()
@onready var player: CharacterBody3D = get_parent().get_parent().get_parent()
@onready var muzzle: Node3D = model.find_child("Muzzle_Point", true, false)
@onready var magazine: Node3D = model.find_child("Rifle_Magazine", true, false)
var ammo: int
var reserve: int
var cooldown := 0.0
var reload_left := 0.0
var reloading := false
var aiming := false
var aim_blend := 0.0
var slide_blend := 0.0
var kick := 0.0
var camera_kick := 0.0
var flash_left := 0.0
var hit_left := 0.0
var trigger_armed := true
var empty_latched := false
var bob_time := 0.0
var sway := Vector2.ZERO
var magazine_rest := Vector3.ZERO
var flash: MeshInstance3D
var audio: AudioStreamPlayer
var last_hit: Dictionary = {}
var shots_total := 0

func _ready() -> void:
	ammo = magazine_size
	reserve = starting_reserve
	model.rotation.y = PI / 2.0
	var grip := model.find_child("Grip_Point", true, false) as Node3D
	model.position = -(model.basis * grip.position)
	magazine_rest = magazine.position
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.name == "Cube":
			mesh.hide()
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash = MeshInstance3D.new()
	var flash_mesh := SphereMesh.new()
	flash_mesh.radius = 0.035
	flash_mesh.height = 0.07
	flash.mesh = flash_mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1, 0.8, 0.25)
	flash.material_override = material
	muzzle.add_child(flash)
	flash.hide()
	audio = AudioStreamPlayer.new()
	audio.max_polyphony = 8
	add_child(audio)
	animate_weapon(0.0)

func _unhandled_input(event: InputEvent) -> void:
	if not player.controls_enabled:
		return
	if event is InputEventMouseMotion:
		sway += event.relative * 0.00015
		sway = sway.limit_length(0.025)
	if event.is_action_pressed("reload"):
		start_reload()

func _physics_process(delta: float) -> void:
	if not player.controls_enabled:
		return
	var held := Input.is_action_pressed("fire")
	if not held:
		trigger_armed = true
		empty_latched = false
	cooldown = maxf(cooldown - delta, 0.0)
	if reloading:
		reload_left = maxf(reload_left - delta, 0.0)
		if reload_left <= 0.0:
			var transferred := mini(magazine_size - ammo, reserve)
			ammo += transferred
			reserve -= transferred
			reloading = false
	if held and trigger_armed:
		try_fire()
	aiming = Input.is_action_pressed("aim") and not player.is_sliding and not reloading
	animate_weapon(delta)

func start_reload() -> bool:
	if reloading or ammo >= magazine_size or reserve <= 0 or not player.controls_enabled:
		return false
	reloading = true
	reload_left = reload_duration
	aiming = false
	return true

func try_fire() -> bool:
	if not player.controls_enabled or get_tree().paused or reloading or cooldown > 0.00001:
		return false
	if ammo <= 0:
		if not empty_latched:
			play_sound(empty_sound)
			empty_latched = true
		return false
	ammo -= 1
	shots_total += 1
	cooldown = 60.0 / rounds_per_minute
	last_hit = trace_shot()
	if not last_hit.is_empty():
		var receiver: Node = last_hit.collider
		while receiver and not receiver.has_method("take_damage"):
			receiver = receiver.get_parent()
		var damaged := false
		if receiver:
			damaged = receiver.take_damage(damage, last_hit.position, player)
		if damaged:
			hit_left = 0.15
			target_hit.emit()
		spawn_impact(last_hit.position, damaged)
	kick = minf(kick + 1.0, 1.8)
	camera_kick = minf(camera_kick + deg_to_rad(0.35), deg_to_rad(1.4))
	flash_left = 0.035
	play_sound(fire_sound)
	shot_fired.emit()
	return true

func ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, [player.get_rid()])
	query.hit_from_inside = true
	return get_world_3d().direct_space_state.intersect_ray(query)

func trace_shot() -> Dictionary:
	var origin := camera.global_position
	var end := origin - camera.global_basis.z * shot_range
	var aim_hit := ray(origin, end)
	if not aim_hit.is_empty():
		end = aim_hit.position
	# This extra segment catches a barrel already projecting through cover.
	var near_hit := ray(origin, muzzle.global_position)
	if not near_hit.is_empty():
		return near_hit
	var muzzle_hit := ray(muzzle.global_position, end)
	return muzzle_hit if not muzzle_hit.is_empty() else aim_hit

func animate_weapon(delta: float) -> void:
	kick = move_toward(kick, 0, delta * 9.0)
	camera_kick = move_toward(camera_kick, 0, delta * deg_to_rad(3.0))
	camera.rotation.x = camera_kick
	aim_blend = move_toward(aim_blend, 1.0 if aiming else 0.0, delta * 7.0)
	camera.fov = lerpf(player.base_fov, player.ads_fov(), aim_blend)
	sway = sway.lerp(Vector2.ZERO, 1.0 - exp(-delta * 12.0))
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	bob_time += delta * speed * 2.2
	var motion := minf(speed / 4.5, 1.0) if player.is_on_floor() else 0.0
	position = Vector3(0.24, -0.23, -0.55).lerp(Vector3(0, -0.221, -0.55), aim_blend)
	position += Vector3(sin(bob_time) * 0.007 * motion + sway.x, cos(bob_time * 2) * 0.005 * motion - sway.y, kick * 0.028) * (1.0 - aim_blend * 0.8)
	rotation = Vector3(kick * 0.025, 0, 0)
	var lower_for_slide: bool = player.is_sliding and not Input.is_action_pressed("fire") and cooldown <= 0.0
	slide_blend = move_toward(slide_blend, 1.0 if lower_for_slide else 0.0, delta * 6.0)
	position += Vector3(0.04, -0.09, 0.07) * slide_blend
	rotation += Vector3(-0.25, 0.15, -0.15) * slide_blend
	magazine.position = magazine_rest
	if reloading:
		var progress := 1.0 - reload_left / reload_duration
		var tilt := sin(progress * PI)
		position += Vector3(-0.06, 0.10, -0.12) * tilt
		rotation += Vector3(0.12, 0.0, -0.65) * tilt
		var drop := smoothstep(0.12, 0.32, progress) * (1.0 - smoothstep(0.65, 0.85, progress))
		magazine.position += Vector3(0, -0.16, 0.03) * drop
	# Retract before reaching walls. Hide only at extremely close contact.
	var wall := ray(camera.global_position, camera.global_position - camera.global_basis.z * 1.0)
	model.visible = true
	if not wall.is_empty():
		var distance: float = camera.global_position.distance_to(wall.position)
		position.z += maxf(0, 0.95 - distance) * 0.65
		model.visible = distance > 0.38
	flash_left = maxf(0, flash_left - delta)
	hit_left = maxf(0, hit_left - delta)
	flash.visible = flash_left > 0

func reset_handling() -> void:
	# Reload transfers only on completion; cancellation leaves both pools intact.
	reloading = false
	reload_left = 0
	cooldown = 0
	kick = 0
	camera_kick = 0
	aim_blend = 0
	slide_blend = 0
	aiming = false
	sway = Vector2.ZERO
	flash_left = 0
	hit_left = 0
	block_trigger()
	animate_weapon(0)

func block_trigger() -> void:
	trigger_armed = false

func play_sound(stream: AudioStream) -> void:
	if stream:
		audio.stream = stream
		audio.play()

func spawn_impact(point: Vector3, damaged: bool) -> void:
	var effect := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.035
	sphere.height = 0.07
	effect.mesh = sphere
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1, 0.25, 0.12) if damaged else Color(1, 0.85, 0.45)
	effect.material_override = material
	effect.process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().current_scene.add_child(effect)
	effect.global_position = point
	var tween := effect.create_tween()
	tween.tween_property(effect, "scale", Vector3.ONE * 0.05, 0.18)
	tween.tween_callback(effect.queue_free)
