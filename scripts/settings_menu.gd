extends Control

const MAIN_MENU_SCENE: String = "res://scenes/main_menu.tscn"

var _settings: Dictionary = {}
var _volume_slider: HSlider = null
var _touch_toggle: CheckButton = null
var _presentation_option: OptionButton = null
var _panel: PanelContainer = null
var _profile_summary: Label = null
var _history_list: VBoxContainer = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings = UISettings.load_settings()
	_build_ui()
	_apply_settings_to_controls()
	_refresh_profile_section()
	UISettings.apply_audio(_settings)
	if not resized.is_connected(_refresh_layout):
		resized.connect(_refresh_layout)
	_refresh_layout()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.045, 0.055, 0.075, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(520, 520)
	center.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)

	var title := Label.new()
	title.text = "Settings"
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Audio and input preferences for desktop and mobile."
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.75, 0.8, 0.88))
	box.add_child(subtitle)

	var volume_row := _build_slider("Master Volume", -30.0, 0.0, 0.5)
	_volume_slider.value_changed.connect(_on_volume_changed)
	box.add_child(volume_row)

	_touch_toggle = CheckButton.new()
	_touch_toggle.text = "Show touch hints in game"
	_touch_toggle.toggled.connect(_on_touch_toggle_changed)
	box.add_child(_touch_toggle)

	_presentation_option = OptionButton.new()
	_presentation_option.add_item("Auto", 0)
	_presentation_option.add_item("Desktop", 1)
	_presentation_option.add_item("Mobile", 2)
	_presentation_option.item_selected.connect(_on_presentation_changed)
	box.add_child(_presentation_option)

	var note := Label.new()
	note.text = "Tip: Landscape works best for ArenaForge right now. Portrait support comes later."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 12)
	note.add_theme_color_override("font_color", Color(0.7, 0.74, 0.8))
	box.add_child(note)

	var profile_title := Label.new()
	profile_title.text = "Run History"
	profile_title.add_theme_font_size_override("font_size", 20)
	box.add_child(profile_title)

	_profile_summary = Label.new()
	_profile_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_profile_summary.add_theme_font_size_override("font_size", 12)
	_profile_summary.add_theme_color_override("font_color", Color(0.82, 0.84, 0.90))
	box.add_child(_profile_summary)

	var history_panel := PanelContainer.new()
	history_panel.custom_minimum_size = Vector2(0, 120)
	box.add_child(history_panel)

	var history_margin := MarginContainer.new()
	history_margin.add_theme_constant_override("margin_left", 10)
	history_margin.add_theme_constant_override("margin_right", 10)
	history_margin.add_theme_constant_override("margin_top", 10)
	history_margin.add_theme_constant_override("margin_bottom", 10)
	history_panel.add_child(history_margin)

	_history_list = VBoxContainer.new()
	_history_list.add_theme_constant_override("separation", 4)
	history_margin.add_child(_history_list)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 10)
	box.add_child(button_row)

	var save_btn := Button.new()
	save_btn.text = "Save"
	save_btn.custom_minimum_size = Vector2(0, 46)
	save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_btn.pressed.connect(_on_save_pressed)
	button_row.add_child(save_btn)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(0, 46)
	back_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_btn.pressed.connect(_on_back_pressed)
	button_row.add_child(back_btn)


func _build_slider(label_text: String, min_value: float, max_value: float, step: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(150, 24)
	row.add_child(label)

	_volume_slider = HSlider.new()
	_volume_slider.min_value = min_value
	_volume_slider.max_value = max_value
	_volume_slider.step = step
	_volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_volume_slider)

	return row


func _apply_settings_to_controls() -> void:
	_volume_slider.value = float(_settings.get(UISettings.KEY_MASTER_VOLUME_DB, -6.0))
	_touch_toggle.button_pressed = bool(_settings.get(UISettings.KEY_TOUCH_HINTS, true))
	var mode: String = str(_settings.get(UISettings.KEY_PRESENTATION_MODE, "auto"))
	match mode:
		"desktop":
			_presentation_option.select(1)
		"mobile":
			_presentation_option.select(2)
		_:
			_presentation_option.select(0)


func _on_volume_changed(value: float) -> void:
	_settings[UISettings.KEY_MASTER_VOLUME_DB] = value
	UISettings.apply_audio(_settings)


func _on_touch_toggle_changed(toggled: bool) -> void:
	_settings[UISettings.KEY_TOUCH_HINTS] = toggled


func _on_presentation_changed(index: int) -> void:
	var mode: String = "auto"
	if index == 1:
		mode = "desktop"
	elif index == 2:
		mode = "mobile"
	_settings[UISettings.KEY_PRESENTATION_MODE] = mode


func _on_save_pressed() -> void:
	UISettings.save_settings(_settings)


func _on_back_pressed() -> void:
	UISettings.save_settings(_settings)
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _refresh_layout() -> void:
	var size_v: Vector2 = get_viewport_rect().size
	if _panel != null:
		_panel.custom_minimum_size = Vector2(clampf(size_v.x * 0.42, 360.0, 680.0), clampf(size_v.y * 0.72, 460.0, 760.0))


func _refresh_profile_section() -> void:
	if _profile_summary == null or _history_list == null:
		return
	var profile: Dictionary = ProfileManager.get_profile()
	_profile_summary.text = "Runs %d | Wins %d | Best placement %d" % [
		int(profile.get("total_runs", 0)),
		int(profile.get("wins", 0)),
		int(profile.get("best_placement", 8))
	]
	for child in _history_list.get_children():
		child.queue_free()
	var history: Array = ProfileManager.get_run_history()
	if history.is_empty():
		var empty := Label.new()
		empty.text = "No finished runs yet."
		empty.add_theme_font_size_override("font_size", 11)
		empty.add_theme_color_override("font_color", Color(0.7, 0.74, 0.8))
		_history_list.add_child(empty)
		return
	for i in mini(5, history.size()):
		var run: Dictionary = history[i]
		var row := Label.new()
		row.text = "#%d  Place %d  Round %d  %s" % [
			i + 1,
			int(run.get("placement", 8)),
			int(run.get("round", 0)),
			str(run.get("encounter", "")).replace("_", " ").capitalize()
		]
		row.add_theme_font_size_override("font_size", 11)
		row.add_theme_color_override("font_color", Color(0.82, 0.84, 0.90))
		_history_list.add_child(row)
