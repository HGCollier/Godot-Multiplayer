extends CharacterBody3D

const SPEED = 7.0
const JUMP_VELOCITY = 8

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

signal health_changed(health)

@onready var camera = $Camera3D
@onready var animation_player = $AnimationPlayer
@onready var muzzle_flash = $Camera3D/Pistol/MuzzleFlash
@onready var raycast = $Camera3D/RayCast3D

var health = 5

func _ready():
	if not is_multiplayer_authority(): return
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	camera.current = true		

func _enter_tree():
	set_multiplayer_authority(str(name).to_int())

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority(): return
	
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * 0.002)
		camera.rotate_x(-event.relative.y * 0.002)
		camera.rotation.x = clamp(camera.rotation.x, -PI / 2, PI / 2)
	
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		
	if event is InputEventMouseButton:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		
	if event.is_action_pressed("shoot") and animation_player.current_animation != "shoot":
		play_shoot_effects.rpc()
		if raycast.is_colliding():
			var hit_player = raycast.get_collider()
			if not hit_player.is_in_group("Player"):
				return
			hit_player.receive_damage.rpc_id(hit_player.get_multiplayer_authority())

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority(): return
	
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle Jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	if InputEventJoypadMotion:
		var axis_vector = Vector2.ZERO
		axis_vector.x = Input.get_action_strength("look_right") - Input.get_action_strength("look_left")
		axis_vector.y = Input.get_action_strength("look_down") - Input.get_action_strength("look_up")
		rotate_y(deg_to_rad(-axis_vector.x) * 2)
		camera.rotate_x(deg_to_rad(-axis_vector.y) * 1)
		camera.rotation.x = clamp(camera.rotation.x, -PI / 2, PI / 2)

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
		
	if (animation_player.current_animation == "shoot"):
		pass
	elif input_dir != Vector2.ZERO and is_on_floor():
		animation_player.play("move")
	else:
		animation_player.play("idle")

	move_and_slide()
	
@rpc("call_local")
func play_shoot_effects():
	animation_player.stop()
	animation_player.play("shoot")
	muzzle_flash.restart()
	muzzle_flash.emitting = true

@rpc("any_peer")
func receive_damage():
	health -= 1
	if health <= 0:
		health = 5
		position = Vector3.ZERO
		position.y += 1
	health_changed.emit(health)

func _on_animation_player_animation_finished(anim_name):
	if anim_name == "shoot":
		animation_player.play("idle")
