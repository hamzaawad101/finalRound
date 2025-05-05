extends Control


func _on_computer_pressed() -> void:
	Global.selected_ai_character = "computer"
	get_tree().change_scene_to_file("res://ground.tscn")


func _on_ai_2_pressed() -> void:
	Global.selected_ai_character = "AI2"
	get_tree().change_scene_to_file("res://ground.tscn")
