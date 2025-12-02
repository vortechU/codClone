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
var original_position: Vector3
var original_rotation: Vector3

# References
@onready var camera: Camera3D = get_parent() if get_parent() is Camera3D else get_viewport().get_camera_3d()
@onready var raycast: RayCast3D = $RayCast3D if has_node("RayCast3D") else null
@onready var muzzle_flash: Node3D = $MuzzleFlash if has_node("MuzzleFlash") else null
@onready var animation_player: AnimationPlayer = $AK_47/AnimationPlayer if has_node("AK_47/AnimationPlayer") else null
@onready var ammo_count_label: Label = get_node_or_null("../../UI/CanvasLayer/AmmoCount")

var base_fov: float = 75.0

signal ammo_changed(current: int, reserve: int)
signal weapon_fired
signal reload_started
signal reload_finished

func _ready() -> void:
	current_ammo = max_ammo
	if ammo_count_label:
		ammo_count_label.text = str(current_ammo) + " / " + str(reserve_ammo)
	
	emit_signal("ammo_changed", current_ammo, reserve_ammo)
	original_position = position
	original_rotation = rotation
	if camera:
		base_fov = camera.fov

func _process(delta: float) -> void:
	# Handle continuous shooting when holding
	if Input.is_action_pressed("Shoot") and not is_reloading:
		shoot()
	
	# Only bob when not playing animation
	var is_animation_playing = animation_player and animation_player.is_playing()
	
	if not is_animation_playing:
		# Weapon bobbing when moving
		var player = camera.get_parent() if camera else null
		var is_moving = false
		
		if player and player is CharacterBody3D:
			is_moving = player.velocity.length() > 0.1
		
		if is_moving:
			sway_time += delta * weapon_bob_speed
			var bob_offset = Vector3(
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
		var target_fov = ads_fov if is_aiming else base_fov
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
	if ammo_count_label:
		ammo_count_label.text = str(current_ammo) + " / " + str(reserve_ammo)
	emit_signal("ammo_changed", current_ammo, reserve_ammo)
	emit_signal("weapon_fired")
	
	# Play shoot animation
	if animation_player and animation_player.has_animation("Shoot"):
		animation_player.play("Shoot")
	
	# Perform raycast from camera
	_fire_raycast()
	
	# Fire rate cooldown
	can_shoot = false
	await get_tree().create_timer(fire_rate).timeout
	can_shoot = true
	
	# Auto reload if empty
	if current_ammo == 0:
		reload()

func _fire_raycast() -> void:
	if not camera:
		return
		
	var space_state = get_world_3d().direct_space_state
	var from = camera.global_transform.origin
	var to = from + (-camera.global_transform.basis.z * gun_range)
	
	var query = PhysicsRayQueryParameters3D.new()
	query.from = from
	query.to = to
	query.collide_with_areas = false
	query.collide_with_bodies = true
	
	var result = space_state.intersect_ray(query)
	
	if result:
		var hit = result.collider
		if hit.has_node("Health"):
			var health: Health = hit.get_node("Health")
			var player = get_parent().get_parent()  # Get player reference
			
			# Award points for hitting enemy (with multiplier for double points)
			if player and player.has_method("add_points"):
				var points = 10 * PowerUpManager.get_points_multiplier()
				player.add_points(points)
			
			# Deal damage (insta-kill if active)
			var damage_to_deal = damage
			if PowerUpManager.insta_kill_active:
				damage_to_deal = 999999  # One-shot kill
			
			health.take_damage(damage_to_deal, player)

func refill_ammo() -> void:
	current_ammo = max_ammo
	reserve_ammo = max_ammo * 3  # Reset reserve to starting amount
	if ammo_count_label:
		ammo_count_label.text = str(current_ammo) + " / " + str(reserve_ammo)

func reload() -> void:
	if is_reloading or current_ammo == max_ammo or reserve_ammo == 0:
		return
	
	is_reloading = true
	emit_signal("reload_started")
	
	await get_tree().create_timer(reload_time).timeout
	
	var ammo_needed = max_ammo - current_ammo
	var ammo_to_reload = min(ammo_needed, reserve_ammo)
	
	current_ammo += ammo_to_reload
	reserve_ammo -= ammo_to_reload
	
	is_reloading = false
	emit_signal("reload_finished")
	emit_signal("ammo_changed", current_ammo, reserve_ammo)
	
	# Update ammo label after reload
	if ammo_count_label:
		ammo_count_label.text = str(current_ammo) + " / " + str(reserve_ammo)
