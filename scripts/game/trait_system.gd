extends RefCounted

class_name TraitSystem

# Returns active synergies given a list of units on the board.
# Returns: Array of { "id", "type" ("race"|"class"), "data", "active_threshold" }
static func get_active_synergies(board_units: Array) -> Array:
	var race_units: Dictionary = {}
	var class_units: Dictionary = {}

	for unit in board_units:
		if unit == null:
			continue
		var unique_unit_id: String = str(unit.unit_id)
		if unit.race != "":
			if not race_units.has(unit.race):
				race_units[unit.race] = {}
			race_units[unit.race][unique_unit_id] = true
		if unit.trait_id != "":
			if not class_units.has(unit.trait_id):
				class_units[unit.trait_id] = {}
			class_units[unit.trait_id][unique_unit_id] = true

	var active: Array = []

	for race_id in race_units:
		var count: int = race_units[race_id].size()
		var race_data: Dictionary = DataManager.get_race(race_id)
		if race_data.is_empty():
			continue
		var threshold = _get_active_threshold(race_data.get("thresholds", []), count)
		if threshold != null:
			active.append({
				"id": race_id,
				"type": "race",
				"data": race_data,
				"active_threshold": threshold,
				"unit_count": count
			})

	for class_id in class_units:
		var count: int = class_units[class_id].size()
		var class_data: Dictionary = DataManager.get_class_data(class_id)
		if class_data.is_empty():
			continue
		var threshold = _get_active_threshold(class_data.get("thresholds", []), count)
		if threshold != null:
			active.append({
				"id": class_id,
				"type": "class",
				"data": class_data,
				"active_threshold": threshold,
				"unit_count": count
			})

	return active


# Apply synergy stat bonuses to all units.
static func apply_synergies(board_units: Array, active_synergies: Array) -> void:
	for synergy in active_synergies:
		var effect: String = synergy["active_threshold"].get("effect", "")
		var value: float = synergy["active_threshold"].get("value", 0.0)
		var synergy_type: String = synergy["type"]
		var synergy_id: String = synergy["id"]

		for unit in board_units:
			var matches: bool = (synergy_type == "race" and unit.race == synergy_id) \
			or (synergy_type == "class" and unit.trait_id == synergy_id)

			match effect:
				"max_hp_bonus_percent":
					if matches:
						unit.max_health = int(float(unit.max_health) * (1.0 + value))
						unit.current_health = unit.get_max_health()
				"damage_bonus_percent":
					if matches:
						unit.attack_damage = int(float(unit.attack_damage) * (1.0 + value))
				"attack_speed_bonus":
					if matches:
						unit.attack_speed += value
				"armor_bonus_percent":
					if matches:
						unit.armor = int(float(unit.armor) * (1.0 + value))
				"attack_range_bonus":
					if matches:
						unit.attack_range += int(value)
				# Effects like gold_per_round, revive_once, burn_on_hit, etc.
				# are handled at the appropriate moment in combat/economy systems.


# Returns the highest active threshold for a given count, or null.
static func _get_active_threshold(thresholds: Array, count: int) -> Variant:
	var best = null
	for t in thresholds:
		if count >= t.get("count", 999):
			if best == null or t.get("count", 0) > best.get("count", 0):
				best = t
	return best
