extends Node

# Active power-up states
var insta_kill_active: bool = false
var double_points_active: bool = false

# Timers
var insta_kill_timer: float = 0.0
var double_points_timer: float = 0.0

# Signals
signal power_up_activated(type: String, duration: float)
signal power_up_expired(type: String)

func _process(delta: float) -> void:
	# Update insta-kill timer
	if insta_kill_active and insta_kill_timer > 0:
		insta_kill_timer -= delta
		if insta_kill_timer <= 0:
			insta_kill_active = false
			emit_signal("power_up_expired", "insta_kill")
	
	# Update double points timer
	if double_points_active and double_points_timer > 0:
		double_points_timer -= delta
		if double_points_timer <= 0:
			double_points_active = false
			emit_signal("power_up_expired", "double_points")

func activate_insta_kill(duration: float) -> void:
	insta_kill_active = true
	insta_kill_timer = duration
	emit_signal("power_up_activated", "insta_kill", duration)
	print("INSTA-KILL ACTIVATED! Duration: ", duration, "s")

func activate_nuke() -> void:
	# Kill all enemies instantly
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy.has_node("Health"):
			var health: Health = enemy.get_node("Health")
			health.take_damage(999999, null)
	
	emit_signal("power_up_activated", "nuke", 0.0)
	print("NUKE ACTIVATED! All enemies killed!")

func activate_max_ammo() -> void:
	# Refill all players' ammo
	var players = get_tree().get_nodes_in_group("Player")
	for player in players:
		var gun = player.find_child("Gun", true, false)
		if gun and gun.has_method("refill_ammo"):
			gun.refill_ammo()
	
	emit_signal("power_up_activated", "max_ammo", 0.0)
	print("MAX AMMO! All weapons refilled!")

func activate_double_points(duration: float) -> void:
	double_points_active = true
	double_points_timer = duration
	emit_signal("power_up_activated", "double_points", duration)
	print("DOUBLE POINTS ACTIVATED! Duration: ", duration, "s")

func get_points_multiplier() -> int:
	return 2 if double_points_active else 1
