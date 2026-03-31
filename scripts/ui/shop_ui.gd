extends Control

class_name ShopUI

const SHOP_HEIGHT: float = UITheme.SHOP_PANEL_HEIGHT
const CARD_W: float = 148.0
const CARD_H: float = 160.0
const PREP_PHASE: int = 0
const COMBAT_PHASE: int = 1
const RESULT_PHASE: int = 2
const UNIT_CARD_SCRIPT_PATH: String = "res://scripts/ui/unit_card.gd"

var _cards: Array = []
var _reroll_btn: Button = null
var _xp_btn: Button = null
var _lock_btn: Button = null
var _gold_label: Label = null
var _interest_label: Label = null
var _level_label: Label = null
var _status_label: Label = null
var _locked: bool = false
var _locked_snapshot: Array[String] = []
var _bench_ui = null
var _board_ui = null
var _hud_ui = null
var _phase: int = PREP_PHASE
var _touch_hints_enabled: bool = true

var _panel: PanelContainer = null
var _panel_patch: NinePatchRect = null
var _cards_row: HBoxContainer = null
var _buttons_col: VBoxContainer = null

signal unit_bought(unit_id: String)
signal unit_hovered(unit_id: String)
signal unit_unhovered()


func _ready() -> void:
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 0.0
	anchor_bottom = 0.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	mouse_filter = Control.MOUSE_FILTER_PASS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	theme = UITheme.build_theme()
	z_as_relative = false
	z_index = 50
	clip_contents = true
	custom_minimum_size = Vector2(0.0, SHOP_HEIGHT)
	_touch_hints_enabled = bool(UISettings.load_settings().get(UISettings.KEY_TOUCH_HINTS, true))

	_build_ui()
	_bind_scene_peers()
	_refresh_overview()

	ShopManager.shop_refreshed.connect(_on_shop_refreshed)
	ShopManager.unit_purchased.connect(_on_unit_purchased)
	ShopManager.shop_lock_changed.connect(_on_shop_lock_changed)
	GameManager.gold_changed.connect(_on_gold_changed)
	_on_shop_lock_changed(ShopManager.is_shop_locked())
	if not resized.is_connected(_refresh_layout):
		resized.connect(_refresh_layout)
	_refresh_layout()


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	add_child(_panel)

	_panel_patch = UITheme.make_nine_patch()
	_panel.add_child(_panel_patch)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	_panel.add_child(margin)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 4)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	root.add_child(header)

	var gold_icon := TextureRect.new()
	gold_icon.texture = preload("res://assets/ui/gold_icon.svg")
	gold_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gold_icon.stretch_mode = TextureRect.STRETCH_SCALE
	gold_icon.custom_minimum_size = Vector2(18, 18)
	header.add_child(gold_icon)

	_gold_label = Label.new()
	_gold_label.add_theme_font_size_override("font_size", 16)
	_gold_label.add_theme_color_override("font_color", UITheme.GOLD_BRIGHT)
	header.add_child(_gold_label)

	_interest_label = Label.new()
	_interest_label.add_theme_font_size_override("font_size", 10)
	_interest_label.add_theme_color_override("font_color", UITheme.GREEN_HP)
	header.add_child(_interest_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	_level_label = Label.new()
	_level_label.add_theme_font_size_override("font_size", 14)
	_level_label.add_theme_color_override("font_color", UITheme.TEAL)
	header.add_child(_level_label)

	var content := HBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	root.add_child(content)

	_cards_row = HBoxContainer.new()
	_cards_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards_row.add_theme_constant_override("separation", 6)
	content.add_child(_cards_row)

	for i in 5:
		var card = _make_unit_card()
		if card == null:
			continue
		card.custom_minimum_size = Vector2(96, 98)
		_cards_row.add_child(card)
		_cards.append(card)
		card.card_tapped.connect(_on_card_tapped)
		card.card_hovered.connect(_on_card_hovered)
		card.card_unhovered.connect(_on_card_unhovered)

	_buttons_col = VBoxContainer.new()
	_buttons_col.custom_minimum_size = Vector2(88, 0)
	_buttons_col.add_theme_constant_override("separation", 4)
	content.add_child(_buttons_col)

	_reroll_btn = _make_button("Reroll\n2 Gold", UITheme.BG_PANEL_ALT, UITheme.TEAL)
	_xp_btn = _make_button("Buy XP\n4 Gold", UITheme.BG_PANEL_ALT, UITheme.GREEN_HP)
	_lock_btn = _make_button("Lock", UITheme.BG_PANEL_ALT, UITheme.GOLD)
	_reroll_btn.pressed.connect(_on_reroll)
	_xp_btn.pressed.connect(_on_buy_xp)
	_lock_btn.pressed.connect(_on_toggle_lock)
	_buttons_col.add_child(_reroll_btn)
	_buttons_col.add_child(_xp_btn)
	_buttons_col.add_child(_lock_btn)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 10)
	_status_label.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	_status_label.visible = false
	root.add_child(_status_label)


func _make_unit_card():
	var card_script: Script = load(UNIT_CARD_SCRIPT_PATH)
	if card_script == null:
		push_error("ShopUI: could not load %s" % UNIT_CARD_SCRIPT_PATH)
		return null
	return card_script.new()


func _make_button(text: String, bg: Color = UITheme.BG_PANEL_ALT, border: Color = UITheme.BORDER_MID) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(84, 22)
	btn.add_theme_stylebox_override("normal", UITheme.button_style(bg, border, 6))
	btn.add_theme_stylebox_override("hover", UITheme.button_style(bg.lightened(0.12), border.lightened(0.2), 6))
	btn.add_theme_font_size_override("font_size", 11)
	btn.add_theme_color_override("font_color", UITheme.TEXT_PRIMARY)
	return btn


func _refresh_layout() -> void:
	var view_size: Vector2 = get_viewport_rect().size
	var width: float = minf(maxf(760.0, view_size.x - UITheme.SCREEN_GUTTER * 2.0), UITheme.CONTENT_MAX_WIDTH)
	position = Vector2(round((view_size.x - width) * 0.5), view_size.y - SHOP_HEIGHT - UITheme.SCREEN_GUTTER)
	size = Vector2(width, SHOP_HEIGHT)

	var compact: bool = width < 1360.0
	var large: bool = width >= 1600.0
	var card_w: float = 100.0 if compact else (124.0 if large else 112.0)
	var card_h: float = 104.0 if compact else (132.0 if large else 118.0)
	_buttons_col.custom_minimum_size = Vector2(96.0 if compact else 112.0, 0.0)
	for card in _cards:
		if card.has_method("set_card_metrics"):
			card.set_card_metrics(card_w, card_h)
		else:
			card.custom_minimum_size = Vector2(card_w, card_h)
			card.size = Vector2(card_w, card_h)


func _on_shop_refreshed(unit_ids: Array[String]) -> void:
	_locked_snapshot = unit_ids.duplicate()
	_apply_shop_units(unit_ids)
	_update_affordability()


func _apply_shop_units(unit_ids: Array[String]) -> void:
	for i in _cards.size():
		var unit_id: String = unit_ids[i] if i < unit_ids.size() else ""
		_cards[i].set_unit(unit_id)


func _on_gold_changed(_new_gold: int) -> void:
	_refresh_overview()
	_update_affordability()


func _on_unit_purchased(unit_id: String) -> void:
	if _bench_ui != null and _bench_ui.has_method("add_unit_from_shop"):
		_bench_ui.add_unit_from_shop(unit_id)
	_apply_shop_units(ShopManager.shop_units)
	unit_bought.emit(unit_id)
	_refresh_overview()
	_update_affordability()


func _on_card_tapped(unit_id: String) -> void:
	if unit_id == "" or _phase != PREP_PHASE:
		return
	if _bench_ui == null or not _bench_ui.can_accept_purchase(unit_id):
		_set_status("Bench full")
		return
	if not ShopManager.purchase_unit(unit_id):
		_set_status("Not enough gold")


func _on_reroll() -> void:
	if _phase != PREP_PHASE:
		return
	if not ShopManager.reroll():
		_set_status("Not enough gold")


func _on_buy_xp() -> void:
	if _phase != PREP_PHASE:
		return
	if not ShopManager.buy_xp():
		_set_status("Can't buy XP")


func _on_toggle_lock() -> void:
	if _phase != PREP_PHASE:
		return
	ShopManager.set_shop_locked(not _locked)


func is_locked() -> bool:
	return _locked


func _update_affordability() -> void:
	var gold: int = GameManager.player_gold
	for card in _cards:
		if card.has_method("set_affordable"):
			var unit_id: String = card.unit_id
			var cost: int = 99
			if unit_id != "":
				var data: Dictionary = DataManager.get_unit(unit_id)
				cost = int(data.get("cost", 99))
			card.set_affordable(gold >= cost)
	if _reroll_btn != null:
		_reroll_btn.disabled = gold < ShopManager.REROLL_COST or _phase != PREP_PHASE
	if _xp_btn != null:
		_xp_btn.disabled = gold < ShopManager.XP_COST or _phase != PREP_PHASE or GameManager.is_max_level()


func _bind_scene_peers() -> void:
	var root := get_parent()
	if root == null:
		return
	_bench_ui = root.get_node_or_null("BenchUI")
	_board_ui = root.get_node_or_null("BoardUI")
	_hud_ui = root.get_node_or_null("HudUI")
	if root.has_signal("phase_changed") and not root.phase_changed.is_connected(_on_phase_changed):
		root.phase_changed.connect(_on_phase_changed)
	if _board_ui != null:
		if not _board_ui.unit_placed.is_connected(_on_board_changed):
			_board_ui.unit_placed.connect(_on_board_changed)
		if not _board_ui.unit_sent_to_bench.is_connected(_on_bench_changed):
			_board_ui.unit_sent_to_bench.connect(_on_bench_changed)


func _on_card_hovered(unit_id: String) -> void:
	unit_hovered.emit(unit_id)


func _on_card_unhovered(_unit_id: String) -> void:
	unit_unhovered.emit()


func _on_phase_changed(phase: int) -> void:
	_phase = phase
	var prep: bool = phase == PREP_PHASE
	_reroll_btn.disabled = not prep or GameManager.player_gold < ShopManager.REROLL_COST
	_xp_btn.disabled = not prep or GameManager.player_gold < ShopManager.XP_COST or GameManager.is_max_level()
	_lock_btn.disabled = not prep


func _on_board_changed(_unit = null, _col: int = -1, _row: int = -1) -> void:
	_refresh_overview()


func _on_bench_changed(_unit) -> void:
	_refresh_overview()


func _on_shop_lock_changed(locked: bool) -> void:
	_locked = locked
	if _lock_btn != null:
		_lock_btn.text = "Unlock" if locked else "Lock"


func refresh_overview() -> void:
	_refresh_overview()


func _refresh_overview() -> void:
	if _gold_label != null:
		_gold_label.text = str(GameManager.player_gold)
	if _interest_label != null:
		var interest: int = min(5, int(float(GameManager.player_gold) / 10.0))
		_interest_label.text = "(+%d)" % interest if interest > 0 else ""
	if _level_label != null:
		_level_label.text = "Lv. %d" % _get_player_level()
	if _status_label != null:
		_status_label.text = ""
		_status_label.visible = false


func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text
		_status_label.visible = text != ""


func _get_team_count() -> int:
	return _board_ui.get_unit_count() if _board_ui != null else 0


func _get_team_capacity() -> int:
	return _board_ui.get_team_capacity() if _board_ui != null else 0


func _get_bench_count() -> int:
	return _bench_ui.get_unit_count() if _bench_ui != null else 0


func _get_bench_capacity() -> int:
	return _bench_ui.get_capacity() if _bench_ui != null else 0


func _get_player_level() -> int:
	return GameManager.get_player_level()


func _get_unit_name(unit_id: String) -> String:
	var data: Dictionary = DataManager.get_unit(unit_id)
	return String(data.get("name", unit_id))
