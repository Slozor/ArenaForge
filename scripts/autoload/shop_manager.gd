extends Node

const SHOP_SIZE: int = 5
const REROLL_COST: int = 2
const XP_COST: int = 4
const XP_PER_BUY: int = 4

# Cost tier → pool size per unit
const TIER_POOL_SIZES: Dictionary = {
	1: 29,
	2: 22,
	3: 18,
	4: 12
}

# Probability of each cost tier per player level (level -> [t1%, t2%, t3%, t4%])
const LEVEL_ODDS: Dictionary = {
	1:  [100, 0,   0,   0],
	2:  [100, 0,   0,   0],
	3:  [75,  25,  0,   0],
	4:  [55,  30,  15,  0],
	5:  [45,  33,  20,  2],
	6:  [30,  40,  25,  5],
	7:  [19,  30,  35,  16],
	8:  [14,  20,  35,  31],
	9:  [10,  15,  30,  45],
	10: [5,   10,  25,  60],
}

var shop_units: Array[String] = []
var unit_pool: Dictionary = {}  # unit_id -> remaining count
var _shop_locked: bool = false
var _pool_initialized: bool = false

signal shop_refreshed(units: Array[String])
signal unit_purchased(unit_id: String)
signal shop_lock_changed(locked: bool)


func _ready() -> void:
	# Initialize pool after DataManager has loaded data
	call_deferred("_initialize_pool")


func _initialize_pool() -> void:
	if _pool_initialized:
		return
	unit_pool.clear()
	for unit_id in DataManager.get_all_unit_ids():
		var unit_data: Dictionary = DataManager.get_unit(unit_id)
		var cost: int = unit_data.get("cost", 1)
		unit_pool[unit_id] = TIER_POOL_SIZES.get(cost, 20)
	_pool_initialized = true


func is_shop_locked() -> bool:
	return _shop_locked


func set_shop_locked(locked: bool) -> void:
	if _shop_locked == locked:
		return
	_shop_locked = locked
	shop_lock_changed.emit(_shop_locked)


func toggle_shop_lock() -> bool:
	set_shop_locked(not _shop_locked)
	return _shop_locked


func get_tier_odds(level: int = -1) -> Array:
	var resolved_level: int = GameManager.get_player_level() if level == -1 else clampi(level, 1, 10)
	return LEVEL_ODDS.get(resolved_level, LEVEL_ODDS[10])


func refresh_shop(force: bool = false) -> Array[String]:
	_ensure_pool_ready()

	if _shop_locked and not force and not shop_units.is_empty():
		shop_refreshed.emit(shop_units)
		return shop_units.duplicate()

	_return_shop_units_to_pool()
	var odds: Array = get_tier_odds()
	shop_units.clear()

	for _i in SHOP_SIZE:
		var unit_id: String = _draw_unit_by_odds(odds)
		shop_units.append(unit_id)

	shop_refreshed.emit(shop_units)
	return shop_units.duplicate()


func reroll() -> bool:
	if not GameManager.spend_gold(REROLL_COST):
		return false
	refresh_shop(true)
	return true


func buy_xp() -> bool:
	if not GameManager.can_buy_xp():
		return false
	if not GameManager.spend_gold(XP_COST):
		return false
	GameManager.add_xp(XP_PER_BUY)
	return true


func purchase_unit(unit_id: String) -> bool:
	if not unit_id in shop_units:
		return false
	var cost: int = DataManager.get_unit(unit_id).get("cost", 1)
	if not GameManager.spend_gold(cost):
		return false

	shop_units.erase(unit_id)
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
		for unit_id in unit_pool:
			if unit_pool[unit_id] > 0:
				candidates.append(unit_id)
		if candidates.is_empty():
			return ""

	var selected_unit: String = candidates[randi() % candidates.size()]
	unit_pool[selected_unit] = maxi(0, unit_pool.get(selected_unit, 0) - 1)
	return selected_unit


func _return_shop_units_to_pool() -> void:
	for unit_id in shop_units:
		if unit_id == "":
			continue
		return_unit_to_pool(unit_id)


func _ensure_pool_ready() -> void:
	if not _pool_initialized:
		_initialize_pool()
