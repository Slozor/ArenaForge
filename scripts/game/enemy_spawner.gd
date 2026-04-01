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
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
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
	unit_ids = _refine_unit_ids_for_style(unit_ids, str(opponent_profile.get("style", "default")), round_num)
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
		"boss":
			return _build_positions_from_row_order(count, [3, 2, 1, 0], true)
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


func _refine_unit_ids_for_style(unit_ids: Array, style: String, round_num: int) -> Array:
	var prefs: Array[String] = _style_role_preferences(style)
	if prefs.is_empty() or unit_ids.is_empty():
		return unit_ids
	var refined: Array[String] = []
	var used: Array[String] = []
	var swaps_left: int = 1 if unit_ids.size() <= 3 else 2
	if round_num >= 11:
		swaps_left += 1
	for original in unit_ids:
		var unit_id: String = str(original)
		if unit_id == "":
			continue
		var unit_data: Dictionary = DataManager.get_unit(unit_id)
		var cost: int = int(unit_data.get("cost", 1))
		var role: String = DataManager.get_unit_role(unit_id)
		var keep_original: bool = prefs.slice(0, 2).has(role) or _rng.randf() > 0.60 or swaps_left <= 0
		if keep_original:
			refined.append(unit_id)
			used.append(unit_id)
			continue
		var replacement: String = _pick_style_unit(cost, prefs, used)
		if replacement == "":
			refined.append(unit_id)
			used.append(unit_id)
			continue
		refined.append(replacement)
		used.append(replacement)
		swaps_left -= 1
	return refined


func _pick_style_unit(cost: int, role_preferences: Array[String], excluded: Array[String]) -> String:
	for role in role_preferences:
		var candidate: String = DataManager.get_random_unit_for_role(role, cost, excluded, _rng)
		if candidate != "":
			return candidate
	var fallback: Array[String] = []
	for unit_id in DataManager.get_all_unit_ids():
		if excluded.has(str(unit_id)):
			continue
		var unit_data: Dictionary = DataManager.get_unit(str(unit_id))
		if int(unit_data.get("cost", 0)) == cost:
			fallback.append(str(unit_id))
	if fallback.is_empty():
		for unit_id in DataManager.get_all_unit_ids():
			var fallback_id: String = str(unit_id)
			if excluded.has(fallback_id):
				continue
			fallback.append(fallback_id)
	if fallback.is_empty():
		return ""
	return fallback[_rng.randi_range(0, fallback.size() - 1)]


func _style_role_preferences(style: String) -> Array[String]:
	match style:
		"frontline", "bruiser":
			return ["frontline", "skirmisher", "balanced", "support", "backline"]
		"burst", "mage":
			return ["backline", "support", "offense", "balanced", "skirmisher"]
		"assassin":
			return ["skirmisher", "backline", "offense", "frontline", "balanced"]
		"tempo", "control":
			return ["support", "balanced", "backline", "frontline", "skirmisher"]
		"economy":
			return ["balanced", "support", "backline", "frontline", "offense"]
		"boss":
			return ["frontline", "balanced", "skirmisher", "support", "backline"]
		_:
			return ["balanced", "frontline", "backline", "support", "skirmisher"]
