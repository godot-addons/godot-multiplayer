extends Node

const Client = preload("res://com.brandonlamb.client/client.gd")
const Settings = preload("res://com.brandonlamb.client/settings.gd")

#const NETWORK_MODE_MASTER = 1
#const NETWORK_MODE_SLAVE = 2
const PLAYERS_PATH = "players/"

onready var ui = get_node("ui")
onready var world = get_parent().get_node("world")

slave var name = "Player"

var client

func _ready():
	ui.connect("client_connected", self, "_on_client_connected")
	ui.connect("client_disconnected", self, "_on_client_disconnected")

"""
Join a game by creating a network client and connecting to a server.
@param ip string server ip address to connect to
@param port integer server port to connect to
@param name string player's name
"""
func join_game(ip, port, name):
	print("join_game(", ip, ",", port, ",", name, ")")
	self.name = name

	if client != null:
		print("Server already running")
		return false

	# Create new server, need to pass in scene tree and settings object
	client = Client.new(get_tree(), Settings.new(ip, port, 1, 57600 / 8, 14400 / 8))

	# Listen for network signals
	client.connect("network_peer_connected", self, "_network_peer_connected")
	client.connect("network_peer_disconnected", self, "_network_peer_disconnected")

	client.connect("connected_to_server", self, "_connected_to_server")
	client.connect("connection_failed", self, "_connection_failed")
	client.connect("server_disconnected", self, "_server_disconnected")

	var r = client.start()

	if !r.status:
		print(r.message)
		ui.add_message(r.message)
		return false

	print(r.message)
	ui.add_message(r.message)

	return true

"""
Signal handler for when the "Connect" button in the UI is clicked to join a game.
@param ctx { "ip_address": "0.0.0.0", "port": 6969, "player_name": "Player 1" }
"""
func _on_client_connected(ctx):
	print("_on_client_connected")
	ui.add_message("_on_client_connected")

	if !join_game(ctx["ip_address"], ctx["port"], ctx["player_name"]):
		print("Unable to connect to server: ip=", ctx["ip_address"], ", port=", ctx["port"])
		ui.add_message(str("Unable to connect to server: ip=", ctx["ip_address"], ", port=", ctx["port"]))

"""
Signal handler for when the "Disconnect" button in the UI is clicked to leave a game.
"""
func _on_client_disconnected():
	print("_on_client_disconnected")
	ui.add_message("_on_client_disconnected")

	var r = client.stop()
	print(r.message)
	ui.add_message(r.message)

	client = null

	leave_game()

"""
Signal handler for when a game server connects to us, we should receive ID=1
@param id integer
"""
func _network_peer_connected(id):
	print("_network_peer_connected: id=", id)
	ui.add_message(str("_network_peer_connected: id=", id))

"""
Signal handler for when a game server disconnects from us, we should receive ID=1
Does not fire when we disconnect from server. Example: server boots client from game.
@param id integer
"""
func _network_peer_disconnected(id):
	print("_network_peer_disconnected: id=", id)
	ui.add_message(str("_network_peer_disconnected: id=", id))

"""
Signal handler for when client connects to game server. This is where we might
call some initial setup functions.
"""
func _connected_to_server():
	print("_connected_to_server")
	ui.add_message("_connected_to_server")

	var id = get_tree().get_network_unique_id()
	rpc("player_joined", id, name)
	rpc("player_ready", id)

"""
Signal handler for when client is unable to connect to the server. We could
call some error handling functions to provide the user feedback.
"""
func _connection_failed():
	print("_connection_failed")
	ui.add_message("_connection_failed")

"""
Signal handler for when the server connects. Example: server shuts down
"""
func _server_disconnected():
	print("_server_disconnected")
	ui.add_message("_server_disconnected")

	var r = client.stop()
	print(r.message)
	ui.add_message(r.message)

	client = null

	leave_game()

"""
Leave a game, clean up scene tree, disconnect from server
"""
func leave_game():
	print("leave_game")
	ui.add_message("leave_game")

	var p = world.get_node(PLAYERS_PATH)
	for i in p.get_children():
		p.remove_child(i)
		i.queue_free()

"""
Get a player node from scene tree by its ID
@param id integer
@return Node
"""
func get_player_by_id(id):
	var path = PLAYERS_PATH + str(id)
	if !world.has_node(path):
		return null

	return world.get_node(path)

"""
Get an array of players contained within the world
@return array of Node
"""
func get_players():
	var ret = []
	for i in world.get_node(PLAYERS_PATH).get_children():
		if !client.peers.has(i.get_name().to_int()):
			continue
		ret.append(i)
	return ret

#
# RPC functions
#

"""
Spawn a player, called on both client and server
@param id integer player id
@param name string player name
@param pos Vector2 player start position
"""
sync func spawn_player(id, name, pos = null):
	print("spawn_player: id=", id, ", name=", name, ", pos=", pos)
	ui.add_message(str("spawn_player: id=", id, ", name=", name, ", pos=", pos))

	if get_player_by_id(id) != null:
		return

	var inst = Node2D.new()
	inst.set_name(str(id))
	#inst.player_name = str(name)
	world.get_node(PLAYERS_PATH).add_child(inst)

"""
Despawn player, called on both client and server. This can be triggered when
a client disconnects from the server, or the server boots a client.
@param id integer player id
"""
sync func despawn_player(id):
	print("despawn_player: id=", id)
	ui.add_message(str("despawn_player: id=", id))

	var node = get_player_by_id(id)
	if node != null:
		node.queue_free()
