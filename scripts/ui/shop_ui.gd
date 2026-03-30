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

var _cards: Array[UnitCard] = []
var _reroll_btn: Button = null
var _xp_btn: Button = null
var _lock_btn: Button = null
var _gold_label: Label = null
var _interest_label: Label = null
var _level_label: Label = null
var _locked: bool = false

signal unit_bought(unit_id: String)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	custom_minimum_size = Vector2(1280, SHOP_HEIGHT)

	_build_background()
	_build_gold_row()
	_build_cards()
	_build_buttons()

	ShopManager.shop_refreshed.connect(_on_shop_refreshed)
	ShopManager.unit_purchased.connect(_on_unit_purchased)
	GameManager.gold_changed.connect(_on_gold_changed)


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

	# Gold icon (placeholder colored square)
	var gold_icon := ColorRect.new()
	gold_icon.color = Color(1.0, 0.82, 0.1)
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


func _build_cards() -> void:
	# 5 cards, centered horizontally
	var total_w: float = 5.0 * CARD_W + 4.0 * CARD_GAP
	var start_x: float = (1280.0 - total_w) / 2.0

	for i in 5:
		var card := _make_unit_card()
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


func _make_unit_card() -> UnitCard:
	# Inline card scene construction
	var card := UnitCard.new()
	card.custom_minimum_size = Vector2(CARD_W, CARD_H)

	var portrait := ColorRect.new()
	portrait.name = "Portrait"
	portrait.custom_minimum_size = Vector2(CARD_W, 90)
	portrait.position = Vector2.ZERO
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
	for i in _cards.size():
		if i < unit_ids.size() and unit_ids[i] != "":
			_cards[i].set_unit(unit_ids[i])
		else:
			_cards[i].clear()
	_update_affordability()


func _on_gold_changed(new_gold: int) -> void:
	_gold_label.text = str(new_gold)
	var interest: int = Economy.get_interest_preview(new_gold)
	_interest_label.text = ("(+%d)" % interest) if interest > 0 else ""
	_update_affordability()


func _on_unit_purchased(unit_id: String) -> void:
	for card in _cards:
		if card.unit_id == unit_id:
			card.clear()
			break
	_update_affordability()


func _on_card_tapped(unit_id: String) -> void:
	if ShopManager.purchase_unit(unit_id):
		unit_bought.emit(unit_id)


func _on_reroll() -> void:
	ShopManager.reroll()


func _on_buy_xp() -> void:
	ShopManager.buy_xp()


func _on_toggle_lock() -> void:
	_locked = not _locked
	_lock_btn.text = ("🔒 Locked" if _locked else "🔓 Lock")


func is_locked() -> bool:
	return _locked


func _update_affordability() -> void:
	var gold: int = GameManager.player_gold
	for card in _cards:
		if not card.is_empty:
			var cost: int = card.unit_data.get("cost", 99)
			card.set_affordable(gold >= cost)
