extends Node

class_name EnemySpawner

# Full combat board dimensions
const COLS: int = 7
# Enemy occupies rows 0-3 of the full 7x8 board.
# Back rows are filled first from the enemy side: 0, 1, 2, 3.
const ENEMY_ROWS: Array = [0, 1, 2, 3]

# Path to the Unit scene used for instantiation.
const UNIT_SCENE_PATH: String = "res://scenes/units/unit.tscn"
const UNIT_SCRIPT_PATH: String = "res://scripts/units/unit.gd"

var _unit_scene: PackedScene = null


func _ready() -> void:
	_unit_scene = load(UNIT_SCENE_PATH)


# Returns an array with all enemy units placed on the enemy side of the
# board (rows 0-3, back rows first). Board positions use the full 7x8 coordinate
# space where row 0 is the enemy back row and row 7 is the player's back row.
func spawn_enemy_team(round_num: int, opponent_index: int = -1, opponent_profile: Dictionary = {}) -> Array:
	var round_entry: Dictionary = get_round_data(round_num)
	if round_entry.is_empty():
		push_error("EnemySpawner: no data for round %d" % round_num)
		return []

	var unit_ids: Array = _resolve_unit_ids(round_entry, opponent_index)
	var positions: Array[Vector2i] = _build_positions_for_style(unit_ids.size(), str(opponent_profile.get("style", "default")))
	var spawned: Array = []

	for i in unit_ids.size():
		var uid: String = unit_ids[i]
		var unit_data: Dictionary = DataManager.get_unit(uid)
		if unit_data.is_empty():
			push_error("EnemySpawner: unknown unit id '%s'" % uid)
			continue

		var unit = _instantiate_unit(unit_data)
		if unit == null:
			continue

		unit.board_position = positions[i]
		unit.is_on_bench = false
		unit.is_enemy_unit = true
		spawned.append(unit)

	return spawned


func get_round_data(round_num: int) -> Dictionary:
	return DataManager.get_round(round_num)


func get_round_type(round_num: int) -> String:
	return get_round_data(round_num).get("type", "combat")


func get_round_reward(round_num: int) -> Dictionary:
	return get_round_data(round_num).get("reward", {})


func get_opponent_count(round_num: int) -> int:
	var round_entry: Dictionary = get_round_data(round_num)
	var opponents: Array = round_entry.get("opponents", [])
	if opponents.is_empty():
		return 1
	return opponents.size()


func get_preview_units(round_num: int, opponent_index: int = -1) -> Array[String]:
	var round_entry: Dictionary = get_round_data(round_num)
	var raw_units: Array = _resolve_unit_ids(round_entry, opponent_index)
	var result: Array[String] = []
	for unit_id in raw_units:
		result.append(str(unit_id))
	return result


# ── Position layout ───────────────────────────────────────────────────────────

# Generates board positions for `count` units. Units are placed in back rows
# first (row 0 → 1 → 2 → 3), spread evenly across columns.
func _build_positions(count: int) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	var remaining: int = count

	for row in ENEMY_ROWS:
		if remaining <= 0:
			break
		var in_this_row: int = mini(remaining, COLS)
		var col_positions: Array[int] = _spread_columns(in_this_row, COLS)
		for col in col_positions:
			positions.append(Vector2i(col, row))
		remaining -= in_this_row

	return positions


func _build_positions_for_style(count: int, style: String) -> Array[Vector2i]:
	match style:
		"frontline", "bruiser":
			return _build_positions_from_row_order(count, [3, 2, 1, 0], true)
		"burst", "mage":
			return _build_positions_from_row_order(count, [0, 1, 2, 3], false)
		"assassin":
			return _build_assassin_positions(count)
		"tempo", "control":
			return _build_positions_from_row_order(count, [1, 2, 0, 3], false)
		"economy":
			return _build_positions_from_row_order(count, [2, 1, 3, 0], false)
		_:
			return _build_positions(count)


func _build_positions_from_row_order(count: int, row_order: Array, center_bias: bool) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	var remaining: int = count
	for row_value in row_order:
		if remaining <= 0:
			break
		var row: int = int(row_value)
		var in_this_row: int = mini(remaining, COLS)
		var col_positions: Array[int] = _spread_columns(in_this_row, COLS)
		if center_bias:
			col_positions.sort_custom(func(a, b): return abs(a - 3) < abs(b - 3))
		for col in col_positions:
			positions.append(Vector2i(col, row))
		remaining -= in_this_row
	return positions


func _build_assassin_positions(count: int) -> Array[Vector2i]:
	var pattern: Array[Vector2i] = [
		Vector2i(0, 1), Vector2i(6, 1), Vector2i(1, 0), Vector2i(5, 0),
		Vector2i(2, 1), Vector2i(4, 1), Vector2i(3, 0), Vector2i(3, 2),
		Vector2i(1, 2), Vector2i(5, 2), Vector2i(2, 3), Vector2i(4, 3)
	]
	var positions: Array[Vector2i] = []
	for cell in pattern:
		if positions.size() >= count:
			break
		positions.append(cell)
	if positions.size() < count:
		for cell in _build_positions(count):
			if positions.size() >= count:
				break
			if not positions.has(cell):
				positions.append(cell)
	return positions


# Returns `count` column indices spread as evenly as possible across `total_cols`.
func _spread_columns(count: int, total_cols: int) -> Array[int]:
	var cols: Array[int] = []
	if count >= total_cols:
		for c in total_cols:
			cols.append(c)
		return cols

	# Space units evenly: e.g. 3 units in 7 cols → cols 1, 3, 5
	var step: float = float(total_cols) / float(count)
	var offset: float = step / 2.0
	for i in count:
		cols.append(int(offset + i * step))
	return cols


# ── Unit instantiation ────────────────────────────────────────────────────────

func _instantiate_unit(unit_data: Dictionary):
	if _unit_scene == null:
		var unit_script: Script = load(UNIT_SCRIPT_PATH)
		if unit_script == null:
			push_error("EnemySpawner: could not load unit script")
			return null
		var spawned_unit = unit_script.new()
		spawned_unit.init(unit_data)
		add_child(spawned_unit)
		return spawned_unit

	var unit = _unit_scene.instantiate()
	if unit == null:
		push_error("EnemySpawner: UNIT_SCENE_PATH does not produce a valid unit node")
		return null
	unit.init(unit_data)
	add_child(unit)
	return unit


# ── Round lookup ──────────────────────────────────────────────────────────────

func _resolve_unit_ids(round_entry: Dictionary, opponent_index: int) -> Array:
	var opponents: Array = round_entry.get("opponents", [])
	if not opponents.is_empty():
		var index: int = clampi(opponent_index, 0, opponents.size() - 1)
		var opponent: Variant = opponents[index]
		if opponent is Dictionary:
			return opponent.get("units", [])
		if opponent is Array:
			return opponent
	var unit_ids: Array = round_entry.get("units", [])
	if unit_ids.is_empty():
		unit_ids = round_entry.get("enemy_units", [])
	return unit_ids
