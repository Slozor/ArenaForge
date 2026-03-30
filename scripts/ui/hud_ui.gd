extends Control

class_name HudUI

# Trait panel colors — mirror UITheme tier system
const TRAIT_INACTIVE: Color = UITheme.TRAIT_INACTIVE
const TRAIT_BRONZE:   Color = UITheme.TRAIT_BRONZE
const TRAIT_SILVER:   Color = UITheme.TRAIT_SILVER
const TRAIT_GOLD_C:   Color = UITheme.TRAIT_GOLD_C
const TRAIT_ACTIVE:   Color = UITheme.TRAIT_GOLD_C   # default active
const TRAIT_TEXT:     Color = UITheme.GOLD_BRIGHT
const TRAIT_BADGE_TEXTURE: Texture2D = preload("res://assets/ui/trait_badge.svg")
const ITEM_TEXTURE: Texture2D = preload("res://assets/items/placeholder_item.svg")
const PREP_PHASE: int = 0
const COMBAT_PHASE: int = 1
const RESULT_PHASE: int = 2

var _health_label: Label = null
var _round_label: Label = null
var _team_label: Label = null
var _bench_label: Label = null
var _phase_label: Label = null
var _result_label: Label = null
var _inventory_label: Label = null
var _inventory_slots: Array[TextureRect] = []
var _inventory_slot_bgs: Array[ColorRect] = []
var _inventory_buttons: Array[Button] = []
var _stage_indicators: Array[ColorRect] = []
var _trait_entries: Dictionary = {}   # trait_id -> { "bg", "label", "count_label" }
var _skip_btn: Button = null
var _overlay: Control = null
var _overlay_title: Label = null
var _overlay_body: Label = null
var _restart_btn: Button = null
var _menu_btn: Button = null
var _board_ui = null
var _bench_ui = null
var _shop_ui = null
var _phase: int = PREP_PHASE
var _touch_hints_enabled: bool = true
var _selected_item_index: int = -1
var _top_bar: ColorRect = null
var _bottom_line: ColorRect = null
var _heart_label: Label = null
var _trait_panel_bg: ColorRect = null
var _trait_title: Label = null
var _overlay_panel: PanelContainer = null
var _inspect_panel: PanelContainer = null
var _inspect_label: Label = null

signal skip_prep_pressed()
signal restart_requested()
signal menu_requested()


func _ready() -> void:
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_PASS
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	custom_minimum_size = Vector2.ZERO
	_touch_hints_enabled = bool(UISettings.load_settings().get(UISettings.KEY_TOUCH_HINTS, true))
	_build_top_bar()
	_build_overview()
	_build_inventory_row()
	_build_trait_panel()
	_build_stage_tracker()
	_build_overlay()
	_build_inspect_panel()
	_bind_scene_peers()
	_refresh_phase_label()

	GameManager.health_changed.connect(_on_health_changed)
	GameManager.round_changed.connect(_on_round_changed)
	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.inventory_changed.connect(_on_inventory_changed)
	GameManager.run_finished.connect(_on_run_finished)
	if not resized.is_connected(_refresh_layout):
		resized.connect(_refresh_layout)
	_refresh_layout()


func _build_top_bar() -> void:
	_top_bar = ColorRect.new()
	_top_bar.color = UITheme.BG_PANEL
	_top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_top_bar)

	_bottom_line = ColorRect.new()
	_bottom_line.color = UITheme.GOLD
	_bottom_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bottom_line)

	# ♥ Health
	_heart_label = Label.new()
	_heart_label.text = "♥"
	_heart_label.position = Vector2(16, 10)
	_heart_label.add_theme_font_size_override("font_size", 22)
	_heart_label.add_theme_color_override("font_color", UITheme.RED_HP)
	add_child(_heart_label)

	_health_label = Label.new()
	_health_label.text = "100"
	_health_label.position = Vector2(40, 12)
	_health_label.add_theme_font_size_override("font_size", 20)
	_health_label.add_theme_color_override("font_color", UITheme.TEXT_PRIMARY)
	add_child(_health_label)

	# Round label
	_round_label = Label.new()
	_round_label.text = "Round 1 / 12"
	_round_label.position = Vector2(0, 14)
	_round_label.custom_minimum_size = Vector2(1280, 22)
	_round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_round_label.add_theme_font_size_override("font_size", 18)
	_round_label.add_theme_color_override("font_color", UITheme.GOLD_BRIGHT)
	add_child(_round_label)

	# Skip prep button (right side)
	_skip_btn = Button.new()
	_skip_btn.text = "▶ Ready"
	_skip_btn.position = Vector2(1140, 8)
	_skip_btn.custom_minimum_size = Vector2(124, 34)
	_skip_btn.add_theme_stylebox_override("normal", UITheme.button_style(UITheme.GREEN_HP.darkened(0.55), UITheme.GREEN_HP, 5))
	_skip_btn.add_theme_color_override("font_color", UITheme.TEXT_PRIMARY)
	_skip_btn.add_theme_font_size_override("font_size", 14)
	_skip_btn.pressed.connect(func(): skip_prep_pressed.emit())
	add_child(_skip_btn)


func _build_overview() -> void:
	_team_label = Label.new()
	_team_label.position = Vector2(980, 12)
	_team_label.custom_minimum_size = Vector2(120, 18)
	_team_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_team_label.add_theme_font_size_override("font_size", 14)
	_team_label.add_theme_color_override("font_color", UITheme.TEXT_SECOND)
	add_child(_team_label)

	_bench_label = Label.new()
	_bench_label.position = Vector2(980, 30)
	_bench_label.custom_minimum_size = Vector2(120, 16)
	_bench_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_bench_label.add_theme_font_size_override("font_size", 12)
	_bench_label.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	add_child(_bench_label)

	_phase_label = Label.new()
	_phase_label.position = Vector2(1120, 12)
	_phase_label.custom_minimum_size = Vector2(140, 22)
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_phase_label.add_theme_font_size_override("font_size", 13)
	_phase_label.add_theme_color_override("font_color", UITheme.TEAL)
	add_child(_phase_label)

	_result_label = Label.new()
	_result_label.position = Vector2(460, 52)
	_result_label.custom_minimum_size = Vector2(360, 24)
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.visible = false
	_result_label.add_theme_font_size_override("font_size", 18)
	_result_label.add_theme_color_override("font_color", UITheme.GOLD_BRIGHT)
	add_child(_result_label)


func _build_inventory_row() -> void:
	_inventory_label = Label.new()
	_inventory_label.text = "Items"
	_inventory_label.position = Vector2(150, 12)
	_inventory_label.add_theme_font_size_override("font_size", 13)
	_inventory_label.add_theme_color_override("font_color", UITheme.TEXT_SECOND)
	add_child(_inventory_label)

	for i in GameManager.MAX_INVENTORY_ITEMS:
		var slot_bg := ColorRect.new()
		slot_bg.color = UITheme.BG_CARD
		slot_bg.position = Vector2(198 + i * 32, 9)
		slot_bg.custom_minimum_size = Vector2(26, 26)
		add_child(slot_bg)
		_inventory_slot_bgs.append(slot_bg)

		var slot_icon := TextureRect.new()
		slot_icon.texture = ITEM_TEXTURE
		slot_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slot_icon.stretch_mode = TextureRect.STRETCH_SCALE
		slot_icon.position = Vector2(199 + i * 32, 10)
		slot_icon.custom_minimum_size = Vector2(24, 24)
		slot_icon.modulate = Color(1, 1, 1, 0.0)
		add_child(slot_icon)
		_inventory_slots.append(slot_icon)

		var slot_btn := Button.new()
		slot_btn.flat = true
		slot_btn.position = Vector2(198 + i * 32, 9)
		slot_btn.custom_minimum_size = Vector2(26, 26)
		slot_btn.pressed.connect(_on_inventory_slot_pressed.bind(i))
		add_child(slot_btn)
		_inventory_buttons.append(slot_btn)


func _build_stage_tracker() -> void:
	# 12 round dots centered in the top bar
	var dot_size: float = 14.0
	var dot_gap: float = 6.0
	var total_w: float = 12 * dot_size + 11 * dot_gap
	var start_x: float = (1280.0 - total_w) / 2.0 - 60.0  # offset left of center label

	for i in 12:
		var dot := ColorRect.new()
		dot.color = UITheme.BORDER_SUBTLE
		dot.custom_minimum_size = Vector2(dot_size, dot_size)
		dot.position = Vector2(start_x + i * (dot_size + dot_gap), 18)
		add_child(dot)
		_stage_indicators.append(dot)


func _build_trait_panel() -> void:
	# Left side panel: shows active traits
	_trait_panel_bg = ColorRect.new()
	_trait_panel_bg.color = Color(UITheme.BG_PANEL.r, UITheme.BG_PANEL.g, UITheme.BG_PANEL.b, 0.90)
	_trait_panel_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_trait_panel_bg)

	_trait_title = Label.new()
	_trait_title.text = "SYNERGIES"
	_trait_title.position = Vector2(4, 56)
	_trait_title.custom_minimum_size = Vector2(132, 18)
	_trait_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_trait_title.add_theme_font_size_override("font_size", 11)
	_trait_title.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	add_child(_trait_title)

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
		row_bg.color = Color(UITheme.TRAIT_INACTIVE.r, UITheme.TRAIT_INACTIVE.g, UITheme.TRAIT_INACTIVE.b, 0.52)
		row_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_bg.custom_minimum_size = Vector2(128, 24)
		row_bg.position = Vector2(6, row_y)
		row_bg.tooltip_text = DataManager.get_trait_tooltip(trait_id)
		add_child(row_bg)

		var row_hitbox := Button.new()
		row_hitbox.flat = true
		row_hitbox.focus_mode = Control.FOCUS_NONE
		row_hitbox.position = Vector2(6, row_y)
		row_hitbox.custom_minimum_size = Vector2(128, 24)
		row_hitbox.tooltip_text = DataManager.get_trait_tooltip(trait_id)
		add_child(row_hitbox)

		var icon_bg := TextureRect.new()
		icon_bg.texture = TRAIT_BADGE_TEXTURE
		icon_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_bg.stretch_mode = TextureRect.STRETCH_SCALE
		icon_bg.custom_minimum_size = Vector2(20, 20)
		icon_bg.position = Vector2(8, row_y + 2)
		icon_bg.modulate = _trait_icon_tint(trait_id)
		icon_bg.tooltip_text = DataManager.get_trait_tooltip(trait_id)
		add_child(icon_bg)

		var lbl := Label.new()
		lbl.text = label_text
		lbl.position = Vector2(32, row_y + 4)
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", UITheme.TEXT_DIM)
		lbl.tooltip_text = DataManager.get_trait_tooltip(trait_id)
		add_child(lbl)

		var count_lbl := Label.new()
		count_lbl.text = "0"
		count_lbl.position = Vector2(110, row_y + 4)
		count_lbl.add_theme_font_size_override("font_size", 11)
		count_lbl.add_theme_color_override("font_color", UITheme.TEXT_DIM)
		count_lbl.tooltip_text = DataManager.get_trait_tooltip(trait_id)
		add_child(count_lbl)

		_trait_entries[trait_id] = {
			"bg": row_bg,
			"label": lbl,
			"count": count_lbl,
			"icon": icon_bg,
			"hitbox": row_hitbox
		}
		row_y += 28.0


func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	add_child(_overlay)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(UITheme.BG_DARK.r, UITheme.BG_DARK.g, UITheme.BG_DARK.b, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	_overlay_panel = PanelContainer.new()
	_overlay_panel.custom_minimum_size = Vector2(420, 260)
	_overlay_panel.add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.BG_PANEL, UITheme.GOLD, 8, 1))
	_overlay_panel.clip_contents = true
	center.add_child(_overlay_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	_overlay_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	_overlay_title = Label.new()
	_overlay_title.text = "Run Complete"
	_overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_title.add_theme_font_size_override("font_size", 28)
	_overlay_title.add_theme_color_override("font_color", UITheme.GOLD_BRIGHT)
	box.add_child(_overlay_title)

	_overlay_body = Label.new()
	_overlay_body.text = ""
	_overlay_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_overlay_body.add_theme_font_size_override("font_size", 15)
	_overlay_body.add_theme_color_override("font_color", UITheme.TEXT_SECOND)
	box.add_child(_overlay_body)

	_restart_btn = Button.new()
	_restart_btn.text = "Play Again"
	_restart_btn.custom_minimum_size = Vector2(0, 46)
	_restart_btn.add_theme_stylebox_override("normal", UITheme.button_style(UITheme.GREEN_HP.darkened(0.55), UITheme.GREEN_HP, 6))
	_restart_btn.add_theme_color_override("font_color", UITheme.TEXT_PRIMARY)
	_restart_btn.pressed.connect(func(): restart_requested.emit())
	box.add_child(_restart_btn)

	_menu_btn = Button.new()
	_menu_btn.text = "Main Menu"
	_menu_btn.custom_minimum_size = Vector2(0, 46)
	_menu_btn.add_theme_stylebox_override("normal", UITheme.button_style(UITheme.BG_PANEL_ALT, UITheme.BORDER_MID, 6))
	_menu_btn.add_theme_color_override("font_color", UITheme.TEXT_SECOND)
	_menu_btn.pressed.connect(func(): menu_requested.emit())
	box.add_child(_menu_btn)


func _build_inspect_panel() -> void:
	_inspect_panel = PanelContainer.new()
	_inspect_panel.visible = false
	_inspect_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inspect_panel.add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.BG_PANEL, UITheme.BORDER_MID, 8, 2))
	_inspect_panel.clip_contents = true
	add_child(_inspect_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	_inspect_panel.add_child(margin)

	_inspect_label = Label.new()
	_inspect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inspect_label.custom_minimum_size = Vector2(240, 0)
	_inspect_label.add_theme_font_size_override("font_size", 12)
	margin.add_child(_inspect_label)


# ── Public: update traits display ──────────────────────────────────────────

func update_synergies(board_units: Array) -> void:
	# Reset all
	for id in _trait_entries:
		var e: Dictionary = _trait_entries[id]
		(e["bg"] as ColorRect).color = Color(UITheme.TRAIT_INACTIVE.r, UITheme.TRAIT_INACTIVE.g, UITheme.TRAIT_INACTIVE.b, 0.52)
		(e["label"] as Label).add_theme_color_override("font_color", UITheme.TEXT_DIM)
		(e["count"] as Label).text = "0"
		(e["count"] as Label).add_theme_color_override("font_color", UITheme.TEXT_DIM)
		(e["icon"] as TextureRect).modulate = _trait_icon_tint(id).darkened(0.35)

	# Count
	var race_counts: Dictionary = {}
	var class_counts: Dictionary = {}
	for unit in board_units:
		race_counts[unit.race] = race_counts.get(unit.race, 0) + 1
		class_counts[unit.trait_id] = class_counts.get(unit.trait_id, 0) + 1

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
			data = DataManager.get_class_data(id)
		for threshold in data.get("thresholds", []):
			if cnt >= threshold.get("count", 999):
				is_active = true

		if is_active:
			# Count how many thresholds are met for tier badge
			var thresholds: Array = data.get("thresholds", [])
			var tiers_met: int = 0
			for threshold in thresholds:
				if cnt >= threshold.get("count", 999):
					tiers_met += 1
			var tier_color: Color
			match tiers_met:
				1: tier_color = UITheme.TRAIT_BRONZE
				2: tier_color = UITheme.TRAIT_SILVER
				_: tier_color = UITheme.TRAIT_GOLD_C
			(e["bg"] as ColorRect).color = tier_color.darkened(0.45)
			(e["label"] as Label).add_theme_color_override("font_color", tier_color.lightened(0.35))
			(e["count"] as Label).add_theme_color_override("font_color", UITheme.GOLD_BRIGHT)
			(e["icon"] as TextureRect).modulate = tier_color.lightened(0.2)

	for id in _trait_entries:
		var entry: Dictionary = _trait_entries[id]
		var count_value: int = int(all_counts.get(id, 0))
		var should_show: bool = count_value > 0
		(entry["bg"] as ColorRect).visible = should_show
		(entry["icon"] as TextureRect).visible = should_show
		(entry["label"] as Label).visible = should_show
		(entry["count"] as Label).visible = should_show
		(entry["hitbox"] as Button).visible = should_show

	_refresh_layout()


func set_skip_button_visible(visible_state: bool) -> void:
	_skip_btn.visible = visible_state


func show_round_result(player_won: bool, reason: String = "") -> void:
	if _result_label == null:
		return
	var status: String = "Victory" if player_won else "Defeat"
	if reason != "":
		status = "%s - %s" % [status, reason.capitalize()]
	_result_label.text = status
	_result_label.add_theme_color_override("font_color", UITheme.GREEN_HP if player_won else UITheme.RED_HP)
	_result_label.visible = true


func hide_round_result() -> void:
	if _result_label != null:
		_result_label.visible = false


func show_run_summary(summary: Dictionary) -> void:
	if _overlay == null:
		return
	var placement: int = summary.get("placement", 0)
	var reason: String = str(summary.get("reason", "completed")).capitalize()
	var round_value: int = summary.get("round", 0)
	var level_value: int = summary.get("level", 1)
	var gold_value: int = summary.get("gold", 0)
	_overlay_title.text = "Victory" if placement == 1 else "Run Complete"
	_overlay_body.text = "Placement #%d\nReason: %s\nRound: %d\nLevel: %d\nGold: %d" % [placement, reason, round_value, level_value, gold_value]
	_overlay.visible = true


func hide_run_summary() -> void:
	if _overlay != null:
		_overlay.visible = false


# ── Signal handlers ────────────────────────────────────────────────────────

func _on_health_changed(hp: int) -> void:
	_health_label.text = str(hp)
	if hp <= 30:
		_health_label.add_theme_color_override("font_color", UITheme.RED_HP)
	elif hp <= 60:
		_health_label.add_theme_color_override("font_color", UITheme.GOLD_BRIGHT)
	else:
		_health_label.add_theme_color_override("font_color", UITheme.TEXT_PRIMARY)


func _on_round_changed(round_num: int) -> void:
	_round_label.text = "Round %d / 12" % round_num
	_update_stage_dots(round_num)
	_refresh_overview()


func _on_gold_changed(_gold: int) -> void:
	pass  # Gold shown in ShopUI


func _on_inventory_changed(items: Array[String]) -> void:
	for i in _inventory_slots.size():
		var icon: TextureRect = _inventory_slots[i]
		var bg: ColorRect = _inventory_slot_bgs[i]
		if i < items.size():
			icon.modulate = _item_tint(items[i])
			icon.tooltip_text = _item_tooltip(items[i])
			bg.color = UITheme.BG_CARD
		else:
			icon.modulate = Color(1, 1, 1, 0.0)
			icon.tooltip_text = ""
			bg.color = Color(UITheme.BG_CARD.r, UITheme.BG_CARD.g, UITheme.BG_CARD.b, 0.45)
	_refresh_inventory_selection()


func _update_stage_dots(current: int) -> void:
	for i in _stage_indicators.size():
		var dot: ColorRect = _stage_indicators[i]
		if i + 1 < current:
			dot.color = UITheme.GREEN_HP.darkened(0.3)
		elif i + 1 == current:
			dot.color = UITheme.GOLD_BRIGHT
		else:
			dot.color = UITheme.BORDER_SUBTLE


func _bind_scene_peers() -> void:
	var root: Node = get_parent()
	if root == null:
		root = get_tree().current_scene
	if root == null:
		return

	_board_ui = root.get_node_or_null("BoardUI")
	_bench_ui = root.get_node_or_null("BenchUI")
	_shop_ui = root.get_node_or_null("ShopUI")

	if root.has_signal("phase_changed") and not root.phase_changed.is_connected(_on_phase_changed):
		root.phase_changed.connect(_on_phase_changed)

	skip_prep_pressed.connect(_on_skip_prep_pressed)

	if _board_ui != null:
		if not _board_ui.unit_tapped.is_connected(_on_unit_targeted_for_item):
			_board_ui.unit_tapped.connect(_on_unit_targeted_for_item)
		_board_ui.unit_placed.connect(func(_unit, _col, _row): _refresh_overview())
		_board_ui.unit_moved.connect(func(_unit, _from, _to): _refresh_overview())
		_board_ui.unit_sent_to_bench.connect(func(_unit): _refresh_overview())

	if _bench_ui != null:
		_bench_ui.unit_sold.connect(func(_unit): _refresh_overview())
		_bench_ui.unit_selected_from_bench.connect(func(_unit): _refresh_overview())
		if not _bench_ui.unit_selected_from_bench.is_connected(_on_unit_targeted_for_item):
			_bench_ui.unit_selected_from_bench.connect(_on_unit_targeted_for_item)

	if _shop_ui != null:
		_shop_ui.unit_bought.connect(func(_unit_id): _refresh_overview())

	_refresh_overview()


func _on_skip_prep_pressed() -> void:
	var root: Node = get_parent()
	if root == null:
		root = get_tree().current_scene
	if root != null and root.has_method("skip_prep"):
		root.call("skip_prep")


func _on_phase_changed(phase: int) -> void:
	_phase = phase
	if phase == PREP_PHASE:
		hide_round_result()
	for button in _inventory_buttons:
		button.disabled = phase != PREP_PHASE
	if phase != PREP_PHASE and _selected_item_index != -1:
		_selected_item_index = -1
		_refresh_inventory_selection()
	if _inspect_panel != null and phase != COMBAT_PHASE:
		_inspect_panel.visible = false
	_refresh_phase_label()
	_refresh_overview()


func _refresh_phase_label() -> void:
	if _phase_label == null:
		return
	match _phase:
		PREP_PHASE:
			_phase_label.text = "Prep"
		COMBAT_PHASE:
			_phase_label.text = "Combat"
		RESULT_PHASE:
			_phase_label.text = "Result"
		_:
			_phase_label.text = "Menu"


func _refresh_layout() -> void:
	var view_size: Vector2 = get_viewport_rect().size
	var width: float = maxf(640.0, view_size.x)
	var height: float = maxf(360.0, view_size.y)
	position = Vector2.ZERO
	size = Vector2(width, height)
	var compact: bool = width < 980.0
	var very_compact: bool = width < 1260.0
	var top_h: float = 54.0 if not compact else 62.0
	var trait_w: float = 132.0 if not compact else 112.0
	var inventory_x: float = 118.0 if not compact else 90.0
	var slot_step: float = 28.0 if very_compact else 32.0
	var slot_size: float = 22.0 if very_compact else 26.0
	var button_w: float = 124.0 if not compact else 104.0

	if _top_bar != null:
		_top_bar.size = Vector2(width, top_h)
	if _bottom_line != null:
		_bottom_line.position = Vector2(0.0, top_h - 2.0)
		_bottom_line.size = Vector2(width, 2.0)
	if _heart_label != null:
		_heart_label.position = Vector2(16.0, 14.0 if compact else 10.0)
	if _health_label != null:
		_health_label.position = Vector2(40.0, 16.0 if compact else 12.0)
	if _round_label != null:
		var round_width: float = 140.0 if not compact else 120.0
		_round_label.position = Vector2((width - round_width) * 0.5, 8.0)
		_round_label.custom_minimum_size = Vector2(round_width, 22.0)
		_round_label.add_theme_font_size_override("font_size", 16 if very_compact else 18)
	if _skip_btn != null:
		_skip_btn.position = Vector2(width - button_w - 16.0, 12.0 if compact else 10.0)
		_skip_btn.custom_minimum_size = Vector2(button_w, 36.0 if compact else 34.0)
		_skip_btn.size = _skip_btn.custom_minimum_size
	var right_info_x: float = width - (button_w + 118.0 if not compact else button_w + 106.0)
	if _team_label != null:
		_team_label.position = Vector2(right_info_x, 8.0 if compact else 8.0)
		_team_label.custom_minimum_size = Vector2(90.0, 18.0)
	if _bench_label != null:
		_bench_label.position = Vector2(right_info_x, 24.0 if compact else 24.0)
		_bench_label.custom_minimum_size = Vector2(90.0, 16.0)
	if _phase_label != null:
		_phase_label.position = Vector2(right_info_x - (86.0 if compact else 96.0), 8.0)
		_phase_label.custom_minimum_size = Vector2(76.0 if compact else 88.0, 22.0)
		_phase_label.add_theme_font_size_override("font_size", 12 if very_compact else 13)
	if _result_label != null:
		_result_label.position = Vector2((width - minf(360.0, width - 180.0)) * 0.5, top_h + 2.0)
		_result_label.custom_minimum_size = Vector2(minf(360.0, width - 180.0), 24.0)
	if _inventory_label != null:
		_inventory_label.position = Vector2(inventory_x, 8.0 if compact else 12.0)
	for i in _inventory_slot_bgs.size():
		var x: float = inventory_x + 48.0 + i * slot_step
		_inventory_slot_bgs[i].position = Vector2(x, 9.0)
		_inventory_slot_bgs[i].custom_minimum_size = Vector2(slot_size, slot_size)
		_inventory_slots[i].position = Vector2(x + 1.0, 10.0)
		_inventory_slots[i].custom_minimum_size = Vector2(slot_size - 2.0, slot_size - 2.0)
		_inventory_buttons[i].position = Vector2(x, 9.0)
		_inventory_buttons[i].custom_minimum_size = Vector2(slot_size, slot_size)

	for i in _stage_indicators.size():
		_stage_indicators[i].visible = false

	if _trait_panel_bg != null:
		_trait_panel_bg.position = Vector2.ZERO
		_trait_panel_bg.size = Vector2(trait_w, maxf(260.0, height - 200.0 - 88.0))
	if _trait_title != null:
		_trait_title.position = Vector2(4.0, top_h + 6.0)
		_trait_title.custom_minimum_size = Vector2(trait_w - 8.0, 18.0)

	var row_y: float = top_h + 20.0
	for trait_id in _trait_entries:
		var e: Dictionary = _trait_entries[trait_id]
		if not (e["bg"] as ColorRect).visible:
			continue
		(e["bg"] as ColorRect).position = Vector2(6.0, row_y)
		(e["bg"] as ColorRect).custom_minimum_size = Vector2(trait_w - 12.0, 22.0)
		(e["icon"] as TextureRect).position = Vector2(8.0, row_y + 2.0)
		(e["label"] as Label).position = Vector2(32.0, row_y + 3.0)
		(e["label"] as Label).add_theme_font_size_override("font_size", 10)
		(e["count"] as Label).position = Vector2(trait_w - 24.0, row_y + 3.0)
		(e["count"] as Label).add_theme_font_size_override("font_size", 10)
		(e["hitbox"] as Button).position = Vector2(6.0, row_y)
		(e["hitbox"] as Button).custom_minimum_size = Vector2(trait_w - 12.0, 22.0)
		row_y += 24.0
	if _overlay_panel != null:
		_overlay_panel.custom_minimum_size = Vector2(clampf(width * 0.38, 320.0, 520.0), clampf(height * 0.34, 220.0, 340.0))
	if _inspect_panel != null:
		_inspect_panel.position = Vector2(width - clampf(width * 0.28, 250.0, 340.0) - 18.0, top_h + 10.0)
		_inspect_panel.custom_minimum_size = Vector2(clampf(width * 0.28, 250.0, 340.0), 0.0)


func _refresh_overview() -> void:
	if _team_label != null:
		_team_label.text = "Board %d/%d" % [_get_team_count(), _get_team_capacity()]
	if _bench_label != null:
		_bench_label.text = "Bench %d/%d" % [_get_bench_count(), _get_bench_capacity()]
	if _skip_btn != null:
		_skip_btn.text = "▶ Ready" if _touch_hints_enabled else "Ready"
	if _inventory_label != null:
		var label_text := "Items %d/%d" % [GameManager.get_item_inventory_size(), GameManager.MAX_INVENTORY_ITEMS]
		if _selected_item_index >= 0:
			label_text += " - Tap item to craft or unit to equip"
		_inventory_label.text = label_text


func _get_team_count() -> int:
	if _board_ui != null:
		return _board_ui.get_unit_count()
	return 0


func _get_team_capacity() -> int:
	if _board_ui != null:
		return _board_ui.get_team_capacity()
	return 5


func _get_bench_count() -> int:
	if _bench_ui != null:
		return _bench_ui.get_unit_count()
	return 0


func _get_bench_capacity() -> int:
	if _bench_ui != null:
		return _bench_ui.get_capacity()
	return 9


func _trait_icon_tint(trait_id: String) -> Color:
	match trait_id:
		"human":
			return Color(0.75, 0.90, 1.00)
		"elf":
			return Color(0.55, 0.95, 0.70)
		"dwarf":
			return Color(0.95, 0.80, 0.45)
		"undead":
			return Color(0.80, 0.82, 0.92)
		"dragon":
			return Color(1.00, 0.55, 0.35)
		"orc":
			return Color(0.60, 0.82, 0.38)
		"fae":
			return Color(0.88, 0.68, 0.98)
		"warrior":
			return Color(0.85, 0.55, 0.35)
		"knight":
			return Color(0.98, 0.84, 0.48)
		"mage":
			return Color(0.55, 0.70, 1.00)
		"sorcerer":
			return Color(0.58, 0.76, 1.00)
		"ranger":
			return Color(0.75, 0.95, 0.55)
		"guardian":
			return Color(0.95, 0.80, 0.45)
		"assassin":
			return Color(0.95, 0.45, 0.65)
		"vanguard":
			return Color(0.94, 0.76, 0.40)
		"duelist":
			return Color(1.00, 0.52, 0.58)
		_:
			return Color(0.8, 0.8, 0.8)


func _item_tint(item_id: String) -> Color:
	var item: Dictionary = DataManager.get_item(item_id)
	var category: String = item.get("category", "")
	match category:
		"component":
			return Color(0.78, 0.86, 1.0, 0.95)
		"crafted":
			return Color(1.0, 0.83, 0.42, 0.98)
		"legacy":
			return Color(0.80, 0.92, 0.78, 0.95)
		_:
			return Color(0.9, 0.9, 0.9, 0.95)


func _item_tooltip(item_id: String) -> String:
	var item: Dictionary = DataManager.get_item(item_id)
	if item.is_empty():
		return item_id
	return "%s\n%s" % [item.get("name", item_id), item.get("description", "")]


func _on_run_finished(summary: Dictionary) -> void:
	show_run_summary(summary)


func _on_inventory_slot_pressed(index: int) -> void:
	var items: Array[String] = GameManager.get_item_inventory()
	if index >= items.size():
		return
	if _selected_item_index == index:
		_selected_item_index = -1
		_refresh_inventory_selection()
		_refresh_overview()
		return
	if _selected_item_index == -1:
		_selected_item_index = index
		_refresh_inventory_selection()
		_refresh_overview()
		return

	var crafted_item: String = GameManager.craft_inventory_items(_selected_item_index, index)
	_selected_item_index = -1
	if crafted_item != "":
		_result_label.text = "Crafted %s" % DataManager.get_item(crafted_item).get("name", crafted_item)
		_result_label.add_theme_color_override("font_color", Color(1.0, 0.83, 0.42))
		_result_label.visible = true
	else:
		_result_label.text = "No valid recipe"
		_result_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
		_result_label.visible = true
	_refresh_inventory_selection()
	_refresh_overview()


func _on_unit_targeted_for_item(unit) -> void:
	if unit == null:
		return
	if _selected_item_index < 0:
		_show_unit_inspect(unit)
		return
	if GameManager.equip_inventory_item_to_unit(_selected_item_index, unit):
		_selected_item_index = -1
		_result_label.text = "Equipped %s" % unit.unit_name
		_result_label.add_theme_color_override("font_color", Color(0.55, 0.9, 0.55))
		_result_label.visible = true
		_refresh_inventory_selection()
		_refresh_overview()
	else:
		_result_label.text = "Unit already has an item"
		_result_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
		_result_label.visible = true


func _show_unit_inspect(unit) -> void:
	if _inspect_panel == null or _inspect_label == null:
		return
	_inspect_label.text = DataManager.get_unit_tooltip(unit.unit_id)
	_inspect_panel.visible = true


func is_item_targeting_active() -> bool:
	return _selected_item_index >= 0 and _phase == PREP_PHASE


func _refresh_inventory_selection() -> void:
	for i in _inventory_slot_bgs.size():
		var bg: ColorRect = _inventory_slot_bgs[i]
		if i == _selected_item_index:
			bg.color = Color(0.95, 0.78, 0.18, 0.95)
		elif i < GameManager.get_item_inventory_size():
			bg.color = Color(0.10, 0.13, 0.18, 0.95)
		else:
			bg.color = Color(0.10, 0.13, 0.18, 0.45)
