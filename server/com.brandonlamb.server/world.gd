extends Node

func _ready():
	get_parent().get_node("lobby").world_ready()
