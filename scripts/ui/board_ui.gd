extends Node2D

class_name BoardUI

const COLS: int = 7
const ROWS: int = 4
const CELL_SIZE: float = 96.0
const BOARD_OFFSET: Vector2 = Vector2(304.0, 55.0)  # centered in 1280x720, below HUD (50px)
const PREP_PHASE: int = 0
const COMBAT_PHASE: int = 1
const TILE_TEXTURE: Texture2D = preload("res://assets/ui/board_tile.svg")

enum InputState { IDLE, UNIT_SELECTED }

var input_state: InputState = InputState.IDLE
var selected_unit = null
var selected_from_cell: Vector2i = Vector2i(-1, -1)
var selected_from_bench: bool = false
var team_capacity: int = 5
var _interaction_enabled: bool = true
var _bench_ui = null
var _hud_ui = null
var _shop_ui = null
var _board_offset: Vector2 = BOARD_OFFSET
var _cell_size: float = CELL_SIZE
var _label_font_size: int = 13

# Grid: [col][row] -> Unit or null
var grid: Array = []

signal unit_placed(unit, col: int, row: int)
signal unit_moved(unit, from: Vector2i, to: Vector2i)
signal unit_sent_to_bench(unit)
signal unit_tapped(unit)

@onready var highlight_layer: Node2D = $HighlightLayer
@onready var cell_highlights: Array = []


func _ready() -> void:
	_initialize_grid()
	_bind_scene_peers()
	if not get_viewport().size_changed.is_connected(_refresh_layout):
		get_viewport().size_changed.connect(_refresh_layout)
	_refresh_layout()
	_draw_board()


func _initialize_grid() -> void:
	grid.resize(COLS)
	for col in COLS:
		grid[col] = []
		grid[col].resize(ROWS)
		for row in ROWS:
			grid[col][row] = null


# Called by bench UI when a unit is tapped on the bench
func select_unit_from_bench(unit) -> void:
	_set_selected(unit, Vector2i(-1, -1), true)


func _unhandled_input(event: InputEvent) -> void:
	if not _interaction_enabled:
		return

	var tap_pos: Vector2 = Vector2.ZERO
	var is_tap: bool = false

	if event is InputEventScreenTouch and event.pressed:
		tap_pos = event.position
		is_tap = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tap_pos = event.position
		is_tap = true

	if not is_tap:
		return

	var cell: Vector2i = _world_to_cell(tap_pos)
	var on_board: bool = _is_valid_cell(cell.x, cell.y)

	match input_state:
		InputState.IDLE:
			if on_board and grid[cell.x][cell.y] != null:
				if _hud_ui != null and _hud_ui.is_item_targeting_active():
					unit_tapped.emit(grid[cell.x][cell.y])
					return
				unit_tapped.emit(grid[cell.x][cell.y])
				_set_selected(grid[cell.x][cell.y], cell, false)

		InputState.UNIT_SELECTED:
			if on_board:
				if cell == selected_from_cell and not selected_from_bench:
					# Tap same cell again → deselect
					_clear_selection()
				elif grid[cell.x][cell.y] != null:
					# Swap with existing unit if the bench can accept the displaced unit.
					if _can_send_unit_to_bench(grid[cell.x][cell.y]):
						_swap_units(cell)
				else:
					# Place on empty cell
					_place_selected_unit(cell)
			else:
				# Tapped outside board → send back to bench
				if not selected_from_bench and _can_send_unit_to_bench(selected_unit):
					_remove_from_board(selected_from_cell)
					unit_sent_to_bench.emit(selected_unit)
				_clear_selection()


func _set_selected(unit, from_cell: Vector2i, from_bench: bool) -> void:
	selected_unit = unit
	selected_from_cell = from_cell
	selected_from_bench = from_bench
	input_state = InputState.UNIT_SELECTED
	_highlight_valid_cells()


func _place_selected_unit(to_cell: Vector2i) -> void:
	if selected_from_bench and get_unit_count() >= team_capacity:
		return

	if not selected_from_bench:
		grid[selected_from_cell.x][selected_from_cell.y] = null

	grid[to_cell.x][to_cell.y] = selected_unit
	selected_unit.board_position = to_cell
	selected_unit.is_on_bench = false
	selected_unit.position = _cell_to_world(to_cell.x, to_cell.y)

	if selected_from_bench:
		unit_placed.emit(selected_unit, to_cell.x, to_cell.y)
	else:
		unit_moved.emit(selected_unit, selected_from_cell, to_cell)

	_clear_selection()


func _swap_units(to_cell: Vector2i) -> void:
	var other_unit = grid[to_cell.x][to_cell.y]

	grid[to_cell.x][to_cell.y] = selected_unit
	selected_unit.board_position = to_cell
	selected_unit.position = _cell_to_world(to_cell.x, to_cell.y)

	if selected_from_bench:
		other_unit.is_on_bench = true
		other_unit.board_position = Vector2i(-1, -1)
		unit_sent_to_bench.emit(other_unit)
		unit_placed.emit(selected_unit, to_cell.x, to_cell.y)
	else:
		grid[selected_from_cell.x][selected_from_cell.y] = other_unit
		other_unit.board_position = selected_from_cell
		other_unit.position = _cell_to_world(selected_from_cell.x, selected_from_cell.y)
		unit_moved.emit(selected_unit, selected_from_cell, to_cell)

	_clear_selection()


func _remove_from_board(cell: Vector2i) -> void:
	if _is_valid_cell(cell.x, cell.y):
		var unit = grid[cell.x][cell.y]
		if unit != null:
			grid[cell.x][cell.y] = null
			unit.is_on_bench = true
			unit.board_position = Vector2i(-1, -1)


func _clear_selection() -> void:
	selected_unit = null
	selected_from_cell = Vector2i(-1, -1)
	selected_from_bench = false
	input_state = InputState.IDLE
	_clear_highlights()


func get_all_placed_units() -> Array:
	var result: Array = []
	for col in COLS:
		for row in ROWS:
			if grid[col][row] != null:
				result.append(grid[col][row])
	return result


func get_unit_count() -> int:
	return get_all_placed_units().size()


func get_team_capacity() -> int:
	return team_capacity


func set_team_capacity(value: int) -> void:
	team_capacity = maxi(1, value)
	if get_unit_count() > team_capacity:
		team_capacity = get_unit_count()
	queue_redraw()


func cell_to_world(col: int, row: int) -> Vector2:
	return _cell_to_world(col, row)


func combat_cell_to_world(col: int, row: int) -> Vector2:
	var combat_cell_h: float = _cell_size * 0.5
	return _board_offset + Vector2(col * _cell_size + _cell_size * 0.5, row * combat_cell_h + combat_cell_h * 0.5)


func _cell_to_world(col: int, row: int) -> Vector2:
	return _board_offset + Vector2(col * _cell_size + _cell_size * 0.5, row * _cell_size + _cell_size * 0.5)


func _world_to_cell(world_pos: Vector2) -> Vector2i:
	var local: Vector2 = world_pos - _board_offset
	return Vector2i(int(local.x / _cell_size), int(local.y / _cell_size))


func _is_valid_cell(col: int, row: int) -> bool:
	return col >= 0 and col < COLS and row >= 0 and row < ROWS


func _draw_board() -> void:
	queue_redraw()


func _draw() -> void:
	var board_rect := Rect2(_board_offset - Vector2(16, 16), Vector2(COLS * _cell_size + 32, ROWS * _cell_size + 32))
	draw_rect(board_rect, Color(0.04, 0.06, 0.09, 0.42), true)
	draw_rect(board_rect, Color(0.42, 0.52, 0.66, 0.32), false, 2.0)
	_draw_lane_labels()

	for col in COLS:
		for row in ROWS:
			var rect_pos: Vector2 = _board_offset + Vector2(col * _cell_size, row * _cell_size)
			var rect := Rect2(rect_pos, Vector2(_cell_size - 2, _cell_size - 2))
			var tint: Color = _tile_tint_for(col, row)
			draw_texture_rect(TILE_TEXTURE, rect, false, tint)
			draw_rect(rect, Color(0.48, 0.58, 0.72, 0.18), false, 1.5)
			if selected_unit != null and selected_from_bench and grid[col][row] == null:
				draw_rect(rect.grow(-8), Color(0.20, 0.60, 0.32, 0.20), true)
				draw_rect(rect.grow(-8), Color(0.32, 0.88, 0.50, 0.85), false, 2.0)
			elif selected_unit != null and not selected_from_bench and Vector2i(col, row) == selected_from_cell:
				draw_rect(rect.grow(-8), Color(0.82, 0.62, 0.18, 0.18), true)
				draw_rect(rect.grow(-8), Color(0.95, 0.80, 0.25, 0.95), false, 3.0)


func _highlight_valid_cells() -> void:
	queue_redraw()


func _clear_highlights() -> void:
	queue_redraw()


func _tile_tint_for(col: int, row: int) -> Color:
	var tint: Color = Color(0.82, 0.90, 1.0, 0.92)
	if row == 0:
		tint = Color(0.92, 0.86, 0.74, 0.96)
	elif row == ROWS - 1:
		tint = Color(0.74, 0.92, 0.82, 0.96)

	if selected_from_bench:
		tint = tint.lerp(Color(0.42, 1.0, 0.62, 1.0), 0.28)
	elif selected_unit != null and not selected_from_bench and Vector2i(col, row) == selected_from_cell:
		tint = tint.lerp(Color(1.0, 0.88, 0.42, 1.0), 0.45)

	return tint


func _draw_lane_labels() -> void:
	var backline_pos := _board_offset + Vector2(8, 8)
	var frontline_pos := _board_offset + Vector2(8, float((ROWS - 1) * _cell_size) + 8)
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	draw_string(font, backline_pos, "Backline", HORIZONTAL_ALIGNMENT_LEFT, -1, _label_font_size, Color(0.72, 0.82, 0.95, 0.78))
	draw_string(font, frontline_pos, "Frontline", HORIZONTAL_ALIGNMENT_LEFT, -1, _label_font_size, Color(0.90, 0.84, 0.66, 0.78))


func _bind_scene_peers() -> void:
	var root: Node = get_parent()
	if root == null:
		root = get_tree().current_scene
	if root == null:
		return

	_bench_ui = root.get_node_or_null("BenchUI")
	_hud_ui = root.get_node_or_null("HudUI")
	_shop_ui = root.get_node_or_null("ShopUI")

	if root.has_signal("phase_changed") and not root.phase_changed.is_connected(_on_phase_changed):
		root.phase_changed.connect(_on_phase_changed)

	if _bench_ui != null:
		if not _bench_ui.unit_selected_from_bench.is_connected(select_unit_from_bench):
			_bench_ui.unit_selected_from_bench.connect(select_unit_from_bench)
		if not unit_placed.is_connected(_on_unit_placed_on_board):
			unit_placed.connect(_on_unit_placed_on_board)
		if not unit_sent_to_bench.is_connected(_on_unit_sent_to_bench):
			unit_sent_to_bench.connect(_on_unit_sent_to_bench)

	_on_phase_changed(PREP_PHASE)


func _refresh_layout() -> void:
	var view_size: Vector2 = get_viewport_rect().size
	var left_margin: float = clampf(view_size.x * 0.11, 96.0, 160.0)
	var right_margin: float = clampf(view_size.x * 0.03, 18.0, 36.0)
	var top_margin: float = 88.0
	var bottom_limit: float = view_size.y - 260.0
	if _bench_ui != null:
		bottom_limit = minf(bottom_limit, _bench_ui.position.y - 18.0)
	elif _shop_ui != null:
		bottom_limit = minf(bottom_limit, _shop_ui.position.y - 92.0)
	var usable_w: float = maxf(280.0, view_size.x - left_margin - right_margin)
	var usable_h: float = maxf(220.0, bottom_limit - top_margin)
	_cell_size = clampf(minf(usable_w / float(COLS), usable_h / float(ROWS)), 52.0, 112.0)
	var board_w: float = float(COLS) * _cell_size
	var board_h: float = float(ROWS) * _cell_size
	_board_offset = Vector2(left_margin + (usable_w - board_w) * 0.5, top_margin + (usable_h - board_h) * 0.5)
	_label_font_size = int(clampf(_cell_size * 0.15, 10.0, 14.0))
	for unit in get_all_placed_units():
		unit.position = _cell_to_world(unit.board_position.x, unit.board_position.y)
	queue_redraw()


func _on_phase_changed(phase: int) -> void:
	_interaction_enabled = phase == PREP_PHASE
	if not _interaction_enabled:
		_clear_selection()
	queue_redraw()


func _on_unit_placed_on_board(unit, _col: int, _row: int) -> void:
	if _bench_ui != null:
		_bench_ui.on_unit_placed_on_board(unit)


func _on_unit_sent_to_bench(unit) -> void:
	if _bench_ui != null:
		_bench_ui.receive_unit_from_board(unit)


func _can_send_unit_to_bench(unit) -> bool:
	if unit == null:
		return false
	if _bench_ui == null:
		return false
	return _bench_ui.can_accept_unit(unit)
