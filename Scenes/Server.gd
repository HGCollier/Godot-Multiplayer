extends Node

const PORT = 25576
const PLAYER = preload("res://Scenes/Player.tscn")

@onready var hud = $CanvasLayer/HUD
@onready var main_menu = $CanvasLayer/MainMenu
@onready var username = $CanvasLayer/MainMenu/PanelContainer/MarginContainer/VBoxContainer/VBoxContainer/Name
@onready var ip_address = $CanvasLayer/MainMenu/PanelContainer/MarginContainer/VBoxContainer/VBoxContainer/IPAddress

var enet_peer = ENetMultiplayerPeer.new()
var connected_players = {}
var local_player

func _on_host_button_pressed():
	main_menu.hide();
	hud.show();
	
	enet_peer.create_server(PORT)
	multiplayer.multiplayer_peer = enet_peer
	
	# Client players
	multiplayer.peer_connected.connect(player_connected)
	multiplayer.peer_disconnected.connect(player_disconnected)
	
	# Host player
	add_player(1, Color(randi_range(0, 10) * .1, randi_range(0, 10) * .1, randi_range(0, 10) * .1))
	
	var upnp = UPNP.new()
	
	var discover_result = upnp.discover()
	assert(discover_result == UPNP.UPNP_RESULT_SUCCESS, "UPNP discover failed! Error %s" % discover_result)
	
	var gateway = upnp.get_gateway()
	assert(gateway and gateway.is_valid_gateway(), "UPNP invalid gateway")
	
	var map_result = upnp.add_port_mapping(PORT)
	assert(map_result == UPNP.UPNP_RESULT_SUCCESS, "UPNP Port mapping failed! Error %s" % map_result)
	
	print("Success! IP address: %s" % upnp.query_external_address())

func _on_join_button_pressed():
	main_menu.hide();
	hud.show();
	
	enet_peer.create_client(ip_address.text, PORT)
	multiplayer.multiplayer_peer = enet_peer
	
func add_player(peer_id, player_color):
	connected_players[peer_id] = {
		color = player_color
	}
	var player = PLAYER.instantiate()
	player.color = player_color
	player.set_multiplayer_authority(peer_id)
	add_child(player)
	if player.is_multiplayer_authority():
		player.username = username.text
		player.health_changed.connect(hud.update_healthbar)
		player.ammo_changed.connect(hud.update_ammo)
	if peer_id == multiplayer.get_unique_id():
		local_player = player
	
func remove_player(peer_id):
	var player = get_node_or_null(str(peer_id))
	if player:
		player.queue_free()
		connected_players.erase(peer_id)
	
# Used for adding new player to existing clients
@rpc("any_peer")
func add_new_player(peer_id, color):
	add_player(peer_id, color)
	
@rpc
func remove_old_player(peer_id):
	remove_player(peer_id)

@rpc("call_local")
func add_previous_players(players):
	for peer_id in players:
		add_player(peer_id, players[peer_id].color)

func player_connected(peer_id):
	var color = Color(randi_range(0, 10) * .1, randi_range(0, 10) * .1, randi_range(0, 10) * .1)
	# Add the newly connected player for all other clients
	add_new_player.rpc(peer_id, color)
	# Add the previously connected players
	add_previous_players.rpc_id(peer_id, connected_players)
	# Add this client player
	add_player(peer_id, color)
	
func player_disconnected(peer_id):
	remove_old_player.rpc(peer_id)
	remove_player(peer_id)
