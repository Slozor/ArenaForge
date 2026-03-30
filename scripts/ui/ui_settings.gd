extends RefCounted

class_name UISettings

const CONFIG_PATH: String = "user://arena_forge_ui.cfg"
const SECTION: String = "ui"
const KEY_MASTER_VOLUME_DB: String = "master_volume_db"
const KEY_TOUCH_HINTS: String = "touch_hints"
const KEY_PRESENTATION_MODE: String = "presentation_mode"


static func load_settings() -> Dictionary:
	var cfg := ConfigFile.new()
	var settings: Dictionary = _default_settings()

	if cfg.load(CONFIG_PATH) == OK:
		settings[KEY_MASTER_VOLUME_DB] = float(cfg.get_value(SECTION, KEY_MASTER_VOLUME_DB, settings[KEY_MASTER_VOLUME_DB]))
		settings[KEY_TOUCH_HINTS] = bool(cfg.get_value(SECTION, KEY_TOUCH_HINTS, settings[KEY_TOUCH_HINTS]))
		settings[KEY_PRESENTATION_MODE] = str(cfg.get_value(SECTION, KEY_PRESENTATION_MODE, settings[KEY_PRESENTATION_MODE]))

	return settings


static func save_settings(settings: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, KEY_MASTER_VOLUME_DB, float(settings.get(KEY_MASTER_VOLUME_DB, -6.0)))
	cfg.set_value(SECTION, KEY_TOUCH_HINTS, bool(settings.get(KEY_TOUCH_HINTS, true)))
	cfg.set_value(SECTION, KEY_PRESENTATION_MODE, str(settings.get(KEY_PRESENTATION_MODE, "auto")))
	cfg.save(CONFIG_PATH)


static func apply_audio(settings: Dictionary) -> void:
	var bus_index: int = AudioServer.get_bus_index("Master")
	if bus_index == -1:
		return
	AudioServer.set_bus_volume_db(bus_index, float(settings.get(KEY_MASTER_VOLUME_DB, -6.0)))


static func _default_settings() -> Dictionary:
	return {
		KEY_MASTER_VOLUME_DB: -6.0,
		KEY_TOUCH_HINTS: true,
		KEY_PRESENTATION_MODE: "auto",
	}
