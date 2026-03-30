extends Node2D

const COLS: int = 7
const ROWS: int = 4  # 4 rows for player, 4 mirrored for enemy
const CELL_SIZE: float = 96.0

var player_units: Array = []
var enemy_units: Array = []
var grid: Array = []  # 2D array [col][row] -> Unit or null


func _ready() -> void:
	_initialize_grid()


func _initialize_grid() -> void:
	grid.resize(COLS)
	for col in COLS:
		grid[col] = []
		grid[col].resize(ROWS)
		for row in ROWS:
			grid[col][row] = null


func place_unit(unit, col: int, row: int) -> bool:
	if not _is_valid_cell(col, row):
		return false
	if grid[col][row] != null:
		return false
	grid[col][row] = unit
	unit.board_position = Vector2i(col, row)
	unit.is_on_bench = false
	unit.position = cell_to_world(col, row)
	player_units.append(unit)
	return true


func remove_unit(col: int, row: int):
	if not _is_valid_cell(col, row):
		return null
	var unit = grid[col][row]
	if unit == null:
		return null
	grid[col][row] = null
	unit.board_position = Vector2i(-1, -1)
	unit.is_on_bench = true
	player_units.erase(unit)
	return unit


func cell_to_world(col: int, row: int) -> Vector2:
	return Vector2(col * CELL_SIZE + CELL_SIZE / 2.0, row * CELL_SIZE + CELL_SIZE / 2.0)


func world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(world_pos.x / CELL_SIZE), int(world_pos.y / CELL_SIZE))


func _is_valid_cell(col: int, row: int) -> bool:
	return col >= 0 and col < COLS and row >= 0 and row < ROWS
