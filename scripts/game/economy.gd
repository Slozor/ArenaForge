extends RefCounted

class_name Economy

# Interest thresholds: every 10 gold = +1 gold/round, max +5
const INTEREST_THRESHOLDS: Array = [10, 20, 30, 40, 50]
const MAX_INTEREST: int = 5
const BASE_GOLD_PER_ROUND: int = 5
const WIN_STREAK_BONUS: int = 1
const LOSS_STREAK_BONUS: int = 1


static func calculate_round_gold(
	current_gold: int,
	win_streak: int,
	loss_streak: int,
	human_synergy_bonus: int
) -> int:
	return calculate_round_income(current_gold, win_streak, loss_streak, human_synergy_bonus)["total"]


static func calculate_round_income(
	current_gold: int,
	win_streak: int,
	loss_streak: int,
	human_synergy_bonus: int
) -> Dictionary:
	var interest: int = _calculate_interest(current_gold)
	var streak_bonus: int = _calculate_streak_bonus(win_streak, loss_streak)
	var total: int = BASE_GOLD_PER_ROUND + interest + streak_bonus + human_synergy_bonus
	return {
		"base": BASE_GOLD_PER_ROUND,
		"interest": interest,
		"streak_bonus": streak_bonus,
		"trait_bonus": human_synergy_bonus,
		"total": total,
	}


static func _calculate_interest(gold: int) -> int:
	var interest: int = 0
	for threshold in INTEREST_THRESHOLDS:
		if gold >= threshold:
			interest += 1
	return mini(interest, MAX_INTEREST)


static func _calculate_streak_bonus(win_streak: int, loss_streak: int) -> int:
	if win_streak >= 3:
		return WIN_STREAK_BONUS
	if loss_streak >= 3:
		return LOSS_STREAK_BONUS
	return 0


# Returns interest amount for display (e.g. "+2" shown in HUD)
static func get_interest_preview(gold: int) -> int:
	return _calculate_interest(gold)


static func get_max_interest() -> int:
	return MAX_INTEREST
