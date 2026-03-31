extends RefCounted

class_name AbilitySystem

const DEAD_STATE: int = 3


static func resolve_ability(caster, ability: Dictionary, allies: Array, enemies: Array) -> void:
	if caster == null or ability.is_empty() or int(caster.state) == DEAD_STATE:
		return

	var effect: String = str(ability.get("effect", "splash_damage"))
	var power: float = float(ability.get("power", 100.0))
	var radius: int = int(ability.get("radius", 0))

	match effect:
		"splash_damage":
			_splash_damage(caster, enemies, power, radius, str(ability.get("target", "weakest_enemy")))
		"line_blast":
			_line_blast(caster, enemies, power, str(ability.get("target", "weakest_enemy")))
		"heal_burst":
			_heal_burst(caster, allies, power, radius, str(ability.get("target", "lowest_ally")))
		"shield_burst":
			_shield_burst(caster, allies, power, radius)
		"chain_damage":
			_chain_damage(caster, enemies, power)
		"execute_strike":
			_execute_strike(caster, enemies, power)
		"frenzy":
			_apply_frenzy(caster, power)
		"burn_burst":
			_burn_burst(caster, enemies, power, radius)
		"drain_damage":
			_drain_damage(caster, enemies, power)
		_:
			_splash_damage(caster, enemies, power, radius, str(ability.get("target", "weakest_enemy")))


static func _splash_damage(caster, enemies: Array, power: float, radius: int, target_mode: String) -> void:
	var target = _pick_enemy_target(caster, enemies, target_mode)
	if target == null:
		return
	var primary_damage: int = maxi(1, int(round(power)))
	var splash_damage: int = maxi(1, int(round(power * 0.65)))
	for enemy in enemies:
		if int(enemy.state) == DEAD_STATE:
			continue
		var dist: int = _distance(enemy.board_position, target.board_position)
		if enemy == target:
			enemy.take_damage(primary_damage)
		elif dist <= maxi(1, radius):
			enemy.take_damage(splash_damage)


static func _line_blast(caster, enemies: Array, power: float, target_mode: String) -> void:
	var target = _pick_enemy_target(caster, enemies, target_mode)
	if target == null:
		return
	var damage: int = maxi(1, int(round(power)))
	for enemy in enemies:
		if int(enemy.state) == DEAD_STATE:
			continue
		if enemy.board_position.y == target.board_position.y:
			enemy.take_damage(damage)


static func _heal_burst(caster, allies: Array, power: float, radius: int, target_mode: String) -> void:
	var center = _pick_ally_target(caster, allies, target_mode)
	if center == null:
		center = caster
	if center == null:
		return
	var heal_amount: int = maxi(1, int(round(power)))
	for ally in allies:
		if int(ally.state) == DEAD_STATE:
			continue
		if _distance(ally.board_position, center.board_position) <= maxi(1, radius):
			ally.heal(heal_amount)


static func _shield_burst(caster, allies: Array, power: float, radius: int) -> void:
	var heal_amount: int = maxi(1, int(round(power)))
	for ally in allies:
		if int(ally.state) == DEAD_STATE:
			continue
		if _distance(ally.board_position, caster.board_position) <= maxi(1, radius):
			ally.heal(heal_amount)


static func _chain_damage(caster, enemies: Array, power: float) -> void:
	var target = _pick_enemy_target(caster, enemies, "weakest_enemy")
	if target == null:
		return
	var sorted: Array = enemies.filter(func(e): return int(e.state) != DEAD_STATE)
	sorted.sort_custom(func(a, b): return _distance(a.board_position, target.board_position) < _distance(b.board_position, target.board_position))
	var falloff: Array[float] = [1.0, 0.75, 0.55]
	for i in min(3, sorted.size()):
		var enemy = sorted[i]
		enemy.take_damage(maxi(1, int(round(power * falloff[i]))))


static func _execute_strike(caster, enemies: Array, power: float) -> void:
	var target = _pick_enemy_target(caster, enemies, "weakest_enemy")
	if target == null:
		return
	var damage: float = power
	if float(target.current_health) / float(max(1, target.get_max_health())) <= 0.35:
		damage *= 1.35
	target.take_damage(maxi(1, int(round(damage))))


static func _apply_frenzy(caster, power: float) -> void:
	caster.temp_attack_speed_mod += float(power)
	caster.play_attack_pulse()


static func _burn_burst(caster, enemies: Array, power: float, radius: int) -> void:
	var target = _pick_enemy_target(caster, enemies, "weakest_enemy")
	if target == null:
		return
	var primary_damage: int = maxi(1, int(round(power)))
	var splash_damage: int = maxi(1, int(round(power * 0.6)))
	for enemy in enemies:
		if int(enemy.state) == DEAD_STATE:
			continue
		var dist: int = _distance(enemy.board_position, target.board_position)
		if enemy == target:
			enemy.take_damage(primary_damage)
			enemy.set_burn_visual(1.0)
		elif dist <= maxi(1, radius):
			enemy.take_damage(splash_damage)
			enemy.set_burn_visual(0.7)


static func _drain_damage(caster, enemies: Array, power: float) -> void:
	var target = _pick_enemy_target(caster, enemies, "weakest_enemy")
	if target == null:
		return
	var damage: int = maxi(1, int(round(power)))
	var died: bool = target.take_damage(damage)
	var heal_amount: int = maxi(1, int(round(float(damage) * 0.5)))
	caster.heal(heal_amount)
	if died:
		caster.play_heal_pulse()


static func _pick_enemy_target(caster, enemies: Array, mode: String):
	var living: Array = []
	for enemy in enemies:
		if int(enemy.state) != DEAD_STATE:
			living.append(enemy)
	if living.is_empty():
		return null
	match mode:
		"nearest_enemy":
			var best = null
			var best_dist: float = INF
			for enemy in living:
				var dist: float = _distance(caster.board_position, enemy.board_position)
				if dist < best_dist:
					best_dist = dist
					best = enemy
			return best
		_:
			var weakest = null
			var lowest_hp: int = 0
			for enemy in living:
				if weakest == null or enemy.current_health < lowest_hp:
					lowest_hp = enemy.current_health
					weakest = enemy
			return weakest


static func _pick_ally_target(caster, allies: Array, mode: String):
	var living: Array = []
	for ally in allies:
		if int(ally.state) != DEAD_STATE:
			living.append(ally)
	if living.is_empty():
		return caster
	match mode:
		"lowest_ally":
			var weakest = living[0]
			var weakest_ratio: float = float(weakest.current_health) / float(max(1, weakest.get_max_health()))
			for ally in living:
				var ratio: float = float(ally.current_health) / float(max(1, ally.get_max_health()))
				if ratio < weakest_ratio:
					weakest_ratio = ratio
					weakest = ally
			return weakest
		_:
			return caster


static func _distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(abs(a.x - b.x), abs(a.y - b.y))
