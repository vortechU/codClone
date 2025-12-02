extends Control

@onready var health_bar: ProgressBar = $CanvasLayer/healthBar
@onready var hit_effect: AnimationPlayer = $CanvasLayer/killEffect/AnimationPlayer
@onready var points_label: Label = $CanvasLayer/pointsNum
@onready var round_label: Label = $CanvasLayer/roundCount

var player: CharacterBody3D = null
var health: Health = null

func _ready() -> void:
	# Find the player in the scene
	var players = get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		player = players[0]
	
	# Wait a frame to ensure player's Health component is ready
	await get_tree().process_frame

	
	if player:
		health = player.get_node_or_null("Health")
		
		if health:
			# Connect to player's health signals
			health.health_changed.connect(_on_player_health_changed)
			health.died.connect(_on_player_died)
			
			# Initialize the health bar
			health_bar.max_value = health.max_health
			health_bar.value = health.current_health
		
		# Connect to player's points signal
		if player.has_signal("points_changed"):
			player.points_changed.connect(_on_player_points_changed)
			# Initialize points display
			if points_label:
				points_label.text = str(player.points)

	# Connect RoundManager signals to update round label
	# Use direct reference since RoundManager is autoloaded
	if RoundManager:
		RoundManager.round_started.connect(_on_round_started)
		RoundManager.round_cleared.connect(_on_round_cleared)
		# Initialize label if a round is already set
		if round_label:
			print("[UI] Round label connected. Current round: ", RoundManager.current_round)
			if RoundManager.current_round > 0:
				round_label.text = "Round: " + str(RoundManager.current_round)
			else:
				round_label.text = "Round: --"
	else:
		print("[UI] ERROR: RoundManager autoload not found!")
		

func _on_player_health_changed(current: int, max_health: int) -> void:
	if health_bar:
		health_bar.max_value = max_health
		# Smooth transition
		var tween = create_tween()
		tween.tween_property(health_bar, "value", current, 0.2)
	
	# Play hit effect animation when taking damage
	if hit_effect and hit_effect.has_animation("hitEffect"):
		hit_effect.play("hitEffect")

func _on_player_died(_instigator: Node = null) -> void:
	# Player died - could show death screen, game over UI, etc.
	if health_bar:
		health_bar.value = 0

func _on_player_points_changed(new_points: int) -> void:
	if points_label:
		points_label.text =  "points: " + str(new_points)

func _on_round_started(round_number: int) -> void:
	print("[UI] Round started signal received: ", round_number)
	if round_label:
		round_label.text = "Round: " + str(round_number)
		print("[UI] Round label updated to: ", round_label.text)

func _on_round_cleared(_round_number: int) -> void:
	# Optional: flash or show message; keep label at current round
	round_label.text = "Round: " + str(RoundManager.current_round)
    
        