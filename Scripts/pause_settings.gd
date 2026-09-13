extends ColorRect
## Live view preferences, persisted locally; no gameplay resumes from slider clicks.
@export var settings_path: String = "user://settings.cfg"
@onready var arena = get_node("../..")
@onready var player = arena.get_node("Player")
var sensitivity: HSlider
var fov: HSlider
var sensitivity_label: Label
var fov_label: Label
var save_status: Label
var dirty := false

func _ready() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -250
	panel.offset_right = 250
	panel.offset_top = -215
	panel.offset_bottom = 215
	add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("142b36")
	style.set_corner_radius_all(14)
	style.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	var title := Label.new()
	title.text = "PAUSED / SETTINGS"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("6ee8d0"))
	column.add_child(title)
	var hint := Label.new()
	hint.text = "Adjust your view. Esc returns to the arena."
	column.add_child(hint)
	sensitivity_label = Label.new()
	column.add_child(sensitivity_label)
	sensitivity = make_slider(column, 0.2, 3.0, 0.05)
	fov_label = Label.new()
	column.add_child(fov_label)
	fov = make_slider(column, 70, 110, 1)
	var note := Label.new()
	note.text = "Higher FOV shows more of your surroundings."
	note.add_theme_font_size_override("font_size", 14)
	column.add_child(note)
	var reset := Button.new()
	reset.text = "Reset view defaults"
	reset.pressed.connect(reset_defaults)
	column.add_child(reset)
	var resume := Button.new()
	resume.text = "RESUME"
	resume.custom_minimum_size.y = 44
	resume.pressed.connect(func(): arena.set_mouse_released(false))
	column.add_child(resume)
	save_status = Label.new()
	save_status.add_theme_font_size_override("font_size", 13)
	column.add_child(save_status)
	load_settings()
	sensitivity.value_changed.connect(_setting_changed)
	fov.value_changed.connect(_setting_changed)

func make_slider(column: VBoxContainer, minimum: float, maximum: float, increment: float) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = increment
	slider.custom_minimum_size = Vector2(0, 28)
	column.add_child(slider)
	return slider

func read_number(config: ConfigFile, key: String, fallback: float, minimum: float, maximum: float) -> float:
	var value = config.get_value("view", key, fallback)
	if (value is float or value is int) and is_finite(float(value)):
		return clampf(float(value), minimum, maximum)
	return fallback

func load_settings() -> void:
	var config := ConfigFile.new()
	config.load(settings_path)
	sensitivity.set_value_no_signal(read_number(config, "sensitivity", 1.0, 0.2, 3.0))
	fov.set_value_no_signal(read_number(config, "fov", 90.0, 70, 110))
	apply_settings()
	dirty = false
	save_status.text = "Preferences saved on resume."

func apply_settings() -> void:
	player.mouse_sensitivity = 0.0022 * sensitivity.value
	player.base_fov = fov.value
	player.camera.fov = lerpf(player.base_fov, player.ads_fov(), player.weapon.aim_blend)
	sensitivity_label.text = "Mouse sensitivity   %.2f×" % sensitivity.value
	fov_label.text = "Field of view   %d° (vertical)" % fov.value

func _setting_changed(_value: float) -> void:
	apply_settings()
	dirty = true
	save_status.text = "Changes apply now; saved on resume."

func reset_defaults() -> void:
	sensitivity.set_value_no_signal(1.0)
	fov.set_value_no_signal(90.0)
	_setting_changed(0)

func save_settings() -> void:
	if not dirty:
		return
	var config := ConfigFile.new()
	config.load(settings_path)
	config.set_value("view", "sensitivity", sensitivity.value)
	config.set_value("view", "fov", fov.value)
	var error := config.save(settings_path)
	if error == OK:
		dirty = false
	else:
		save_status.text = "Could not save preferences (%s)." % error_string(error)
		push_warning(save_status.text)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_node_ready():
		save_settings()
