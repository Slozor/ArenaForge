extends Node

# Game states
enum GameState {
	MAIN_MENU,
	PREPARATION,
	BATTLE,
	GAME_OVER
}

const MAX_LEVEL: int = 10
const XP_PER_BUY: int = 4
const MAX_INVENTORY_ITEMS: int = 10
const STAR_MERGE_REQUIREMENTS: Dictionary = {
	1: 3,
	2: 3
}

# XP needed to advance from the current level to the next one.
const XP_TO_NEXT_LEVEL: Dictionary = {
	1: 2,
	2: 4,
	3: 6,
	4: 10,
	5: 12,
	6: 16,
	7: 20,
	8: 24,
	9: 28
}

# Team size / board cap by level.
const TEAM_SIZE_CAPS: Dictionary = {
	1: 3,
	2: 3,
	3: 4,
	4: 5,
	5: 6,
	6: 7,
	7: 8,
	8: 9,
	9: 10,
	10: 10
}

var current_state: GameState = GameState.MAIN_MENU
var player_gold: int = 0
var player_health: int = 100
var player_xp: int = 0
var player_level: int = 1
var current_round: int = 0
var current_round_kind: String = "combat"
var item_inventory: Array[String] = []
var final_placement: int = 0
var run_summary: Dictionary = {}

signal state_changed(new_state: GameState)
signal gold_changed(new_amount: int)
signal health_changed(new_amount: int)
signal round_changed(new_round: int)
signal xp_changed(new_xp: int, xp_to_next: int)
signal level_changed(new_level: int)
signal team_cap_changed(new_cap: int)
signal round_kind_changed(round_kind: String)
signal inventory_changed(items: Array[String])
signal run_finished(summary: Dictionary)


func change_state(new_state: GameState) -> void:
	current_state = new_state
	state_changed.emit(new_state)


func add_gold(amount: int) -> void:
	if amount <= 0:
		return
	player_gold += amount
	gold_changed.emit(player_gold)


func spend_gold(amount: int) -> bool:
	if player_gold < amount:
		return false
	player_gold -= amount
	gold_changed.emit(player_gold)
	return true


func add_xp(amount: int) -> int:
	if amount <= 0 or is_max_level():
		return 0

	var gained_levels: int = 0
	player_xp += amount

	while not is_max_level():
		var needed: int = get_xp_to_next_level()
		if player_xp < needed:
			break
		player_xp -= needed
		player_level += 1
		gained_levels += 1
		level_changed.emit(player_level)
		team_cap_changed.emit(get_team_size_cap())

	if is_max_level():
		player_xp = 0

	xp_changed.emit(player_xp, get_xp_to_next_level())
	return gained_levels


func get_merge_requirement(star_level: int) -> int:
	return STAR_MERGE_REQUIREMENTS.get(star_level, 0)


func can_buy_xp() -> bool:
	return not is_max_level()


func is_max_level() -> bool:
	return player_level >= MAX_LEVEL


func get_player_level() -> int:
	return player_level


func get_player_xp() -> int:
	return player_xp


func set_round_kind(round_kind: String) -> void:
	if current_round_kind == round_kind:
		return
	current_round_kind = round_kind
	round_kind_changed.emit(current_round_kind)


func get_round_kind() -> String:
	return current_round_kind


func get_xp_to_next_level(level: int = -1) -> int:
	var resolved_level: int = player_level if level == -1 else clampi(level, 1, MAX_LEVEL)
	if resolved_level >= MAX_LEVEL:
		return 0
	return XP_TO_NEXT_LEVEL.get(resolved_level, XP_TO_NEXT_LEVEL[9])


func get_team_size_cap(level: int = -1) -> int:
	var resolved_level: int = player_level if level == -1 else clampi(level, 1, MAX_LEVEL)
	return TEAM_SIZE_CAPS.get(resolved_level, TEAM_SIZE_CAPS[MAX_LEVEL])


func can_field_more_units(unit_count: int, level: int = -1) -> bool:
	return unit_count < get_team_size_cap(level)


func get_item_inventory() -> Array[String]:
	return item_inventory.duplicate()


func get_item_inventory_size() -> int:
	return item_inventory.size()


func can_store_item() -> bool:
	return item_inventory.size() < MAX_INVENTORY_ITEMS


func add_item_to_inventory(item_id: String) -> bool:
	if item_id == "" or DataManager.get_item(item_id).is_empty():
		return false
	if not can_store_item():
		return false
	item_inventory.append(item_id)
	inventory_changed.emit(item_inventory)
	return true


func add_items_to_inventory(item_ids: Array) -> Array[String]:
	var added: Array[String] = []
	for item_id in item_ids:
		if add_item_to_inventory(str(item_id)):
			added.append(str(item_id))
	return added


func remove_item_from_inventory(index: int) -> String:
	if index < 0 or index >= item_inventory.size():
		return ""
	var item_id: String = item_inventory[index]
	item_inventory.remove_at(index)
	inventory_changed.emit(item_inventory)
	return item_id


func equip_inventory_item_to_unit(index: int, unit) -> bool:
	if unit == null or index < 0 or index >= item_inventory.size():
		return false
	if unit.equipped_item != "":
		return false
	var item_id: String = item_inventory[index]
	var item_data: Dictionary = DataManager.get_item(item_id)
	if item_data.is_empty():
		return false
	unit.equip_item(item_id, item_data)
	remove_item_from_inventory(index)
	return true


func craft_inventory_items(index_a: int, index_b: int) -> String:
	if index_a == index_b:
		return ""
	var first_index: int = maxi(index_a, index_b)
	var second_index: int = mini(index_a, index_b)
	if first_index >= item_inventory.size() or second_index < 0:
		return ""

	var result_item: String = DataManager.get_craft_result(
		item_inventory[index_a],
		item_inventory[index_b]
	)
	if result_item == "":
		return ""

	remove_item_from_inventory(first_index)
	remove_item_from_inventory(second_index)
	if not add_item_to_inventory(result_item):
		return ""
	inventory_changed.emit(item_inventory)
	return result_item


func grant_item_reward(item_id: String, units: Array = []) -> bool:
	if item_id == "":
		return false
	var item_data: Dictionary = DataManager.get_item(item_id)
	if item_data.is_empty():
		return false
	if item_data.get("auto_equip", false):
		var target = _select_reward_target(units)
		if target != null and target.equipped_item == "":
			target.equip_item(item_id, item_data)
			return true
	return add_item_to_inventory(item_id)


func grant_item_rewards(item_ids: Array, units: Array = []) -> Array[String]:
	var granted: Array[String] = []
	for item_id in item_ids:
		var resolved: String = str(item_id)
		if grant_item_reward(resolved, units):
			granted.append(resolved)
	return granted


func clear_inventory() -> void:
	item_inventory.clear()
	inventory_changed.emit(item_inventory)


func register_run_result(placement: int, reason: String = "") -> void:
	final_placement = max(1, placement)
	run_summary = {
		"placement": final_placement,
		"reason": reason,
		"round": current_round,
		"level": player_level,
		"gold": player_gold
	}
	run_finished.emit(run_summary)


func get_run_summary() -> Dictionary:
	return run_summary.duplicate(true)


func get_final_placement() -> int:
	return final_placement


func take_damage(amount: int) -> void:
	player_health -= amount
	health_changed.emit(player_health)
	if player_health <= 0:
		change_state(GameState.GAME_OVER)


func start_new_game() -> void:
	player_gold = 5
	player_health = 100
	player_xp = 0
	player_level = 1
	current_round = 1
	current_round_kind = "combat"
	final_placement = 0
	run_summary = {}
	item_inventory.clear()
	gold_changed.emit(player_gold)
	health_changed.emit(player_health)
	xp_changed.emit(player_xp, get_xp_to_next_level())
	level_changed.emit(player_level)
	team_cap_changed.emit(get_team_size_cap())
	round_kind_changed.emit(current_round_kind)
	inventory_changed.emit(item_inventory)
	round_changed.emit(current_round)
	change_state(GameState.PREPARATION)


func next_round() -> void:
	current_round += 1
	round_changed.emit(current_round)
	change_state(GameState.PREPARATION)


func _select_reward_target(units: Array):
	var best = null
	var best_score: int = -1
	for unit in units:
		if unit == null or int(unit.state) == 3:
			continue
		if unit.equipped_item != "":
			continue
		var score: int = unit.cost * 100 + unit.star_level * 25 + unit.get_attack_damage()
		if score > best_score:
			best_score = score
			best = unit
	return best
