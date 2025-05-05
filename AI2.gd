extends CharacterBody2D
class_name AI2
# --- Exported variables ---
@export var speed: float = 200.0
@export var player_path: NodePath
@export var jump_velocity: float = -150.0
@export var double_jump_velocity: float = -150
@export var attack_cooldown: float = 0.4
@export var max_health: int = 100
@export var hitbox_offset: Vector2 = Vector2(20, 0)
@export var movement_smoothing: float = 0.15
@export var decision_update_frequency: float = 0.2
@export_range(0, 100) var aggression_level: int = 75
@export var debug_mode: bool = true  # Enable debug visualization
@export var attack_start_distance:  float = 60.0   # when AI can begin attacking
@export var attack_stop_distance:   float = 50.0   # how close AI will get at minimum
@export var special_attack_cooldown: float = 5.0
@export var special_attack_chance: int = 25  # % chance to use it instead of regular attack
@export var special_attack_lunge: float = 1.0
@export var special_attack_damage: int = 25
var time_since_special_attack: float = 0.0
# --- Nodes and constants ---
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var player: Node2D = get_node("/root/ground/player")
@onready var deal_damage_zone = $AIdealDamage
@onready var damage_shape: CollisionShape2D = $AIdealDamage/CollisionShape2D
const TreeNode = preload("res://TreeNode.gd")
const DecisionNode = preload("res://DecisionNode.gd")
const ActionNode = preload("res://ActionNode.gd")
const RETREAT_SAFE_DISTANCE = 300
# --- State variables ---
enum AIState { IDLE, RUNNING, ATTACKING, JUMPING, FALLING, RETREATING, STRAFING }
const MINIMUM_DISTANCE = 200  
var current_state: AIState = AIState.IDLE
var last_attack_was_1: bool = false
var is_dead: bool = false
var current_health: int = max_health
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var has_double_jumped: bool = false
var animation_locked: bool = false
var direction: Vector2 = Vector2.ZERO
var target_direction: Vector2 = Vector2.ZERO
var was_in_air: bool = false
var can_attack: bool = true
var is_attacking: bool = false
var decision_tree: TreeNode
var attack_commit_time: float = 0.4
var attack_committed_until: float = 0.0
var decision_cooldown_timer: float = 0.0
var action_change_delay: float = 0.0
var last_player_position: Vector2 = Vector2.ZERO
var player_movement_pattern: Array = []
var player_attack_frequency: float = 0.0
var distance_to_player: float = 0.0
var time_since_last_attack: float = 0.0
var attack_timeout: float = 1.5
var player_direction: Vector2 = Vector2.ZERO  #  Vector pointing to player
var player_tracking_enabled: bool = true  # Toggle for player tracking
const SPEED := 150
const JUMP_VELOCITY := -400
const GRAVITY := 900
const ATTACK_RANGE := 60.0
const ATTACK_COOLDOWN := 0.5
var enemy_alive := true
var is_jumping := false
var enemy_in_range := false
var obstacle_in_path := false
var attack_timer := 0.0
var animation_done := false
var health = 100

var min_health = 0
var taking_damage = false
var is_roaming: bool
var damage_to_deal = 10
var attack_type: String = ""
# Frames when damage is active for each attack
var attack_hit_frames = {
	"attack1": [4, 5],
	"attack2": [3, 4],
	"attack3": [6, 7],
	"special_attack":[4,5,8,9]
}
func update_animation() -> void:
	if animation_locked:
		return  # Don't change animation while locked
		
	# More dynamic animation selection based on both state and movement
	match current_state:
		AIState.IDLE:
			animated_sprite.play("idle")
		AIState.RUNNING, AIState.STRAFING, AIState.RETREATING:
			animated_sprite.play("run")
		AIState.ATTACKING:
			# Animation is handled by attack methods
			pass
		AIState.JUMPING:
			if velocity.y < 0:
				animated_sprite.play("jump_start")
			else:
				set_state(AIState.FALLING)
				animated_sprite.play("jump_end")  # Add a falling 
		AIState.FALLING:
			animated_sprite.play("jump_end")  # Add a falling

	# Update sprite direction 
	face_player()

# Separated method to handle sprite direction
func face_player():
	if player.global_position.x < global_position.x:
		animated_sprite.flip_h = true
		deal_damage_zone.scale.x = -1
	else:
		animated_sprite.flip_h = false
		deal_damage_zone.scale.x = 1

func set_state(new_state: AIState):
	if current_state != new_state:
		# State transition logic
		match new_state:
			AIState.ATTACKING:
				# Don't interrupt attacks with other states
				if current_state == AIState.ATTACKING:
					return
			AIState.JUMPING:
				# Play jump start animation
				if is_on_floor() and not animation_locked:
					animated_sprite.play("jump_start")  
		
		current_state = new_state
		if not animation_locked:
			update_animation()

# --- Ready ---
func _ready():
	damage_shape.disabled = true 
	play_animation("idle")
	animated_sprite.connect("animation_finished", Callable(self, "_on_animation_finished"))
	animated_sprite.connect("frame_changed", Callable(self, "_on_frame_changed"))
	set_up_decision_tree()
	current_health = max_health
	last_player_position = player.global_position if player else global_position
func play_animation(name: String):
	if not animated_sprite.is_playing() or animated_sprite.animation != name:
		animated_sprite.speed_scale = 1.0
		animated_sprite.play(name)
func set_up_decision_tree() -> void:
	var idle_action = ActionNode.new().init(Callable(self, "idle_action"))
	var attack_action = ActionNode.new().init(Callable(self, "attack_player"))
	var chase_action = ActionNode.new().init(Callable(self, "chase_player"))
	var retreat_action = ActionNode.new().init(Callable(self, "retreat_from_player"))
	var strafe_action = ActionNode.new().init(Callable(self, "strafe_around_player"))
	var dodge_action = ActionNode.new().init(Callable(self, "dodge_attack"))
	
	# Is player attacking decision
	var player_attacking_decision = DecisionNode.new().init(
		Callable(self, "is_player_attacking"),
		dodge_action,  # If player is attacking, consider dodging
		attack_action  # Otherwise attack
	)
	
	# Attack vs strafe decision
	var attack_decision = DecisionNode.new().init(
		Callable(self, "should_attack"),
		attack_action,     # If should attack, attack immediately
		strafe_action      # Otherwise strafe around player
	)
	
	# Player distance decision
	var near_decision = DecisionNode.new().init(
		Callable(self, "is_player_near"),
		player_attacking_decision,  # If near, check if player is attacking
		chase_action                # Otherwise chase player
	)
	
	# Too close decision
	var proximity_decision = DecisionNode.new().init(
		Callable(self, "is_too_close"),
		retreat_action,  # If too close, retreat
		near_decision    # Otherwise check if in range to attack
	)
	
	# Root decision - IMPROVED to always know player location
	decision_tree = DecisionNode.new().init(
		Callable(self, "is_player_valid"),
		proximity_decision,  # If player exists, check proximity
		idle_action          # Otherwise idle/patrol
	)
func _on_frame_changed():
	var anim = animated_sprite.animation
	var frame = animated_sprite.frame
	
	if is_attacking and anim in attack_hit_frames:
		var active_frames = attack_hit_frames[anim]
		if frame in active_frames:
			damage_shape.disabled = false
		else:
			damage_shape.disabled = true
	else:
		damage_shape.disabled = true
# --- Physics Process ---
func _physics_process(delta: float):
	if not Global.game_started:
		return
	
	Global.AiDamageAmount = damage_to_deal
	Global.AiDamageZone = $AIdealDamage
	
	if is_dead:
		return

	# Increment time since last attack
	time_since_last_attack += delta
	
	# Update player tracking
	update_player_tracking()

	if Time.get_ticks_msec() / 1000.0 < attack_committed_until:
		velocity.x = move_toward(velocity.x, 0, speed * 0.1)  # Slow deceleration during attacks
		apply_gravity(delta)
		move_and_slide()
		return

	# Force attack if idle too long and player is near
	if can_attack and not is_attacking and time_since_last_attack > attack_timeout and is_player_near():
		attack_player()
		decision_cooldown_timer = decision_update_frequency  # Reset decision timer
	
	  # Decision cooldown with jitter to make behavior less robotic
	if decision_cooldown_timer > 0:
		decision_cooldown_timer -= delta
	else:
		# Ensure decision tree is initialized before evaluation
		if decision_tree != null:
			decision_tree.evaluate(self)  # Evaluate the AI decision tree
		decision_cooldown_timer = decision_update_frequency + randf_range(-0.05, 0.1)  


	# Action change cooldown
	if action_change_delay > 0:
		action_change_delay -= delta
	
	# Apply smooth direction changes
	if target_direction != direction:
		direction.x = move_toward(direction.x, target_direction.x, movement_smoothing)
	
	# Apply gravity
	apply_gravity(delta)

	# Apply movement with smooth acceleration/deceleration
	var target_speed = direction.x * speed

	# Retrieve player's direction if necessary
	if player and player.has_method("get_direction"):
		var player_direction = player.get_direction()
		# You can now use player_direction to adjust AI movement logic
		if player_direction.x > 0:
			# Example: If the player is moving right, the AI might respond
			pass
		elif player_direction.x < 0:
			# Example: If the player is moving left, the AI might respond
			pass

	# Apply final velocity based on the target speed
	velocity.x = move_toward(velocity.x, target_speed, speed * 0.2)
	
	# Move the AI
	move_and_slide()

	# Check if just landed
	if was_in_air and is_on_floor():
		land()
		was_in_air = false


# Update player position tracking
func update_player_tracking() -> void:
	if not player:
		player_tracking_enabled = false
		distance_to_player = 1000.0  # Large value if no player
		return
		
	player_tracking_enabled = true
	player_direction = player.global_position - global_position
	distance_to_player = player_direction.length()
	
	# Track player movement
	if last_player_position.distance_to(player.global_position) > 5:
		player_movement_pattern.append(player.global_position - last_player_position)
		if player_movement_pattern.size() > 5:
			player_movement_pattern.remove_at(0)
		last_player_position = player.global_position

func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
		was_in_air = true
	else:
		has_double_jumped = false

# --- Decision Functions ---
# Basic check if player exists
func is_player_valid() -> bool:
	return player != null
func is_player_near() -> bool:
	return distance_to_player <= attack_start_distance
	
func is_player_in_optimal_range() -> bool:
	return distance_to_player >= 35 and distance_to_player <= 60

# IMPROVED: Now uses the player_tracking system
func is_player_visible() -> bool:
	if not player_tracking_enabled:
		return false
	return abs(player_direction.y) < 40

#Now uses the player_tracking system
func is_too_close() -> bool:
	return distance_to_player < 20

func is_player_attacking() -> bool:
	# Check if the player exists and has an 'is_attacking' variable
	if player:
		# Check directly for is_attacking or the player's animation state
		return player.is_attacking or (player.has_method("get_animation_state") and player.get_animation_state() == "attacking")
	return false
func should_attack() -> bool:
	if not can_attack:
		return false
		
	# More likely to attack at low health
	var health_factor = 1.0 - (current_health / float(max_health))
	
	# Higher base chance to attack
	var attack_chance = 65 + (health_factor * 20)  # Base 65% chance
	
	# Even higher chance if we haven't attacked in a while
	if time_since_last_attack > 1.0:
		attack_chance += 20  # Up to 85%
		
	# Almost certain to attack if in perfect range
	if is_player_in_optimal_range():
		attack_chance += 15  # Up to 100%
	
	return randi() % 100 < attack_chance

func should_dodge() -> bool:
	if not is_on_floor() or current_state == AIState.JUMPING:
		return false  # Can't dodge while in air
		
	# Only dodge sometimes even when player attacks
	if is_player_attacking():
		return randi() % 100 < 40  # 40% dodge chance
		
	return false


# Function to check if retreating is safe (when AI is far enough from the player)
# Improved retreat safety check
func is_retreat_safe() -> bool:
	if not player:
		return true
	var distance = global_position.distance_to(player.global_position)
	return distance > MINIMUM_DISTANCE  # AI is considered safe if it's beyond the minimum distance
# --- Action Functions ---

# retreat logic
func retreat_from_player() -> void:
	if action_change_delay > 0:
		return

	# If we're already far enough from the player, stop retreating
	if is_retreat_safe():
		set_state(AIState.IDLE)
		return

	set_state(AIState.RETREATING)

	# Get direction AWAY from player
	var direction = (global_position - player.global_position).normalized()
	var retreat_velocity = direction * speed * 0.8
	velocity.x = retreat_velocity.x

	# Maybe jump away
	if is_on_floor() and randi() % 100 < 30:
		velocity.y = jump_velocity * 0.8
		set_state(AIState.JUMPING)

	move_and_slide()

	action_change_delay = 0.3 + randf() * 0.2

func dodge_attack() -> void:
	if not is_on_floor() or action_change_delay > 0:
		return
		
	# Calculate dodge direction based on player position and velocity
	var dodge_direction = -sign(player_direction.x)
	
	# Sometimes dodge toward player to be unpredictable
	if randi() % 100 < 20:
		dodge_direction *= -1
		
	target_direction.x = dodge_direction
	velocity.x = dodge_direction * speed * 1.5  # Quick dodge
	velocity.y = jump_velocity * 0.7  # Small hop
	set_state(AIState.JUMPING)
	
	action_change_delay = 0.25


# strafing logic
func strafe_around_player():
	if action_change_delay > 0:
		return

	set_state(AIState.STRAFING)

	# Check the distance to the player
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# If AI is too close, retreat instead of strafing
	if distance_to_player < MINIMUM_DISTANCE:
		retreat_from_player()
		return
	
	# Choose strafing direction with more intelligent logic
	if randi() % 100 < 20 or target_direction.x == 0:
		# Prefer strafing perpendicular to player's facing direction
		if player and player.has_method("get_direction"):
			var player_direction = player.get_direction()
			# If player is facing right, strafe away from that
			if player_direction.x > 0:
				target_direction.x = -1
			else:
				target_direction.x = 1
		else:
			# Random direction if we can't get player direction
			target_direction.x = [1, -1][randi() % 2]

	# Occasionally jump while strafing
	if is_on_floor() and randi() % 100 < 5:
		velocity.y = jump_velocity * 0.6  # Small hop
		set_state(AIState.JUMPING)

	# Apply movement based on target direction
	velocity.x = move_toward(velocity.x, target_direction.x * speed, speed * 0.1)

	action_change_delay = 0.2 + randf() * 0.2

	# Break out of strafing to attack if the player is in good range
	if can_attack and is_player_in_optimal_range() and time_since_last_attack > 0.5:
		# 50% chance to immediately attack instead of strafing
		if randi() % 100 < 50:
			action_change_delay = 0
			attack_player()
func perform_attack(anim_name: String, lunge_factor: float) -> void:
	# set up
	is_attacking = true
	animation_locked = true
	damage_shape.disabled = false
	
	# play and lunge
	play_animation(anim_name)
	velocity.x = sign(target_direction.x) * speed * lunge_factor
	
	# wait for the animation to fully finish
	await animated_sprite.animation_finished
	
	# tear down
	_end_attack()


func _end_attack() -> void:
	is_attacking = false
	animation_locked = false
	damage_shape.disabled = true
	update_animation()  # return to idle/run/jump
	
var recent_attacks: Array = []

func attack_player() -> void:
	if not can_attack or is_attacking or action_change_delay > 0:
		return

	time_since_last_attack = 0
	can_attack = false
	set_state(AIState.ATTACKING)

	# Face the player
	if player:
		target_direction.x = sign(player.global_position.x - global_position.x)
		animated_sprite.flip_h = player.global_position.x < global_position.x

	# Define attack options with weighted entries
	var attack_pool := [
		{"name": "attack1", "lunge": 0.3},
		{"name": "attack2", "lunge": 0.5},
		{"name": "attack3", "lunge": 0.3},
		{"name": "special_attack", "lunge": 0.7},
	]

	if recent_attacks.size() > 0:
		attack_pool = attack_pool.filter(func(a): return a["name"] != recent_attacks[-1])

	# Choose a random attack from pool
	var attack_choice = attack_pool[randi() % attack_pool.size()]
	var anim_name = attack_choice["name"]
	var lunge = attack_choice["lunge"]

	# Store last used attack
	recent_attacks.append(anim_name)
	if recent_attacks.size() > 3:
		recent_attacks.pop_front()

	# Perform the selected attack
	if anim_name == "special_attack":
		perform_special_attack(anim_name, lunge)
	else:
		perform_attack(anim_name, lunge)
		last_attack_was_1 = anim_name == "attack1"

	# Commit timing & cooldown
	attack_committed_until = Time.get_ticks_msec() / 1000.0 + attack_commit_time
	action_change_delay = attack_cooldown
	attack_timer = ATTACK_COOLDOWN

	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true

func perform_special_attack(anim_name: String, lunge: float) -> void:
	animated_sprite.play(anim_name)
	velocity.x = lunge * target_direction.x * 100
	
#  Better chasing logic
func chase_player() -> void:
	if is_attacking or action_change_delay > 0:
		return
		
	set_state(AIState.RUNNING)
	update_animation()
	# More direct calculation of direction to player
	if player:
		target_direction.x = sign(player.global_position.x - global_position.x)
	
	# Occasionally jump if player is above
	if player and player.global_position.y < global_position.y - 20 and is_on_floor():
		if randi() % 50 < 20:
			velocity.y = jump_velocity
			set_state(AIState.JUMPING)
	
	# Small chance to strafe while chasing
	if randi() % 100 < 5 and distance_to_player < 80:
		strafe_around_player()
		
	action_change_delay = 0.15

func idle_action() -> void:
	if is_attacking or action_change_delay > 0:
		return
		
	set_state(AIState.IDLE)

	# Random small movements while idle
	if randi() % 100 < 3:  # Small chance to move
		target_direction.x = randf_range(-1, 1)  # Random direction
		action_change_delay = 1.0 + randf() * 1.0
	else:
		target_direction.x = move_toward(target_direction.x, 0, 0.05)  # Gradually stop
	
	# Sometimes look around 
	if randi() % 100 < 2:
		animated_sprite.flip_h = !animated_sprite.flip_h
		
	# If player suddenly appears, break out of idle immediately
	if player and distance_to_player < 100:
		action_change_delay = 0
		decision_cooldown_timer = 0

# --- Combat Functions ---
func attack1():  perform_attack("attack1", 0.3)
func attack2():  perform_attack("attack2", 0.5)
func attack3():  perform_attack("attack3", 0.3)
func _on_a_ihit_box_area_entered(area: Area2D):
	if area == Global.playerDamageZone:
		var damage = Global.playerDamageAmount
		take_damage(damage)

func land():
	if not animation_locked:
		animated_sprite.play("jump_end")  # play landing anim 
		await animated_sprite.animation_finished
		set_state(AIState.IDLE)
		update_animation()

# --- Damage Functions ---
func take_damage(amount: int):
	if is_dead:
		return  # Don't process damage if already dead
	health -= amount
	
	# Cancel current action when hit
	action_change_delay = 0
	
	# Flash sprite or play hit animation
	animated_sprite.modulate = Color(5, 5, 5, 1)  # Flash white
	await get_tree().create_timer(0.3).timeout
	if not is_dead:
		animated_sprite.modulate = Color(1, 1, 1, 1)  # Return to normal
	
	if health <= 0:
		die()
	else:
		# Check for counterattack
		var counterattack_chance = 40 + (1.0 - (current_health / float(max_health))) * 40
		if randi() % 100 < counterattack_chance and can_attack:
			# Reset cooldowns to allow immediate action
			decision_cooldown_timer = 0
			action_change_delay = 0
			
			# Either attack or retreat based on health
			if health < max_health * 0.3:  # Low health
				retreat_from_player()
			else:
				attack_player()

func die() -> void:
	if is_dead:
		return
	is_dead = true
	animation_locked = true
	velocity = Vector2.ZERO
	animated_sprite.play("die")
	action_change_delay = 9999  # Lock action
