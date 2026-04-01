extends Node

var units: Dictionary = {}       # unit_id -> unit data dict
var races: Dictionary = {}       # race_id -> race data dict
var classes: Dictionary = {}     # class_id -> class data dict
var items: Dictionary = {}       # item_id -> item data dict
var rounds: Dictionary = {}      # round_num -> round data dict
var opponents: Dictionary = {}   # opponent_id -> opponent profile dict
var opponent_order: Array[String] = []
var augments: Dictionary = {}    # augment_id -> augment data dict
var encounters: Dictionary = {}  # encounter_id -> encounter data dict
var _tiny_dungeon_portraits: Dictionary = {
	"iron_guard": "res://assets/kenney_tiny_dungeon/Tiles/tile_0087.png",
	"watchman": "res://assets/kenney_tiny_dungeon/Tiles/tile_0085.png",
	"paladin": "res://assets/kenney_tiny_dungeon/Tiles/tile_0086.png",
	"silver_paladin": "res://assets/kenney_tiny_dungeon/Tiles/tile_0087.png",
	"scout": "res://assets/kenney_tiny_dungeon/Tiles/tile_0098.png",
	"elven_archer": "res://assets/kenney_tiny_dungeon/Tiles/tile_0097.png",
	"elven_mage": "res://assets/kenney_tiny_dungeon/Tiles/tile_0099.png",
	"storm_adept": "res://assets/kenney_tiny_dungeon/Tiles/tile_0099.png",
	"shadowblade": "res://assets/kenney_tiny_dungeon/Tiles/tile_0088.png",
	"glade_sage": "res://assets/kenney_tiny_dungeon/Tiles/tile_0084.png",
	"lumen_ranger": "res://assets/kenney_tiny_dungeon/Tiles/tile_0098.png",
	"mirth_blade": "res://assets/kenney_tiny_dungeon/Tiles/tile_0088.png",
	"moonweaver": "res://assets/kenney_tiny_dungeon/Tiles/tile_0100.png",
	"thornwarden": "res://assets/kenney_tiny_dungeon/Tiles/tile_0096.png",
	"oak_sentinel": "res://assets/kenney_tiny_dungeon/Tiles/tile_0096.png",
	"bone_walker": "res://assets/kenney_tiny_dungeon/Tiles/tile_0096.png",
	"grave_archer": "res://assets/kenney_tiny_dungeon/Tiles/tile_0096.png",
	"soul_reaper": "res://assets/kenney_tiny_dungeon/Tiles/tile_0100.png",
	"crag_chief": "res://assets/kenney_tiny_dungeon/Tiles/tile_0084.png",
	"ember_raider": "res://assets/kenney_tiny_dungeon/Tiles/tile_0088.png",
	"forge_shaman": "res://assets/kenney_tiny_dungeon/Tiles/tile_0099.png",
	"siegebreaker": "res://assets/kenney_tiny_dungeon/Tiles/tile_0086.png",
	"ash_duelist": "res://assets/kenney_tiny_dungeon/Tiles/tile_0088.png",
	"stone_breaker": "res://assets/kenney_tiny_dungeon/Tiles/tile_0086.png",
	"runesmith": "res://assets/kenney_tiny_dungeon/Tiles/tile_0099.png",
	"stone_bulwark": "res://assets/kenney_tiny_dungeon/Tiles/tile_0087.png",
	"flameling": "res://assets/kenney_tiny_dungeon/Tiles/tile_0097.png",
	"dragon_knight": "res://assets/kenney_tiny_dungeon/Tiles/tile_0086.png",
	"ember_witch": "res://assets/kenney_tiny_dungeon/Tiles/tile_0100.png",
	"spellblade": "res://assets/kenney_tiny_dungeon/Tiles/tile_0088.png"
}


func _ready() -> void:
	_load_units()
	_load_traits()
	_load_items()
	_load_rounds()
	_load_opponents()
	_load_augments()
	_load_encounters()


func _load_units() -> void:
	var raw: Dictionary = _read_json("res://data/units.json")
	for unit_data in raw.get("units", []):
		units[unit_data["id"]] = unit_data


func _load_traits() -> void:
	var raw: Dictionary = _read_json("res://data/traits.json")
	for race_data in raw.get("races", []):
		races[race_data["id"]] = race_data
	for class_data in raw.get("classes", []):
		classes[class_data["id"]] = class_data


func _load_items() -> void:
	var raw: Dictionary = _read_json("res://data/items.json")
	for item_data in raw.get("items", []):
		items[item_data["id"]] = item_data


func _load_rounds() -> void:
	var raw: Dictionary = _read_json("res://data/rounds.json")
	for round_data in raw.get("rounds", []):
		rounds[int(round_data.get("round", 0))] = round_data


func _load_opponents() -> void:
	var raw: Dictionary = _read_json("res://data/opponents.json")
	opponents.clear()
	opponent_order.clear()
	for opponent_data in raw.get("opponents", []):
		var opponent_id: String = str(opponent_data.get("id", ""))
		if opponent_id == "":
			continue
		opponents[opponent_id] = opponent_data
		opponent_order.append(opponent_id)


func _load_augments() -> void:
	augments = {
		"tactical_reserve": {
			"id": "tactical_reserve",
			"name": "Tactical Reserve",
			"tier": "silver",
			"description": "+1 maximum board size."
		},
		"golden_handshake": {
			"id": "golden_handshake",
			"name": "Golden Handshake",
			"tier": "silver",
			"description": "Gain 6 gold immediately."
		},
		"silver_spoon": {
			"id": "silver_spoon",
			"name": "Silver Spoon",
			"tier": "silver",
			"description": "Gain +2 bonus gold at the start of every round."
		},
		"frontline_oath": {
			"id": "frontline_oath",
			"name": "Frontline Oath",
			"tier": "gold",
			"description": "Your team gains 12% max health."
		},
		"rapid_fire": {
			"id": "rapid_fire",
			"name": "Rapid Fire",
			"tier": "gold",
			"description": "Your team gains 18% attack speed."
		},
		"heavy_blades": {
			"id": "heavy_blades",
			"name": "Heavy Blades",
			"tier": "gold",
			"description": "Your team gains 15% attack damage."
		},
		"arcane_charge": {
			"id": "arcane_charge",
			"name": "Arcane Charge",
			"tier": "gold",
			"description": "Your team starts combat with 20 mana."
		},
		"stone_skin": {
			"id": "stone_skin",
			"name": "Stone Skin",
			"tier": "silver",
			"description": "Your team gains 12 armor."
		},
		"component_cache": {
			"id": "component_cache",
			"name": "Component Cache",
			"tier": "silver",
			"description": "Gain a random component immediately."
		},
		"battle_ready": {
			"id": "battle_ready",
			"name": "Battle Ready",
			"tier": "silver",
			"description": "Your team starts combat with 10% bonus max health as healing."
		},
		"mana_surge": {
			"id": "mana_surge",
			"name": "Mana Surge",
			"tier": "gold",
			"description": "Your team starts combat with 35 mana."
		},
		"bulwark_training": {
			"id": "bulwark_training",
			"name": "Bulwark Training",
			"tier": "silver",
			"description": "Your team gains 18 armor."
		},
		"treasure_token": {
			"id": "treasure_token",
			"name": "Treasure Token",
			"tier": "silver",
			"description": "Gain 8 gold immediately."
		},
		"component_cache_plus": {
			"id": "component_cache_plus",
			"name": "Component Cache+",
			"tier": "gold",
			"description": "Gain 2 random components immediately."
		}
	}


func _load_encounters() -> void:
	encounters = {
		"rich_opening": {
			"id": "rich_opening",
			"name": "Rich Opening",
			"description": "Start the run with 4 extra gold."
		},
		"component_cache": {
			"id": "component_cache",
			"name": "Component Cache",
			"description": "Start the run with a random component."
		},
		"battle_banner": {
			"id": "battle_banner",
			"name": "Battle Banner",
			"description": "Your team capacity is increased by 1 for the whole run."
		},
		"second_wind": {
			"id": "second_wind",
			"name": "Second Wind",
			"description": "Winning a combat restores 2 health."
		}
	}


func get_unit(unit_id: String) -> Dictionary:
	return units.get(unit_id, {})


func get_all_unit_ids() -> Array:
	return units.keys()


func get_units_by_cost(cost: int) -> Array:
	var result: Array = []
	for id in units:
		if units[id].get("cost", 0) == cost:
			result.append(id)
	return result


func get_race(race_id: String) -> Dictionary:
	return races.get(race_id, {})


func get_class_data(class_id: String) -> Dictionary:
	return classes.get(class_id, {})


func get_trait_data(trait_id: String) -> Dictionary:
	var race_data: Dictionary = get_race(trait_id)
	if not race_data.is_empty():
		return race_data
	return get_class_data(trait_id)


func get_item(item_id: String) -> Dictionary:
	return items.get(item_id, {})


func get_item_icon(item_id: String) -> Texture2D:
	var item: Dictionary = get_item(item_id)
	var category: String = str(item.get("category", "component"))
	var path: String = "res://assets/items/icon_%s.svg" % category
	if FileAccess.file_exists(path):
		return load(path) as Texture2D
	return load("res://assets/items/placeholder_item.svg") as Texture2D


func get_all_item_ids() -> Array:
	return items.keys()


func get_items_by_category(category: String) -> Array:
	var result: Array = []
	for item_id in items:
		if items[item_id].get("category", "") == category:
			result.append(item_id)
	return result


func get_item_role(item_id: String) -> String:
	var item: Dictionary = get_item(item_id)
	if item.is_empty():
		return "utility"
	return _infer_item_role(item)


func get_random_item(category: String = "", mode: String = "component", excluded: Array = [], rng: RandomNumberGenerator = null) -> String:
	var pool: Array[String] = _build_item_pool(category, mode, excluded)
	if pool.is_empty():
		return ""
	var picker: RandomNumberGenerator = rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		picker.randomize()
	var total_weight: int = 0
	var weighted_pool: Array = []
	for item_id in pool:
		var item: Dictionary = get_item(item_id)
		var weight: int = _get_item_weight(item)
		weighted_pool.append({ "id": item_id, "weight": weight })
		total_weight += weight
	if total_weight <= 0:
		return pool[0]
	var roll: int = picker.randi_range(1, total_weight)
	var running: int = 0
	for entry in weighted_pool:
		running += int(entry.get("weight", 0))
		if roll <= running:
			return str(entry.get("id", ""))
	return pool[0]


func get_random_item_for_role(role: String, category: String = "", mode: String = "component", excluded: Array = [], rng: RandomNumberGenerator = null) -> String:
	var pool: Array[String] = _build_item_pool(category, mode, excluded)
	if pool.is_empty():
		return ""
	var role_pool: Array[String] = []
	for item_id in pool:
		if _infer_item_role(get_item(item_id)) == role:
			role_pool.append(item_id)
	if role_pool.is_empty():
		role_pool = pool
	return get_random_item_from_pool(role_pool, rng)


func get_random_items(count: int, category: String = "", mode: String = "component", rng: RandomNumberGenerator = null) -> Array[String]:
	var result: Array[String] = []
	var excluded: Array[String] = []
	for _i in count:
		var item_id: String = get_random_item(category, mode, excluded, rng)
		if item_id == "":
			break
		result.append(item_id)
		excluded.append(item_id)
	return result


func get_random_item_from_pool(pool: Array[String], rng: RandomNumberGenerator = null) -> String:
	if pool.is_empty():
		return ""
	var picker: RandomNumberGenerator = rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		picker.randomize()
	return pool[picker.randi_range(0, pool.size() - 1)]


func _build_item_pool(category: String, mode: String, excluded: Array = []) -> Array[String]:
	var result: Array[String] = []
	for item_id in items:
		if excluded.has(item_id):
			continue
		var item: Dictionary = items[item_id]
		var item_category: String = str(item.get("category", ""))
		if category != "" and item_category != category:
			continue
		if not _matches_item_mode(item_category, mode):
			continue
		result.append(item_id)
	return result


func _matches_item_mode(item_category: String, mode: String) -> bool:
	match mode:
		"component":
			return item_category == "component"
		"crafted":
			return item_category == "crafted"
		"legacy":
			return item_category == "legacy"
		"mixed":
			return item_category == "component" or item_category == "crafted"
		_:
			return true


func _get_item_weight(item: Dictionary) -> int:
	if item.has("loot_weight"):
		return maxi(1, int(item.get("loot_weight", 1)))
	match str(item.get("category", "")):
		"component":
			return 10
		"crafted":
			return 4
		"legacy":
			return 2
		_:
			return 1


func get_craft_result(item_a: String, item_b: String) -> String:
	var pair: Array = [item_a, item_b]
	pair.sort()
	for item_id in items:
		var item_data: Dictionary = items[item_id]
		var recipe: Array = item_data.get("combine_from", [])
		if recipe.size() != 2:
			continue
		var recipe_pair: Array = [str(recipe[0]), str(recipe[1])]
		recipe_pair.sort()
		if recipe_pair == pair:
			return item_id
	return ""


func get_item_recipe(item_id: String) -> Array:
	return items.get(item_id, {}).get("combine_from", [])


func get_item_tooltip(item_id: String) -> String:
	var item: Dictionary = get_item(item_id)
	if item.is_empty():
		return item_id
	var category: String = str(item.get("category", "")).capitalize()
	var effect: String = str(item.get("effect", "")).replace("_", " ").capitalize()
	var lines: Array[String] = []
	lines.append(str(item.get("name", item_id)))
	if category != "":
		lines.append(category)
	if str(item.get("description", "")) != "":
		lines.append(str(item.get("description", "")))
	if effect != "":
		lines.append("Effect: %s" % effect)
	if str(item.get("category", "")) == "component":
		lines.append("Combine with a matching component to craft a full item")
	if item.get("combine_from", []).size() == 2:
		lines.append("Combine: %s + %s" % [str(item["combine_from"][0]), str(item["combine_from"][1])])
	if bool(item.get("auto_equip", false)):
		lines.append("Auto-equip if inventory is full")
	return "\n".join(lines)


func get_unit_portrait_path(unit_id: String) -> String:
	var unit_data: Dictionary = get_unit(unit_id)
	if unit_data.is_empty():
		return "res://assets/portraits/race_generic.svg"
	if _tiny_dungeon_portraits.has(unit_id):
		return str(_tiny_dungeon_portraits[unit_id])
	var unit_path: String = "res://assets/portraits/units/%s.svg" % unit_id
	if FileAccess.file_exists(unit_path):
		return unit_path
	var race_id: String = str(unit_data.get("race", ""))
	var race_path: String = "res://assets/portraits/race_%s.svg" % race_id
	if FileAccess.file_exists(race_path):
		return race_path
	return "res://assets/portraits/race_generic.svg"


func get_unit_portrait(unit_id: String) -> Texture2D:
	var path: String = get_unit_portrait_path(unit_id)
	return load(path) as Texture2D


func get_unit_role(unit_id: String) -> String:
	var unit_data: Dictionary = get_unit(unit_id)
	if unit_data.is_empty():
		return "balanced"
	return _infer_unit_role(unit_data)


func get_units_by_role(role: String, cost: int = -1) -> Array:
	var result: Array = []
	for unit_id in units:
		var unit_data: Dictionary = units[unit_id]
		if cost != -1 and int(unit_data.get("cost", 0)) != cost:
			continue
		if _infer_unit_role(unit_data) == role:
			result.append(unit_id)
	return result


func get_random_unit_for_role(role: String, cost: int = -1, excluded: Array = [], rng: RandomNumberGenerator = null) -> String:
	var pool: Array[String] = []
	for unit_id in units:
		if excluded.has(unit_id):
			continue
		var unit_data: Dictionary = units[unit_id]
		if cost != -1 and int(unit_data.get("cost", 0)) != cost:
			continue
		if _infer_unit_role(unit_data) == role:
			pool.append(unit_id)
	if pool.is_empty():
		for unit_id in units:
			if excluded.has(unit_id):
				continue
			var unit_data: Dictionary = units[unit_id]
			if cost != -1 and int(unit_data.get("cost", 0)) != cost:
				continue
			pool.append(unit_id)
	return get_random_item_from_pool(pool, rng)


func get_round(round_num: int) -> Dictionary:
	return rounds.get(round_num, {})


func get_round_type(round_num: int) -> String:
	return get_round(round_num).get("type", "combat")


func get_round_reward(round_num: int) -> Dictionary:
	return get_round(round_num).get("reward", {})


func get_opponent(opponent_id: String) -> Dictionary:
	return opponents.get(opponent_id, {})


func get_all_opponent_ids() -> Array[String]:
	return opponent_order.duplicate()


func get_augment(augment_id: String) -> Dictionary:
	return augments.get(augment_id, {})


func get_random_augments(count: int, excluded: Array = [], rng: RandomNumberGenerator = null) -> Array[String]:
	var choices: Array[String] = []
	var pool: Array[String] = []
	for augment_id in augments.keys():
		if excluded.has(augment_id):
			continue
		pool.append(str(augment_id))
	if pool.is_empty() or count <= 0:
		return choices
	var picker: RandomNumberGenerator = rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		picker.randomize()
	while choices.size() < count and not pool.is_empty():
		var index: int = picker.randi_range(0, pool.size() - 1)
		choices.append(pool[index])
		pool.remove_at(index)
	return choices


func get_random_augments_for_round(round_num: int, count: int, excluded: Array = [], rng: RandomNumberGenerator = null) -> Array[String]:
	var allowed_tiers: Array[String] = ["silver"]
	if round_num >= 8:
		allowed_tiers.append("gold")
	var choices: Array[String] = []
	var pool: Array[String] = []
	for augment_id in augments.keys():
		if excluded.has(augment_id):
			continue
		var augment: Dictionary = get_augment(str(augment_id))
		var tier: String = str(augment.get("tier", "silver"))
		if not allowed_tiers.has(tier):
			continue
		pool.append(str(augment_id))
	if pool.is_empty():
		return get_random_augments(count, excluded, rng)
	var picker: RandomNumberGenerator = rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		picker.randomize()
	while choices.size() < count and not pool.is_empty():
		var index: int = picker.randi_range(0, pool.size() - 1)
		choices.append(pool[index])
		pool.remove_at(index)
	return choices


func get_augment_tooltip(augment_id: String) -> String:
	var augment: Dictionary = get_augment(augment_id)
	if augment.is_empty():
		return augment_id.replace("_", " ").capitalize()
	var lines: Array[String] = []
	lines.append(str(augment.get("name", augment_id.replace("_", " ").capitalize())))
	lines.append("%s Augment" % str(augment.get("tier", "silver")).capitalize())
	lines.append(str(augment.get("description", "")))
	return "\n".join(lines)


func get_encounter(encounter_id: String) -> Dictionary:
	return encounters.get(encounter_id, {})


func get_random_encounter(rng: RandomNumberGenerator = null) -> String:
	if encounters.is_empty():
		return ""
	var keys: Array = encounters.keys()
	var picker: RandomNumberGenerator = rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		picker.randomize()
	return str(keys[picker.randi_range(0, keys.size() - 1)])


func get_encounter_tooltip(encounter_id: String) -> String:
	var encounter: Dictionary = get_encounter(encounter_id)
	if encounter.is_empty():
		return ""
	return "%s\n%s" % [str(encounter.get("name", encounter_id)), str(encounter.get("description", ""))]


func get_all_round_numbers() -> Array:
	return rounds.keys()


func get_unit_tooltip(unit_id: String) -> String:
	var unit_data: Dictionary = get_unit(unit_id)
	if unit_data.is_empty():
		return unit_id
	var stats: Dictionary = unit_data.get("stats", {})
	var race_id: String = str(unit_data.get("race", ""))
	var trait_id: String = str(unit_data.get("trait", ""))
	var race_name: String = get_race(race_id).get("name", race_id.capitalize())
	var trait_name: String = get_class_data(trait_id).get("name", trait_id.capitalize())
	var passive_id: String = str(unit_data.get("passive", ""))
	var passive_label: String = passive_id.replace("_", " ").capitalize()
	var ability: Dictionary = get_unit_ability(unit_id)
	var lines: Array[String] = []
	lines.append(str(unit_data.get("name", unit_id)))
	lines.append("%s / %s" % [race_name, trait_name])
	lines.append("Cost: %s" % str(unit_data.get("cost", 1)))
	lines.append("HP: %s  AD: %s  AS: %s" % [
		str(stats.get("health", 0)),
		str(stats.get("attack_damage", 0)),
		str(stats.get("attack_speed", 0.0))
	])
	lines.append("Range: %s  Armor: %s" % [
		str(stats.get("attack_range", 0)),
		str(stats.get("armor", 0))
	])
	lines.append("Passive: %s" % passive_label)
	if not ability.is_empty():
		lines.append("Ability: %s (%d mana, %.1fs cast)" % [
			str(ability.get("name", "Ability")),
			int(ability.get("mana", 0)),
			float(ability.get("cast_time", 0.0))
		])
		lines.append(str(ability.get("description", "")))
	return "\n".join(lines)


func get_unit_ability(unit_id: String) -> Dictionary:
	var unit_data: Dictionary = get_unit(unit_id)
	if unit_data.is_empty():
		return {}
	return _resolve_unit_ability(unit_data)


func get_trait_tooltip(trait_id: String) -> String:
	var trait_data: Dictionary = get_trait_data(trait_id)
	if trait_data.is_empty():
		return trait_id.capitalize()
	var lines: Array[String] = []
	lines.append(str(trait_data.get("name", trait_id.capitalize())))
	lines.append(str(trait_data.get("description", "")))
	for threshold in trait_data.get("thresholds", []):
		var count: String = str(threshold.get("count", 0))
		var label: String = str(threshold.get("label", count + " " + str(trait_data.get("name", trait_id.capitalize()))))
		lines.append("%s: %s" % [label, _format_threshold_effect(threshold)])
	return "\n".join(lines)


func _resolve_unit_ability(unit_data: Dictionary) -> Dictionary:
	var unit_id: String = str(unit_data.get("id", ""))
	var cost: int = int(unit_data.get("cost", 1))
	var mana: int = 60 + (cost - 1) * 10
	var cast_time: float = 0.30 + float(cost - 1) * 0.05

	match unit_id:
		"iron_guard":
			return _make_ability("Bulwark Slam", "shield_burst", 130, 60, 0.35, "self", 1, "Raise a shield and heal nearby allies.")
		"scout":
			return _make_ability("Pinning Shot", "line_blast", 110, 70, 0.35, "weakest_enemy", 0, "Fire a shot through the lane and slow the target.")
		"paladin":
			return _make_ability("Radiant Aegis", "heal_burst", 150, 70, 0.40, "lowest_ally", 1, "Heal the most wounded ally and splash healing nearby.")
		"elven_archer":
			return _make_ability("Piercing Volley", "line_blast", 120, 70, 0.35, "weakest_enemy", 0, "Loose a volley that cuts through the enemy line.")
		"elven_mage":
			return _make_ability("Lunar Burst", "splash_damage", 145, 80, 0.40, "weakest_enemy", 1, "Detonate a moonlit burst around the target.")
		"shadowblade":
			return _make_ability("Shadow Lunge", "execute_strike", 190, 60, 0.30, "weakest_enemy", 0, "Leap into the weakest enemy for a lethal strike.")
		"stone_breaker":
			return _make_ability("Forge Shield", "shield_burst", 115, 70, 0.40, "self", 1, "Harden your front line with a heavy shield.")
		"runesmith":
			return _make_ability("Rune Shatter", "splash_damage", 125, 80, 0.45, "weakest_enemy", 1, "Shatter runes in a burst that hits nearby enemies.")
		"bone_walker":
			return _make_ability("Grave Curse", "drain_damage", 100, 60, 0.35, "weakest_enemy", 0, "Curse the target and siphon life from the hit.")
		"soul_reaper":
			return _make_ability("Soul Drain", "drain_damage", 170, 80, 0.40, "weakest_enemy", 0, "Rip away the target's soul and heal yourself.")
		"flameling":
			return _make_ability("Ember Burst", "burn_burst", 125, 70, 0.35, "weakest_enemy", 1, "Ignite the target and scorch nearby foes.")
		"dragon_knight":
			return _make_ability("Dragon Roar", "splash_damage", 155, 90, 0.45, "weakest_enemy", 1, "Roar out a draconic shockwave.")
		"watchman":
			return _make_ability("Hold the Line", "shield_burst", 120, 60, 0.35, "self", 1, "Brace and rally nearby allies.")
		"storm_adept":
			return _make_ability("Static Chain", "chain_damage", 120, 70, 0.35, "weakest_enemy", 0, "Chain lightning jumps across the enemy backline.")
		"stone_bulwark":
			return _make_ability("Stone Guard", "shield_burst", 170, 80, 0.45, "self", 1, "Call a stone barrier that steadies allies nearby.")
		"grave_archer":
			return _make_ability("Grave Volley", "line_blast", 115, 70, 0.35, "weakest_enemy", 0, "Launch a volley that grinds through a lane.")
		"silver_paladin":
			return _make_ability("Sanctuary", "heal_burst", 180, 90, 0.45, "lowest_ally", 1, "Flood the battlefield with restorative light.")
		"ember_witch":
			return _make_ability("Magma Pulse", "burn_burst", 155, 90, 0.45, "weakest_enemy", 1, "Burst magma over the target and nearby enemies.")
		"crag_chief":
			return _make_ability("Crag Slam", "splash_damage", 120, 60, 0.35, "weakest_enemy", 1, "Smash the ground and crack nearby foes.")
		"ember_raider":
			return _make_ability("Blade Fever", "frenzy", 0.42, 60, 0.30, "self", 0, "Enter a feverish trance and attack faster.")
		"forge_shaman":
			return _make_ability("Cinder Totem", "burn_burst", 135, 70, 0.40, "weakest_enemy", 1, "Call a cinder totem that scorches the fight.")
		"siegebreaker":
			return _make_ability("Siege Wave", "line_blast", 160, 90, 0.45, "weakest_enemy", 0, "Roll a heavy wave through the entire lane.")
		"ash_duelist":
			return _make_ability("Smoke Cut", "execute_strike", 175, 70, 0.35, "weakest_enemy", 0, "Slip through the smoke and cut down the weakest foe.")
		"glade_sage":
			return _make_ability("Healing Bloom", "heal_burst", 160, 70, 0.40, "lowest_ally", 1, "Blooming magic heals the weakest allies nearby.")
		"lumen_ranger":
			return _make_ability("Prism Shot", "chain_damage", 125, 70, 0.35, "weakest_enemy", 0, "Fire a prism arrow that ricochets between targets.")
		"mirth_blade":
			return _make_ability("Gleeful Frenzy", "frenzy", 0.50, 60, 0.30, "self", 0, "Dance into a rapid flurry of attacks.")
		"thornwarden":
			return _make_ability("Thorn Bastion", "shield_burst", 145, 70, 0.40, "self", 1, "Wrap yourself and allies in thorned protection.")
		"moonweaver":
			return _make_ability("Moonfall", "splash_damage", 155, 80, 0.40, "weakest_enemy", 1, "Drop moonlight onto the enemy cluster.")
		"oak_sentinel":
			return _make_ability("Root Guard", "shield_burst", 170, 80, 0.45, "self", 1, "Root in place and guard the team with living bark.")
		"spellblade":
			return _make_ability("Arcane Rush", "chain_damage", 150, 70, 0.35, "weakest_enemy", 0, "Rush forward with a spell-charged finishing strike.")
		_:
			return _make_ability(
				"%s Burst" % str(unit_data.get("name", unit_id)),
				"chain_damage" if str(unit_data.get("trait", "")) in ["assassin", "duelist"] else "splash_damage",
				110 + cost * 10,
				mana,
				cast_time,
				"weakest_enemy",
				1,
				"Signature ability built from the unit's current archetype."
			)


func _make_ability(ability_name: String, effect: String, power: float, mana: int, cast_time: float, target: String, area_radius: int, description: String) -> Dictionary:
	return {
		"name": ability_name,
		"effect": effect,
		"power": power,
		"mana": mana,
		"cast_time": cast_time,
		"target": target,
		"radius": area_radius,
		"description": description
	}


func _infer_unit_role(unit_data: Dictionary) -> String:
	var stats: Dictionary = unit_data.get("stats", {})
	var trait_id: String = str(unit_data.get("trait", ""))
	var race_id: String = str(unit_data.get("race", ""))
	var ability: Dictionary = _resolve_unit_ability(unit_data)
	var effect: String = str(ability.get("effect", ""))
	var range: int = int(stats.get("attack_range", 0))
	var health: int = int(stats.get("health", 0))
	var damage: int = int(stats.get("attack_damage", 0))
	var attack_speed: float = float(stats.get("attack_speed", 0.0))
	var frontline_traits: Array[String] = ["knight", "vanguard", "guardian", "warrior", "bruiser"]
	var backline_traits: Array[String] = ["mage", "sorcerer", "ranger", "archer", "caster"]
	var skirmisher_traits: Array[String] = ["assassin", "duelist", "skirmisher"]
	var support_effects: Array[String] = ["heal_burst", "shield_burst"]
	var defensive_effects: Array[String] = ["shield_burst", "heal_burst", "damage_reflect_percent", "max_hp_flat", "armor_flat"]
	var offensive_effects: Array[String] = ["splash_damage", "line_blast", "chain_damage", "burn_burst", "drain_damage", "execute_strike"]
	if support_effects.has(effect):
		return "support"
	if skirmisher_traits.has(trait_id):
		return "skirmisher"
	if backline_traits.has(trait_id) or range >= 3:
		return "backline"
	if frontline_traits.has(trait_id) or health >= 700 or damage >= 70 or defensive_effects.has(effect):
		return "frontline"
	if offensive_effects.has(effect) or attack_speed >= 1.15:
		return "backline"
	if race_id in ["orc", "dwarf"] and health >= 600:
		return "frontline"
	return "balanced"


func _infer_item_role(item: Dictionary) -> String:
	var effect: String = str(item.get("effect", ""))
	var description: String = str(item.get("description", "")).to_lower()
	match effect:
		"attack_damage_flat", "attack_speed_flat", "lifesteal_percent", "damage_per_ally_percent", "damage_bonus_percent":
			return "offense"
		"armor_flat", "max_hp_flat", "damage_reflect_percent", "revive_once", "team_shield_percent":
			return "defense"
		"attack_slow_on_hit":
			return "tempo"
		_:
			pass
	if "mana" in description or "heal" in description or "shield" in description:
		return "utility"
	if "burn" in description or "ricochet" in description or "splash" in description or "chain" in description:
		return "tempo"
	return "utility"


func _format_threshold_effect(threshold: Dictionary) -> String:
	var effect: String = str(threshold.get("effect", ""))
	var value: Variant = threshold.get("value", 0)
	match effect:
		"gold_per_round":
			return "+%s gold per round" % str(value)
		"attack_speed_bonus":
			return "+%s%% attack speed" % str(int(round(float(value) * 100.0)))
		"armor_bonus_percent":
			return "+%s%% armor" % str(int(round(float(value) * 100.0)))
		"max_hp_bonus_percent":
			return "+%s%% max HP" % str(int(round(float(value) * 100.0)))
		"damage_bonus_percent":
			return "+%s%% damage" % str(int(round(float(value) * 100.0)))
		"attack_range_bonus":
			return "+%s range" % str(value)
		"team_shield_percent":
			return "Shield allies for %s%% max HP" % str(int(round(float(value) * 100.0)))
		"revive_once":
			return "Revive once at %s%% HP" % str(int(round(float(value) * 100.0)))
		"burn_on_hit":
			return "Burn for %s DPS" % str(value)
		"leap_to_weakest":
			return "Leap to the weakest enemy"
		_:
			return str(effect).replace("_", " ").capitalize()


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("DataManager: could not open %s" % path)
		return {}
	var text: String = file.get_as_text()
	file.close()
	var result: Variant = JSON.parse_string(text)
	if result == null:
		push_error("DataManager: failed to parse %s" % path)
		return {}
	return result
