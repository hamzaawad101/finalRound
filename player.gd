extends CharacterBody2D

@export var speed: float = 200.0
@export var jump_velocity: float = -150.0
@export var double_jump_velocity: float = -150
@export var attack_cooldown: float = 0.5
@export var max_health: int = 100
@export var hitbox_offset: Vector2 = Vector2(20, 0) # Set this to match your current right-side offset
var last_attack_was_1: bool = false
var is_dead: bool = false
var current_health: int = max_health
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var has_double_jumped: bool = false
var animation_locked: bool = false
var direction: Vector2 = Vector2.ZERO
var was_in_air: bool = false
var can_attack: bool = true
var is_attacking: bool = false

# This function processes all physics-related movements like gravity, jumping, etc.
func _physics_process(delta: float) -> void:
	if is_dead:
		return # if dead, ignore input

	# Add gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
		was_in_air = true
	else:
		has_double_jumped = false
		if was_in_air:
			land()
			was_in_air = false

	# Handle jump.
	if Input.is_action_just_pressed("jump_start") and not is_attacking:
		if is_on_floor():
			jump()
		elif not has_double_jumped:
			double_jump()

	# Handle attack input
	if Input.is_action_just_pressed("attack1") and can_attack and not is_attacking:
		if last_attack_was_1:
			attack2()
		else:
			attack1()
		last_attack_was_1 = !last_attack_was_1
	
	# Movement input (skip this if attacking!)
	if not is_attacking:
		direction = Input.get_vector("left", "right", "up", "down")
		if direction.x != 0 and animated_sprite.animation != "jump_end":
			velocity.x = direction.x * speed
		else:
			velocity.x = move_toward(velocity.x, 0, speed)
	else:
		# Freeze horizontal movement while attacking
		velocity.x = 0

	move_and_slide()
	update_animation()
	update_facing_direction()
	update_hitbox_position()

# Updates the animation based on current state
func update_animation():
	if not animation_locked:
		if is_attacking:
			# Don't override attack animation
			return
		elif not is_on_floor():
			animated_sprite.play("jump_loop")
		elif direction.x != 0:
			animated_sprite.play("run")
		else:
			animated_sprite.play("idle")

# Update character facing direction
func update_facing_direction():
	if direction.x > 0:
		animated_sprite.flip_h = false
	elif direction.x < 0:
		animated_sprite.flip_h = true

# Handle normal jump
func jump():
	velocity.y = jump_velocity
	animated_sprite.play("jump_start")
	animation_locked = true

# Handle double jump
func double_jump():
	velocity.y = double_jump_velocity
	animated_sprite.play("jump_double")
	animation_locked = true
	has_double_jumped = true

# Handle landing animation
func land():
	animated_sprite.play("jump_end")
	animation_locked = true

# Basic attack logic for attack1
func attack1() -> void:
	is_attacking = true
	can_attack = false
	animation_locked = true
	animated_sprite.play("attack1")

	# Enable the hitbox right when the attack starts
	$HitBox.monitoring = true

	# Wait a short moment to simulate active attack window
	await get_tree().create_timer(0.2).timeout # Adjust this to match your hit timing

	# Disable hitbox after the attack window
	$HitBox.monitoring = false

	# Wait until the attack animation is fully over
	await animated_sprite.animation_finished

	can_attack = true
	is_attacking = false
	animation_locked = false
	
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

# Take damage and trigger "take hit" animation
func take_hit() -> void:
	if animation_locked:
		return # Prevent interrupting other critical animations like death

	is_attacking = false
	can_attack = false
	animation_locked = true
	animated_sprite.play("takeHit")

	await animated_sprite.animation_finished

	can_attack = true
	animation_locked = false
	
# Function for taking damage
func take_damage(amount: int = 1) -> void:
	if is_dead or animation_locked:
		return

	current_health -= amount
	print("Health:", current_health)

	# Check if the health is below 0 and handle the death logic
	if current_health <= 0:
		die()
	else:
		take_hit()

# Handle death logic
func die() -> void:
	if is_dead:
		return

	# Mark character as dead
	is_dead = true
	is_attacking = false
	can_attack = false
	animation_locked = true
	velocity = Vector2.ZERO # Stop movement
	animated_sprite.play("death")

	# Wait for death animation to finish
	await animated_sprite.animation_finished
	current_health = max_health

	# Reload the scene for respawn
	get_tree().reload_current_scene()

# Update hitbox position based on sprite's facing direction
func update_hitbox_position():
	if animated_sprite.flip_h:
		$HitBox.position = Vector2(-hitbox_offset.x, hitbox_offset.y)
	else:
		$HitBox.position = hitbox_offset
		
# Called when animation finishes
func _on_animated_sprite_2d_animation_finished():
	if ["jump_end", "jump_start", "jump_double", "fall", "takeHit"].has(animated_sprite.animation):
		animation_locked = false
	elif ["attack1", "attack2"].has(animated_sprite.animation):
		is_attacking = false
		animation_locked = false
	elif animated_sprite.animation == "death":
		pass

# Hitbox collision detection
func _on_hit_box_body_entered(body: Node2D):
	if body.is_in_group("enemies"):
		print("Hit: ", body.name)
		take_damage(1)
