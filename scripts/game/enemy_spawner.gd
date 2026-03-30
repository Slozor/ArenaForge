extends Node

class_name EnemySpawner

# Full combat board dimensions
const COLS: int = 7
# Enemy occupies rows 4-7 of the full 7x8 board.
# Back rows are filled first: 7, 6, 5, 4.
const ENEMY_ROWS: Array = [7, 6, 5, 4]

# Path to the Unit scene used for instantiation.
const UNIT_SCENE_PATH: String = "res://scenes/units/unit.tscn"

var _unit_scene: PackedScene = null
var _rounds_data: Array = []


func _ready() -> void:
	_unit_scene = load(UNIT_SCENE_PATH)
	_load_rounds()


func _load_rounds() -> void:
	var raw: Dictionary = _read_json("res://data/rounds.json")
	_rounds_data = raw.get("rounds", [])


# Returns an Array[Unit] with all enemy units placed on the enemy side of the
# board (rows 4-7, back rows first). Board positions use the full 7x8 coordinate
# space where row 0 is the player's front row and row 7 is the enemy's back row.
func spawn_enemy_team(round_num: int) -> Array[Unit]:
	var round_entry: Dictionary = _get_round_entry(round_num)
	if round_entry.is_empty():
		push_error("EnemySpawner: no data for round %d" % round_num)
		return []

	var unit_ids: Array = round_entry.get("units", [])
	var positions: Array[Vector2i] = _build_positions(unit_ids.size())
	var spawned: Array[Unit] = []

	for i in unit_ids.size():
		var uid: String = unit_ids[i]
		var unit_data: Dictionary = DataManager.get_unit(uid)
		if unit_data.is_empty():
			push_error("EnemySpawner: unknown unit id '%s'" % uid)
			continue

		var unit: Unit = _instantiate_unit(unit_data)
		if unit == null:
			continue

		unit.board_position = positions[i]
		unit.is_on_bench = false
		spawned.append(unit)

	return spawned


# ── Position layout ───────────────────────────────────────────────────────────

# Generates board positions for `count` units. Units are placed in back rows
# first (row 7 → 6 → 5 → 4), spread evenly across columns.
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

func _instantiate_unit(unit_data: Dictionary) -> Unit:
	if _unit_scene == null:
		# Fallback: create a bare Unit node if the scene is not available.
		var unit: Unit = Unit.new()
		unit.init(unit_data)
		add_child(unit)
		return unit

	var unit: Unit = _unit_scene.instantiate() as Unit
	if unit == null:
		push_error("EnemySpawner: UNIT_SCENE_PATH does not produce a Unit node")
		return null
	unit.init(unit_data)
	add_child(unit)
	return unit


# ── Round lookup ──────────────────────────────────────────────────────────────

func _get_round_entry(round_num: int) -> Dictionary:
	for entry in _rounds_data:
		if entry.get("round", -1) == round_num:
			return entry
	return {}


# ── JSON helper ───────────────────────────────────────────────────────────────

func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("EnemySpawner: could not open %s" % path)
		return {}
	var text: String = file.get_as_text()
	file.close()
	var result: Variant = JSON.parse_string(text)
	if result == null:
		push_error("EnemySpawner: failed to parse %s" % path)
		return {}
	return result
