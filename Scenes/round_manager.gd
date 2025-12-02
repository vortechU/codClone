extends Node

# Singleton that manages zombie rounds and enemy spawning.
# Autoload this as "RoundManager".

signal round_started(round_number: int)
signal round_cleared(round_number: int)
signal enemy_spawned(enemy: Node)

@export var enemy_scene: PackedScene
@export var spawn_points: Array[NodePath] = []
@export var initial_round: int = 1
@export var base_enemies_per_round: int = 6
@export var enemies_increment_per_round: int = 2
@export var max_concurrent_enemies: int = 12
@export var spawn_interval: float = 1.0

var current_round: int = 0
var alive_enemies: int = 0
var total_to_spawn: int = 0
var spawned_this_round: int = 0
var _spawn_timer: Timer

func _ready() -> void:
	_spawn_timer = Timer.new()
	_spawn_timer.wait_time = spawn_interval
	_spawn_timer.one_shot = false
	_spawn_timer.autostart = false
	add_child(_spawn_timer)
	_spawn_timer.timeout.connect(_on_spawn_tick)
	# Optionally start first round automatically if desired
	# Uncomment to auto-start:
	start_round(initial_round)

func start_round(round_num: int = -1) -> void:
	if round_num > 0:
		current_round = round_num
	else:
		current_round = max(1, current_round + 1 if current_round > 0 else initial_round)

	spawned_this_round = 0
	alive_enemies = 0
	total_to_spawn = _calc_total_for_round(current_round)
	emit_signal("round_started", current_round)
	_spawn_timer.start()
	print("Round ", current_round, " started. Total to spawn: ", total_to_spawn)

func _calc_total_for_round(round_num: int) -> int:
	return base_enemies_per_round + enemies_increment_per_round * (round_num - 1)

func _on_spawn_tick() -> void:
	if enemy_scene == null or spawn_points.is_empty():
		return
	# Stop if spawned all and waiting for clears
	if spawned_this_round >= total_to_spawn:
		_spawn_timer.stop()
		return
	# Respect concurrent cap
	if alive_enemies >= max_concurrent_enemies:
		return
	# Pick spawn point
	var idx = spawned_this_round % spawn_points.size()
	var sp: Node3D = get_node_or_null(spawn_points[idx])
	if sp == null or not sp.is_inside_tree():
		return
	# Instantiate
	var enemy: Node3D = enemy_scene.instantiate()
	# Ensure enemy in enemies group for power-ups like nuke
	if enemy and not enemy.is_in_group("enemies"):
		enemy.add_to_group("enemies")
	# Place and add under spawn point's parent (usually level/root)
	enemy.global_transform = sp.global_transform
	sp.get_parent().add_child(enemy)
	spawned_this_round += 1
	alive_enemies += 1
	emit_signal("enemy_spawned", enemy)
	print("Spawned enemy ", spawned_this_round, "/", total_to_spawn, " | alive: ", alive_enemies)
	# Wire enemy death to decrement alive counter
	var health: Node = enemy.get_node_or_null("Health")
	if health and health.has_signal("died"):
		health.connect("died", _on_enemy_died)

func _on_enemy_died(_instigator: Node = null) -> void:
	alive_enemies = max(0, alive_enemies - 1)
	print("Enemy died. Alive: ", alive_enemies, " | spawned: ", spawned_this_round, "/", total_to_spawn)
	# If we've spawned all and none remain, round cleared
	if spawned_this_round >= total_to_spawn and alive_enemies == 0:
		emit_signal("round_cleared", current_round)
		print("Round ", current_round, " cleared.")
		# Auto-start next round after short delay
		await get_tree().create_timer(2.0).timeout
		start_round(current_round + 1)

func force_clear_round() -> void:
	# Kills all enemies (useful for testing)
	for e in get_tree().get_nodes_in_group("enemies"):
		var h: Node = e.get_node_or_null("Health")
		if h and h.has_method("take_damage"):
			h.take_damage(1e9, self)

