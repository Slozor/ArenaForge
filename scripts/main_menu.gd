extends Control

const GAME_SCENE: String = "res://scenes/game/game_scene.tscn"
const SETTINGS_SCENE: String = "res://scenes/settings_menu.tscn"
const RELEASE_LABEL: String = "Prototype v0.1 - Web Demo"

var _start_button: Button = null
var _settings_button: Button = null
var _quit_button: Button = null
var _panel: PanelContainer = null
var _profile_label: Label = null
var _web_hint_label: Label = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UISettings.apply_audio(UISettings.load_settings())
	_build_menu()
	if ProfileManager != null and ProfileManager.has_signal("profile_changed"):
		ProfileManager.profile_changed.connect(_refresh_profile_summary)
	if not resized.is_connected(_refresh_layout):
		resized.connect(_refresh_layout)
	_refresh_layout()
	_refresh_profile_summary()


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file(SETTINGS_SCENE)


func _on_quit_pressed() -> void:
	get_tree().quit()


func _build_menu() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.055, 0.065, 0.09, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var accent := ColorRect.new()
	accent.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	accent.color = Color(0.09, 0.12, 0.16, 0.18)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(accent)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(460, 420)
	center.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)

	var title := Label.new()
	title.text = "ARENA FORGE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Auto-battler prototype for desktop and mobile"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.75, 0.8, 0.88))
	box.add_child(subtitle)

	var hint := Label.new()
	hint.text = "Tap / click to buy units, place them on board, then hit Ready."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.65, 0.7, 0.76))
	box.add_child(hint)

	var release_label := Label.new()
	release_label.text = RELEASE_LABEL
	release_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	release_label.add_theme_font_size_override("font_size", 11)
	release_label.add_theme_color_override("font_color", Color(0.86, 0.74, 0.34))
	box.add_child(release_label)

	_web_hint_label = Label.new()
	_web_hint_label.text = "Browser demo: best played in landscape at 1280x720 or higher."
	_web_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_web_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_web_hint_label.add_theme_font_size_override("font_size", 10)
	_web_hint_label.add_theme_color_override("font_color", Color(0.62, 0.68, 0.75))
	_web_hint_label.visible = OS.has_feature("web")
	box.add_child(_web_hint_label)

	_profile_label = Label.new()
	_profile_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_profile_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_profile_label.add_theme_font_size_override("font_size", 11)
	_profile_label.add_theme_color_override("font_color", Color(0.82, 0.84, 0.90))
	box.add_child(_profile_label)

	_start_button = _make_menu_button("Start Game")
	_start_button.pressed.connect(_on_start_pressed)
	box.add_child(_start_button)

	_settings_button = _make_menu_button("Settings")
	_settings_button.pressed.connect(_on_settings_pressed)
	box.add_child(_settings_button)

	_quit_button = _make_menu_button("Quit")
	_quit_button.pressed.connect(_on_quit_pressed)
	box.add_child(_quit_button)
	_quit_button.visible = not OS.has_feature("web")


func _make_menu_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 52)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.22, 0.30)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	button.add_theme_stylebox_override("normal", style)
	var hover_style := style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color(0.22, 0.30, 0.40)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_font_size_override("font_size", 15)
	return button


func _refresh_layout() -> void:
	var size_v: Vector2 = get_viewport_rect().size
	if _panel != null:
		_panel.custom_minimum_size = Vector2(clampf(size_v.x * 0.36, 320.0, 520.0), clampf(size_v.y * 0.54, 340.0, 520.0))


func _refresh_profile_summary(_profile: Dictionary = {}) -> void:
	if _profile_label == null:
		return
	var profile: Dictionary = ProfileManager.get_profile()
	var last_summary: Dictionary = profile.get("last_summary", {})
	var summary_text: String = "Runs %d | Wins %d | Best %d" % [
		int(profile.get("total_runs", 0)),
		int(profile.get("wins", 0)),
		int(profile.get("best_placement", 8))
	]
	if not last_summary.is_empty():
		summary_text += "\nLast run: Place %d on round %d" % [
			int(last_summary.get("placement", 8)),
			int(last_summary.get("round", 0))
		]
	_profile_label.text = summary_text
