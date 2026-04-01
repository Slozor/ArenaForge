extends Node

class_name GameLoop

const MAIN_MENU_SCENE: String = "res://scenes/main_menu.tscn"

enum Phase { PREPARATION, COMBAT, RESULT }

const TOTAL_ROUNDS: int = 15
const PREP_TIME: float = 30.0
const COMBAT_TIMEOUT: float = 30.0

var current_phase: Phase = Phase.PREPARATION
var prep_timer: float = 0.0
var combat_timer: float = 0.0

var win_streak: int = 0
var loss_streak: int = 0

var board_ui = null
var bench_ui = null
var hud_ui = null
var shop_ui = null
var combat_controller = null
var enemy_spawner = null
var enemy_units: Array = []
var current_round_data: Dictionary = {}
var current_round_kind: String = "creep"
var current_opponent_index: int = 0
var current_opponent_profile: Dictionary = {}
var opponent_lobby: Array = []
var _player_prep_positions: Dictionary = {}
var _loot_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _pending_reward_choices: Dictionary = {}
var _special_reward_claimed: bool = false
var _pending_late_game_reward: bool = false

signal phase_changed(phase: Phase)
signal prep_timer_updated(seconds_left: float)
signal combat_finished(player_won: bool)
signal game_over()
signal round_context_changed(round_data: Dictionary, opponent_profile: Dictionary, lobby: Array, opponent_index: int)


func _ready() -> void:
	_loot_rng.randomize()
	board_ui = get_node_or_null("BoardUI")
	bench_ui = get_node_or_null("BenchUI")
	hud_ui = get_node_or_null("HudUI")
	shop_ui = get_node_or_null("ShopUI")

	combat_controller = CombatController.new()
	combat_controller.name = "CombatController"
	add_child(combat_controller)
	combat_controller.combat_ended.connect(on_combat_ended)
	combat_controller.unit_moved.connect(_on_combat_unit_moved)

	enemy_spawner = EnemySpawner.new()
	enemy_spawner.name = "EnemySpawner"
	add_child(enemy_spawner)

	if board_ui != null:
		board_ui.unit_placed.connect(_on_board_changed)
		board_ui.unit_moved.connect(_on_board_changed)
		board_ui.unit_sent_to_bench.connect(_on_board_unit_sent_to_bench)
		board_ui.set_team_capacity(GameManager.get_team_size_cap())

	GameManager.level_changed.connect(_on_level_changed)
	GameManager.augment_choice_resolved.connect(_on_augment_choice_resolved)
	combat_finished.connect(_on_combat_finished)
	game_over.connect(_on_game_over)

	ShopManager.reset_for_new_game()
	GameManager.start_new_game()
	opponent_lobby = _build_opponent_lobby()
	_refresh_board_state()
	start_round(false)

	if hud_ui != null:
		if not hud_ui.skip_prep_pressed.is_connected(skip_prep):
			hud_ui.skip_prep_pressed.connect(skip_prep)
		hud_ui.restart_requested.connect(_restart_run)
		hud_ui.menu_requested.connect(_return_to_menu)
		if hud_ui.has_signal("selection_chosen"):
			hud_ui.selection_chosen.connect(_on_selection_chosen)


func start_round(grant_income: bool = true) -> void:
	_pending_late_game_reward = false
	if grant_income:
		_grant_round_income()
	_reset_player_units_for_preparation()
	_sync_round_context()
	ShopManager.refresh_shop()
	_enter_preparation()


func _enter_preparation() -> void:
	_reset_player_units_for_preparation()
	current_phase = Phase.PREPARATION
	prep_timer = PREP_TIME
	phase_changed.emit(Phase.PREPARATION)
	if hud_ui != null:
		hud_ui.set_skip_button_visible(true)


func _enter_combat() -> void:
	if not _is_battle_round():
		_resolve_special_round()
		return
	current_phase = Phase.COMBAT
	combat_timer = COMBAT_TIMEOUT
	phase_changed.emit(Phase.COMBAT)
	if hud_ui != null:
		hud_ui.set_skip_button_visible(false)
	_store_player_prep_positions()
	_prepare_player_units_for_combat()
	_spawn_enemy_team()
	_position_units_for_combat(_get_player_units())
	_position_units_for_combat(enemy_units)
	combat_controller.start(_get_player_units(), enemy_units, {"enemy": _build_combat_modifiers(current_opponent_profile)})
	_apply_synergies_to_board()


func _process(delta: float) -> void:
	match current_phase:
		Phase.PREPARATION:
			prep_timer -= delta
			prep_timer_updated.emit(maxf(prep_timer, 0.0))
			if prep_timer <= 0.0:
				_enter_combat()
		Phase.COMBAT:
			combat_timer -= delta
			if combat_timer <= 0.0:
				_resolve_combat_timeout()


func skip_prep() -> void:
	if current_phase == Phase.PREPARATION:
		if _is_battle_round():
			_enter_combat()
		else:
			_resolve_special_round()


func on_combat_ended(player_won: bool) -> void:
	if current_phase != Phase.COMBAT:
		return
	_restore_player_prep_positions()
	_reset_player_units_for_preparation()
	current_phase = Phase.RESULT
	phase_changed.emit(Phase.RESULT)

	if player_won:
		GameManager.record_round_win()
		win_streak += 1
		loss_streak = 0
		if GameManager.has_encounter("second_wind"):
			GameManager.player_health = mini(100, GameManager.player_health + 2)
			GameManager.health_changed.emit(GameManager.player_health)
	else:
		GameManager.record_round_loss()
		loss_streak += 1
		win_streak = 0
		var damage: int = _calculate_loss_damage()
		if damage > 0:
			GameManager.take_damage(damage)

	combat_finished.emit(player_won)
	if player_won and _round_uses_late_game_choice():
		GameManager.record_special_round_cleared()
		_pending_late_game_reward = true
		_offer_late_game_choice(current_round_data.get("reward", {}))
		return
	_grant_round_reward()

	if GameManager.player_health <= 0:
		_finish_run("eliminated")
		return

	if GameManager.current_round >= TOTAL_ROUNDS:
		_finish_run("victory")
		return

	GameManager.next_round()
	start_round()


func _resolve_combat_timeout() -> void:
	var player_count: int = _count_alive_units(_get_player_units())
	var enemy_count: int = _count_alive_units(enemy_units)
	on_combat_ended(player_count >= enemy_count)


func _apply_synergies_to_board() -> void:
	var player_units: Array = _get_player_units()
	var active := TraitSystem.get_active_synergies(player_units)
	TraitSystem.apply_synergies(player_units, active)
	_apply_augments_to_board(player_units)


func _grant_round_income() -> void:
	var human_bonus: int = _get_human_synergy_bonus()
	var income: Dictionary = Economy.calculate_round_income(
		GameManager.player_gold,
		win_streak,
		loss_streak,
		human_bonus
	)
	GameManager.add_gold(income.get("total", 0))
	if GameManager.has_augment("silver_spoon"):
		GameManager.add_gold(2)


func _resolve_special_round() -> void:
	_restore_player_prep_positions()
	_reset_player_units_for_preparation()
	current_phase = Phase.RESULT
	phase_changed.emit(Phase.RESULT)
	GameManager.record_special_round_cleared()
	_special_reward_claimed = false
	_pending_reward_choices.clear()
	var reward: Dictionary = current_round_data.get("reward", {})
	if current_round_kind == "draft":
		_offer_draft_choice(reward)
		return
	if current_round_kind == "armory":
		_offer_armory_choice(reward)
		return
	if current_round_kind == "loot":
		_offer_loot_choice(reward)
		return
	if bool(reward.get("augment_choice", false)):
		var options: Array[String] = DataManager.get_random_augments_for_round(GameManager.current_round, 3, GameManager.get_active_augments(), _loot_rng)
		if not options.is_empty():
			GameManager.offer_augment_choices(options)
			return
	_grant_round_reward()
	combat_finished.emit(true)
	_advance_round_or_finish("special")


func _grant_round_reward() -> void:
	if current_round_data.is_empty():
		return
	var reward: Dictionary = current_round_data.get("reward", {})
	var gold_reward: int = reward.get("gold", 0)
	if current_round_kind != "creep" and not _round_uses_late_game_choice():
		gold_reward += int(current_opponent_profile.get("reward_bonus_gold", 0))
	if gold_reward > 0:
		GameManager.add_gold(gold_reward)

	var item_ids: Array[String] = _roll_reward_items(reward)
	var granted_items: Array[String] = GameManager.grant_item_rewards(item_ids, _get_player_units())
	if hud_ui != null and not granted_items.is_empty() and hud_ui.has_method("show_item_rewards"):
		hud_ui.call("show_item_rewards", granted_items)


func _roll_reward_items(reward: Dictionary) -> Array[String]:
	var item_ids: Array[String] = []
	var explicit_items: Array = reward.get("items", [])
	if not explicit_items.is_empty():
		for item_id in explicit_items:
			item_ids.append(str(item_id))
		return item_ids

	var item_count: int = reward.get("item_count", 0)
	if item_count <= 0:
		return item_ids

	var item_mode: String = str(reward.get("item_mode", reward.get("item_category", "mixed")))
	var item_category: String = str(reward.get("item_category", ""))
	var category_filter: String = "" if item_category == "mixed" else item_category
	var full_item_chance: float = float(reward.get("full_item_chance", 0.0))
	var reward_roles: Array[String] = _get_item_reward_roles()
	var excluded: Array[String] = []

	for _i in item_count:
		var roll_mode: String = item_mode
		if item_mode == "mixed":
			roll_mode = "crafted" if _loot_rng.randf() < full_item_chance else "component"
		var preferred_role: String = reward_roles[min(_i, reward_roles.size() - 1)] if not reward_roles.is_empty() else "utility"
		var item_id: String = DataManager.get_random_item_for_role(preferred_role, category_filter, roll_mode, excluded, _loot_rng)
		if item_id == "":
			item_id = DataManager.get_random_item(category_filter, roll_mode, excluded, _loot_rng)
		if item_id == "":
			break
		item_ids.append(item_id)
		excluded.append(item_id)

	return item_ids


func _get_human_synergy_bonus() -> int:
	var human_count: int = 0
	for unit in _get_player_units():
		if unit.race == "human":
			human_count += 1
	if human_count >= 3:
		return 2
	elif human_count >= 2:
		return 1
	return 0


func _get_board_role_profile() -> Dictionary:
	var profile: Dictionary = {
		"frontline": 0,
		"backline": 0,
		"support": 0,
		"skirmisher": 0,
		"balanced": 0
	}
	for unit in _get_player_units():
		if unit == null:
			continue
		var role: String = DataManager.get_unit_role(str(unit.unit_id))
		profile[role] = int(profile.get(role, 0)) + 1
	return profile


func _get_item_reward_roles() -> Array[String]:
	var profile: Dictionary = _get_board_role_profile()
	var frontline: int = int(profile.get("frontline", 0))
	var backline: int = int(profile.get("backline", 0))
	var support: int = int(profile.get("support", 0))
	var skirmisher: int = int(profile.get("skirmisher", 0))
	var roles: Array[String] = []
	if frontline <= backline:
		roles.append("defense")
		roles.append("utility")
		roles.append("tempo")
		roles.append("offense")
	else:
		roles.append("offense")
		roles.append("tempo")
		roles.append("utility")
		roles.append("defense")
	if support <= 0:
		roles.append("utility")
	if skirmisher <= frontline:
		roles.append("tempo")
	roles.append("balanced")
	return _unique_string_array(roles)


func _get_draft_roles() -> Array[String]:
	var profile: Dictionary = _get_board_role_profile()
	var roles: Array[String] = []
	if int(profile.get("frontline", 0)) <= 0:
		roles.append("frontline")
	if int(profile.get("backline", 0)) <= 0:
		roles.append("backline")
	if int(profile.get("support", 0)) <= 0:
		roles.append("support")
	if int(profile.get("skirmisher", 0)) <= 0:
		roles.append("skirmisher")
	roles.append_array(["frontline", "backline", "support", "skirmisher", "balanced"])
	return _unique_string_array(roles)


func _unique_string_array(values: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		if value == "":
			continue
		if not result.has(value):
			result.append(value)
	return result


func _apply_augments_to_board(units: Array) -> void:
	for unit in units:
		if unit == null:
			continue
		if GameManager.has_augment("frontline_oath"):
			unit.max_health = int(round(float(unit.max_health) * 1.12))
			unit.current_health = unit.get_max_health()
		if GameManager.has_augment("battle_ready"):
			unit.current_health = mini(unit.get_max_health(), unit.current_health + int(round(float(unit.get_max_health()) * 0.10)))
		if GameManager.has_augment("rapid_fire"):
			unit.attack_speed += 0.18
		if GameManager.has_augment("heavy_blades"):
			unit.attack_damage = int(round(float(unit.attack_damage) * 1.15))
		if GameManager.has_augment("arcane_charge"):
			unit.gain_mana(20)
		if GameManager.has_augment("mana_surge"):
			unit.gain_mana(35)
		if GameManager.has_augment("stone_skin"):
			unit.armor += 12
		if GameManager.has_augment("bulwark_training"):
			unit.armor += 18
		unit.health_changed.emit(unit.current_health, unit.get_max_health())
		unit.queue_redraw()


func _calculate_loss_damage() -> int:
	var stage_base: int = 1 if current_round_kind == "creep" else 2
	if GameManager.current_round >= 14:
		stage_base = 5
	elif GameManager.current_round >= 11:
		stage_base = 4
	elif GameManager.current_round >= 8:
		stage_base = 3
	elif GameManager.current_round >= 5:
		stage_base = 3
	if current_round_kind == "elite":
		stage_base += 1
	elif current_round_kind == "boss":
		stage_base += 2
	var surviving_enemies: int = _count_alive_units(enemy_units)
	var survivor_bonus: int = maxi(1, int(ceil(float(surviving_enemies) * 0.5))) if surviving_enemies > 0 else 0
	return stage_base + survivor_bonus


func get_player_level() -> int:
	return GameManager.get_player_level()


func get_total_rounds() -> int:
	return TOTAL_ROUNDS


func _get_player_units() -> Array:
	if board_ui == null:
		return []
	return board_ui.get_all_placed_units()


func _count_alive_units(units: Array) -> int:
	return units.filter(func(unit): return int(unit.state) != 3).size()


func _refresh_board_state() -> void:
	if hud_ui != null:
		hud_ui.update_synergies(_get_player_units())


func _on_board_changed(_unit, _a, _b = null) -> void:
	_refresh_board_state()


func _on_board_unit_sent_to_bench(_unit) -> void:
	_refresh_board_state()


func _on_level_changed(new_level: int) -> void:
	if board_ui != null:
		board_ui.set_team_capacity(GameManager.get_team_size_cap(new_level))
	_refresh_board_state()


func _spawn_enemy_team() -> void:
	_clear_enemy_units()
	enemy_units = enemy_spawner.spawn_enemy_team(GameManager.current_round, current_opponent_index, current_opponent_profile)
	if board_ui != null:
		for unit in enemy_units:
			if unit != null and is_instance_valid(unit) and unit.get_parent() != board_ui:
				unit.reparent(board_ui)


func _clear_enemy_units() -> void:
	for unit in enemy_units:
		if is_instance_valid(unit):
			unit.queue_free()
	enemy_units.clear()


func _sync_round_context() -> void:
	current_round_data = enemy_spawner.get_round_data(GameManager.current_round)
	current_round_kind = enemy_spawner.get_round_type(GameManager.current_round)
	current_opponent_index = _get_opponent_index(current_round_data)
	current_opponent_profile = _resolve_opponent_profile(current_round_data, current_opponent_index)
	var context_payload: Dictionary = current_round_data.duplicate(true)
	context_payload["preview_units"] = enemy_spawner.get_preview_units(GameManager.current_round, current_opponent_index)
	GameManager.set_round_kind(current_round_kind)
	round_context_changed.emit(context_payload, current_opponent_profile, opponent_lobby, current_opponent_index)


func _get_opponent_index(round_data: Dictionary) -> int:
	var opponents: Array = round_data.get("opponents", [])
	if opponents.is_empty():
		if str(round_data.get("profile_id", "")) != "" or opponent_lobby.is_empty():
			return 0
		return maxi(0, (GameManager.current_round - 1) % opponent_lobby.size())
	return (GameManager.current_round - 1) % opponents.size()


func _is_battle_round() -> bool:
	return current_round_kind == "combat" or current_round_kind == "creep" or current_round_kind == "npc" or current_round_kind == "elite" or current_round_kind == "boss"


func _round_uses_late_game_choice() -> bool:
	if current_round_data.is_empty():
		return false
	var reward: Dictionary = current_round_data.get("reward", {})
	return bool(reward.get("late_game_choice", false)) or current_round_kind == "elite" or current_round_kind == "boss"


func _resolve_opponent_profile(round_data: Dictionary, opponent_index: int) -> Dictionary:
	var round_profile_id: String = str(round_data.get("profile_id", ""))
	if round_profile_id != "":
		var round_profile: Dictionary = DataManager.get_opponent(round_profile_id)
		if not round_profile.is_empty():
			return round_profile
	var opponents: Array = round_data.get("opponents", [])
	if opponents.is_empty():
		if opponent_lobby.is_empty():
			return {}
		return opponent_lobby[clampi(opponent_index, 0, opponent_lobby.size() - 1)]
	var index: int = clampi(opponent_index, 0, opponents.size() - 1)
	var opponent_entry: Variant = opponents[index]
	if opponent_entry is Dictionary:
		var profile_id: String = str(opponent_entry.get("profile_id", ""))
		if profile_id != "":
			var profile: Dictionary = DataManager.get_opponent(profile_id)
			if not profile.is_empty():
				return profile
	if opponent_lobby.is_empty():
		return {}
	return opponent_lobby[clampi(opponent_index, 0, opponent_lobby.size() - 1)]


func _build_combat_modifiers(profile: Dictionary) -> Dictionary:
	var modifiers: Dictionary = profile.get("combat_modifiers", {}).duplicate(true)
	if modifiers.is_empty():
		var style: String = str(profile.get("style", ""))
		match style:
			"frontline", "bruiser":
				modifiers = {
					"health_mult": 1.10,
					"armor_bonus": 8
				}
			"burst", "mage":
				modifiers = {
					"starting_mana": 15,
					"cast_time_delta": -0.05
				}
			"assassin":
				modifiers = {
					"attack_damage_mult": 1.08,
					"attack_speed_bonus": 0.08
				}
			"tempo", "control":
				modifiers = {
					"starting_mana": 10,
					"attack_speed_bonus": 0.05,
					"armor_bonus": 4
				}
			"economy":
				modifiers = {
					"health_mult": 0.98,
					"attack_speed_bonus": 0.04
				}
			"boss":
				modifiers = {
					"health_mult": 1.20,
					"armor_bonus": 14,
					"starting_mana": 25,
					"attack_speed_bonus": 0.08,
					"cast_time_delta": -0.08
				}
	return modifiers


func _build_opponent_lobby() -> Array:
	var result: Array = []
	for opponent_id in DataManager.get_all_opponent_ids():
		var opponent: Dictionary = DataManager.get_opponent(opponent_id)
		if not opponent.is_empty():
			result.append(opponent)
	return result


func _advance_round_or_finish(reason: String) -> void:
	if GameManager.player_health <= 0:
		_finish_run(reason)
		return
	if GameManager.current_round >= TOTAL_ROUNDS:
		_finish_run(reason)
		return
	GameManager.next_round()
	start_round()


func _on_augment_choice_resolved(_augment_id: String) -> void:
	if current_phase != Phase.RESULT:
		return
	if _special_reward_claimed:
		_pending_late_game_reward = false
		advance_after_special_round(current_round_kind)
		return
	_grant_round_reward()
	combat_finished.emit(true)
	_advance_round_or_finish("augment")


func _offer_loot_choice(reward: Dictionary) -> void:
	_pending_reward_choices.clear()
	var options: Array[Dictionary] = []
	var used: Array[String] = []
	var reward_gold: int = int(reward.get("gold", 0))
	var reward_count: int = maxi(1, int(reward.get("item_count", 1)))
	var reward_mode: String = str(reward.get("item_mode", reward.get("item_category", "mixed")))
	var reward_category: String = str(reward.get("item_category", ""))
	var full_item_chance: float = float(reward.get("full_item_chance", 0.0))
	var reward_roles: Array[String] = _get_item_reward_roles()
	for index in 3:
		var item_ids: Array[String] = []
		var local_used: Array[String] = used.duplicate()
		for _i in reward_count:
			var roll_mode: String = reward_mode
			if reward_mode == "mixed":
				roll_mode = "crafted" if _loot_rng.randf() < full_item_chance else "component"
			var reward_role: String = reward_roles[min(index, reward_roles.size() - 1)] if not reward_roles.is_empty() else "utility"
			var item_id: String = DataManager.get_random_item_for_role(reward_role, "" if reward_category == "mixed" else reward_category, roll_mode, local_used, _loot_rng)
			if item_id == "":
				item_id = DataManager.get_random_item("" if reward_category == "mixed" else reward_category, roll_mode, local_used, _loot_rng)
			if item_id == "":
				break
			item_ids.append(item_id)
			local_used.append(item_id)
		if item_ids.is_empty():
			continue
		used.append_array(item_ids)
		var choice_id: String = "loot_%d" % index
		options.append({
			"id": choice_id,
			"kind": "loot_reward",
			"name": "%s Cache + %d Gold" % [reward_roles[min(index, reward_roles.size() - 1)].capitalize() if not reward_roles.is_empty() else "Utility", reward_gold],
			"description": _format_reward_choice_description(item_ids, reward_gold)
		})
		_pending_reward_choices[choice_id] = {
			"items": item_ids,
			"gold": reward_gold,
			"follow_up_augment": bool(reward.get("augment_choice", false))
		}
	if hud_ui != null and hud_ui.has_method("show_reward_choices"):
		hud_ui.show_reward_choices("Choose Your Loot", options)


func _offer_armory_choice(reward: Dictionary) -> void:
	_pending_reward_choices.clear()
	var options: Array[Dictionary] = []
	var mode: String = str(reward.get("armory_mode", "component_plus"))
	var used_items: Array[String] = []
	var reward_roles: Array[String] = _get_item_reward_roles()
	for index in 3:
		var choice_id: String = "armory_%d" % index
		var payload: Dictionary = {}
		var role: String = reward_roles[min(index, reward_roles.size() - 1)] if not reward_roles.is_empty() else "utility"
		payload = _build_armory_payload(mode, used_items, role)
		if payload.is_empty():
			continue
		var item_ids: Array[String] = payload.get("items", [])
		used_items.append_array(item_ids)
		payload["gold"] = int(reward.get("gold", 0))
		payload["follow_up_augment"] = bool(reward.get("augment_choice", false))
		_pending_reward_choices[choice_id] = payload
		options.append({
			"id": choice_id,
			"kind": "loot_reward",
			"name": str(payload.get("title", "Armory Choice")),
			"description": _format_reward_choice_description(item_ids, int(payload.get("gold", 0)))
		})
	if hud_ui != null and hud_ui.has_method("show_reward_choices"):
		hud_ui.show_reward_choices("Choose an Armory Reward", options)


func _offer_late_game_choice(reward: Dictionary) -> void:
	_pending_reward_choices.clear()
	var options: Array[Dictionary] = []
	var role_profile: Dictionary = _get_board_role_profile()
	var strongest_role: String = "utility"
	var strongest_value: int = -1
	for role_name in ["frontline", "backline", "support", "skirmisher", "balanced"]:
		var role_value: int = int(role_profile.get(role_name, 0))
		if role_value > strongest_value:
			strongest_value = role_value
			strongest_role = role_name
	var role_choices: Array[Dictionary] = [
		{
			"id": "late_offense",
			"title": "%s Forge" % strongest_role.capitalize(),
			"role": "offense",
			"mode": "champion_armory",
			"gold": 6,
			"follow_up_augment": false
		},
		{
			"id": "late_defense",
			"title": "%s Bastion" % strongest_role.capitalize(),
			"role": "defense",
			"mode": "crafted_plus",
			"gold": 6,
			"follow_up_augment": false
		},
		{
			"id": "late_utility",
			"title": "%s Insight" % strongest_role.capitalize(),
			"role": "utility",
			"mode": "mixed",
			"gold": 4,
			"follow_up_augment": true
		}
	]
	for choice in role_choices:
		var payload: Dictionary = _build_armory_payload(str(choice.get("mode", "mixed")), [], str(choice.get("role", "utility")))
		if payload.is_empty():
			continue
		var item_ids: Array[String] = payload.get("items", [])
		if item_ids.is_empty():
			continue
		payload["gold"] = int(choice.get("gold", 0)) + int(reward.get("gold", 0))
		payload["follow_up_augment"] = bool(choice.get("follow_up_augment", false))
		payload["title"] = str(choice.get("title", "Late Reward"))
		payload["advance_after_choice"] = true
		var choice_id: String = str(choice.get("id", "late_reward"))
		options.append({
			"id": choice_id,
			"kind": "loot_reward",
			"name": str(payload.get("title", "Late Reward")),
			"description": _format_reward_choice_description(item_ids, int(payload.get("gold", 0)))
		})
		_pending_reward_choices[choice_id] = payload
	if hud_ui != null and hud_ui.has_method("show_reward_choices"):
		var title: String = "Choose Your Spoils"
		if current_round_kind == "boss":
			title = "Boss Spoils"
		elif current_round_kind == "elite":
			title = "Elite Spoils"
		hud_ui.show_reward_choices(title, options)


func _offer_draft_choice(reward: Dictionary) -> void:
	_pending_reward_choices.clear()
	if bool(reward.get("draft_units", false)):
		_offer_unit_draft_choice(reward)
		return
	var options: Array[Dictionary] = []
	var used: Array[String] = []
	var reward_roles: Array[String] = _get_item_reward_roles()
	for explicit in reward.get("items", []):
		var item_id: String = str(explicit)
		if item_id == "" or used.has(item_id):
			continue
		used.append(item_id)
		var item_data: Dictionary = DataManager.get_item(item_id)
		options.append({
			"id": item_id,
			"kind": "draft_reward",
			"name": str(item_data.get("name", item_id)),
			"description": DataManager.get_item_tooltip(item_id)
		})
	while options.size() < 3:
		var reward_role: String = reward_roles[min(options.size(), reward_roles.size() - 1)] if not reward_roles.is_empty() else "utility"
		var rolled_id: String = DataManager.get_random_item_for_role(reward_role, "", "crafted", used, _loot_rng)
		if rolled_id == "":
			rolled_id = DataManager.get_random_item("", "crafted", used, _loot_rng)
		if rolled_id == "":
			break
		used.append(rolled_id)
		options.append({
			"id": rolled_id,
			"kind": "draft_reward",
			"name": "%s Cache" % reward_role.capitalize(),
			"description": DataManager.get_item_tooltip(rolled_id)
		})
	for option in options:
		_pending_reward_choices[str(option.get("id", ""))] = {
			"items": [str(option.get("id", ""))],
			"gold": int(reward.get("gold", 0)),
			"follow_up_augment": bool(reward.get("augment_choice", false))
		}
	if hud_ui != null and hud_ui.has_method("show_reward_choices"):
		hud_ui.show_reward_choices("Choose a Draft Reward", options)


func _offer_unit_draft_choice(reward: Dictionary) -> void:
	var options: Array[Dictionary] = []
	var used: Array[String] = []
	var draft_costs: Array = reward.get("draft_costs", [2, 2, 3])
	var draft_roles: Array[String] = _get_draft_roles()
	for index in draft_costs.size():
		var preferred_role: String = draft_roles[min(index, draft_roles.size() - 1)] if not draft_roles.is_empty() else "balanced"
		var unit_id: String = _choose_draft_unit(int(draft_costs[index]), preferred_role, used)
		if unit_id == "":
			continue
		used.append(unit_id)
		var unit_data: Dictionary = DataManager.get_unit(unit_id)
		var choice_id: String = "draft_unit_%d" % index
		options.append({
			"id": choice_id,
			"kind": "draft_reward",
			"name": "%s Recruit" % str(unit_data.get("name", unit_id)),
			"description": _format_unit_draft_description(unit_data)
		})
		_pending_reward_choices[choice_id] = {
			"unit_id": unit_id,
			"gold": int(reward.get("gold", 0)),
			"follow_up_augment": bool(reward.get("augment_choice", false))
		}
	if hud_ui != null and hud_ui.has_method("show_reward_choices"):
		hud_ui.show_reward_choices("Choose a Recruit", options)


func _build_armory_payload(mode: String, excluded_items: Array[String], role: String = "utility") -> Dictionary:
	var payload: Dictionary = {}
	match mode:
		"crafted_plus", "champion_armory":
			var crafted_id: String = DataManager.get_random_item_for_role(role, "", "crafted", excluded_items, _loot_rng)
			if crafted_id == "":
				crafted_id = DataManager.get_random_item("", "crafted", excluded_items, _loot_rng)
			var component_id: String = DataManager.get_random_item_for_role(role, "", "component", excluded_items, _loot_rng)
			if component_id == "":
				component_id = DataManager.get_random_item("", "component", excluded_items, _loot_rng)
			if crafted_id == "":
				return {}
			var items: Array[String] = [crafted_id]
			if component_id != "":
				items.append(component_id)
			payload["items"] = items
			payload["title"] = "%s Package" % role.capitalize()
		"component_plus":
			var first_component: String = DataManager.get_random_item_for_role(role, "", "component", excluded_items, _loot_rng)
			if first_component == "":
				first_component = DataManager.get_random_item("", "component", excluded_items, _loot_rng)
			if first_component == "":
				return {}
			var local_excluded: Array[String] = excluded_items.duplicate()
			local_excluded.append(first_component)
			var second_component: String = DataManager.get_random_item_for_role(role, "", "component", local_excluded, _loot_rng)
			if second_component == "":
				second_component = DataManager.get_random_item("", "component", local_excluded, _loot_rng)
			var items: Array[String] = [first_component]
			if second_component != "":
				items.append(second_component)
			payload["items"] = items
			payload["title"] = "%s Components" % role.capitalize()
		_:
			var mixed_item: String = DataManager.get_random_item_for_role(role, "", "mixed", excluded_items, _loot_rng)
			if mixed_item == "":
				mixed_item = DataManager.get_random_item("", "mixed", excluded_items, _loot_rng)
			if mixed_item == "":
				return {}
			payload["items"] = [mixed_item]
			payload["title"] = "%s Armory" % role.capitalize()
	return payload


func _choose_draft_unit(cost: int, role: String, excluded: Array[String]) -> String:
	var unit_id: String = DataManager.get_random_unit_for_role(role, cost, excluded, _loot_rng)
	if unit_id == "":
		unit_id = _roll_draft_unit(cost, excluded)
	return unit_id


func _armory_theme_pool(theme: String, excluded_items: Array[String]) -> Array[String]:
	var pools: Dictionary = {
		"offense": [
			"forged_blade", "blazing_edge", "storm_lance", "rage_crown",
			"vampiric_blade", "archmage_foci"
		],
		"defense": [
			"reinforced_mail", "giant_core", "elder_core", "bastion_mail",
			"sunforged_plate", "heartward_talisman", "thornmail", "iron_cloak"
		],
		"tempo": [
			"storm_bow", "gale_serum", "phantom_quiver", "frozen_heart"
		]
	}
	var result: Array[String] = []
	for item_id in pools.get(theme, []):
		var resolved_id: String = str(item_id)
		if excluded_items.has(resolved_id):
			continue
		if DataManager.get_item(resolved_id).is_empty():
			continue
		result.append(resolved_id)
	return result


func _on_selection_chosen(kind: String, choice_id: String) -> void:
	if kind != "draft_reward" and kind != "loot_reward":
		return
	if not _pending_reward_choices.has(choice_id):
		return
	var payload: Dictionary = _pending_reward_choices.get(choice_id, {})
	var gold_reward: int = int(payload.get("gold", 0))
	if gold_reward > 0:
		GameManager.add_gold(gold_reward)
	var granted_items: Array[String] = GameManager.grant_item_rewards(payload.get("items", []), _get_player_units())
	var recruited_unit_id: String = str(payload.get("unit_id", ""))
	if recruited_unit_id != "":
		_grant_reward_unit(recruited_unit_id)
	_special_reward_claimed = true
	if hud_ui != null and hud_ui.has_method("show_item_rewards"):
		hud_ui.show_item_rewards(granted_items)
	_pending_reward_choices.clear()
	if bool(payload.get("follow_up_augment", false)):
		var options: Array[String] = DataManager.get_random_augments_for_round(GameManager.current_round, 3, GameManager.get_active_augments(), _loot_rng)
		if not options.is_empty():
			GameManager.offer_augment_choices(options)
			return
	if not _pending_late_game_reward:
		combat_finished.emit(true)
	else:
		_pending_late_game_reward = false
	advance_after_special_round(kind)


func _grant_reward_unit(unit_id: String) -> void:
	if unit_id == "" or bench_ui == null:
		return
	if bench_ui.has_method("can_accept_purchase") and not bool(bench_ui.call("can_accept_purchase", unit_id)):
		var unit_data: Dictionary = DataManager.get_unit(unit_id)
		var fallback_value: int = maxi(2, int(unit_data.get("cost", 1)) + 1)
		GameManager.add_gold(fallback_value)
		if hud_ui != null and hud_ui.has_method("show_item_rewards"):
			hud_ui.show_item_rewards([])
			hud_ui.show_inspect_text("Bench full. Converted %s into %d gold." % [str(unit_data.get("name", unit_id)), fallback_value])
		return
	bench_ui.call("add_unit_from_shop", unit_id)


func _roll_draft_unit(cost: int, excluded: Array[String]) -> String:
	var candidates: Array = DataManager.get_units_by_cost(cost)
	var pool: Array[String] = []
	for candidate in candidates:
		var unit_id: String = str(candidate)
		if excluded.has(unit_id):
			continue
		pool.append(unit_id)
	if pool.is_empty():
		for candidate in DataManager.get_all_unit_ids():
			var fallback_id: String = str(candidate)
			if excluded.has(fallback_id):
				continue
			pool.append(fallback_id)
	if pool.is_empty():
		return ""
	return pool[_loot_rng.randi_range(0, pool.size() - 1)]


func advance_after_special_round(reason: String) -> void:
	_advance_round_or_finish(reason)


func _format_reward_choice_description(item_ids: Array[String], gold_reward: int) -> String:
	var parts: Array[String] = []
	if gold_reward > 0:
		parts.append("+%d Gold" % gold_reward)
	for item_id in item_ids:
		var item_data: Dictionary = DataManager.get_item(item_id)
		parts.append("%s: %s" % [str(item_data.get("name", item_id)), str(item_data.get("description", ""))])
	return "\n".join(parts)


func _format_unit_draft_description(unit_data: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("%s %s" % [str(unit_data.get("race", "")).capitalize(), str(unit_data.get("trait", "")).capitalize()])
	lines.append("%d-cost recruit" % int(unit_data.get("cost", 1)))
	lines.append("Role: %s" % DataManager.get_unit_role(str(unit_data.get("id", ""))).capitalize())
	var stats: Dictionary = unit_data.get("stats", {})
	lines.append("%d HP  %d AD  %s AS" % [
		int(stats.get("health", 0)),
		int(stats.get("attack_damage", 0)),
		str(stats.get("attack_speed", 0.0))
	])
	return "\n".join(lines)


func _finish_run(reason: String) -> void:
	var placement: int = _calculate_run_placement(reason)
	GameManager.register_run_result(placement, reason)
	GameManager.change_state(GameManager.GameState.GAME_OVER)
	game_over.emit()


func _calculate_run_placement(reason: String) -> int:
	if reason == "victory" or GameManager.current_round >= TOTAL_ROUNDS:
		return 1
	var progress_ratio: float = clampf(float(GameManager.current_round) / float(TOTAL_ROUNDS), 0.0, 1.0)
	var placement: int = 8 - int(floor(progress_ratio * 7.0))
	return clampi(placement, 2, 8)


func _on_combat_finished(player_won: bool) -> void:
	if hud_ui != null:
		hud_ui.show_round_result(player_won, current_round_kind)


func _on_game_over() -> void:
	if hud_ui != null:
		hud_ui.set_skip_button_visible(false)


func _restart_run() -> void:
	get_tree().reload_current_scene()


func _return_to_menu() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _store_player_prep_positions() -> void:
	_player_prep_positions.clear()
	for unit in _get_player_units():
		_player_prep_positions[unit.get_instance_id()] = unit.board_position


func _restore_player_prep_positions() -> void:
	if board_ui == null:
		return
	for unit in _get_player_units():
		var instance_id: int = unit.get_instance_id()
		if not _player_prep_positions.has(instance_id):
			continue
		var prep_pos: Vector2i = _player_prep_positions[instance_id]
		unit.board_position = prep_pos
		unit.visible = true
		unit.position = board_ui.cell_to_world(prep_pos.x, prep_pos.y)
	_player_prep_positions.clear()


func _reset_player_units_for_preparation() -> void:
	if board_ui == null:
		return
	for unit in _get_player_units():
		if unit == null:
			continue
		var instance_id: int = unit.get_instance_id()
		if _player_prep_positions.has(instance_id):
			unit.board_position = _player_prep_positions[instance_id]
		elif unit.board_position.y >= 4:
			unit.board_position = Vector2i(unit.board_position.x, unit.board_position.y - 4)
		unit.is_enemy_unit = false
		unit.visible = true
		unit.reset_combat_state()
		unit.position = board_ui.cell_to_world(unit.board_position.x, unit.board_position.y)
	if board_ui.has_method("refresh_all_unit_positions"):
		board_ui.refresh_all_unit_positions()


func _prepare_player_units_for_combat() -> void:
	for unit in _get_player_units():
		unit.is_enemy_unit = false
		unit.board_position = Vector2i(unit.board_position.x, unit.board_position.y + 4)
		unit.visible = true


func _position_units_for_combat(units: Array) -> void:
	if board_ui == null:
		return
	for unit in units:
		unit.position = board_ui.combat_cell_to_world(unit.board_position.x, unit.board_position.y)


func _on_combat_unit_moved(unit, to: Vector2i) -> void:
	if board_ui == null or unit == null:
		return
	unit.position = board_ui.combat_cell_to_world(to.x, to.y)
	unit.queue_redraw()
