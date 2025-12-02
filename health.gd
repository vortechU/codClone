extends Node

# Reusable Health component for any entity (Player, Enemy, props)
# Attach this scene/node as a child of an entity and wire signals as needed.

class_name Health

@export var max_health: int = 100
@export var start_health: int = 100
@export var invulnerable: bool = false
@export var regen_per_second: float = 0.0
@export var auto_queue_free_on_death: bool = false

var current_health: float

signal health_changed(current: int, max: int)
signal damaged(amount: int, instigator: Node)
signal healed(amount: int, instigator: Node)
signal died(instigator: Node)

func _ready() -> void:
	current_health = clampf(float(start_health), 0.0, float(max_health))
	emit_signal("health_changed", int(round(current_health)), max_health)

func _process(delta: float) -> void:
	if regen_per_second > 0.0 and current_health > 0.0 and current_health < max_health:
		_apply_heal(regen_per_second * delta, null, false)

func is_alive() -> bool:
	return current_health > 0.0

func take_damage(amount: float, instigator: Node = null) -> void:
	if amount <= 0.0:
		return
	if invulnerable or not is_alive():
		return
	current_health = max(current_health - amount, 0.0)
	emit_signal("damaged", int(round(amount)), instigator)
	emit_signal("health_changed", int(round(current_health)), max_health)
	if current_health <= 0.0:
		_die(instigator)

func heal(amount: float, instigator: Node = null) -> void:
	if amount <= 0.0 or not is_alive():
		return
	_apply_heal(amount, instigator)

func _apply_heal(amount: float, instigator: Node, emit_events: bool = true) -> void:
	var prev = current_health
	current_health = min(current_health + amount, float(max_health))
	if emit_events and current_health > prev:
		emit_signal("healed", int(round(current_health - prev)), instigator)
		emit_signal("health_changed", int(round(current_health)), max_health)

func set_max_health(new_max: int, clamp_current: bool = true) -> void:
	max_health = max(1, new_max)
	if clamp_current:
		current_health = clampf(current_health, 0.0, float(max_health))
		emit_signal("health_changed", int(round(current_health)), max_health)

func reset() -> void:
	current_health = float(max_health)
	emit_signal("health_changed", int(round(current_health)), max_health)

func _die(instigator: Node) -> void:
	emit_signal("died", instigator)
	if auto_queue_free_on_death and is_instance_valid(get_parent()):
		# Remove the owning entity if desired
		get_parent().queue_free()
