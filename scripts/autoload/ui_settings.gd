extends Node

const SETTINGS_PATH: String = "user://ui_settings.cfg"

const KEY_MASTER_VOLUME_DB: String = "master_volume_db"
const KEY_TOUCH_HINTS: String = "touch_hints"
const KEY_PRESENTATION_MODE: String = "presentation_mode"

const _DEFAULTS: Dictionary = {
	KEY_MASTER_VOLUME_DB: -6.0,
	KEY_TOUCH_HINTS: true,
	KEY_PRESENTATION_MODE: "auto",
}


func load_settings() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return _DEFAULTS.duplicate()
	var result: Dictionary = _DEFAULTS.duplicate()
	for key in _DEFAULTS:
		if cfg.has_section_key("settings", key):
			result[key] = cfg.get_value("settings", key)
	return result


func save_settings(settings: Dictionary) -> void:
	var cfg := ConfigFile.new()
	for key in settings:
		cfg.set_value("settings", key, settings[key])
	cfg.save(SETTINGS_PATH)


func apply_audio(settings: Dictionary) -> void:
	var db: float = float(settings.get(KEY_MASTER_VOLUME_DB, -6.0))
	var bus_idx: int = AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, db)
