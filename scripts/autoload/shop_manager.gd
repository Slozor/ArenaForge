extends Node

const SHOP_SIZE: int = 5
const REROLL_COST: int = 2
const XP_COST: int = 4

# Unit tiers and their pool sizes
const TIER_POOL_SIZES: Dictionary = {
	1: 29,
	2: 22,
	3: 18,
	4: 12,
	5: 10
}

var shop_units: Array[String] = []
var unit_pool: Dictionary = {}  # unit_id -> remaining count

signal shop_refreshed(units: Array[String])


func _ready() -> void:
	_initialize_pool()


func _initialize_pool() -> void:
	# Placeholder: populate with unit IDs per tier
	for tier in TIER_POOL_SIZES:
		var count: int = TIER_POOL_SIZES[tier]
		# Units will be populated once unit data is defined
		pass


func refresh_shop() -> void:
	shop_units.clear()
	for i in SHOP_SIZE:
		var unit: String = _draw_random_unit()
		if unit != "":
			shop_units.append(unit)
	shop_refreshed.emit(shop_units)


func reroll_shop() -> bool:
	if not GameManager.spend_gold(REROLL_COST):
		return false
	refresh_shop()
	return true


func buy_xp() -> bool:
	if not GameManager.spend_gold(XP_COST):
		return false
	# XP logic will be handled by the player node
	return true


func _draw_random_unit() -> String:
	# Placeholder until unit roster is defined
	return ""
