extends Node2D

@onready var player = $player
var ai = null # Will be spawned

var player_target_position = Vector2(200, 300)
var ai_target_position = Vector2(600, 300)

var move_speed = 200
var intro_done = false

func _ready():
	# Spawn the correct AI based on selected character
	var ai_scene_path = "res://characters/" + Global.selected_ai_character + ".tscn"
	var ai_scene = load(ai_scene_path)
	ai = ai_scene.instantiate()
	ai.position = Vector2(900, 300) # Start off-screen right
	add_child(ai)

func _process(delta):
	if not intro_done and ai:
		var player_reached = false
		var ai_reached = false

		# Move player to target
		if player.position.x < player_target_position.x:
			player.position.x += move_speed * delta
			if player.has_node("AnimationPlayer"):
				player.get_node("AnimationPlayer").play("walk")
		else:
			player_reached = true
			if player.has_node("AnimationPlayer"):
				player.get_node("AnimationPlayer").play("idle")

		# Move AI to target
		if ai.position.x > ai_target_position.x:
			ai.position.x -= move_speed * delta
			if ai.has_node("AnimationPlayer"):
				ai.get_node("AnimationPlayer").play("walk")
		else:
			ai_reached = true
			if ai.has_node("AnimationPlayer"):
				ai.get_node("AnimationPlayer").play("idle")

		# If both reached
		if player_reached and ai_reached:
			intro_done = true
			start_game()

func start_game():
	# Save positions if you want
	Global.player_start_position = player.position
	Global.ai_start_position = ai.position

	# Now load the real game scene
	var main_game_scene = load("res://ground.tscn").instantiate()
	get_tree().root.add_child(main_game_scene)
	queue_free() # Remove intro scene
