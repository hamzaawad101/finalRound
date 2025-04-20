extends CharacterBody2D
class_name AICharacter

# --- Exported variables ---
@export var speed: float = 200.0
@export var player_path: NodePath
@export var jump_velocity: float = -150.0
@export var double_jump_velocity: float = -150
@export var attack_cooldown: float = 0.5
@export var max_health: int = 100
@export var hitbox_offset: Vector2 = Vector2(20, 0) # adjust this to match your sprite

# --- Nodes and constants ---
@onready var player: CharacterBody2D = get_node(player_path)
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
const TreeNode = preload("res://TreeNode.gd")
const DecisionNode = preload("res://DecisionNode.gd")
const ActionNode = preload("res://ActionNode.gd")

# --- State variables ---
enum AIState { IDLE, RUNNING, ATTACKING, JUMPING }

var current_state: AIState = AIState.IDLE
var last_attack_was_1: bool = false
var is_dead: bool = false
var current_health: int = max_health
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var has_double_jumped: bool = false
var animation_locked: bool = false
var direction: Vector2 = Vector2.ZERO
var was_in_air: bool = false
var can_attack: bool = true
var is_attacking: bool = false
var decision_tree: TreeNode
var attack_commit_time: float = 0.4
var attack_committed_until: float = 0.0
var decision_cooldown_time: float = 0.3
var decision_cooldown_timer: float = 0.0

# --- Movement ---
var move_input: Vector2 = Vector2.ZERO

func update_animation():
	match current_state:
		AIState.IDLE:
			animated_sprite.play("idle")
		AIState.RUNNING:
			animated_sprite.play("run")
		AIState.ATTACKING:
			animated_sprite.play("attack")
		AIState.JUMPING:
			animated_sprite.play("jump")
			
func set_state(new_state: AIState) -> void:
	if current_state != new_state:
		current_state = new_state
		update_animation()


# --- Ready ---
func _ready() -> void:
	var attack_action = ActionNode.new().init(Callable(self, "attack_player"))
	var chase_action = ActionNode.new().init(Callable(self, "chase_player"))
	var idle_action = ActionNode.new().init(Callable(self, "idle_action"))
	var retreat_action = ActionNode.new().init(Callable(self, "retreat_from_player"))

	var is_visible_decision = DecisionNode.new().init(
		Callable(self, "is_player_visible"),
		chase_action,
		idle_action
	)
	
	var near_decision = DecisionNode.new().init(
		Callable(self, "is_player_near"),
		attack_action,
		is_visible_decision
	)

	decision_tree = DecisionNode.new().init(
		Callable(self, "is_player_near"),
		attack_action,
		is_visible_decision
	)
	
	decision_tree = DecisionNode.new().init(
		Callable(self, "is_too_close"),
		retreat_action,
		near_decision
	)



# --- Physics Process ---
func _physics_process(delta: float) -> void:
	if is_dead:
		return
		
	if Time.get_ticks_msec() / 1000.0 < attack_committed_until:
		# If committed, can't move
		velocity.x = 0
		move_and_slide()
		return
	# Decision delay
	if decision_cooldown_timer > 0:
		decision_cooldown_timer -= delta
	else:
		decision_tree.evaluate(self)
		decision_cooldown_timer = decision_cooldown_time + randf() * 0.3  # Random extra thinking time!
		
	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta
		was_in_air = true
	else:
		has_double_jumped = false
	if was_in_air:
		land()
		was_in_air = false

	# Evaluate decision tree
	decision_tree.evaluate(self)

	# Apply movement
	velocity.x = direction.x * speed
	move_and_slide()

# --- Decision Functions ---
func is_player_near() -> bool:
	if player == null:
		return false
	return global_position.distance_to(player.global_position) < 30

func is_player_visible() -> bool:
	if player == null:
		return false
	# Very simple check; you could add real vision later
	return abs(global_position.y - player.global_position.y) < 30
	
func is_too_close() -> bool:
	return global_position.distance_to(player.global_position) < 10
	
func retreat_from_player() -> void:
	var move_dir = (global_position.x - player.global_position.x)
	direction.x = sign(move_dir)  # move away
	velocity.x = direction.x * speed * 0.5  # retreat slower

func attack_player() -> void:
	if not is_attacking and can_attack:
		if randi() % 100 < 60:  # Only 60% chance to actually attack when in range
			is_attacking = true
			can_attack = false

			set_state(AIState.ATTACKING)

			if last_attack_was_1:
				attack2()
			else:
				attack1()
			last_attack_was_1 = !last_attack_was_1

			attack_committed_until = Time.get_ticks_msec() / 1000.0 + attack_commit_time

			await get_tree().create_timer(attack_cooldown).timeout

			can_attack = true
			is_attacking = false


func chase_player() -> void:
	if not is_attacking:
		set_state(AIState.RUNNING)

	var move_dir = player.global_position.x - global_position.x
	direction.x = sign(move_dir)

	var chase_speed = speed

	# 20% chance to strafe instead of chasing directly
	if randi() % 100 < 20:
		chase_speed *= 0.7
		direction.x *= -1  # Move left or right randomly
	elif randi() % 100 < 10:
		# 10% chance to stop briefly
		direction.x = 0

	velocity.x = direction.x * chase_speed

	# Randomly jump if below player
	if player.global_position.y < global_position.y - 10 and is_on_floor():
		if randi() % 100 < 10:
			velocity.y = jump_velocity
			set_state(AIState.JUMPING)


func idle_action():
	if not is_attacking:
		set_state(AIState.IDLE)

	if randi() % 100 < 5:  # 5% chance each frame to move
		direction.x = randf_range(-1, 1)  # random left or right
	else:
		direction.x = move_toward(direction.x, 0, 0.1)  # slowly drift to stop
	velocity.x = direction.x * speed * 0.5  # patrol slower

# --- Combat Functions ---
func attack1() -> void:
	is_attacking = true
	can_attack = false
	animated_sprite.play("attack1") # assuming you have an "attack1" animation
		# Enable the hitbox right when the attack starts
	$HitBox.monitoring = true

	# Wait a short moment to simulate active attack window
	await get_tree().create_timer(0.2).timeout # Adjust this to match your hit timing

	# Disable hitbox after the attack window
	$HitBox.monitoring = false

	# Wait until the attack animation is fully over
	await animated_sprite.animation_finished
	# Reset attack state after cooldown
	await get_tree().create_timer(attack_cooldown).timeout
	is_attacking = false
	can_attack = true
	
# Alternate attack logic for attack2
func attack2() -> void:
	is_attacking = true
	can_attack = false
	animation_locked = true
	animated_sprite.play("attack2")

	$HitBox.monitoring = true
	await get_tree().create_timer(0.2).timeout
	$HitBox.monitoring = false

	await animated_sprite.animation_finished

	can_attack = true
	is_attacking = false
	animation_locked = false

# --- Landing ---
func land() -> void:
	# Handle landing animations if you have them
	animated_sprite.play("jump_end") # assuming you have a "land" animation

# --- Damage Functions ---
func take_damage(amount: int) -> void:
	current_health -= amount
	if current_health <= 0:
		die()

func die() -> void:
	is_dead = true
	animated_sprite.play("die") # assuming you have a "die" animation
	await animated_sprite.animation_finished
	queue_free()
