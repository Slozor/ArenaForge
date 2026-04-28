extends Node2D
class_name Unit
const STATE_IDLE: int = 0
const STATE_MOVING: int = 1
const STATE_ATTACKING: int = 2
const STATE_DEAD: int = 3
const MAX_EQUIPPED_ITEMS: int = 3

const BODY_RADIUS: float = 20.0

# Identity
@export var unit_id: String = ""
@export var unit_name: String = ""
@export var race: String = ""
@export var trait_id: String = ""
@export var cost: int = 1
@export var star_level: int = 1
@export var ability_id: String = ""

# Base stats (set from JSON via init())
var base_max_health: int = 0
var base_attack_damage: int = 0
var base_attack_speed: float = 1.0
var base_attack_range: int = 1
var base_armor: int = 0
var base_move_speed: float = 2.0
var max_health: int = 0
var attack_damage: int = 0
var attack_speed: float = 1.0
var attack_range: int = 1
var armor: int = 0
var move_speed: float = 2.0
var passive: String = ""
var ability_name: String = ""
var ability_description: String = ""
var mana: int = 0
var mana_max: int = 100
var cast_time: float = 0.35
var portrait_texture: Texture2D = null

# Item bonuses (applied on top of base stats)
var item_attack_damage: int = 0
var item_armor: int = 0
var item_max_hp: int = 0
var item_attack_speed: float = 0.0
var temp_attack_speed_mod: float = 0.0
var equipped_item: String = ""
var equipped_items: Array[String] = []

# Runtime
var current_health: int = 0
var state: int = STATE_IDLE
var board_position: Vector2i = Vector2i(-1, -1)
var is_on_bench: bool = true
var is_enemy_unit: bool = false
var has_revived: bool = false
var target = null
var _flash_color: Color = Color.TRANSPARENT
var _flash_strength: float = 0.0
var _burn_strength: float = 0.0
var _slow_strength: float = 0.0
var _pulse_scale: float = 1.0
var _is_dying: bool = false
var _cast_strength: float = 0.0
var unit_visual_scale: float = 1.0
var _death_tween: Tween = null

signal died(unit)
signal health_changed(current: int, maximum: int)


func init(data: Dictionary) -> void:
	unit_id = data.get("id", "")
	unit_name = data.get("name", "")
	race = data.get("race", "")
	trait_id = data.get("trait", "")
	cost = data.get("cost", 1)
	passive = data.get("passive", "")
	portrait_texture = DataManager.get_unit_portrait(unit_id)
	_apply_ability_data(DataManager.get_unit_ability(unit_id))

	var stats: Dictionary = data.get("stats", {})
	base_max_health = stats.get("health", 500)
	base_attack_damage = stats.get("attack_damage", 50)
	base_attack_speed = stats.get("attack_speed", 1.0)
	base_attack_range = stats.get("attack_range", 1)
	base_armor = stats.get("armor", 0)
	base_move_speed = stats.get("move_speed", 2.0)

	_recalculate_stats()
	current_health = get_max_health()
	queue_redraw()


func reset_combat_state() -> void:
	_stop_death_tween()
	_recalculate_stats()
	current_health = get_max_health()
	state = STATE_IDLE
	has_revived = false
	target = null
	temp_attack_speed_mod = 0.0
	_flash_color = Color.TRANSPARENT
	_flash_strength = 0.0
	_burn_strength = 0.0
	_slow_strength = 0.0
	_pulse_scale = 1.0
	_is_dying = false
	mana = 0
	_cast_strength = 0.0
	scale = Vector2.ONE
	modulate = Color.WHITE
	health_changed.emit(current_health, get_max_health())
	queue_redraw()


func _recalculate_stats() -> void:
	var star_multiplier: float = 1.0
	if star_level == 2:
		star_multiplier = 1.8
	elif star_level >= 3:
		star_multiplier = 3.2

	max_health = int(float(base_max_health) * star_multiplier)
	attack_damage = int(float(base_attack_damage) * star_multiplier)
	attack_speed = base_attack_speed
	attack_range = base_attack_range
	armor = base_armor
	move_speed = base_move_speed


func get_max_health() -> int:
	return max_health + item_max_hp


func get_attack_damage() -> int:
	return attack_damage + item_attack_damage


func get_attack_speed() -> float:
	return attack_speed + item_attack_speed + temp_attack_speed_mod


func get_armor() -> int:
	return armor + item_armor


func get_mana_ratio() -> float:
	return clampf(float(mana) / float(max(1, mana_max)), 0.0, 1.0)


func get_equipped_items() -> Array[String]:
	return equipped_items.duplicate()


func get_equipped_item_count() -> int:
	return equipped_items.size()


func can_equip_more_items() -> bool:
	return equipped_items.size() < MAX_EQUIPPED_ITEMS


func gain_mana(amount: int) -> bool:
	if amount <= 0 or state == STATE_DEAD:
		return mana >= mana_max
	mana = mini(mana + amount, mana_max)
	queue_redraw()
	return mana >= mana_max


func consume_mana() -> void:
	mana = 0
	queue_redraw()


func begin_cast() -> void:
	play_cast_pulse()


func play_cast_pulse() -> void:
	_cast_strength = 1.0
	_flash_color = Color(0.32, 0.78, 1.0, 1.0)
	_flash_strength = 0.9
	_pulse_scale = 1.10
	queue_redraw()


func finish_cast() -> void:
	_cast_strength = 0.0
	queue_redraw()


func take_damage(raw_amount: int, ignore_armor: bool = false) -> bool:
	if state == STATE_DEAD:
		return false
	if raw_amount <= 0:
		return false

	var reduced: int = raw_amount
	if not ignore_armor:
		reduced = _apply_armor_reduction(raw_amount)

	current_health -= reduced
	play_damage_flash()
	health_changed.emit(current_health, get_max_health())
	if current_health <= 0:
		_on_death()
		return true
	return false


func heal(amount: int) -> void:
	current_health = mini(current_health + amount, get_max_health())
	play_heal_pulse()
	health_changed.emit(current_health, get_max_health())


func equip_item(item_id: String, item_data: Dictionary) -> void:
	if not can_equip_more_items():
		return
	equipped_items.append(item_id)
	equipped_item = equipped_items[0] if not equipped_items.is_empty() else ""
	var effect: String = item_data.get("effect", "")
	var value: float = item_data.get("value", 0.0)
	_apply_item_bonus(effect, value)
	queue_redraw()


func upgrade_to_star(level: int) -> void:
	star_level = clampi(level, 1, 3)
	_recalculate_stats()
	current_health = get_max_health()
	health_changed.emit(current_health, get_max_health())


func _apply_armor_reduction(raw: int) -> int:
	var reduction: float = float(get_armor()) / (float(get_armor()) + 100.0)
	return maxi(1, int(float(raw) * (1.0 - reduction)))


func _on_death() -> void:
	if state == STATE_DEAD:
		return
	state = STATE_DEAD
	play_death_pop()
	died.emit(self)


func _process(delta: float) -> void:
	if _flash_strength > 0.0:
		_flash_strength = maxf(0.0, _flash_strength - delta * 3.5)
		queue_redraw()
	if _burn_strength > 0.0:
		_burn_strength = maxf(0.0, _burn_strength - delta * 0.8)
		queue_redraw()
	if _slow_strength > 0.0:
		_slow_strength = maxf(0.0, _slow_strength - delta * 0.9)
		queue_redraw()
	if _pulse_scale > 1.0:
		_pulse_scale = lerpf(_pulse_scale, 1.0, minf(1.0, delta * 10.0))
		scale = Vector2.ONE * unit_visual_scale * _pulse_scale
	elif not _is_dying:
		scale = Vector2.ONE * unit_visual_scale


func _draw() -> void:
	var body_color: Color = _race_color()
	var accent_color: Color = _trait_color()
	var team_ring: Color = Color(0.34, 0.72, 1.0, 0.22) if not is_enemy_unit else Color(1.0, 0.42, 0.42, 0.22)
	draw_circle(Vector2(0, 30), 22.0, Color(0, 0, 0, 0.18))
	draw_circle(Vector2.ZERO, 30.0, team_ring)
	_draw_pixel_sprite(body_color, accent_color)

	if get_max_health() > 0:
		var hp_ratio: float = clampf(float(current_health) / float(get_max_health()), 0.0, 1.0)
		var bar_rect: Rect2 = Rect2(Vector2(-30, -50), Vector2(60, 6))
		draw_rect(bar_rect, Color(0.05, 0.08, 0.12, 0.9), true)
		draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * hp_ratio, bar_rect.size.y)), Color(0.35, 0.95, 0.50, 0.95), true)
		var mana_rect: Rect2 = Rect2(Vector2(-30, -42), Vector2(60, 5))
		draw_rect(mana_rect, Color(0.04, 0.10, 0.16, 0.85), true)
		draw_rect(Rect2(mana_rect.position, Vector2(mana_rect.size.x * get_mana_ratio(), mana_rect.size.y)), Color(0.28, 0.72, 1.0, 0.92), true)

	for i in equipped_items.size():
		draw_circle(Vector2(16 + i * 9, -28), 4.0, Color(1.0, 0.85, 0.35, 0.95))
	if mana >= mana_max:
		draw_circle(Vector2.ZERO, BODY_RADIUS + 9.0, Color(0.28, 0.72, 1.0, 0.18))

	var font: Font = ThemeDB.fallback_font
	if font != null and star_level > 1:
		draw_string(font, Vector2(-8, 38), "★", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.88, 0.32, 0.95))

	if _burn_strength > 0.0:
		draw_circle(Vector2.ZERO, BODY_RADIUS + 8.0, Color(1.0, 0.45, 0.18, 0.16 * _burn_strength))
	if _slow_strength > 0.0:
		draw_circle(Vector2.ZERO, BODY_RADIUS + 8.0, Color(0.45, 0.72, 1.0, 0.16 * _slow_strength))
	if _flash_strength > 0.0:
		var flash_color: Color = Color(_flash_color.r, _flash_color.g, _flash_color.b, 0.55 * _flash_strength)
		draw_circle(Vector2.ZERO, BODY_RADIUS + 4.0, flash_color)
	if _cast_strength > 0.0:
		draw_circle(Vector2.ZERO, BODY_RADIUS + 12.0, Color(0.24, 0.74, 1.0, 0.10 * _cast_strength))


func _draw_pixel_sprite(body_color: Color, accent_color: Color) -> void:
	var dark: Color = body_color.darkened(0.35)
	var light: Color = body_color.lightened(0.16)
	if portrait_texture != null:
		draw_texture_rect(portrait_texture, Rect2(Vector2(-22, -30), Vector2(44, 44)), false, Color.WHITE)
		return
	draw_rect(Rect2(Vector2(-18, -24), Vector2(36, 14)), light, true)
	draw_rect(Rect2(Vector2(-20, -10), Vector2(40, 24)), body_color, true)
	draw_rect(Rect2(Vector2(-14, 14), Vector2(10, 10)), dark, true)
	draw_rect(Rect2(Vector2(4, 14), Vector2(10, 10)), dark, true)
	draw_rect(Rect2(Vector2(-22, -4), Vector2(4, 16)), dark, true)
	draw_rect(Rect2(Vector2(18, -4), Vector2(4, 16)), dark, true)
	draw_rect(Rect2(Vector2(-20, -16), Vector2(40, 4)), accent_color, true)
	draw_rect(Rect2(Vector2(-11, -20), Vector2(4, 4)), Color(0.08, 0.10, 0.14, 0.92), true)
	draw_rect(Rect2(Vector2(7, -20), Vector2(4, 4)), Color(0.08, 0.10, 0.14, 0.92), true)
	draw_rect(Rect2(Vector2(-8, -2), Vector2(16, 4)), accent_color.lightened(0.12), true)
	match race:
		"elf", "fae":
			draw_rect(Rect2(Vector2(-32, -24), Vector2(4, 10)), light, true)
			draw_rect(Rect2(Vector2(28, -24), Vector2(4, 10)), light, true)
		"orc":
			draw_rect(Rect2(Vector2(-18, -2), Vector2(4, 4)), Color(0.96, 0.90, 0.70, 0.95), true)
			draw_rect(Rect2(Vector2(14, -2), Vector2(4, 4)), Color(0.96, 0.90, 0.70, 0.95), true)
		"dragon":
			draw_rect(Rect2(Vector2(-16, -40), Vector2(6, 6)), Color(0.98, 0.76, 0.42, 0.92), true)
			draw_rect(Rect2(Vector2(10, -40), Vector2(6, 6)), Color(0.98, 0.76, 0.42, 0.92), true)


func play_attack_pulse() -> void:
	_pulse_scale = 1.1


func play_damage_flash() -> void:
	_flash_color = Color(1.0, 0.28, 0.22, 1.0)
	_flash_strength = 1.0
	_pulse_scale = 1.06
	queue_redraw()


func play_heal_pulse() -> void:
	_flash_color = Color(0.40, 1.0, 0.55, 1.0)
	_flash_strength = 0.75
	_pulse_scale = 1.08
	queue_redraw()


func set_burn_visual(duration_scale: float = 1.0) -> void:
	_burn_strength = maxf(_burn_strength, duration_scale)


func _apply_item_bonus(effect: String, value: float) -> void:
	match effect:
		"attack_damage_flat":
			item_attack_damage += int(value)
		"armor_flat":
			item_armor += int(value)
		"max_hp_flat":
			item_max_hp += int(value)
		"attack_speed_flat":
			item_attack_speed += value
	queue_redraw()


func set_slow_visual(duration_scale: float = 1.0) -> void:
	_slow_strength = maxf(_slow_strength, duration_scale)
	queue_redraw()


func play_death_pop() -> void:
	_is_dying = true
	_stop_death_tween()
	_death_tween = create_tween()
	_death_tween.tween_property(self, "scale", Vector2.ONE * 1.2, 0.08)
	_death_tween.tween_property(self, "modulate", Color(1.0, 0.35, 0.35, 0.0), 0.22)


func _apply_ability_data(data: Dictionary) -> void:
	if data.is_empty():
		ability_id = ""
		ability_name = "Signature"
		ability_description = "A signature attack unfolds when mana is full."
		mana_max = 100
		cast_time = 0.35
		return
	ability_id = str(data.get("id", ability_id))
	ability_name = str(data.get("name", "Signature"))
	ability_description = str(data.get("description", "A signature attack unfolds when mana is full."))
	mana_max = maxi(1, int(data.get("mana", 100)))
	cast_time = maxf(0.1, float(data.get("cast_time", 0.35)))


func cancel_death_visuals() -> void:
	_stop_death_tween()
	_is_dying = false
	scale = Vector2.ONE * unit_visual_scale
	modulate = Color.WHITE
	queue_redraw()


func _stop_death_tween() -> void:
	if _death_tween != null and is_instance_valid(_death_tween):
		_death_tween.kill()
	_death_tween = null


func _race_color() -> Color:
	match race:
		"human": return Color(0.74, 0.84, 0.96)
		"elf": return Color(0.54, 0.92, 0.66)
		"dwarf": return Color(0.88, 0.74, 0.48)
		"undead": return Color(0.76, 0.78, 0.90)
		"dragon": return Color(0.95, 0.48, 0.30)
		"orc": return Color(0.56, 0.78, 0.34)
		"fae": return Color(0.80, 0.64, 0.96)
		_: return Color(0.7, 0.7, 0.78)


func _trait_color() -> Color:
	match trait_id:
		"warrior", "knight", "vanguard": return Color(0.98, 0.82, 0.42)
		"mage", "sorcerer": return Color(0.48, 0.72, 1.0)
		"ranger": return Color(0.60, 0.94, 0.54)
		"guardian": return Color(1.0, 0.92, 0.58)
		"assassin", "duelist": return Color(0.98, 0.48, 0.66)
		_: return Color(0.92, 0.92, 0.96)


func _cost_color() -> Color:
	match cost:
		1: return Color(0.68, 0.70, 0.75)
		2: return Color(0.22, 0.78, 0.38)
		3: return Color(0.30, 0.54, 0.96)
		4: return Color(0.72, 0.34, 0.96)
		_: return Color(0.92, 0.82, 0.46)
