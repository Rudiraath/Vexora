extends Area3D
@export var damage_per_tick: float = 25.0
@export var tick_interval: float = 0.5
var next_tick: Dictionary = {}
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	$Label3D.text = "DAMAGE TEST\n%d HP every %.1fs\nSTEP OFF TO STOP" % [damage_per_tick, tick_interval]
	body_exited.connect(func(body: Node3D): next_tick.erase(body.get_instance_id()))
func _physics_process(delta: float) -> void:
	for body in get_overlapping_bodies():
		if not body.is_in_group("players") or not body.has_method("take_damage"):
			continue
		var id := body.get_instance_id()
		var remaining: float = next_tick.get(id, 0.0) - delta
		if remaining <= 0:
			body.take_damage(damage_per_tick, body.global_position, self)
			remaining = maxf(tick_interval, 0.05)
		next_tick[id] = remaining
