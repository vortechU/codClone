extends Node

# Game state
var current_round: int = 1
var zombies_remaining: int = 0
var zombies_killed_this_round: int = 0

# Point awards (CoD Zombies values)
const POINTS_PER_HIT = 10
const POINTS_PER_KILL = 50
const POINTS_PER_HEADSHOT_KILL = 100

signal round_started(round_number: int)
signal round_ended(round_number: int)
signal zombie_killed(killer: Node)

func award_hit_points(player: Node) -> void:
    if player and player.has_method("add_points"):
        player.add_points(POINTS_PER_HIT)

func award_kill_points(player: Node, is_headshot: bool = false) -> void:
    if player and player.has_method("add_points"):
        var points = POINTS_PER_HEADSHOT_KILL if is_headshot else POINTS_PER_KILL
        player.add_points(points)
    
    zombies_killed_this_round += 1
    emit_signal("zombie_killed", player)

func start_round(gameRound: int) -> void:
    current_round = gameRound
    zombies_remaining = 6 + (gameRound * 4)  # CoD Zombies formula
    zombies_killed_this_round = 0
    emit_signal("round_started", gameRound)
func end_round() -> void:
    emit_signal("round_ended", current_round)