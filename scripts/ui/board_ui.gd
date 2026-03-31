extends Node2D

class_name BoardUI

const BOARD_TILE_TEXTURE: Texture2D = preload("res://assets/ui/board_tile.svg")
const BOARD_TILE_FRONT_TEXTURE: Texture2D = preload("res://assets/ui/board_tile_front.svg")
const BOARD_TILE_SELECTED_TEXTURE: Texture2D = preload("res://assets/ui/board_tile_selected.svg")
const ARENA_OUTER_TILE: Texture2D = preload("res://assets/kenney_ui_pixel_adventure/tile_0001.png")
const ARENA_SAND_TILE: Texture2D = preload("res://assets/kenney_tiny_dungeon/Tiles/tile_0048.png")
const ARENA_SAND_DETAIL_TILE: Texture2D = preload("res://assets/kenney_tiny_dungeon/Tiles/tile_0049.png")
const ARENA_SAND_ACCENT_TILE: Texture2D = preload("res://assets/kenney_tiny_dungeon/Tiles/tile_0050.png")
const ARENA_STONE_TOP_LEFT: Texture2D = preload("res://assets/kenney_tiny_dungeon/Tiles/tile_0037.png")
const ARENA_STONE_TOP: Texture2D = preload("res://assets/kenney_tiny_dungeon/Tiles/tile_0038.png")
const ARENA_STONE_TOP_RIGHT: Texture2D = preload("res://assets/kenney_tiny_dungeon/Tiles/tile_0040.png")
const ARENA_STONE_BOTTOM_LEFT: Texture2D = preload("res://assets/kenney_tiny_dungeon/Tiles/tile_0036.png")
const ARENA_STONE_BOTTOM: Texture2D = preload("res://assets/kenney_tiny_dungeon/Tiles/tile_0039.png")
const ARENA_STONE_BOTTOM_RIGHT: Texture2D = preload("res://assets/kenney_tiny_dungeon/Tiles/tile_0040.png")
const ARENA_TORCH: Texture2D = preload("res://assets/kenney_tiny_dungeon/Tiles/tile_0053.png")

const COLS: int = 7
const ROWS: int = 4
const CELL_SIZE: float = 96.0
const BOARD_OFFSET: Vector2 = Vector2(304.0, 55.0)  # centered in 1280x720, below HUD (50px)
const PREP_PHASE: int = 0
const COMBAT_PHASE: int = 1
const HEX_RADIUS_RATIO: float = 0.43

enum InputState { IDLE, UNIT_SELECTED }

var input_state: InputState = InputState.IDLE
var selected_unit = null
var selected_from_cell: Vector2i = Vector2i(-1, -1)
var selected_from_bench: bool = false
var team_capacity: int = 5
var _interaction_enabled: bool = true
var _bench_ui = null
var _hud_ui = null
var _shop_ui = null
var _board_offset: Vector2 = BOARD_OFFSET
var _cell_size: float = CELL_SIZE
var _label_font_size: int = 13
var _play_rect: Rect2 = Rect2()
var _hovered_unit = null
var _tooltip_panel: PanelContainer = null
var _tooltip_label: Label = null

# Grid: [col][row] -> Unit or null
var grid: Array = []

signal unit_placed(unit, col: int, row: int)
signal unit_moved(unit, from: Vector2i, to: Vector2i)
signal unit_sent_to_bench(unit)
signal unit_tapped(unit)

@onready var highlight_layer: Node2D = $HighlightLayer
@onready var cell_highlights: Array = []


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_initialize_grid()
	_build_tooltip()
	_bind_scene_peers()
	if not get_viewport().size_changed.is_connected(_refresh_layout):
		get_viewport().size_changed.connect(_refresh_layout)
	_refresh_layout()
	_draw_board()


func _build_tooltip() -> void:
	_tooltip_panel = PanelContainer.new()
	_tooltip_panel.visible = false
	_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tooltip_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	_tooltip_panel.add_child(margin)

	_tooltip_label = Label.new()
	_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip_label.custom_minimum_size = Vector2(220, 0)
	_tooltip_label.add_theme_font_size_override("font_size", 12)
	margin.add_child(_tooltip_label)


func _initialize_grid() -> void:
	grid.resize(COLS)
	for col in COLS:
		grid[col] = []
		grid[col].resize(ROWS)
		for row in ROWS:
			grid[col][row] = null


# Called by bench UI when a unit is tapped on the bench
func select_unit_from_bench(unit) -> void:
	_set_selected(unit, Vector2i(-1, -1), true)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_hovered_unit(event.position)
		return

	var tap_pos: Vector2 = Vector2.ZERO
	var is_tap: bool = false

	if event is InputEventScreenTouch and event.pressed:
		tap_pos = event.position
		is_tap = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tap_pos = event.position
		is_tap = true

	if not is_tap:
		return

	var tapped_unit = _find_unit_at_position(tap_pos)

	if not _interaction_enabled:
		if tapped_unit != null:
			unit_tapped.emit(tapped_unit)
		return

	var cell: Vector2i = _world_to_cell(tap_pos)
	var on_board: bool = _is_valid_cell(cell.x, cell.y)

	match input_state:
		InputState.IDLE:
			if tapped_unit != null:
				unit_tapped.emit(tapped_unit)
				if tapped_unit.is_enemy_unit:
					return
				if _hud_ui != null and _hud_ui.is_item_targeting_active():
					return
				if on_board and grid[cell.x][cell.y] == tapped_unit:
					_set_selected(tapped_unit, cell, false)

		InputState.UNIT_SELECTED:
			if on_board:
				if cell == selected_from_cell and not selected_from_bench:
					# Tap same cell again → deselect
					_clear_selection()
				elif grid[cell.x][cell.y] != null:
					# Swap with existing unit if the bench can accept the displaced unit.
					if _can_send_unit_to_bench(grid[cell.x][cell.y]):
						_swap_units(cell)
				else:
					# Place on empty cell
					_place_selected_unit(cell)
			else:
				# Tapped outside board → send back to bench
				if not selected_from_bench and _can_send_unit_to_bench(selected_unit):
					_remove_from_board(selected_from_cell)
					unit_sent_to_bench.emit(selected_unit)
				_clear_selection()


func _set_selected(unit, from_cell: Vector2i, from_bench: bool) -> void:
	selected_unit = unit
	selected_from_cell = from_cell
	selected_from_bench = from_bench
	input_state = InputState.UNIT_SELECTED
	_highlight_valid_cells()


func _place_selected_unit(to_cell: Vector2i) -> void:
	if selected_from_bench and get_unit_count() >= team_capacity:
		return

	if not selected_from_bench:
		grid[selected_from_cell.x][selected_from_cell.y] = null

	grid[to_cell.x][to_cell.y] = selected_unit
	selected_unit.board_position = to_cell
	selected_unit.is_on_bench = false
	selected_unit.visible = true
	selected_unit.position = _cell_to_world(to_cell.x, to_cell.y)

	if selected_from_bench:
		unit_placed.emit(selected_unit, to_cell.x, to_cell.y)
	else:
		unit_moved.emit(selected_unit, selected_from_cell, to_cell)

	_clear_selection()


func _swap_units(to_cell: Vector2i) -> void:
	var other_unit = grid[to_cell.x][to_cell.y]

	grid[to_cell.x][to_cell.y] = selected_unit
	selected_unit.board_position = to_cell
	selected_unit.position = _cell_to_world(to_cell.x, to_cell.y)

	if selected_from_bench:
		other_unit.is_on_bench = true
		other_unit.board_position = Vector2i(-1, -1)
		other_unit.visible = false
		unit_sent_to_bench.emit(other_unit)
		unit_placed.emit(selected_unit, to_cell.x, to_cell.y)
	else:
		grid[selected_from_cell.x][selected_from_cell.y] = other_unit
		other_unit.board_position = selected_from_cell
		other_unit.position = _cell_to_world(selected_from_cell.x, selected_from_cell.y)
		unit_moved.emit(selected_unit, selected_from_cell, to_cell)

	_clear_selection()


func _remove_from_board(cell: Vector2i) -> void:
	if _is_valid_cell(cell.x, cell.y):
		var unit = grid[cell.x][cell.y]
		if unit != null:
			grid[cell.x][cell.y] = null
			unit.is_on_bench = true
			unit.board_position = Vector2i(-1, -1)
			unit.visible = false


func _clear_selection() -> void:
	selected_unit = null
	selected_from_cell = Vector2i(-1, -1)
	selected_from_bench = false
	input_state = InputState.IDLE
	_clear_highlights()


func get_all_placed_units() -> Array:
	var result: Array = []
	for col in COLS:
		for row in ROWS:
			if grid[col][row] != null:
				result.append(grid[col][row])
	return result


func _update_hovered_unit(pointer_pos: Vector2) -> void:
	_hovered_unit = _find_unit_at_position(pointer_pos)
	_update_tooltip(pointer_pos)


func _update_tooltip(pointer_pos: Vector2) -> void:
	if _tooltip_panel == null or _tooltip_label == null:
		return
	if _hovered_unit == null:
		_tooltip_panel.visible = false
		if _hud_ui != null and _hud_ui.has_method("hide_inspect"):
			_hud_ui.call("hide_inspect")
		return
	var tooltip_text: String = DataManager.get_unit_tooltip(_hovered_unit.unit_id)
	_tooltip_label.text = tooltip_text
	_tooltip_panel.visible = true
	if _hud_ui != null and _hud_ui.has_method("show_inspect_text"):
		_hud_ui.call("show_inspect_text", tooltip_text)
	var tooltip_pos: Vector2 = pointer_pos + Vector2(16, 16)
	var view_size: Vector2 = get_viewport_rect().size
	_tooltip_panel.position = tooltip_pos
	var panel_size: Vector2 = _tooltip_panel.get_combined_minimum_size()
	if tooltip_pos.x + panel_size.x > view_size.x - 8.0:
		_tooltip_panel.position.x = view_size.x - panel_size.x - 8.0
	if tooltip_pos.y + panel_size.y > view_size.y - 8.0:
		_tooltip_panel.position.y = tooltip_pos.y - panel_size.y - 24.0


func remove_unit_instance(unit) -> bool:
	if unit == null:
		return false
	for col in COLS:
		for row in ROWS:
			if grid[col][row] == unit:
				grid[col][row] = null
				unit.board_position = Vector2i(-1, -1)
				unit.visible = false
				queue_redraw()
				return true
	return false


func _find_unit_at_position(pointer_pos: Vector2):
	var closest_unit = null
	var closest_dist_sq: float = 1600.0
	for child in get_children():
		if child == null or not is_instance_valid(child):
			continue
		if not (child is Node2D):
			continue
		if not child.has_method("get_attack_damage"):
			continue
		if not child.visible:
			continue
		var dist_sq: float = child.position.distance_squared_to(pointer_pos)
		if dist_sq <= closest_dist_sq:
			closest_dist_sq = dist_sq
			closest_unit = child
	return closest_unit


func get_unit_count() -> int:
	return get_all_placed_units().size()


func get_team_capacity() -> int:
	return team_capacity


func set_team_capacity(value: int) -> void:
	team_capacity = maxi(1, value)
	if get_unit_count() > team_capacity:
		team_capacity = get_unit_count()
	queue_redraw()


func cell_to_world(col: int, row: int) -> Vector2:
	return _cell_to_world(col, row)


func combat_cell_to_world(col: int, row: int) -> Vector2:
	var combat_cell_h: float = _cell_size * 0.50
	return _board_offset + Vector2(col * _cell_size + _cell_size * 0.5, row * combat_cell_h + combat_cell_h * 0.5)


func _cell_to_world(col: int, row: int) -> Vector2:
	return _board_offset + Vector2(col * _cell_size + _cell_size * 0.5, row * _cell_size + _cell_size * 0.5)


func _world_to_cell(world_pos: Vector2) -> Vector2i:
	var local: Vector2 = world_pos - _board_offset
	return Vector2i(int(local.x / _cell_size), int(local.y / _cell_size))


func _is_valid_cell(col: int, row: int) -> bool:
	return col >= 0 and col < COLS and row >= 0 and row < ROWS


func _draw_board() -> void:
	queue_redraw()


func _draw() -> void:
	var board_rect := Rect2(_board_offset - Vector2(22, 22), Vector2(COLS * _cell_size + 44, ROWS * _cell_size + 44))
	var arena_rect := _play_rect
	_draw_tiled_texture(ARENA_OUTER_TILE, arena_rect, 48.0)
	draw_rect(arena_rect, Color(0.92, 0.74, 0.28, 0.22), false, 2.0)
	var inner_outer_rect: Rect2 = Rect2(arena_rect.position + Vector2(18, 18), arena_rect.size - Vector2(36, 36))
	_draw_tiled_texture(ARENA_OUTER_TILE, inner_outer_rect, 48.0, Color(1, 1, 1, 0.18))
	_draw_arena_ground(board_rect)
	draw_rect(board_rect, Color(0.92, 0.74, 0.28, 0.92), false, 2.0)
	draw_rect(Rect2(board_rect.position + Vector2(8, 8), board_rect.size - Vector2(16, 16)), Color(0.22, 0.75, 0.95, 0.18), false, 1.0)
	_draw_lane_labels()

	for col in COLS:
		for row in ROWS:
			var center: Vector2 = _cell_to_world(col, row)
			var tile_rect: Rect2 = Rect2(center - Vector2(_cell_size * 0.5, _cell_size * 0.5), Vector2(_cell_size, _cell_size))
			var tile_texture: Texture2D = BOARD_TILE_FRONT_TEXTURE if row == ROWS - 1 else BOARD_TILE_TEXTURE
			draw_texture_rect(tile_texture, tile_rect, false, Color(1, 1, 1, 0.78))

			if selected_unit != null and selected_from_bench and grid[col][row] == null:
				draw_texture_rect(BOARD_TILE_SELECTED_TEXTURE, tile_rect, false, Color(0.30, 0.95, 0.82, 0.55))
			elif selected_unit != null and not selected_from_bench and Vector2i(col, row) == selected_from_cell:
				draw_texture_rect(BOARD_TILE_SELECTED_TEXTURE, tile_rect, false, Color(1.0, 1.0, 1.0, 0.92))


func _draw_arena_wings(_board_rect: Rect2) -> void:
	return


func _draw_arena_ground(board_rect: Rect2) -> void:
	var tile_size: float = 32.0
	var cols: int = int(ceil(board_rect.size.x / tile_size))
	var rows: int = int(ceil(board_rect.size.y / tile_size))
	for y in rows:
		for x in cols:
			var pos: Vector2 = board_rect.position + Vector2(x * tile_size, y * tile_size)
			var rect: Rect2 = Rect2(pos, Vector2(tile_size, tile_size))
			var texture: Texture2D = ARENA_SAND_TILE
			if y == 0 and x == 0:
				texture = ARENA_STONE_TOP_LEFT
			elif y == 0 and x == cols - 1:
				texture = ARENA_STONE_TOP_RIGHT
			elif y == rows - 1 and x == 0:
				texture = ARENA_STONE_BOTTOM_LEFT
			elif y == rows - 1 and x == cols - 1:
				texture = ARENA_STONE_BOTTOM_RIGHT
			elif y == 0:
				texture = ARENA_STONE_TOP
			elif y == rows - 1:
				texture = ARENA_STONE_BOTTOM
			elif x == 0 or x == cols - 1:
				texture = ARENA_SAND_TILE
			else:
				if (x + y) % 7 == 0:
					texture = ARENA_SAND_DETAIL_TILE
				elif (x + y) % 11 == 0:
					texture = ARENA_SAND_ACCENT_TILE
			draw_texture_rect(texture, rect, false)

	var side_tile_rect: Rect2 = Rect2(board_rect.position + Vector2(tile_size, tile_size), Vector2(tile_size, tile_size))
	var right_tile_rect: Rect2 = Rect2(board_rect.position + Vector2(board_rect.size.x - tile_size * 2.0, tile_size), Vector2(tile_size, tile_size))
	draw_texture_rect(ARENA_TORCH, side_tile_rect, false)
	draw_texture_rect(ARENA_TORCH, right_tile_rect, false)


func _draw_tiled_texture(texture: Texture2D, rect: Rect2, tile_size: float = 16.0, tint: Color = Color.WHITE) -> void:
	if texture == null:
		return
	var cols: int = int(ceil(rect.size.x / tile_size))
	var rows: int = int(ceil(rect.size.y / tile_size))
	for y in rows:
		for x in cols:
			var tile_rect: Rect2 = Rect2(rect.position + Vector2(x * tile_size, y * tile_size), Vector2(tile_size, tile_size))
			draw_texture_rect(texture, tile_rect, false, tint)


func _highlight_valid_cells() -> void:
	queue_redraw()


func _clear_highlights() -> void:
	queue_redraw()


func _draw_lane_labels() -> void:
	var backline_pos := _board_offset + Vector2(8, 8)
	var frontline_pos := _board_offset + Vector2(8, float((ROWS - 1) * _cell_size) + 8)
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	draw_string(font, backline_pos, "Backline", HORIZONTAL_ALIGNMENT_LEFT, -1, _label_font_size, Color(0.72, 0.82, 0.95, 0.78))
	draw_string(font, frontline_pos, "Frontline", HORIZONTAL_ALIGNMENT_LEFT, -1, _label_font_size, Color(0.90, 0.84, 0.66, 0.78))


func _bind_scene_peers() -> void:
	var root: Node = get_parent()
	if root == null:
		root = get_tree().current_scene
	if root == null:
		return

	_bench_ui = root.get_node_or_null("BenchUI")
	_hud_ui = root.get_node_or_null("HudUI")
	_shop_ui = root.get_node_or_null("ShopUI")

	if root.has_signal("phase_changed") and not root.phase_changed.is_connected(_on_phase_changed):
		root.phase_changed.connect(_on_phase_changed)

	if _bench_ui != null:
		if not _bench_ui.unit_selected_from_bench.is_connected(select_unit_from_bench):
			_bench_ui.unit_selected_from_bench.connect(select_unit_from_bench)
		if not unit_placed.is_connected(_on_unit_placed_on_board):
			unit_placed.connect(_on_unit_placed_on_board)
		if not unit_sent_to_bench.is_connected(_on_unit_sent_to_bench):
			unit_sent_to_bench.connect(_on_unit_sent_to_bench)

	_on_phase_changed(PREP_PHASE)


func _refresh_layout() -> void:
	var view_size: Vector2 = get_viewport_rect().size
	var content_w: float = minf(maxf(640.0, view_size.x - UITheme.SCREEN_GUTTER * 2.0), UITheme.CONTENT_MAX_WIDTH)
	var content_x: float = round((view_size.x - content_w) * 0.5)
	var side_pad: float = clampf(content_w * 0.010, 8.0, 18.0)
	var side_column: float = clampf(content_w * 0.11, 72.0, 132.0)
	var top_margin: float = UITheme.TOP_BAR_HEIGHT + UITheme.UI_STACK_GAP
	var shop_y: float = view_size.y - UITheme.SHOP_PANEL_HEIGHT - UITheme.SCREEN_GUTTER
	var bench_y: float = shop_y - UITheme.BENCH_PANEL_HEIGHT - UITheme.UI_STACK_GAP
	var bottom_limit: float = bench_y - UITheme.UI_STACK_GAP - 6.0
	_play_rect = Rect2(Vector2(content_x, top_margin), Vector2(content_w, maxf(200.0, bottom_limit - top_margin)))
	var left_margin: float = side_column + side_pad
	var right_margin: float = side_column + side_pad
	var usable_w: float = maxf(280.0, _play_rect.size.x - left_margin - right_margin)
	var usable_h: float = maxf(220.0, _play_rect.size.y - 2.0)
	_cell_size = round(clampf(minf(usable_w / float(COLS), usable_h / float(ROWS)), 72.0, 168.0))
	var board_w: float = float(COLS) * _cell_size
	var board_h: float = float(ROWS) * _cell_size
	_board_offset = Vector2(
		round(_play_rect.position.x + (_play_rect.size.x - board_w) * 0.5),
		round(_play_rect.position.y + (_play_rect.size.y - board_h) * 0.40)
	)
	_label_font_size = int(clampf(_cell_size * 0.14, 10.0, 14.0))
	for child in get_children():
		if child == null or not is_instance_valid(child):
			continue
		if not (child is Node2D):
			continue
		if not child.has_method("get_attack_damage"):
			continue
		if child.has_method("set"):
			child.set("unit_visual_scale", clampf(_cell_size / 72.0, 1.3, 2.4))
		if bool(child.get("is_enemy_unit")) or child.board_position.y >= ROWS:
			child.position = combat_cell_to_world(child.board_position.x, child.board_position.y)
		elif child.board_position.x >= 0 and child.board_position.y >= 0:
			child.position = _cell_to_world(child.board_position.x, child.board_position.y)
	queue_redraw()


func _on_phase_changed(phase: int) -> void:
	_interaction_enabled = phase == PREP_PHASE
	if not _interaction_enabled:
		_clear_selection()
	_hovered_unit = null
	_update_tooltip(Vector2.ZERO)
	queue_redraw()


func _on_unit_placed_on_board(unit, _col: int, _row: int) -> void:
	if _bench_ui != null:
		_bench_ui.on_unit_placed_on_board(unit)


func _on_unit_sent_to_bench(unit) -> void:
	if _bench_ui != null:
		_bench_ui.receive_unit_from_board(unit)


func _can_send_unit_to_bench(unit) -> bool:
	if unit == null:
		return false
	if _bench_ui == null:
		return false
	return _bench_ui.can_accept_unit(unit)


func _hex_points(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 6:
		var angle: float = deg_to_rad(60.0 * i - 30.0)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points


func _draw_hex_outline(points: PackedVector2Array, color: Color, width: float) -> void:
	for i in points.size():
		var next_index: int = (i + 1) % points.size()
		draw_line(points[i], points[next_index], color, width)
