extends Area3D

func _on_body_entered(body):
	if body.is_in_group("Player") and body.is_multiplayer_authority():
		body.respawn_player.rpc()
