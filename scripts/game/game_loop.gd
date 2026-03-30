extends Node

class_name GameLoop

const MAIN_MENU_SCENE: String = "res://scenes/main_menu.tscn"

enum Phase { PREPARATION, COMBAT, RESULT }

const TOTAL_ROUNDS: int = 12
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
var current_round_kind: String = "combat"
var current_opponent_index: int = 0
var _player_prep_positions: Dictionary = {}

signal phase_changed(phase: Phase)
signal prep_timer_updated(seconds_left: float)
signal combat_finished(player_won: bool)
signal game_over()


func _ready() -> void:
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
	combat_finished.connect(_on_combat_finished)
	game_over.connect(_on_game_over)

	ShopManager.reset_for_new_game()
	GameManager.start_new_game()
	_refresh_board_state()
	start_round(false)

	if hud_ui != null:
		hud_ui.restart_requested.connect(_restart_run)
		hud_ui.menu_requested.connect(_return_to_menu)


func start_round(grant_income: bool = true) -> void:
	if grant_income:
		_grant_round_income()
	_sync_round_context()
	ShopManager.refresh_shop()
	_enter_preparation()


func _enter_preparation() -> void:
	current_phase = Phase.PREPARATION
	prep_timer = PREP_TIME
	phase_changed.emit(Phase.PREPARATION)
	if hud_ui != null:
		hud_ui.set_skip_button_visible(true)


func _enter_combat() -> void:
	if current_round_kind != "combat":
		_resolve_special_round()
		return
	current_phase = Phase.COMBAT
	combat_timer = COMBAT_TIMEOUT
	phase_changed.emit(Phase.COMBAT)
	if hud_ui != null:
		hud_ui.set_skip_button_visible(false)
	_store_player_prep_positions()
	_apply_synergies_to_board()
	_spawn_enemy_team()
	_position_units_for_combat(_get_player_units())
	_position_units_for_combat(enemy_units)
	combat_controller.start(_get_player_units(), enemy_units)


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
		if current_round_kind == "combat":
			_enter_combat()
		else:
			_resolve_special_round()


func on_combat_ended(player_won: bool) -> void:
	if current_phase != Phase.COMBAT:
		return
	_restore_player_prep_positions()
	current_phase = Phase.RESULT
	phase_changed.emit(Phase.RESULT)

	if player_won:
		win_streak += 1
		loss_streak = 0
	else:
		loss_streak += 1
		win_streak = 0
		var damage: int = _calculate_loss_damage()
		GameManager.take_damage(damage)

	combat_finished.emit(player_won)
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


func _grant_round_income() -> void:
	var human_bonus: int = _get_human_synergy_bonus()
	var income: Dictionary = Economy.calculate_round_income(
		GameManager.player_gold,
		win_streak,
		loss_streak,
		human_bonus
	)
	GameManager.add_gold(income.get("total", 0))


func _resolve_special_round() -> void:
	_restore_player_prep_positions()
	current_phase = Phase.RESULT
	phase_changed.emit(Phase.RESULT)
	_grant_round_reward()
	combat_finished.emit(true)
	_advance_round_or_finish("special")


func _grant_round_reward() -> void:
	if current_round_data.is_empty():
		return
	var reward: Dictionary = current_round_data.get("reward", {})
	var gold_reward: int = reward.get("gold", 0)
	if gold_reward > 0:
		GameManager.add_gold(gold_reward)

	var item_ids: Array = reward.get("items", [])
	if item_ids.is_empty():
		var item_count: int = reward.get("item_count", 0)
		var item_category: String = reward.get("item_category", "")
		if item_count > 0:
			item_ids = DataManager.get_random_items(item_count, item_category)
	GameManager.grant_item_rewards(item_ids, _get_player_units())


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


func _calculate_loss_damage() -> int:
	return 2 + _count_alive_units(enemy_units)


func get_player_level() -> int:
	return GameManager.get_player_level()


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
	enemy_units = enemy_spawner.spawn_enemy_team(GameManager.current_round, current_opponent_index)


func _clear_enemy_units() -> void:
	for unit in enemy_units:
		if is_instance_valid(unit):
			unit.queue_free()
	enemy_units.clear()


func _sync_round_context() -> void:
	current_round_data = enemy_spawner.get_round_data(GameManager.current_round)
	current_round_kind = enemy_spawner.get_round_type(GameManager.current_round)
	current_opponent_index = _get_opponent_index(current_round_data)
	GameManager.set_round_kind(current_round_kind)


func _get_opponent_index(round_data: Dictionary) -> int:
	var opponents: Array = round_data.get("opponents", [])
	if opponents.is_empty():
		return 0
	return (GameManager.current_round - 1) % opponents.size()


func _advance_round_or_finish(reason: String) -> void:
	if GameManager.player_health <= 0:
		_finish_run(reason)
		return
	if GameManager.current_round >= TOTAL_ROUNDS:
		_finish_run(reason)
		return
	GameManager.next_round()
	start_round()


func _finish_run(reason: String) -> void:
	var placement: int = maxi(1, TOTAL_ROUNDS - GameManager.current_round + 1)
	GameManager.register_run_result(placement, reason)
	GameManager.change_state(GameManager.GameState.GAME_OVER)
	game_over.emit()


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
		unit.position = board_ui.cell_to_world(prep_pos.x, prep_pos.y)
	_player_prep_positions.clear()


func _position_units_for_combat(units: Array) -> void:
	if board_ui == null:
		return
	for unit in units:
		unit.position = board_ui.combat_cell_to_world(unit.board_position.x, unit.board_position.y)


func _on_combat_unit_moved(unit, to: Vector2i) -> void:
	if board_ui == null or unit == null:
		return
	unit.position = board_ui.combat_cell_to_world(to.x, to.y)
