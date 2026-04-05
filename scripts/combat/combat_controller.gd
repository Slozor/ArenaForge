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
# Attack speed haste: unit id -> { timer, original_temp_mod }
var _haste_targets: Dictionary = {}
# Quick lookup: instance_id -> unit (populated in start())
var _unit_map: Dictionary = {}

signal unit_attacked(attacker, target, damage: int)
signal unit_moved(unit, to: Vector2i)
signal unit_died(unit, is_player_unit: bool)
signal combat_ended(player_won: bool)


func start(p_units: Array, e_units: Array, battle_modifiers: Dictionary = {}) -> void:
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
	_haste_targets.clear()

	_unit_map.clear()
	for unit in player_units + enemy_units:
		unit.reset_combat_state()
		_register_position(unit)
		_unit_map[unit.get_instance_id()] = unit

	# Initialize per-unit state
	for unit in player_units + enemy_units:
		var enemy_modifiers: Dictionary = battle_modifiers.get("enemy", {})
		if enemy_modifiers.is_empty() and battle_modifiers.has("health_mult"):
			enemy_modifiers = battle_modifiers
		var player_modifiers: Dictionary = battle_modifiers.get("player", {})
		if player_modifiers.is_empty() and battle_modifiers.has("player_health_mult"):
			player_modifiers = battle_modifiers
		var side_modifiers: Dictionary = enemy_modifiers if unit in enemy_units else player_modifiers
		_apply_side_modifiers(unit, side_modifiers)
		var state: Dictionary = {}
		var ability: Dictionary = DataManager.get_unit_ability(unit.unit_id)
		var item_identity: Dictionary = _apply_combat_start_item_effects(unit, ability)
		PassiveHandler.on_combat_start(unit, state)
		unit.consume_mana()
		var starting_mana: int = int(side_modifiers.get("starting_mana", 0)) + int(item_identity.get("starting_mana", 0))
		if starting_mana > 0:
			unit.gain_mana(starting_mana)
		var cast_time_delta: float = float(side_modifiers.get("cast_time_delta", 0.0)) + float(item_identity.get("cast_time_delta", 0.0))
		if cast_time_delta != 0.0:
			ability["cast_time"] = maxf(0.10, float(ability.get("cast_time", 0.35)) + cast_time_delta)
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


func _apply_side_modifiers(unit, modifiers: Dictionary) -> void:
	if modifiers.is_empty() or unit == null:
		return
	var health_mult: float = float(modifiers.get("health_mult", 1.0))
	if health_mult != 1.0:
		unit.max_health = maxi(1, int(round(float(unit.max_health) * health_mult)))
		unit.current_health = unit.get_max_health()
	var attack_damage_mult: float = float(modifiers.get("attack_damage_mult", 1.0))
	if attack_damage_mult != 1.0:
		unit.attack_damage = maxi(1, int(round(float(unit.attack_damage) * attack_damage_mult)))
	var armor_bonus: int = int(modifiers.get("armor_bonus", 0))
	if armor_bonus != 0:
		unit.armor += armor_bonus
	var attack_speed_bonus: float = float(modifiers.get("attack_speed_bonus", 0.0))
	if attack_speed_bonus != 0.0:
		unit.attack_speed += attack_speed_bonus
	if not modifiers.is_empty():
		unit.health_changed.emit(unit.current_health, unit.get_max_health())
		unit.queue_redraw()


func stop() -> void:
	_is_running = false
	_unit_map.clear()


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
		_unit_state[unit.get_instance_id()] = us

	# --- Timed effects ---
	_tick_burn(delta)
	_tick_slow_effects(delta)
	_tick_haste_effects(delta)
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
		_unit_state[unit.get_instance_id()] = us


func _try_attack(unit, us: Dictionary) -> void:
	var target = _acquire_target(unit)
	if target == null or int(target.state) == DEAD_STATE:
		return
	if not UnitAI.in_attack_range(unit, target):
		return

	var base_dmg: int = unit.get_attack_damage()
	var modified_dmg: int = _apply_attack_item_bonuses(unit, base_dmg)
	var final_dmg: int = PassiveHandler.on_pre_attack(unit, target, modified_dmg, us.get("passive", {}))

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
	_unit_state[unit.get_instance_id()] = us

	if int(target.state) == DEAD_STATE:
		PassiveHandler.on_kill(unit, target, us.get("passive", {}))
		_unit_state[unit.get_instance_id()] = us


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
	_unit_state[unit.get_instance_id()] = us

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
	_haste_targets.erase(unit.get_instance_id())
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

func _apply_burn(target, duration: float = 3.0, dps: int = 10) -> void:
	_burn_targets[target.get_instance_id()] = {
		"timer": duration,
		"dps": dps,
		"accumulator": 0.0
	}
	target.set_burn_visual(1.0)


func _tick_burn(delta: float) -> void:
	var expired: Array = []
	for id in _burn_targets.keys():
		var b: Dictionary = _burn_targets[id]
		b["timer"] -= delta
		b["accumulator"] += float(b.get("dps", 0)) * delta
		var unit = _unit_map.get(id)
		if unit != null and int(unit.state) != DEAD_STATE:
			while b["accumulator"] >= 1.0 and int(unit.state) != DEAD_STATE:
				b["accumulator"] -= 1.0
				unit.take_damage(1, true)
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
			"blazing_edge":
				if int(defender.state) != DEAD_STATE:
					_apply_burn(defender, 4.0, 14)
			"phantom_quiver":
				_apply_phantom_quiver(attacker, defender, damage_dealt)
			"storm_lance":
				_apply_storm_lance(attacker, defender, damage_dealt)

	for item_id in defender.get_equipped_items():
		match item_id:
			"thornmail":
				var reflected: int = maxi(1, int(float(damage_dealt) * 0.20))
				attacker.take_damage(reflected, true)
			"bastion_mail":
				var heavy_reflect: int = maxi(1, int(float(damage_dealt) * 0.30))
				attacker.take_damage(heavy_reflect, true)
			"sunforged_plate":
				if int(attacker.state) != DEAD_STATE:
					_apply_burn(attacker, 3.0, 10)


func _apply_attack_item_bonuses(attacker, base_damage: int) -> int:
	var multiplier: float = 1.0
	var role_profile: Dictionary = _get_item_role_profile(attacker)
	multiplier += minf(0.18, float(role_profile.get("offense", 0)) * 0.04)
	multiplier += minf(0.08, float(role_profile.get("tempo", 0)) * 0.02)
	for item_id in attacker.get_equipped_items():
		match item_id:
			"rage_crown":
				var alive_allies: int = _count_alive_allies(attacker)
				multiplier += minf(0.60, float(alive_allies) * 0.15)
	return maxi(1, int(round(float(base_damage) * multiplier)))


func _count_alive_allies(unit) -> int:
	var count: int = 0
	for ally in _get_allies_of(unit):
		if ally == unit:
			continue
		if int(ally.state) != DEAD_STATE:
			count += 1
	return count


func _apply_phantom_quiver(attacker, primary_target, damage_dealt: int) -> void:
	var bounce_target = null
	var bounce_dist: int = 999
	for enemy in _get_enemies_of(attacker):
		if enemy == primary_target or int(enemy.state) == DEAD_STATE:
			continue
		var dist: int = maxi(abs(enemy.board_position.x - primary_target.board_position.x), abs(enemy.board_position.y - primary_target.board_position.y))
		if dist < bounce_dist:
			bounce_dist = dist
			bounce_target = enemy
	if bounce_target != null:
		bounce_target.take_damage(maxi(1, int(round(float(damage_dealt) * 0.40))), true)


func _apply_storm_lance(attacker, primary_target, damage_dealt: int) -> void:
	for enemy in _get_enemies_of(attacker):
		if enemy == primary_target or int(enemy.state) == DEAD_STATE:
			continue
		if enemy.board_position.y == primary_target.board_position.y:
			enemy.take_damage(maxi(1, int(round(float(damage_dealt) * 0.35))), true)


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


func _apply_attack_speed_haste(target, duration: float, haste_flat: float) -> void:
	var id: int = target.get_instance_id()
	if _haste_targets.has(id):
		target.temp_attack_speed_mod = float(_haste_targets[id].get("original_temp_mod", target.temp_attack_speed_mod)) + haste_flat
		_haste_targets[id]["timer"] = duration
		return
	var original_temp_mod: float = target.temp_attack_speed_mod
	target.temp_attack_speed_mod = original_temp_mod + haste_flat
	_haste_targets[id] = {
		"timer": duration,
		"original_temp_mod": original_temp_mod
	}
	target.play_attack_pulse()


func _tick_slow_effects(delta: float) -> void:
	var expired: Array = []
	for id in _slow_targets.keys():
		var entry: Dictionary = _slow_targets[id]
		entry["timer"] -= delta
		if entry["timer"] <= 0.0:
			var unit = _unit_map.get(id)
			if unit != null and int(unit.state) != DEAD_STATE:
				unit.temp_attack_speed_mod = float(entry.get("original_temp_mod", 0.0))
			expired.append(id)
		else:
			_slow_targets[id] = entry
	for id in expired:
		_slow_targets.erase(id)


func _tick_haste_effects(delta: float) -> void:
	var expired: Array = []
	for id in _haste_targets.keys():
		var entry: Dictionary = _haste_targets[id]
		entry["timer"] -= delta
		if entry["timer"] <= 0.0:
			var unit = _unit_map.get(id)
			if unit != null and int(unit.state) != DEAD_STATE:
				unit.temp_attack_speed_mod = float(entry.get("original_temp_mod", 0.0))
			expired.append(id)
		else:
			_haste_targets[id] = entry
	for id in expired:
		_haste_targets.erase(id)


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
			unit.play_cast_pulse()
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
	amount += int(_get_item_role_profile(unit).get("utility", 0))
	var id: int = unit.get_instance_id()
	var us: Dictionary = _unit_state.get(id, {})
	if us.get("casting", false):
		return
	if unit.gain_mana(amount):
		_begin_cast(unit)


func _apply_combat_start_item_effects(unit, _ability: Dictionary = {}) -> Dictionary:
	var role_profile: Dictionary = _get_item_role_profile(unit)
	var adjustments: Dictionary = {
		"starting_mana": 0,
		"cast_time_delta": 0.0
	}
	var offense_count: int = int(role_profile.get("offense", 0))
	var defense_count: int = int(role_profile.get("defense", 0))
	var tempo_count: int = int(role_profile.get("tempo", 0))
	var utility_count: int = int(role_profile.get("utility", 0))
	if offense_count > 0:
		unit.attack_damage += offense_count * 4
	if defense_count > 0:
		unit.armor += defense_count * 4
		unit.heal(maxi(1, int(round(float(unit.get_max_health()) * 0.04 * float(defense_count)))))
	if tempo_count > 0:
		unit.attack_speed += float(tempo_count) * 0.05
	if utility_count > 0:
		adjustments["starting_mana"] = utility_count * 8
		adjustments["cast_time_delta"] = -0.02 * float(utility_count)
	for item_id in unit.get_equipped_items():
		match item_id:
			"heartward_talisman":
				unit.heal(maxi(1, int(round(float(unit.get_max_health()) * 0.12))))
	unit.health_changed.emit(unit.current_health, unit.get_max_health())
	unit.queue_redraw()
	return adjustments


func _get_item_role_profile(unit) -> Dictionary:
	var profile: Dictionary = {
		"offense": 0,
		"defense": 0,
		"tempo": 0,
		"utility": 0
	}
	if unit == null:
		return profile
	for item_id in unit.get_equipped_items():
		var role: String = DataManager.get_item_role(str(item_id))
		profile[role] = int(profile.get(role, 0)) + 1
	return profile


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
