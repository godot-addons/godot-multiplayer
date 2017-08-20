extends Control

signal client_connected(ctx)
signal client_disconnected()

func _ready():
	get_node("messages").set_scroll_active(true)
	get_node("messages").set_scroll_follow(true)

func _on_connect_pressed():
	var ctx = {
		"ip_address": get_node("ip_address").text,
		"port": get_node("port").text.to_int(),
		"player_name": get_node("player_name").text
	}

	get_node("connect").disabled = true
	get_node("disconnect").disabled = false

	emit_signal("client_connected", ctx)

func _on_disconnect_pressed():
	get_node("connect").disabled = false
	get_node("disconnect").disabled = true

	emit_signal("client_disconnected")

func add_message(msg):
	get_node("messages").add_text(msg + "\n")
