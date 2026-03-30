extends RefCounted

class_name UnitAI

const DEAD_STATE: int = 3

# Full combat board: 7 cols x 8 rows (player rows 4-7, enemy rows 0-3)
const COMBAT_COLS: int = 7
const COMBAT_ROWS: int = 8

# Find the best target for a unit from the enemy list.
# Priority: closest unit. Tiebreak: prefer non-assassins (tanks first).
static func find_target(unit, enemies: Array):
	if unit.trait_id == "assassin":
		return find_assassin_target(unit, enemies)

	var best_target = null
	var best_score: float = INF

	for enemy in enemies:
		if int(enemy.state) == DEAD_STATE:
			continue
		var dist: float = _combat_distance(unit.board_position, enemy.board_position)
		# Role tiebreaker: tanks (warrior/guardian) get +0, others +0.1, assassins +0.2
		var role_bias: float = _role_bias(enemy.trait_id)
		var score: float = dist + role_bias
		if score < best_score:
			best_score = score
			best_target = enemy

	return best_target


# Find the weakest enemy (lowest current HP) — used by assassins.
static func find_weakest_enemy(enemies: Array):
	var weakest = null
	var lowest_hp: int = 0
	for enemy in enemies:
		if int(enemy.state) == DEAD_STATE:
			continue
		if weakest == null or enemy.current_health < lowest_hp:
			lowest_hp = enemy.current_health
			weakest = enemy
	return weakest


# Find the assassin target: weakest enemy, with a backline-friendly tiebreak.
static func find_assassin_target(unit, enemies: Array):
	var best = null
	var lowest_hp: int = 0
	var farthest_dist: float = -1.0
	for enemy in enemies:
		if int(enemy.state) == DEAD_STATE:
			continue
		var hp: int = enemy.current_health
		var dist: float = _combat_distance(unit.board_position, enemy.board_position)
		if best == null or hp < lowest_hp or (hp == lowest_hp and dist > farthest_dist):
			lowest_hp = hp
			farthest_dist = dist
			best = enemy
	return best


# Keep the old helper for callers that still expect a backline-ish pick.
static func find_backline_target(unit, enemies: Array):
	return find_assassin_target(unit, enemies)


# Returns true if the unit is within attack range of the target.
static func in_attack_range(unit, target) -> bool:
	return _combat_distance(unit.board_position, target.board_position) <= float(unit.attack_range)


# Returns the next cell to move toward the target.
# Tries the diagonal/straight step that gets closest.
# Returns Vector2i(-1,-1) if already at target or no move possible.
static func next_move_toward(unit, target, occupied: Dictionary) -> Vector2i:
	var from: Vector2i = unit.board_position
	var to: Vector2i = target.board_position

	if from == to:
		return Vector2i(-1, -1)

	# Generate all 8 neighbours + stay-put
	var candidates: Array[Vector2i] = _get_neighbours(from)
	var best_cell: Vector2i = Vector2i(-1, -1)
	var best_dist: float = INF

	for cell in candidates:
		if not _on_combat_board(cell):
			continue
		if occupied.has(cell) and occupied[cell] != unit:
			continue
		# Don't step into target's cell (we want to be adjacent, not on top)
		if cell == to:
			continue
		var dist: float = _combat_distance(cell, to)
		if dist < best_dist:
			best_dist = dist
			best_cell = cell

	return best_cell


# Manhattan-style distance on our square grid (Chebyshev — diagonal counts as 1).
static func _combat_distance(a: Vector2i, b: Vector2i) -> float:
	return float(maxi(abs(a.x - b.x), abs(a.y - b.y)))


static func _role_bias(trait_id: String) -> float:
	match trait_id:
		"warrior", "guardian": return 0.0
		"assassin":            return 0.2
		_:                     return 0.1


static func _get_neighbours(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			result.append(cell + Vector2i(dx, dy))
	return result


static func _on_combat_board(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < COMBAT_COLS and cell.y >= 0 and cell.y < COMBAT_ROWS
