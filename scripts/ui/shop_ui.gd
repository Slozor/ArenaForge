extends Control

class_name ShopUI

# Layout constants (anchored bottom of 1280×720 screen)
const SHOP_Y: float = 510.0
const SHOP_HEIGHT: float = 200.0
const CARD_W: float = 148.0
const CARD_H: float = 160.0
const CARD_GAP: float = 10.0
const BUTTON_W: float = 120.0
const BUTTON_H: float = 52.0
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
var _team_label: Label = null
var _bench_label: Label = null
var _status_label: Label = null
var _locked: bool = false
var _locked_snapshot: Array[String] = []
var _bench_ui = null
var _board_ui = null
var _phase: int = PREP_PHASE
var _touch_hints_enabled: bool = true

signal unit_bought(unit_id: String)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	custom_minimum_size = Vector2(1280, SHOP_HEIGHT)
	_touch_hints_enabled = bool(UISettings.load_settings().get(UISettings.KEY_TOUCH_HINTS, true))

	_build_background()
	_build_gold_row()
	_build_overview_row()
	_build_cards()
	_build_buttons()
	_bind_scene_peers()
	_refresh_overview()

	ShopManager.shop_refreshed.connect(_on_shop_refreshed)
	ShopManager.unit_purchased.connect(_on_unit_purchased)
	ShopManager.shop_lock_changed.connect(_on_shop_lock_changed)
	GameManager.gold_changed.connect(_on_gold_changed)
	_on_shop_lock_changed(ShopManager.is_shop_locked())


func _build_background() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.11, 0.95)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Top border line
	var line := ColorRect.new()
	line.color = Color(0.3, 0.35, 0.45)
	line.custom_minimum_size = Vector2(1280, 2)
	line.position = Vector2.ZERO
	add_child(line)


func _build_gold_row() -> void:
	var row := HBoxContainer.new()
	row.position = Vector2(20, 8)
	row.add_theme_constant_override("separation", 6)
	add_child(row)

	# Gold icon from the art pipeline
	var gold_icon := TextureRect.new()
	gold_icon.texture = preload("res://assets/ui/gold_icon.svg")
	gold_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gold_icon.stretch_mode = TextureRect.STRETCH_SCALE
	gold_icon.custom_minimum_size = Vector2(22, 22)
	row.add_child(gold_icon)

	_gold_label = Label.new()
	_gold_label.text = "0"
	_gold_label.add_theme_font_size_override("font_size", 22)
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	row.add_child(_gold_label)

	_interest_label = Label.new()
	_interest_label.text = ""
	_interest_label.add_theme_font_size_override("font_size", 14)
	_interest_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.4))
	row.add_child(_interest_label)

	_level_label = Label.new()
	_level_label.text = "Lv. 1"
	_level_label.add_theme_font_size_override("font_size", 14)
	_level_label.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
	_level_label.position = Vector2(1180, 8)
	add_child(_level_label)


func _build_overview_row() -> void:
	_team_label = Label.new()
	_team_label.position = Vector2(900, 8)
	_team_label.add_theme_font_size_override("font_size", 14)
	_team_label.add_theme_color_override("font_color", Color(0.85, 0.95, 0.85))
	add_child(_team_label)

	_bench_label = Label.new()
	_bench_label.position = Vector2(900, 26)
	_bench_label.add_theme_font_size_override("font_size", 12)
	_bench_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	add_child(_bench_label)

	_status_label = Label.new()
	_status_label.position = Vector2(20, 172)
	_status_label.custom_minimum_size = Vector2(760, 20)
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9))
	add_child(_status_label)


func _build_cards() -> void:
	# 5 cards, centered horizontally
	var total_w: float = 5.0 * CARD_W + 4.0 * CARD_GAP
	var start_x: float = (1280.0 - total_w) / 2.0

	for i in 5:
		var card = _make_unit_card()
		if card == null:
			continue
		card.position = Vector2(start_x + i * (CARD_W + CARD_GAP), 30)
		add_child(card)
		_cards.append(card)
		card.card_tapped.connect(_on_card_tapped)


func _build_buttons() -> void:
	var cards_right_x: float = (1280.0 + 5.0 * CARD_W + 4.0 * CARD_GAP) / 2.0 + 14.0

	# Reroll button
	_reroll_btn = _make_button("↺ Reroll\n2g", Color(0.25, 0.45, 0.65))
	_reroll_btn.position = Vector2(cards_right_x, 30)
	_reroll_btn.custom_minimum_size = Vector2(BUTTON_W, BUTTON_H)
	_reroll_btn.pressed.connect(_on_reroll)
	add_child(_reroll_btn)

	# Buy XP button
	_xp_btn = _make_button("▲ Buy XP\n4g", Color(0.30, 0.55, 0.30))
	_xp_btn.position = Vector2(cards_right_x, 90)
	_xp_btn.custom_minimum_size = Vector2(BUTTON_W, BUTTON_H)
	_xp_btn.pressed.connect(_on_buy_xp)
	add_child(_xp_btn)

	# Lock button
	_lock_btn = _make_button("🔓 Lock", Color(0.45, 0.35, 0.20))
	_lock_btn.position = Vector2(cards_right_x, 148)
	_lock_btn.custom_minimum_size = Vector2(BUTTON_W, BUTTON_H - 14)
	_lock_btn.pressed.connect(_on_toggle_lock)
	add_child(_lock_btn)


func _make_unit_card():
	# Inline card scene construction
	var card_script: Script = load(UNIT_CARD_SCRIPT_PATH)
	if card_script == null:
		push_error("ShopUI: could not load %s" % UNIT_CARD_SCRIPT_PATH)
		return null
	var card = card_script.new()
	card.custom_minimum_size = Vector2(CARD_W, CARD_H)

	var portrait := TextureRect.new()
	portrait.name = "Portrait"
	portrait.custom_minimum_size = Vector2(CARD_W, 90)
	portrait.position = Vector2.ZERO
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_SCALE
	card.add_child(portrait)

	var name_lbl := Label.new()
	name_lbl.name = "NameLabel"
	name_lbl.position = Vector2(4, 94)
	name_lbl.custom_minimum_size = Vector2(CARD_W - 8, 20)
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(name_lbl)

	var cost_lbl := Label.new()
	cost_lbl.name = "CostLabel"
	cost_lbl.position = Vector2(4, 116)
	cost_lbl.custom_minimum_size = Vector2(CARD_W - 8, 18)
	cost_lbl.add_theme_font_size_override("font_size", 14)
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(cost_lbl)

	var race_lbl := Label.new()
	race_lbl.name = "RaceLabel"
	race_lbl.position = Vector2(4, 134)
	race_lbl.custom_minimum_size = Vector2((CARD_W - 8) / 2.0, 16)
	race_lbl.add_theme_font_size_override("font_size", 11)
	race_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	card.add_child(race_lbl)

	var trait_lbl := Label.new()
	trait_lbl.name = "TraitLabel"
	trait_lbl.position = Vector2(CARD_W / 2.0, 134)
	trait_lbl.custom_minimum_size = Vector2((CARD_W - 8) / 2.0, 16)
	trait_lbl.add_theme_font_size_override("font_size", 11)
	trait_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	card.add_child(trait_lbl)

	var overlay := ColorRect.new()
	overlay.name = "Overlay"
	overlay.color = Color(0, 0, 0, 0)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.add_child(overlay)

	var tap := Button.new()
	tap.name = "TapArea"
	tap.flat = true
	tap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.add_child(tap)

	return card


func _make_button(text: String, color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("normal", style)
	var hover_style := style.duplicate() as StyleBoxFlat
	hover_style.bg_color = color.lightened(0.2)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_font_size_override("font_size", 13)
	return btn


# ── Signal handlers ────────────────────────────────────────────────────────

func _on_shop_refreshed(unit_ids: Array[String]) -> void:
	_locked_snapshot = unit_ids.duplicate()
	_apply_shop_units(unit_ids)
	_set_status("")
	_update_affordability()


func _apply_shop_units(unit_ids: Array[String]) -> void:
	for i in _cards.size():
		if i < unit_ids.size() and unit_ids[i] != "":
			_cards[i].set_unit(unit_ids[i])
		else:
			_cards[i].clear()


func _on_gold_changed(new_gold: int) -> void:
	_gold_label.text = str(new_gold)
	var interest: int = Economy.get_interest_preview(new_gold)
	_interest_label.text = ("(+%d)" % interest) if interest > 0 else ""
	_update_affordability()
	_refresh_overview()


func _on_unit_purchased(unit_id: String) -> void:
	for card in _cards:
		if card.unit_id == unit_id:
			card.clear()
			break
	_locked_snapshot = ShopManager.shop_units.duplicate()
	_set_status("Purchased %s" % _get_unit_name(unit_id))
	_update_affordability()
	_refresh_overview()


func _on_card_tapped(unit_id: String) -> void:
	if _phase != PREP_PHASE:
		_set_status("Shop closed during combat")
		return
	if _bench_ui == null:
		_set_status("Bench unavailable")
		return
	if _bench_ui != null and not _bench_ui.can_accept_purchase(unit_id):
		_set_status("Bench full")
		return

	if not ShopManager.purchase_unit(unit_id):
		_set_status("Not enough gold")
		return

	if not _bench_ui.add_unit_from_shop(unit_id):
		var cost: int = DataManager.get_unit(unit_id).get("cost", 1)
		GameManager.add_gold(cost)
		ShopManager.return_unit_to_pool(unit_id)
		ShopManager.shop_units.append(unit_id)
		ShopManager.shop_refreshed.emit(ShopManager.shop_units)
		_set_status("Bench full")
		_refresh_overview()
		return

	unit_bought.emit(unit_id)
	_locked_snapshot = ShopManager.shop_units.duplicate()
	_set_status("Bought %s" % _get_unit_name(unit_id))
	_update_affordability()
	_refresh_overview()


func _on_reroll() -> void:
	if _phase != PREP_PHASE:
		_set_status("Reroll unavailable during combat")
		return
	if ShopManager.reroll():
		_locked_snapshot = ShopManager.shop_units.duplicate()
		_set_status("Shop refreshed")
	else:
		_set_status("Not enough gold")


func _on_buy_xp() -> void:
	if _phase != PREP_PHASE:
		_set_status("XP only during preparation")
		return
	if ShopManager.buy_xp():
		_set_status("Bought XP")
	else:
		_set_status("Not enough gold")


func _on_toggle_lock() -> void:
	if _phase != PREP_PHASE:
		return
	_locked = ShopManager.toggle_shop_lock()
	_locked_snapshot = ShopManager.shop_units.duplicate()
	_set_status("Shop locked" if _locked else "Shop unlocked")
	_update_affordability()


func is_locked() -> bool:
	return _locked


func _update_affordability() -> void:
	var gold: int = GameManager.player_gold
	for card in _cards:
		if not card.is_empty:
			var cost: int = card.unit_data.get("cost", 99)
			var can_buy: bool = _phase == PREP_PHASE and gold >= cost and _bench_ui != null
			if can_buy:
				can_buy = _bench_ui.can_accept_purchase(card.unit_id)
			card.set_affordable(can_buy)

	if _reroll_btn != null:
		_reroll_btn.disabled = _phase != PREP_PHASE
	if _xp_btn != null:
		_xp_btn.disabled = _phase != PREP_PHASE or not GameManager.can_buy_xp()
	if _lock_btn != null:
		_lock_btn.disabled = _phase != PREP_PHASE


func _bind_scene_peers() -> void:
	var root: Node = get_parent()
	if root == null:
		root = get_tree().current_scene
	if root == null:
		return

	_bench_ui = root.get_node_or_null("BenchUI")
	_board_ui = root.get_node_or_null("BoardUI")

	if root.has_signal("phase_changed") and not root.phase_changed.is_connected(_on_phase_changed):
		root.phase_changed.connect(_on_phase_changed)

	if _bench_ui != null:
		_bench_ui.unit_sold.connect(_on_bench_changed)
		_bench_ui.unit_selected_from_bench.connect(func(_unit): _refresh_overview())
		_bench_ui.unit_sold.connect(func(_unit): _refresh_overview())
		_bench_ui.unit_selected_from_bench.connect(func(_unit): _set_status("Select a board cell to place"))

	if _board_ui != null:
		_board_ui.unit_placed.connect(func(_unit, _col, _row): _on_board_changed())
		_board_ui.unit_moved.connect(func(_unit, _from, _to): _on_board_changed())
		_board_ui.unit_sent_to_bench.connect(func(_unit): _on_board_changed())

	_refresh_overview()


func _on_phase_changed(phase: int) -> void:
	_phase = phase
	if _phase != PREP_PHASE:
		_set_status("Combat phase")
	_update_affordability()
	_refresh_overview()


func _on_board_changed() -> void:
	_refresh_overview()


func _on_bench_changed(_unit) -> void:
	_refresh_overview()


func _on_shop_lock_changed(locked: bool) -> void:
	_locked = locked
	if _lock_btn != null:
		_lock_btn.text = ("🔒 Locked" if _locked else "🔓 Lock")
		_lock_btn.add_theme_color_override(
			"font_color",
			Color(1.0, 0.9, 0.6) if _locked else Color.WHITE
		)
	_update_affordability()


func _refresh_overview() -> void:
	if _team_label != null:
		_team_label.text = "Team %d/%d" % [_get_team_count(), _get_team_capacity()]
	if _bench_label != null:
		_bench_label.text = "Bench %d/%d" % [_get_bench_count(), _get_bench_capacity()]
	if _level_label != null:
		_level_label.text = "Lv. %d" % _get_player_level()
	if _status_label != null:
		_status_label.visible = _touch_hints_enabled or _status_label.text != ""


func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text
		if text == "":
			_status_label.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9))
		elif text.find("full") != -1:
			_status_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.35))
		elif text.find("closed") != -1 or text.find("locked") != -1:
			_status_label.add_theme_color_override("font_color", Color(0.9, 0.75, 0.45))
		else:
			_status_label.add_theme_color_override("font_color", Color(0.8, 0.9, 0.7))


func _get_team_count() -> int:
	if _board_ui != null:
		return _board_ui.get_unit_count()
	return 0


func _get_team_capacity() -> int:
	if _board_ui != null:
		return _board_ui.get_team_capacity()
	return 5


func _get_bench_count() -> int:
	if _bench_ui != null:
		return _bench_ui.get_unit_count()
	return 0


func _get_bench_capacity() -> int:
	if _bench_ui != null:
		return _bench_ui.get_capacity()
	return 9


func _get_player_level() -> int:
	var root: Node = get_parent()
	if root == null:
		root = get_tree().current_scene
	if root != null and root.has_method("get_player_level"):
		return int(root.call("get_player_level"))
	if GameManager.has_method("get_player_level"):
		return int(GameManager.call("get_player_level"))
	return 1


func _get_unit_name(unit_id: String) -> String:
	var data: Dictionary = DataManager.get_unit(unit_id)
	if data.is_empty():
		return unit_id.capitalize()
	return data.get("name", unit_id)
