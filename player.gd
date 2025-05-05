extends CharacterBody2D

@export var speed: float = 200.0
@export var jump_velocity: float = -150.0
@export var double_jump_velocity: float = -150
@export var attack_cooldown: float = 0.5
@export var max_health: int = 100

var last_attack_was_1: bool = false
var is_dead: bool = false
var current_health: int = max_health
var has_double_jumped: bool = false
var animation_locked: bool = false
var direction: Vector2 = Vector2.ZERO
var was_in_air: bool = false
var can_attack: bool = true
var is_attacking: bool = false
var is_knockbacked: bool = false
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var attack_type: String = ""
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var deal_damage_zone = $DealDamage
var health = 100
var healthMin = 0
var can_take_damage: bool
func _ready():
	Global.playerBody = self
	Global.playerAlive = true
	is_dead = false
	can_take_damage = true

func _physics_process(delta: float) -> void:
	Global.playerDamageZone = deal_damage_zone
	if is_dead:
		return

	if not is_on_floor():
		velocity += get_gravity() * delta
		was_in_air = true
	else:
		has_double_jumped = false
		if was_in_air:
			land()
			was_in_air = false

	if Input.is_action_just_pressed("jump_start") and not is_attacking:
		if is_on_floor():
			jump()
		elif not has_double_jumped:
			double_jump()

	if Input.is_action_just_pressed("attack1") and can_attack and not is_attacking:
		if last_attack_was_1:
			attack2()
		else:
			attack1()
		last_attack_was_1 = !last_attack_was_1

	if not is_attacking and not animation_locked and not is_knockbacked:
		direction = Input.get_vector("left", "right", "up", "down")
		if direction.x != 0 and animated_sprite.animation != "jump_end":
			velocity.x = direction.x * speed
		else:
			velocity.x = move_toward(velocity.x, 0, speed)
	elif is_knockbacked:
		velocity.x = move_toward(velocity.x, 0, speed * delta * 2)
	check_hitBox()
	move_and_slide()
	update_animation()
	update_facing_direction()
func check_hitBox():
	var hitbox_area = $PlayerHitBox.get_overlapping_areas()
	var damage: int
	if hitbox_area:
		var hitBox = hitbox_area.front()
		if hitBox.get_parent() is AI:
			damage = Global.AiDamageAmount
			
	if can_take_damage:
		take_damage(damage)

func take_damage(damage):
	print("test", damage)
	if damage != 0:
		if health > 0:
			take_hit()
			health -= damage
			print("Player Health: ", health)
			if health <= 0:
				health = 0
				is_dead = true
				Global.playerAlive = false
				die()
			take_damage_cooldown(1.0)
func die():
	animated_sprite.play("death")
	await get_tree().create_timer(3.5).timeout
	self.queue_free()
	
	get_tree().reload_current_scene()
				
func take_damage_cooldown(wait_time):
	can_take_damage = false
	await get_tree().create_timer(wait_time).timeout
	can_take_damage = true
	

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
		deal_damage_zone.scale.x = 1
	elif direction.x < 0:
		animated_sprite.flip_h = true
		deal_damage_zone.scale.x = -1

func jump():
	velocity.y = jump_velocity
	animated_sprite.play("jump_start")
	animation_locked = true

func double_jump():
	velocity.y = double_jump_velocity
	animated_sprite.play("jump_double")
	animation_locked = true
	has_double_jumped = true

func land():
	animated_sprite.play("jump_end")
	animation_locked = true

func attack1() -> void:
	is_attacking = true
	can_attack = false
	animation_locked = true
	attack_type = "attack1"
	animated_sprite.play("attack1")
	set_damage(attack_type)
	toggle_damage_collision(attack_type)

	await get_tree().create_timer(0.2).timeout
	await animated_sprite.animation_finished

	can_attack = true
	is_attacking = false
	animation_locked = false

func attack2() -> void:
	is_attacking = true
	can_attack = false
	animation_locked = true
	attack_type = "attack2"
	animated_sprite.play("attack2")
	
	toggle_damage_collision(attack_type)

	await get_tree().create_timer(0.2).timeout
	await animated_sprite.animation_finished

	can_attack = true
	is_attacking = false
	animation_locked = false

func toggle_damage_collision(attack: String) -> void:
	var damage_zone_collision = deal_damage_zone.get_node("CollisionShape2D")
	var wait_time: float
	if attack == "attack1":
		wait_time = .4
	elif attack == "attack2":
		wait_time = .4
	damage_zone_collision.disabled = false
	await get_tree().create_timer(wait_time).timeout
	damage_zone_collision.disabled = true

		
func take_hit() -> void:
	if animation_locked:
		return

	is_attacking = false
	can_attack = false
	animation_locked = true
	animated_sprite.play("takeHit")

	animated_sprite.modulate = Color(1, 0.2, 0.2)
	await get_tree().create_timer(0.1).timeout
	animated_sprite.modulate = Color(1, 1, 1)
	var dir = animated_sprite.flip_h if animated_sprite.flip_h else -1
	apply_knockback(dir)

	await animated_sprite.animation_finished
	can_attack = true
	animation_locked = false


func _on_animated_sprite_2d_animation_finished():
	if ["jump_end", "jump_start", "jump_double", "fall", "takeHit"].has(animated_sprite.animation):
		animation_locked = false
	elif ["attack1", "attack2"].has(animated_sprite.animation):
		is_attacking = false
		animation_locked = false
	elif animated_sprite.animation == "death":
		pass
func apply_knockback(direction: int) -> void:
	var force = 300.0
	velocity.x = force * direction
	is_knockbacked = true
	await get_tree().create_timer(0.2).timeout
	is_knockbacked = false
	
func set_damage(attack_type):
	var current_damage_to_deal: int
	if attack_type == "attack1":
		current_damage_to_deal = 8
	elif attack_type == "attack2":
		current_damage_to_deal = 10
	Global.playerDamageAmount = current_damage_to_deal
