extends Control

@onready var grid := $Grid
var card_scene := preload("res://scenes/ui/weapon_card.tscn")

func _ready():
	# populate with placeholder cards
	for i in range(12):
		var c = card_scene.instantiate()
		var icon = c.get_node("Icon")
		# optional: assign placeholder texture if exists
		var tex = load("res://assets/sprites/coin.png")
		if tex:
			icon.texture = tex
		grid.add_child(c)
