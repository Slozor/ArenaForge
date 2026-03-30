extends Node

var units: Dictionary = {}       # unit_id -> unit data dict
var races: Dictionary = {}       # race_id -> race data dict
var classes: Dictionary = {}     # class_id -> class data dict
var items: Dictionary = {}       # item_id -> item data dict


func _ready() -> void:
	_load_units()
	_load_traits()
	_load_items()


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


func get_class(class_id: String) -> Dictionary:
	return classes.get(class_id, {})


func get_item(item_id: String) -> Dictionary:
	return items.get(item_id, {})


func get_random_items(count: int) -> Array:
	var all_ids: Array = items.keys()
	all_ids.shuffle()
	return all_ids.slice(0, min(count, all_ids.size()))


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
