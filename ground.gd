extends Node2D

@onready var player = $player
@onready var player_health_bar = $CanvasLayer/Playerbar
@onready var ai_health_bar = $CanvasLayer/AIbar
@onready var countdown_label = $CanvasLayer/countdown
@onready var countdown_timer = $CanvasLayer/CountdownTimer
@onready var game_over_label = $CanvasLayer/GameOverLabel
var countdown_numbers = ["3", "2", "1", "FIGHT!"]
var countdown_index = 0
var game_started = false
var game_over = false
var ai_instance = null 
func _ready():
	player_health_bar.target = player
	
	var ai_scene_path = "res://characters/" + Global.selected_ai_character + ".tscn"
	var ai_scene = load(ai_scene_path)
	ai_instance = ai_scene.instantiate()
	ai_instance.position = Vector2(200, 100)
	add_child(ai_instance)
	ai_health_bar.target = ai_instance

	start_countdown()

func start_countdown():
	countdown_label.text = countdown_numbers[countdown_index]
	countdown_timer.start()


func _on_Countdown_timer_timeout():
	countdown_index += 1
	if countdown_index < countdown_numbers.size():
		countdown_label.text = countdown_numbers[countdown_index]
	else:
		countdown_label.hide()
		countdown_timer.stop()
		Global.game_started = true # Now allow players and AI to move 
func _process(delta):
	if not game_over and Global.game_started:
		if player.health <= 0:
			game_over = true
			show_game_over("LOSER")
		elif ai_instance and ai_instance.health <= 0:
			game_over = true
			show_game_over("WINNER")

func show_game_over(result_text):
	Global.game_started = false
	game_over_label.text = result_text
	game_over_label.show()
	
	await get_tree().create_timer(2.5).timeout
	get_tree().change_scene_to_file("res://menu.tscn")
