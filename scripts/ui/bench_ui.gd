extends Control

class_name BenchUI

const BENCH_SLOTS: int = 9
const SLOT_SIZE: float = 80.0
const SLOT_GAP: float = 8.0
const BENCH_Y: float = 0.0

var _slots: Array[Control] = []
var _units: Array = []         # Unit or null per slot
var _selected_slot: int = -1   # -1 = nothing selected

signal unit_selected_from_bench(unit: Unit)
signal unit_sold(unit: Unit)


func _ready() -> void:
	custom_minimum_size = Vector2(1280, SLOT_SIZE + 16)
	_build_background()
	_build_slots()


func _build_background() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.10, 0.13, 0.90)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var top_line := ColorRect.new()
	top_line.color = Color(0.3, 0.35, 0.45)
	top_line.custom_minimum_size = Vector2(1280, 2)
	add_child(top_line)


func _build_slots() -> void:
	var total_w: float = BENCH_SLOTS * SLOT_SIZE + (BENCH_SLOTS - 1) * SLOT_GAP
	var start_x: float = (1280.0 - total_w) / 2.0

	for i in BENCH_SLOTS:
		_units.append(null)
		var slot := _make_slot(i)
		slot.position = Vector2(start_x + i * (SLOT_SIZE + SLOT_GAP), 8)
		add_child(slot)
		_slots.append(slot)


func _make_slot(index: int) -> Control:
	var container := Control.new()
	container.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	container.name = "Slot_%d" % index

	var bg := ColorRect.new()
	bg.name = "BG"
	bg.color = Color(0.13, 0.16, 0.20)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.add_child(bg)

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


# ── Public API ─────────────────────────────────────────────────────────────

func add_unit(unit: Unit) -> bool:
	var slot: int = _find_free_slot()
	if slot == -1:
		return false
	_units[slot] = unit
	_refresh_slot(slot)
	# Auto-merge: check for star upgrade
	_check_merge(unit)
	return true


func remove_unit_at(slot: int) -> Unit:
	var unit: Unit = _units[slot]
	if unit == null:
		return null
	_units[slot] = null
	_refresh_slot(slot)
	if _selected_slot == slot:
		_selected_slot = -1
	return unit


func deselect() -> void:
	if _selected_slot != -1:
		_set_slot_selected(_selected_slot, false)
		_selected_slot = -1


func is_full() -> bool:
	return _find_free_slot() == -1


func get_all_units() -> Array:
	var result: Array = []
	for u in _units:
		if u != null:
			result.append(u)
	return result


# ── Slot interaction ────────────────────────────────────────────────────────

func _on_slot_tapped(index: int) -> void:
	var unit: Unit = _units[index]

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
func on_unit_placed_on_board(unit: Unit) -> void:
	var idx: int = _units.find(unit)
	if idx != -1:
		_units[idx] = null
		_refresh_slot(idx)
	_selected_slot = -1


# Called by board_ui when a unit is sent back to bench
func receive_unit_from_board(unit: Unit) -> void:
	add_unit(unit)


# ── Merge (star upgrade) ───────────────────────────────────────────────────

func _check_merge(new_unit: Unit) -> void:
	# Count how many of the same unit_id we have (star_level 1 only)
	if new_unit.star_level != 1:
		return

	var matches: Array = []
	for i in BENCH_SLOTS:
		var u: Unit = _units[i]
		if u != null and u.unit_id == new_unit.unit_id and u.star_level == 1:
			matches.append(i)

	if matches.size() < 3:
		return

	# Upgrade: keep first slot, remove other two
	var keep_idx: int = matches[0]
	var base_unit: Unit = _units[keep_idx]
	base_unit.upgrade_to_star(2)

	for i in range(1, 3):
		var remove_idx: int = matches[i]
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
	var unit: Unit = _units[slot_idx]
	if unit == null:
		return
	var sell_value: int = unit.cost * unit.star_level
	GameManager.add_gold(sell_value)
	unit_sold.emit(unit)
	_units[slot_idx] = null
	_refresh_slot(slot_idx)
	_selected_slot = -1


# ── Visual refresh ─────────────────────────────────────────────────────────

func _refresh_slot(index: int) -> void:
	var slot: Control = _slots[index]
	var unit: Unit = _units[index]
	var bg: ColorRect = slot.get_node("BG") as ColorRect
	var name_lbl: Label = slot.get_node("NameLabel") as Label
	var star_lbl: Label = slot.get_node("StarLabel") as Label
	var sell_lbl: Label = slot.get_node("SellLabel") as Label

	if unit == null:
		bg.color = Color(0.13, 0.16, 0.20)
		name_lbl.text = ""
		star_lbl.text = ""
		sell_lbl.text = ""
		return

	var cost: int = unit.cost
	var tier_color: Color = UnitCard.COST_COLORS.get(cost, Color.GRAY)
	bg.color = tier_color.darkened(0.5)
	name_lbl.text = unit.unit_name
	star_lbl.text = "★" if unit.star_level == 2 else ""
	sell_lbl.text = "%dg" % (cost * unit.star_level)


func _set_slot_selected(index: int, selected: bool) -> void:
	var slot: Control = _slots[index]
	var bg: ColorRect = slot.get_node("BG") as ColorRect
	if bg == null:
		return
	if selected:
		bg.color = bg.color.lightened(0.3)
	else:
		_refresh_slot(index)


func _find_free_slot() -> int:
	for i in BENCH_SLOTS:
		if _units[i] == null:
			return i
	return -1
