extends Node

const NETWORK_MODE_MASTER = 1
const NETWORK_MODE_SLAVE = 2
const PLAYERS_PATH = "players/"

onready var ui = get_node("ui")
onready var world = get_parent().get_node("world")

slave var name = "Player"

var players = {}

func _ready():
	ui.connect("client_connected", self, "_on_client_connected")
	ui.connect("client_disconnected", self, "_on_client_disconnected")

	var t = get_tree()
	t.connect("network_peer_connected", self, "_network_peer_connected")
	t.connect("network_peer_disconnected", self, "_network_peer_disconnected")

	t.connect("connected_to_server", self, "_connected_to_server")
	t.connect("connection_failed", self, "_connection_failed")
	t.connect("server_disconnected", self, "_server_disconnected")

"""
Signal handler for when the "Connect" button in the UI is clicked to join a game.
@param ctx { "ip_address": "0.0.0.0", "port": 6969, "player_name": "Player 1" }
"""
func _on_client_connected(ctx):
	print("_on_client_connected(ctx)")
	ui.add_message("Connecting to server")

	if !join_game(ctx["ip_address"], ctx["port"], ctx["player_name"]):
		ui.add_message(str("Unable to connect to server on ip:port ", ctx["ip_address"], ":", ctx["port"]))

"""
Signal handler for when the "Disconnect" button in the UI is clicked to leave a game.
"""
func _on_client_disconnected():
	print("_on_client_disconnected()")
	ui.add_message("Disconnecting from server")
	leave_game()

"""
Signal handler for when a game server connects to us, we should receive ID=1
@param id integer
"""
func _network_peer_connected(id):
	print("_network_peer_connected(", id, ")")
	ui.add_message(str("_network_peer_connected ", id))
	if get_tree().is_network_server():
		players[id] = null

"""
Signal handler for when a game server disconnects from us, we should receive ID=1
Does not fire when we disconnect from server. Example: server boots client from game.
@param id integer
"""
func _network_peer_disconnected(id):
	print("_network_peer_disconnected(", id, ")")
	ui.add_message(str("_network_peer_disconnected ", id))

"""
Signal handler for when client connects to game server. This is where we might
call some initial setup functions.
"""
func _connected_to_server():
	print("_connected_to_server()")
	ui.add_message("_connected_to_server")
	rpc("player_joined", get_tree().get_network_unique_id(), name)

	print("rpc(player_ready)")
	rpc("player_ready", get_tree().get_network_unique_id())

"""
Signal handler for when client is unable to connect to the server. We could
call some error handling functions to provide the user feedback.
"""
func _connection_failed():
	print("_connection_failed()")
	ui.add_message("_connection_failed")

"""
Signal handler for when the server connects. Example: server shuts down
"""
func _server_disconnected():
	print("_server_disconnected()")
	ui.add_message("_server_disconnected")
	leave_game()

"""
Join a game by creating a network client and connecting to a server.
@param ip string server ip address to connect to
@param port integer server port to connect to
@param name string player's name
"""
func join_game(ip, port, name):
	print("join_game(", ip, ",", port, ",", name, ")")
	self.name = name
	var net = NetworkedMultiplayerENet.new()
	#net.set_compression_mode(net.COMPRESS_ZLIB)

	if net.create_client(ip, port) != OK:
		print("Cannot create a client on ip ", ip, " & port ", port, "!")
		ui.add_message(str("Cannot create a client on ip ", ip, " & port ", port, "!"))
		return false

	get_tree().set_network_peer(net)

	print("Connecting to ", ip, ":", port, "..")
	ui.add_message(str("Connecting to ", ip, ":", port, ".."))
	return true

"""
Leave a game, clean up scene tree, disconnect from server
"""
func leave_game():
	print("leave_game()")
	var p = world.get_node(PLAYERS_PATH)
	for i in p.get_children():
		p.remove_child(i)
		i.queue_free()

	get_tree().call_deferred("set_network_peer", null)

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
		if !players.has(i.get_name().to_int()):
			continue
		ret.append(i)
	return ret

"""
Spawn a player, called on both client and server
@param id integer player id
@param name string player name
@param pos Vector2 player start position
"""
sync func spawn_player(id, name, pos = null):
	print("spawn_player(", id, ",", name, ", pos)")
	ui.add_message(str("Spawn player id:name ", id, ":", name))

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
	print("despawn_player(", id, ")")

	var node = get_player_by_id(id)
	if node != null:
		node.queue_free()
