extends Control

class_name UnitCard

const CARD_W: float = 148.0
const CARD_H: float = 168.0

# Mirrors UITheme for static preload access
const COST_COLORS: Dictionary = {
	1: Color(0.55, 0.55, 0.58),
	2: Color(0.07, 0.60, 0.22),
	3: Color(0.18, 0.45, 0.88),
	4: Color(0.58, 0.12, 0.82),
}
const COST_LABEL_COLORS: Dictionary = {
	1: Color(0.88, 0.88, 0.90),
	2: Color(0.55, 1.00, 0.65),
	3: Color(0.65, 0.85, 1.00),
	4: Color(0.88, 0.65, 1.00),
}

var unit_id: String = ""
var unit_data: Dictionary = {}
var is_affordable: bool = true
var is_empty: bool = true

signal card_tapped(uid: String)

@onready var _portrait    = $Portrait
@onready var _name_label  = $NameLabel
@onready var _cost_badge  = $CostBadge
@onready var _cost_label  = $CostLabel
@onready var _trait_row   = $TraitRow
@onready var _overlay     = $Overlay
@onready var _tap_area    = $TapArea


func _ready() -> void:
	_tap_area.pressed.connect(_on_tapped)
	custom_minimum_size = Vector2(CARD_W, CARD_H)
	_show_empty()


func set_unit(id: String) -> void:
	unit_id = id
	unit_data = DataManager.get_unit(id)
	is_empty = unit_data.is_empty()
	_refresh_display()


func set_affordable(can_afford: bool) -> void:
	is_affordable = can_afford
	_overlay.color = Color(0, 0, 0, 0.0 if can_afford else 0.52)
	_tap_area.disabled = not can_afford or is_empty


func clear() -> void:
	unit_id = ""
	unit_data = {}
	is_empty = true
	_show_empty()


func _refresh_display() -> void:
	if is_empty:
		_show_empty()
		return

	var cost: int = unit_data.get("cost", 1)
	var border: Color = COST_COLORS.get(cost, UITheme.BORDER_MID)
	var label_col: Color = COST_LABEL_COLORS.get(cost, UITheme.TEXT_PRIMARY)

	_portrait.color = border.darkened(0.55)
	_name_label.text = unit_data.get("name", "?")

	_cost_badge.color = border.darkened(0.2)
	_cost_label.text = str(cost)
	_cost_label.add_theme_color_override("font_color", label_col)

	var race: String  = unit_data.get("race",  "").capitalize()
	var trait: String = unit_data.get("trait", "").capitalize()
	_set_trait_row(race, trait, border)

	_overlay.color = Color(0, 0, 0, 0)
	_tap_area.disabled = false
	queue_redraw()


func _show_empty() -> void:
	_portrait.color    = UITheme.BG_CARD
	_name_label.text   = ""
	_cost_label.text   = ""
	_cost_badge.color  = UITheme.BG_PANEL
	_clear_trait_row()
	_overlay.color = Color(0, 0, 0, 0)
	_tap_area.disabled = true
	queue_redraw()


func _set_trait_row(race: String, trait_name: String, accent: Color) -> void:
	for child in _trait_row.get_children():
		child.queue_free()
	for t in [race, trait_name]:
		var pill := Label.new()
		pill.text = t
		pill.add_theme_font_size_override("font_size", 10)
		pill.add_theme_color_override("font_color", UITheme.TEXT_SECOND)
		var style := UITheme.panel_style(accent.darkened(0.65), accent.darkened(0.35), 3, 1)
		style.content_margin_left  = 5
		style.content_margin_right = 5
		style.content_margin_top   = 2
		style.content_margin_bottom = 2
		pill.add_theme_stylebox_override("normal", style)
		_trait_row.add_child(pill)


func _clear_trait_row() -> void:
	for child in _trait_row.get_children():
		child.queue_free()


func _on_tapped() -> void:
	if not is_empty and is_affordable:
		card_tapped.emit(unit_id)


func _draw() -> void:
	var border_col := UITheme.BORDER_SUBTLE
	var border_w   := 1.5
	var glow_col   := Color(0, 0, 0, 0)

	if not is_empty:
		var cost: int = unit_data.get("cost", 1)
		border_col = COST_COLORS.get(cost, UITheme.BORDER_MID)
		border_w   = 2.5
		glow_col   = border_col
		glow_col.a = 0.18

	# Outer glow
	if glow_col.a > 0:
		draw_rect(Rect2(Vector2(-3, -3), Vector2(CARD_W + 6, CARD_H + 6)), glow_col, true)
	# Card bg
	draw_rect(Rect2(Vector2.ZERO, Vector2(CARD_W, CARD_H)), UITheme.BG_CARD, true)
	# Border
	draw_rect(Rect2(Vector2.ZERO, Vector2(CARD_W, CARD_H)), border_col, false, border_w)
	# Top accent line
	if not is_empty:
		draw_rect(Rect2(Vector2(0, 0), Vector2(CARD_W, 3)), border_col, true)
