extends Control

func _ready():
	pass
	
func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://character_slot.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()
