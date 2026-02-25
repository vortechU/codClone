extends Control

@onready var health_bar: ProgressBar = $CanvasLayer/healthBar
@onready var hit_effect: AnimationPlayer = $CanvasLayer/killEffect/AnimationPlayer
@onready var points_label: Label = $CanvasLayer/pointsNum
@onready var round_label: Label = $CanvasLayer/roundCount
@onready var bestScore: Label = $CanvasLayer/loseCondition/BestScore

var player: CharacterBody3D = null
var health: Health = null
var playerBattery: Timer = null

func _ready() -> void:
	# Find the player in the scene
	process_mode = Node.PROCESS_MODE_ALWAYS
	var pause_menu = $CanvasLayer/PauseMenu
	if pause_menu:
		pause_menu.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	var players = get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		player = players[0]
	
	# Wait a frame to ensure player's Health component is ready
	await get_tree().process_frame

	
	if player:
		health = player.get_node_or_null("Health")
		playerBattery = player.get_node_or_null("Battery")
		
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
		print("[UI] Connected to RoundManager signals")
		print("[UI] round_cleared signal connections: ", RoundManager.round_cleared.get_connections())
		# Initialize label if a round is already set
		if round_label:
			print("[UI] Round label connected. Current round: ", RoundManager.current_round)
			if RoundManager.current_round > 0:
				round_label.text = "Round: " + str(RoundManager.current_round)
			else:
				round_label.text = "Round: --"
	else:
		print("[UI] ERROR: RoundManager autoload not found!")


func _process(_delta):
	# Update the UI every frame
	if playerBattery:
		$CanvasLayer/BatteryBar.value = (playerBattery.time_left / playerBattery.wait_time) * 100

		# Check for death by darkness
		if playerBattery.is_stopped():
			if health:
				health.take_damage(9999, self)  # Instantly kill the player





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
	# Show death screen UI - player handles its own state
	if health_bar:
		health_bar.value = 0
	
	$CanvasLayer/loseCondition.visible = true
	var highScore = SaveManager.load_score()
	bestScore.text = "Best Score: " + str(highScore)
	if player.points >= highScore:
		SaveManager.save_score(player.points)

func _on_player_points_changed(new_points: int) -> void:
	if points_label:
		points_label.text =  "points: " + str(new_points)

func _on_round_started(round_number: int) -> void:
	print("[UI] Round started signal received: ", round_number)
	if round_label:
		round_label.text = "Round: " + str(round_number)
		print("[UI] Round label updated to: ", round_label.text)

func _on_round_cleared(round_number: int) -> void:
	print("[UI] _on_round_cleared called! Round ", round_number, " cleared!")
	# The round_started signal will update the label when the next round begins
	# This is just for feedback/effects if needed
	
		

func _on_try_again_pressed() -> void:
	Engine.time_scale = 1.0  # Ensure time scale is reset
	get_tree().reload_current_scene()


func _on_bt_resume_pressed() -> void:
	_set_paused(false)

func _set_paused(paused: bool) -> void:
	get_tree().paused = paused
	var pause_menu = $CanvasLayer/PauseMenu
	if pause_menu:
		pause_menu.visible = paused
	set_physics_process(not paused)
	set_process(not paused)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED)

func _input(_event) -> void:
	if Input.is_action_just_pressed("Pause"):
		_set_paused(not get_tree().paused)
		return

func _on_bt_mainmenu_pressed() -> void:
	_set_paused(false)
	#show mouse cursor before changing scene
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")
	
