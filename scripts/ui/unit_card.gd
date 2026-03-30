extends Control

class_name UnitCard

# Cost tier colors matching TFT convention
const COST_COLORS: Dictionary = {
	1: Color(0.65, 0.65, 0.65),   # gray
	2: Color(0.15, 0.70, 0.30),   # green
	3: Color(0.20, 0.45, 0.90),   # blue
	4: Color(0.60, 0.20, 0.90),   # purple
}
const COST_GOLD_COLOR: Dictionary = {
	1: Color(0.9, 0.8, 0.6),
	2: Color(0.7, 1.0, 0.7),
	3: Color(0.7, 0.8, 1.0),
	4: Color(0.9, 0.7, 1.0),
}

const CARD_W: float = 148.0
const CARD_H: float = 160.0

var unit_id: String = ""
var unit_data: Dictionary = {}
var is_affordable: bool = true
var is_empty: bool = true

signal card_tapped(unit_id: String)

@onready var _portrait_rect: ColorRect = $Portrait
@onready var _name_label: Label = $NameLabel
@onready var _cost_label: Label = $CostLabel
@onready var _trait_label: Label = $TraitLabel
@onready var _race_label: Label = $RaceLabel
@onready var _overlay: ColorRect = $Overlay
@onready var _tap_area: Button = $TapArea


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
	_overlay.color = Color(0, 0, 0, 0.0 if can_afford else 0.45)
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
	var tier_color: Color = COST_COLORS.get(cost, Color.WHITE)
	var gold_color: Color = COST_GOLD_COLOR.get(cost, Color.WHITE)

	_portrait_rect.color = tier_color.darkened(0.3)
	_name_label.text = unit_data.get("name", "?")
	_name_label.add_theme_color_override("font_color", Color.WHITE)

	_cost_label.text = str(cost) + "g"
	_cost_label.add_theme_color_override("font_color", gold_color)

	var race: String = unit_data.get("race", "")
	var trait: String = unit_data.get("trait", "")
	_race_label.text = race.capitalize()
	_trait_label.text = trait.capitalize()

	_overlay.color = Color(0, 0, 0, 0)
	_tap_area.disabled = false
	queue_redraw()


func _show_empty() -> void:
	_portrait_rect.color = Color(0.12, 0.14, 0.18)
	_name_label.text = ""
	_cost_label.text = ""
	_race_label.text = ""
	_trait_label.text = ""
	_overlay.color = Color(0, 0, 0, 0)
	_tap_area.disabled = true
	queue_redraw()


func _on_tapped() -> void:
	if not is_empty and is_affordable:
		card_tapped.emit(unit_id)


func _draw() -> void:
	if is_empty:
		draw_rect(Rect2(Vector2.ZERO, Vector2(CARD_W, CARD_H)),
			Color(0.12, 0.14, 0.18), true, 0.0)
		draw_rect(Rect2(Vector2.ZERO, Vector2(CARD_W, CARD_H)),
			Color(0.25, 0.28, 0.32), false, 1.5)
		return

	var cost: int = unit_data.get("cost", 1)
	var border_col: Color = COST_COLORS.get(cost, Color.WHITE)

	# Card background
	draw_rect(Rect2(Vector2.ZERO, Vector2(CARD_W, CARD_H)),
		Color(0.10, 0.12, 0.16), true)
	# Border — thicker + colored by cost tier
	draw_rect(Rect2(Vector2.ZERO, Vector2(CARD_W, CARD_H)),
		border_col, false, 2.5)
