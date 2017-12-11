extends Control

signal server_started(ctx)
signal server_stopped()

func _ready():
	get_node("messages").set_scroll_follow(true)
	get_node("messages").set_scroll_active(true)

"""
Signal handler for when the "Start Server" button is clicked in the UI
"""
func _on_start_server_pressed():
	var ctx = {
		"ip_address": get_node("ip_address").text,
		"port": get_node("port").text.to_int(),
		"max_clients": get_node("max_players").value
	}

	get_node("start_server").disabled = true
	get_node("stop_server").disabled = false

	emit_signal("server_started", ctx)

"""
Signal handler for when the "Stop Server" button is clicked in the UI
"""
func _on_stop_server_pressed():
	get_node("start_server").disabled = false
	get_node("stop_server").disabled = true

	emit_signal("server_stopped")

"""
Add a message to the messages RichTextLabel
"""
func add_message(msg):
	get_node("messages").add_text(msg + "\n")
