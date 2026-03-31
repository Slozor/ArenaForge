extends Control

class_name UnitCard

const DEFAULT_CARD_SIZE := Vector2(148.0, 168.0)
const MIN_CARD_SIZE := Vector2(84.0, 88.0)
const FRAME_TEXTURE: Texture2D = preload("res://assets/ui/card_frame.svg")

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
signal card_hovered(uid: String)
signal card_unhovered(uid: String)

var _portrait: TextureRect = null
var _frame: TextureRect = null
var _name_label: Label = null
var _cost_badge: ColorRect = null
var _cost_label: Label = null
var _trait_row: HBoxContainer = null
var _overlay: ColorRect = null
var _tap_area: Button = null


func _ready() -> void:
	custom_minimum_size = DEFAULT_CARD_SIZE
	mouse_filter = Control.MOUSE_FILTER_PASS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_portrait)

	_frame = TextureRect.new()
	_frame.texture = FRAME_TEXTURE
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_frame.stretch_mode = TextureRect.STRETCH_SCALE
	_frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)

	_cost_badge = ColorRect.new()
	_cost_badge.color = UITheme.BG_PANEL
	_cost_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cost_badge)

	_cost_label = Label.new()
	_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cost_label)

	_name_label = Label.new()
	_name_label.add_theme_color_override("font_color", UITheme.TEXT_PRIMARY)
	_name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_name_label.add_theme_constant_override("shadow_offset_x", 1)
	_name_label.add_theme_constant_override("shadow_offset_y", 1)
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name_label)

	_trait_row = HBoxContainer.new()
	_trait_row.add_theme_constant_override("separation", 3)
	_trait_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_trait_row)

	_overlay = ColorRect.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

	_tap_area = Button.new()
	_tap_area.flat = true
	_tap_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tap_area.pressed.connect(_on_tapped)
	_tap_area.mouse_entered.connect(_on_hovered)
	_tap_area.mouse_exited.connect(_on_unhovered)
	add_child(_tap_area)

	if not resized.is_connected(_layout_children):
		resized.connect(_layout_children)
	_show_empty()
	_layout_children()


func set_card_metrics(card_w: float, card_h: float) -> void:
	custom_minimum_size = Vector2(maxf(MIN_CARD_SIZE.x, card_w), maxf(MIN_CARD_SIZE.y, card_h))
	size = custom_minimum_size
	_layout_children()
	queue_redraw()


func set_unit(id: String) -> void:
	unit_id = id
	unit_data = DataManager.get_unit(id)
	is_empty = unit_data.is_empty()
	tooltip_text = "" if is_empty else DataManager.get_unit_tooltip(unit_id)
	if _tap_area != null:
		_tap_area.tooltip_text = tooltip_text
	_refresh_display()


func set_affordable(can_afford: bool) -> void:
	is_affordable = can_afford
	_overlay.color = Color(0, 0, 0, 0.0 if can_afford else 0.52)
	_tap_area.disabled = is_empty or not can_afford


func clear() -> void:
	unit_id = ""
	unit_data = {}
	is_empty = true
	tooltip_text = ""
	if _tap_area != null:
		_tap_area.tooltip_text = ""
	_show_empty()


func _layout_children() -> void:
	var draw_size: Vector2 = _get_draw_size()
	var pad: float = clampf(draw_size.x * 0.08, 6.0, 14.0)
	var badge_size: float = clampf(draw_size.x * 0.16, 18.0, 24.0)
	var portrait_h: float = draw_size.y * 0.46
	var portrait_rect := Rect2(Vector2(pad, pad + 4.0), Vector2(draw_size.x - pad * 2.0, portrait_h))
	var footer_h: float = clampf(draw_size.y * 0.24, 28.0, 42.0)
	var name_h: float = clampf(draw_size.y * 0.12, 12.0, 18.0)

	_portrait.position = portrait_rect.position
	_portrait.size = portrait_rect.size

	_cost_badge.position = Vector2(draw_size.x - badge_size - 4.0, 4.0)
	_cost_badge.size = Vector2(badge_size, badge_size)
	_cost_badge.custom_minimum_size = _cost_badge.size

	_cost_label.position = _cost_badge.position
	_cost_label.size = _cost_badge.size
	_cost_label.custom_minimum_size = _cost_label.size
	_cost_label.add_theme_font_size_override("font_size", clampi(int(round(draw_size.y * 0.08)), 10, 13))

	_name_label.position = Vector2(pad, draw_size.y - footer_h + 2.0)
	_name_label.size = Vector2(draw_size.x - pad * 2.0, name_h)
	_name_label.custom_minimum_size = _name_label.size
	_name_label.add_theme_font_size_override("font_size", clampi(int(round(draw_size.y * 0.06)), 8, 10))

	_trait_row.position = Vector2(pad, draw_size.y - clampf(draw_size.y * 0.10, 14.0, 20.0))
	_trait_row.size = Vector2(draw_size.x - pad * 2.0, 14.0)
	_trait_row.custom_minimum_size = _trait_row.size


func _refresh_display() -> void:
	if is_empty:
		_show_empty()
		return

	var cost: int = unit_data.get("cost", 1)
	var border: Color = COST_COLORS.get(cost, UITheme.BORDER_MID)
	var label_col: Color = COST_LABEL_COLORS.get(cost, UITheme.TEXT_PRIMARY)

	_portrait.texture = DataManager.get_unit_portrait(unit_id)
	_portrait.modulate = Color.WHITE
	_frame.modulate = border.lightened(0.15)
	_name_label.text = unit_data.get("name", "?")

	_cost_badge.color = border.darkened(0.2)
	_cost_label.text = str(cost)
	_cost_label.add_theme_color_override("font_color", label_col)

	var race: String = str(unit_data.get("race", "")).capitalize()
	var trait_name: String = str(unit_data.get("trait", "")).capitalize()
	_set_trait_row(race, trait_name, border)

	_overlay.color = Color(0, 0, 0, 0.0 if is_affordable else 0.52)
	_tap_area.disabled = not is_affordable
	_layout_children()
	queue_redraw()


func _show_empty() -> void:
	_portrait.texture = null
	_portrait.modulate = UITheme.BG_CARD
	_frame.modulate = UITheme.BG_PANEL
	_name_label.text = ""
	_cost_label.text = ""
	_cost_badge.color = UITheme.BG_PANEL
	_clear_trait_row()
	_overlay.color = Color(0, 0, 0, 0)
	_tap_area.disabled = true
	_layout_children()
	queue_redraw()


func _set_trait_row(race: String, trait_name: String, accent: Color) -> void:
	for child in _trait_row.get_children():
		child.queue_free()
	for t in [race, trait_name]:
		if t == "":
			continue
		var pill := Label.new()
		pill.text = t
		pill.add_theme_font_size_override("font_size", clampi(int(round(_get_draw_size().y * 0.045)), 7, 8))
		pill.add_theme_color_override("font_color", UITheme.TEXT_SECOND)
		var style := UITheme.panel_style(accent.darkened(0.65), accent.darkened(0.35), 3, 1)
		style.content_margin_left = 4
		style.content_margin_right = 4
		style.content_margin_top = 1
		style.content_margin_bottom = 1
		pill.add_theme_stylebox_override("normal", style)
		_trait_row.add_child(pill)


func _clear_trait_row() -> void:
	for child in _trait_row.get_children():
		child.queue_free()


func _on_tapped() -> void:
	if not is_empty and is_affordable:
		card_tapped.emit(unit_id)


func _on_hovered() -> void:
	if not is_empty:
		card_hovered.emit(unit_id)


func _on_unhovered() -> void:
	card_unhovered.emit(unit_id)


func _draw() -> void:
	var draw_size: Vector2 = _get_draw_size()
	var card_w: float = draw_size.x
	var card_h: float = draw_size.y
	var border_col := UITheme.BORDER_SUBTLE
	var border_w := 1.5
	var glow_col := Color(0, 0, 0, 0)

	if not is_empty:
		var cost: int = unit_data.get("cost", 1)
		border_col = COST_COLORS.get(cost, UITheme.BORDER_MID)
		border_w = 2.0
		glow_col = border_col
		glow_col.a = 0.14

	if glow_col.a > 0.0:
		draw_rect(Rect2(Vector2(-2, -2), Vector2(card_w + 4.0, card_h + 4.0)), glow_col, true)

	var portrait_bottom: float = card_h * 0.64
	draw_rect(Rect2(Vector2.ZERO, draw_size), Color(0.03, 0.05, 0.09, 1.0), true)
	draw_rect(Rect2(Vector2(4, 4), Vector2(card_w - 8.0, portrait_bottom - 4.0)), Color(0.10, 0.16, 0.24, 0.96), true)
	draw_rect(Rect2(Vector2(4, card_h - 46.0), Vector2(card_w - 8.0, 42.0)), Color(0.05, 0.08, 0.13, 0.96), true)
	draw_rect(Rect2(Vector2.ZERO, draw_size), border_col, false, border_w)

	if not is_empty:
		draw_rect(Rect2(Vector2(0, 0), Vector2(card_w, 3)), border_col, true)
		draw_rect(Rect2(Vector2(8, 8), Vector2(card_w - 16.0, maxf(18.0, portrait_bottom - 24.0))), Color(1, 1, 1, 0.04), false, 1.0)
		_draw_trait_emblem(border_col)


func _draw_trait_emblem(accent: Color) -> void:
	var trait_id: String = str(unit_data.get("trait", ""))
	var emblem_size: float = clampf(_get_draw_size().x * 0.13, 16.0, 20.0)
	var emblem_rect := Rect2(Vector2(8, 8), Vector2(emblem_size, emblem_size))
	draw_rect(emblem_rect, Color(0.04, 0.06, 0.10, 0.82), true)
	draw_rect(emblem_rect, accent, false, 1.5)
	match trait_id:
		"warrior", "vanguard", "knight", "guardian":
			draw_rect(Rect2(emblem_rect.position + Vector2(5, 4), Vector2(9, 10)), Color(0.92, 0.92, 0.96, 0.95), true)
			draw_rect(Rect2(emblem_rect.position + Vector2(3, 8), Vector2(13, 4)), accent.darkened(0.2), true)
		"ranger":
			draw_line(emblem_rect.position + Vector2(4, emblem_size - 4), emblem_rect.position + Vector2(emblem_size - 4, 4), Color(0.92, 0.92, 0.96, 0.95), 2.0)
			draw_line(emblem_rect.position + Vector2(4, 4), emblem_rect.position + Vector2(emblem_size - 4, emblem_size - 4), accent.lightened(0.2), 2.0)
		"mage", "sorcerer":
			draw_circle(emblem_rect.get_center(), emblem_size * 0.28, Color(0.92, 0.92, 0.96, 0.95))
			draw_circle(emblem_rect.get_center(), emblem_size * 0.14, accent.darkened(0.2))
		"assassin", "duelist":
			draw_line(emblem_rect.position + Vector2(4, emblem_size - 4), emblem_rect.position + Vector2(emblem_size - 4, 4), Color(0.92, 0.92, 0.96, 0.95), 3.0)
			draw_line(emblem_rect.position + Vector2(7, emblem_size - 4), emblem_rect.position + Vector2(emblem_size - 4, 7), accent.lightened(0.25), 1.5)
		_:
			draw_circle(emblem_rect.get_center(), emblem_size * 0.22, Color(0.92, 0.92, 0.96, 0.95))


func _get_draw_size() -> Vector2:
	if size.x > 0.0 and size.y > 0.0:
		return size
	return custom_minimum_size if custom_minimum_size != Vector2.ZERO else DEFAULT_CARD_SIZE
