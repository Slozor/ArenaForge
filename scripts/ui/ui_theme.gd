extends RefCounted

class_name UITheme

const PANEL_9SLICE: Texture2D = preload("res://assets/ui/panel_9slice.svg")

# ── Backgrounds ──────────────────────────────────────────────────────────────
const BG_DARK       := Color(0.04, 0.055, 0.09, 1.0)   # #0A0E17 — main bg
const BG_PANEL      := Color(0.07, 0.10,  0.16, 0.97)  # #121A28 — panels
const BG_PANEL_ALT  := Color(0.10, 0.14,  0.21, 0.97)  # #1A2435 — hover/alt
const BG_CARD       := Color(0.08, 0.11,  0.18, 1.0)   # #15202E — card bg

# ── Borders ───────────────────────────────────────────────────────────────────
const BORDER_SUBTLE := Color(0.18, 0.25,  0.34, 1.0)   # #2E4057
const BORDER_MID    := Color(0.28, 0.38,  0.50, 1.0)   # #476180
const BORDER_BRIGHT := Color(0.42, 0.56,  0.70, 1.0)   # #6B8FB3

# ── Text ──────────────────────────────────────────────────────────────────────
const TEXT_PRIMARY  := Color(0.94, 0.90, 0.82, 1.0)    # #F0E6D2 — TFT cream
const TEXT_SECOND   := Color(0.62, 0.72, 0.82, 1.0)    # #9EB8D1
const TEXT_DIM      := Color(0.42, 0.50, 0.60, 1.0)    # #6B8099

# ── Accents ───────────────────────────────────────────────────────────────────
const GOLD          := Color(0.78, 0.61, 0.24, 1.0)    # #C79B3D — TFT gold
const GOLD_BRIGHT   := Color(0.96, 0.82, 0.38, 1.0)    # #F5D261
const TEAL          := Color(0.04, 0.76, 0.89, 1.0)    # #0AC2E3 — Hextech
const GREEN_HP      := Color(0.18, 0.76, 0.32, 1.0)    # #2EC252
const RED_HP        := Color(0.90, 0.22, 0.22, 1.0)    # #E63838

# ── Cost tier card borders ────────────────────────────────────────────────────
const COST_1 := Color(0.55, 0.55, 0.58, 1.0)  # gray
const COST_2 := Color(0.07, 0.60, 0.22, 1.0)  # green
const COST_3 := Color(0.18, 0.45, 0.88, 1.0)  # blue
const COST_4 := Color(0.58, 0.12, 0.82, 1.0)  # purple

const COST_COLORS: Array = [
	Color.TRANSPARENT, COST_1, COST_2, COST_3, COST_4
]

const COST_GLOW: Array = [
	Color.TRANSPARENT,
	Color(0.70, 0.70, 0.72, 0.35),
	Color(0.10, 0.75, 0.30, 0.35),
	Color(0.25, 0.55, 1.00, 0.35),
	Color(0.70, 0.18, 1.00, 0.35),
]

# ── Trait tier badge colors ───────────────────────────────────────────────────
const TRAIT_INACTIVE := Color(0.22, 0.28, 0.36, 1.0)   # #384858
const TRAIT_BRONZE   := Color(0.55, 0.37, 0.22, 1.0)   # #8C5E38
const TRAIT_SILVER   := Color(0.55, 0.62, 0.70, 1.0)   # #8C9EB3
const TRAIT_GOLD_C   := Color(0.78, 0.61, 0.24, 1.0)   # same as GOLD

# ── Board ─────────────────────────────────────────────────────────────────────
const BOARD_TILE        := Color(0.09, 0.13, 0.21, 1.0)   # #17213A
const BOARD_TILE_HOVER  := Color(0.14, 0.20, 0.32, 1.0)
const BOARD_TILE_SELECT := Color(0.04, 0.76, 0.89, 0.25)  # teal highlight
const BOARD_BORDER      := Color(0.20, 0.30, 0.45, 0.85)

# ── Layout rhythm (base 1280x720 viewport) ──────────────────────────────────
const TOP_BAR_HEIGHT := 40.0
const SHOP_PANEL_HEIGHT := 60.0
const BENCH_PANEL_HEIGHT := 72.0
const ITEM_PANEL_HEIGHT := 44.0
const UI_STACK_GAP := 12.0
const SCREEN_GUTTER := 16.0
const BOTTOM_GUTTER := 18.0
const LOWER_RAIL_LIFT := 104.0
const CONTENT_MAX_WIDTH := 1728.0
const RAIL_MAX_WIDTH := 780.0
const ITEM_RAIL_MAX_WIDTH := 520.0


static func content_width(view_size: Vector2) -> float:
	return minf(maxf(320.0, view_size.x - SCREEN_GUTTER * 2.0), CONTENT_MAX_WIDTH)


static func content_left(view_size: Vector2) -> float:
	var width: float = content_width(view_size)
	return round((view_size.x - width) * 0.5)


static func rail_width(view_size: Vector2) -> float:
	return minf(content_width(view_size) * 0.66, RAIL_MAX_WIDTH)


static func rail_left(view_size: Vector2) -> float:
	var width: float = rail_width(view_size)
	return round((view_size.x - width) * 0.5)


static func item_rail_width(view_size: Vector2) -> float:
	return minf(content_width(view_size) * 0.42, ITEM_RAIL_MAX_WIDTH)


static func item_rail_left(view_size: Vector2) -> float:
	var width: float = item_rail_width(view_size)
	return round((view_size.x - width) * 0.5)


# ── Helper: build a StyleBoxFlat ──────────────────────────────────────────────
static func panel_style(
	bg: Color = BG_PANEL,
	border: Color = BORDER_SUBTLE,
	radius: int = 6,
	border_w: int = 1
) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.border_width_top    = border_w
	s.border_width_bottom = border_w
	s.border_width_left   = border_w
	s.border_width_right  = border_w
	s.corner_radius_top_left     = radius
	s.corner_radius_top_right    = radius
	s.corner_radius_bottom_left  = radius
	s.corner_radius_bottom_right = radius
	return s


static func button_style(
	bg: Color,
	border: Color = BORDER_MID,
	radius: int = 6
) -> StyleBoxFlat:
	return panel_style(bg, border, radius, 1)


static func build_theme() -> Theme:
	var theme := Theme.new()
	theme.set_default_font_size(12)
	theme.set_color("font_color", "Label", TEXT_PRIMARY)
	theme.set_color("font_color", "Button", TEXT_PRIMARY)
	theme.set_color("font_pressed_color", "Button", TEXT_PRIMARY)
	theme.set_constant("outline_size", "Label", 0)
	theme.set_stylebox("panel", "PanelContainer", panel_style())
	theme.set_stylebox("normal", "Button", button_style(BG_PANEL_ALT, BORDER_MID, 6))
	theme.set_stylebox("hover", "Button", button_style(BG_PANEL_ALT.lightened(0.12), BORDER_BRIGHT, 6))
	theme.set_stylebox("pressed", "Button", button_style(BG_PANEL_ALT.darkened(0.10), BORDER_BRIGHT, 6))
	return theme


static func make_nine_patch() -> NinePatchRect:
	var patch := NinePatchRect.new()
	patch.texture = PANEL_9SLICE
	patch.draw_center = true
	patch.patch_margin_left = 12
	patch.patch_margin_top = 12
	patch.patch_margin_right = 12
	patch.patch_margin_bottom = 12
	patch.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	patch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return patch
