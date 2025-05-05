extends CharacterBody2D
class_name AICharacter
# Constants
const SPEED := 150
const JUMP_VELOCITY := -400
const GRAVITY := 900
const ATTACK_RANGE := 60.0
const ATTACK_COOLDOWN := 0.5
@onready var decision_graph := preload("res://StateGraph.gd").new()
# Nodes
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var player: Node2D = get_node("/root/ground/player")
@onready var deal_damage_zone = $AIdealDamage
@onready var damage_shape: CollisionShape2D = $AIdealDamage/CollisionShape2D
# Attack hitbox activation frames (inclusive)
var attack_hit_frames := {
	"attack1": [3, 4],
	"attack2": [5, 6]
}
# AI Decision Graph

# State
var current_state := "idle"
var is_dead := false
var enemy_alive := true
var is_jumping := false
var enemy_in_range := false
var obstacle_in_path := false
var attack_timer := 0.0
var animation_done := false
var health = 100
var max_health = 100
var min_health = 0
var taking_damage = false
var is_roaming: bool
var damage_to_deal = 10
var is_attacking: bool = false
var attack_type: String = ""
var knockback := Vector2.ZERO
var knockback_timer := 0.0
const KNOCKBACK_DURATION := 0.2 # seconds


func _ready():
	init_graph()
	damage_shape.disabled = true 
	play_animation("idle")
	sprite.connect("animation_finished", Callable(self, "_on_animation_finished"))
	sprite.connect("frame_changed", Callable(self, "_on_frame_changed"))

func _physics_process(delta):
	if not Global.game_started:
		return
	Global.AiDamageAmount = damage_to_deal
	Global.AiDamageZone = $AIdealDamage
	if is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# Update flags and facing
	update_flags()
	face_player()
	update_state()

	# Only handle normal state when not being knocked back
	if knockback_timer <= 0:
		handle_state()
	else:
		# Apply knockback
		velocity.x = knockback.x
		knockback_timer -= delta
		if knockback_timer <= 0:
			knockback = Vector2.ZERO

	attack_timer -= delta
	move_and_slide()
	
func init_graph():
	var nodes = [
		Graph.new("idle", {
			"enemy_near": "attack1",
			"low_health": "run",
			"jump_required": "jump_start",
			"default": "run"
		}),
		Graph.new("attack1", {
			"animation_done": "attack2",
			"enemy_dead": "idle",
			"default": "attack1"
		}),
		Graph.new("attack2", {
			"animation_done": "idle",
			"default": "attack2"
		}),
		Graph.new("run", {
			"obstacle": "jump_start",
			"enemy_near": "attack1",
			"default": "run"
		}),
		Graph.new("jump_start", {
			"default": "jump_loop"
		}),
		Graph.new("jump_loop", {
			"on_ground": "jump_end",
			"default": "jump_loop"
		}),
		Graph.new("jump_end", {
			"default": "idle"
		}),
		Graph.new("takeHit", {
			"animation_done": "idle",
			"health_low": "death",
			"default": "takeHit"
		}),
		Graph.new("death", {
			"default": "death"
		}),
	]

	for node in nodes:
		decision_graph.add_node(node)
func update_flags():
	var distance_to_player = global_position.distance_to(player.global_position)
	enemy_in_range = distance_to_player <= ATTACK_RANGE
	obstacle_in_path = false # Replace with raycast logic if needed

func update_state():
	var conditions = {
		"enemy_near": enemy_in_range,
		"enemy_dead": not enemy_alive,
		"enemy_alive": enemy_alive,
		"low_health": health < 30,
		"jump_required": obstacle_in_path,
		"on_ground": is_on_floor(),
		"health_low": health <= 0,
		"obstacle": obstacle_in_path,
		"animation_done": animation_done
	}

	current_state = decision_graph.get_next_state(current_state, conditions)
	animation_done = false
func handle_state():
	match current_state:
		"idle":
			velocity.x = 0
			play_animation("idle")
		"run":
			var dir = sign(player.global_position.x - global_position.x)
			velocity.x = dir * SPEED
			play_animation("run")
		"jump_start":
			if is_on_floor():
				velocity.y = JUMP_VELOCITY
				is_jumping = true
				play_animation("jump_start")
		"jump_loop":
			play_animation("jump_loop")
		"jump_end":
			is_jumping = false
			play_animation("jump_end")
		"attack1":
			velocity.x = 0
			if attack_timer <= 0:
				_begin_attack("attack1")
		"attack2":
			velocity.x = 0
			if attack_timer <= 0:
				_begin_attack("attack2")
		"takeHit":
			velocity.x = knockback.x # Apply knockback while taking hit
			play_animation("takeHit")
		"death":
			is_dead = true
			velocity = Vector2.ZERO
			play_animation("death")

func play_animation(name: String):
	if not sprite.is_playing() or sprite.animation != name:
		sprite.speed_scale = 1.0
		sprite.play(name)

func face_player():
	if player.global_position.x < global_position.x:
		sprite.flip_h = true
		deal_damage_zone.scale.x = -1
	else:
		sprite.flip_h = false
		deal_damage_zone.scale.x = 1

func _on_animation_finished():
	animation_done = true
	if current_state.begins_with("attack"):
		damage_shape.disabled = true


func hit(damage: int):
	if is_dead:
		return

	health -= damage
	animation_done = false
	
	# Apply knockback right after starting the takeHit animation
	var knockback_strength = 300
	var direction = sign(global_position.x - player.global_position.x) # Push away from player
	knockback.x = direction * knockback_strength
	knockback_timer = KNOCKBACK_DURATION
	
	# Start the "takeHit" animation immediately
	current_state = "takeHit"
	play_animation("takeHit")

	# If health is 0 or less, switch to "death" state
	if health <= 0:
		is_dead = true
		current_state = "death"
		play_animation("death")


func set_enemy_alive(value: bool):
	enemy_alive = value


func _on_a_ihit_box_area_entered(area: Area2D):
	if area == Global.playerDamageZone:
		var damage = Global.playerDamageAmount
		hit(damage)
		
func _begin_attack(anim_name: String) -> void:
	is_attacking = true
	attack_timer = ATTACK_COOLDOWN
	play_animation(anim_name)

	await sprite.animation_finished

	is_attacking = false
	# Defer disabling the damage shape
	damage_shape.set_deferred("disabled", true)

# Deferred function to disable the damage shape
#func disable_damage_shape():
	#damage_shape.disabled = true
func _on_frame_changed():
	var anim = sprite.animation
	var frame = sprite.frame

	if is_attacking and anim in attack_hit_frames:
		var active_frames = attack_hit_frames[anim]
		if frame in active_frames:
			# Defer enabling the damage shape
			damage_shape.set_deferred("disabled", false)
		else:
			# Defer disabling the damage shape
			damage_shape.set_deferred("disabled", true)
	else:
		# Defer disabling the damage shape
		damage_shape.set_deferred("disabled", true)
