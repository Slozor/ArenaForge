extends RefCounted

class_name PassiveHandler

# Called once at combat start for a unit.
static func on_combat_start(unit: Unit, state: Dictionary) -> void:
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
			unit.item_attack_damage += int(float(unit.get_armor()) * 0.3)
		"dragon_aura":
			pass  # Applied to allies via trait system


# Called every delta while combat is running.
static func on_tick(unit: Unit, state: Dictionary, delta: float, allies: Array, enemies: Array) -> void:
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
					for enemy in state.get("cursed_enemies", []):
						if is_instance_valid(enemy) and enemy.state != Unit.State.DEAD:
							enemy.item_attack_damage = maxi(0, enemy.item_attack_damage + int(enemy.get_attack_damage() * 0.20))


# Called just before an attack lands. Returns final damage.
static func on_pre_attack(attacker: Unit, defender: Unit, base_damage: int, state: Dictionary) -> int:
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
static func on_hit(attacker: Unit, defender: Unit, damage_dealt: int, state: Dictionary, all_enemies: Array) -> void:
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
static func on_kill(unit: Unit, killed: Unit, state: Dictionary) -> void:
	match unit.passive:
		"soul_harvest":
			var heal_amount: int = int(float(unit.get_max_health()) * 0.25)
			unit.heal(heal_amount)


# Called when this unit dies.
static func on_death(unit: Unit, state: Dictionary, nearby_enemies: Array) -> void:
	match unit.passive:
		"death_explosion":
			var explosion_damage: int = int(float(unit.get_attack_damage()) * 0.5)
			for enemy in nearby_enemies:
				if enemy.state != Unit.State.DEAD:
					enemy.take_damage(explosion_damage)
		"death_curse":
			state["curse_active"] = true
			state["curse_timer"] = 3.0
			state["cursed_enemies"] = nearby_enemies.duplicate()
			for enemy in nearby_enemies:
				if enemy.state != Unit.State.DEAD:
					# −20% attack damage for 3 seconds
					enemy.item_attack_damage -= int(float(enemy.get_attack_damage()) * 0.20)


# --- Helpers ---

static func _heal_adjacent_ally(healer: Unit, allies: Array) -> void:
	var pos: Vector2i = healer.board_position
	for ally in allies:
		if ally == healer or ally.state == Unit.State.DEAD:
			continue
		var d: int = maxi(abs(ally.board_position.x - pos.x), abs(ally.board_position.y - pos.y))
		if d <= 1:
			var heal: int = int(float(ally.get_max_health()) * 0.08)
			ally.heal(heal)
			break  # heal only nearest ally


static func _pierce_line(attacker: Unit, primary_target: Unit, all_enemies: Array, damage: int) -> void:
	# Hits all enemies in the same column as the primary target
	for enemy in all_enemies:
		if enemy == primary_target or enemy.state == Unit.State.DEAD:
			continue
		if enemy.board_position.x == primary_target.board_position.x:
			enemy.take_damage(int(float(damage) * 0.5))
