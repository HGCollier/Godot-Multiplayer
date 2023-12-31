extends CharacterBody3D

const SPEED = 7.0
const JUMP_VELOCITY = 8
const MAX_AMMO = 6

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

signal health_changed(health)
signal ammo_changed(ammo)

@onready var camera = $Camera3D
@onready var animation_player = $AnimationPlayer
@onready var pistol = $Camera3D/Pistol
@onready var muzzle_flash = $Camera3D/Pistol/MuzzleFlash
@onready var raycast = $Camera3D/RayCast3D
@onready var mesh = $MeshInstance3D
@onready var eyes = $Eyes
@onready var label = $Label3D
@onready var ragdoll_clone = $RigidClone

var health = 5
var ammo = MAX_AMMO
var color: Color = Color(0, 0, 0)
var username: String:
	get:
		return username
	set(value):
		username = value
		update_label.rpc(value)

func _ready():
	ragdoll_clone.freeze = true
	name = str(get_multiplayer_authority())
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	mesh.set_material_override(material)
	
	if not is_multiplayer_authority():
		return
		
	label.hide()
	eyes.hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	camera.current = true

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * 0.002)
		camera.rotate_x(-event.relative.y * 0.002)
		camera.rotation.x = clamp(camera.rotation.x, -PI / 2, PI / 2)
	
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		
	if event is InputEventMouseButton:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		
	if animation_player.current_animation == "reload" || animation_player.current_animation == "shoot":
		return
		
	if event.is_action_pressed("reload"):
		play_reload_effects.rpc()
		return
		
	if event.is_action_pressed("shoot") and ammo > 0:
		play_shoot_effects.rpc()
		if raycast.is_colliding():
			var hit_player = raycast.get_collider()
			if not hit_player.is_in_group("Player"):
				return
			hit_player.receive_damage.rpc_id(hit_player.get_multiplayer_authority())

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	
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
		
	if (animation_player.current_animation == "shoot" || animation_player.current_animation == "reload"):
		pass
	elif input_dir != Vector2.ZERO and is_on_floor():
		animation_player.play("move")
	else:
		animation_player.play("idle")

	move_and_slide()
	
@rpc("call_local")
func play_shoot_effects():
	if ammo <= 0:
		return
	animation_player.stop()
	animation_player.play("shoot")
	muzzle_flash.restart()
	muzzle_flash.emitting = true
	ammo -= 1
	ammo_changed.emit(ammo)
	
@rpc("call_local")
func play_reload_effects():
	animation_player.stop()
	animation_player.play("reload")
	ammo = MAX_AMMO
	ammo_changed.emit(ammo)

@rpc("any_peer")
func receive_damage():
	health -= 1
	health_changed.emit(health)
	if health <= 0:
		ragdoll.rpc()
		await get_tree().create_timer(4).timeout
		respawn_player.rpc()
	
@rpc("call_local")
func ragdoll():
	mesh.hide()
	eyes.hide()
	pistol.hide()
	if is_multiplayer_authority():
		return
	var _ragdoll = RigidBody3D.new()
	var _mesh_instance = MeshInstance3D.new()
	var _collision_shape = CollisionShape3D.new()
	_mesh_instance.mesh = CapsuleMesh.new()
	_collision_shape.shape = CapsuleShape3D.new()
	_ragdoll.add_child(_mesh_instance)
	_ragdoll.add_child(_collision_shape)
	_ragdoll.apply_impulse(Vector3(10, 10, 0), Vector3.ZERO)
	get_parent().add_child(_ragdoll)

@rpc("call_local")
func update_label(text):
	label.text = text

@rpc("call_local")
func respawn_player():
	pistol.show()
	ragdoll_clone.hide()
	ragdoll_clone.freeze = true
	ragdoll_clone.position = Vector3.ZERO
	ragdoll_clone.rotation = Vector3.ZERO
	health = 5
	ammo = MAX_AMMO
	position = Vector3.ZERO
	position.y += 1
	health_changed.emit(health)
	ammo_changed.emit(ammo)
	if is_multiplayer_authority():
		return
	mesh.show()
	eyes.show()

func _on_animation_player_animation_finished(anim_name):
	if anim_name == "shoot":
		animation_player.play("idle")
