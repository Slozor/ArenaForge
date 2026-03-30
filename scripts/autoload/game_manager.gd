extends Node

# Game states
enum GameState {
	MAIN_MENU,
	PREPARATION,
	BATTLE,
	GAME_OVER
}

var current_state: GameState = GameState.MAIN_MENU
var player_gold: int = 0
var player_health: int = 100
var current_round: int = 0

signal state_changed(new_state: GameState)
signal gold_changed(new_amount: int)
signal health_changed(new_amount: int)
signal round_changed(new_round: int)


func change_state(new_state: GameState) -> void:
	current_state = new_state
	state_changed.emit(new_state)


func add_gold(amount: int) -> void:
	player_gold += amount
	gold_changed.emit(player_gold)


func spend_gold(amount: int) -> bool:
	if player_gold < amount:
		return false
	player_gold -= amount
	gold_changed.emit(player_gold)
	return true


func take_damage(amount: int) -> void:
	player_health -= amount
	health_changed.emit(player_health)
	if player_health <= 0:
		change_state(GameState.GAME_OVER)


func start_new_game() -> void:
	player_gold = 5
	player_health = 100
	current_round = 1
	round_changed.emit(current_round)
	change_state(GameState.PREPARATION)


func next_round() -> void:
	current_round += 1
	round_changed.emit(current_round)
	_grant_round_gold()
	change_state(GameState.PREPARATION)


func _grant_round_gold() -> void:
	var base_gold: int = 5
	var round_bonus: int = min(current_round, 5)
	add_gold(base_gold + round_bonus)
