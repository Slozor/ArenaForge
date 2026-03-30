extends Node2D

class_name BoardUI

const COLS: int = 7
const ROWS: int = 4
const CELL_SIZE: float = 96.0
const BOARD_OFFSET: Vector2 = Vector2(304.0, 55.0)  # centered in 1280x720, below HUD (50px)

enum InputState { IDLE, UNIT_SELECTED }

var input_state: InputState = InputState.IDLE
var selected_unit: Unit = null
var selected_from_cell: Vector2i = Vector2i(-1, -1)
var selected_from_bench: bool = false

# Grid: [col][row] -> Unit or null
var grid: Array = []

signal unit_placed(unit: Unit, col: int, row: int)
signal unit_moved(unit: Unit, from: Vector2i, to: Vector2i)
signal unit_sent_to_bench(unit: Unit)

@onready var highlight_layer: Node2D = $HighlightLayer
@onready var cell_highlights: Array = []


func _ready() -> void:
	_initialize_grid()
	_draw_board()


func _initialize_grid() -> void:
	grid.resize(COLS)
	for col in COLS:
		grid[col] = []
		grid[col].resize(ROWS)
		for row in ROWS:
			grid[col][row] = null


# Called by bench UI when a unit is tapped on the bench
func select_unit_from_bench(unit: Unit) -> void:
	_set_selected(unit, Vector2i(-1, -1), true)


func _input(event: InputEvent) -> void:
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
				_set_selected(grid[cell.x][cell.y], cell, false)

		InputState.UNIT_SELECTED:
			if on_board:
				if cell == selected_from_cell and not selected_from_bench:
					# Tap same cell again → deselect
					_clear_selection()
				elif grid[cell.x][cell.y] != null:
					# Swap with existing unit
					_swap_units(cell)
				else:
					# Place on empty cell
					_place_selected_unit(cell)
			else:
				# Tapped outside board → send back to bench
				if not selected_from_bench:
					_remove_from_board(selected_from_cell)
					unit_sent_to_bench.emit(selected_unit)
				_clear_selection()


func _set_selected(unit: Unit, from_cell: Vector2i, from_bench: bool) -> void:
	selected_unit = unit
	selected_from_cell = from_cell
	selected_from_bench = from_bench
	input_state = InputState.UNIT_SELECTED
	_highlight_valid_cells()


func _place_selected_unit(to_cell: Vector2i) -> void:
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
	var other_unit: Unit = grid[to_cell.x][to_cell.y]

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
		var unit: Unit = grid[cell.x][cell.y]
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


func cell_to_world(col: int, row: int) -> Vector2:
	return _cell_to_world(col, row)


func _cell_to_world(col: int, row: int) -> Vector2:
	return BOARD_OFFSET + Vector2(col * CELL_SIZE + CELL_SIZE * 0.5, row * CELL_SIZE + CELL_SIZE * 0.5)


func _world_to_cell(world_pos: Vector2) -> Vector2i:
	var local: Vector2 = world_pos - BOARD_OFFSET
	return Vector2i(int(local.x / CELL_SIZE), int(local.y / CELL_SIZE))


func _is_valid_cell(col: int, row: int) -> bool:
	return col >= 0 and col < COLS and row >= 0 and row < ROWS


func _draw_board() -> void:
	queue_redraw()


func _draw() -> void:
	for col in COLS:
		for row in ROWS:
			var rect_pos: Vector2 = BOARD_OFFSET + Vector2(col * CELL_SIZE, row * CELL_SIZE)
			var rect := Rect2(rect_pos, Vector2(CELL_SIZE - 2, CELL_SIZE - 2))
			var color: Color = Color(0.2, 0.25, 0.3, 0.8)
			draw_rect(rect, color)
			draw_rect(rect, Color(0.4, 0.5, 0.6, 0.5), false, 1.5)


func _highlight_valid_cells() -> void:
	queue_redraw()


func _clear_highlights() -> void:
	queue_redraw()
