extends Control

@onready var healthbar = $VBoxContainer/Healthbar
@onready var ammo = $VBoxContainer/Ammo

func update_healthbar(value):
	healthbar.value = value
	
func update_ammo(value):
	ammo.text = "%s/∞" % value
