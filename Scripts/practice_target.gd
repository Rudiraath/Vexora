extends StaticBody3D
## Reusable damage contract: take_damage(amount, hit_position, source) -> bool.
@export var max_health: float = 100.0
@export var reset_delay: float = 3.0
var health: float
var reset_left := 0.0
var flash_left := 0.0
var material: StandardMaterial3D
@onready var label: Label3D = $Label3D

func _ready() -> void:
	health = max_health
	material = StandardMaterial3D.new()
	$MeshInstance3D.material_override = material
	update_display()

func take_damage(amount: float, _point: Vector3, _source: Node) -> bool:
	if health <= 0 or amount <= 0:
		return false
	health = maxf(0, health - amount)
	flash_left = 0.15
	if health <= 0:
		reset_left = reset_delay
	update_display()
	return true

func _physics_process(delta: float) -> void:
	flash_left = maxf(0, flash_left - delta)
	if reset_left > 0:
		reset_left = maxf(0, reset_left - delta)
		if reset_left == 0:
			health = max_health
	update_display()

func update_display() -> void:
	material.albedo_color = Color(1, 0.25, 0.12) if flash_left > 0 else Color(0.1, 0.75, 0.65)
	$MeshInstance3D.visible = health > 0
	$CollisionShape3D.set_deferred("disabled", health <= 0)
	label.text = "TARGET  %d / %d" % [health, max_health] if health > 0 else "RESET  %.1fs" % reset_left
