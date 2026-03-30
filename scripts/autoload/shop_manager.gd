extends Node

const SHOP_SIZE: int = 5
const REROLL_COST: int = 2
const XP_COST: int = 4

# Cost tier → pool size per unit
const TIER_POOL_SIZES: Dictionary = {
	1: 29,
	2: 22,
	3: 18,
	4: 12
}

# Probability of each cost tier per round (round -> [t1%, t2%, t3%, t4%])
const TIER_ODDS: Dictionary = {
	1:  [100, 0,   0,   0],
	2:  [75,  25,  0,   0],
	3:  [55,  30,  15,  0],
	4:  [40,  35,  20,  5],
	5:  [30,  35,  25,  10],
	6:  [20,  30,  30,  20],
	7:  [15,  25,  30,  30],
	8:  [10,  20,  30,  40],
	9:  [5,   15,  30,  50],
	10: [5,   10,  25,  60],
	11: [5,   5,   20,  70],
	12: [5,   5,   15,  75],
}

var shop_units: Array[String] = []
var unit_pool: Dictionary = {}  # unit_id -> remaining count

signal shop_refreshed(units: Array[String])
signal unit_purchased(unit_id: String)


func _ready() -> void:
	# Initialize pool after DataManager has loaded data
	call_deferred("_initialize_pool")


func _initialize_pool() -> void:
	unit_pool.clear()
	for unit_id in DataManager.get_all_unit_ids():
		var unit_data: Dictionary = DataManager.get_unit(unit_id)
		var cost: int = unit_data.get("cost", 1)
		unit_pool[unit_id] = TIER_POOL_SIZES.get(cost, 20)


func refresh_shop() -> void:
	var round_num: int = clampi(GameManager.current_round, 1, 12)
	var odds: Array = TIER_ODDS.get(round_num, TIER_ODDS[1])
	shop_units.clear()

	for _i in SHOP_SIZE:
		var unit_id: String = _draw_unit_by_odds(odds)
		shop_units.append(unit_id)

	shop_refreshed.emit(shop_units)


func reroll() -> bool:
	if not GameManager.spend_gold(REROLL_COST):
		return false
	refresh_shop()
	return true


func buy_xp() -> bool:
	if not GameManager.spend_gold(XP_COST):
		return false
	# XP handled by player level node
	return true


func purchase_unit(unit_id: String) -> bool:
	if not unit_id in shop_units:
		return false
	var cost: int = DataManager.get_unit(unit_id).get("cost", 1)
	if not GameManager.spend_gold(cost):
		return false

	shop_units.erase(unit_id)
	if unit_id in unit_pool:
		unit_pool[unit_id] = maxi(0, unit_pool[unit_id] - 1)

	unit_purchased.emit(unit_id)
	return true


func return_unit_to_pool(unit_id: String) -> void:
	if unit_id in unit_pool:
		var cost: int = DataManager.get_unit(unit_id).get("cost", 1)
		unit_pool[unit_id] = mini(unit_pool[unit_id] + 1, TIER_POOL_SIZES.get(cost, 20))


func _draw_unit_by_odds(odds: Array) -> String:
	var roll: int = randi() % 100
	var tier: int = 1
	var cumulative: int = 0
	for i in odds.size():
		cumulative += odds[i]
		if roll < cumulative:
			tier = i + 1
			break

	var candidates: Array = []
	for unit_id in unit_pool:
		if unit_pool[unit_id] > 0:
			var unit_data: Dictionary = DataManager.get_unit(unit_id)
			if unit_data.get("cost", 1) == tier:
				candidates.append(unit_id)

	if candidates.is_empty():
		return ""

	return candidates[randi() % candidates.size()]
