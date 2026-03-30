extends Node2D

enum UnitState {
	IDLE,
	MOVING,
	ATTACKING,
	DEAD
}

@export var unit_name: String = ""
@export var tier: int = 1
@export var cost: int = 1
@export var max_health: int = 100
@export var attack_damage: int = 10
@export var attack_speed: float = 1.0
@export var attack_range: float = 1.0
@export var move_speed: float = 2.0
@export var traits: Array[String] = []

var current_health: int = 0
var current_state: UnitState = UnitState.IDLE
var star_level: int = 1  # 1, 2, or 3 stars
var target = null
var board_position: Vector2i = Vector2i(-1, -1)
var is_on_bench: bool = true

signal died(unit)
signal health_changed(current: int, maximum: int)


func _ready() -> void:
	current_health = max_health


func take_damage(amount: int) -> void:
	current_health -= amount
	health_changed.emit(current_health, max_health)
	if current_health <= 0:
		_die()


func heal(amount: int) -> void:
	current_health = min(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)


func upgrade_star() -> void:
	star_level += 1
	max_health = int(max_health * 1.8)
	attack_damage = int(attack_damage * 1.8)
	current_health = max_health


func get_scaled_stat(base_value: int) -> int:
	match star_level:
		2: return int(base_value * 1.8)
		3: return int(base_value * 3.24)
	return base_value


func _die() -> void:
	current_state = UnitState.DEAD
	died.emit(self)
