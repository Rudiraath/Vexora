extends CharacterBody3D

signal health_changed(current: float, maximum: float)
signal eliminated(source: Node)
signal respawned
@export_group("Health")
@export var max_health: float = 150.0
@export var respawn_delay: float = 2.0
@export var spawn_protection_duration: float = 1.0
var health: float = 150.0
var is_dead := false
var respawn_left := 0.0
var protection_left := 0.0
var damage_flash_left := 0.0

@export_group("Ground movement")
@export var move_speed: float = 4.5
@export var ground_acceleration: float = 14.0
@export var ground_deceleration: float = 12.0
@export var turn_acceleration: float = 18.0
@export var reverse_acceleration: float = 20.0
@export var momentum_deceleration: float = 6.0
const JUMP_SPEED := 5.5
const GRAVITY := 18.0
@export_group("Air movement")
@export var air_acceleration: float = 7.0
@export var air_drag: float = 0.25
@export var air_momentum_decay: float = 0.6
@export_group("View")
@export var mouse_sensitivity: float = 0.0022
@export var base_fov: float = 90.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var weapon = $Head/Camera3D/AssaultRifle
@export_group("Slide")
@export var slide_speed: float = 8.8
@export var slide_duration: float = 0.7
@export var slide_cooldown: float = 0.0
@export var slide_min_speed: float = 3.2
@export var slide_friction: float = 4.0
@export var slide_height: float = 1.05
@export var slide_camera_height: float = 0.9
var is_sliding := false
var is_crouched := false
var slide_left := 0.0
var slide_cooldown_left := 0.0
var slide_armed := true
var standing_shape: CapsuleShape3D
@onready var body_shape: CollisionShape3D = $CollisionShape3D
var spawn_transform := Transform3D.IDENTITY
var controls_enabled := true
var animation_player: AnimationPlayer
var animation_names: Dictionary = {}

func _ready() -> void:
	health = max_health
	add_to_group("players")
	standing_shape = body_shape.shape.duplicate() as CapsuleShape3D
	body_shape.shape = body_shape.shape.duplicate()
	# Keep the existing character at its original scale; render its shadow in FPS view.
	for node in $Visual.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.name == "Cube":
			mesh.hide()
		else:
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	var players := $Visual.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		animation_player = players[0] as AnimationPlayer
		for animation_name in animation_player.get_animation_list():
			var short_name: String = String(animation_name).get_slice("/", String(animation_name).get_slice_count("/") - 1)
			animation_names[short_name] = animation_name
			if short_name in ["Idle", "Run", "Fall"]:
				# Duplicate only the runtime resource; the imported animation stays untouched.
				var library_name := ""
				if "/" in String(animation_name):
					library_name = String(animation_name).get_slice("/", 0)
				var library := animation_player.get_animation_library(library_name)
				var animation := animation_player.get_animation(animation_name).duplicate() as Animation
				animation.loop_mode = Animation.LOOP_LINEAR
				library.remove_animation(short_name)
				library.add_animation(short_name, animation)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and controls_enabled and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotation.x = clampf(head.rotation.x - event.relative.y * mouse_sensitivity, deg_to_rad(-85), deg_to_rad(85))
	if event.is_action_pressed("respawn") and controls_enabled:
		respawn()

func _physics_process(delta: float) -> void:
	damage_flash_left = maxf(0, damage_flash_left - delta)
	protection_left = maxf(0, protection_left - delta)
	if is_dead:
		respawn_left = maxf(0, respawn_left - delta)
		if respawn_left == 0:
			respawn(true)
		return
	if not controls_enabled:
		return
	slide_cooldown_left = maxf(0.0, slide_cooldown_left - delta)
	var grounded := is_on_floor()
	var movement := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := global_basis * Vector3(movement.x, 0, movement.y)
	if not Input.is_action_pressed("slide"):
		slide_armed = true
	elif slide_armed:
		slide_armed = false
		start_slide()
	if not grounded:
		velocity.y -= GRAVITY * delta
	elif Input.is_action_just_pressed("jump") and can_stand():
		end_slide()
		velocity.y = JUMP_SPEED
	if is_sliding:
		slide_left = maxf(0.0, slide_left - delta)
		var horizontal := Vector3(velocity.x, 0, velocity.z)
		horizontal = horizontal.move_toward(Vector3.ZERO, slide_friction * delta)
		velocity.x = horizontal.x
		velocity.z = horizontal.z
		if slide_left == 0.0 or not grounded:
			end_slide()
	else:
		var speed := move_speed * (0.6 if is_crouched else 1.0)
		var horizontal := Vector3(velocity.x, 0, velocity.z)
		if grounded and velocity.y <= 0.0:
			horizontal = ground_velocity(horizontal, direction, speed, delta)
		else:
			horizontal = air_velocity(horizontal, direction, delta)
		velocity.x = horizontal.x
		velocity.z = horizontal.z
	update_slide_posture(delta)
	move_and_slide()
	if is_sliding and Vector2(velocity.x, velocity.z).length() < 1.5:
		end_slide()
	var next_animation := "Idle"
	if not is_on_floor():
		next_animation = "Jump" if velocity.y > 0 else "Fall"
	elif Vector2(velocity.x, velocity.z).length() > 0.2:
		next_animation = "Run"
	if animation_player and animation_names.has(next_animation):
		var selected: StringName = animation_names[next_animation]
		if animation_player.current_animation != selected or not animation_player.is_playing():
			animation_player.play(selected, 0.12)
	if global_position.y < -10:
		eliminate(null)

func respawn(new_life: bool = false) -> void:
	is_dead = false
	health = max_health
	respawn_left = 0
	protection_left = spawn_protection_duration if new_life else 0.0
	damage_flash_left = 0
	controls_enabled = not get_tree().paused
	body_shape.set_deferred("disabled", false)
	$Visual.show()
	weapon.show()
	if new_life:
		weapon.ammo = weapon.magazine_size
		weapon.reserve = weapon.starting_reserve
	is_sliding = false
	is_crouched = false
	slide_left = 0.0
	slide_cooldown_left = 0.0
	slide_armed = false
	body_shape.shape.height = standing_shape.height
	body_shape.position.y = standing_shape.height * 0.5
	head.position.y = 1.62
	weapon.reset_handling()
	global_transform = spawn_transform
	var bots := get_parent().get_node_or_null("Bots")
	if new_life and bots and not bots.bots.is_empty():
		global_position = bots.choose_spawn(self) + Vector3(0, 0.08, 0)
		look_at(Vector3(0, global_position.y, 0))
	velocity = Vector3.ZERO
	head.rotation = Vector3.ZERO
	reset_physics_interpolation()
	health_changed.emit(health, max_health)
	respawned.emit()

func start_slide() -> bool:
	if not controls_enabled or get_tree().paused or is_sliding or is_crouched or not is_on_floor() or slide_cooldown_left > 0.0:
		return false
	var horizontal := Vector3(velocity.x, 0, velocity.z)
	if horizontal.length() < slide_min_speed:
		return false
	is_sliding = true
	slide_left = slide_duration
	horizontal = horizontal.normalized() * maxf(horizontal.length(), slide_speed)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	return true

func end_slide() -> void:
	if is_sliding:
		is_sliding = false
		slide_left = 0.0
		slide_cooldown_left = slide_cooldown

func can_stand() -> bool:
	if not is_crouched:
		return true
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = standing_shape
	query.transform = Transform3D(global_basis, global_position + Vector3(0, standing_shape.height * 0.5 + 0.03, 0))
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	query.margin = 0.001
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func update_slide_posture(delta: float) -> void:
	# Feet stay in place. Remain low under cover until there is standing room.
	is_crouched = is_sliding or not can_stand()
	var height := slide_height if is_crouched else standing_shape.height
	body_shape.shape.height = height
	body_shape.position.y = height * 0.5
	head.position.y = lerpf(head.position.y, slide_camera_height if is_crouched else 1.62, 1.0 - exp(-delta * 16.0))

func ground_velocity(current: Vector3, direction: Vector3, speed: float, delta: float) -> Vector3:
	# Move the velocity vector as a whole: diagonal acceleration cannot exceed
	# straight-line acceleration, and steering bends momentum rather than snapping it.
	var target := direction.limit_length(1.0) * speed
	if target.is_zero_approx():
		return current.move_toward(Vector3.ZERO, ground_deceleration * delta)
	var rate := ground_acceleration
	if not current.is_zero_approx():
		var alignment := current.normalized().dot(target.normalized())
		if alignment < -0.1:
			rate = reverse_acceleration
		elif alignment < 0.8:
			rate = turn_acceleration
		elif current.length() > speed:
			# Ease excess slide speed back to running speed without a hard clamp.
			rate = momentum_deceleration
	return current.move_toward(target, rate * delta)

func air_velocity(current: Vector3, direction: Vector3, delta: float) -> Vector3:
	# Keep takeoff momentum; steer with limited acceleration rather than braking
	# toward zero every frame. Input cannot build speed beyond the takeoff speed.
	if direction.is_zero_approx():
		return current.move_toward(Vector3.ZERO, air_drag * delta)
	var speed_limit := maxf(move_speed, current.length() - air_momentum_decay * delta)
	var target := direction.limit_length(1.0) * speed_limit
	return current.move_toward(target, air_acceleration * delta).limit_length(speed_limit)

func ads_fov() -> float:
	# Keep the same magnification ratio at every selected base FOV.
	return rad_to_deg(2.0 * atan(tan(deg_to_rad(base_fov) * 0.5) * 0.66))

func take_damage(amount: float, _point: Vector3 = Vector3.ZERO, source: Node = null) -> bool:
	# Same damage receiver contract as practice targets; suitable for future bots.
	if is_dead or get_tree().paused or protection_left > 0 or not is_finite(amount) or amount <= 0:
		return false
	health = maxf(0, health - amount)
	damage_flash_left = 0.22
	health_changed.emit(health, max_health)
	if health == 0:
		eliminate(source)
	return true

func eliminate(source: Node = null) -> void:
	if is_dead:
		return
	is_dead = true
	health = 0
	respawn_left = respawn_delay
	controls_enabled = false
	velocity = Vector3.ZERO
	end_slide()
	slide_armed = false
	weapon.reset_handling()
	weapon.hide()
	$Visual.hide()
	body_shape.set_deferred("disabled", true)
	if animation_player:
		animation_player.pause()
	health_changed.emit(health, max_health)
	eliminated.emit(source)
