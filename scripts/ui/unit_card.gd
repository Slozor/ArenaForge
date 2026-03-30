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
const CARD_FRAME_TEXTURE: Texture2D = preload("res://assets/ui/card_frame.svg")
const UNIT_PORTRAIT_TEXTURE: Texture2D = preload("res://assets/portraits/placeholder_unit.svg")

var unit_id: String = ""
var unit_data: Dictionary = {}
var is_affordable: bool = true
var is_empty: bool = true

signal card_tapped(unit_id)

@onready var _portrait_rect = $Portrait
@onready var _name_label = $NameLabel
@onready var _cost_label = $CostLabel
@onready var _trait_label = $TraitLabel
@onready var _race_label = $RaceLabel
@onready var _overlay = $Overlay
@onready var _tap_area = $TapArea


func _ready() -> void:
	_ensure_frame()
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

	_portrait_rect.texture = UNIT_PORTRAIT_TEXTURE
	_portrait_rect.modulate = tier_color
	_name_label.text = unit_data.get("name", "?")
	_name_label.add_theme_color_override("font_color", Color.WHITE)

	_cost_label.text = str(cost) + "g"
	_cost_label.add_theme_color_override("font_color", gold_color)

	var race: String = unit_data.get("race", "")
	var trait_name: String = unit_data.get("trait", "")
	_race_label.text = race.capitalize()
	_trait_label.text = trait_name.capitalize()

	_overlay.color = Color(0, 0, 0, 0)
	_tap_area.disabled = false
	queue_redraw()


func _show_empty() -> void:
	_portrait_rect.texture = UNIT_PORTRAIT_TEXTURE
	_portrait_rect.modulate = Color(0.12, 0.14, 0.18)
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
	var border_col: Color = Color(0.25, 0.28, 0.32)
	var border_width: float = 1.5
	if not is_empty:
		var cost: int = unit_data.get("cost", 1)
		border_col = COST_COLORS.get(cost, Color.WHITE)
		border_width = 2.5

	draw_rect(Rect2(Vector2.ZERO, Vector2(CARD_W, CARD_H)), border_col, false, border_width)


func _ensure_frame() -> void:
	if get_node_or_null("Frame") != null:
		return
	var frame := TextureRect.new()
	frame.name = "Frame"
	frame.texture = CARD_FRAME_TEXTURE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	move_child(frame, 0)
