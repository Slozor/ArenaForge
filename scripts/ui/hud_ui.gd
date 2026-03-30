extends Control

class_name HudUI

# Trait panel colors
const TRAIT_INACTIVE: Color = Color(0.25, 0.28, 0.32)
const TRAIT_ACTIVE: Color = Color(0.75, 0.60, 0.15)
const TRAIT_TEXT: Color = Color(1.0, 0.90, 0.5)

var _health_label: Label = null
var _round_label: Label = null
var _stage_indicators: Array[ColorRect] = []
var _trait_entries: Dictionary = {}   # trait_id -> { "bg", "label", "count_label" }
var _skip_btn: Button = null

signal skip_prep_pressed()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	custom_minimum_size = Vector2(1280, 50)
	_build_top_bar()
	_build_trait_panel()
	_build_stage_tracker()

	GameManager.health_changed.connect(_on_health_changed)
	GameManager.round_changed.connect(_on_round_changed)
	GameManager.gold_changed.connect(_on_gold_changed)


func _build_top_bar() -> void:
	var bar := ColorRect.new()
	bar.color = Color(0.06, 0.07, 0.10, 0.92)
	bar.custom_minimum_size = Vector2(1280, 50)
	add_child(bar)

	var bottom_line := ColorRect.new()
	bottom_line.color = Color(0.3, 0.35, 0.45)
	bottom_line.custom_minimum_size = Vector2(1280, 2)
	bottom_line.position = Vector2(0, 48)
	add_child(bottom_line)

	# ♥ Health
	var heart := Label.new()
	heart.text = "♥"
	heart.position = Vector2(16, 10)
	heart.add_theme_font_size_override("font_size", 22)
	heart.add_theme_color_override("font_color", Color(0.9, 0.2, 0.25))
	add_child(heart)

	_health_label = Label.new()
	_health_label.text = "100"
	_health_label.position = Vector2(40, 12)
	_health_label.add_theme_font_size_override("font_size", 20)
	_health_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(_health_label)

	# Round label
	_round_label = Label.new()
	_round_label.text = "Round 1 / 12"
	_round_label.position = Vector2(0, 14)
	_round_label.custom_minimum_size = Vector2(1280, 22)
	_round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_round_label.add_theme_font_size_override("font_size", 18)
	_round_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.95))
	add_child(_round_label)

	# Skip prep button (right side)
	_skip_btn = Button.new()
	_skip_btn.text = "▶ Ready"
	_skip_btn.position = Vector2(1140, 8)
	_skip_btn.custom_minimum_size = Vector2(124, 34)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.45, 0.20)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	_skip_btn.add_theme_stylebox_override("normal", style)
	_skip_btn.add_theme_font_size_override("font_size", 14)
	_skip_btn.pressed.connect(func(): skip_prep_pressed.emit())
	add_child(_skip_btn)


func _build_stage_tracker() -> void:
	# 12 round dots centered in the top bar
	var dot_size: float = 14.0
	var dot_gap: float = 6.0
	var total_w: float = 12 * dot_size + 11 * dot_gap
	var start_x: float = (1280.0 - total_w) / 2.0 - 60.0  # offset left of center label

	for i in 12:
		var dot := ColorRect.new()
		dot.color = Color(0.3, 0.32, 0.38)
		dot.custom_minimum_size = Vector2(dot_size, dot_size)
		dot.position = Vector2(start_x + i * (dot_size + dot_gap), 18)
		add_child(dot)
		_stage_indicators.append(dot)


func _build_trait_panel() -> void:
	# Left side panel: shows active traits
	var panel_bg := ColorRect.new()
	panel_bg.color = Color(0.07, 0.08, 0.11, 0.88)
	panel_bg.custom_minimum_size = Vector2(140, 380)
	panel_bg.position = Vector2(0, 50)
	add_child(panel_bg)

	var title := Label.new()
	title.text = "SYNERGIES"
	title.position = Vector2(4, 56)
	title.custom_minimum_size = Vector2(132, 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	add_child(title)

	# We'll populate trait rows dynamically when synergies change
	var all_traits: Array = []
	for id in DataManager.races:
		all_traits.append({ "id": id, "data": DataManager.races[id], "type": "race" })
	for id in DataManager.classes:
		all_traits.append({ "id": id, "data": DataManager.classes[id], "type": "class" })

	var row_y: float = 78.0
	for entry in all_traits:
		var trait_id: String = entry["id"]
		var label_text: String = entry["data"].get("name", trait_id)

		var row_bg := ColorRect.new()
		row_bg.color = TRAIT_INACTIVE
		row_bg.custom_minimum_size = Vector2(128, 24)
		row_bg.position = Vector2(6, row_y)
		add_child(row_bg)

		var icon_bg := ColorRect.new()
		icon_bg.color = Color(0.18, 0.20, 0.26)
		icon_bg.custom_minimum_size = Vector2(20, 20)
		icon_bg.position = Vector2(8, row_y + 2)
		add_child(icon_bg)

		var lbl := Label.new()
		lbl.text = label_text
		lbl.position = Vector2(32, row_y + 4)
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(0.7, 0.72, 0.78))
		add_child(lbl)

		var count_lbl := Label.new()
		count_lbl.text = "0"
		count_lbl.position = Vector2(110, row_y + 4)
		count_lbl.add_theme_font_size_override("font_size", 11)
		count_lbl.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
		add_child(count_lbl)

		_trait_entries[trait_id] = {
			"bg": row_bg,
			"label": lbl,
			"count": count_lbl
		}
		row_y += 28.0


# ── Public: update traits display ──────────────────────────────────────────

func update_synergies(board_units: Array) -> void:
	# Reset all
	for id in _trait_entries:
		var e: Dictionary = _trait_entries[id]
		(e["bg"] as ColorRect).color = TRAIT_INACTIVE
		(e["label"] as Label).add_theme_color_override("font_color", Color(0.7, 0.72, 0.78))
		(e["count"] as Label).text = "0"
		(e["count"] as Label).add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))

	# Count
	var race_counts: Dictionary = {}
	var class_counts: Dictionary = {}
	for unit in board_units:
		race_counts[unit.race] = race_counts.get(unit.race, 0) + 1
		class_counts[unit.trait] = class_counts.get(unit.trait, 0) + 1

	var all_counts: Dictionary = {}
	for k in race_counts:
		all_counts[k] = race_counts[k]
	for k in class_counts:
		all_counts[k] = class_counts[k]

	for id in all_counts:
		if not _trait_entries.has(id):
			continue
		var cnt: int = all_counts[id]
		var e: Dictionary = _trait_entries[id]
		(e["count"] as Label).text = str(cnt)

		# Check if active
		var is_active: bool = false
		var data: Dictionary = DataManager.get_race(id)
		if data.is_empty():
			data = DataManager.get_class(id)
		for threshold in data.get("thresholds", []):
			if cnt >= threshold.get("count", 999):
				is_active = true

		if is_active:
			(e["bg"] as ColorRect).color = TRAIT_ACTIVE.darkened(0.3)
			(e["label"] as Label).add_theme_color_override("font_color", TRAIT_TEXT)
			(e["count"] as Label).add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))


func set_skip_button_visible(visible_state: bool) -> void:
	_skip_btn.visible = visible_state


# ── Signal handlers ────────────────────────────────────────────────────────

func _on_health_changed(hp: int) -> void:
	_health_label.text = str(hp)
	if hp <= 30:
		_health_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))
	elif hp <= 60:
		_health_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.2))
	else:
		_health_label.add_theme_color_override("font_color", Color.WHITE)


func _on_round_changed(round_num: int) -> void:
	_round_label.text = "Round %d / 12" % round_num
	_update_stage_dots(round_num)


func _on_gold_changed(_gold: int) -> void:
	pass  # Gold shown in ShopUI


func _update_stage_dots(current: int) -> void:
	for i in _stage_indicators.size():
		var dot: ColorRect = _stage_indicators[i]
		if i + 1 < current:
			dot.color = Color(0.2, 0.55, 0.25)   # won (green)
		elif i + 1 == current:
			dot.color = Color(1.0, 0.78, 0.1)    # current (yellow)
		else:
			dot.color = Color(0.3, 0.32, 0.38)   # future (gray)
