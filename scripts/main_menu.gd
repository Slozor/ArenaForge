extends Control

const GAME_SCENE: String = "res://scenes/game/game_scene.tscn"
const SETTINGS_SCENE: String = "res://scenes/settings_menu.tscn"

var _start_button: Button = null
var _settings_button: Button = null
var _quit_button: Button = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UISettings.apply_audio(UISettings.load_settings())
	_build_menu()


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
	add_child(bg)

	var accent := ColorRect.new()
	accent.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	accent.color = Color(0.09, 0.12, 0.16, 0.18)
	add_child(accent)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 420)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

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

	_start_button = _make_menu_button("Start Game")
	_start_button.pressed.connect(_on_start_pressed)
	box.add_child(_start_button)

	_settings_button = _make_menu_button("Settings")
	_settings_button.pressed.connect(_on_settings_pressed)
	box.add_child(_settings_button)

	_quit_button = _make_menu_button("Quit")
	_quit_button.pressed.connect(_on_quit_pressed)
	box.add_child(_quit_button)


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
