extends Node

class_name CombatController

const DEAD_STATE: int = 3
const IDLE_STATE: int = 0
const MOVING_STATE: int = 1
const ATTACKING_STATE: int = 2

# How often units move one cell (seconds)
const MOVE_INTERVAL: float = 0.35
# How many seconds before sudden death
const SUDDEN_DEATH_TIME: float = 30.0
# Damage per second during sudden death
const SUDDEN_DEATH_DPS: int = 15

var player_units: Array = []
var enemy_units: Array = []

var _is_running: bool = false
var _combat_ended: bool = false
var _elapsed: float = 0.0
var _move_timer: float = 0.0
var _sudden_death: bool = false
var _sudden_death_accumulator: float = 0.0

# Per-unit state: attack cooldown + passive state
# Key: unit instance id, Value: { "atk_timer": float, "passive": Dictionary }
var _unit_state: Dictionary = {}

# Occupied cells on combat board: Vector2i -> Unit
var _occupied: Dictionary = {}

# Timed combat effects
# Burn: unit id -> { timer, dps, accumulator }
var _burn_targets: Dictionary = {}
# Attack speed slow: unit id -> { timer, original_speed }
var _slow_targets: Dictionary = {}

signal unit_attacked(attacker, target, damage: int)
signal unit_moved(unit, to: Vector2i)
signal unit_died(unit, is_player_unit: bool)
signal combat_ended(player_won: bool)


func start(p_units: Array, e_units: Array) -> void:
	player_units = p_units.duplicate()
	enemy_units = e_units.duplicate()
	_is_running = true
	_combat_ended = false
	_elapsed = 0.0
	_move_timer = 0.0
	_sudden_death = false
	_sudden_death_accumulator = 0.0
	_unit_state.clear()
	_occupied.clear()
	_burn_targets.clear()
	_slow_targets.clear()

	for unit in player_units + enemy_units:
		unit.reset_combat_state()
		_register_position(unit)

	# Initialize per-unit state
	for unit in player_units + enemy_units:
		var state: Dictionary = {}
		PassiveHandler.on_combat_start(unit, state)
		var ability: Dictionary = DataManager.get_unit_ability(unit.unit_id)
		unit.consume_mana()
		unit.finish_cast()
		_unit_state[unit.get_instance_id()] = {
			"atk_timer": 1.0 / maxf(unit.get_attack_speed(), 0.1),
			"passive": state,
			"target": null,
			"ability": ability,
			"casting": false,
			"cast_timer": 0.0
		}

	# Assassin leap at combat start
	_apply_assassin_leaps()

	# Guardian shields
	_apply_guardian_shields()

	# Connect death signals
	for unit in player_units + enemy_units:
		if not unit.died.is_connected(_on_unit_died):
			unit.died.connect(_on_unit_died)


func stop() -> void:
	_is_running = false


func _process(delta: float) -> void:
	if not _is_running:
		return

	_elapsed += delta

	# --- Sudden death ---
	if not _sudden_death and _elapsed >= SUDDEN_DEATH_TIME:
		_sudden_death = true

	if _sudden_death:
		_apply_sudden_death(delta)

	# --- Passive tick ---
	var all_units: Array = player_units + enemy_units
	for unit in all_units:
		var us: Dictionary = _unit_state.get(unit.get_instance_id(), {})
		var enemies: Array = _get_enemies_of(unit)
		var allies: Array = _get_allies_of(unit)
		if int(unit.state) == DEAD_STATE and unit.passive != "death_curse":
			continue
		PassiveHandler.on_tick(unit, us.get("passive", {}), delta, allies, enemies)

	# --- Timed effects ---
	_tick_burn(delta)
	_tick_slow_effects(delta)
	_tick_casts(delta)

	# --- Movement tick ---
	_move_timer += delta
	if _move_timer >= MOVE_INTERVAL:
		_move_timer = 0.0
		_tick_movement()

	# --- Attack tick ---
	_tick_attacks(delta)

	# --- Win condition ---
	_check_end()


# ── Movement ────────────────────────────────────────────────────────────────

func _tick_movement() -> void:
	for unit in player_units + enemy_units:
		if int(unit.state) == DEAD_STATE:
			continue
		if _is_casting(unit):
			continue
		var target = _acquire_target(unit)
		if target == null:
			continue
		if UnitAI.in_attack_range(unit, target):
			unit.state = ATTACKING_STATE
			continue
		unit.state = MOVING_STATE
		var next: Vector2i = UnitAI.next_move_toward(unit, target, _occupied)
		if next != Vector2i(-1, -1):
			_move_unit(unit, next)


func _move_unit(unit, to: Vector2i) -> void:
	_occupied.erase(unit.board_position)
	unit.board_position = to
	_occupied[to] = unit
	unit_moved.emit(unit, to)


# ── Attacks ─────────────────────────────────────────────────────────────────

func _tick_attacks(delta: float) -> void:
	for unit in player_units + enemy_units:
		if int(unit.state) == DEAD_STATE:
			continue
		if _is_casting(unit):
			continue
		var us: Dictionary = _unit_state.get(unit.get_instance_id(), {})
		us["atk_timer"] -= delta
		if us["atk_timer"] <= 0.0:
			us["atk_timer"] = 1.0 / maxf(unit.get_attack_speed(), 0.1)
			_try_attack(unit, us)


func _try_attack(unit, us: Dictionary) -> void:
	var target = _acquire_target(unit)
	if target == null or int(target.state) == DEAD_STATE:
		return
	if not UnitAI.in_attack_range(unit, target):
		return

	var base_dmg: int = unit.get_attack_damage()
	var final_dmg: int = PassiveHandler.on_pre_attack(unit, target, base_dmg, us.get("passive", {}))

	# Dragon race burn: dealt as flat damage before armor (applied by CombatController)
	var burn_active: bool = _has_dragon_burn_synergy(unit)

	unit.play_attack_pulse()
	target.take_damage(final_dmg)
	_gain_mana(unit, 20)
	_gain_mana(target, maxi(6, int(float(final_dmg) * 0.30)))

	if burn_active and int(target.state) != DEAD_STATE:
		_apply_burn(target)

	_apply_item_proc_on_hit(unit, target, final_dmg)

	unit_attacked.emit(unit, target, final_dmg)

	PassiveHandler.on_hit(unit, target, final_dmg, us.get("passive", {}), _get_enemies_of(unit))

	if int(target.state) == DEAD_STATE:
		PassiveHandler.on_kill(unit, target, us.get("passive", {}))


# ── Special combat-start effects ────────────────────────────────────────────

func _apply_assassin_leaps() -> void:
	for unit in player_units + enemy_units:
		if unit.trait_id != "assassin":
			continue
		var enemies: Array = _get_enemies_of(unit)
		var bt = UnitAI.find_assassin_target(unit, enemies)
		if bt == null:
			continue
		# Find nearest free cell adjacent to the backline target
		var leap_cell: Vector2i = _find_free_adjacent(bt.board_position, unit)
		if leap_cell != Vector2i(-1, -1):
			_occupied.erase(unit.board_position)
			unit.board_position = leap_cell
			_occupied[leap_cell] = unit
			unit_moved.emit(unit, leap_cell)


func _apply_guardian_shields() -> void:
	# Count guardians per team
	var player_guardians: int = 0
	var enemy_guardians: int = 0
	for u in player_units:
		if u.trait_id == "guardian":
			player_guardians += 1
	for u in enemy_units:
		if u.trait_id == "guardian":
			enemy_guardians += 1

	if player_guardians >= 2:
		for u in player_units:
			u.heal(int(float(u.get_max_health()) * 0.15))
	if enemy_guardians >= 2:
		for u in enemy_units:
			u.heal(int(float(u.get_max_health()) * 0.15))


# ── Targeting ───────────────────────────────────────────────────────────────

func _acquire_target(unit):
	var enemies: Array = _get_enemies_of(unit)
	return UnitAI.find_target(unit, enemies)


func _get_enemies_of(unit) -> Array:
	if unit in player_units:
		return enemy_units
	return player_units


func _get_allies_of(unit) -> Array:
	if unit in player_units:
		return player_units
	return enemy_units


# ── Death ───────────────────────────────────────────────────────────────────

func _on_unit_died(unit) -> void:
	var is_player: bool = unit in player_units
	var us: Dictionary = _unit_state.get(unit.get_instance_id(), {})
	us["casting"] = false
	us["cast_timer"] = 0.0
	_unit_state[unit.get_instance_id()] = us
	unit.finish_cast()
	var nearby: Array = _get_units_within_range(unit, 1, _get_enemies_of(unit))
	PassiveHandler.on_death(unit, us.get("passive", {}), nearby)

	_occupied.erase(unit.board_position)
	unit_died.emit(unit, is_player)

	# Check Undead revive synergy
	if _has_undead_revive_synergy(unit):
		_revive_unit(unit)
		return

	_check_end()


func _revive_unit(unit) -> void:
	unit.has_revived = true
	unit.current_health = int(float(unit.get_max_health()) * 0.50)
	unit.state = IDLE_STATE
	unit.temp_attack_speed_mod = 0.0
	unit.cancel_death_visuals()
	_register_position(unit)
	_burn_targets.erase(unit.get_instance_id())
	_slow_targets.erase(unit.get_instance_id())
	unit.health_changed.emit(unit.current_health, unit.get_max_health())


# ── Synergy helpers ──────────────────────────────────────────────────────────

func _has_dragon_burn_synergy(unit) -> bool:
	if unit.race != "dragon":
		return false
	var team: Array = _get_allies_of(unit)
	var count: int = 0
	for u in team:
		if u.race == "dragon" and int(u.state) != DEAD_STATE:
			count += 1
	return count >= 2


func _has_undead_revive_synergy(unit) -> bool:
	if unit.race != "undead" or unit.has_revived:
		return false
	var team: Array = _get_allies_of(unit)
	var count: int = 0
	for u in team:
		if u.race == "undead":
			count += 1
	return count >= 2


# ── Burn DoT (Dragon race) ───────────────────────────────────────────────────

func _apply_burn(target) -> void:
	_burn_targets[target.get_instance_id()] = {
		"timer": 3.0,
		"dps": 10,
		"accumulator": 0.0
	}
	target.set_burn_visual(1.0)


func _tick_burn(delta: float) -> void:
	var expired: Array = []
	for id in _burn_targets.keys():
		var b: Dictionary = _burn_targets[id]
		b["timer"] -= delta
		b["accumulator"] += float(b.get("dps", 0)) * delta
		for unit in player_units + enemy_units:
			if unit.get_instance_id() == id and int(unit.state) != DEAD_STATE:
				while b["accumulator"] >= 1.0 and int(unit.state) != DEAD_STATE:
					b["accumulator"] -= 1.0
					unit.take_damage(1, true)
				break
		if b["timer"] <= 0.0:
			expired.append(id)
		else:
			_burn_targets[id] = b
	for id in expired:
		_burn_targets.erase(id)


func _apply_item_proc_on_hit(attacker, defender, damage_dealt: int) -> void:
	for item_id in attacker.get_equipped_items():
		match item_id:
			"vampiric_blade":
				var heal_amount: int = maxi(1, int(float(damage_dealt) * 0.15))
				attacker.heal(heal_amount)
			"frozen_heart":
				if int(defender.state) != DEAD_STATE:
					_apply_attack_speed_slow(defender, 2.0, 0.25)

	for item_id in defender.get_equipped_items():
		match item_id:
			"thornmail":
				var reflected: int = maxi(1, int(float(damage_dealt) * 0.20))
				attacker.take_damage(reflected, true)


func _apply_attack_speed_slow(target, duration: float, slow_percent: float) -> void:
	var id: int = target.get_instance_id()
	if _slow_targets.has(id):
		_slow_targets[id]["timer"] = duration
		return

	var original_temp_mod: float = target.temp_attack_speed_mod
	var slow_amount: float = target.get_attack_speed() * slow_percent
	target.temp_attack_speed_mod = original_temp_mod - slow_amount
	target.set_slow_visual(1.0)
	_slow_targets[id] = {
		"timer": duration,
		"original_temp_mod": original_temp_mod
	}


func _tick_slow_effects(delta: float) -> void:
	var expired: Array = []
	for id in _slow_targets.keys():
		var entry: Dictionary = _slow_targets[id]
		entry["timer"] -= delta
		if entry["timer"] <= 0.0:
			for unit in player_units + enemy_units:
				if unit.get_instance_id() == id and int(unit.state) != DEAD_STATE:
					unit.temp_attack_speed_mod = float(entry.get("original_temp_mod", 0.0))
					break
			expired.append(id)
		else:
			_slow_targets[id] = entry
	for id in expired:
		_slow_targets.erase(id)


# ── Sudden death ─────────────────────────────────────────────────────────────

func _apply_sudden_death(delta: float) -> void:
	_sudden_death_accumulator += float(SUDDEN_DEATH_DPS) * delta
	var tick_damage: int = int(_sudden_death_accumulator)
	if tick_damage <= 0:
		return
	_sudden_death_accumulator -= float(tick_damage)
	for unit in player_units + enemy_units:
		if int(unit.state) != DEAD_STATE:
			unit.take_damage(tick_damage, true)


# ── Win condition ────────────────────────────────────────────────────────────

func _check_end() -> void:
	if _combat_ended:
		return
	var players_alive: int = player_units.filter(func(u): return int(u.state) != DEAD_STATE).size()
	var enemies_alive: int = enemy_units.filter(func(u): return int(u.state) != DEAD_STATE).size()

	if players_alive == 0 or enemies_alive == 0:
		_end_combat(enemies_alive == 0)


func _end_combat(player_won: bool) -> void:
	if _combat_ended:
		return
	_combat_ended = true
	_is_running = false
	combat_ended.emit(player_won)


# ── Utility ──────────────────────────────────────────────────────────────────

func _register_position(unit) -> void:
	if unit.board_position != Vector2i(-1, -1):
		_occupied[unit.board_position] = unit


func _tick_casts(delta: float) -> void:
	for unit in player_units + enemy_units:
		if int(unit.state) == DEAD_STATE:
			continue
		var us: Dictionary = _unit_state.get(unit.get_instance_id(), {})
		if not us.get("casting", false):
			continue
		us["cast_timer"] = float(us.get("cast_timer", 0.0)) - delta
		if us["cast_timer"] > 0.0:
			continue
		us["casting"] = false
		us["cast_timer"] = 0.0
		_unit_state[unit.get_instance_id()] = us
		if int(unit.state) != DEAD_STATE:
			AbilitySystem.resolve_ability(
				unit,
				us.get("ability", {}),
				_get_allies_of(unit),
				_get_enemies_of(unit)
			)
			unit.finish_cast()
			unit.state = IDLE_STATE
			us["atk_timer"] = 1.0 / maxf(unit.get_attack_speed(), 0.1)
			_unit_state[unit.get_instance_id()] = us


func _gain_mana(unit, amount: int) -> void:
	if unit == null or amount <= 0 or int(unit.state) == DEAD_STATE:
		return
	var id: int = unit.get_instance_id()
	var us: Dictionary = _unit_state.get(id, {})
	if us.get("casting", false):
		return
	if unit.gain_mana(amount):
		_begin_cast(unit)


func _begin_cast(unit) -> void:
	var id: int = unit.get_instance_id()
	var us: Dictionary = _unit_state.get(id, {})
	if us.is_empty() or us.get("casting", false):
		return
	us["casting"] = true
	us["cast_timer"] = float(us.get("ability", {}).get("cast_time", 0.35))
	_unit_state[id] = us
	unit.consume_mana()
	unit.begin_cast()
	unit.state = ATTACKING_STATE


func _is_casting(unit) -> bool:
	var us: Dictionary = _unit_state.get(unit.get_instance_id(), {})
	return us.get("casting", false)


func _find_free_adjacent(center: Vector2i, _mover) -> Vector2i:
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var cell: Vector2i = center + Vector2i(dx, dy)
			if _on_combat_board(cell) and not _occupied.has(cell):
				return cell
	return Vector2i(-1, -1)


func _get_units_within_range(origin, range_cells: int, candidates: Array) -> Array:
	var result: Array = []
	for u in candidates:
		if int(u.state) == DEAD_STATE:
			continue
		var d: int = maxi(
			abs(u.board_position.x - origin.board_position.x),
			abs(u.board_position.y - origin.board_position.y)
		)
		if d <= range_cells:
			result.append(u)
	return result


func _on_combat_board(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < UnitAI.COMBAT_COLS and cell.y >= 0 and cell.y < UnitAI.COMBAT_ROWS
