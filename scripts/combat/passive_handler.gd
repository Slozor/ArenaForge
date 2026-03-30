extends RefCounted

class_name PassiveHandler

const DEAD_STATE: int = 3

# Called once at combat start for a unit.
static func on_combat_start(unit, state: Dictionary) -> void:
	match unit.passive:
		"stealth_opener":
			state["stealthed"] = true
			state["stealth_timer"] = 2.0
		"first_strike":
			state["first_attack_done"] = false
		"pierce_shot":
			state["attack_count"] = 0
		"armor_to_power":
			# Convert 30% of armor into bonus attack damage
			unit.attack_damage += int(float(unit.get_armor()) * 0.3)
		"dragon_aura":
			pass  # Applied to allies via trait system
		"healing_aura":
			state["aura_timer"] = 1.0


# Called every delta while combat is running.
static func on_tick(unit, state: Dictionary, delta: float, allies: Array, _enemies: Array) -> void:
	match unit.passive:
		"stealth_opener":
			if state.get("stealthed", false):
				state["stealth_timer"] -= delta
				if state["stealth_timer"] <= 0.0:
					state["stealthed"] = false
		"last_stand":
			var hp_ratio: float = float(unit.current_health) / float(unit.get_max_health())
			if hp_ratio < 0.30 and not state.get("last_stand_active", false):
				state["last_stand_active"] = true
				unit.attack_speed += unit.attack_speed * 0.30
		"healing_aura":
			state["aura_timer"] = state.get("aura_timer", 0.0) - delta
			if state["aura_timer"] <= 0.0:
				state["aura_timer"] = 1.0  # heal tick every 1 second
				_heal_adjacent_ally(unit, allies)
		"death_curse":
			# Debuff timer countdown on enemies
			if state.get("curse_active", false):
				state["curse_timer"] -= delta
				if state["curse_timer"] <= 0.0:
					state["curse_active"] = false
					for entry in state.get("curse_targets", []):
						var enemy = entry.get("unit", null)
						var amount: int = entry.get("amount", 0)
						if is_instance_valid(enemy) and int(enemy.state) != DEAD_STATE:
							enemy.attack_damage = maxi(0, enemy.attack_damage + amount)


# Called just before an attack lands. Returns final damage.
static func on_pre_attack(attacker, _defender, base_damage: int, state: Dictionary) -> int:
	var damage: int = base_damage

	match attacker.passive:
		"first_strike":
			if not state.get("first_attack_done", true):
				damage = int(float(damage) * 1.5)
				state["first_attack_done"] = true
		"stealth_opener":
			if state.get("stealthed", false):
				damage = int(float(damage) * 2.0)
				state["stealthed"] = false  # stealth breaks on first attack

	return damage


# Called after an attack lands.
static func on_hit(attacker, defender, _damage_dealt: int, state: Dictionary, all_enemies: Array) -> void:
	match attacker.passive:
		"armor_shred":
			defender.armor = maxi(0, defender.armor - int(float(defender.armor) * 0.10))
		"pierce_shot":
			state["attack_count"] = state.get("attack_count", 0) + 1
			if state["attack_count"] % 3 == 0:
				_pierce_line(attacker, defender, all_enemies, attacker.get_attack_damage())
		"frozen_heart_item":
			# From item: slow enemy attack speed
			pass

	# Burn on hit (Dragon race synergy — applied externally, but passive hook available)


# Called when this unit kills an enemy.
static func on_kill(unit, _killed, _state: Dictionary) -> void:
	match unit.passive:
		"soul_harvest":
			var heal_amount: int = int(float(unit.get_max_health()) * 0.25)
			unit.heal(heal_amount)


# Called when this unit dies.
static func on_death(unit, state: Dictionary, nearby_enemies: Array) -> void:
	match unit.passive:
		"death_explosion":
			var explosion_damage: int = int(float(unit.get_attack_damage()) * 0.5)
			for enemy in nearby_enemies:
				if int(enemy.state) != DEAD_STATE:
					enemy.take_damage(explosion_damage)
		"death_curse":
			state["curse_active"] = true
			state["curse_timer"] = 3.0
			state["curse_targets"] = []
			for enemy in nearby_enemies:
				if int(enemy.state) != DEAD_STATE:
					# −20% attack damage for 3 seconds
					var amount: int = int(float(enemy.get_attack_damage()) * 0.20)
					enemy.attack_damage = maxi(0, enemy.attack_damage - amount)
					state["curse_targets"].append({
						"unit": enemy,
						"amount": amount
					})


# --- Helpers ---

static func _heal_adjacent_ally(healer, allies: Array) -> void:
	var pos: Vector2i = healer.board_position
	for ally in allies:
		if ally == healer or int(ally.state) == DEAD_STATE:
			continue
		var d: int = maxi(abs(ally.board_position.x - pos.x), abs(ally.board_position.y - pos.y))
		if d <= 1:
			var heal: int = int(float(ally.get_max_health()) * 0.08)
			ally.heal(heal)
			break  # heal only nearest ally


static func _pierce_line(_attacker, primary_target, all_enemies: Array, damage: int) -> void:
	# Hits all enemies in the same column as the primary target
	for enemy in all_enemies:
		if enemy == primary_target or int(enemy.state) == DEAD_STATE:
			continue
		if enemy.board_position.x == primary_target.board_position.x:
			enemy.take_damage(int(float(damage) * 0.5))
