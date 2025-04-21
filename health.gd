extends ProgressBar

@onready var timer = $Timer
@onready var damage_bar: ProgressBar = $damage

var health = 0: set = _set_health

func _ready():
	init_health(100) # Or set this from Player later

func init_health(_health):
	health = _health
	max_value = health
	value = health
	if damage_bar:
		damage_bar.max_value = health
		damage_bar.value = health

func _set_health(_new_health):
	var prev_health = health
	health = min(max_value, _new_health)
	value = health

	if health <= 0:
		queue_free()

	if health < prev_health:
		timer.start()
	elif damage_bar:
		damage_bar.value = health

func _on_timer_timeout():
	if damage_bar:
		damage_bar.value = health
