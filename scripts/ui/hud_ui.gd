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
var _inventory_title: Label = null
var _inventory_row: HBoxContainer = null
var _inventory_slots: Array[TextureRect] = []
var _inventory_slot_bgs: Array[ColorRect] = []
var _inventory_buttons: Array[Button] = []

var _opponent_panel: PanelContainer = null
var _opponent_name: Label = null
var _opponent_round: Label = null
var _opponent_hint: Label = null
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
var _announce_panel: PanelContainer = null
var _announce_title: Label = null
var _announce_body: Label = null

var _augment_panel: PanelContainer = null
var _augment_title: Label = null
var _augment_buttons: Array[Button] = []

var _round_context: Dictionary = {}
var _round_opponent: Dictionary = {}
var _round_lobby: Array = []
var _round_opponent_index: int = 0
var _active_trait_count: int = 0
var _default_inspect_text: String = ""
var _announce_token: int = 0
var _prep_timer_seconds: float = 0.0
var _layout_refreshing: bool = false
var _layout_refresh_pending: bool = false

signal skip_prep_pressed()
signal restart_requested()
signal menu_requested()
signal selection_chosen(kind: String, choice_id: String)


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
	GameManager.encounter_changed.connect(_on_encounter_changed)
	GameManager.run_finished.connect(_on_run_finished)
	if not resized.is_connected(_refresh_layout):
		resized.connect(_queue_refresh_layout)
	_queue_refresh_layout()
	_refresh_overview()


func _queue_refresh_layout() -> void:
	if _layout_refresh_pending:
		return
	_layout_refresh_pending = true
	call_deferred("_run_queued_refresh_layout")


func _run_queued_refresh_layout() -> void:
	_layout_refresh_pending = false
	_refresh_layout()


func _build_ui() -> void:
	_build_top_bar()
	_build_traits()
	_build_inventory()
	_build_opponent_panel()
	_build_inspect()
	_build_loot()
	_build_overlay()
	_build_announce_panel()
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
	_round_label.custom_minimum_size = Vector2(180, 20)
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
	_phase_label.add_theme_font_size_override("font_size", 9)
	_phase_label.add_theme_color_override("font_color", UITheme.TEAL)
	right_box.add_child(_phase_label)

	var counts_row := HBoxContainer.new()
	counts_row.add_theme_constant_override("separation", 6)
	right_box.add_child(counts_row)

	_team_label = Label.new()
	_team_label.add_theme_font_size_override("font_size", 9)
	_team_label.add_theme_color_override("font_color", UITheme.TEXT_SECOND)
	counts_row.add_child(_team_label)

	_bench_label = Label.new()
	_bench_label.add_theme_font_size_override("font_size", 9)
	_bench_label.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	counts_row.add_child(_bench_label)

	_skip_btn = Button.new()
	_skip_btn.text = "Ready"
	_skip_btn.custom_minimum_size = Vector2(88, 28)
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
	_inventory_panel.visible = false
	_inventory_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	add_child(_inventory_panel)
	_inventory_panel.add_child(UITheme.make_nine_patch())

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	_inventory_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	box.add_child(header)

	_inventory_title = Label.new()
	_inventory_title.text = "ITEMS"
	_inventory_title.add_theme_font_size_override("font_size", 9)
	_inventory_title.add_theme_color_override("font_color", UITheme.TEXT_SECOND)
	header.add_child(_inventory_title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var craft_hint := Label.new()
	craft_hint.text = "tap item > item/unit"
	craft_hint.add_theme_font_size_override("font_size", 8)
	craft_hint.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	header.add_child(craft_hint)

	_inventory_row = HBoxContainer.new()
	_inventory_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_inventory_row.add_theme_constant_override("separation", 6)
	box.add_child(_inventory_row)

	for i in GameManager.MAX_INVENTORY_ITEMS:
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(34, 34)
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
		icon.offset_left = 4
		icon.offset_top = 4
		icon.offset_right = -4
		icon.offset_bottom = -4
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

	_opponent_hint = Label.new()
	_opponent_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_opponent_hint.add_theme_font_size_override("font_size", 9)
	_opponent_hint.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	box.add_child(_opponent_hint)

	_opponent_row = HBoxContainer.new()
	_opponent_row.add_theme_constant_override("separation", 6)
	box.add_child(_opponent_row)


func _build_inspect() -> void:
	_inspect_panel = PanelContainer.new()
	_inspect_panel.visible = false
	_inspect_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_inspect_panel.z_as_relative = false
	_inspect_panel.z_index = 240
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
	_inspect_label.custom_minimum_size = Vector2(280, 120)
	margin.add_child(_inspect_label)


func _build_loot() -> void:
	_loot_panel = PanelContainer.new()
	_loot_panel.visible = false
	_loot_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_loot_panel.z_as_relative = false
	_loot_panel.z_index = 235
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


func _build_announce_panel() -> void:
	_announce_panel = PanelContainer.new()
	_announce_panel.visible = false
	_announce_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	add_child(_announce_panel)
	_announce_panel.add_child(UITheme.make_nine_patch())

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	_announce_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	margin.add_child(box)

	_announce_title = Label.new()
	_announce_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_announce_title.add_theme_font_size_override("font_size", 15)
	_announce_title.add_theme_color_override("font_color", UITheme.GOLD_BRIGHT)
	box.add_child(_announce_title)

	_announce_body = Label.new()
	_announce_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_announce_body.add_theme_font_size_override("font_size", 10)
	_announce_body.add_theme_color_override("font_color", UITheme.TEXT_SECOND)
	box.add_child(_announce_body)


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


func _host_rect(host_name: String) -> Rect2:
	var root := get_tree().current_scene
	if root == null:
		return Rect2()
	var host = root.find_child(host_name, true, false)
	if host is Control:
		var control_host: Control = host
		return Rect2(control_host.global_position - global_position, control_host.size)
	return Rect2()


func _refresh_layout() -> void:
	if _layout_refreshing:
		return
	_layout_refreshing = true
	var view_size: Vector2 = get_viewport_rect().size
	var top_rect: Rect2 = _host_rect("TopBarHost")
	var play: Rect2 = _host_rect("PlayAreaHost")
	var trait_host: Rect2 = _host_rect("TraitHost")
	var opponent_host: Rect2 = _host_rect("OpponentHost")
	var item_host: Rect2 = _host_rect("ItemHost")
	if top_rect.size == Vector2.ZERO:
		top_rect = Rect2(Vector2(UITheme.content_left(view_size), UITheme.top_bar_y(view_size)), Vector2(UITheme.content_width(view_size), UITheme.TOP_BAR_HEIGHT))
	if play.size == Vector2.ZERO:
		play = UITheme.play_rect(view_size)
	if trait_host.size == Vector2.ZERO:
		trait_host = Rect2(Vector2(play.position.x, play.position.y), Vector2(UITheme.side_panel_width(view_size), play.size.y))
	if opponent_host.size == Vector2.ZERO:
		opponent_host = Rect2(Vector2(play.end.x - UITheme.side_panel_width(view_size), play.position.y), Vector2(UITheme.side_panel_width(view_size), play.size.y))
	if item_host.size == Vector2.ZERO:
		item_host = Rect2(Vector2(UITheme.item_rail_left(view_size), UITheme.item_y(view_size)), Vector2(UITheme.item_rail_width(view_size), UITheme.ITEM_PANEL_HEIGHT))
	var width: float = top_rect.size.x
	var left_x: float = top_rect.position.x
	var top_y: float = top_rect.position.y
	var compact: bool = UITheme.is_compact(view_size)
	size = view_size

	_top_panel.position = top_rect.position
	_top_panel.size = top_rect.size

	var item_y: float = item_host.position.y
	var board_h: float = play.size.y

	var trait_height: float = 0.0
	var trait_width: float = 0.0
	if _trait_list != null:
		var trait_min: Vector2 = _trait_list.get_combined_minimum_size()
		trait_height = clampf(trait_min.y + 16.0, 30.0, minf(128.0, board_h - 20.0))
		trait_width = clampf(trait_min.x + 18.0, 72.0, 132.0)
	_trait_panel.visible = _active_trait_count > 0 and _trait_list != null and _trait_list.get_child_count() > 0
	if _trait_panel.visible:
		_trait_panel.position = Vector2(trait_host.position.x, trait_host.position.y + 8.0)
		_trait_panel.size = Vector2(minf(trait_width, trait_host.size.x), trait_height)
	else:
		_trait_panel.position = Vector2(-1000, -1000)
		_trait_panel.size = Vector2.ZERO

	var opponent_size: Vector2 = UITheme.opponent_panel_size(view_size)
	var opponent_w: float = opponent_size.x
	_opponent_panel.position = Vector2(opponent_host.position.x + maxf(0.0, opponent_host.size.x - opponent_w), opponent_host.position.y + 44.0)
	_opponent_panel.size = opponent_size

	var inventory_size: int = GameManager.get_item_inventory().size()
	_inventory_panel.visible = inventory_size > 0
	if _inventory_panel.visible:
		_inventory_panel.position = item_host.position
		_inventory_panel.size = item_host.size
	else:
		_inventory_panel.position = Vector2(-1000, -1000)
		_inventory_panel.size = Vector2.ZERO

	if _inspect_panel.visible:
		var inspect_size: Vector2 = UITheme.inspect_panel_size(view_size)
		var inspect_w: float = inspect_size.x
		var inspect_h: float = inspect_size.y
		_inspect_panel.position = Vector2(left_x + width - inspect_w - 16.0, item_y - inspect_h - 12.0)
		_inspect_panel.size = inspect_size
	else:
		_inspect_panel.position = Vector2(-1000, -1000)
		_inspect_panel.size = Vector2.ZERO

	var loot_size: Vector2 = UITheme.loot_panel_size(view_size)
	_loot_panel.position = Vector2(left_x + width - loot_size.x - 16.0, item_y - (88.0 if compact else 96.0))
	_loot_panel.size = loot_size

	_overlay_panel.position = Vector2(left_x + (width - 360.0) * 0.5, top_y + 96.0)
	_overlay_panel.size = Vector2(360, 220)

	_announce_panel.position = Vector2(left_x + (width - 300.0) * 0.5, top_y + UITheme.TOP_BAR_HEIGHT + 12.0)
	_announce_panel.size = Vector2(300, 52)

	_augment_panel.position = Vector2(left_x + (width - 340.0) * 0.5, top_y + 88.0)
	_augment_panel.size = Vector2(340, 180)
	_layout_refreshing = false


func update_synergies(board_units: Array) -> void:
	for child in _trait_list.get_children():
		_trait_list.remove_child(child)
		child.queue_free()
	_trait_entries.clear()
	_active_trait_count = 0

	var unique_counts: Dictionary = {}
	for unit in board_units:
		if unit == null:
			continue
		var unique_unit_id: String = str(unit.unit_id)
		var race_id: String = str(unit.race)
		var trait_id: String = str(unit.trait_id)
		if race_id != "":
			if not unique_counts.has(race_id):
				unique_counts[race_id] = {}
			unique_counts[race_id][unique_unit_id] = true
		if trait_id != "":
			if not unique_counts.has(trait_id):
				unique_counts[trait_id] = {}
			unique_counts[trait_id][unique_unit_id] = true

	for trait_id in unique_counts.keys():
		var count: int = unique_counts[trait_id].size()
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.custom_minimum_size = Vector2(0, 14)
		row.add_theme_constant_override("separation", 6)
		_trait_list.add_child(row)

		var badge := ColorRect.new()
		badge.custom_minimum_size = Vector2(8, 8)
		badge.color = UITheme.GOLD
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(badge)

		var name_lbl := Label.new()
		var trait_data: Dictionary = DataManager.get_trait_data(trait_id)
		name_lbl.text = str(trait_data.get("name", trait_id.capitalize()))
		name_lbl.add_theme_font_size_override("font_size", 10)
		name_lbl.add_theme_color_override("font_color", UITheme.TEXT_PRIMARY)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(name_lbl)

		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(spacer)

		var count_lbl := Label.new()
		count_lbl.text = str(count)
		count_lbl.add_theme_font_size_override("font_size", 10)
		count_lbl.add_theme_color_override("font_color", UITheme.GOLD_BRIGHT)
		count_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(count_lbl)

		row.mouse_entered.connect(_on_trait_hovered.bind(DataManager.get_trait_tooltip(trait_id)))
		row.mouse_exited.connect(_on_hover_exit)
		_active_trait_count += 1

	_refresh_layout()


func set_skip_button_visible(visible_state: bool) -> void:
	if _skip_btn != null:
		_skip_btn.visible = visible_state


func show_round_result(player_won: bool, reason: String = "") -> void:
	_overlay_shade.visible = true
	_overlay_panel.visible = true
	_overlay_title.text = "Victory" if player_won else "Defeat"
	var round_label: String = str(_round_context.get("label", _round_context.get("type", reason))).strip_edges()
	var body_lines: Array[String] = []
	if round_label != "":
		body_lines.append(round_label)
	if player_won:
		body_lines.append("Your board won the fight.")
		if GameManager.has_encounter("second_wind"):
			body_lines.append("Second Wind restored health.")
	else:
		body_lines.append("Your tactician took damage.")
	_overlay_body.text = "\n".join(body_lines)


func hide_round_result() -> void:
	_overlay_shade.visible = false
	_overlay_panel.visible = false


func show_run_summary(summary: Dictionary) -> void:
	_overlay_shade.visible = true
	_overlay_panel.visible = true
	var placement: int = int(summary.get("placement", 8))
	_overlay_title.text = "Victory" if placement <= 1 else "Run Over"
	var augment_count: int = int((summary.get("augments", []) as Array).size())
	var inventory_count: int = int((summary.get("inventory", []) as Array).size())
	var encounter_label: String = str(summary.get("encounter", "")).replace("_", " ").capitalize()
	var reason: String = str(summary.get("reason", "")).replace("_", " ").capitalize()
	_overlay_body.text = "Placement %s\nReason %s\nRound %s\nLevel %s\nHP %s\nGold %s\nEncounter %s\nRecord %d-%d\nGold Earned %d\nItems Earned %d\nSpecial Rounds %d\nAugments %d\nItems Held %d" % [
		str(summary.get("placement", "-")),
		reason if reason != "" else "-",
		str(summary.get("round", "-")),
		str(summary.get("level", "-")),
		str(summary.get("health", "-")),
		str(summary.get("gold", "-")),
		encounter_label if encounter_label != "" else "-",
		int(summary.get("wins", 0)),
		int(summary.get("losses", 0)),
		int(summary.get("gold_earned", 0)),
		int(summary.get("items_earned", 0)),
		int(summary.get("special_rounds", 0)),
		augment_count,
		inventory_count
	]


func hide_run_summary() -> void:
	hide_round_result()


func show_round_intro(round_data: Dictionary, opponent_profile: Dictionary) -> void:
	if _announce_panel == null:
		return
	var label: String = str(round_data.get("label", "Next Round"))
	var subtitle: String = ""
	var round_type: String = str(round_data.get("type", ""))
	if round_type == "npc" or round_type == "combat" or round_type == "creep":
		var opp_name: String = str(opponent_profile.get("name", "Creep Wave"))
		var opp_title: String = str(opponent_profile.get("title", ""))
		var opp_quote: String = str(opponent_profile.get("quote", ""))
		subtitle = opp_name if opp_title == "" else "%s - %s" % [opp_name, opp_title]
		if opp_quote != "":
			subtitle += " | %s" % opp_quote
	elif round_type == "armory":
		subtitle = "Choose one reward package"
	elif round_type == "draft":
		subtitle = "Pick one free recruit"
	elif round_type == "loot":
		subtitle = "Choose the best loot bundle"
	_announce_title.text = label
	_announce_body.text = subtitle
	_announce_panel.visible = true
	_announce_token += 1
	var token: int = _announce_token
	var timer: SceneTreeTimer = get_tree().create_timer(1.8)
	timer.timeout.connect(func():
		if token == _announce_token and _announce_panel != null:
			_announce_panel.visible = false
	)


func _on_health_changed(hp: int) -> void:
	_health_label.text = "♥ %d" % hp


func _on_round_changed(round_num: int) -> void:
	var total_rounds: int = 15
	var root = get_parent()
	if root != null and root.has_method("get_total_rounds"):
		total_rounds = int(root.call("get_total_rounds"))
	_round_label.text = "Round %d / %d" % [round_num, total_rounds]


func _on_gold_changed(_gold: int) -> void:
	_refresh_overview()


func _on_inventory_changed(items: Array[String]) -> void:
	for i in _inventory_slots.size():
		var icon: TextureRect = _inventory_slots[i]
		var bg: ColorRect = _inventory_slot_bgs[i]
		if i < items.size():
			var item_id: String = items[i]
			icon.texture = DataManager.get_item_icon(item_id)
			icon.modulate = Color.WHITE
			bg.color = _item_slot_color(item_id)
		else:
			icon.texture = ITEM_TEXTURE
			icon.modulate = Color(1, 1, 1, 0.0)
			bg.color = Color(UITheme.BG_CARD.r, UITheme.BG_CARD.g, UITheme.BG_CARD.b, 0.55)
	refresh_inventory_selection()
	_refresh_overview()
	_queue_refresh_layout()


func _bind_scene_peers() -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	_board_ui = root.find_child("BoardUI", true, false)
	_bench_ui = root.find_child("BenchUI", true, false)
	_shop_ui = root.find_child("ShopUI", true, false)
	if root.has_signal("phase_changed") and not root.phase_changed.is_connected(_on_phase_changed):
		root.phase_changed.connect(_on_phase_changed)
	if root.has_signal("prep_timer_updated") and not root.prep_timer_updated.is_connected(_on_prep_timer_updated):
		root.prep_timer_updated.connect(_on_prep_timer_updated)
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
	if phase == PREP_PHASE:
		hide_round_result()
		_hide_loot_panel()
		if _augment_panel != null:
			_augment_panel.visible = false
	_refresh_phase_label()
	if phase != PREP_PHASE:
		_selected_item_index = -1
		_prep_timer_seconds = 0.0
		refresh_inventory_selection()
	_refresh_help_text()


func _on_prep_timer_updated(seconds_left: float) -> void:
	_prep_timer_seconds = seconds_left
	_refresh_phase_label()


func _refresh_phase_label() -> void:
	if _phase_label == null:
		return
	if _phase == PREP_PHASE:
		_phase_label.text = "Prep %ds" % int(ceil(_prep_timer_seconds))
	elif _phase == COMBAT_PHASE:
		_phase_label.text = "Fight"
	else:
		_phase_label.text = "End"


func _refresh_overview() -> void:
	_on_health_changed(GameManager.player_health)
	_on_round_changed(GameManager.current_round)
	var item_count: int = GameManager.get_item_inventory_size()
	var augment_count: int = GameManager.get_active_augments().size()
	var encounter: Dictionary = GameManager.get_current_encounter()
	_inventory_label.text = "Items %d/%d" % [item_count, GameManager.MAX_INVENTORY_ITEMS]
	if not encounter.is_empty():
		_augment_label.text = "%s%s" % [
			str(encounter.get("name", "")),
			" | Augments %d" % augment_count if augment_count > 0 else ""
		]
	else:
		_augment_label.text = "Augments %d" % augment_count if augment_count > 0 else ""
	_team_label.text = "%d/%d" % [_get_team_count(), _get_team_capacity()]
	_bench_label.text = "%d/%d" % [_get_bench_count(), _get_bench_capacity()]
	_refresh_opponent_panel()
	_refresh_help_text()
	_queue_refresh_layout()


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


func _on_encounter_changed(_encounter_id: String) -> void:
	_refresh_overview()


func _on_augment_choice_offered(options: Array[String]) -> void:
	_augment_panel.visible = true
	_augment_title.text = "Choose an Augment"
	for i in _augment_buttons.size():
		var button := _augment_buttons[i]
		if i < options.size():
			var augment_id: String = options[i]
			var data: Dictionary = DataManager.get_augment(augment_id)
			button.text = str(data.get("name", augment_id))
			button.tooltip_text = str(data.get("description", ""))
			button.set_meta("choice_kind", "augment")
			button.set_meta("augment_id", augment_id)
			button.set_meta("choice_id", augment_id)
			button.visible = true
		else:
			button.visible = false


func _on_inventory_slot_pressed(index: int) -> void:
	var items: Array[String] = GameManager.get_item_inventory()
	if index >= items.size():
		_selected_item_index = -1
		refresh_inventory_selection()
		_refresh_help_text()
		return
	if _selected_item_index == -1:
		_selected_item_index = index
		refresh_inventory_selection()
		_refresh_help_text()
		return
	if _selected_item_index == index:
		_selected_item_index = -1
		refresh_inventory_selection()
		_refresh_help_text()
		return
	var crafted_item: String = GameManager.craft_inventory_items(_selected_item_index, index)
	_selected_item_index = -1
	refresh_inventory_selection()
	_refresh_help_text()
	if crafted_item != "":
		show_inspect_text("Crafted %s" % crafted_item)
	else:
		show_inspect_text("No valid recipe")


func _on_augment_button_pressed(index: int) -> void:
	if index < 0 or index >= _augment_buttons.size():
		return
	var button: Button = _augment_buttons[index]
	if not button.has_meta("choice_kind") or not button.has_meta("choice_id"):
		return
	var choice_kind: String = str(button.get_meta("choice_kind"))
	var choice_id: String = str(button.get_meta("choice_id"))
	if choice_kind == "augment":
		if GameManager.choose_augment(choice_id):
			_augment_panel.visible = false
		return
	_augment_panel.visible = false
	selection_chosen.emit(choice_kind, choice_id)


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
		_refresh_help_text()
		show_inspect_text("Equipped %s" % unit.unit_name)


func _show_unit_inspect(unit) -> void:
	if unit == null:
		hide_inspect()
		return
	show_inspect_text(DataManager.get_unit_tooltip(unit.unit_id))


func show_inspect_text(text: String) -> void:
	_inspect_label.text = text
	_inspect_panel.visible = text.strip_edges() != ""
	if _inspect_panel.visible:
		_inspect_panel.move_to_front()
		_queue_refresh_layout()


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


func show_reward_choices(title: String, choices: Array[Dictionary]) -> void:
	_augment_panel.visible = true
	_augment_title.text = title
	for i in _augment_buttons.size():
		var button := _augment_buttons[i]
		if i < choices.size():
			var choice: Dictionary = choices[i]
			button.text = str(choice.get("name", choice.get("id", "Choice")))
			button.tooltip_text = str(choice.get("description", ""))
			button.set_meta("choice_kind", str(choice.get("kind", "reward")))
			button.set_meta("choice_id", str(choice.get("id", "")))
			button.visible = true
		else:
			button.visible = false


func _hide_loot_panel() -> void:
	_loot_panel.visible = false


func _on_round_context_changed(round_data: Dictionary, opponent_profile: Dictionary, lobby: Array, opponent_index: int) -> void:
	_round_context = round_data
	_round_opponent = opponent_profile
	_round_lobby = lobby
	_round_opponent_index = opponent_index
	_refresh_opponent_panel()
	_refresh_help_text()
	if _phase == PREP_PHASE:
		show_round_intro(round_data, opponent_profile)


func _refresh_opponent_panel() -> void:
	if _opponent_name == null:
		return
	var opp_name: String = str(_round_opponent.get("name", "Creep Wave"))
	var opp_title: String = str(_round_opponent.get("title", ""))
	var opp_kind: String = str(_round_context.get("label", _round_context.get("kind", "Opening PvE")))
	_opponent_name.text = opp_name if opp_title == "" else "%s - %s" % [opp_name, opp_title]
	_opponent_round.text = opp_kind
	_opponent_hint.text = str(_round_opponent.get("threat", ""))
	for child in _opponent_row.get_children():
		child.queue_free()
	var lobby: Array = _round_context.get("preview_units", [])
	if lobby.is_empty():
		lobby = _round_opponent.get("units", [])
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
	return DataManager.get_item_tooltip(item_id)


func _item_slot_color(item_id: String) -> Color:
	var item: Dictionary = DataManager.get_item(item_id)
	var category: String = str(item.get("category", ""))
	match category:
		"crafted":
			return Color(UITheme.GOLD.r, UITheme.GOLD.g, UITheme.GOLD.b, 0.28)
		"legacy":
			return Color(UITheme.TEAL.r, UITheme.TEAL.g, UITheme.TEAL.b, 0.22)
		_:
			return Color(UITheme.BORDER_MID.r, UITheme.BORDER_MID.g, UITheme.BORDER_MID.b, 0.26)


func is_item_targeting_active() -> bool:
	return _selected_item_index >= 0


func refresh_inventory_selection() -> void:
	for i in _inventory_slot_bgs.size():
		var bg: ColorRect = _inventory_slot_bgs[i]
		var items: Array[String] = GameManager.get_item_inventory()
		if i == _selected_item_index:
			bg.color = Color(UITheme.GOLD_BRIGHT.r, UITheme.GOLD_BRIGHT.g, UITheme.GOLD_BRIGHT.b, 0.65)
		elif i < items.size():
			bg.color = _item_slot_color(items[i])
		else:
			bg.color = Color(UITheme.BG_CARD.r, UITheme.BG_CARD.g, UITheme.BG_CARD.b, 0.55)


func _refresh_help_text() -> void:
	var round_kind: String = str(_round_context.get("type", GameManager.get_round_kind()))
	if _phase == COMBAT_PHASE:
		_default_inspect_text = "Combat is live. Watch casts, target focus, and item procs."
	elif _phase == RESULT_PHASE:
		_default_inspect_text = "Round resolved. Claim rewards, augments, or continue the run."
	elif _selected_item_index >= 0:
		_default_inspect_text = "Tap another item to craft, or tap a unit to equip the selected item."
	else:
		match round_kind:
			"draft":
				_default_inspect_text = "Draft round. Choose one free recruit for your board."
			"armory":
				_default_inspect_text = "Armory round. Pick one reward package of items and gold."
			"loot":
				_default_inspect_text = "Loot round. Choose the bundle that best fits your comp."
			"creep":
				_default_inspect_text = "Prep: buy, place, and press Ready."
			"npc", "combat":
				_default_inspect_text = "Prep: position your team, merge upgrades, and equip items before combat."
				var threat_hint: String = str(_round_opponent.get("reward_hint", ""))
				if threat_hint != "":
					_default_inspect_text += " " + threat_hint
			_:
				_default_inspect_text = "Build your board, manage gold, and prepare for the next fight."
	if _bench_ui != null and _bench_ui.has_method("set_hint_text"):
		_bench_ui.set_hint_text(_default_inspect_text)
