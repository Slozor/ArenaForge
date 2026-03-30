extends Node

class_name GameLoop

enum Phase { PREPARATION, COMBAT, RESULT }

const TOTAL_ROUNDS: int = 12
const PREP_TIME: float = 30.0
const COMBAT_TIMEOUT: float = 30.0

var current_phase: Phase = Phase.PREPARATION
var prep_timer: float = 0.0
var combat_timer: float = 0.0

# Streak tracking
var win_streak: int = 0
var loss_streak: int = 0

# References set by game_scene
var board: Board = null
var shop_ui: Node = null

signal phase_changed(phase: Phase)
signal prep_timer_updated(seconds_left: float)
signal combat_finished(player_won: bool)
signal game_over()


func start_round() -> void:
	_grant_round_income()
	ShopManager.refresh_shop()
	_enter_preparation()


func _enter_preparation() -> void:
	current_phase = Phase.PREPARATION
	prep_timer = PREP_TIME
	phase_changed.emit(Phase.PREPARATION)


func _enter_combat() -> void:
	current_phase = Phase.COMBAT
	combat_timer = COMBAT_TIMEOUT
	phase_changed.emit(Phase.COMBAT)
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
		prep_timer = 0.0


func on_combat_ended(player_won: bool) -> void:
	if current_phase != Phase.COMBAT:
		return
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

	if GameManager.player_health <= 0:
		game_over.emit()
		return

	if GameManager.current_round >= TOTAL_ROUNDS:
		game_over.emit()
		return

	GameManager.next_round()
	start_round()


func _resolve_combat_timeout() -> void:
	# Sudden death: whoever has fewer surviving units loses
	var player_count: int = board.player_units.size()
	var enemy_count: int = board.enemy_units.size()
	on_combat_ended(player_count >= enemy_count)


func _apply_synergies_to_board() -> void:
	var active := TraitSystem.get_active_synergies(board.player_units)
	TraitSystem.apply_synergies(board.player_units, active)


func _grant_round_income() -> void:
	var human_bonus: int = _get_human_synergy_bonus()
	var earned: int = Economy.calculate_round_gold(
		GameManager.player_gold,
		win_streak,
		loss_streak,
		human_bonus
	)
	GameManager.add_gold(earned)


func _get_human_synergy_bonus() -> int:
	var human_count: int = 0
	for unit in board.player_units:
		if unit.race == "human":
			human_count += 1
	if human_count >= 3:
		return 2
	elif human_count >= 2:
		return 1
	return 0


func _calculate_loss_damage() -> int:
	# Base damage + 1 per surviving enemy unit
	return 2 + board.enemy_units.size()
