extends CharacterBody3D

var player = null

@export var player_path: NodePath
@export var normalSpeed: float = 5.0
@export var chase_speed: float = 5.0
@export var attack_radius: float = 2.0
@export var attack_damage: float = 5.0
@export var attack_cooldown: float = 1.0
@export var power_up_drop_chance: float = 0.15  # 15% chance to drop power-up
@export var power_up_scenes: Array[PackedScene] = []  # Assign power-up scenes in editor
@onready var nav_agent = $NavigationAgent3D
@onready var health: Health = null

var attack_timer: float = 0.0


func _ready():
    # Resolve player reference robustly: use explicit path if provided, else fallback to group lookup
    if player_path != null and String(player_path) != "":
        var candidate = get_node_or_null(player_path)
        if candidate != null:
            player = candidate
    if player == null:
        var players = get_tree().get_nodes_in_group("Player")
        if players.size() > 0:
            player = players[0]
    # If still null, defer one frame in case spawn order puts player later
    if player == null:
        await get_tree().process_frame
        var players2 = get_tree().get_nodes_in_group("Player")
        if players2.size() > 0:
            player = players2[0]
    # Ensure Health exists and connect signals
    health = get_node_or_null("Health")
    if health == null:
        health = Health.new()
        health.name = "Health"
        add_child(health)
    health.died.connect(_on_enemy_died)


func _physics_process(delta: float) -> void:
    # Guard against player being freed during respawn
    if player == null or not is_instance_valid(player) or not player.is_inside_tree():
        return

    var distance_to_player = global_transform.origin.distance_to(player.global_transform.origin)

    # Always follow the player by default; stop only to attack in range
    if distance_to_player <= attack_radius:
        # Attack logic - damage player every second
        nav_agent.set_velocity(Vector3.ZERO)
        nav_agent.max_speed = 0.0
        
        # Update attack timer
        attack_timer -= delta
        
        if attack_timer <= 0.0:
            # Damage player if close and health exists on player
            if player and player.has_node("Health"):
                var p_health: Health = player.get_node("Health")
                if p_health and p_health.is_alive():
                    p_health.take_damage(attack_damage, self)
                    attack_timer = attack_cooldown  # Reset timer
    else:
        nav_agent.target_position = player.global_transform.origin
        nav_agent.max_speed = normalSpeed
        attack_timer = 0.0  # Reset timer when not attacking

    # Move only if we have a valid path and navigation map is ready
    if player != null and nav_agent.get_navigation_map() != RID() and not nav_agent.is_navigation_finished():
        var next_path_position = nav_agent.get_next_path_position()
        var to_next = next_path_position - global_transform.origin
        if to_next.length() > 0.001:
            var direction = to_next.normalized()
            velocity = direction * nav_agent.max_speed
        else:
            nav_agent.set_velocity(Vector3.ZERO)
            velocity = Vector3.ZERO

    # Perform movement in physics step only when inside tree
    if is_inside_tree():
        move_and_slide()

func _on_enemy_died(_instigator: Node = null) -> void:
    # Cache position early (signal may arrive after node starts leaving tree)
    var spawn_pos: Vector3 = global_position
    # TEST MODE: Always spawn a power-up on death to visualize gameplay flow.
    # To revert to chance-based drops, replace this block with:
    # if power_up_scenes.size() > 0 and randf() < power_up_drop_chance:
    #     _drop_power_up_at(spawn_pos)
    if power_up_scenes.size() > 0:
        _drop_power_up_at(spawn_pos)
    queue_free()

func _drop_power_up_at(spawn_pos: Vector3) -> void:
    # Pick a random power-up from the array
    if power_up_scenes.is_empty():
        return
    var random_power_up = power_up_scenes[randi() % power_up_scenes.size()]
    if not random_power_up:
        return
    var parent_node: Node = get_parent()
    if parent_node == null:
        return
    # Instantiate and add first, THEN set global position (needs to be in tree)
    var power_up: Node3D = random_power_up.instantiate()
    parent_node.add_child(power_up)
    # Use cached spawn_pos; enemy may soon be freed
    if power_up.is_inside_tree():
        power_up.global_position = spawn_pos + Vector3(0, 1, 0)