extends CanvasLayer

@onready var main_menu = $MainMenu
@onready var ip_address = $MainMenu/PanelContainer/MarginContainer/VBoxContainer/VBoxContainer/IPAddress
@onready var hud = $HUD
@onready var healthbar = $HUD/VBoxContainer/Healthbar
@onready var ammo = $HUD/VBoxContainer/Ammo

const PLAYER = preload("res://Scenes/Player.tscn")
const PORT = 25576
var enet_peer = ENetMultiplayerPeer.new()

func _on_host_button_pressed():
	main_menu.hide()
	hud.show()
	
	enet_peer.create_server(PORT)
	multiplayer.multiplayer_peer = enet_peer
	multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_disconnected.connect(remove_player)
	
	add_player(multiplayer.get_unique_id())
	upnp_setup()
	
	print("HOST: ", multiplayer.get_unique_id())

func _on_join_button_pressed():
	main_menu.hide()
	hud.show()
	
	enet_peer.create_client(ip_address.text, PORT)
	multiplayer.multiplayer_peer = enet_peer
	
func add_player(peer_id):
	var player = PLAYER.instantiate()
	player.name = str(peer_id)
	$"..".add_child(player)
	if player.is_multiplayer_authority():
		player.health_changed.connect(update_healthbar)
		player.ammo_changed.connect(update_ammo)

func remove_player(peer_id):
	var player = $"..".get_node_or_null(str(peer_id))
	if player:
		player.queue_free()
		
func upnp_setup():
	var upnp = UPNP.new()
	
	var discover_result = upnp.discover()
	assert(discover_result == UPNP.UPNP_RESULT_SUCCESS, "UPNP discover failed! Error %s" % discover_result)
	
	var gateway = upnp.get_gateway()
	assert(gateway and gateway.is_valid_gateway(), "UPNP invalid gateway")
	
	var map_result = upnp.add_port_mapping(PORT)
	assert(map_result == UPNP.UPNP_RESULT_SUCCESS, "UPNP Port mapping failed! Error %s" % map_result)
	
	print("Success! IP address: %s" % upnp.query_external_address())
	
func update_healthbar(value):
	healthbar.value = value
	
func update_ammo(value):
	ammo.text = "%s/∞" % value

func _on_multiplayer_spawner_spawned(node):
	var material = StandardMaterial3D.new()
	material.albedo_color = node.color
	node.mesh.set_material_override(material)
	if node.is_multiplayer_authority():
		node.health_changed.connect(update_healthbar)
		node.ammo_changed.connect(update_ammo)
