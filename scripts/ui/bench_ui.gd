extends Control

class_name BenchUI

const BENCH_SLOTS: int = 9
const SLOT_SIZE: float = 80.0
const SLOT_GAP: float = 8.0
const PREP_PHASE: int = 0
const COMBAT_PHASE: int = 1
const RESULT_PHASE: int = 2
const SLOT_TEXTURE: Texture2D = preload("res://assets/ui/board_tile.svg")
const PORTRAIT_TEXTURE: Texture2D = preload("res://assets/portraits/placeholder_unit.svg")
const UNIT_SCRIPT_PATH: String = "res://scripts/units/unit.gd"
const COST_COLORS: Dictionary = {
	1: Color(0.65, 0.65, 0.65),
	2: Color(0.15, 0.70, 0.30),
	3: Color(0.20, 0.45, 0.90),
	4: Color(0.60, 0.20, 0.90)
}

var _slots: Array[Control] = []
var _units: Array = []         # Unit or null per slot
var _selected_slot: int = -1   # -1 = nothing selected
var _interaction_enabled: bool = true
var _board_ui = null
var _phase_label: Label = null
var _count_label: Label = null
var _hint_label: Label = null
var _touch_hints_enabled: bool = true
var _background_line: ColorRect = null
var _title_label: Label = null

signal unit_selected_from_bench(unit)
signal unit_sold(unit)


func _ready() -> void:
	anchor_left = 0.0
	anchor_top = 1.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = -(SLOT_SIZE + 34.0)
	offset_right = 0.0
	offset_bottom = -200.0
	custom_minimum_size = Vector2(0.0, SLOT_SIZE + 34.0)
	_touch_hints_enabled = bool(UISettings.load_settings().get(UISettings.KEY_TOUCH_HINTS, true))
	_build_background()
	_build_header()
	_build_slots()
	_bind_scene_peers()
	_refresh_overview()
	if not resized.is_connected(_refresh_layout):
		resized.connect(_refresh_layout)
	_refresh_layout()


func _build_background() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.10, 0.13, 0.90)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_background_line = ColorRect.new()
	_background_line.color = Color(0.3, 0.35, 0.45)
	add_child(_background_line)


func _build_header() -> void:
	_title_label = Label.new()
	_title_label.text = "BENCH"
	_title_label.position = Vector2(18, 6)
	_title_label.add_theme_font_size_override("font_size", 13)
	_title_label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	add_child(_title_label)

	_count_label = Label.new()
	_count_label.position = Vector2(96, 6)
	_count_label.add_theme_font_size_override("font_size", 13)
	_count_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.35))
	add_child(_count_label)

	_phase_label = Label.new()
	_phase_label.position = Vector2(240, 6)
	_phase_label.add_theme_font_size_override("font_size", 12)
	_phase_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	add_child(_phase_label)

	_hint_label = Label.new()
	_hint_label.position = Vector2(420, 6)
	_hint_label.add_theme_font_size_override("font_size", 12)
	_hint_label.add_theme_color_override("font_color", Color(0.65, 0.7, 0.76))
	add_child(_hint_label)


func _build_slots() -> void:
	for i in BENCH_SLOTS:
		_units.append(null)
		var slot := _make_slot(i)
		add_child(slot)
		_slots.append(slot)


func _make_slot(index: int) -> Control:
	var container := Control.new()
	container.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	container.name = "Slot_%d" % index

	var bg := TextureRect.new()
	bg.name = "BG"
	bg.texture = SLOT_TEXTURE
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.modulate = Color(0.66, 0.74, 0.86, 0.92)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.add_child(bg)

	var portrait := TextureRect.new()
	portrait.name = "Portrait"
	portrait.texture = PORTRAIT_TEXTURE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.position = Vector2(14, 10)
	portrait.custom_minimum_size = Vector2(SLOT_SIZE - 28, SLOT_SIZE - 28)
	portrait.modulate = Color(1, 1, 1, 0.0)
	container.add_child(portrait)

	var border := ColorRect.new()
	border.name = "Border"
	border.color = Color(0, 0, 0, 0)
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.add_child(border)

	var name_lbl := Label.new()
	name_lbl.name = "NameLabel"
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	name_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.add_child(name_lbl)

	var star_lbl := Label.new()
	star_lbl.name = "StarLabel"
	star_lbl.position = Vector2(2, 2)
	star_lbl.add_theme_font_size_override("font_size", 12)
	star_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	container.add_child(star_lbl)

	var sell_lbl := Label.new()
	sell_lbl.name = "SellLabel"
	sell_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sell_lbl.add_theme_font_size_override("font_size", 10)
	sell_lbl.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	sell_lbl.position = Vector2(0, SLOT_SIZE - 16)
	sell_lbl.custom_minimum_size = Vector2(SLOT_SIZE, 14)
	container.add_child(sell_lbl)

	var btn := Button.new()
	btn.name = "TapArea"
	btn.flat = true
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.pressed.connect(_on_slot_tapped.bind(index))
	container.add_child(btn)

	return container


func _refresh_layout() -> void:
	var width: float = maxf(640.0, get_viewport_rect().size.x)
	var compact: bool = width < 980.0
	var slot_scale: float = clampf((width - 44.0) / (BENCH_SLOTS * SLOT_SIZE + (BENCH_SLOTS - 1) * SLOT_GAP), 0.62, 1.0)
	if compact:
		slot_scale = minf(slot_scale, 0.78)
	var slot_size: float = SLOT_SIZE * slot_scale
	var gap: float = maxf(4.0, SLOT_GAP * slot_scale)
	var header_h: float = 24.0
	var bench_h: float = slot_size + header_h + 14.0
	offset_top = -bench_h
	offset_bottom = -200.0

	if _background_line != null:
		_background_line.size = Vector2(width, 2.0)
	if _title_label != null:
		_title_label.position = Vector2(16.0, 6.0)
	if _count_label != null:
		_count_label.position = Vector2(92.0, 6.0)
	if _phase_label != null:
		_phase_label.position = Vector2(190.0, 6.0)
	if _hint_label != null:
		_hint_label.position = Vector2(width * 0.42, 6.0)
		_hint_label.visible = _touch_hints_enabled and not compact

	var total_w: float = BENCH_SLOTS * slot_size + (BENCH_SLOTS - 1) * gap
	var start_x: float = (width - total_w) * 0.5
	var slots_y: float = header_h + 8.0
	for i in _slots.size():
		var slot: Control = _slots[i]
		slot.position = Vector2(start_x + i * (slot_size + gap), slots_y)
		slot.custom_minimum_size = Vector2(slot_size, slot_size)
		slot.size = Vector2(slot_size, slot_size)
		var portrait: TextureRect = slot.get_node("Portrait") as TextureRect
		if portrait != null:
			var portrait_size: float = maxf(24.0, slot_size - 28.0)
			portrait.position = Vector2((slot_size - portrait_size) * 0.5, (slot_size - portrait_size) * 0.5 - 2.0)
			portrait.custom_minimum_size = Vector2(portrait_size, portrait_size)
		var sell_lbl: Label = slot.get_node("SellLabel") as Label
		if sell_lbl != null:
			sell_lbl.position = Vector2(0.0, slot_size - 16.0)
			sell_lbl.custom_minimum_size = Vector2(slot_size, 14.0)


# ── Public API ─────────────────────────────────────────────────────────────

func add_unit(unit) -> bool:
	var slot: int = _find_free_slot()
	if slot != -1:
		_units[slot] = unit
		unit.is_on_bench = true
		unit.board_position = Vector2i(-1, -1)
		_refresh_slot(slot)
		_check_merge(unit)
		_refresh_overview()
		return true

	if unit.star_level == 1 and _can_merge_unit(unit.unit_id):
		_apply_direct_merge(unit.unit_id)
		_refresh_overview()
		return true

	return false


func add_unit_from_shop(unit_id: String) -> bool:
	var data: Dictionary = DataManager.get_unit(unit_id)
	if data.is_empty():
		return false
	var unit_script: Script = load(UNIT_SCRIPT_PATH)
	if unit_script == null:
		return false
	var unit = unit_script.new()
	unit.init(data)
	return add_unit(unit)


func can_accept_purchase(unit_id: String) -> bool:
	if _find_free_slot() != -1:
		return true
	return _can_merge_unit(unit_id)


func can_accept_unit(unit) -> bool:
	if unit == null:
		return false
	if _find_free_slot() != -1:
		return true
	return unit.star_level == 1 and _can_merge_unit(unit.unit_id)


func remove_unit_at(slot: int):
	var unit = _units[slot]
	if unit == null:
		return null
	_units[slot] = null
	_refresh_slot(slot)
	if _selected_slot == slot:
		_selected_slot = -1
	_refresh_overview()
	return unit


func deselect() -> void:
	if _selected_slot != -1:
		_set_slot_selected(_selected_slot, false)
		_selected_slot = -1


func is_full() -> bool:
	return _find_free_slot() == -1


func get_unit_count() -> int:
	var count: int = 0
	for unit in _units:
		if unit != null:
			count += 1
	return count


func get_capacity() -> int:
	return BENCH_SLOTS


func get_free_slots() -> int:
	return max(0, BENCH_SLOTS - get_unit_count())


func get_all_units() -> Array:
	var result: Array = []
	for u in _units:
		if u != null:
			result.append(u)
	return result


# ── Slot interaction ────────────────────────────────────────────────────────

func _on_slot_tapped(index: int) -> void:
	if not _interaction_enabled:
		return

	var unit = _units[index]

	if _selected_slot == index:
		# Tap same slot → sell
		_sell_unit(index)
		return

	if _selected_slot != -1:
		# Another slot was selected → deselect it
		_set_slot_selected(_selected_slot, false)
		_selected_slot = -1

	if unit == null:
		return

	# Select this unit
	_selected_slot = index
	_set_slot_selected(index, true)
	unit_selected_from_bench.emit(unit)


# Called by board_ui when unit was successfully placed on board
func on_unit_placed_on_board(unit) -> void:
	var idx: int = _units.find(unit)
	if idx != -1:
		_units[idx] = null
		_refresh_slot(idx)
	_selected_slot = -1
	_refresh_overview()


# Called by board_ui when a unit is sent back to bench
func receive_unit_from_board(unit) -> void:
	add_unit(unit)


# ── Merge (star upgrade) ───────────────────────────────────────────────────

func _check_merge(new_unit) -> void:
	# Count how many of the same unit_id we have (star_level 1 only)
	if new_unit.star_level != 1:
		return

	var matches: Array = []
	for i in BENCH_SLOTS:
		var u = _units[i]
		if u != null and u.unit_id == new_unit.unit_id and u.star_level == 1:
			matches.append(i)

	if matches.size() < 3:
		return

	# Upgrade: keep first slot, remove other two
	var keep_idx: int = matches[0]
	var base_unit = _units[keep_idx]
	base_unit.upgrade_to_star(2)

	for i in range(1, 3):
		var remove_idx: int = matches[i]
		_units[remove_idx] = null
		_refresh_slot(remove_idx)

	_refresh_slot(keep_idx)
	_show_upgrade_flash(keep_idx)


func _apply_direct_merge(unit_id: String) -> void:
	var matches: Array[int] = _find_matching_slots(unit_id)
	if matches.size() < 2:
		return

	var keep_idx: int = matches[0]
	var remove_idx: int = matches[1]
	var base_unit = _units[keep_idx]
	var removed_unit = _units[remove_idx]
	if base_unit == null or removed_unit == null:
		return

	base_unit.upgrade_to_star(mini(base_unit.star_level + 1, 2))
	_units[remove_idx] = null
	_refresh_slot(remove_idx)
	_refresh_slot(keep_idx)
	_show_upgrade_flash(keep_idx)


func _show_upgrade_flash(slot_idx: int) -> void:
	# Quick gold border flash to signal upgrade (tween)
	var slot: Control = _slots[slot_idx]
	var border: ColorRect = slot.get_node("Border") as ColorRect
	if border == null:
		return
	border.color = Color(1.0, 0.85, 0.1, 0.8)
	var tween := create_tween()
	tween.tween_property(border, "color", Color(0, 0, 0, 0), 0.6)


# ── Sell ─────────────────────────────────────────────────────────────────────

func _sell_unit(slot_idx: int) -> void:
	var unit = _units[slot_idx]
	if unit == null:
		return
	var sell_value: int = unit.cost * unit.star_level
	GameManager.add_gold(sell_value)
	unit_sold.emit(unit)
	_units[slot_idx] = null
	_refresh_slot(slot_idx)
	_selected_slot = -1
	_refresh_overview()


# ── Visual refresh ─────────────────────────────────────────────────────────

func _refresh_slot(index: int) -> void:
	var slot: Control = _slots[index]
	var unit = _units[index]
	var bg: TextureRect = slot.get_node("BG") as TextureRect
	var portrait: TextureRect = slot.get_node("Portrait") as TextureRect
	var name_lbl: Label = slot.get_node("NameLabel") as Label
	var star_lbl: Label = slot.get_node("StarLabel") as Label
	var sell_lbl: Label = slot.get_node("SellLabel") as Label

	if unit == null:
		bg.modulate = Color(0.66, 0.74, 0.86, 0.42)
		portrait.modulate = Color(1, 1, 1, 0.0)
		name_lbl.text = ""
		star_lbl.text = ""
		sell_lbl.text = ""
		return

	var cost: int = unit.cost
	var tier_color: Color = COST_COLORS.get(cost, Color.GRAY)
	bg.modulate = tier_color.lightened(0.2)
	portrait.modulate = tier_color.lightened(0.05)
	name_lbl.text = unit.unit_name
	star_lbl.text = "★" if unit.star_level == 2 else ""
	sell_lbl.text = "%dg" % (cost * unit.star_level)


func _set_slot_selected(index: int, selected: bool) -> void:
	var slot: Control = _slots[index]
	var bg: TextureRect = slot.get_node("BG") as TextureRect
	if bg == null:
		return
	if selected:
		bg.modulate = bg.modulate.lerp(Color(1.0, 0.9, 0.55, 1.0), 0.35)
	else:
		_refresh_slot(index)


func _find_free_slot() -> int:
	for i in BENCH_SLOTS:
		if _units[i] == null:
			return i
	return -1


func _find_matching_slots(unit_id: String) -> Array[int]:
	var matches: Array[int] = []
	for i in BENCH_SLOTS:
		var unit = _units[i]
		if unit != null and unit.unit_id == unit_id and unit.star_level == 1:
			matches.append(i)
	return matches


func _can_merge_unit(unit_id: String) -> bool:
	return _find_matching_slots(unit_id).size() >= 2


func _bind_scene_peers() -> void:
	var root: Node = get_parent()
	if root == null:
		root = get_tree().current_scene
	if root == null:
		return

	_board_ui = root.get_node_or_null("BoardUI")

	if root.has_signal("phase_changed") and not root.phase_changed.is_connected(_on_phase_changed):
		root.phase_changed.connect(_on_phase_changed)

	if _board_ui != null:
		if not unit_selected_from_bench.is_connected(_board_ui.select_unit_from_bench):
			unit_selected_from_bench.connect(_board_ui.select_unit_from_bench)
		if not _board_ui.unit_placed.is_connected(_on_board_unit_placed):
			_board_ui.unit_placed.connect(_on_board_unit_placed)
		if not _board_ui.unit_sent_to_bench.is_connected(receive_unit_from_board):
			_board_ui.unit_sent_to_bench.connect(receive_unit_from_board)

	_on_phase_changed(PREP_PHASE)


func _on_board_unit_placed(unit, _col: int, _row: int) -> void:
	on_unit_placed_on_board(unit)


func _on_phase_changed(phase: int) -> void:
	_interaction_enabled = phase == PREP_PHASE
	for slot in _slots:
		var btn: Button = slot.get_node_or_null("TapArea") as Button
		if btn != null:
			btn.disabled = not _interaction_enabled
	if not _interaction_enabled:
		deselect()
	_refresh_overview()


func _refresh_overview() -> void:
	if _count_label != null:
		_count_label.text = "%d/%d" % [get_unit_count(), BENCH_SLOTS]
	if _phase_label != null:
		_phase_label.text = "Tap a bench unit, then tap the board. Tap again to sell."
		if not _interaction_enabled:
			_phase_label.text = "Bench locked during combat."
	if _hint_label != null:
		_hint_label.visible = _touch_hints_enabled and size.x >= 980.0
		_hint_label.text = "Sell: tap selected unit again. Move back: tap empty space."
