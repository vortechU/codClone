extends Node3D

# Gun stats
@export var damage: float = 25.0
@export var fire_rate: float = 0.1  # Time between shots
@export var max_ammo: int = 30
@export var reserve_ammo: int = 90
@export var reload_time: float = 2.0
@export var gun_range: float = 100.0

# Weapon effects
@export var weapon_bob_speed: float = 10.0
@export var weapon_bob_amount: float = 0.05
@export var ads_fov: float = 60.0  # Aim down sights FOV
@export var ads_speed: float = 8.0

# State
var current_ammo: int
var can_shoot: bool = true
var is_reloading: bool = false
var is_aiming: bool = false
var sway_time: float = 0.0

# Cached references
var playerRef: CharacterBody3D
var camera: Camera3D
var animation_player: AnimationPlayer
var ammo_count_label: Label
var muzzle_light: Light3D
var space_state: PhysicsDirectSpaceState3D
var original_position: Vector3
var original_rotation: Vector3
var base_fov: float = 75.0
var camera_basis_z: Vector3  # Cache camera forward direction

signal ammo_changed(current: int, reserve: int)
signal weapon_fired
signal reload_started
signal reload_finished

func _ready() -> void:
	# Cache node references once at startup
	var parent = get_parent()
	var grandparent = parent.get_parent() if parent else null
	playerRef = grandparent if grandparent is CharacterBody3D else null
	camera = parent if parent is Camera3D else get_viewport().get_camera_3d()
	animation_player = get_node_or_null("AK_47/AnimationPlayer")
	ammo_count_label = get_node_or_null("../../UI/CanvasLayer/AmmoCount")
	muzzle_light = get_node_or_null("muzzleLight")
	space_state = get_world_3d().direct_space_state
	
	current_ammo = max_ammo
	original_position = position
	original_rotation = rotation
	
	if camera:
		base_fov = camera.fov
		camera_basis_z = -camera.global_transform.basis.z
	
	_update_ammo_display()
	ammo_changed.emit(current_ammo, reserve_ammo)

func _process(delta: float) -> void:
	# Handle continuous shooting when holding
	if Input.is_action_pressed("Shoot") and not is_reloading:
		shoot()
	
	# Weapon bobbing (only when not animating and player is grounded)
	if playerRef and playerRef.is_on_floor() and not (animation_player and animation_player.is_playing()):
		var velocity_length := playerRef.velocity.length()
		
		if velocity_length > 0.1:
			sway_time += delta * weapon_bob_speed
			var bob_offset := Vector3(
				sin(sway_time * 0.5) * weapon_bob_amount,
				abs(cos(sway_time)) * weapon_bob_amount,
				0.0
			)
			position = lerp(position, original_position + bob_offset, delta * 10.0)
		else:
			sway_time = 0.0
			position = lerp(position, original_position, delta * 10.0)
		
		rotation = lerp(rotation, original_rotation, delta * 10.0)
	
	# ADS (Aim Down Sights) handling
	if camera:
		var target_fov := ads_fov if is_aiming else base_fov
		camera.fov = lerp(camera.fov, target_fov, delta * ads_speed)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		is_aiming = event.pressed
	
	if event.is_action_pressed("reload"):  # Map 'R' key in project settings
		reload()

func shoot() -> void:
	if not can_shoot or is_reloading or current_ammo <= 0:
		return
	
	current_ammo -= 1
	$shootSound.play()
	_update_ammo_display()
	ammo_changed.emit(current_ammo, reserve_ammo)
	weapon_fired.emit()
	
	# Play shoot animation
	if animation_player and animation_player.has_animation("Shoot"):
		animation_player.play("Shoot")

	# Muzzle flash
	if muzzle_light:
		muzzle_light.visible = true
		get_tree().create_timer(0.05, false).timeout.connect(_hide_muzzle_flash, CONNECT_ONE_SHOT)
	
	# Perform raycast from camera
	_fire_raycast()
	
	# Fire rate cooldown
	can_shoot = false
	get_tree().create_timer(fire_rate, false).timeout.connect(_reset_shoot_cooldown, CONNECT_ONE_SHOT)
	
	# Auto reload if empty
	if current_ammo == 0:
		$emptySound.play()
		reload()

func _fire_raycast() -> void:
	if not camera or not space_state:
		return
		
	# Update cached camera direction
	camera_basis_z = -camera.global_transform.basis.z
	var from := camera.global_position
	var to := from + camera_basis_z * gun_range
	
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	
	var result := space_state.intersect_ray(query)
	
	if result:
		var hit := result.collider as Node3D
		var health := hit.get_node_or_null("Health") as Health
		
		if health:
			# Award points for hitting enemy
			if playerRef and playerRef.has_method("add_points"):
				var points := 10 * PowerUpManager.get_points_multiplier()
				playerRef.add_points(points)
			
			# Deal damage (insta-kill if active)
			var damage_to_deal := 999999.0 if PowerUpManager.insta_kill_active else damage
			health.take_damage(damage_to_deal, playerRef)

func refill_ammo() -> void:
	current_ammo = max_ammo
	reserve_ammo = max_ammo * 3  # Reset reserve to starting amount
	_update_ammo_display()

func reload() -> void:
	if is_reloading or current_ammo == max_ammo or reserve_ammo == 0:
		return
	
	is_reloading = true
	reload_started.emit()
	
	await get_tree().create_timer(reload_time, false).timeout
	
	var ammo_needed := max_ammo - current_ammo
	var ammo_to_reload := int(min(ammo_needed, reserve_ammo))
	
	current_ammo += ammo_to_reload
	reserve_ammo -= ammo_to_reload
	
	is_reloading = false
	reload_finished.emit()
	ammo_changed.emit(current_ammo, reserve_ammo)
	_update_ammo_display()

# Helper functions
func _update_ammo_display() -> void:
	if ammo_count_label:
		ammo_count_label.text = "%d / %d" % [current_ammo, reserve_ammo]

func _hide_muzzle_flash() -> void:
	if muzzle_light:
		muzzle_light.visible = false

func _reset_shoot_cooldown() -> void:
	can_shoot = true
