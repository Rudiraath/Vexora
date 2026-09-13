extends CanvasLayer
@onready var player = get_parent().get_node("Player")
var bar: ProgressBar
var value_label: Label
var protection_label: Label
var damage_flash: ColorRect
var death_overlay: ColorRect
var death_message: Label
func _ready() -> void:
	layer = 0
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	damage_flash = overlay(root, Color(0.85, 0.08, 0.03, 0))
	death_overlay = overlay(root, Color(0.015, 0.025, 0.04, 0.72))
	death_message = Label.new()
	death_message.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	death_message.offset_left = -280
	death_message.offset_right = 280
	death_message.offset_top = -90
	death_message.offset_bottom = 90
	death_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	death_message.add_theme_font_size_override("font_size", 30)
	death_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_overlay.add_child(death_message)
	var box := VBoxContainer.new()
	root.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	box.offset_left = 30
	box.offset_top = -157
	box.offset_right = 315
	box.offset_bottom = -61
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_label = Label.new()
	value_label.add_theme_font_size_override("font_size", 26)
	value_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	value_label.add_theme_constant_override("shadow_offset_y", 2)
	box.add_child(value_label)
	bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(285, 18)
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("6ee8a0")
	fill.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("fill", fill)
	var background := StyleBoxFlat.new()
	background.bg_color = Color("182b33")
	background.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("background", background)
	box.add_child(bar)
	protection_label = Label.new()
	protection_label.add_theme_font_size_override("font_size", 14)
	box.add_child(protection_label)

func overlay(root: Control, tint: Color) -> ColorRect:
	var rect := ColorRect.new()
	root.add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.color = tint
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

func _process(_delta: float) -> void:
	bar.max_value = player.max_health
	bar.value = player.health
	value_label.text = "HEALTH  %d / %d" % [player.health, player.max_health]
	var low: bool = player.health <= player.max_health * 0.3
	value_label.modulate = Color(1, 0.35, 0.25) if low else Color.WHITE
	protection_label.text = "SPAWN PROTECTION  %.1fs" % player.protection_left if player.protection_left > 0 else ""
	damage_flash.color.a = (player.damage_flash_left / 0.22) * 0.22
	death_overlay.visible = player.is_dead
	death_message.text = "ELIMINATED\nRespawning in %.1fs" % player.respawn_left
