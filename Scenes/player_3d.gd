extends CharacterBody3D

#player paramaters
const SPEED = 5.0
const SPRINT_SPEED = 8.0
const JUMP_VELOCITY = 4.5
const ACCELERATION = 10.0
const FRICTION = 15.0

# Camera effects
const BOB_FREQ = 2.0
const BOB_AMP = 0.08
const BASE_FOV = 75.0
const FOV_CHANGE = 10.0
const TILT_AMOUNT = 2.0

@onready var camera = $Camera3D
@onready var health: Health = null
#initiate the points system
var points: int = 0
signal points_changed(new_points: int)


var camera_bob_time = 0.0
var was_in_air = false
var has_double_jumped = false
func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if camera:
		camera.fov = BASE_FOV

	# Ensure a Health component exists and connect signals
	health = get_node_or_null("Health")
	if health == null:
		health = Health.new()
		health.name = "Health"
		add_child(health)
	health.health_changed.connect(_on_health_changed)
	health.died.connect(_on_player_died)
	



func _physics_process(delta: float) -> void:
	doubleJump()
	
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Handle movement input
	var input_dir := Input.get_vector("Left", "Right", "Forward", "Backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# Determine current speed based on sprint input
	var current_speed = SPRINT_SPEED if Input.is_action_pressed("Sprint") else SPEED
	
	if direction:
		velocity.x = move_toward(velocity.x, direction.x * current_speed, ACCELERATION * delta)
		velocity.z = move_toward(velocity.z, direction.z * current_speed, ACCELERATION * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
		velocity.z = move_toward(velocity.z, 0, FRICTION * delta)
	
	# Camera effects
	_apply_camera_effects(delta, input_dir)

	# Toggle mouse mode / quit (use just_pressed to avoid repeat)
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().quit()


	move_and_slide()

	# Example: fall damage if falling fast and hitting ground
	if is_on_floor() and velocity.y <= -20.0 and health and health.is_alive():
		health.take_damage(10, self)

func _apply_camera_effects(delta: float, input_dir: Vector2) -> void:
	if not camera:
		return
	
	# Head bobbing
	if is_on_floor() and velocity.length() > 0.1:
		camera_bob_time += delta * velocity.length()
		camera.position.y = sin(camera_bob_time * BOB_FREQ) * BOB_AMP
	else:
		camera.position.y = lerp(camera.position.y, 0.0, delta * 5.0)
	
	# FOV kick based on sprint
	var target_fov = BASE_FOV + FOV_CHANGE if Input.is_action_pressed("Sprint") else BASE_FOV
	camera.fov = lerp(camera.fov, target_fov, delta * 8.0)
	
	# Camera tilt when strafing
	var tilt = -input_dir.x * TILT_AMOUNT
	camera.rotation.z = lerp(camera.rotation.z, deg_to_rad(tilt), delta * 10.0)
	
	# Landing impact
	if not is_on_floor():
		was_in_air = true
	elif was_in_air:
		# Just landed - small camera dip
		camera.position.y = -0.1
		was_in_air = false

func _input(event):
	if event is InputEventMouseMotion and camera:
		rotate_y(deg_to_rad(-event.relative.x * 0.1))
		var camera_rotation = camera.rotation_degrees
		camera_rotation.x = clamp(camera_rotation.x - event.relative.y * 0.1, -89, 89)
		camera.rotation_degrees = camera_rotation

	# Debug: press H to take damage, J to heal
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_H and health:
			health.take_damage(5, self)
		elif event.keycode == KEY_J and health:
			health.heal(5, self)

func apply_camera_recoil(amount: float) -> void:
	if camera:
		var camera_rotation = camera.rotation_degrees
		camera_rotation.x -= amount
		camera_rotation.x = clamp(camera_rotation.x, -89, 89)
		camera.rotation_degrees = camera_rotation

func _on_health_changed(_current: int, _max: int) -> void:
	# TODO: update UI, play feedback
	pass

func _on_player_died(_instigator: Node = null) -> void:
	# Simple respawn: reload current scene
	get_tree().reload_current_scene()


func doubleJump():
	if Input.is_action_just_pressed("ui_accept") and not is_on_floor() and not has_double_jumped:
		velocity.y = JUMP_VELOCITY * 1.5
		has_double_jumped = true
	if is_on_floor():
		has_double_jumped = false


func add_points(amount: int) -> void:
	points += amount
	emit_signal("points_changed", points)
	