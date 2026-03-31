extends Control

class_name HudUI

const PREP_PHASE: int = 0
const COMBAT_PHASE: int = 1
const RESULT_PHASE: int = 2
const ITEM_TEXTURE: Texture2D = preload("res://assets/items/placeholder_item.svg")
const NPC_AVATAR_TEXTURE: Texture2D = preload("res://assets/ui/npc_avatar.svg")

var _board_ui = null
var _bench_ui = null
var _shop_ui = null
var _phase: int = PREP_PHASE
var _selected_item_index: int = -1

var _top_panel: PanelContainer = null
var _top_patch: NinePatchRect = null
var _health_label: Label = null
var _inventory_label: Label = null
var _augment_label: Label = null
var _round_label: Label = null
var _phase_label: Label = null
var _team_label: Label = null
var _bench_label: Label = null
var _skip_btn: Button = null

var _trait_panel: PanelContainer = null
var _trait_list: VBoxContainer = null
var _trait_entries: Dictionary = {}

var _inventory_panel: PanelContainer = null
var _inventory_row: HBoxContainer = null
var _inventory_slots: Array[TextureRect] = []
var _inventory_slot_bgs: Array[ColorRect] = []
var _inventory_buttons: Array[Button] = []

var _opponent_panel: PanelContainer = null
var _opponent_name: Label = null
var _opponent_round: Label = null
var _opponent_row: HBoxContainer = null

var _inspect_panel: PanelContainer = null
var _inspect_label: Label = null
var _loot_panel: PanelContainer = null
var _loot_label: Label = null

var _overlay_shade: ColorRect = null
var _overlay_panel: PanelContainer = null
var _overlay_title: Label = null
var _overlay_body: Label = null
var _restart_btn: Button = null
var _menu_btn: Button = null

var _augment_panel: PanelContainer = null
var _augment_title: Label = null
var _augment_buttons: Array[Button] = []

var _round_context: Dictionary = {}
var _round_opponent: Dictionary = {}
var _round_lobby: Array = []
var _round_opponent_index: int = 0

signal skip_prep_pressed()
signal restart_requested()
signal menu_requested()


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
	_build_ui()
	_bind_scene_peers()
	GameManager.health_changed.connect(_on_health_changed)
	GameManager.round_changed.connect(_on_round_changed)
	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.inventory_changed.connect(_on_inventory_changed)
	GameManager.augment_choice_offered.connect(_on_augment_choice_offered)
	GameManager.augments_changed.connect(_on_augments_changed)
	GameManager.run_finished.connect(_on_run_finished)
	if not resized.is_connected(_refresh_layout):
		resized.connect(_refresh_layout)
	_refresh_layout()
	_refresh_overview()


func _build_ui() -> void:
	_build_top_bar()
	_build_traits()
	_build_inventory()
	_build_opponent_panel()
	_build_inspect()
	_build_loot()
	_build_overlay()
	_build_augment_panel()


func _build_top_bar() -> void:
	_top_panel = PanelContainer.new()
	_top_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	add_child(_top_panel)

	_top_patch = UITheme.make_nine_patch()
	_top_panel.add_child(_top_patch)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	_top_panel.add_child(margin)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	_health_label = Label.new()
	_health_label.add_theme_font_size_override("font_size", 16)
	_health_label.add_theme_color_override("font_color", UITheme.TEXT_PRIMARY)
	row.add_child(_health_label)

	var inv_box := VBoxContainer.new()
	inv_box.add_theme_constant_override("separation", 0)
	row.add_child(inv_box)

	_inventory_label = Label.new()
	_inventory_label.add_theme_font_size_override("font_size", 10)
	_inventory_label.add_theme_color_override("font_color", UITheme.TEXT_SECOND)
	inv_box.add_child(_inventory_label)

	_augment_label = Label.new()
	_augment_label.add_theme_font_size_override("font_size", 9)
	_augment_label.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	inv_box.add_child(_augment_label)

	var center_spacer := Control.new()
	center_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(center_spacer)

	_round_label = Label.new()
	_round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_round_label.custom_minimum_size = Vector2(260, 22)
	_round_label.add_theme_font_size_override("font_size", 16)
	_round_label.add_theme_color_override("font_color", UITheme.GOLD_BRIGHT)
	row.add_child(_round_label)

	var right_spacer := Control.new()
	right_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right_spacer)

	var right_box := VBoxContainer.new()
	right_box.add_theme_constant_override("separation", 0)
	row.add_child(right_box)

	_phase_label = Label.new()
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_phase_label.add_theme_font_size_override("font_size", 10)
	_phase_label.add_theme_color_override("font_color", UITheme.TEAL)
	right_box.add_child(_phase_label)

	var counts_row := HBoxContainer.new()
	counts_row.add_theme_constant_override("separation", 8)
	right_box.add_child(counts_row)

	_team_label = Label.new()
	_team_label.add_theme_font_size_override("font_size", 10)
	_team_label.add_theme_color_override("font_color", UITheme.TEXT_SECOND)
	counts_row.add_child(_team_label)

	_bench_label = Label.new()
	_bench_label.add_theme_font_size_override("font_size", 10)
	_bench_label.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	counts_row.add_child(_bench_label)

	_skip_btn = Button.new()
	_skip_btn.text = "Ready"
	_skip_btn.custom_minimum_size = Vector2(96, 28)
	_skip_btn.add_theme_stylebox_override("normal", UITheme.button_style(UITheme.GREEN_HP.darkened(0.55), UITheme.GREEN_HP, 6))
	_skip_btn.add_theme_color_override("font_color", UITheme.TEXT_PRIMARY)
	_skip_btn.add_theme_font_size_override("font_size", 12)
	_skip_btn.pressed.connect(func(): skip_prep_pressed.emit())
	row.add_child(_skip_btn)


func _build_traits() -> void:
	_trait_panel = PanelContainer.new()
	_trait_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	add_child(_trait_panel)
	_trait_panel.add_child(UITheme.make_nine_patch())

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	_trait_panel.add_child(margin)

	_trait_list = VBoxContainer.new()
	_trait_list.add_theme_constant_override("separation", 4)
	margin.add_child(_trait_list)


func _build_inventory() -> void:
	_inventory_panel = PanelContainer.new()
	_inventory_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	add_child(_inventory_panel)
	_inventory_panel.add_child(UITheme.make_nine_patch())

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	_inventory_panel.add_child(margin)

	_inventory_row = HBoxContainer.new()
	_inventory_row.add_theme_constant_override("separation", 6)
	margin.add_child(_inventory_row)

	for i in GameManager.MAX_INVENTORY_ITEMS:
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(22, 22)
		_inventory_row.add_child(slot)

		var bg := ColorRect.new()
		bg.color = Color(UITheme.BG_CARD.r, UITheme.BG_CARD.g, UITheme.BG_CARD.b, 0.55)
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slot.add_child(bg)
		_inventory_slot_bgs.append(bg)

		var icon := TextureRect.new()
		icon.texture = ITEM_TEXTURE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 2
		icon.offset_top = 2
		icon.offset_right = -2
		icon.offset_bottom = -2
		icon.modulate = Color(1, 1, 1, 0.0)
		slot.add_child(icon)
		_inventory_slots.append(icon)

		var btn := Button.new()
		btn.flat = true
		btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		btn.pressed.connect(_on_inventory_slot_pressed.bind(i))
		btn.mouse_entered.connect(_on_inventory_slot_hovered.bind(i))
		btn.mouse_exited.connect(hide_inspect)
		slot.add_child(btn)
		_inventory_buttons.append(btn)


func _build_opponent_panel() -> void:
	_opponent_panel = PanelContainer.new()
	_opponent_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	add_child(_opponent_panel)
	_opponent_panel.add_child(UITheme.make_nine_patch())

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_opponent_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	var title := Label.new()
	title.text = "NPC Lobby"
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", UITheme.TEXT_PRIMARY)
	box.add_child(title)

	_opponent_name = Label.new()
	_opponent_name.add_theme_font_size_override("font_size", 14)
	_opponent_name.add_theme_color_override("font_color", UITheme.GOLD_BRIGHT)
	box.add_child(_opponent_name)

	_opponent_round = Label.new()
	_opponent_round.add_theme_font_size_override("font_size", 11)
	_opponent_round.add_theme_color_override("font_color", UITheme.TEXT_SECOND)
	box.add_child(_opponent_round)

	_opponent_row = HBoxContainer.new()
	_opponent_row.add_theme_constant_override("separation", 6)
	box.add_child(_opponent_row)


func _build_inspect() -> void:
	_inspect_panel = PanelContainer.new()
	_inspect_panel.visible = false
	_inspect_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	add_child(_inspect_panel)
	_inspect_panel.add_child(UITheme.make_nine_patch())

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_inspect_panel.add_child(margin)

	_inspect_label = Label.new()
	_inspect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inspect_label.add_theme_font_size_override("font_size", 11)
	_inspect_label.add_theme_color_override("font_color", UITheme.TEXT_PRIMARY)
	margin.add_child(_inspect_label)


func _build_loot() -> void:
	_loot_panel = PanelContainer.new()
	_loot_panel.visible = false
	_loot_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	add_child(_loot_panel)
	_loot_panel.add_child(UITheme.make_nine_patch())

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_loot_panel.add_child(margin)

	_loot_label = Label.new()
	_loot_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_loot_label.add_theme_font_size_override("font_size", 11)
	_loot_label.add_theme_color_override("font_color", UITheme.TEXT_PRIMARY)
	margin.add_child(_loot_label)


func _build_overlay() -> void:
	_overlay_shade = ColorRect.new()
	_overlay_shade.color = Color(0, 0, 0, 0.55)
	_overlay_shade.visible = false
	_overlay_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay_shade)

	_overlay_panel = PanelContainer.new()
	_overlay_panel.visible = false
	_overlay_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	add_child(_overlay_panel)
	_overlay_panel.add_child(UITheme.make_nine_patch())

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_overlay_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	_overlay_title = Label.new()
	_overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_title.add_theme_font_size_override("font_size", 18)
	_overlay_title.add_theme_color_override("font_color", UITheme.GOLD_BRIGHT)
	box.add_child(_overlay_title)

	_overlay_body = Label.new()
	_overlay_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_overlay_body.add_theme_font_size_override("font_size", 12)
	_overlay_body.add_theme_color_override("font_color", UITheme.TEXT_PRIMARY)
	box.add_child(_overlay_body)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 8)
	box.add_child(buttons)

	_restart_btn = Button.new()
	_restart_btn.text = "Play Again"
	_restart_btn.pressed.connect(func(): restart_requested.emit())
	buttons.add_child(_restart_btn)

	_menu_btn = Button.new()
	_menu_btn.text = "Main Menu"
	_menu_btn.pressed.connect(func(): menu_requested.emit())
	buttons.add_child(_menu_btn)


func _build_augment_panel() -> void:
	_augment_panel = PanelContainer.new()
	_augment_panel.visible = false
	_augment_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	add_child(_augment_panel)
	_augment_panel.add_child(UITheme.make_nine_patch())

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	_augment_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	_augment_title = Label.new()
	_augment_title.text = "Choose an Augment"
	_augment_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_augment_title.add_theme_font_size_override("font_size", 16)
	_augment_title.add_theme_color_override("font_color", UITheme.TEAL)
	box.add_child(_augment_title)

	for i in 3:
		var button := Button.new()
		button.visible = false
		button.add_theme_stylebox_override("normal", UITheme.button_style(UITheme.BG_PANEL_ALT, UITheme.TEAL, 6))
		button.add_theme_color_override("font_color", UITheme.TEXT_PRIMARY)
		button.add_theme_font_size_override("font_size", 12)
		button.custom_minimum_size = Vector2(260, 32)
		button.pressed.connect(_on_augment_button_pressed.bind(i))
		box.add_child(button)
		_augment_buttons.append(button)


func _refresh_layout() -> void:
	var view_size: Vector2 = get_viewport_rect().size
	var width: float = minf(maxf(1280.0, view_size.x - UITheme.SCREEN_GUTTER * 2.0), UITheme.CONTENT_MAX_WIDTH)
	var left_x: float = round((view_size.x - width) * 0.5)
	var top_y: float = UITheme.SCREEN_GUTTER
	size = view_size

	_top_panel.position = Vector2(left_x, top_y)
	_top_panel.size = Vector2(width, UITheme.TOP_BAR_HEIGHT)

	var board_top: float = top_y + UITheme.TOP_BAR_HEIGHT + UITheme.UI_STACK_GAP
	var board_bottom: float = view_size.y - UITheme.SCREEN_GUTTER - UITheme.SHOP_PANEL_HEIGHT - UITheme.UI_STACK_GAP - UITheme.BENCH_PANEL_HEIGHT - UITheme.UI_STACK_GAP
	var board_h: float = maxf(220.0, board_bottom - board_top)

	_trait_panel.position = Vector2(left_x, board_top)
	_trait_panel.size = Vector2(120, minf(220.0, board_h))

	_opponent_panel.position = Vector2(left_x + width - 220.0, board_top + 56.0)
	_opponent_panel.size = Vector2(200, 120)

	_inventory_panel.position = Vector2(left_x + 132.0, top_y + 2.0)
	_inventory_panel.size = Vector2(260, 30)

	_inspect_panel.position = Vector2(left_x + width - 260.0, board_top + 186.0)
	_inspect_panel.size = Vector2(240, 140)

	_loot_panel.position = Vector2(left_x + width - 260.0, view_size.y - UITheme.SCREEN_GUTTER - UITheme.SHOP_PANEL_HEIGHT - UITheme.BENCH_PANEL_HEIGHT - 84.0)
	_loot_panel.size = Vector2(240, 74)

	_overlay_panel.position = Vector2(left_x + (width - 360.0) * 0.5, top_y + 96.0)
	_overlay_panel.size = Vector2(360, 220)

	_augment_panel.position = Vector2(left_x + (width - 340.0) * 0.5, top_y + 88.0)
	_augment_panel.size = Vector2(340, 180)


func update_synergies(board_units: Array) -> void:
	for child in _trait_list.get_children():
		child.queue_free()
	_trait_entries.clear()

	var counts: Dictionary = {}
	for unit in board_units:
		if unit == null:
			continue
		var race_id: String = str(unit.race)
		var trait_id: String = str(unit.trait_id)
		if race_id != "":
			counts[race_id] = int(counts.get(race_id, 0)) + 1
		if trait_id != "":
			counts[trait_id] = int(counts.get(trait_id, 0)) + 1

	for trait_id in counts.keys():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_trait_list.add_child(row)

		var badge := ColorRect.new()
		badge.custom_minimum_size = Vector2(8, 8)
		badge.color = UITheme.GOLD
		row.add_child(badge)

		var name_lbl := Label.new()
		var trait_data: Dictionary = DataManager.get_trait_data(trait_id)
		name_lbl.text = str(trait_data.get("name", trait_id.capitalize()))
		name_lbl.add_theme_font_size_override("font_size", 10)
		name_lbl.add_theme_color_override("font_color", UITheme.TEXT_PRIMARY)
		row.add_child(name_lbl)

		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spacer)

		var count_lbl := Label.new()
		count_lbl.text = str(counts[trait_id])
		count_lbl.add_theme_font_size_override("font_size", 10)
		count_lbl.add_theme_color_override("font_color", UITheme.GOLD_BRIGHT)
		row.add_child(count_lbl)

		row.mouse_entered.connect(_on_trait_hovered.bind(DataManager.get_trait_tooltip(trait_id)))


func set_skip_button_visible(visible_state: bool) -> void:
	if _skip_btn != null:
		_skip_btn.visible = visible_state


func show_round_result(player_won: bool, reason: String = "") -> void:
	_overlay_shade.visible = true
	_overlay_panel.visible = true
	_overlay_title.text = "Victory" if player_won else "Defeat"
	_overlay_body.text = reason


func hide_round_result() -> void:
	_overlay_shade.visible = false
	_overlay_panel.visible = false


func show_run_summary(summary: Dictionary) -> void:
	_overlay_shade.visible = true
	_overlay_panel.visible = true
	_overlay_title.text = "Run Over"
	_overlay_body.text = "Placement %s\nRound %s\nLevel %s\nGold %s" % [
		str(summary.get("placement", "-")),
		str(summary.get("round", "-")),
		str(summary.get("level", "-")),
		str(summary.get("gold", "-"))
	]


func hide_run_summary() -> void:
	hide_round_result()


func _on_health_changed(hp: int) -> void:
	_health_label.text = "♥ %d" % hp


func _on_round_changed(round_num: int) -> void:
	_round_label.text = "Round %d / 12" % round_num


func _on_gold_changed(_gold: int) -> void:
	_refresh_overview()


func _on_inventory_changed(items: Array[String]) -> void:
	for i in _inventory_slots.size():
		var icon: TextureRect = _inventory_slots[i]
		var bg: ColorRect = _inventory_slot_bgs[i]
		if i < items.size():
			icon.texture = DataManager.get_item_icon(items[i])
			icon.modulate = Color.WHITE
			bg.color = Color(UITheme.BG_CARD.r, UITheme.BG_CARD.g, UITheme.BG_CARD.b, 0.85)
		else:
			icon.texture = ITEM_TEXTURE
			icon.modulate = Color(1, 1, 1, 0.0)
			bg.color = Color(UITheme.BG_CARD.r, UITheme.BG_CARD.g, UITheme.BG_CARD.b, 0.55)
	refresh_inventory_selection()
	_refresh_overview()


func _bind_scene_peers() -> void:
	var root := get_parent()
	if root == null:
		return
	_board_ui = root.get_node_or_null("BoardUI")
	_bench_ui = root.get_node_or_null("BenchUI")
	_shop_ui = root.get_node_or_null("ShopUI")
	if root.has_signal("phase_changed") and not root.phase_changed.is_connected(_on_phase_changed):
		root.phase_changed.connect(_on_phase_changed)
	if root.has_signal("round_context_changed") and not root.round_context_changed.is_connected(_on_round_context_changed):
		root.round_context_changed.connect(_on_round_context_changed)
	if _board_ui != null:
		if not _board_ui.unit_tapped.is_connected(_on_unit_targeted_for_item):
			_board_ui.unit_tapped.connect(_on_unit_targeted_for_item)
		_board_ui.unit_placed.connect(func(_unit, _col, _row): _refresh_overview())
		_board_ui.unit_moved.connect(func(_unit, _from, _to): _refresh_overview())
	if _bench_ui != null:
		if not _bench_ui.unit_selected_from_bench.is_connected(_on_unit_targeted_for_item):
			_bench_ui.unit_selected_from_bench.connect(_on_unit_targeted_for_item)
		if _bench_ui.has_signal("unit_hovered") and not _bench_ui.unit_hovered.is_connected(_on_bench_unit_hovered):
			_bench_ui.unit_hovered.connect(_on_bench_unit_hovered)
		if _bench_ui.has_signal("unit_unhovered") and not _bench_ui.unit_unhovered.is_connected(_on_hover_exit):
			_bench_ui.unit_unhovered.connect(_on_hover_exit)
	if _shop_ui != null:
		if not _shop_ui.unit_hovered.is_connected(_on_shop_unit_hovered):
			_shop_ui.unit_hovered.connect(_on_shop_unit_hovered)
		if not _shop_ui.unit_unhovered.is_connected(_on_hover_exit):
			_shop_ui.unit_unhovered.connect(_on_hover_exit)


func _on_phase_changed(phase: int) -> void:
	_phase = phase
	_refresh_phase_label()
	if phase != PREP_PHASE:
		_selected_item_index = -1
		refresh_inventory_selection()


func _refresh_phase_label() -> void:
	if _phase_label == null:
		return
	_phase_label.text = "Prep" if _phase == PREP_PHASE else ("Fight" if _phase == COMBAT_PHASE else "End")


func _refresh_overview() -> void:
	_on_health_changed(GameManager.player_health)
	_on_round_changed(GameManager.current_round)
	_inventory_label.text = "Items %d/%d" % [GameManager.get_item_inventory_size(), GameManager.MAX_INVENTORY_ITEMS]
	_augment_label.text = "Augments %d" % GameManager.get_active_augments().size()
	_team_label.text = "%d/%d" % [_get_team_count(), _get_team_capacity()]
	_bench_label.text = "%d/%d" % [_get_bench_count(), _get_bench_capacity()]
	_refresh_opponent_panel()


func _get_team_count() -> int:
	return _board_ui.get_unit_count() if _board_ui != null else 0


func _get_team_capacity() -> int:
	return _board_ui.get_team_capacity() if _board_ui != null else 0


func _get_bench_count() -> int:
	return _bench_ui.get_unit_count() if _bench_ui != null else 0


func _get_bench_capacity() -> int:
	return _bench_ui.get_capacity() if _bench_ui != null else 0


func _on_run_finished(summary: Dictionary) -> void:
	show_run_summary(summary)


func _on_augments_changed(_active_augments: Array[String]) -> void:
	_refresh_overview()


func _on_augment_choice_offered(options: Array[String]) -> void:
	_augment_panel.visible = true
	for i in _augment_buttons.size():
		var button := _augment_buttons[i]
		if i < options.size():
			var augment_id: String = options[i]
			var data: Dictionary = DataManager.get_augment(augment_id)
			button.text = str(data.get("name", augment_id))
			button.tooltip_text = str(data.get("description", ""))
			button.set_meta("augment_id", augment_id)
			button.visible = true
		else:
			button.visible = false


func _on_inventory_slot_pressed(index: int) -> void:
	var items: Array[String] = GameManager.get_item_inventory()
	if index >= items.size():
		_selected_item_index = -1
		refresh_inventory_selection()
		return
	if _selected_item_index == -1:
		_selected_item_index = index
		refresh_inventory_selection()
		return
	if _selected_item_index == index:
		_selected_item_index = -1
		refresh_inventory_selection()
		return
	var crafted_item: String = GameManager.craft_inventory_items(_selected_item_index, index)
	_selected_item_index = -1
	refresh_inventory_selection()
	if crafted_item != "":
		show_inspect_text("Crafted %s" % crafted_item)
	else:
		show_inspect_text("No valid recipe")


func _on_augment_button_pressed(index: int) -> void:
	if index < 0 or index >= _augment_buttons.size():
		return
	var button: Button = _augment_buttons[index]
	if not button.has_meta("augment_id"):
		return
	if GameManager.choose_augment(str(button.get_meta("augment_id"))):
		_augment_panel.visible = false


func _on_inventory_slot_hovered(index: int) -> void:
	var items: Array[String] = GameManager.get_item_inventory()
	if index < 0 or index >= items.size():
		hide_inspect()
		return
	show_inspect_text(_item_tooltip(items[index]))


func _on_unit_targeted_for_item(unit) -> void:
	if unit == null or _selected_item_index < 0:
		return
	if GameManager.equip_inventory_item_to_unit(_selected_item_index, unit):
		_selected_item_index = -1
		refresh_inventory_selection()
		show_inspect_text("Equipped %s" % unit.unit_name)


func _show_unit_inspect(unit) -> void:
	if unit == null:
		hide_inspect()
		return
	show_inspect_text(DataManager.get_unit_tooltip(unit.unit_id))


func show_inspect_text(text: String) -> void:
	_inspect_label.text = text
	_inspect_panel.visible = text != ""


func hide_inspect() -> void:
	if _inspect_panel != null:
		_inspect_panel.visible = false


func _on_hover_exit() -> void:
	hide_inspect()


func _on_shop_unit_hovered(unit_id: String) -> void:
	if unit_id == "":
		hide_inspect()
		return
	show_inspect_text(DataManager.get_unit_tooltip(unit_id))


func _on_trait_hovered(text: String) -> void:
	show_inspect_text(text)


func _on_bench_unit_hovered(unit) -> void:
	_show_unit_inspect(unit)


func show_item_rewards(item_ids: Array[String]) -> void:
	if item_ids.is_empty():
		_loot_panel.visible = false
		return
	var lines: Array[String] = []
	for item_id in item_ids:
		var data: Dictionary = DataManager.get_item(item_id)
		lines.append(str(data.get("name", item_id)))
	_loot_label.text = "Loot: " + ", ".join(lines)
	_loot_panel.visible = true


func _hide_loot_panel() -> void:
	_loot_panel.visible = false


func _on_round_context_changed(round_data: Dictionary, opponent_profile: Dictionary, lobby: Array, opponent_index: int) -> void:
	_round_context = round_data
	_round_opponent = opponent_profile
	_round_lobby = lobby
	_round_opponent_index = opponent_index
	_refresh_opponent_panel()


func _refresh_opponent_panel() -> void:
	if _opponent_name == null:
		return
	var opp_name: String = str(_round_opponent.get("name", "Creep Wave"))
	var opp_kind: String = str(_round_context.get("label", _round_context.get("kind", "Opening PvE")))
	_opponent_name.text = opp_name
	_opponent_round.text = opp_kind
	for child in _opponent_row.get_children():
		child.queue_free()
	var lobby: Array = _round_opponent.get("units", [])
	if lobby.is_empty():
		lobby = ["watchman", "bone_walker"]
	for unit_id in lobby:
		_opponent_row.add_child(_make_unit_chip(str(unit_id)))


func _make_unit_chip(unit_id: String) -> Control:
	var box := Control.new()
	box.custom_minimum_size = Vector2(24, 24)
	var tex := TextureRect.new()
	tex.texture = DataManager.get_unit_portrait(unit_id)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_child(tex)
	return box


func _item_tooltip(item_id: String) -> String:
	var data: Dictionary = DataManager.get_item(item_id)
	if data.is_empty():
		return item_id
	return "%s\n%s" % [str(data.get("name", item_id)), str(data.get("description", ""))]


func is_item_targeting_active() -> bool:
	return _selected_item_index >= 0


func refresh_inventory_selection() -> void:
	for i in _inventory_slot_bgs.size():
		var bg: ColorRect = _inventory_slot_bgs[i]
		bg.color = Color(UITheme.GOLD_BRIGHT.r, UITheme.GOLD_BRIGHT.g, UITheme.GOLD_BRIGHT.b, 0.65) if i == _selected_item_index else Color(UITheme.BG_CARD.r, UITheme.BG_CARD.g, UITheme.BG_CARD.b, 0.55)
