extends Node

const PROFILE_PATH: String = "user://profile.save"
const MAX_RUN_HISTORY: int = 12

var profile: Dictionary = {
	"total_runs": 0,
	"wins": 0,
	"best_placement": 8,
	"last_summary": {},
	"run_history": []
}

signal profile_changed(profile_data: Dictionary)


func _ready() -> void:
	load_profile()
	GameManager.run_finished.connect(_on_run_finished)


func load_profile() -> Dictionary:
	var file: FileAccess = FileAccess.open(PROFILE_PATH, FileAccess.READ)
	if file == null:
		profile_changed.emit(get_profile())
		return get_profile()
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		profile["total_runs"] = int(parsed.get("total_runs", 0))
		profile["wins"] = int(parsed.get("wins", 0))
		profile["best_placement"] = int(parsed.get("best_placement", 8))
		profile["last_summary"] = parsed.get("last_summary", {})
		profile["run_history"] = parsed.get("run_history", [])
	profile_changed.emit(get_profile())
	return get_profile()


func save_profile() -> void:
	var file: FileAccess = FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(profile))
	file.close()


func get_profile() -> Dictionary:
	return profile.duplicate(true)


func get_run_history() -> Array:
	return (profile.get("run_history", []) as Array).duplicate(true)


func get_last_summary() -> Dictionary:
	return (profile.get("last_summary", {}) as Dictionary).duplicate(true)


func _on_run_finished(summary: Dictionary) -> void:
	profile["total_runs"] = int(profile.get("total_runs", 0)) + 1
	if int(summary.get("placement", 8)) <= 1:
		profile["wins"] = int(profile.get("wins", 0)) + 1
	profile["best_placement"] = mini(int(profile.get("best_placement", 8)), int(summary.get("placement", 8)))
	profile["last_summary"] = summary.duplicate(true)
	var history: Array = profile.get("run_history", [])
	history.push_front(summary.duplicate(true))
	while history.size() > MAX_RUN_HISTORY:
		history.pop_back()
	profile["run_history"] = history
	save_profile()
	profile_changed.emit(get_profile())
