extends Control

class_name BenchUI

const BENCH_SLOTS: int = 9
const SLOT_SIZE: float = 96.0
const PREP_PHASE: int = 0
const COMBAT_PHASE: int = 1
const RESULT_PHASE: int = 2
const SLOT_TEXTURE: Texture2D = preload("res://assets/ui/bench_slot.svg")
const PORTRAIT_TEXTURE: Texture2D = preload("res://assets/portraits/placeholder_unit.svg")
const UNIT_SCRIPT_PATH: String = "res://scripts/units/unit.gd"
const COST_COLORS: Dictionary = {
	1: UITheme.COST_1,
	2: UITheme.COST_2,
	3: UITheme.COST_3,
	4: UITheme.COST_4,
}

var _slots: Array[Control] = []
var _units: Array = []
var _selected_slot: int = -1
var _interaction_enabled: bool = true
var _board_ui = null
var _shop_ui = null
var _touch_hints_enabled: bool = true

var _panel: PanelContainer = null
var _panel_patch: NinePatchRect = null
var _header_row: HBoxContainer = null
var _slots_row: HBoxContainer = null
var _title_label: Label = null
var _count_label: Label = null
var _hint_label: Label = null

signal unit_selected_from_bench(unit)
signal unit_sold(unit)
signal unit_hovered(unit)
signal unit_unhovered()


func _ready() -> void:
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 0.0
	anchor_bottom = 0.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	mouse_filter = Control.MOUSE_FILTER_PASS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	theme = UITheme.build_theme()
	z_as_relative = false
	z_index = 100
	_touch_hints_enabled = bool(UISettings.load_settings().get(UISettings.KEY_TOUCH_HINTS, true))
	for i in BENCH_SLOTS:
		_units.append(null)
	_build_ui()
	_bind_scene_peers()
	_refresh_overview()
	if not resized.is_connected(_refresh_layout):
		resized.connect(_refresh_layout)
	_refresh_layout()
	call_deferred("move_to_front")


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	add_child(_panel)

	_panel_patch = UITheme.make_nine_patch()
	_panel.add_child(_panel_patch)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 8)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	_header_row = HBoxContainer.new()
	_header_row.add_theme_constant_override("separation", 8)
	vbox.add_child(_header_row)

	_title_label = Label.new()
	_title_label.text = "BENCH"
	_title_label.add_theme_font_size_override("font_size", 10)
	_title_label.add_theme_color_override("font_color", UITheme.TEXT_SECOND)
	_header_row.add_child(_title_label)

	_count_label = Label.new()
	_count_label.add_theme_font_size_override("font_size", 10)
	_count_label.add_theme_color_override("font_color", UITheme.GOLD)
	_header_row.add_child(_count_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_row.add_child(spacer)

	_hint_label = Label.new()
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint_label.add_theme_font_size_override("font_size", 9)
	_hint_label.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	_header_row.add_child(_hint_label)

	_slots_row = HBoxContainer.new()
	_slots_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slots_row.add_theme_constant_override("separation", 6)
	vbox.add_child(_slots_row)

	for i in BENCH_SLOTS:
		var slot := _make_slot(i)
		_slots_row.add_child(slot)
		_slots.append(slot)


func _make_slot(index: int) -> Control:
	var slot := Control.new()
	slot.name = "Slot_%d" % index
	slot.mouse_filter = Control.MOUSE_FILTER_PASS
	slot.custom_minimum_size = Vector2(32, 32)
	slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var bg := TextureRect.new()
	bg.name = "BG"
	bg.texture = SLOT_TEXTURE
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.modulate = Color(UITheme.BORDER_MID.r, UITheme.BORDER_MID.g, UITheme.BORDER_MID.b, 0.30)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(bg)

	var portrait := TextureRect.new()
	portrait.name = "Portrait"
	portrait.texture = PORTRAIT_TEXTURE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.modulate = Color(1, 1, 1, 0.0)
	slot.add_child(portrait)

	var border := ColorRect.new()
	border.name = "Border"
	border.color = Color(0, 0, 0, 0)
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(border)

	var star_lbl := Label.new()
	star_lbl.name = "StarLabel"
	star_lbl.position = Vector2(2, 1)
	star_lbl.add_theme_font_size_override("font_size", 11)
	star_lbl.add_theme_color_override("font_color", UITheme.GOLD_BRIGHT)
	star_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(star_lbl)

	var btn := Button.new()
	btn.name = "TapArea"
	btn.flat = true
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.pressed.connect(_on_slot_tapped.bind(index))
	btn.mouse_entered.connect(_on_slot_hovered.bind(index))
	btn.mouse_exited.connect(_on_slot_unhovered)
	slot.add_child(btn)

	return slot


func _refresh_layout() -> void:
	var view_size: Vector2 = get_viewport_rect().size
	var width: float = minf(maxf(760.0, view_size.x - UITheme.SCREEN_GUTTER * 2.0), UITheme.CONTENT_MAX_WIDTH)
	var bench_h: float = UITheme.BENCH_PANEL_HEIGHT
	var shop_y: float = view_size.y - UITheme.SHOP_PANEL_HEIGHT - UITheme.SCREEN_GUTTER
	var bench_y: float = shop_y - bench_h - UITheme.UI_STACK_GAP
	position = Vector2(round((view_size.x - width) * 0.5), bench_y)
	size = Vector2(width, bench_h)

	var compact: bool = width < 1360.0
	var large: bool = width >= 1600.0
	var available_w: float = width - 32.0
	var slot_size: float = clampf((available_w - float(BENCH_SLOTS - 1) * 6.0) / float(BENCH_SLOTS), 22.0, 44.0 if large else 36.0)
	if compact:
		slot_size = minf(slot_size, 30.0)
	_slots_row.add_theme_constant_override("separation", clampi(int(round(slot_size * 0.18)), 4, 8))

	for slot in _slots:
		slot.custom_minimum_size = Vector2(slot_size, slot_size)
		var portrait: TextureRect = slot.get_node("Portrait") as TextureRect
		if portrait != null:
			var inset: float = clampf(slot_size * 0.10, 2.0, 4.0)
			portrait.offset_left = inset
			portrait.offset_top = inset
			portrait.offset_right = -inset
			portrait.offset_bottom = -inset


func add_unit(unit) -> bool:
	var slot: int = _find_free_slot()
	if slot != -1:
		if unit.get_parent() == null and _board_ui != null:
			_board_ui.add_child(unit)
		_units[slot] = unit
		unit.is_on_bench = true
		unit.is_enemy_unit = false
		unit.board_position = Vector2i(-1, -1)
		unit.visible = false
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
	return _find_free_slot() != -1 or _can_merge_unit(unit.unit_id)


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
	if _selected_slot >= 0 and _selected_slot < _slots.size():
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
	return BENCH_SLOTS - get_unit_count()


func get_all_units() -> Array:
	var result: Array = []
	for u in _units:
		if u != null:
			result.append(u)
	return result


func _on_slot_tapped(index: int) -> void:
	if not _interaction_enabled:
		return
	var unit = _units[index]
	if unit == null:
		deselect()
		return
	if _selected_slot == index:
		_sell_unit(index)
		return
	deselect()
	_selected_slot = index
	_set_slot_selected(index, true)
	unit_selected_from_bench.emit(unit)


func _on_slot_hovered(index: int) -> void:
	if index < 0 or index >= _units.size():
		return
	var unit = _units[index]
	if unit != null:
		unit_hovered.emit(unit)


func _on_slot_unhovered() -> void:
	unit_unhovered.emit()


func on_unit_placed_on_board(unit) -> void:
	var idx: int = _units.find(unit)
	if idx != -1:
		_units[idx] = null
		_refresh_slot(idx)
	unit.visible = true
	_check_merge(unit)
	_selected_slot = -1
	_refresh_overview()


func receive_unit_from_board(unit) -> void:
	add_unit(unit)


func _check_merge(new_unit) -> void:
	if new_unit == null:
		return
	_try_merge_chain_for_unit(new_unit)


func _apply_direct_merge(unit_id: String) -> void:
	var candidates: Array = _get_merge_candidates(unit_id, 1)
	if candidates.size() >= 3:
		_merge_candidates(candidates.slice(0, 3))


func _show_upgrade_flash(slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= _slots.size():
		return
	var border: ColorRect = _slots[slot_idx].get_node("Border") as ColorRect
	if border == null:
		return
	border.color = Color(UITheme.GOLD_BRIGHT.r, UITheme.GOLD_BRIGHT.g, UITheme.GOLD_BRIGHT.b, 0.35)
	var tween := create_tween()
	tween.tween_property(border, "color", Color(0, 0, 0, 0), 0.22)


func _sell_unit(slot_idx: int) -> void:
	var unit = _units[slot_idx]
	if unit == null:
		return
	var sell_value: int = unit.cost * int(pow(3.0, float(unit.star_level - 1)))
	GameManager.add_gold(sell_value)
	unit_sold.emit(unit)
	_units[slot_idx] = null
	if is_instance_valid(unit):
		unit.queue_free()
	_refresh_slot(slot_idx)
	_selected_slot = -1
	_refresh_overview()


func _refresh_slot(index: int) -> void:
	var slot: Control = _slots[index]
	var unit = _units[index]
	var bg: TextureRect = slot.get_node("BG") as TextureRect
	var portrait: TextureRect = slot.get_node("Portrait") as TextureRect
	var star_lbl: Label = slot.get_node("StarLabel") as Label
	var border: ColorRect = slot.get_node("Border") as ColorRect

	if unit == null:
		bg.modulate = Color(UITheme.BORDER_MID.r, UITheme.BORDER_MID.g, UITheme.BORDER_MID.b, 0.30)
		portrait.texture = PORTRAIT_TEXTURE
		portrait.modulate = Color(1, 1, 1, 0.0)
		star_lbl.text = ""
		border.color = Color(0, 0, 0, 0)
		slot.tooltip_text = ""
		return

	var cost: int = unit.cost
	var tier_color: Color = COST_COLORS.get(cost, UITheme.BORDER_MID)
	bg.modulate = tier_color.darkened(0.22)
	portrait.texture = DataManager.get_unit_portrait(unit.unit_id)
	portrait.modulate = Color.WHITE
	star_lbl.text = "★".repeat(unit.star_level - 1) if unit.star_level > 1 else ""
	border.color = Color(0, 0, 0, 0)
	slot.tooltip_text = DataManager.get_unit_tooltip(unit.unit_id)


func _set_slot_selected(index: int, selected: bool) -> void:
	if index < 0 or index >= _slots.size():
		return
	var border: ColorRect = _slots[index].get_node("Border") as ColorRect
	if border == null:
		return
	border.color = Color(UITheme.GOLD_BRIGHT.r, UITheme.GOLD_BRIGHT.g, UITheme.GOLD_BRIGHT.b, 0.35) if selected else Color(0, 0, 0, 0)


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
	return _get_merge_candidates(unit_id, 1).size() >= 3 or _get_merge_candidates(unit_id, 2).size() >= 3


func _try_merge_chain_for_unit(unit) -> void:
	var candidates: Array = _get_merge_candidates(unit.unit_id, unit.star_level)
	if candidates.size() >= 3:
		var keeper = _merge_candidates(candidates.slice(0, 3))
		if keeper != null and keeper.star_level < 3:
			_try_merge_chain_for_unit(keeper)


func _merge_candidates(candidates: Array):
	if candidates.size() < 3:
		return null
	var keeper = candidates[0]
	keeper.upgrade_to_star(keeper.star_level + 1)
	for i in range(1, candidates.size()):
		var merged_unit = candidates[i]
		if merged_unit == null:
			continue
		var slot_idx: int = _units.find(merged_unit)
		if slot_idx != -1:
			_units[slot_idx] = null
			_refresh_slot(slot_idx)
		if is_instance_valid(merged_unit):
			merged_unit.queue_free()
	var keeper_slot: int = _units.find(keeper)
	if keeper_slot != -1:
		_refresh_slot(keeper_slot)
		_show_upgrade_flash(keeper_slot)
	_refresh_overview()
	return keeper


func _get_merge_candidates(unit_id: String, star_level: int) -> Array:
	var board_candidates: Array = []
	if _board_ui != null:
		for unit in _board_ui.get_all_placed_units():
			if unit != null and unit.unit_id == unit_id and unit.star_level == star_level:
				board_candidates.append(unit)

	var bench_candidates: Array = []
	for unit in _units:
		if unit != null and unit.unit_id == unit_id and unit.star_level == star_level:
			bench_candidates.append(unit)

	var ordered: Array = []
	if not board_candidates.is_empty():
		ordered.append(board_candidates[0])
	for unit in bench_candidates:
		if not ordered.has(unit):
			ordered.append(unit)
	for unit in board_candidates:
		if not ordered.has(unit):
			ordered.append(unit)
	return ordered


func _bind_scene_peers() -> void:
	var root := get_parent()
	if root == null:
		return
	_board_ui = root.get_node_or_null("BoardUI")
	_shop_ui = root.get_node_or_null("ShopUI")
	if root.has_signal("phase_changed") and not root.phase_changed.is_connected(_on_phase_changed):
		root.phase_changed.connect(_on_phase_changed)
	if _board_ui != null:
		if not _board_ui.unit_placed.is_connected(_on_board_unit_placed):
			_board_ui.unit_placed.connect(_on_board_unit_placed)
		if not _board_ui.unit_sent_to_bench.is_connected(receive_unit_from_board):
			_board_ui.unit_sent_to_bench.connect(receive_unit_from_board)
	_on_phase_changed(PREP_PHASE)


func _on_board_unit_placed(unit, _col: int, _row: int) -> void:
	on_unit_placed_on_board(unit)


func _on_phase_changed(phase: int) -> void:
	_interaction_enabled = phase == PREP_PHASE
	if not _interaction_enabled:
		deselect()
	_refresh_overview()


func refresh_overview() -> void:
	_refresh_overview()


func _refresh_overview() -> void:
	if _count_label != null:
		_count_label.text = "%d/%d" % [get_unit_count(), BENCH_SLOTS]
	if _hint_label != null:
		_hint_label.text = "Tap a bench unit, then place it." if _interaction_enabled else ""
	for i in _slots.size():
		_refresh_slot(i)
