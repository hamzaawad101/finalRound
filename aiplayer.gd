extends CharacterBody2D

@export var speed: float = 100.0
@export var jump_velocity: float = -150.0
@export var attack_range: float = 50.0
@export var attack_cooldown: float = 1.0
@export var max_health: int = 3

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $HitBox
@onready var player: Node2D = get_parent().get_node("Player") # Adjust path if needed

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var direction: Vector2 = Vector2.ZERO
var can_attack = true
var is_attacking = false
var animation_locked = false
var has_double_jumped = false
var was_in_air = false
var is_dead = false
var current_health = max_health

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if not is_on_floor():
		velocity.y += gravity * delta
		was_in_air = true
	else:
		has_double_jumped = false
		if was_in_air:
			land()
			was_in_air = false

	# Follow and attack player
	update_ai_behavior()

	if not is_attacking:
		velocity.x = direction.x * speed
	else:
		velocity.x = 0

	move_and_slide()
	update_animation()
	update_facing_direction()

func update_ai_behavior():
	if not player or player.is_dead:
		direction = Vector2.ZERO
		return

	var distance = global_position.distance_to(player.global_position)
	var x_diff = player.global_position.x - global_position.x

	# Move toward player if not too close
	if abs(x_diff) > attack_range and not is_attacking:
		direction.x = sign(x_diff)
	else:
		direction.x = 0
		if can_attack and not is_attacking:
			attack()

func update_animation():
	if not animation_locked:
		if is_attacking:
			return
		elif not is_on_floor():
			animated_sprite.play("jump_loop")
		elif direction.x != 0:
			animated_sprite.play("run")
		else:
			animated_sprite.play("idle")

func update_facing_direction():
	if direction.x > 0:
		animated_sprite.flip_h = false
	elif direction.x < 0:
		animated_sprite.flip_h = true

func jump():
	velocity.y = jump_velocity
	animated_sprite.play("jump_start")
	animation_locked = true

func land():
	animated_sprite.play("jump_end")
	animation_locked = true

func attack():
	is_attacking = true
	can_attack = false
	animation_locked = true
	animated_sprite.play("attack1" if randi() % 2 == 0 else "attack2")
	hitbox.monitoring = true

	await get_tree().create_timer(0.2).timeout
	hitbox.monitoring = false

	await animated_sprite.animation_finished
	is_attacking = false
	animation_locked = false
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true

func take_damage(amount: int) -> void:
	if is_dead:
		return
	current_health -= amount
	if current_health <= 0:
		die()
	else:
		animated_sprite.play("takeHit")
		animation_locked = true
		await animated_sprite.animation_finished
		animation_locked = false

func die() -> void:
	if is_dead:
		return
	is_dead = true
	is_attacking = false
	can_attack = false
	velocity = Vector2.ZERO
	animated_sprite.play("death")
	await animated_sprite.animation_finished
	queue_free()

func _on_hit_box_body_entered(body: Node2D):
	if body.is_in_group("player"):
		body.take_damage(1)
