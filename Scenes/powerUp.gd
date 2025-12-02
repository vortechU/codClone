extends Area3D

class_name PowerUp

enum PowerUpType { INSTA_KILL, NUKE, MAX_AMMO, DOUBLE_POINTS }

@export var power_up_type: PowerUpType = PowerUpType.INSTA_KILL
@export var duration: float = 30.0  # Duration in seconds (0 = instant effect)
@export var float_amplitude: float = 0.5
@export var float_speed: float = 2.0
@export var spin_speed: float = 2.0

var time: float = 0.0
var start_position: Vector3

func _ready() -> void:
	start_position = position
	body_entered.connect(_on_body_entered)
	# Ensure it's on a collision layer the player can detect
	collision_layer = 0
	collision_mask = 1  # Player layer

func _process(delta: float) -> void:
	time += delta
	
	# Float up and down
	position.y = start_position.y + sin(time * float_speed) * float_amplitude
	
	# Spin around Y axis
	rotate_y(delta * spin_speed)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		activate(body)
		queue_free()

func activate(_player: Node) -> void:
	match power_up_type:
		PowerUpType.INSTA_KILL:
			PowerUpManager.activate_insta_kill(duration)
		PowerUpType.NUKE:
			PowerUpManager.activate_nuke()
		PowerUpType.MAX_AMMO:
			PowerUpManager.activate_max_ammo()
		PowerUpType.DOUBLE_POINTS:
			PowerUpManager.activate_double_points(duration)
