extends Node2D

class_name Unit

enum State { IDLE, MOVING, ATTACKING, DEAD }

# Identity
@export var unit_id: String = ""
@export var unit_name: String = ""
@export var race: String = ""
@export var trait: String = ""
@export var cost: int = 1
@export var star_level: int = 1

# Base stats (set from JSON via init())
var max_health: int = 0
var attack_damage: int = 0
var attack_speed: float = 1.0
var attack_range: int = 1
var armor: int = 0
var move_speed: float = 2.0
var passive: String = ""

# Item bonuses (applied on top of base stats)
var item_attack_damage: int = 0
var item_armor: int = 0
var item_max_hp: int = 0
var item_attack_speed: float = 0.0
var equipped_item: String = ""

# Runtime
var current_health: int = 0
var state: State = State.IDLE
var board_position: Vector2i = Vector2i(-1, -1)
var is_on_bench: bool = true
var has_revived: bool = false
var target: Unit = null

signal died(unit: Unit)
signal health_changed(current: int, maximum: int)


func init(data: Dictionary) -> void:
	unit_id = data.get("id", "")
	unit_name = data.get("name", "")
	race = data.get("race", "")
	trait = data.get("trait", "")
	cost = data.get("cost", 1)
	passive = data.get("passive", "")

	var stats: Dictionary = data.get("stats", {})
	max_health = stats.get("health", 500)
	attack_damage = stats.get("attack_damage", 50)
	attack_speed = stats.get("attack_speed", 1.0)
	attack_range = stats.get("attack_range", 1)
	armor = stats.get("armor", 0)
	move_speed = stats.get("move_speed", 2.0)

	_apply_star_scaling()
	current_health = get_max_health()


func get_max_health() -> int:
	return max_health + item_max_hp


func get_attack_damage() -> int:
	return attack_damage + item_attack_damage


func get_attack_speed() -> float:
	return attack_speed + item_attack_speed


func get_armor() -> int:
	return armor + item_armor


func take_damage(raw_amount: int) -> void:
	var reduced: int = _apply_armor_reduction(raw_amount)
	current_health -= reduced
	health_changed.emit(current_health, get_max_health())
	if current_health <= 0:
		_on_death()


func heal(amount: int) -> void:
	current_health = mini(current_health + amount, get_max_health())
	health_changed.emit(current_health, get_max_health())


func equip_item(item_id: String, item_data: Dictionary) -> void:
	equipped_item = item_id
	var effect: String = item_data.get("effect", "")
	var value: float = item_data.get("value", 0.0)
	match effect:
		"attack_damage_flat":  item_attack_damage = int(value)
		"armor_flat":          item_armor = int(value)
		"max_hp_flat":         item_max_hp = int(value)
		"attack_speed_flat":   item_attack_speed = value


func upgrade_to_star(level: int) -> void:
	star_level = level
	_apply_star_scaling()
	current_health = get_max_health()


func _apply_star_scaling() -> void:
	if star_level == 2:
		max_health = int(max_health * 1.8)
		attack_damage = int(attack_damage * 1.8)


func _apply_armor_reduction(raw: int) -> int:
	var reduction: float = float(get_armor()) / (float(get_armor()) + 100.0)
	return maxi(1, int(float(raw) * (1.0 - reduction)))


func _on_death() -> void:
	state = State.DEAD
	died.emit(self)
